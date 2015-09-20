local Util = require("Util")
local callMethod = Util.callMethod
local Task = require("Util.Task")
local next = _G.next
local type = _G.type

-- Weak table of all filters.
local allFilters = setmetatable({}, { __mode = 'k' })

-- Whenever we zone, empty all spawnfilters.

--------------------------------- SpawnFilter object.
local SpawnFilter = {}
SpawnFilter.__index = SpawnFilter

function SpawnFilter:new()
	local x = setmetatable({ {} }, self)
	x._taskMain = function() return callMethod(x, "updater") end
	allFilters[x] = true
	return x
end

---- Access
-- Get number of spawns in this spawnfilter
function SpawnFilter:count()
	local n = 0
	for _ in next,self[1] do n=n+1 end
	return n
end

-- Check if spawn or id is in filter.
function SpawnFilter:check(x)
	if type(x) == "number" then
		return self[1][x]
	else
		return self[1][x.id]
	end
end

-- Get the table for this spawnfilter.
function SpawnFilter:table() return self[1] end

-- Pack all the spawn objects in this filter into an array.
function SpawnFilter:packSpawns(array)
	local oldsz, i = #array, 1
	for k,v in next,self[1] do array[i] = v; i = i + 1 end
	for j=i,oldsz do array[j] = nil end
end

---- Addition
local function _reallyAdd(self, id, spawn)
	self[1][id] = spawn
	-- if self.n then self.n = self.n + 1 end
	return callMethod(self, "added", spawn)
end

-- Add a spawn to this spawnfilter.
function SpawnFilter:add(spawn)
	local id = spawn.id
	if (not id) or (id == 0) then return end
	if self[1][id] then return end
	return _reallyAdd(self, id, spawn)
end

---- Removal
local function _reallyRemove(self, id, spawn)
	self[1][id] = nil
	-- if self.n then self.n = self.n - 1 end
	return callMethod(self, "removed", spawn)
end

-- Remove a spawn from this spawn filter by ID.
function SpawnFilter:removeByID(id)
	if (not id) or (id == 0) then return end
	local spawn = self[1][id]
	if not spawn then return end
	return _reallyRemove(self, id, spawn)
end

-- Remove a spawn from this spawnfilter.
function SpawnFilter:remove(spawn)
	return self:removeByID(spawn.id)
end

--------- Mutation
-- Remove all spawns in this filter that are not in the other.
-- like this = this (intersect) other.
function SpawnFilter:intersect(other)
	for id,spawn in next,self[1] do
		if not other[id] then
			_reallyRemove(self, id, spawn)
		end
	end
end

-- Add all spawns in the other filter that aren't in this one.
-- Like this = this (union) other
function SpawnFilter:union(other)
	local tbl = self[1]
	for id,spawn in next,other do
		if not tbl[id] then
			_reallyAdd(self, id, spawn)
		end
	end
end

-- Run self:updater() every interval seconds.
-- Call self:update(nil) to stop updating.
-- An interval of zero updates every tick. DONT DO THAT unless
-- you are really sure of what you are doing.
function SpawnFilter:update(interval)
	-- Create task if nonexistent.
	local t = self._task
	if not t then
		t = Task:new(); self._task = t
		t.main = self._taskMain
		t:prepare()
	end
	t:loop(interval)
	-- Wake the task if an interval was given.
	if interval then t:event("_start") end
end


return SpawnFilter
