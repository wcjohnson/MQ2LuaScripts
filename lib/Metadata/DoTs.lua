--
-- DoTs.lua
--
-- Someday this will be a list of all the DoTs.
--


-- Table format: Stripped DoT name (no rank suffix) = DoT value.
-- Value is a somewhat arbitrary number that sort of represents the DoTs DPS.
-- Some casting routines might use that for prioritization.
local dots = {
  ["Ignite Energy"] = { value = 700 },
  ["Pyre of the Bereft"] = { value = 800 },
  ["Reaver's Pyre"] = { value = 900 },
  ["Arachne's Pallid Haze"] = { value = 1000 },
  ["Demise"] = { value = 2000 },
  ["Soul Reaper's Pyre"] = { value = 3000 },
  ["Thoughtburn"] = { value = 4000 },
  ["Pyre of Nos"] = { value = 5000 },
  ["Rilfed's Swift Sickness"] = { value = 6000, fast = true },
  ["Tenak's Flashblaze"] = { value = 7000, fast = true },
  ["Ninavero's Swift Deconstruction"] = { value = 8000, fast = true},
  ["Burlabis' Swift Venom"] = { value = 9000, fast = true }
}


return dots
