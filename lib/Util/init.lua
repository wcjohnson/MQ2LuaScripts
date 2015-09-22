local _G = _G;

local select = _G.select;
local type = _G.type;
local next = _G.next;
local tostring = _G.tostring;
local tconcat = _G.table.concat;
local setmetatable = _G.setmetatable;
local getmetatable = _G.getmetatable;
local error = error

local Util = {}

------------------------ Functionals.
function Util.noop() end
function Util.True() return true end
function Util.False() return false end
function Util.Nil() return nil end
function Util.identity(x) return x end
function Util.constant(k) return function() return k end end
function Util.iota(i0) local i = i0 or 0; return function() i = i + 1; return i end end
function Util.Error(str, lv) return function() error(str, lv or 2) end end


-- Call a function if it exists.
function Util.call(f, ...)
	if f then return f(...) end
end

-- Call a method on an object if it exists.
function Util.callMethod(self, index, ...)
	local fn = self[index]
	if fn then return fn(self, ...) end
end

-- Call a method on an object's metatable if it exists.
function Util.callMetaMethod(self, metaIndex, ...)
	local mt = getmetatable(self); if not mt then return end
	local fn = mt[metaIndex];
	if fn then return fn(self, ...) end
end

-- Get an element on an object's metatable if it exists.
function Util.getMeta(self, k)
	local mt = getmetatable(self); if not mt then return nil end
	return mt[k]
end

-- Set an element on an objects metatable if it exists.
function Util.setMeta(self, k, v)
	local mt = getmetatable(self); if not mt then return end
	mt[k] = v
end

-- Writes the array portion of all the sources into the target and returns the target.
-- If the target is nil, it will be created if one of the sources is nonempty.
function Util.concat_arrays(target, ...)
	-- Foreach source
	for i=1,select("#", ...) do
		local source = select(i, ...);
		if type(source) == "table" then
			-- Count the source
			local nsource = #source;
			-- If nonempty...
			if nsource > 0 then
				if not target then target = {}; end
				-- Write it into the target, at the end.
				for j=1,nsource do target[#target + 1] = source[j]; end
			end -- if nsource > 0
		end -- if type(source) == table
	end -- for i=1,select("#")

	return target;
end

-- Writes the nonarray portion of all the sources into the target and returns the target.
-- If the target is nil, it will be created if one of the sources is nonempty.
function Util.concat_hashes(target, ...)
	for i=1,select("#", ...) do
		local source = select(i, ...);
		if type(source) == "table" then
			for key, value in next, source do
				if type(key) ~= "number" then
					if not target then target = {}; end
					target[key] = value;
				end -- type(key) ~= number
			end -- for key,value
		end -- if type(source) == table
	end -- for i=1,select(#)

	return target;
end

-- Copy the entries of source into target without recursing into subarrays. Tables
-- in the source will be copied by reference into target and will not be duplicated.
function Util.shallow_copy(target, source)
	if type(source) == "table" then
		if not target then target = {}; end
		for key, value in next, source do
			target[key] = value;
		end
	end
	return target;
end
-- Util.extend is an alias for shallow_copy
Util.extend = Util.shallow_copy
Util.assign = Util.shallow_copy

-----
-- @function XF.Util.empty
-- Removes all entries from the given table.
-----
function Util.empty(T)
	for k in next,T do T[k] = nil; end
	return T;
end

-----
-- @function XF.Util.is_empty
-- Returns true iff the given table is empty.
-----
function Util.is_empty(T)
	if next(T) then return false; else return true; end
end

-----
-- @function XF.Util.deep_copy
-- Creates a deep copy of a table. All tables which are referentially reachable from the given table
-- including tables used as keys, tables used as values, and all recursions thereof, will be copied
-- exactly. Metatables are preserved, but the metatables themselves are not cloned.
-- @in any t Arbitrary Lua data.
-- @out any tc A deep copy of t if t was a table. t if t was a non-table primitive.
-----
local function copyWorker(x, copied)
	-- If x is not a table or we've copied it before, early out
	if type(x) ~= "table" then return x; elseif copied[x] then return copied[x];end
	-- x is a table we haven't copied before. Create it.
	local newTable = {}; copied[x] = newTable;
	-- Copy each of the key/value pairs into the new table
	for k,v in next,x do newTable[copyWorker(k, copied)] = copyWorker(v, copied); end
	-- Copy the metatable
	return setmetatable(newTable, getmetatable(x));
end

function Util.deep_copy(t)
	return copyWorker(t, {});
end


-----
-- @function XF.Util.pack
-- @descr Given a table and a series of arguments, loads the arguments into the array
-- portion of the table. DOES NOT attempt to clear the table first. Essentially,
-- this function is the "inverse" function of Lua's _G.unpack. As unpack() converts
-- an array to a ..., pack() converts a ... to an array.
-- @in array A The destination array to be packed into.
-- @in any ... The values to be saved into A, in sequence.
-- @return array A
-----
function Util.pack(A, ...)
	for i=1,select("#",...) do A[i] = select(i,...); end
	return A;
end

-----
-- @function XF.Util.strcat
-- @descr Convert all arguments to strings and then concatenate.
-- @in any ... A sequence of strings to be concatenated.
-- @return string The ordered concatenation of all strings in ...
-----
function Util.strcat(...)
	local n = select("#", ...)
	if n>1 then
		local cattbl = {}
		for i=1,select("#",...) do cattbl[i] = tostring(select(i,...)); end
		return tconcat(cattbl)
	elseif n == 1 then
		return tostring(...);
	else
		return ""
	end
end

-----
-- @function XF.Util.filter_array
-- @descr Given a destination array, source array, and filter function f, invokes f(x) on each
-- element of the source array, writing only those elements for which f(x) was true into the
-- destination. The destination may be the same as the source, or nil, in which case
-- the source array is modified in place.
--
-- This operation adds elements to the destination table and may therefore be unsafe for use
-- during an iteration of the destination table.
-----
function Util.filter_array(dst, src, filter)
	if type(dst) ~= "table" then dst = src; end
	local src_elt, cursor = nil, 0;
	-- Pack the matching elements of src into the early portion of dst
	for i=1,#src do
		src_elt = src[i];
		if filter(src_elt) then cursor = cursor + 1; dst[cursor] = src_elt; end
	end
	-- Destroy everything to the "right" of the cursor.
	for i=(cursor + 1),#dst do dst[i] = nil; end

	return dst;
end

function Util.remove_element(a, what)
	return Util.filter_array(a, a, function(x) return (x ~= what) end)
end

-----
-- @function XF.Util.filter_table
-- @descr Given a destination table, source table, and filter function f, invokes f(k,v) on
-- each pair of the source table, writing only those pairs for which f(k,v) was true into
-- the destination. If f(k,v) was false, the k-entry is removed from the destination.
--
-- Other than as described, the destination table IS NOT emptied by this function, so you must
-- provide an empty destination table if you wish that behavior.
--
-- The destination may be the same as the source, or nil, in which case the table is modified
-- in place.
--
-- This operation adds elements to the destination table and may therefore be unsafe for use
-- during an iteration of the destination table.
-----
function Util.filter_table(dst, src, filter)
	if type(dst) ~= "table" then dst = src; end
	for k,v in next,src do
		if filter(k,v) then dst[k] = v; else dst[k] = nil; end
	end
	return dst;
end

-----
-- @function XF.Util.filtered_pairs
-- @descr Given a table T and a filter function f, returns a Lua iterator triple which will
-- iterate over those elements of T for which f(k,v) returns true. All normal rules for Lua
-- iterators apply to the returned iterator.
-----

-----
-- @function Util.quote
-- @descr Given a Lua table, returns a quoted version that can be load()ed to restore the original.
-- All keys must be numeric or string. Does not serialize functions.
-----
local function quote_recursive(datum, acc)
	if datum == nil then return end
	local td = type(datum)
	if td == "string" then
		acc[#acc + 1] = ("%q"):format(datum)
	elseif td == "number" then
		acc[#acc + 1] = tostring(datum)
	elseif td == "boolean" then
		acc[#acc + 1] = datum and "true" or "false"
	elseif td == "table" then
		acc[#acc + 1] = "{\n"
		for k,v in pairs(datum) do
			td = type(k)
			if td == "string" then
				acc[#acc + 1] = "["; acc[#acc + 1] = ("%q"):format(k); acc[#acc + 1] = "] = "
			elseif td == "number" then
				acc[#acc + 1] = "["; acc[#acc + 1] = tostring(k); acc[#acc + 1] = "] = "
			else
				error("cannot quote table with non-primitive keys");
			end
			quote_recursive(v, acc)
			acc[#acc + 1] = ",\n"
		end
		acc[#acc + 1] = "}\n"
	else
		error("cannot quote datum of type " .. td);
	end
end

function Util.quote(x)
	acc = {}; quote_recursive(x, acc)
	return table.concat(acc)
end



return Util
