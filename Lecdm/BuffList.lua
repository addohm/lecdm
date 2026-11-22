-- Lecdm: its own list of buffs, for the Buffs tab's checklist. Each entry is matched by spell
-- name: tools/gen_data.py writes every spell ID with one of its names into BuffData.lua, so all
-- ranks, and the other names (the group versions, like Prayer of Fortitude), count as the first.
--   names        the entry's names; the first is the one shown
--   class        the classes it's listed for ("DRUID MAGE"), as theirs
--   race         only for this race (UnitRace's file name), with the class
--   castBy       the class that can put it on others (a shared buff); none: only you can. In
--                combat the running-out sound is timed from your own cast, so for a shared buff
--                it's quiet while someone else of that class is in your group.
--   warn         its own warning time in seconds (the "Each buff's own" choice)
--   note         shown in its tooltip
-- Sections are the checklist's submenus, in this order. Forever has no Blessing of Salvation or
-- Sanctuary, Greater Blessing of Light or Elemental Mastery (its SpellName table, 2026-11-22).
local _, ns = ...

local L = { sections = {}, byName = {} }
ns.BuffList = L

local function Section(name, entries)
	local section = { name = name, entries = entries }
	table.insert(L.sections, section)
	for _, e in ipairs(entries) do
		e.section = section
		e.name = e[1]
		for _, n in ipairs(e) do L.byName[n] = L.byName[n] or e end
	end
end

Section("Class buffs", {
	{ "Battle Shout", class = "WARRIOR", castBy = "WARRIOR", warn = 15 },
	{ "Power Word: Fortitude", "Prayer of Fortitude", class = "PRIEST", castBy = "PRIEST", warn = 120 },
	{ "Divine Spirit", "Prayer of Spirit", class = "PRIEST", castBy = "PRIEST", warn = 120 },
	{ "Shadow Protection", "Prayer of Shadow Protection", class = "PRIEST", castBy = "PRIEST", warn = 120 },
	{ "Inner Fire", class = "PRIEST", warn = 60 },
	{ "Fear Ward", class = "PRIEST", castBy = "PRIEST", warn = 30 },
	{ "Shadowguard", class = "PRIEST", race = "Troll", warn = 60, note = "Troll priests." },
	{ "Touch of Weakness", class = "PRIEST", race = "Scourge", warn = 60, note = "Undead priests." },
	{ "Mark of the Wild", "Gift of the Wild", class = "DRUID", castBy = "DRUID", warn = 120 },
	{ "Thorns", class = "DRUID", castBy = "DRUID", warn = 60 },
	{ "Omen of Clarity", class = "DRUID", warn = 60 },
	{ "Arcane Intellect", "Arcane Brilliance", class = "MAGE", castBy = "MAGE", warn = 120 },
	{ "Amplify Magic", class = "MAGE", castBy = "MAGE", warn = 60 },
	{ "Dampen Magic", class = "MAGE", castBy = "MAGE", warn = 60 },
	{ "Mage Armor", class = "MAGE", warn = 60 },
	{ "Ice Armor", "Frost Armor", class = "MAGE", warn = 60 },
	{ "Blessing of Might", "Greater Blessing of Might", class = "PALADIN", castBy = "PALADIN", warn = 60 },
	{ "Blessing of Wisdom", "Greater Blessing of Wisdom", class = "PALADIN", castBy = "PALADIN", warn = 60 },
	{ "Blessing of Kings", "Greater Blessing of Kings", class = "PALADIN", castBy = "PALADIN", warn = 60 },
	{ "Blessing of Light", class = "PALADIN", castBy = "PALADIN", warn = 60 },
	{ "Righteous Fury", class = "PALADIN", warn = 60 },
	{ "Devotion Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Retribution Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Concentration Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Sanctity Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Shadow Resistance Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Frost Resistance Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Fire Resistance Aura", class = "PALADIN", castBy = "PALADIN", warn = 0 },
	{ "Trueshot Aura", class = "HUNTER", castBy = "HUNTER", warn = 0 },
	{ "Aspect of the Hawk", class = "HUNTER", warn = 0 },
	{ "Aspect of the Monkey", class = "HUNTER", warn = 0 },
	{ "Aspect of the Cheetah", class = "HUNTER", warn = 0 },
	{ "Aspect of the Pack", class = "HUNTER", castBy = "HUNTER", warn = 0 },
	{ "Aspect of the Wild", class = "HUNTER", castBy = "HUNTER", warn = 0 },
	{ "Aspect of the Beast", class = "HUNTER", warn = 0 },
	{ "Lightning Shield", class = "SHAMAN", warn = 60 },
	{ "Strength of Earth", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Grace of Air", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Windfury Totem", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Mana Spring", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Healing Stream", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Stoneskin", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Tranquil Air", class = "SHAMAN", castBy = "SHAMAN", warn = 0, note = "From the totem." },
	{ "Demon Armor", "Demon Skin", class = "WARLOCK", warn = 60 },
	{ "Unending Breath", class = "WARLOCK", castBy = "WARLOCK", warn = 60 },
	{ "Detect Invisibility", "Detect Greater Invisibility", "Detect Lesser Invisibility", class = "WARLOCK", castBy = "WARLOCK", warn = 60 },
	{ "Soul Link", class = "WARLOCK", warn = 0 },
	{ "Slice and Dice", class = "ROGUE", warn = 3 },
})

Section("Procs and cooldowns", {
	{ "Flurry", class = "WARRIOR SHAMAN", warn = 3 },
	{ "Enrage", class = "WARRIOR DRUID", warn = 3 },
	{ "Bloodrage", class = "WARRIOR", warn = 3 },
	{ "Berserker Rage", class = "WARRIOR", warn = 3 },
	{ "Death Wish", class = "WARRIOR", warn = 5 },
	{ "Recklessness", class = "WARRIOR", warn = 5 },
	{ "Sweeping Strikes", class = "WARRIOR", warn = 3 },
	{ "Reckless Swings", class = "WARRIOR", warn = 2 },
	{ "Gore Drinker", class = "WARRIOR", warn = 2 },
	{ "Shield Block", class = "WARRIOR", warn = 2 },
	{ "Shield Wall", class = "WARRIOR", warn = 3 },
	{ "Last Stand", class = "WARRIOR", warn = 3 },
	{ "Retaliation", class = "WARRIOR", warn = 3 },
	{ "Shadowform", class = "PRIEST", warn = 0 },
	{ "Inner Focus", class = "PRIEST", warn = 0 },
	{ "Fade", class = "PRIEST", warn = 3 },
	{ "Spirit Tap", class = "PRIEST", warn = 3 },
	{ "Dark Inspiration", class = "PRIEST", castBy = "PRIEST", warn = 3 },
	{ "Inspiration", class = "PRIEST", castBy = "PRIEST", warn = 3 },
	{ "Divine Aegis", class = "PRIEST", castBy = "PRIEST", warn = 3 },
	{ "Prayer of Mending", class = "PRIEST", castBy = "PRIEST", warn = 5 },
	{ "Power Infusion", class = "PRIEST", castBy = "PRIEST", warn = 3 },
	{ "Power Word: Shield", class = "PRIEST", castBy = "PRIEST", warn = 5 },
	{ "Renew", class = "PRIEST", castBy = "PRIEST", warn = 3 },
	{ "Elune's Grace", class = "PRIEST", race = "NightElf", warn = 3, note = "Night elf priests." },
	{ "Feedback", class = "PRIEST", race = "Human", warn = 3, note = "Human priests." },
	{ "Dark Sacrifice", class = "PRIEST", race = "Scourge", warn = 3, note = "Undead priests." },
	{ "Clearcasting", class = "DRUID MAGE SHAMAN", warn = 3 },
	{ "Barkskin", class = "DRUID", warn = 3 },
	{ "Nature's Grasp", class = "DRUID", warn = 5 },
	{ "Dash", class = "DRUID", warn = 3 },
	{ "Frenzied Regeneration", class = "DRUID", warn = 3 },
	{ "Nature's Swiftness", class = "DRUID SHAMAN", warn = 0 },
	{ "Nature's Grace", class = "DRUID", warn = 1 },
	{ "Eclipse", class = "DRUID", warn = 3 },
	{ "Tiger's Fury", class = "DRUID", warn = 2 },
	{ "Leader of the Pack", class = "DRUID", castBy = "DRUID", warn = 0 },
	{ "Moonkin Aura", class = "DRUID", castBy = "DRUID", warn = 0 },
	{ "Wild Growth", class = "DRUID", castBy = "DRUID", warn = 3 },
	{ "Innervate", class = "DRUID", castBy = "DRUID", warn = 3 },
	{ "Rejuvenation", class = "DRUID", castBy = "DRUID", warn = 3 },
	{ "Regrowth", class = "DRUID", castBy = "DRUID", warn = 3 },
	{ "Arcane Power", class = "MAGE", warn = 3 },
	{ "Presence of Mind", class = "MAGE", warn = 0 },
	{ "Combustion", class = "MAGE", warn = 0 },
	{ "Ice Barrier", class = "MAGE", warn = 5 },
	{ "Mana Shield", class = "MAGE", warn = 5 },
	{ "Ice Block", class = "MAGE", warn = 2 },
	{ "Evocation", class = "MAGE", warn = 0 },
	{ "Divine Shield", class = "PALADIN", warn = 3 },
	{ "Divine Protection", class = "PALADIN", warn = 3 },
	{ "Blessing of Protection", class = "PALADIN", castBy = "PALADIN", warn = 3 },
	{ "Blessing of Freedom", class = "PALADIN", castBy = "PALADIN", warn = 3 },
	{ "Divine Favor", class = "PALADIN", warn = 0 },
	{ "Holy Shield", class = "PALADIN", warn = 2 },
	{ "Vengeance", class = "PALADIN", warn = 2 },
	{ "Redoubt", class = "PALADIN", warn = 2 },
	{ "Seal of Righteousness", class = "PALADIN", warn = 5 },
	{ "Seal of Command", class = "PALADIN", warn = 5 },
	{ "Seal of the Crusader", class = "PALADIN", warn = 5 },
	{ "Seal of Wisdom", class = "PALADIN", warn = 5 },
	{ "Seal of Light", class = "PALADIN", warn = 5 },
	{ "Seal of Justice", class = "PALADIN", warn = 5 },
	{ "Rapid Fire", class = "HUNTER", warn = 3 },
	{ "Quick Shots", class = "HUNTER", warn = 2 },
	{ "Deterrence", class = "HUNTER", warn = 2 },
	{ "Shadow Trance", class = "WARLOCK", warn = 2 },
	{ "Amplify Curse", class = "WARLOCK", warn = 0 },
	{ "Shadow Ward", class = "WARLOCK", warn = 5 },
	{ "Sacrifice", class = "WARLOCK", warn = 3, note = "Your voidwalker's shield." },
	{ "Adrenaline Rush", class = "ROGUE", warn = 3 },
	{ "Blade Flurry", class = "ROGUE", warn = 3 },
	{ "Evasion", class = "ROGUE", warn = 3 },
	{ "Sprint", class = "ROGUE", warn = 3 },
	{ "Cold Blood", class = "ROGUE", warn = 0 },
	{ "Remorseless", class = "ROGUE", warn = 3 },
})

Section("Racials", {
	{ "Berserking", race = "Troll", warn = 3 },
	{ "Blood Fury", race = "Orc", warn = 3 },
	{ "Stoneform", race = "Dwarf", warn = 2 },
	{ "Perception", race = "Human", warn = 3 },
	{ "Shadowmeld", race = "NightElf", warn = 0 },
	{ "Will of the Forsaken", race = "Scourge", warn = 0 },
})

Section("World buffs", {
	{ "Rallying Cry of the Dragonslayer", warn = 300, note = "From Onyxia's head. No effect inside raids." },
	{ "Warchief's Blessing", warn = 300, note = "From Rend's head in Upper Blackrock Spire. No effect inside raids." },
	{ "Spirit of Zandalar", warn = 300, note = "From Hakkar's heart. No effect inside raids." },
	{ "Songflower Serenade", warn = 300, note = "Songflowers in Felwood. No effect inside raids." },
	{ "Fengus' Ferocity", warn = 300, note = "Dire Maul tribute run. No effect inside raids." },
	{ "Mol'dar's Moxie", warn = 300, note = "Dire Maul tribute run. No effect inside raids." },
	{ "Slip'kik's Savvy", warn = 300, note = "Dire Maul tribute run. No effect inside raids." },
	{ "Traces of Silithyst", warn = 120, note = "Turning in Silithyst in Silithus." },
	{ "Sayge's Dark Fortune of Damage", "Sayge's Dark Fortune of Agility", "Sayge's Dark Fortune of Intelligence",
		"Sayge's Dark Fortune of Spirit", "Sayge's Dark Fortune of Stamina", "Sayge's Dark Fortune of Strength",
		"Sayge's Dark Fortune of Armor", "Sayge's Dark Fortune of Resistance",
		warn = 300, note = "Sayge at the Darkmoon Faire. No effect inside raids." },
})

Section("Consumables", {
	{ "Flask of the Titans", warn = 300 },
	{ "Supreme Power", warn = 300, note = "Flask of Supreme Power." },
	{ "Distilled Wisdom", warn = 300, note = "Flask of Distilled Wisdom." },
	{ "Chromatic Resistance", warn = 300, note = "Flask of Chromatic Resistance." },
	{ "Elixir of the Mongoose", warn = 120 },
	{ "Elixir of the Giants", warn = 120, note = "Elixir of Giants." },
	{ "Greater Agility", warn = 120, note = "Elixir of Greater Agility." },
	{ "Greater Arcane Elixir", warn = 120 },
	{ "Greater Firepower", warn = 120, note = "Elixir of Greater Firepower." },
	{ "Shadow Power", warn = 120, note = "Elixir of Shadow Power." },
	{ "Frost Power", warn = 120, note = "Elixir of Frost Power." },
	{ "Health II", warn = 120, note = "Elixir of Fortitude." },
	{ "Greater Armor", warn = 120, note = "Elixir of Superior Defense." },
	{ "Mana Regeneration", warn = 120, note = "Mageblood Potion." },
	{ "Juju Power", warn = 120 },
	{ "Juju Might", warn = 120 },
	{ "Winterfall Firewater", warn = 120 },
	{ "Rage of Ages", warn = 120, note = "R.O.I.D.S." },
	{ "Strike of the Scorpok", warn = 120, note = "Ground Scorpok Assay." },
	{ "Spirit of Boar", warn = 120, note = "Lung Juice Cocktail." },
	{ "Infallible Mind", warn = 120, note = "Cerebral Cortex Compound." },
	{ "Spiritual Domination", warn = 120, note = "Gizzard Gum." },
	{ "Well Fed", warn = 120, note = "Food." },
})

-- The entry a name belongs to (any of its names), or nil.
function L.Entry(name)
	return L.byName[name]
end

-- Every name of a buff's entry (just the name, for a buff not on the list).
function L.Names(name)
	local e = L.byName[name]
	if not e then return { name } end
	local names = {}
	for _, n in ipairs(e) do names[#names + 1] = n end
	return names
end

-- Whether an entry is for this class and race (class and race file names).
function L.IsFor(e, class, race)
	if e.race and e.race ~= race then return false end
	if e.class then return (" " .. e.class .. " "):find(" " .. class .. " ", 1, true) ~= nil end
	return e.race ~= nil
end
