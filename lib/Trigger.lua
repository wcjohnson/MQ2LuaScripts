--
-- Triggers.lua
-- (C)2015 Bill Johnson
--
-- System similar to MQ2Melee's "downshits."
-- 
local Task = require("Core.Task")
local Player = require("Data.Player")
local Spell = require("Data.Spell")
local MQ2 = require("MQ2")
local MQ2Cast = require("MQ2Cast")
local Cast = MQ2Cast.Cast
local Core = require("Core")

-- Trigger database
local triggers = {}

---------------------------------------------- Trigger object
local Trigger = {}
function Trigger:new(mainFunc, delay)
	-- Create the trigger
	t = Task:new()
	function t:activate() self:loop(self.delay) end
	function t:deactivate() self:loop(nil) end
	t.main = mainFunc or function() end
	t.delay = delay or 0
	-- Store trigger in database
	triggers[#triggers + 1] = t
	-- Activate it
	t:activate(); t:run()

	return t
end

-- On leaveGame, cancel all triggers
local function cancelAll()
	MQ2.log("Triggers.cancelAll()")
	for i=1,#triggers do
		triggers[i]:deactivate()
		triggers[i]:stop()
	end
	-- Throwout old database.
	triggers = {}
end
Core.leftWorld:connect(cancelAll)
Trigger._cancelAll = cancelAll

--------------------------------- Trigger utilities

-- Chain trigger. Will run each function in succession for each iteration of the trigger mainloop.
function Trigger.Chain(...)
	local triggerChain = { ... }
	local triggerIdx = 1

	return function(self)
		-- Get current trigger
		local trigger = triggerChain[triggerIdx]
		if not trigger then triggerIdx = 1; trigger = triggerChain[1] end
		if not trigger then
			--Core.print("Trigger.Chain aborting")
			return
		end -- no triggers in chain...
		--Core.print("Trigger.Chain running trigger #", triggerIdx)
		-- Move on to next trigger in chain
		triggerIdx = triggerIdx + 1
		-- Do the trigger.
		return trigger(self)
	end
end

-- Simple trigger. If condition, then action.
function Trigger.Simple(cond, act)
	return function(self)
		if cond(self) then return act(self) end
	end
end

-- Cast trigger. If condition, then cast the given spell.
function Trigger.Cast(cond, spell, castOptions)
	local cast = Cast:new(castOptions)
	if not cast:setAbility(spell) then error("can't find spell " .. spell) end

	return function(self)
		self.cast = cast
		if cond(self) then
			-- Cast the spell and wait for a result.
			ev = self:waitFor(cast:waitable())
			return ev
		end
	end

end

-- Typical conditions for buffing.
function Trigger.BuffConditions()
	return function(self)
		local buffName = self.cast:getBuffName()
		return
			(not Player.isInIdleZone()) and
			(not Player.hasLongBuff(buffName)) and
			Player.buffPosture() and
			Spell.stacks(buffName) and
			(Player.pctMana() > 30)
	end
end

return Trigger
