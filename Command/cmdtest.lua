local Core = require("Core")

Core.print("Cmdtest loaded")

return function(cmd, rest)
	Core.print("TEST: ", cmd, " ", rest)
end

