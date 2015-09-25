-- Dotemup macro
-- Cast all memorized DoTs on current target.
local DotSequence = require("Automation.Tactical.Casting.DotSequence")
local Caster = require("Automation.Tactical.Casting.Caster")
local Spawn = require("Data.Spawn")
local debug = require("Core").debug

return function(cmd, rest)
	local ds = DotSequence:new()
	ds:addDots(DotSequence.memmedDots())
	if not
		ds:runWithTarget(Spawn.forMyTarget(), function(...)
			debug(1, ...)
		end)
	then
		debug(1, "couldnt Dotemup.")
		Caster:abort()
	end
end
