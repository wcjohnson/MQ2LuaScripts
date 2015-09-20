--
-- Haters.lua
-- (C)2015 Bill Johnson
--
-- Uses XTarget to keep track of haters.
--

local Core = require("Core")
local Task = require("Core.Task")
local Target = require("Data.Target")
local getXTInfo = Target.getXTInfo
local Spawn = require("Data.Spawn")
local Signal = require("Util.Signal")
local SpawnFilter = require("Data.SpawnFilter")

----------------- Hater monitor.
local nhaters = 0
local Haters = SpawnFilter:new()
local onHatersChanged = Signal:new()

function Haters:updater()
	local id, ty, tt, name, aggro, hp
	local hater
	local set = self:table()
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
	self:intersect(newHaters)
end

Haters:update(0.25)

function Haters:added(spawn)
	Core.print("haterFilter:added ", spawn.id, spawn:Name())
end

function Haters:removed(spawn)
	Core.print("haterFilter:removed ", spawn.id, spawn:Name())
end


----------------------- API
Haters.onChanged = onHatersChanged

return Haters
