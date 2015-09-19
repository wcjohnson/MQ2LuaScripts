-- MQ2Caster
-- Allows a task to invoke MQ2Cast, sending events from MQ2Cast back
-- to the requesting task.
--
-- Loosely based on MQ2Cast_Spell_Routines
local find = string.find
local extend = require("Util").extend

local Core = require("Core")
local Task = require("Core.Task")
local MQ2 = require("MQ2")
local exec = MQ2.exec
local data = MQ2.data
local Spell = require("Data.Spell")

--local function debug(...) Core.print(...) end
local function debug(...) end

--------------------------------- MQ2cast interface
local function CastStatus()
	return data("Cast.Status")
end

local function CastResult()
	return data("Cast.Result")
end

------------------------------ CASTING TASK
-- A background task that watches for casts and processes them.
local castTask = Task:new()

-- Watch MQ2Cast status.
function castTask:main()
	-- Are we currently casting a spell?
	local cast = self.cast; if not cast then return end
	-- Check to see if the cast status needs to be updated.
	--MQ2.log(MQ2.data("Cast.Status"))
	local castStatus = CastStatus()
	if cast.status ~= castStatus then
		cast.status = castStatus
		self:event("castStatusChanged")
	end
end

function castTask:handleEvent(ev)
	--MQ2.log("castTask:handleEvent ", tostring(ev))
	local x = self[ev]
	if x then x(self, ev) end
end

function castTask:castStatusChanged()
	local cast = self.cast;
	local status = cast.status;

	debug("castTask:castStatusChanged ", tostring(status))
	if not find(cast.status, "C") then
		self:event("castDone")
	end
end

function castTask:castDone()
	local cast = self.cast
	local result = CastResult()
	debug("castTask:castDone ", tostring(result))
	-- Clear task status and stop runloop.
	self.cast = nil
	self:loop(nil)
	-- Invoke callbacks on task
	if result == "CAST_SUCCESS" then
		return cast:_success()
	else
		return cast:_failure()
	end
end

function castTask:castStart()
	debug("castTask:castStart")
	self:loop(0.2)
end

castTask:run()

------------------------------- Cast object.
-- Represents a request for MQ2Cast to cast a spell.
local Cast = {}
Cast.__index = Cast

function Cast:new(data)
	x = setmetatable({}, Cast)
	x.status = ""
	x.retries = 1
	x.cancelInvis = false
	x.cancelFeign = false
	x.memorize = true
	x.waitForCooldown = true
	x.gem = Spell.getDefaultGem()
	-- Mixin options
	extend(x, data)
	return x
end

-- Find the ability (spell, AA, or item) that we will be casting.
function Cast:setAbility(name)
	local name, ty = Spell.findAbility(name)
	if not name then return nil end
	self.name = name; self.type = ty
	if ty == "item" then
		-- For clickies, get the name of the buff they will put up
		self.buffName = Spell.getItemSpellName(name)
	else
		self.buffName = name
	end
	self:computeCommand()
	return true
end

-- Compute command from cast options.
function Cast:computeCommand()
	local castPortion
	if self.type == "alt" then
		castPortion = ([[/casting "%s|alt"]]):format(self.name)
	elseif self.type == "item" then
		castPortion = ([[/casting "%s|item"]]):format(self.name)
	else
		castPortion = ([[/casting "%s|gem%d"]]):format(self.name, self.gem)
	end

	-- XXX: compute options
	self.command = castPortion
end

-- Compute the buff name this cast would apply.
function Cast:getBuffName() return self.buffName end

-- Execute the cast.
function Cast:execute()
	-- Make sure the cast paramters exist
	if (not self.type) or (not self.name) or (not self.command) then
		error("attempt to execute unspecified cast")
	end
	-- If we have a nomem spellcast, make sure the spell is already in a gem.

	-- Make sure mq2cast is ready to cast.
	self.status = CastStatus()
	if (castTask.cast) or (not find(self.status, "I")) then
		debug("Cast:execute() failed because CAST_BUSY")
		return self:_failure("CAST_BUSY")
	end
	-- Launch spellcast.
	debug("Cast:execute(): casting ", self.type, " '", self.name, "' with command '", self.command, "'")
	castTask.cast = self
	castTask:event("castStart")
	exec(self.command)
	return self
end

-- Internal Callbacks
function Cast:_success()
	if self.succeeded then return self:succeeded() end
end

function Cast:_failure(reason)
	if self.failed then return self:failed(reason) end
end

function Cast:_waiter(waiter)
	function self:succeeded() waiter:event("cast_succeeded"); end
	function self:failed(reason) waiter:event("cast_failed", reason); end
end

return {
	Cast = Cast,
}
