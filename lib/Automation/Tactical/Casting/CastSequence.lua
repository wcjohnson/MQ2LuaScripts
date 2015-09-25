--
-- CastSequence.lua
-- (C) 2015 Bill Johnson
--
-- A tactics type that casts a sequence of spells on a target.
--
local Tactical = require("Automation.Tactical")
local Caster = require("Automation.Tactical.Casting.Caster")
local Util = require("Util")
local MQ2Cast = require("MQ2Cast")
local debug = require("Core").debug

local Tactics = Tactical.Tactics
local Cast = MQ2Cast.Cast


local CastSequence = Util.extend({}, Tactics)
CastSequence.__index = CastSequence

function CastSequence:new()
  local x = setmetatable({}, self)
  x.cast = Cast:new()
  return x
end

local originalNextTactic = Tactics.nextTactic
function CastSequence:nextTactic(...)
  -- Abort if target changed.
  if self.target and (not self.target:isMyTarget()) then
    debug(1, "CastSequence: target changed. stopping sequence.")
    return nil
  end
  return originalNextTactic(self, ...)
end

function CastSequence:didBegin()
  if self.target then
    debug(1, "CastSequence: targeting [", self.target:Name(), "]")
    self.target:target()
  end
end

function CastSequence:addSpell(spell, condition)
  self:addTactic(Caster.Spell:new(spell, condition))
end

function CastSequence:run(cb)
  return Caster:execute(self, cb)
end

function CastSequence:runWithTarget(targ, cb)
  self.target = targ
  debug(1, "CastSequence: running on ", targ:Name())
  return Caster:execute(self, cb)
end

-- Determine if the conditions for any spells in this sequence hold.
function CastSequence:check()
  for i=1,#self do
    if self[i]:condition() then return i end
  end
  return nil
end

return CastSequence
