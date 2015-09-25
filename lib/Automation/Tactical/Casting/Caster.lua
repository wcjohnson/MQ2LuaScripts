--
-- Tactical.Caster.lua
-- (C)2015 Bill Johnson
--
-- Uses the Tactics system to cast spells, abilities, and items.
--
local Tactical = require("Automation.Tactical")
local Tactician = require("Automation.Tactical.Tactician")
local MQ2Cast = require("MQ2Cast")
local Core = require("Core")
local Util = require("Util")

local debug = Core.debug
local clock = MQ2.clock
local Tactic = Tactical.Tactic

------------------------------ Caster - the tactician that runs casts.
local Caster = Tactician:new()

function Caster:didTransitionTo_willExecute()
  local tactic = self.tactic
  local cast = self.tactics.cast
  cast:setAbility(tactic.spell)
  self:nextState("execute")
end

-- Execute casting task.
function Caster:executeTactic(tactic)
  local cast = self.tactics.cast
  function cast:succeeded() return Caster:tacticDidExecute(tactic, true) end
  function cast:failed(reason)
    return Caster:tacticDidExecute(tactic, false, reason)
  end
  -- Cast abilit was already set in willExecute
  debug(1, "Caster: casting [", tactic.spell, "]...")
  return cast:execute()
end

-- Abort casting
function Caster:didTransitionTo_abort()
  debug(1, "Caster: aborting cast")
  self.tactics.cast:interrupt()
end

-- Start caster task
Caster:run()

--------------------------- Spell: the thing the Caster casts
local Spell = Util.extend({}, Tactic)
Spell.__index = Spell

function Spell:new(spell, condition)
  local x = Tactic:new()
  x.spell = spell; x.condition = condition or Util.True
  return x
end

Caster.Spell = Spell

return Caster
