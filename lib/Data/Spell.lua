local MQ2 = require("MQ2")
local data = MQ2.data

local function book(name)
	return data( ("Me.Book[%s]"):format(name) ) and true or false
end

local function stacks(name)
	return data( ("Spell[%s].Stacks"):format(name) ) and true or false
end

local function split(spell)
	local base, rankSuffix, rank = spell:match("()%s?([Rr][Kk]%.?%s?([Ii][Ii][Ii]?))$")
	if not base then return spell, "", "", 1 end
	local numericRank = 1
	rank = rank and rank:upper() or ""
	if rank == "II" then
		numericRank = 2
	elseif rank == "III" then
		numericRank = 3
	end
	return spell:sub(1,base-1), (rankSuffix or ""), (rank or ""), numericRank
end

local SpellTools = {}

-- The default gem number for memorizing spells.
local defaultGem = 8
function SpellTools.getDefaultGem() return defaultGem end
function SpellTools.setDefaultGem(n) defaultGem = n end

-- Check if you have the spell.
function SpellTools.known(name)
	return book(name)
end

-- Split a spell into name and rank
function SpellTools.split(name)
	return split(name)
end

-- Check if a spell would stack on you.
function SpellTools.stacks(name)
	return stacks(name)
end

-- Check if you can cast a spell.
function SpellTools.ready(name)
	return data( ("Cast.Ready[%s]"):format(name) )
end

-- Check if you have a spell memorized.
function SpellTools.gem(name)
	local gemn = data( ("Me.Gem[%s]"):format(name) )
	if not gemn then return nil end
	return gemn
end

-- Find proper name of the given spell
function SpellTools.getRanked(spell)
	-- If spell is already in the book, early out
	if book(spell) then return spell; end
	-- Add rank suffixes.
	-- XXX: This entails several linear searches over the spellbook.
	-- It's an MQ2 problem we could easily code around.
	local base = split(spell)
	spell = base .. " Rk. II"
	if book(spell) then return spell; end
	spell = base .. " Rk. III"
	if book(spell) then return spell; end
	-- No such spell.
	return nil
end

-- Locate item
function SpellTools.findItem(name)
	return data( ("FindItem[=%s].ID"):format(name) )
end

-- Locate AA
function SpellTools.findAA(name)
	return data( ("Me.AltAbility[%s].ID"):format(name) )
end


-- Locate the equipment
-- properName, type (spell|alt|item), itemToEquip = Spell.findAbility(name)
function SpellTools.findAbility(name)
	-- Are we casting from an item?
	local id = SpellTools.findItem(name)
	if id then
		if data( ("FindItem[=%s].EffectType.Equal[Click Worn]"):format(name) ) then
			-- If clicky must be worn, inform parent.
			return name, 'item', name
		else
			return name, 'item', nil
		end
	end
	-- Are we casting an AA?
	id = SpellTools.findAA(name)
	if id then return name, 'alt', nil; end
	-- Are we casting a spell?
	name = SpellTools.getRanked(name)
	if not name then return nil; end
	return name, 'spell'
end

-- For a clicky item, get the spell it will cast
function SpellTools.getItemSpellName(itemName)
	return data( ("FindItem[=%s].Spell.Name"):format(itemName) )
end


return SpellTools
