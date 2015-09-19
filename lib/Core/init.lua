local _G = _G
local next = _G.next
local Util = require("Util")
local strcat = Util.strcat
local Signal = require("Util.Signal")
local Task = require("Util.Task")

local MQ2 = require("MQ2")
_G.MQ2 = MQ2
local Core = {}
_G.Core = Core

----------------------------------------------------------- BASIC IO
local _print = MQ2.print
function Core.print(...) return _print(strcat(...)) end
function Core.log(...) return _print(strcat(...)) end

local debugVerbosity = 0
function Core.debug(level, ...)
	if level > debugVerbosity then return end
	return _print(strcat(...))
end
function Core.setDebugVerbosity(dv) debugVerbosity = dv end

----------------------------------------------------------- PULSES
-- Pulse handler. XXX: cheating here and peering into the internal structure
-- of the Signal for a little performance boost.
local pulse = Signal:new()
local pulsars = pulse[1]
MQ2.event("pulse", function()
	for _,fn in next,pulsars do fn() end
end)
Core.pulse = pulse

-- Initialize taskmaster
pulse:connect( Task.taskmaster(MQ2.clock) )

--------------------------------------------------------- COMMANDS
local command = Signal:new()
Core.command = command
function Core.onCommand(name, rest)
	MQ2.print("Core.onCommand(", name, ", '", rest ,"')")
	return command:raise(name, rest)
end

-- Command registry
local commandRegistry = {}
command:connect( function(name, rest)
	local handler = commandRegistry[name];
	if not handler then
		local ok, msg = pcall( function() require( ("Command.%s"):format(name) ) end )
		if not ok then
			MQ2.print("couldn't dynamically load command ", tostring(name), ": ", tostring(msg))
			return
		end
		handler = commandRegistry[name];
	end
	if not handler then return end
	handler(name, rest)
end )

function Core.registerCommand(cmd, handler)
	commandRegistry[cmd] = handler
end

-- Basic commands
Core.registerCommand("eval", function(cmd, rest)
	fn, err = load(rest, "console")
	if fn then return fn() else error(err) end
end)

--------------------------------------------------------------- OTHER EVENTS
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


MQ2.print("Core loaded");
return Core
