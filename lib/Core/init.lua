local _G = _G
local Signal = require("Util.Signal")

-- Expose macroquest api as a global.
local MQ2 = require("MQ2")
_G.MQ2 = MQ2

local Core = {}

-- basic event handlers
local pulse = Signal:new()
MQ2.event("pulse", function() pulse:raise() end)
Core.pulse = pulse

local shutdown = Signal:new()
function Core._shutdown()
	MQ2.print("Core.shutdownHandler()");
	return shutdown:raise()
end
Core.shutdown = shutdown

local enteredWorld = Signal:new()
function Core._enteredWorld()
	MQ2.log("Core._enteredWorld()");
	-- Load the character's init.lua profile.
	charName = MQ2.data("Me.CleanName")
	serverName = MQ2.data("MacroQuest.Server")
	initName = ("init_%s_%s.lua"):format(charName, serverName)
	MQ2.log("Loading init script ", initName);
	local ok, initFunc = pcall(MQ2.load, initName)
	if ok and initFunc then
		local ok, err = pcall(initFunc)
		if not ok then
			MQ2.log("Error while running ", initName, ": ", err)
		end
	else
		MQ2.log("Couldnt load ", initName, ": ", initFunc)
	end
	return enteredWorld:raise()
end
Core.enteredWorld = enteredWorld

local leftWorld = Signal:new()
function Core._leftWorld()
	MQ2.log("Core._leftWorld()");
	return leftWorld:raise()
end
Core.leftWorld = leftWorld

function Core._gameStateChanged()
	MQ2.log("Core._gameStateChanged(", MQ2.gamestate(), ")");
end

function Core._zoned()
	MQ2.log("Core._zoned()")
end

local leftZone = Signal:new()
function Core._leftZone()
	MQ2.log("Core._leftZone()")
	return leftZone:raise()
end
Core.leftZone = leftZone

function Core._enteredZone()
	MQ2.log("Core._enteredZone()")
end

local function concat(...)
	local tbl = {}
	for i=1,select("#",...) do
		tbl[i] = tostring(select(i,...))
	end
	return table.concat(tbl)
end

function Core.print(...)
	MQ2.print(concat(...))
end
function Core.log(...)
	MQ2.log(concat(...))
end


MQ2.print("Core loaded");
return Core
