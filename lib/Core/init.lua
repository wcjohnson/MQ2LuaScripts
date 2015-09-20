local _G = _G
local next = _G.next
local Util = require("Util")
local strcat = Util.strcat
local Signal = require("Util.Signal")
local Task = require("Util.Task")

-- Expose MQ2 and Core globally
local MQ2 = require("MQ2")
_G.MQ2 = MQ2
local Core = {}
_G.Core = Core
-- Expose data and exec thru Core.
Core.data = MQ2.data
Core.exec = MQ2.exec

----------------------------------------------------------- BASIC IO
local _print = MQ2.print
function Core.print(...) return _print(strcat(...)) end
function Core.log(...) return _print(strcat(...)) end
function Core.error(...) return _print(strcat(...)) end

local debugVerbosity = 0
function Core.debug(level, ...)
	if level > debugVerbosity then return end
	return _print(strcat(...))
end
function Core.setDebugVerbosity(dv) debugVerbosity = dv end

--------------------------------------------------------- CONNECT TO MQ2 EVENTS
-- Pulse handler. XXX: cheating here and peering into the internal structure
-- of the Signal for a little performance boost.
local pulse = Signal:new()
local pulsars = pulse[1]
MQ2.pulse(function() for _,fn in next,pulsars do fn() end end)
Core.pulse = pulse
-- Initialize taskmaster
pulse:connect( Task.taskmaster(MQ2.clock) )

-- Event handlers
local events = {}
MQ2.events(events)

--------------------------------------------------------- COMMANDS
local command = Signal:new()
Core.command = command
function events.command(name, rest)
	Core.print("Core.onCommand(", name, ", '", rest ,"')")
	return command:raise(name, rest)
end

-- Command registry
local commandRegistry = {}
command:connect( function(name, rest)
	local handler = commandRegistry[name];
	if not handler then
		local ok, rst = pcall( require, ("Command.%s"):format(name) )
		if not ok then
			Core.print("couldn't dynamically load command ", tostring(name), ": ", tostring(rst))
			return
		else
			handler = rst; commandRegistry[name] = rst
		end
	end
	if not handler then return end
	return handler(name, rest)
end )

function Core.registerCommand(cmd, handler) commandRegistry[cmd] = handler end

-- Basic commands
Core.registerCommand("eval", function(cmd, rest)
	fn, err = load(rest)
	if fn then return fn() else return error(err) end
end)

--------------------------------------------------------------- OTHER EVENTS
local shutdown = Signal:new()
function events.shutdown()
	Core.log("events.shutdown()");
	return shutdown:raise()
end
Core.shutdown = shutdown

local enteredWorld = Signal:new()
function events.enteredWorld()
	Core.log("events.enteredWorld()");
	-- Load the character's init.lua profile.
	charName = MQ2.data("Me.CleanName")
	serverName = MQ2.data("MacroQuest.Server")
	initName = ("init_%s_%s.lua"):format(charName, serverName)
	Core.print("Loading init script: ", initName);
	local ok, initFunc = pcall(MQ2.load, initName)
	if ok and initFunc then
		local ok, err = pcall(initFunc)
		if not ok then
			Core.error("Error while running ", initName, ": ", err)
		end
	else
		Core.log("Couldnt load ", initName, ": ", initFunc)
	end
	return enteredWorld:raise()
end
Core.enteredWorld = enteredWorld

local leftWorld = Signal:new()
function events.leftWorld()
	Core.log("Core.leftWorld()");
	return leftWorld:raise()
end
Core.leftWorld = leftWorld

function events.gameStateChanged()
	Core.log("Core.gameStateChanged(", MQ2.gamestate(), ")");
end

function events.zoned()
	Core.log("Core.zoned()")
end

local leftZone = Signal:new()
function events.leftZone()
	Core.log("Core.leftZone()")
	return leftZone:raise()
end
Core.leftZone = leftZone

function events.enteredZone()
	Core.log("Core.enteredZone()")
end


Core.print("Core loaded");
return Core
