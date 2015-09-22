local MQ2 = require("MQ2")
local Core = require("Core")

local xdata = MQ2.xdata
local print = Core.print

local Target = {}

------------------- XTarget stuff
local function getXTargetInfo(i)
	local id = xdata( "Me", nil, "XTarget", i, "ID" )
	if (not id) or (id == 0) then return nil end
	return
		id,
		xdata( "Me", nil, "XTarget", i, "TargetType" ),
		xdata( "Me", nil, "XTarget", i, "Type" ),
		xdata( "Me", nil, "XTarget", i, "CleanName" ),
		xdata( "Me", nil, "XTarget", i, "PctHPs" ),
		xdata( "Me", nil, "XTarget", i, "PctAggro" )
end
Target.getXTargetInfo = getXTargetInfo


return Target
