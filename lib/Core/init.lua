local _G = _G
local Util = require("Util")
local Signal = require("Util.Signal")
local Task = require("Util.Task")
local Deferred = require("Util.Deferred")

local next = next
local pcall = pcall
local strcat = Util.strcat

-- Expose MQ2 and Core globally
local MQ2 = require("MQ2")
_G.MQ2 = MQ2
local Core = {}
_G.Core = Core
-- Expose data and exec thru Core.
Core.data = MQ2.data
Core.xdata = MQ2.xdata
Core.exec = MQ2.exec

----------------------------------------------------------- BASIC IO
local _print = MQ2.print
function Core.print(...) return _print(strcat(...)) end
function Core.log(...) return _print(strcat(...)) end
function Core.error(...) return _print(strcat(...)) end
_G.print = Core.print

local debugVerbosity = 10
function Core.debug(level, ...)
	if level > debugVerbosity then return end
	return _print(strcat("[Debug ", level, "] ", ...))
end
function Core.setDebugVerbosity(dv) debugVerbosity = dv end
local debug = Core.debug

--------------------------------------------------------- CONNECT TO MQ2 EVENTS
-- Pulse handler. XXX: cheating here and peering into the internal structure
-- of the Signal for a little performance boost.
local pulse = Signal:new()
local pulsars = pulse[1]
MQ2.pulse(function() for _,fn in next,pulsars do fn() end end)
Core.pulse = pulse
-- Initialize taskmaster
pulse:connect( Task.taskmaster(MQ2.clock) )
pulse:connect( Deferred.loop )

---- Event handlers
-- This is all events MQ2Lua knows about.
local evtList = {
	"command", "shutdown", "enteredWorld", "leftWorld", "gameStateChanged",
	"zoned", "enteredZone", "leftZone",
	"onAddSpawn", "onRemoveSpawn", "onAddGroundItem", "onRemoveGroundItem",
	"cleanUI", "reloadUI"
}

local events = {}
MQ2.events(events)

for i=1,#evtList do
	local ename = evtList[i]
	local esig = Signal:new()
	Core[ename] = esig
	events[ename] = function(...)
		--debug(10, "Core.events.", ename, ": ", ...)
		return esig:raise(...)
	end
end

--------------------------------------------------------- COMMANDS
-- Command registry
local commandRegistry = {}
Core.command:connect( function(name, rest)
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

-- /lua eval command
Core.registerCommand("eval", function(cmd, rest)
	fn, err = load(rest)
	if fn then return fn() else return error(err) end
end)

--------------------------------------------------------------- SCRIPT LOADER
function Core.runscript(filename, silent)
	local ok, rst = pcall(MQ2.load, filename)
	if ok and rst then
		ok, rst = pcall(rst)
		if not ok then
			Core.error("Error evaluating ", filename, ": ", rst)
		end
	else
		debug(2, "Core.loadscript: ", rst)
		if not silent then
			Core.error( rst )
		end
	end
end

Core.enteredWorld:connect( function()
	-- Load the character's init.lua profile.
	charName = MQ2.data("Me.CleanName")
	serverName = MQ2.data("MacroQuest.Server")
	initName = ("init_%s_%s.lua"):format(charName, serverName)
	Core.print("Loading init script: ", initName);
	return Core.runscript(initName, true)
end)

Core.print("[MQ2Lua] ==================== Core loaded");
return Core
