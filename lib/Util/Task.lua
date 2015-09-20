local co_resume = coroutine.resume
local co_create = coroutine.create
local co_status = coroutine.status
local co_yield = coroutine.yield
local tremove = table.remove
local tinsert = table.insert
local type = _G.type
local unpack = table.unpack
local error = _G.error
local select = _G.select

local clock = nil

local Util = require("Util")
local filter_array = Util.filter_array
local remove_element = Util.remove_element

--local function debug(...) require("Core").log(...) end
local function debug(...) end

local function compressEvent(ev, ...)
	if select("#", ...) == 0 then return ev else return {ev, ...}	end
end

local function decompressEvent(ev)
	if type(ev) == "table" then return unpack(ev) else return ev end
end

----------------------- Taskmaster
-- Resume a paused task upon receipt of an event.
local function task_resume(task, ev)
	--debug("task_resume: task ", tostring(task), " received event: ", tostring(ev))
	local ok, errMsg
	-- Clear the task's wakeup timer
	task[3] = nil
	-- Pass the event to the coroutine's mainloop
	ok, errMsg = co_resume(task[1], ev)
	-- Propagate lua errors.
	if not ok then error(errMsg) end
end

-- Wait until an event arrives or until a certain clocktime, whichever is sooner.
local function task_waitUntil(task, t)
	-- Set the task's wakeup timer
	task[3] = t
	-- Yield to other tasks.
	local ev = co_yield("_wait")
	-- Allow task to be killed.
	if ev == "_kill" then
		debug("task_waitUntil: task ", tostring(task), " was forcekilled.")
		taskmaster_remove(task)
		co_yield("_killed")
		error("zombie Task was resumed...")
	end
	-- Return the event we got from the taskmaster back to the controlling task.
	return ev
end

-- Get the last event from this tasks' event queue.
local function task_popEvent(task)
	local q = task[2]
	local ev = q[#q]
	if ev then q[#q] = nil; return ev else return nil end
end

local function task_isDone(task)
	if co_status(task[1]) == "dead" then
		return true
	else
		return false
	end
end

local function taskmaster_processTask(t, task)
	local ev = task_popEvent(task)
	if ev then
		task_resume(task, ev)
	elseif task[3] and t > task[3] then
		task_resume(task, "_wake")
	end
end

local tasks = {}
local taskn = 1

local function taskmaster_nextTask(t)
	task = tasks[taskn]; if not task then taskn = 1; return end
	if task_isDone(task) then
		-- debug("taskmaster_nextTask: removing dead task ", tostring(task), " at index ", taskn)
		return tremove(tasks, taskn)
	else
		taskn = taskn + 1
		return taskmaster_processTask(t, task)
	end
end

local tasksPerTick = 5
local function taskmaster_loop()
	local t = clock()
	for i=1,tasksPerTick do
		taskmaster_nextTask(t)
	end
end

local function taskmaster_add(task)
	tasks[#tasks + 1] = task
end

local function taskmaster_remove(task)
	remove_element(tasks, task)
end

-- Set up the taskmaster.
-- Pass in a clock function, which will return a monotone increasing
-- clock. (os.clock works.)
-- Will return a loop function, which you should call often.
local function taskmaster_setup(clockFunc)
	clock = clockFunc
	return taskmaster_loop
end

----------------------- Task main function
-- Event-handling mainloop.
function task_main(self, ev)
	--debug("task_main: task ", tostring(self), " event ", ev)
	local t;
	while true do
		t = clock()
		-- "_start" is sent when the task's main() should run
		-- which is at first launch and for each mainLoop tick.
		if ev == "_start" then
			-- Run the mainloop.
			self:main()
			-- If we're still looping...
			if self.runLoopDelay then 
				-- Schedule the next loop iteration
				self.runLoopDue = t + self.runLoopDelay
			else
				-- We're not looping anymore. Reset the runloop due date.
				self.runLoopDue = nil
			end
		elseif ev == "_stop" then
			-- Someone asked us to stop. This should terminate the coroutine.
			return
		elseif ev ~= "_wake" then
			-- Handle event.
			local hev = self.handleEvent
			if hev then
				hev(self, decompressEvent(ev))
			end
		end
		-- If we're looping, and the run loop is due...
		if self.runLoopDelay and (t > (self.runLoopDue or 0)) then
			-- Send "_start" to ourselves.			
			self:event("_start")
		end
		-- Wait until the run loop is due, or until woken by an event if we aren't looping.
		ev = task_waitUntil(self, self.runLoopDue)
	end
end

----------------------- Task object
local Task = {}
Task.__index = Task

function Task:new()
	local x = setmetatable({}, Task)
	x:reset()
	return x
end

-- Send an event to this task.
function Task:event(ev, ...)
	return tinsert(self[2], 1, compressEvent(ev, ...))
end
function Task:_event(cev)
	return tinsert(self[2], 1, cev)
end

-- Enqueue the given task in the taskmaster.
function Task:run()
	self:event("_start")
	taskmaster_add(self)
end
function Task:prepare()
	taskmaster_add(self)
end

-- Wait, either for an event or the given number of seconds, whichever
-- comes first. If no timeout provided, will wait forever.
function Task:wait(sec)
	return task_waitUntil(self, sec and clock() + sec or nil)
end

-- Wait until the stated clock() value.
function Task:waitUntil(t)
	return task_waitUntil(self, t)
end

-- Wait for a waitable.
function Task:waitFor(waitable, sec)
	waitable(self)
	waitable()
	return task_waitUntil(self, sec and clock() + sec or nil)
end

-- Determine if the task is currently active
function Task:isActive()
	return (self[1] and (co_status(self[1]) ~= "dead"))
end

-- Reset a task object whose main function has terminated.
function Task:reset()
	if self:isActive() then
		error("cannot reset an active task")
	end
	self[1] = co_create( function(...) return task_main(self, ...) end )
	self[2] = {}
	self[3] = nil
end

-- Instruct the task to repeat its mainloop.
-- Call with nil to stop looping.
function Task:loop(delay)
	self.runLoopDelay = delay
	-- Setting runLoopDue will cause the runloop to be scheduled when the mainloop picks up again.
	if delay then self.runLoopDue = 0 else self.runLoopDue = nil end
end

-- Stop this task.
function Task:stop() self:event("_stop") end

-- Force kill this task.
function Task:kill() self:event("_kill") end

-- Helper functions for dealing with events with args.
Task.compressEvent = compressEvent
Task.decompressEvent = decompressEvent

-- Taskmaster setup
Task.taskmaster = taskmaster_setup

return Task
