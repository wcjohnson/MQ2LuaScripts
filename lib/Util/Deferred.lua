--
-- Deferred.lua
-- (C)2015 Bill Johnson
--
-- Defer functions until next tick after stack unwinds.
--
local next = next

----------------- IMPLEMENTATION
local deferreds = {}
local deferred_once = {}
local deferred_xq = {}
local function loop()
  -- Move deferreds onto execution queue
  for i=#deferreds,1,-1 do
    deferred_xq[#deferred_xq + 1] = deferreds[i]; deferreds[i] = nil
    --deferreds[i](); deferreds[i] = nil
  end
  for k in next,deferred_once do
    deferred_xq[#deferred_xq + 1] = k; deferred_once[k] = nil
    --k(); deferred_once[k] = nil
  end
  -- Run execution queue.
  for i=#deferred_xq,1,-1 do deferred_xq[i](); deferred_xq[i] = nil end
end

------------------ API
-- Defer execution of f until (at least) the current stack unwinds.
local function defer(f)
  deferreds[#deferreds + 1] =f
end
-- Defer execution of f if it isn't already scheduled for executions.
local function defer_once(f)
  deferred_once[f] = true
end
-- Return a version of f that will only run its body once per mainloop
-- regardless of how many times it is invoked.
local function debounce(f)
  return function() defer_once(f) end
end

return {
  defer = defer,
  defer_once = defer_once,
  debounce = debounce,
  loop = loop
}
