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

-- Trigger object
local Trigger = {}
function Trigger:new()
	-- Create the trigger
	t = Task:new()
	function t:activate() self:loop(self.delay) end
	function t:deactivate() self:loop(nil) end
	-- Store trigger in database
	triggers[#triggers + 1] = t

	return t
end

function Trigger.BuffSpell(delay, origSp, castOptions)
	local cast = Cast:new(castOptions)
	if not cast:setAbility(origSp) then error("can't find spell " .. tostring(origSp)) end
	local spellName = cast.name

	function cast:failed(reason) MQ2.log("BuffSpell failed ", tostring(reason)) end

	local t = Trigger:new()
	t.delay = delay or 1
	function t:main()
		--MQ2.log("BuffSpell:main()")
		-- Buff exit conditions
		if (
			Player.isInIdleZone()
			or Player.hasLongBuff(spellName)
			or (not Player.buffPosture())
			or (not Spell.stacks(spellName))
			or (not (Player.pctMana() > 30))
		) 
		then
			--MQ2.log("BuffSpell:condFail()")
			return
		end
		-- Wait until the cast wakes our coroutine.
		return self:waitFor(cast:execute())
	end
	t:activate()
	t:run()
	return t
end

-- On leaveGame, cancel all triggers
local function cancelAll()
	MQ2.log("Triggers.cancelAll()")
	for i=1,#triggers do
		triggers[i]:deactivate()
		triggers[i]:stop()
	end
end
Core.leftWorld:connect(cancelAll)
Trigger._cancelAll = cancelAll

return Trigger
