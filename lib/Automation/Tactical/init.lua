--
-- Tactics.lua
-- (C)2015 Bill Johnson
--
-- Tactic and Tactics objects for use with the Tactician.
--


--
-- Tactics
-- Tactics is a list of Tactic objects, together with some metadata on how the
-- Tactician should process those objects.
--
local Tactics = {}
Tactics.__index = Tactics

function Tactics:new()
  return setmetatable({}, self)
end

function Tactics:addTactic(tactic)
  self[#self + 1] = tactic
end

function Tactics:clearTactics()
  for i=#self,1,-1 do self[i] = nil end
end

-- tactic, newState = Tactics:nextTactic(tactician, state, lastTactic, lastSuccess, lastResult))
--
-- Get the next tactic to try. You can use this to implement looping and
-- retry behavior of your choice. Tactician will always pass nil as the
-- state when no previous tactics has been tried.
--
-- The example implementation given here iterates once over the tactics list,
-- returning any tactic matching the condition.
function Tactics:nextTactic(tactician, state, lastTactic, lastSuccess, lastResult)
  local tactic

  -- Initial result.
  if not state then state = 0 end

  -- Retry last tactic?
  if lastTactic and (not lastSuccess) then
    if lastTactic:shouldRetry(lastResult) then
      return lastTactic, state
    end
  end

  -- Get the next tactic matching the condition.
  local i = state + 1
  while true do
    tactic = self[i]
    if not tactic then
      if self.loopTactics then
        i = 1; tactic = self[1]; if not tactic then return nil end
      else
        return nil
      end
    end
    if tactic:condition(self, tactician) then return tactic, i end
    i = i + 1
  end
end

-- Callback invoked by Tactician when beginning execution with these tactics.
function Tactics:didBegin()
end

------------------------------------------
-- Tactic
-- An individual tactic object describing a condition and an action to execute.
local Tactic = {}
Tactic.__index = Tactic

function Tactic:new()
  return setmetatable({}, self)
end

-- Condition to test when using this tactic
function Tactic:condition(tactician)
  return true
end

-- Retry condition for if this tactic fails.
function Tactic:shouldRetry(lastResult)
  return false
end

-- Exports
return {
  Tactics = Tactics,
  Tactic = Tactic
}
