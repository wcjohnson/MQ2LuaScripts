-- NecroBot

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
local debug = Core.debug
local xdata = Core.xdata
local Cast = MQ2Cast.Cast
local exec = Core.exec

-----------
-- Options
-----------
local campRadius = 100 -- Haters in this radius are valid targets.
local aggroThreshold = 70 -- Feign if aggro on any mob above this threshold.
local medThreshold = 99 -- Med if mana below this threshold.
local useMemmedDots = true -- Automatically cast any DoT that's memorized
local dotsPerPass = 5 -- Number of DoTs to cast on one target before looking for other targets to dot.
local additionalDots = {
	{ spell = "Heroic Soulreaper Robe", condition = Util.True }
}

-------------------- bot is a task with a StateMachine attached.
local bot = StatefulTask:new()
bot.targets = {}
-- Event debugging
local _botevent = bot.event
function bot:event(ev, ...)
	if(ev ~= "_start") then debug(1, "bot:event ", ev, ": ", ...) end
	return _botevent(self, ev, ...)
end

-- Target-finding subsystem.
local function hater_add() return bot:event("targets") end
local function hater_remove() return bot:event("targets") end
local hatersInCamp = SpawnFilter:new()
local function inCampPredicate(spawn)
	return spawn:isInRange(campRadius)
end
hatersInCamp:updater( function(self)
	self:assign(Haters.set, inCampPredicate)
end )
hatersInCamp:update(1)
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

-- Feign cast
local feignCast = Cast:new()
feignCast:setAbility("Death Peace")

----------------- Feign state
-- TODO: Automation/Feigner - keep feigning till it works.
function bot:didTransitionTo_feign()
	log("bot:feign")
	self:loop(1)
end

function bot:loop_feign()
	-- Unfeign if we don't have aggro anymore
	if not hasAggro() then
		self:nextState("combat")
	end
	-- Keep trying to feign till we're feigned.
	if not xdata("Me", nil, "Feigning") then
		feignCast:execute()
	end
end

function bot:feign_event_lost_aggro()
	return self:nextState("combat")
end

function bot:didTransitionFrom_feign()
	self:loop(nil)
end

----------------- Attack state
function bot:didTransitionTo_attack()
	log(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> bot:attack ", self.target:Name())
	aggroFlag = false -- force new aggro notification
	self.target:target()
	exec("/pet attack")
	Dotter:go(self.target, Dotter.memmedDoTs(), dotter_succeeded, dotter_aborted, dotsPerPass)
end

function bot:didTransitionFrom_attack()
	Dotter:abort()
end

function bot:attack_event_dotter_succeeded()
	self:nextState("combat")
end

function bot:attack_event_dotter_aborted(reason)
	self:nextState("combat")
end

function bot:attack_event_pulled_aggro()
	self:nextState("feign")
end

----------------- Combat state.
-- XXX: Assist HP threshold - don't attack until mob below %
-- XXX: "call for assist" function - zerg a target until dead
-- XXX: LoS check.
function bot:didTransitionTo_combat()
	log("bot:combat")
	-- If no haters left, goto main.
	hatersInCamp:pack(self.targets)
	if hatersInCamp:count() == 0 then return self:nextState("rest") end
	self:loop(1)
end

function bot:didTransitionFrom_combat()
	self:loop(nil)
end

function bot:loop_combat()
	-- If has aggro, feign.

	-- If not standing, and I don't have aggro, stand up.
	if (not xdata("Me", nil, "Standing")) and (not aggroFlag) then
		MQ2.exec([[/stand]])
	end
	-- Target the highest HP eligible target
	self.target = nil
	table.sort(self.targets, function(a, b) return a:PctHP() > b:PctHP() end)
	for i=1,#(self.targets) do
		if checkTargetValidity(self.targets[i]) then self.target = self.targets[i]; break end
	end
	-- If I do have a target...
	if checkTargetValidity(self.target) then
		self:nextState("attack")
	end
end

function bot:combat_event_targets()
	hatersInCamp:pack(self.targets)
	-- When nobody hates us, transition back to main.
	if hatersInCamp:count() == 0 then return self:nextState("rest") end
end

function bot:combat_event_pulled_aggro()
	return self:nextState("feign")
end

----------------- Rest state.
function bot:didTransitionTo_rest(from, to)
	log("bot:rest")
	-- If anyone hates us, transition to the Combat state.
	if hatersInCamp:count() > 0 then self:event("transitionTo", "combat") end
	self:loop(2)
end

function bot:didTransitionFrom_rest(from, to)
	self:loop(nil)
end

function bot:loop_rest()
	-- Med if LoM
	if xdata("Me", nil, "Standing") and (xdata("Me", nil, "PctMana") < medThreshold) then
		MQ2.exec("/sit")
	end
end

function bot:rest_event_targets()
	-- If anyone hates us, transition to the Combat state.
	if hatersInCamp:count() > 0 then self:event("transitionTo", "combat") end
end

---------------- Commands

function bot:playBot()
	if self:state() == "main" or self:state() == "__init" then self:nextState("rest") end
end

function bot:pauseBot()
	self:nextState("main")
end

bot:run()
return bot
