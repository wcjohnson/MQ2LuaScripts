-- NecroBot is a state machine.
-- States:
-- THINK:
--		Check what to do next. All states transition back to THINK
--		after they complete.
-- OPPORTUNISTIC_CHECK_TARGETS:
--		Iterate through xtarget list. Find someone who isn't dotted up.
--		Stores value for who's not dotted up and what dot they're missing.
-- FEIGN:
--		When aggro above feign threshold on any xtarg, go to this state.
--		We keep casting feign until it works, the goto FEIGNED
-- FEIGNED:
--		Our feign worked. Sit here until aggro < threshold.
--		Then goto THINK.
local Util = require("Util")
local MQ2Cast = require("MQ2Cast")
local Core = require("Core")
local Haters = require("Data.Haters")
local StatefulTask = require("Util.StatefulTask")
local Spell = require("Data.Spell")
local Target = require("Data.Target")
local SpawnFilter = require("Data.SpawnFilter")
local Dotter = require("Automation.Dotter")
local Task = require("Util.Task")
local Deferred = require("Util.Deferred")

local log = Core.print
local xdata = Core.xdata
local Cast = MQ2Cast.Cast

-----------
-- Options
-----------
local campRadius = 100 -- Haters in this radius are valid targets.
local aggroThreshold = 70 -- Feign if aggro on any mob above this threshold.
local medThreshold = 99 -- Med if mana below this threshold.
local useMemmedDots = true -- Automatically cast any DoT that's memorized
local additionalDots = {

}

-------------------- bot is a task with a StateMachine attached.
local bot = StatefulTask:new()
bot.targets = {}
-- Event debugging
local _botevent = bot.event
function bot:event(ev, ...)
	if(ev ~= "_start") then log("bot:event ", ev, ...) end
	return _botevent(self, ev, ...)
end

-- Haters in camp range.
local hatersInCamp = SpawnFilter:new()
local function inCampPredicate(spawn)
	return spawn:isInRange(campRadius)
end
hatersInCamp:updater( function(self)
	self:assign(Haters.set, inCampPredicate)
end )
hatersInCamp:update(1)
local function hater_add() return bot:event("targets") end
local function hater_remove() return bot:event("targets") end
hatersInCamp:onAdded(hater_add)
hatersInCamp:onRemoved(hater_remove)

-- Aggro checker
local function aggro_gained() return bot:event("pulled_aggro") end
local function aggro_lost() return bot:event("lost_aggro") end
local aggroChecker = Task:new()
local aggroFlag = false
local function hasAggro()
	for i=1,10 do
		local _,tt,_,name,_,aggro = Target.getXTargetInfo(i)
		if aggro and (aggro > aggroThreshold) then
			log("hasAggro on ", name)
			return true
		end
	end
	return false
end
function aggroChecker:main()
	if hasAggro() then
		if (not aggroFlag) then aggroFlag = true; aggro_gained() end
	else
		if aggroFlag then aggroFlag = false; aggro_lost() end
	end
end
aggroChecker:run()
aggroChecker:loop(1)

-- Dotter callbacks
local function dotter_succeeded(dotsCast) return bot:event("dotter_succeeded", dotsCast) end
local function dotter_aborted(...) return bot:event("dotter_aborted", ...) end

-- Target validity callbacks
local function checkTargetValidity(target)
	if (not target) or (not target:isValid()) then return false end
	if target:PctHP() < 1 then return false end
	if not hatersInCamp:test(target) then return false end
	return true
end

local function nextTarget(targets, target)
	local ix = Util.find(targets, target)
	if not ix then return targets[1] end
	return targets[ix + 1] or targets[1]
end

-- Feign cast
local feignCast = Cast:new()
feignCast:setAbility("Death Peace")

----------------- Feign state
-- TODO: Automation/Feigner - keep feigning till it works.
function bot:didTransitionTo_feign()
	log("bot:feign")
	Dotter:abort()
	self:loop(1)
end

function bot:loop_feign()
	if not xdata("Me", nil, "Feigning") then
		feignCast:execute()
	end
end

function bot:feign_event_lost_aggro()
	return self:transitionTo("combat")
end

function bot:didTransitionFrom_feign()
	self:loop(nil)
	-- Get up
	MQ2.exec([[/stand]])
end

----------------- Attack state
function bot:didTransitionTo_attack()
	log(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> bot:attack ", self.target:Name())
	aggroFlag = false -- force new aggro notification
	Dotter:go(self.target, Dotter.memmedDoTs(), dotter_succeeded, dotter_aborted)
end

function bot:didTransitionFrom_attack()
	Dotter:abort()
end

function bot:attack_event_dotter_succeeded()
	self:nextTarget()
	self:nextState("combat")
end

function bot:attack_event_dotter_aborted(reason)
	self:nextState("combat")
end

function bot:attack_event_pulled_aggro()
	self:nextState("feign")
end

----------------- Combat state.
function bot:didTransitionTo_combat()
	log("bot:combat")
	-- If no haters left, goto main.
	hatersInCamp:pack(self.targets)
	if hatersInCamp:count() == 0 then return self:nextState("main") end
	self:loop(1)
end

function bot:didTransitionFrom_combat()
	self:loop(nil)
end

function bot:nextTarget()
	self.target = nextTarget(self.targets, self.target)
end

function bot:loop_combat()
	-- If not standing, and I don't have aggro, stand up.
	if (not xdata("Me", nil, "Standing")) and (not aggroFlag) then
		MQ2.exec([[/stand]])
	end
	-- If I don't have a target...
	if not checkTargetValidity(self.target) then
		-- Sort targets by health; highest first
		table.sort(self.targets, function(a, b)
			return a:PctHP() > b:PctHP()
		end)
		self.target = nextTarget(self.targets, self.target)
	end
	-- If I do have a target...
	if checkTargetValidity(self.target) then
		self:nextState("attack")
	end
end

function bot:combat_event_targets()
	hatersInCamp:pack(self.targets)
	-- When nobody hates us, transition back to main.
	if hatersInCamp:count() == 0 then return self:nextState("main") end
end

function bot:combat_event_pulled_aggro()
	return self:nextState("feign")
end

----------------- Main state.
function bot:didTransitionTo_main(from, to)
	log("bot:main")
	-- If anyone hates us, transition to the Combat state.
	if hatersInCamp:count() > 0 then self:event("transitionTo", "combat") end
	self:loop(2)
end

function bot:didTransitionFrom_main(from, to)
	self:loop(nil)
end

function bot:loop_main()
	if xdata("Me", nil, "Standing") and (xdata("Me", nil, "PctMana") < medThreshold) then
		MQ2.exec("/sit")
	end
end

function bot:main_event_targets()
	-- If anyone hates us, transition to the Combat state.
	if hatersInCamp:count() > 0 then self:event("transitionTo", "combat") end
end

return bot
