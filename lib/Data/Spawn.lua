--
-- Spawn.lua
-- (C)2015 Bill Johnson
--
-- Spawn object.
--
local Core = require("Core")
local data = Core.data
local xdata = Core.xdata
local exec = Core.exec
local sqrt = math.sqrt

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

function Spawn.forID(id)
	if (not id) or (id == 0) then return nil end
	local x = spawndb[id]; if x then return x end
	x = Spawn:new(id); spawndb[id] = x; return x
end

function Spawn.forMyTarget()
	return Spawn.forID(xdata("Target", nil, "ID"))
end

function Spawn:Name()
	return xdata( "Spawn", self.id, "CleanName" )
end

function Spawn:PctHP()
	return xdata( "Spawn", self.id, "PctHPs" )
end

function Spawn:isValid()
	return xdata( "Spawn", self.id, "ID") and true or false
end

function Spawn:target()
	if xdata("Target", nil, "ID") ~= self.id then
		return exec( ("/target id %d"):format(self.id) )
	end
end

function Spawn:isMyTarget()
	return (xdata("Target", nil, "ID") == self.id)
end

-- Determine if this spawn is within r of me.
function Spawn:isInRange(r)
	local x, y = xdata("Me", nil, "X"), xdata("Me", nil, "Y")
	if (not x) or (not y) then return false end
	local x1, y1 = xdata("Spawn", self.id, "X"), xdata("Spawn", self.id, "Y")
	if (not x1) or (not y1) then return false end
	return sqrt( (x-x1)*(x-x1) + (y-y1)*(y-y1) ) < r
end

return Spawn
