local _G = _G
local next = _G.next
local type = _G.type
local error = _G.error

local Tagset = require("Util.Tagset")
local add = Tagset.tagset_add
local remove = Tagset.tagset_remove

local Signal = {}
Signal.__index = Signal

function Signal:new()
	return setmetatable({ {} }, Signal)
end

function Signal:raise(...)
	for _,f in next,self[1] do f(...) end
end

function Signal:connect(...)
	local key, fn, n = nil, nil, select("#", ...)
	if n < 1 or n > 2 then
		error("Invalid number of arguments to Signal:connect")
	end
	if n == 1 then
		key = {}; fn = select(1, ...)
	else
		key = select(1, ...)
		if type(key) ~= "table" then
			error("Signal:connect - provided key must be a table.")
		end
		fn = select(2, ...)
	end
	if type(fn) ~= "function" then
		error("Signal:connect - first argument must be a function") 
	end
	add(self[1], key, fn)
	return key
end

function Signal:disconnect(key)
	return remove(self[1], key)
end

function Signal:meta(onEmpty, onNonEmpty)
	return Tagset.tagset_set_monitor(self[1], onEmpty, onNonEmpty, self)
end

return Signal
