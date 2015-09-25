-- MQ2Caster
-- Allows a task to invoke MQ2Cast, sending events from MQ2Cast back
-- to the requesting task.
--
-- Loosely based on MQ2Cast_Spell_Routines
local find = string.find
local extend = require("Util").extend
local callMethod = require("Util").callMethod

local Core = require("Core")
local Task = require("Util.Task")
local MQ2 = require("MQ2")
local Spell = require("Data.Spell")

local exec = MQ2.exec
local data = MQ2.data
local xdata = MQ2.xdata
local clock = MQ2.clock
local debug = Core.debug

--------------------------------- MQ2cast interface
local function CastStatus() return xdata("Cast", nil, "Status") end
local function CastResult() return xdata("Cast", nil, "Result") end

------------------------------ CASTING TASK
-- A background task that watches for casts and processes them.
local castTask = Task:new()

-- Watch MQ2Cast status.
function castTask:main()
	-- Are we currently casting a spell?
	local cast = self.cast; if not cast then return end
	-- Check to see if the cast status needs to be updated.
	local castStatus = CastStatus()
	if cast.status ~= castStatus then
		cast.status = castStatus; 	self:event("castStatusChanged")
	end
	if not self.casting then
		-- GCD wait
		if self.gcdWait then
			if (not xdata("Me", nil, "SpellInCooldown")) then
				self.gcdWait = nil; self.started = clock()
				exec(cast.command)
			end
			return
		end

		-- Timeout if MQ2cast isn't bothering to try and cast this
		if ((clock() - self.started) > cast.precastTimeout) then
			self:event("castDone", "CAST_TIMEOUT")
		end
	end
end

function castTask:handleEvent(ev, ...) return callMethod(self, ev, ...) end

function castTask:castStatusChanged()
	local cast = self.cast;
	local status = cast.status;

	debug(10, "castTask:castStatusChanged ", tostring(status))
	if not find(cast.status, "C") then
		self:event("castDone")
	else
		self.casting = true
	end
end

function castTask:castDone(result)
	local cast = self.cast
	local result = result or CastResult()
	debug(10, "castTask:castDone ", tostring(result))
	-- Clear task status and stop runloop.
	self.cast = nil; self.casting = false; self:loop(nil)
	-- Invoke callbacks on task
	if result == "CAST_SUCCESS" then return cast:_success() else return cast:_failure(result) end
end

function castTask:castInterrupt()
	local cast = self.cast
	-- Clear task status and stop runloop.
	self.cast = nil; self.casting = false; self:loop(nil)
	debug(2, "castTask:castInterrupt() -- interrupting cast")
	exec([[/interrupt]])
	return cast:_failure("CAST_INTERRUPTED")
end

function castTask:castStart()
	debug(10, "castTask:castStart")
	self.started = clock()
	self.casting = false
	self:loop(0.2)
end

castTask:run()

------------------------------- Cast object.
-- Represents a request for MQ2Cast to cast a spell.
local Cast = {}
Cast.__index = Cast

function Cast:new(data)
	x = setmetatable({
		status = "",
		tries = 1, -- Number of times to retry this spell in the event of noncritical failures.
		cancelInvis = false, -- If true, cast despite invisibility. Otherwise, fail if Invis.
		cancelFeign = false, -- If true, get up from FD when casting. Otherwise, fail if FD'd.
		memorize = true, -- Memorize this spell if not already memorized. When false, abort if not memorized.
		gem = Spell.getDefaultGem(), -- What gem should I memorize in?
		precastTimeout = 1, -- How long should I wait for MQ2Cast to acknowledge the cast.
		cooldownTimeout = 0, -- How long should I wait for a cooling-down ability? 0 = immediate error
		gcdWait = true -- Should I wait for the global cooldown?
	}, self)
	-- Mixin options
	extend(x, data)
	return x
end

-- Update options for this cast
function Cast:setOptions(options)
	extend(self, options)
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

-- Compute cooldown. In case of spells, will onl work if spell is in a gem.
-- Returns 0 if ready.
function Cast:getCooldown()
	return Spell.getCooldown(self.type, self.name)
end

function Cast:isReady()
	return xdata("Cast", nil, "Ready", self.name)
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

	self.command = castPortion
end

-- Compute the buff name this cast would apply.
function Cast:getBuffName() return self.buffName end

-- Execute the cast.
function Cast:execute()
	-- Make sure the cast paramters exist
	if (not self.type) or (not self.name) or (not self.command) then error("attempt to execute unspecified cast") end
	-- Make sure mq2cast is ready to cast.
	self.status = CastStatus()
	if (castTask.cast) or (not find(self.status, "I")) then
		debug(2, "Cast:execute() failed because a cast is already pending")
		return self:_failure("CAST_PENDING")
	end
	-- if invis, don't cast unless cancelInvis is true
	if (not self.cancelInvis) and xdata("Me", nil, "Invis") then
		return self:_failure("CAST_INVISIBLE")
	end
	-- if feigned, cancel feign if permitted
	if xdata("Me", nil, "Feigning") then
		if not self.cancelFeign then return self:_failure("CAST_STANDING") end
		exec([[/stand]])
	end
	-- If we have a nomem spellcast, make sure the spell is already in a gem.
	if self.type == "spell" and (not self.memorize) then
		if not Spell.gem(self.name) then
			debug(3, "Cast:execute() failed because [", self.name, "] not memorized")
			return self:_failure("CAST_NOMEM")
		end
	end
	-- Check cooldown
	local cd, waitUntil = self:getCooldown(), nil
	if cd and cd > self.cooldownTimeout then
		debug(3, "Cast:execute() failed because [", self.name, "] in cooldown")
		return self:_failure("CAST_NOTREADY")
	end
	if cd and cd > 0 and self.cooldownTimeout > 0 then
		waitUntil = clock() + cd + 0.3
	end
	-- Launch spellcast.
	debug(5, "Cast:execute(): casting ", self.type, " '", self.name, "' with command '", self.command, "'")
	castTask.cast = self
	castTask:event("castStart")
	-- If GCD and GCDwait...
	castTask.waitUntil = waitUntil
	if self.gcdWait and (self.type == "spell") and xdata("Me", nil, "SpellInCooldown") then
		debug(5, "Cast:execute() waiting for GCD")
		castTask.gcdWait = true
		-- Defer execution till castloop
	elseif waitUntil then
		-- Defer execution till castloop
	else
		exec(self.command)
	end
	return self
end

-- Interrupt the cast, if it is still casting.
function Cast:interrupt()
	if castTask.cast ~= self then return end
	castTask:event("castInterrupt")
end

-- A waitable version of this task for use with task:waitFor()
function Cast:waitable()
	return function(notificationTarget)
		if not notificationTarget then return self:execute() end
		function self:succeeded() notificationTarget:event("cast_succeeded") end
		function self:failed(reason) notificationTarget:event("cast_failed", reason) end
	end
end

-- Internal Callbacks
function Cast:_success()
	if self.succeeded then return self:succeeded() end
end

function Cast:_failure(reason)
	if self.failed then return self:failed(reason) end
end

return {
	Cast = Cast,
}
