-- Posture macro
-- If feigned, get up. If in combat, feign. Otherwise, sit.
local Core = require("Core")
local data = Core.data
local exec = Core.exec

return function(cmd, rest)
	-- If moving, do nothing
	if data("Me.Moving") then
		return Core.print("can't change posture while moving")
	end
	-- If feigning, stand.
	if data("Me.Feigning") then return exec("/stand") end
	-- If in combat, feign.
	if data("Me.CombatState") == "COMBAT" then
		return exec([[/casting "Death Peace"]])
	end
	-- If sitting, stand; if standing, sit.
	if data("Me.Sitting") then return exec("/stand") end
	if data("Me.Standing") then return exec("/sit") end
end


