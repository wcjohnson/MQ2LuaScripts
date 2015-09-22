local Util = require("Util")
local Task = require("Util.Task")
local Core = require("Core")
local KeyedSet = require("Util.KeyedSet")

local next = _G.next
local type = _G.type
local setmetatable = _G.setmetatable
local callMethod = Util.callMethod
local getMeta = Util.getMeta
local setMeta = Util.setMeta

-- Weak table of all filters.
local allFilters = setmetatable({}, { __mode = 'k' })

-- Whenever we zone, empty all spawnfilters.
Core.leftZone:connect( function()
	for filt in next, allFilters do filt:clear() end
end )

-- Whenever a spawn is removed, remove it from all spawnfilters.
Core.onRemoveSpawn:connect( function(id)
	for filt in next, allFilters do filt:removeID(id) end
end )

--------------------------------- SpawnFilter object.
local SpawnFilter = {}
Util.extend(SpawnFilter, KeyedSet)

function SpawnFilter:new()
	local x = KeyedSet:new()
	setmetatable(x, { __index = self, __newindex = Util.Error("Don't add entries to SpawnFilters!") })
	allFilters[x] = true
	return x
end

return SpawnFilter
