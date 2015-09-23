--
-- Dotter.lua
-- (C)2015 Bill Johnson
--
-- State machine that casts as many DoTs as possible on the current target.
--
local Core = require("Core")
local MQ2Cast = require("MQ2Cast")
local StatefulTask = require("Util.StatefulTask")
local Spell = require("Data.Spell")
local Target = require("Data.Target")
local Player = require("Data.Player")
local Util = require("Util")
local AllDoTs = require("Metadata.DoTs")

local Cast = MQ2Cast.Cast
local debug = Core.debug
local call = Util.call
local xdata = Core.xdata

-- Can I cast this dot on my current target?
local function canDotTarget(dot)
	if Spell.ready(dot) and (not Target.hasMyBuff(dot)) then
		return true
	else
		return false
	end
end

-- Find a dot I could cast on this target.
local function findDotForTarget(dots)
	for i=1,#dots do
		if canDotTarget(dots[i]) then return dots[i] end
	end
end

local dotter = StatefulTask:new()

-- Cast object for dotter
dotter.cast = Cast:new({ nomem = true })
function dotter.cast:succeeded()
  dotter:event("succeeded")
end
function dotter.cast:failed(reason)
  dotter:event("failed")
end

------------ State: main - waiting for someone to ask us to cast something

------------ State: begin - begin casting on target
function dotter:didTransitionTo_begin()
  self.target:target()
	self.dotsTried = {}
  self.dotsCast = {}
  self:nextState("pick")
end

------------ State: pick - determine which DoT to cast
function dotter:didTransitionTo_pick()
  --debug(1, "dotter:pick")
  -- Verify conditions
	if not Player.castingPosture() then
		debug(1, "dotter:pick aborting - player not in casting posture")
		return self:nextState("abort")
	end
  if (not self.target) or (not self.target:isMyTarget()) then
    debug(1, "dotter:pick aborting - target changed")
    return self:nextState("abort")
  end
	if xdata("Target", nil, "PctHPs") < 1 then
		debug(1, "dotter:pick done - target dead")
		return self:nextState("done")
	end
  -- Look for a dot we can cast
  local dot = findDotForTarget(self.dots, self.target)
  debug(1, "dotter:pick findDotForTarget=",dot)
	if dot then
    self.dot = dot; self:nextState("cast")
	else
    self:nextState("done")
	end
end

----------- State: cast - use MQ2Cast to cast the dot
function dotter:didTransitionTo_cast()
  debug(1, "dotter:cast: ", self.dot)
  self.cast:setAbility(self.dot)
  self.cast:execute()
end

function dotter:cast_event_succeeded()
  -- Pick next dot if this one worked.
  table.insert(self.dotsCast, self.dot)
  self:nextState("waitForGCD")
end

function dotter:cast_event_failed(reason)
  self:nextState("abort")
end

-------------- State: waitForGCD - wait for global cooldown.
function dotter:didTransitionTo_waitForGCD()
  --debug(1, "dotter:waitForGCD")
  self:loop(0) -- Tight loop, don't want to waste any time.
end

function dotter:loop_waitForGCD()
  -- If any spell gem is ready we are out of GCD.
  for i=1,12 do
    if xdata("Cast", nil, "Ready", i) then
      return self:nextState("pick")
    end
  end
end

function dotter:didTransitionFrom_waitForGCD()
  self:loop(nil)
end

-------------- State: done - can't cast any more dots on this target
function dotter:didTransitionTo_done()
  debug(1, "dotter:done")
  -- Invoke done callback
  call(self.onDone, self.dotsCast)
  self:nextState("main")
end

-------------- State: abort - something went wrong.
function dotter:didTransitionTo_abort()
  debug(1, "dotter:abort")
  -- Interrupt our cast if some other process asked us to abort.
  self.cast:interrupt()
  call(self.onAbort, "aborted", self.dotsCast)
	self.target = nil; self.onAbort = nil; self.onDone = nil
  self:nextState("main")
end

-- Begin the dotting process.
function dotter:go(target, dots, onDone, onAbort)
	local state = self:state()
  if state ~= "main" and state ~= "__init" then return onAbort("busy", self:state()) end
  self.target = target; self.dots = dots; self.onDone = onDone; self.onAbort = onAbort
  self:nextState("begin")
  return true
end

-- Abort an in-progress dotting.
function dotter:abort()
	debug(1, "dotter: abort was requested...")
	if self:state() ~= "main" then self:nextState("abort") end
end

-- Get list of memmed dots.
function dotter.memmedDoTs()
  local dots = {}
  for i=1,Spell.numGems() do
    local id, name, strippedName = Spell.getSpellInfoForGem(i)
		if id then strippedName = Spell.split(name) end -- strip rank
    if name and AllDoTs[strippedName] then dots[#dots + 1] = name end
  end
  return dots
end

-- Returns true if one of the dots can work on the target.
function dotter.canDoTTarget(dots)
	return findDotForTarget(dots)
end

dotter:run()
return dotter
