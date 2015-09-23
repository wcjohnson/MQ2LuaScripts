local MQ2 = require("MQ2")
local data = MQ2.data
local exec = MQ2.exec
local xdata = MQ2.xdata

local Player = {}

-- Basic stats
function Player.pctHealth() return data("Me.PctHPs") end
function Player.pctMana() return data("Me.PctMana") end
function Player.outOfCombat()
	local cs = data("Me.CombatState")
	if cs == "ACTIVE" or cs == "RESTING" then return true else return false end
end

-- Buffs
function Player.hasLongBuff(name) return data( ("Me.Buff[%s]"):format(name) ) end
function Player.hasShortBuff(name) return data( ("Me.Song[%s]"):format(name) ) end
function Player.removeBuff(name) return exec( ("/removebuff %s"):format(name) ) end

-- Common checks
function Player.castingPosture()
	return (not data("Me.Moving")) and data("Me.Standing") and (not data("Me.Invis"))
end
Player.buffPosture = Player.castingPosture -- Old name



-- "Idle zones" - zones where automated action should be suppressed
local idleZone = {}
function Player.setIdleZoneIDs(zidArray)
	idleZone = {}
	for i=1,#zidArray do
		idleZone[zidArray[i]] = true
	end
end

-- Default list of idle zones.
-- Override in your personal init.lua
Player.setIdleZoneIDs({ 151,202,203,219,344,345,463,33480,33113 })

function Player.isZoneIdle(zid)
	return idleZone[zid or ""]
end

function Player.isInIdleZone()
	return idleZone[data("Zone.ID") or ""]
end

return Player
