-- Lecdm: Blizzard's list. Every entry Blizzard's Cooldown Manager has for the character, by
-- section (Essential, Utility, Tracked buffs, ...), learned or not, read through
-- C_CooldownViewer. A cooldown ID is Blizzard's key for an entry; it's never secret, so the
-- listener names entries through it.
local _, ns = ...

local Cat = {}
ns.Catalogue = Cat

Cat.byID = {}     -- cooldownID -> { cooldownID, spellID, name, category, known, aura, selfAura,
                  --   charges, ids = { every spell ID the entry names: base, override, linked } }
Cat.bySpell = {}  -- spellID -> the same entry
Cat.sections = {} -- { value, name, ids }, by section value

local function Plain(v)
	if ns.IsSecret(v) then return nil end
	return v
end

local function EntryName(info, spellID)
	if spellID then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and Plain(name) then return name end
		return "spell " .. spellID
	end
	if Plain(info.equipSlot) then return "equipment slot " .. info.equipSlot end
	return "cooldown " .. tostring(info.cooldownID)
end

function Cat.Build()
	wipe(Cat.byID)
	wipe(Cat.bySpell)
	wipe(Cat.sections)
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return end
	for sectionName, value in pairs(Enum.CooldownViewerCategory or {}) do
		local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, value, true)
		if ok and type(ids) == "table" then
			local section = { value = value, name = sectionName, ids = {} }
			for _, id in ipairs(ids) do
				local okInfo, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
				if okInfo and type(info) == "table" then
					local spellID = Plain(info.overrideSpellID) or Plain(info.spellID)
					local ids = {}
					for _, v in ipairs({ Plain(info.spellID), Plain(info.overrideSpellID) }) do ids[#ids + 1] = v end
					for _, v in ipairs(Plain(info.linkedSpellIDs) or {}) do
						if Plain(v) then ids[#ids + 1] = v end
					end
					Cat.byID[id] = {
						cooldownID = id, spellID = spellID, name = EntryName(info, spellID),
						category = value, known = Plain(info.isKnown),
						aura = Plain(info.hasAura) or Plain(info.selfAura), selfAura = Plain(info.selfAura),
						charges = Plain(info.charges), ids = ids,
					}
					if spellID then Cat.bySpell[spellID] = Cat.byID[id] end
					table.insert(section.ids, id)
				end
			end
			table.insert(Cat.sections, section)
		end
	end
	table.sort(Cat.sections, function(a, b) return a.value < b.value end)
end

-- The name for a cooldown ID, looked up now if the list didn't have it.
function Cat.Name(cooldownID)
	local entry = Cat.byID[cooldownID]
	if entry then return entry.name end
	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if ok and type(info) == "table" then
		return EntryName(info, Plain(info.overrideSpellID) or Plain(info.spellID))
	end
	return "cooldown " .. tostring(cooldownID)
end

-- Spell entries of the given sections, in Blizzard's order: learned ones only, or all with all.
function Cat.Spells(values, all)
	local list = {}
	for _, section in ipairs(Cat.sections) do
		if values[section.value] then
			for _, id in ipairs(section.ids) do
				local entry = Cat.byID[id]
				if entry.spellID and (all or entry.known) then table.insert(list, entry) end
			end
		end
	end
	return list
end

function Cat.PrintCounts()
	if #Cat.sections == 0 then Cat.Build() end
	if #Cat.sections == 0 then
		ns.Print("Blizzard's list: empty (C_CooldownViewer gave nothing)")
		return
	end
	local parts = {}
	for _, section in ipairs(Cat.sections) do
		local known = 0
		for _, id in ipairs(section.ids) do
			if Cat.byID[id].known then known = known + 1 end
		end
		table.insert(parts, section.name .. " " .. known .. "/" .. #section.ids)
	end
	ns.Print("Blizzard's list (learned/all): " .. table.concat(parts, ", "))
end

-- Every entry, into the log and chat, so it can be copied with /lecdm log.
function Cat.PrintAll()
	Cat.Build()
	ns.Log("Blizzard's list, by section (* = not learned yet):", true)
	for _, section in ipairs(Cat.sections) do
		local names = {}
		for _, id in ipairs(section.ids) do
			local entry = Cat.byID[id]
			table.insert(names, (entry.known and "" or "*") .. entry.name)
		end
		ns.Log(section.name .. " (" .. #section.ids .. "): " .. (#names > 0 and table.concat(names, ", ") or "-"), true)
	end
end
