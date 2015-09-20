--
-- noop.lua
--
-- Global no-op function.
-- The idea is that require("noop") will always give the same function
-- pointer, so you can compare for equality with this to see if
-- a function is a no-op, assuming everyone is in compliance.
--
-- Don't RELY on this being true, but it might help optimize some
-- things.
--
local function noop() end
return noop
