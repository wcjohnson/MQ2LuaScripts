--
-- Hooker.lua
-- (C)2015 Bill Johnson
--
-- A utility for creating Lua hookchains.
--
local type = _G.type
local tinsert = _G.table.insert
local tremove = _G.table.remove
local setmetatable = _G.setmetatable
local global_noop = require("noop")

local hooker_metatable = {
	__call = function(self, ...)
		for i=1,#self do self[i](...) end
	end
}

local function hooker_append(first, second)
	if type(second) == "table" then
		for i=1,#second do
			first[#first + 1] = second[i]
		end
	else
		first[#first + 1] = second
	end
	return first
end

local function hooker_prepend(first, second)
	tinsert(second, 1, first)
	return second
end

local function hooker_pair(first, second)
	return setmetatable({first, second}, hooker_metatable)
end

local function unhook_remove(haystack, i)
	tremove(haystack, i)
	if #haystack == 1 then return haystack[1] else return haystack end
end

-- Usage: func = hook(first, second)
-- Func will call first, then second.
local function hook(first, second)
	-- If both args aren't provided, we're not doing anything.
	if (not first) or (first == global_noop) then
		return second
	elseif (not second) or (second == global_noop) then
		return first
	end
	-- If first arg is a hooker...
	if type(first) == "table" then
		return hooker_append(first, second)
	elseif type(second) == "table" then
		return hooker_prepend(first, second)
	else
		return hooker_pair(first, second)
	end
end

-- usage: func = unhook(func, functionPreviouslyHooked)
local function unhook(haystack, needle)
	-- Haystack is pure function
	if type(haystack) ~= "table" then
		if haystack == needle then return global_noop else return haystack end
	end
	-- Haystack is a length-1 hookchain... (shouldnt happen)
	if #haystack == 1 then
		if haystack[1] == needle then return global_noop else return haystack[1] end
	end
	-- Find needle in haystack
	for i=1,#haystack do
		if haystack[i] == needle then return unhook_remove(haystack, i) end
	end
	-- No-op.
	return haystack
end

return {
	hook = hook,
	unhook = unhook
}
