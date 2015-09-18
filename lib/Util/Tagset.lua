--------------------------------------
-- XF - eXtensible Framework
-- (C) 2010 Bill Johnson (Venificus of Eredar server)
--
-- Implementation of the event paradigm for XF. There are two key concepts at work in XF's event
-- subsystem: tags and tagsets. Both tags and tagsets are internally represented by Lua tables, but
-- for most purposes they should be regarded as opaque handles to be passed to the functions of this
-- library.
--
-- Tags represent individual opaque objects; tagsets are simply sets of tags. (In reality a tag is
-- actually the set of tagsets it belongs to, but this is an implementation detail that should not
-- be relied upon.) The EventKernel API is carefully designed so that referential integrity between
-- tags and tagsets is always guaranteed. That is, deleting a tag deletes it from all tagsets
-- automatically; deleting a tagset removes all tags from it; and so forth.
--
-- Using these paradigms, one can create an event system as follows: tags represent unique per-event
-- bindings; that is, for each tag and each event, that tag represents zero or one bindings from
-- that event to some handler function.
--
-- Meanwhile, each event is represented by a tagset consisting of (tag, func) pairs; one for each
-- tag bound to that event. So executing the event is literally as simple as: foreach (tag,func) in
-- event do func(); end. This is essentially as fast as it is possible for a multiple-dispatch event
-- system to get in Lua.
---------------------------------------
local _G = _G;

local next = _G.next;
local type = _G.type;
local getmetatable = _G.getmetatable;
local setmetatable = _G.setmetatable;
local select = _G.select;
local unpack = _G.unpack;

local Util = require("Util");
local noop = Util.noop;

local EventKernel = {}

--------------------------------------------
-- Kernel functions
--------------------------------------------
-----
-- @function XF.Event.tagset_run
-- Given a tagset whose values are functions (typically, an event hookchain), execute
-- all of those functions in arbitrary order with the given arguments.
-----
local function tagset_run(tagset, ...)
	for _,f in next,tagset do f(...); end
end
EventKernel.tagset_run = tagset_run;


-- Internal: for a tagset with a metatable, perform the metatable operations appropriate
-- to removing something from the tagset.
local function _tagset_meta_remove(tagset, mt)
	-- Decrement the bind counter. If we decremented to 0, invoke the onempty handler
	local rc = mt[1]; mt[1] = rc - 1;
	if rc == 1 then return (mt[2] or noop)(unpack(mt, 4)); end
end
local function _tagset_meta_add(tagset, mt)
	-- Increment the bind counter. If it went from 0 to 1, invoke the nonempty handler.
	local rc = mt[1]; if not rc then rc = 0; end 
	mt[1] = rc + 1;
	if rc == 0 then return (mt[3] or noop)(unpack(mt, 4)); end
end
local function _tagset_meta_clear(tagset, mt)
	-- Zero the bind counter. If we decremented to 0, invoke the onempty handler
	local rc = mt[1]; mt[1] = 0;
	if rc > 0 then return (mt[2] or noop)(unpack(mt, 4)); end
end

-----
-- @function XF.Event.tagset_set_monitor
-- Set the monitor functions for the given tagset. The monitor functions are called when
-- the tagset becomes empty or nonempty, respectively. Additional arguments passed to
-- this function will be passed along to the monitors.
-----
local function tagset_set_monitor(tagset, on_empty, on_nonempty, ...)
	-- Create the monitor if it doesn't already exist
	local monitor = getmetatable(tagset);
	if not monitor then monitor = {0}; setmetatable(tagset, monitor); end
	-- Populate the monitor
	monitor[2], monitor[3] = on_empty, on_nonempty;
	for i=1, select("#", ...) do monitor[3 + i] = select(i, ...); end
	-- Return the tagset
	return tagset;
end
EventKernel.tagset_set_monitor = tagset_set_monitor;

-----
-- @function XF.Event.tagset_remove
-- From the given tagset, remove the given tag.
-----
local function tagset_remove(tagset, tag)
	-- Early out if there's nothing to do
	if not tagset[tag] then return; end
	-- Clear the tag from the tagset, maintaining RI
	tagset[tag] = nil; tag[tagset] = nil;
	-- Enforce metatable operations for the tagset.
	local mt = getmetatable(tagset);
	if mt then return _tagset_meta_remove(tagset, mt); end
end
EventKernel.tagset_remove = tagset_remove;

-----
-- @function XF.Event.tagset_add
-- Add the given tag to the given tagset, associated to the given value.
-----
local function tagset_add(tagset, tag, value)
	-- Shunt to remove if they passed in a nil value.
	if value == nil then return tagset_remove(tagset, tag); end
	-- Early out if we already have the tag
	if tagset[tag] then tagset[tag] = value; return; end
	tagset[tag] = value; tag[tagset] = true;
	-- Perform meta operations if necessary.
	local mt = getmetatable(tagset);
	if mt then return _tagset_meta_add(tagset, mt); end
end
EventKernel.tagset_add = tagset_add;

-----
-- @function XF.Event.tagset_clear
-- Remove all tags from the given tagset.
-----
local function tagset_clear(tagset)
	-- Already empty?
	if not next(tagset) then return; end
	-- Remove all tags from the tagset
	for tag in next,tagset do tagset[tag] = nil; tag[tagset] = nil; end
	-- If the tagset has a metatable, set the refcount to 0 and behave appropriately.
	local mt = getmetatable(tagset);
	if mt then return _tagset_meta_clear(tagset, mt); end
end
EventKernel.tagset_clear = tagset_clear;

-----
-- @function XF.Event.tag_clear
-- Remove the given tag from all tagsets of which it is currently a member.
-----
local function tag_clear(tag)
	for tagset in next,tag do
		------ Inline version of tagset_remove
		tagset[tag] = nil; tag[tagset] = nil;
		local mt = getmetatable(tagset);
		if mt then _tagset_meta_remove(tagset, mt); end
	end
end
EventKernel.tag_clear = tag_clear;

-----
-- @function XF.Event.tagset_dump
-- Dump debugging information about the given tagset in the form of strings, which
-- will be passed as arguments to the given output function.
-----
local function tagset_dump(tagset, print_func)
	local cnt = 0;
	for k,v in next,tagset do
		print_func("Tag ", k, " -> ", v); cnt = cnt + 1;
	end
	print_func("Raw count: ", cnt);
	local mt = getmetatable(tagset);
	if mt then
		print_func("Meta count: ", mt[1]);
	end
end
EventKernel.tagset_dump = tagset_dump;

return EventKernel
