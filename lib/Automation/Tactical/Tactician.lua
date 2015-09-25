--
-- Tacticians.lua
-- (C)2015 Bill Johnson
--
-- A Tactician is a state machine for executing sequences of Tactics.
--
local Core = require("Core")
local StatefulTask = require("Util.StatefulTask")
local Util = require("Util")

local debug = Core.debug
local call = Util.call
local xdata = Core.xdata

local Tactician = {}

---------------------------------------- API
-- Make a tactician
function Tactician:new()
	local t = StatefulTask:new()
	Util.extend(t, Tactician)
	return t
end

-- Execute a set of tactics.
-- Returns false if the tactician is busy executing another set of tactics.
function Tactician:execute(tactics, onDone)
	-- Check for busy
	if self.tactics then
		debug(1, "Tactician:execute: Tactician is busy")
		return false
	end
	if not tactics then
		error("Tactician:execute: missing tactics variable")
	end
	-- Run the tactics
	self.tactics = tactics; self.onDone = onDone
	self:nextState("begin")
	return true
end

-- Check if tactician is busy with another set of tactics.
function Tactician:isBusy()
	if self.tactics then return true else return false end
end

-- Report result of tactics:executeTactic.
function Tactician:tacticDidExecute(tactic, success, data)
	if self:state() == "abort" then return end -- Ignore result from aborted tactics
	local tactics, myTactic = self.tactics, self.tactic
	if not tactics then return end -- Post-abort stuff
	if myTactic ~= tactic then return end
	-- Store success information
	if success then table.insert(self.tacticsSuccessful, tactic) end
	self.lastTacticSucceeded = success
	self.lastTacticResult = data
	-- Jump back to tactic selection
	return self:nextState("didExecute")
end

-- Abort an in-progress set of tactics.
function Tactician:abort(tactics)
	if self:state() ~= "main" then
		if tactics and (self.tactics ~= tactics) then
			debug(1, "Tactician: someone asked me to abort, but it was not the guy using me.")
		end
		debug(1, "Tactician: aborting...")
		self:nextState("abort")
	end
end

-- Run a tactic. The tactic should call self:tacticDidExecute to report results.
-- Must be overriden in subclasses.
function Tactician:executeTactic(tactic)
	error("You should implement this")
end

------------------------------------------------ STATE MACHINE
function Tactician:_reset()
	self.tactics = nil; self.onDone = nil
end

------------ State: main - waiting for task.
function Tactician:didTransitionTo_main()
	debug(10, "Tactition: state: main")
end

------------ State: begin - begin executing a set of Tactics.
function Tactician:didTransitionTo_begin()
	debug(10, "Tactician: state: begin")
	self.tacticsTried = {}
  self.tacticsSuccessful = {}
	self.tacticsState = nil; self.tactic = nil
	self.lastTacticSucceeded = nil; self.lastTacticResult = nil
	self.tactics:didBegin()
  self:nextState("pick")
end

------------ State: pick - choose a tactic to try.
function Tactician:didTransitionTo_pick()
	debug(10, "Tactician: state: pick")
	local tactics, tacticsState = self.tactics, self.tacticsState

	-- Determine the tactic to run.
	local tactic, ts = tactics:nextTactic(self, tacticsState, self.tactic, self.lastTacticSucceeded, self.lastTacticResult)
	self.tacticsState = ts

	-- Try the tactic
	self.tactic = tactic
	if tactic then
		table.insert(self.tacticsTried, tactic)
		return self:nextState("willExecute")
	else
		return self:nextState("done")
	end
end

-------------- State: willExecute - a tactic has been picked and is about to run
-- You may override this in a subclass if you need to do something
-- before a tactic executes. For example, Caster uses this to wait for a
-- gcd if the thing being cast is a spell.
function Tactician:didTransitionTo_willExecute()
	return self:nextState("execute")
end

----------- State: execute - Run the tactic.
function Tactician:didTransitionTo_execute()
	debug(10, "Tactician: state: execute")
	local tactics, tactic = self.tactics, self.tactic
	return self:executeTactic(tactic)
end

-------------- State: didExecute - a tactic has just executed.
-- You may override this in a subclass if you need to do something
-- after tactics execute.
function Tactician:didTransitionTo_didExecute()
	return self:nextState("pick")
end

-------------- State: done - tactic selection returned nil
function Tactician:didTransitionTo_done()
  debug(10, "Tactician: state: done")
  -- Invoke done callback
  call(self.onDone, self, true)
  return self:nextState("main")
end

function Tactician:didTransitionFrom_done()
	self:_reset()
end

-------------- State: abort - received outside request to stop.
-- If you need to clean up during abort, you can override didTransitionTo_abort
-- in a subclass.
function Tactician:willTransitionTo_abort()
  debug(10, "Tactician: will abort")
  call(self.onDone, self, false, "TACTICIAN_ABORT")
  self:nextState("main")
	return true
end

function Tactician:didTransitionFrom_abort()
	self:_reset()
end

return Tactician
