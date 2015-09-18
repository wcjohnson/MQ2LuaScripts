--
-- Haters.lua
-- (C)2015 Bill Johnson
--
-- Uses XTarget to keep track of haters.
--
local MQ2 = require("MQ2")
local data = MQ2.data

local Task = require("Core.Task")
local Target = require("Data.Target")
local getXTInfo = Target.getXTInfo
local Spawn = require("Data.Spawn")
local Signal = require("Util.Signal")

----------------- Hater monitor.
local haters = {}
local nhaters = 0
local onHatersChanged = Signal:new()

local h8rade = Task:new()
h8rade:loop(0.5)

function h8rade:main()
	local id, ty, tt, name, aggro, hp
	local hater
	local changed = false

	-- Mark all haters
	for k,v in pairs(haters) do
		v._hater_visited = false
	end
	nhaters = 0

	-- Pull hate data from xtargets
	for i=1,13 do
		id, tt, ty, name, hp, aggro = getXTInfo(i)
		if id and (tt == "Auto Hater") and (ty == "NPC") then
			hater = haters[id]
			if not hater then
				-- Hater wasn't on the list; add it.
				hater = Spawn:forID(id)
				haters[id] = hater
				changed = true
			end
			-- Update hater info
			hater._hater_visited = true
			hater.name = name
			hater.aggro = aggro
			hater.hp = hp
			nhaters = nhaters + 1
		end
	end

	-- Remove any non-visited haters
	for k,v in pairs(haters) do
		if not v._hater_visited then
			haters[k] = nil
			changed = true
		end
	end

	-- If our haters changed let listeners know.
	if changed then onHatersChanged:raise() end
end

h8rade:run()

----------------------- API
local Haters = {}

Haters.onHatersChanged = onHatersChanged

-- Pack haters into an array.
function Haters.packInto(array)
	local oldsz, i = #array, 1
	for k,v in pairs(haters) do
		array[i] = v
		i = i + 1
	end
	for j=i,oldsz do
		array[j] = nil
	end
	return array
end

-- Check if the given spawn is a hater
function Haters.byID(id)
	return haters[id or 0]
end

function Haters.getNHaters()
	return nhaters
end


return Haters
