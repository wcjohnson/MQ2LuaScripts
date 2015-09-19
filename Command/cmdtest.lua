local Core = require("Core")

Core.print("Cmdtest loaded")

Core.registerCommand("cmdtest", function()
	Core.print("Cmdtest running")
end)
