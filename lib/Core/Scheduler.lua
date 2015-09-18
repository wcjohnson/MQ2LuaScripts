--------------------------------------
-- (C) 2010 Bill Johnson
--
-- Implementation of a scheduling algorithm.
---------------------------------------
local MQ2 = require("MQ2")
local Core = require("Core")

local clock = MQ2.clock
local next = _G.next;
local unpack = table.unpack;
local select = _G.select;
local tsort = table.sort;

local Scheduler = {}
if not Scheduler then return; end

-----------------------------------------------------------------
-- CORE
-----------------------------------------------------------------
-- The schedule future table; records all future scheduled events in time sorted order.
local sched_future = {};
-- The schedule execution queue; scheduled events that are past due are placed here to be run.
-- Using the execution queue enables insertion reentrancy in the scheduler (a requirement since
-- things often want to reschedule themselves) and also helps enforce strict time ordering.
local sched_xq = {};
-- Function for time-sorting the schedule queue. Objects with lowest time should be last in the
-- queue; as it's more efficient in lua to pull elements off the end of an array.
local function timeSort(x1,x2) return x1[1] > x2[1]; end

-- The main schedule executive. Called per-frame.
local function SchedFrame()
	-- Indices:
	-- n = # of schedule entries
	-- m = index of active element in execution queue
	-- t = time
	local n, m, t = #sched_future, 0, clock();
	-- Objects of interest: x = entry at tail of schedule (lowest time); temp = a temp variable for swaps
	local x, tmp = sched_future[n], nil;
	-- For each scheduled object that's past-due
	while (x and x[1] <= t) do
		-- Increment our write position
		m = m + 1;
		-- Remove us from the future queue
		sched_future[n] = nil;
		-- Write our schedule entry into the execution queue
		sched_xq[m] = x;
		-- Move to the previous schedule entry in the array (next in time)
		n = n - 1; x = sched_future[n];
	end
	-- For every object added to the execution queue (in reverse order, i.e. increasing time order)
	for i=m,1,-1 do
		-- Retrieve and execute
		x = sched_xq[i];
		tmp = x[2]; if tmp then tmp(unpack(x,3)); end
		-- Remove it from the execution queue
		sched_xq[i] = nil;
	end
end

-- Schedule allocator. Finds a free schedule entry or reuses one off the free list.
local function SchedAlloc()
	return {};
end
-- Append entries to the schedule queue.
local function SchedAppend(x)
	sched_future[#sched_future + 1] = x;
	return tsort(sched_future, timeSort);
end
local function SchedAppendAndReturn(x)
	sched_future[#sched_future + 1] = x;
	tsort(sched_future, timeSort);
	return x;
end

-- Run the scheduler every pulse.
Core.pulse:connect(SchedFrame)

--------------------------------------------------------
-- API
--------------------------------------------------------
-----
-- @function XF.Scheduler.Schedule
-- Schedule f to happen in dt seconds, passing any additional arguments along to f.
-----
function Scheduler.Schedule(dt, f, ...)
	local x = { clock() + dt, f, ... }
	--x.func = f; x.t = GetTime() + dt;
	--for i=1,select("#", ...) do x[i] = select(i, ...); end
	SchedAppend(x);
	return x;
end

-- Remove a scheduled task.
function Scheduler.Unschedule(x)
	for i=1,#sched_future do
		if sched_future[i] == x then
			-- Just clear out the entry; no need to screw around with the list.
			sched_future[i] = {}
		end
	end
end

-- Reschedule, re-using the schedule object.
-- Should only be used if you know the scheduled task has already run, or was Unscheduled.
function Scheduler.Reschedule(x, dt)
	x[1] = clock() + dt;
	SchedAppend(x);
	return x;
end

-- Grab direct access to the future schedule. This should be used with great caution.
function Scheduler._GetSchedule()
	return sched_future;
end

return Scheduler
