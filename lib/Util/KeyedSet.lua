--
-- KeyedSet.lua
-- (C)2015 Bill Johnson
--
-- A keyed set is an observable collection of objects all with a distinct ID.
-- The obj.id field is always used as the ID.
-- The keyed set has methods for
local Util = require("Util")
local Task = require("Util.Task")
local Hooker = require("Util.Hooker")
local noop = require("noop")

local setmetatable = setmetatable
local getmetatable = getmetatable
local next = next
local select = select
local rawset = rawset

local getMeta = Util.getMeta
local setMeta = Util.setMeta
local True = Util.True
local callMetaMethod = Util.callMetaMethod

--------------- Helpers
local function _reallyAdd(self, id, obj)
  rawset(self, id, obj)
  return callMetaMethod(self, "onAdded", id, obj)
end

local function _reallyRemove(self, id, obj)
  rawset(self, id, nil)
  return callMetaMethod(self, "onRemoved", id, obj)
end

--------------------------------------------------- Core
local KeyedSet = {}

function KeyedSet:new()
  local x = setmetatable( {}, { __index = self, __newindex = Util.Error("don't add table entries to KeyedSets!") } )
  return x
end

------ Observation
local function _obs(self, key, what, func)
  local mt = getmetatable(self)
  mt[key] = what(mt[key], func)
end

function KeyedSet:onAdded(func)
  return _obs(self, "onAdded", Hooker.hook, func)
end
function KeyedSet:onRemoved(func)
  return _obs(self, "onRemoved", Hooker.hook, func)
end
function KeyedSet:offAdded(func)
  return _obs(self, "onAdded", Hooker.unhook, func)
end
function KeyedSet:offRemoved(func)
  return _obs(self, "onRemoved", Hooker.unhook, func)
end

------ Access
function KeyedSet:test(obj)
  if not obj or (not obj.id) or (not self[obj.id]) then return false else return true end
end

function KeyedSet:testID(id)
  return self[id]
end

function KeyedSet:pack(array)
  local oldsz, i = #array, 1
  for k,v in next,self do array[i] = v; i = i + 1 end
  for j=i,oldsz do array[j] = nil end
end

function KeyedSet:packIDs(array)
  local oldsz, i = #array, 1
  for k,v in next,self do array[i] = k; i = i + 1 end
  for j=i,oldsz do array[j] = nil end
end

function KeyedSet:count()
  local n = 0
  for _ in next,self do n=n+1 end
  return n
end

------ Mutation
function KeyedSet:add(obj)
  if not obj or (not obj.id) or self[obj.id] then return end
  return _reallyAdd(self, obj.id, obj)
end

function KeyedSet:remove(obj)
  if not obj or (not obj.id) or (not self[obj.id]) then return end
  return _reallyRemove(self, obj.id, obj)
end

function KeyedSet:removeID(id)
  local obj = self[id]; if not obj then return end
  return _reallyRemove(self, id, obj)
end

-- Remove all
function KeyedSet:clear()
  for k,v in next,self do _reallyRemove(self, k, v) end
end

-- Remove all objects not matching predicate.
function KeyedSet:filterInPlace(predicate)
  for k,v in next,self do
    if not predicate(v) then _reallyRemove(self, k, v) end
  end
end

-- Remove objects in this set that arent in the other.
function KeyedSet:intersectWith(otherSet)
  for k,v in next,self do
    if not otherSet[k] then _reallyRemove(self, k, v) end
  end
end

-- Add objects in other set not in this one.
function KeyedSet:unionWith(otherSet)
  for k,v in next,otherSet do
    if not self[k] then _reallyAdd(self, k, v) end
  end
end

-- Make this set have the same members as the other set, modulo
-- filtration by the predicate.
function KeyedSet:assign(otherSet, predicate)
  if not predicate then predicate = Util.True end
  for k,v in next,self do
    if (not otherSet[k]) or (not predicate(v)) then _reallyRemove(self, k, v) end
  end
  for k,v in next,otherSet do
    if (not self[k]) and predicate(v) then _reallyAdd(self, k, v) end
  end
end

-- Make this set update itself in accordance with the other set, modified
-- by the predicate.
function KeyedSet:observe(otherSet, predicate)
  -- Don't observe if already observing
  if getMeta(self, "observed") then return nil end
  if not predicate then predicate = Util.True end

  local function observedAdd(set, id, obj)
    if predicate(obj) then return self:add(obj) end
  end
  local function observedRemove(set, id, obj)
    return self:remove(obj)
  end

  setMeta(self, "observed", otherSet)
  setMeta(self, "observedAdd", observedAdd)
  setMeta(self, "observedRemove", observedRemove)

  self:assign(otherSet, predicate)
  otherSet:onAdded(observedAdd)
  otherSet:onRemoved(observedRemove)
  return true
end

-- Stop observing.
function KeyedSet:stopObserving()
  otherSet = getMeta(self, "observed"); if not otherSet then return end

  otherSet:offAdded(getMeta(self, "observedAdd"))
  otherSet:offRemoved(getMeta(self, "observedRemove"))

  setMeta(self, "observedAdd", nil)
  setMeta(self, "observedRemove", nil)
  setmeta(self, "observed", nil)
end

-- Set a periodic updater function for this set.
function KeyedSet:updater(upd)
	-- Create task if nonexistent.
	local t = getMeta(self, "_task")
	if not t then
		t = Task:new(); setMeta(self, "_task", t); t:prepare()
	end
	t.main = function(...) upd(self, ...) end
end

-- Run updater every interval seconds.
-- Call self:update(nil) to stop updating.
-- An interval of zero updates every tick. DONT DO THAT unless
-- you are really sure of what you are doing.
function KeyedSet:update(interval)
	-- Create task if nonexistent.
	local t = getMeta(self, "_task")
	t:loop(interval)
	-- Wake the task if an interval was given.
	if interval then t:event("_start") end
end


return KeyedSet
