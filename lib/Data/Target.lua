local MQ2 = require("MQ2")
local data = MQ2.data
local Core = require("Core")
local print = Core.print

local Target = {}

------------------- XTarget stuff

-- Pregenerate the data strings to make this a little more efficient.
-- This is actually totally insane and we should be working around 
-- the braindead mq2data system. Maybe someday.
local xt_ty_field = {}
local xt_id_field = {}
local xt_tt_field = {}
local xt_name_field = {}
local xt_aggro_field = {}
local xt_hp_field = {}

for i=1,13 do
	xt_id_field[i] = ("Me.XTarget[%d].ID"):format(i)
	xt_ty_field[i] = ("Me.XTarget[%d].Type"):format(i)
	xt_tt_field[i] = ("Me.XTarget[%d].TargetType"):format(i)
	xt_name_field[i] = ("Me.XTarget[%d].Name"):format(i)
	xt_aggro_field[i] = ("Me.XTarget[%d].PctAggro"):format(i)
	xt_hp_field[i] = ("Me.XTarget[%d].PctHPs"):format(i)
end

local function getXTargetInfo(i)
	local id = data( xt_id_field[i] )
	if (not id) or (id == 0) then return nil end
	return 
		id,
		data( xt_tt_field[i] ),
		data( xt_ty_field[i] ),
		data( xt_name_field[i] ),
		data( xt_hp_field[i] ),
		data( xt_aggro_field[i] )
end
Target.getXTInfo = getXTargetInfo

function Target.dumpXTargets()
	print("----------")
	for i=1,13 do
		print(getXTargetInfo(i))
	end
	print("-----------")
end



return Target
