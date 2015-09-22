--
-- Haters.lua
-- (C)2015 Bill Johnson
--
-- Uses XTarget to keep track of haters.
--

local Core = require("Core")
local Task = require("Util.Task")
local Target = require("Data.Target")
local Spawn = require("Data.Spawn")
local Signal = require("Util.Signal")
local SpawnFilter = require("Data.SpawnFilter")
local Deferred = require("Util.Deferred")

local getXTInfo = Target.getXTargetInfo

----------------- Hater monitor.
local nhaters = 0
local Haters = SpawnFilter:new()

Haters:updater( function(self)
	local id, ty, tt, name, aggro, hp
	local hater
	local set = self
	local newHaters = {}

	-- Pull hate data from xtargets
	nhaters = 0
	for i=1,13 do
		id, tt, ty, name, hp, aggro = getXTInfo(i)
		if id and (tt == "Auto Hater") and (ty == "NPC") then
			newHaters[id] = true
			hater = set[id]
			if not hater then
				-- Hater wasn't on the list; add it.
				hater = Spawn:forID(id)
				self:add(hater)
			end
			hater.name = name
			hater.aggro = aggro
			hater.hp = hp

			nhaters = nhaters + 1
		end
	end

	-- Remove stale haters.
	self:intersectWith(newHaters)
end )

Haters:update(0.25)
Haters:onAdded( function(_, id, spawn)
	Core.print("haterFilter:added ", id, spawn:Name())
end)
Haters:onRemoved( function(_, id, spawn)
	Core.print("haterFilter:removed ", id, spawn:Name())
end)

------------
local exports = {}
exports.set = Haters

local onChanged = Signal:new()
exports.onChanged = onChanged

local debounceChanges = Deferred.debounce( function()
	return onChanged:raise(Haters)
end )
Haters:onAdded(debounceChanges)
Haters:onRemoved(debounceChanges)

return exports
