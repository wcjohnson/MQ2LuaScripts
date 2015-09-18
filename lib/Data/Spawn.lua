--
-- Spawn.lua
-- (C)2015 Bill Johnson
-- 
-- Spawn object.
--
local Core = require("Core")

local spawndb = {}

-- Dump spawn db whenever we zone.
local function dump_db() spawndb = {} end
Core.leftZone:connect(dump_db)
-- XXX: Remove spawns from spawn DB when Everquest removes them.

local Spawn = {}
Spawn.__index = Spawn

function Spawn:new(id)
	local x = setmetatable( { }, self )
	x.id = id or 0
	return x
end

function Spawn:forID(id)
	local x = spawndb[id]
	if x then return x end
	x = Spawn:new(id); spawndb[id] = x; return x
end

return Spawn
