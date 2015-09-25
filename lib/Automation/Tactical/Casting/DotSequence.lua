--
-- DotSequence.lua
-- (C) 2015 Bill Johnson
--
-- Sequence of DoT spells. Checks to see if DoT is up before casting.
--

local CastSequence = require("Automation.Tactical.Casting.CastSequence")
local Caster = require("Automation.Tactical.Casting.Caster")
local Util = require("Util")
local Target = require("Data.Target")
local Spell = require("Data.Spell")
local AllDoTs = require("Metadata.DoTs")

local DotSequence = Util.extend({}, CastSequence)
DotSequence.__index = DotSequence

local function dotCondition(tactic, ...)
  if Target.hasMyBuff(tactic.spell) then return false end
  if tactic.extraCondition then return tactic:extraCondition(...) end
  return true
end

function DotSequence:addDot(dot, condition)
  local x = Caster.Spell:new(dot, dotCondition)
  x.isDot = true
  x.extraCondition = condition
  return self:addTactic(x)
end

-- Check if any of the dots in this sequence could be cast on the target.
function DotSequence:checkDots(targ)
  if targ then self.target = targ; targ:target() end
  for i=1,#self do
    if self[i].isDot and self[i]:condition() then return i end
  end
  return nil
end

local function memmedDots()
  local dots = {}
  for i=1,Spell.numGems() do
    local id, name, strippedName = Spell.getSpellInfoForGem(i)
		if id then strippedName = Spell.split(name) end -- strip rank
    if name and AllDoTs[strippedName] then
			dots[#dots + 1] = name
		end
  end
  return dots
end

DotSequence.memmedDots = memmedDots

function DotSequence:addDots(list)
  for i=1,#list do self:addDot(list[i]) end
end

return DotSequence
