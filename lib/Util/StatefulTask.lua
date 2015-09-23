--
-- StatefulTask.lua
-- (C)2015 Bill Johnson
--
-- A Task combined with a StateMachine, including facilities for
-- statefully handling events.
--
local StateMachine = require("Util.StateMachine")
local Task = require("Util.Task")

local compressEvent = Task.compressEvent
local tinsert = table.insert
local select = select

local log = function(...) require("Core").print(...) end
-- local log = function(...) end

local function stHandleEvent(self, ev, ...)
	local state = self:state()
	-- Execute a command to transition
	if ev == "transitionTo" then
		return self:transitionTo(select(1, ...))
	end
	-- Look for a stateful event handler.
	local evh = self[ ("%s_event_%s"):format(state, ev) ]
	if evh then
		return evh(self, ev, ...)
	else
		-- Look for a stateful unhandled-event handler.
		local uhevh = self[ ("%s_unhandled_event"):format(state) ]
		if uhevh then return uhevh(self, ev, ...) end
	end
end

local function stStash(self, ev, ...)
	tinsert(self._replayQ, compressEvent(ev, ...))
end

local function stReplay(self)
	local rq = self._replayQ; self._replayQ = {}
	for i=1,#rq do self:_event(rq[i]) end
end

local function stMain(self)
	local loopFunc = self[ ("loop_%s"):format(self:state()) ]
	if loopFunc then return loopFunc(self) end
	-- Begin by transitioning to "main" state.
	if self:state() == "__init" then
		self:transitionTo("main")
	end
end

local function stNextState(self, where, ...)
	return self:event("transitionTo", where, ...)
end

local StatefulTask = {}

function StatefulTask:new()
	local t = Task:new()
	StateMachine:mixInto(t)
	t._replayQ = {}
	t.stash = stStash; t.replay = stReplay; t.nextState = stNextState
	t.handleEvent = stHandleEvent; t.main = stMain
	return t
end

return StatefulTask
