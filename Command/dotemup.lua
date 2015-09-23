-- Dotemup macro
-- Cast all memorized DoTs on current target.
local Dotter = require("Automation.Dotter")
local Spawn = require("Data.Spawn")

local function csv(...)
	if select("#", ...) == 0 then return "(nothing)" end
	local ctbl = {}
	for i=1,select("#", ...) do
		ctbl[#ctbl + 1] = select(i, ...)
		ctbl[#ctbl + 1] = ", "
	end
	ctbl[#ctbl] = nil
	return table.concat(ctbl)
end

return function(cmd, rest)
	local dots = Dotter.memmedDoTs();
	print("dotemup: Dotting 'em up with: ", csv(table.unpack(dots)))
	Dotter:go(
		Spawn.forMyTarget(),
		dots,
		function(dotsCast) print("dotemup: I cast: ", csv(table.unpack(dotsCast))) end,
		function(...) print("dotemup failed: ", ...) end
	)
end
