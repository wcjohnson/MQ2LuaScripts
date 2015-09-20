local Tests = {}
_G.Tests = Tests

local MQ2 = require("MQ2")
local Core = require("Core")
local Scheduler = require("Core.Scheduler")
local Task = require("Core.Task")
local Util = require("Util")
local MQ2Caster = require("MQ2Caster")
local Spell = require("Data.Spell")
local Player = require("Data.Player")
local Trigger = require("Trigger")

function Tests.scheduler()
	Scheduler.Schedule(1, function() MQ2.print("hi") end)
end

function Tests.task()
	local t = Task:new()
	MQ2.print("Launching Task ", tostring(t))

	function t:main()
		MQ2.print("this")
		self:wait(2)
		MQ2.print("is")
		self:wait(2)
		MQ2.print("sparta")
		self:stop()
	end

	t:run()
end

function Tests.runloop()
	local t = Task:new()
	t:loop(1)
	function t:main()
		MQ2.print(MQ2.clock(), " la la la")
	end
	function t:handleEvent(ev)
		MQ2.print("event ", ev)
	end

	Scheduler.Schedule(5, function() t:event("SURPRISE BITCH") end)
	Scheduler.Schedule(10, function() t:stop() end)

	t:run()
end

function Tests.cast()
	MQ2Caster.TestCast("Hulking Bodyguard")
end

function Tests.config()
	MQ2.saveconfig("test", "return " .. Util.quote({1,2,3}))

	f = MQ2.loadconfig("test")
	testConfig = f()
	MQ2.print("Loaded: ", Util.quote(testConfig))
end

function Tests.splitspell(sp)
	local a,b,c,d = SpellUtil.split(sp)
	MQ2.print(tostring(a), "|", tostring(b), "|", tostring(c), "|", tostring(d))
	MQ2.print(tostring(SpellUtil.getRanked(a)))
end

return Tests
