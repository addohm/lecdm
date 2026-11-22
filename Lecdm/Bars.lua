-- Lecdm: icon bars (the code says "bars"). Lecdm's own icons, in bars the player sets up
-- (ns.db.bars.list); not to be confused with timer bars (Blizzard's "tracked bars"), which
-- come with the buffs. A bar holds entries: a spell (its ID), an equipment slot ("slot:13":
-- whatever is equipped there, shown while it has a use effect) or an item from the bags
-- ("item:<itemID>": shown while you have one, with the count). Item cooldowns aren't secret
-- (Blizzard's docs; the owner's trinket check read plain numbers in combat), so their swipe is
-- Cooldown:SetCooldown; a secret one would be refused and cleared. For each spell:
--  * the swipe and countdown come from C_Spell.GetSpellCooldownDuration, drawn by the game
--    (Cooldown:SetCooldownFromDurationObject), the GCD included unless the bar turns it off;
--  * grey while on a real cooldown (isActive and not isOnGCD: never secret), dark while it can't
--    be cast (IsSpellUsable), red while the target is out of range (IsSpellInRange);
--  * per spell, "only when ready" or "only while on cooldown" hides it otherwise, and the bar
--    closes the gap: these are Lecdm's own frames, so Lua may decide (confirmed in combat in a
--    dungeon, TESTING.md).
-- Spells not learned yet keep their place in the list and show once learned. The first time a
-- profile is used, two bars are filled from Blizzard's list (Essential, Utility).
-- While the bars are on, Blizzard's Essential and Utility viewers are made invisible (alpha 0),
-- never hidden: they keep running, so the listener still hears them. Plain frames, no mouse
-- (except while unlocked to move), not protected: made and updated in combat too.
local _, ns = ...

local B = {}
ns.Bars = B

B.SHOW = { { "always", "Always" }, { "ready", "Only when ready" }, { "usable", "Only when ready and usable" },
	{ "cooldown", "Only on cooldown" } }
B.GROW = { { "CENTER", "Centre" }, { "LEFT", "Left / top" }, { "RIGHT", "Right / bottom" } }
B.BLIZZARD = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
B.BLIZZARD_BUFFS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local frames = {}  -- bar id -> its frame
local unlocked = false
local faded = {}   -- Blizzard viewer -> true while Lecdm keeps it invisible

-- A new bar with the default look.
function B.NewBar(name)
	local bars = ns.db.bars
	bars.nextID = (bars.nextID or 1) + 1
	local bar = { id = "bar" .. bars.nextID, name = name, spells = {}, show = {} }
	B.FillLook(bar)
	table.insert(bars.list, bar)
	return bar
end

-- A bar's look and visibility (also for bars made before a setting existed).
B.LOOK = {
	size = 40, gap = 4, grow = "CENTER", vertical = false, perRow = 12, gcd = true, emptyItems = "hide",
	border = 1, borderColor = "black", zoom = 0.08, countdown = "normal", keybind = false,
	grey = true, red = true, dark = true, showWhen = "always", alpha = 1, oocAlpha = 1, tooltip = "off",
	cdAlpha = 1, zeroCharges = true, swipe = "normal", swipeColor = "dark", edge = false, activeColor = "gold",
	threshold = 0, thresholdColor = "red", thresholdDecimals = false,
}
function B.FillLook(bar)
	for k, v in pairs(B.LOOK) do
		if bar[k] == nil then bar[k] = v end
	end
end

-- The swipe: drawn as the game does, reversed (the dark part shrinks instead), or not at all;
-- its colour; and the bright edge on its line.
B.SWIPES = { { "normal", "Normal" }, { "reverse", "Reversed" }, { "off", "None (the countdown only)" } }
B.SWIPE_COLORS = { { "dark", "Dark" }, { "class", "Class colour" }, { "gold", "Gold" }, { "blue", "Blue" },
	{ "red", "Red" }, { "white", "White" } }
local SWIPE_RGB = { dark = { 0, 0, 0, 0.8 }, gold = { 1, 0.78, 0.38, 0.75 }, blue = { 0.25, 0.6, 1, 0.7 },
	red = { 0.9, 0.2, 0.2, 0.7 }, white = { 1, 1, 1, 0.6 } }
function B.SwipeRGBA(color)
	if color == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b, 0.75 end
	end
	local c = SWIPE_RGB[color] or SWIPE_RGB.dark
	return c[1], c[2], c[3], c[4]
end

-- The countdown under a set time (threshold, seconds; 0: off): in a colour, and with a decimal.
-- The colour is the game's duration text binding on Lecdm's own font string (its colour curve
-- applies in combat too); the decimal is the game's countdown's (SetCountdownMillisecondsThreshold),
-- so it shows when there's no colour.
B.THRESHOLDS = { { 0, "Off" }, { 3, "3 s" }, { 5, "5 s" }, { 10, "10 s" }, { 30, "30 s" }, { 60, "1 min" } }
B.THRESHOLD_COLORS = { { "none", "None (as above)" }, { "red", "Red" }, { "orange", "Orange" }, { "yellow", "Yellow" } }
local THRESHOLD_RGB = { red = { 1, 0.25, 0.25 }, orange = { 1, 0.55, 0.1 }, yellow = { 1, 0.9, 0.2 } }

local function TimeBinding(b, bar)
	local rgb = THRESHOLD_RGB[bar.thresholdColor]
	local want = (bar.threshold or 0) > 0 and rgb and B.FONTS[bar.countdown] and C_DurationUtil
		and C_DurationUtil.CreateDurationTextBinding and C_CurveUtil
	if not want then
		if b.timeBinding then
			pcall(b.timeBinding.SetEnabled, b.timeBinding, false)
			b.timeText:SetText("")
		end
		b.useBinding = false
		return
	end
	if not b.timeBinding then
		b.timeText = b.over:CreateFontString(nil, "OVERLAY", B.FONTS[bar.countdown])
		b.timeText:SetPoint("CENTER")
		local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
		if not (ok and binding) then return end
		b.timeBinding = binding
		binding:SetFontString(b.timeText)
	end
	pcall(b.timeText.SetFontObject, b.timeText, B.FONTS[bar.countdown])
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, CreateColor(rgb[1], rgb[2], rgb[3], 1))
	curve:AddPoint(bar.threshold, CreateColor(1, 1, 1, 1))
	b.timeBinding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.RemainingDuration)
	b.useBinding = true
end

-- The countdown a binding shows now: a duration object, or nil for none.
local function Countdown(b, dur)
	if not b.useBinding then return end
	if dur then
		pcall(b.timeBinding.SetDuration, b.timeBinding, dur)
		pcall(b.timeBinding.SetEnabled, b.timeBinding, true)
	else
		pcall(b.timeBinding.SetEnabled, b.timeBinding, false)
		b.timeText:SetText("")
	end
end

-- The tooltip on hover: off (the icons let clicks through), on, or out of combat only.
B.TOOLTIPS = { { "off", "Off" }, { "on", "On" }, { "ooc", "Out of combat only" } }
B.BORDERS = { { 0, "None" }, { 1, "Thin" }, { 2, "Thick" }, { 3, "Heavy" } }
B.BORDER_COLORS = { { "black", "Black" }, { "class", "Class colour" }, { "gold", "Gold" }, { "white", "White" } }
B.ZOOMS = { { 0, "None" }, { 0.08, "A little" }, { 0.15, "More" } }
B.TEXT_SIZES = { { "off", "Off" }, { "small", "Small" }, { "normal", "Normal" }, { "large", "Large" }, { "huge", "Huge" } }
B.FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }

function B.BorderRGB(color)
	if color == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	elseif color == "gold" then
		return 1, 0.82, 0
	elseif color == "white" then
		return 1, 1, 1
	end
	return 0, 0, 0
end

function B.Get(id)
	for i, bar in ipairs(ns.db.bars.list) do
		if bar.id == id then return bar, i end
	end
end

-- Fills the profile's first bars from Blizzard's list, once (when the list has loaded).
local function Seed()
	local bars = ns.db.bars
	if bars.seeded then return end
	local essential = ns.Catalogue.Spells({ [0] = true }, true)
	local utility = ns.Catalogue.Spells({ [1] = true }, true)
	if #essential + #utility == 0 then return end
	bars.seeded = true
	for _, def in ipairs({ { "Cooldowns", essential }, { "Utility", utility } }) do
		local bar = B.NewBar(def[1])
		for _, e in ipairs(def[2]) do
			if not B.BarOf(e.spellID) then table.insert(bar.spells, e.spellID) end
		end
		-- The trinkets go with the utility spells.
		if def[1] == "Utility" then
			for _, key in ipairs({ "slot:13", "slot:14" }) do
				if not B.BarOf(key) then table.insert(bar.spells, key) end
			end
		end
	end
end

-- The bar a spell is on, and its place there.
function B.BarOf(spellID)
	for _, bar in ipairs(ns.db.bars.list) do
		for i, id in ipairs(bar.spells) do
			if id == spellID then return bar, i end
		end
	end
end

-- Puts a spell on a bar (taking it off any other) or takes it off.
function B.SetOnBar(bar, spellID, on)
	local other, i = B.BarOf(spellID)
	if other then
		table.remove(other.spells, i)
		other.show[spellID] = nil
		if other.forms then other.forms[spellID] = nil end
		if other.talents then other.talents[spellID] = nil end
		if other.active then other.active[spellID] = nil end
		if other.looks then other.looks[spellID] = nil end
		if other.bestOrder then other.bestOrder[spellID] = nil end
	end
	if on then table.insert(bar.spells, spellID) end
	ns.Refresh()
end

-- Stances and forms: a spell can show only in one, or only out of it ("in:<form spell ID>",
-- "out:<id>"; id 0 is no stance or form). GetShapeshiftForm's index gives the form's spell.
function B.FormNow()
	if not GetShapeshiftForm then return nil end
	local ok, i = pcall(GetShapeshiftForm)
	if not ok or ns.IsSecret(i) or type(i) ~= "number" then return nil end
	if i == 0 then return 0 end
	local okInfo, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
	if okInfo and not ns.IsSecret(spellID) and type(spellID) == "number" then return spellID end
end

-- The class's stances and forms: { spellID, name } each.
function B.Forms()
	local list = {}
	local ok, n = pcall(GetNumShapeshiftForms)
	if not ok or ns.IsSecret(n) or type(n) ~= "number" then return list end
	for i = 1, n do
		local okInfo, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
		if okInfo and not ns.IsSecret(spellID) and type(spellID) == "number" then
			list[#list + 1] = { spellID, B.SpellName(spellID) or ("form " .. i) }
		end
	end
	return list
end

function B.SetForm(bar, key, value)
	bar.forms = bar.forms or {}
	bar.forms[key] = value
	ns.Refresh()
end

-- Whether a spell's stance or form condition lets it show now (unknown: yes).
local function FormAllows(bar, key)
	local cond = bar.forms and bar.forms[key]
	if not cond then return true end
	local mode, id = cond:match("^(%a+):(%d+)$")
	local now = B.FormNow()
	if not (mode and now) then return true end
	return (mode == "in") == (now == tonumber(id))
end

-- Talents: a spell can show only with a talent taken, or only without it ("with:<nodeID>",
-- "without:<nodeID>"; Talents.lua).
function B.SetTalent(bar, key, value)
	bar.talents = bar.talents or {}
	bar.talents[key] = value
	ns.Refresh()
end

local function TalentAllows(bar, key)
	local cond = bar.talents and bar.talents[key]
	if not cond then return true end
	local mode, id = cond:match("^(%a+):(%d+)$")
	local taken = mode and ns.Talents.Taken(tonumber(id))
	if taken == nil then return true end
	return (mode == "with") == taken
end

-- An empty space on a bar ("space:<n>"): it keeps its place, showing nothing.
function B.AddSpace(bar)
	bar.nextSpace = (bar.nextSpace or 0) + 1
	table.insert(bar.spells, "space:" .. bar.nextSpace)
	ns.Refresh()
end

-- Adds a spell ("6673") or an item ("item:13446") by ID; false if the game knows no such thing.
function B.AddByID(bar, text)
	text = strtrim(text or "")
	local kind, n = text:lower():match("^(%a+):(%d+)$")
	local id = tonumber(n or text)
	if not id then return false end
	if kind == "item" then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if not (ok and icon and not ns.IsSecret(icon)) then return false end
		local key = "item:" .. id
		if B.BarOf(key) ~= bar then B.SetOnBar(bar, key, true) end
		return true
	end
	if kind and kind ~= "spell" then return false end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if not (ok and name and not ns.IsSecret(name)) then return false end
	if B.BarOf(id) ~= bar then B.SetOnBar(bar, id, true) end
	return true
end

-- Moves a spell up (-1) or down (1) its bar.
function B.MoveSpell(bar, index, dir)
	local j = index + dir
	if j < 1 or j > #bar.spells then return end
	bar.spells[index], bar.spells[j] = bar.spells[j], bar.spells[index]
	ns.Refresh()
end

function B.Delete(id)
	local _, i = B.Get(id)
	if i then table.remove(ns.db.bars.list, i) end
	ns.Refresh()
end

-- Every bar back to Blizzard's list, as on a new profile.
function B.StartOver()
	ns.db.bars.list = {}
	ns.db.bars.seeded = false
	Seed()
	ns.Refresh()
end

-- Learned: Blizzard's list says so, or the spellbook does.
function B.Known(spellID)
	local entry = ns.Catalogue.bySpell[spellID]
	if entry and entry.known then return true end
	for _, fn in ipairs({ C_SpellBook and C_SpellBook.IsSpellKnown, IsPlayerSpell }) do
		local ok, known = pcall(fn, spellID)
		if ok and known == true then return true end
	end
	return false
end

function B.SpellName(spellID)
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	return ok and not ns.IsSecret(name) and name or ("spell " .. tostring(spellID))
end

function B.SpellIcon(spellID)
	local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
	return ok and not ns.IsSecret(icon) and icon or 134400
end

-- Entries: spells, equipment slots, bag items -----------------------------------------------

B.SLOTS = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
	[8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Top trinket",
	[14] = "Bottom trinket", [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

-- "spell", spellID / "slot", slot / "item", itemID.
function B.Kind(key)
	if type(key) == "number" then return "spell", key end
	local kind, id = tostring(key):match("^(%a+):(%d+)$")
	return kind, tonumber(id)
end

local function SlotItem(slot)
	local ok, itemID = pcall(GetInventoryItemID, "player", slot)
	if ok and not ns.IsSecret(itemID) and itemID then return itemID end
end

local function HasUse(itemID)
	if not itemID then return false end
	local ok, name = pcall(C_Item.GetItemSpell, itemID)
	return ok and not ns.IsSecret(name) and name ~= nil
end

-- The item an entry shows now (a slot's: what's equipped there).
function B.ItemOf(key)
	local kind, id = B.Kind(key)
	if kind == "slot" then return SlotItem(id) end
	if kind == "item" then return id end
	if kind == "best" then
		local order = B.BestOrder(nil, key)
		for _, itemID in ipairs(order) do
			if B.ItemCount(itemID) > 0 then return itemID end
		end
		return order[1]
	end
end

-- "Best in your bags" ("best:N"): one entry for a kind of item, showing the best you carry, in
-- the bar's order for it (bar.bestOrder[key], else the best first).
B.BEST = {
	{ name = "Best healing potion", items = { 13446, 3928, 1710, 929, 858, 118 } },
	{ name = "Best mana potion", items = { 13444, 13443, 6149, 3827, 3385, 2455 } },
	{ name = "Best healthstone", items = { 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509,
		19007, 19006, 5511, 19005, 19004, 5512 } },
	{ name = "Best rune (Dark or Demonic)", items = { 20520, 12662 } },
}

-- An entry's item order: the bar's own for it, else the list's (bar nil: the bar it's on).
function B.BestOrder(bar, key)
	local _, n = B.Kind(key)
	local def = B.BEST[n]
	if not def then return {} end
	bar = bar or B.BarOf(key)
	local own = bar and bar.bestOrder and bar.bestOrder[key]
	if own and #own == #def.items then return own end
	return def.items
end

-- Moves an item up (-1) or down (1) in an entry's order.
function B.MoveBest(bar, key, index, dir)
	local order = {}
	for i, id in ipairs(B.BestOrder(bar, key)) do order[i] = id end
	local j = index + dir
	if j < 1 or j > #order then return end
	order[index], order[j] = order[j], order[index]
	bar.bestOrder = bar.bestOrder or {}
	bar.bestOrder[key] = order
	ns.Refresh()
end

local function ItemName(itemID)
	local ok, name = pcall(C_Item.GetItemNameByID, itemID)
	return ok and not ns.IsSecret(name) and name or ("item " .. tostring(itemID))
end

function B.ItemCount(itemID)
	local ok, n = pcall(C_Item.GetItemCount, itemID)
	if ok and not ns.IsSecret(n) and type(n) == "number" then return n end
	return 0
end

function B.EntryName(key)
	local kind, id = B.Kind(key)
	if kind == "spell" then return B.SpellName(id) end
	if kind == "space" then return "Empty space" end
	if kind == "best" then return B.BEST[id] and B.BEST[id].name or ("best " .. id) end
	if kind == "slot" then
		local itemID = SlotItem(id)
		return (B.SLOTS[id] or ("Slot " .. id)) .. ": " .. (itemID and ItemName(itemID) or "empty")
	end
	return ItemName(id)
end

function B.EntryIcon(key)
	local kind, id = B.Kind(key)
	if kind == "spell" then return B.SpellIcon(id) end
	if kind == "space" then return nil end
	local itemID = B.ItemOf(key)
	if not itemID then return 134400 end
	local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
	return ok and not ns.IsSecret(icon) and icon or 134400
end

-- Shown at all: a spell learned, an equipped item with a use effect, an item in the bags.
function B.EntryKnown(key)
	local kind, id = B.Kind(key)
	if kind == "spell" then return B.Known(id) end
	if kind == "space" then return true end
	if kind == "slot" then return HasUse(SlotItem(id)) end
	if kind == "best" then
		local itemID = B.ItemOf(key)
		return itemID ~= nil and B.ItemCount(itemID) > 0
	end
	return B.ItemCount(id) > 0
end

-- Why an entry isn't shown (for the tab).
function B.Missing(key)
	local kind = B.Kind(key)
	if kind == "spell" then return "not learned" end
	if kind == "slot" then return "nothing with a use effect" end
	return "none in your bags"
end

-- For the checklist: the trinket slots, and every other slot holding an item with a use effect.
function B.Equipped()
	local list = {}
	for slot = 1, 18 do
		if slot == 13 or slot == 14 or HasUse(SlotItem(slot)) then list[#list + 1] = "slot:" .. slot end
	end
	return list
end

-- For the checklist: items with a use effect in the bags, once each.
function B.BagItems()
	local list, seen = {}, {}
	if not (C_Container and C_Container.GetContainerNumSlots) then return list end
	for bag = 0, 4 do
		local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (okN and not ns.IsSecret(n) and n) or 0 do
			local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			local id = okI and type(info) == "table" and info.itemID
			if id and not ns.IsSecret(id) and not seen[id] and HasUse(id) then
				seen[id] = true
				list[#list + 1] = "item:" .. id
			end
		end
	end
	return list
end

-- The icons ------------------------------------------------------------------------------

local function Button(frame, i)
	local b = frame.buttons[i]
	if b then return b end
	b = CreateFrame("Frame", nil, frame)
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	b.cd:SetHideCountdownNumbers(false)
	-- The stack count, above the swipe.
	b.over = CreateFrame("Frame", nil, b)
	b.over:SetAllPoints()
	b.over:SetFrameLevel(b.cd:GetFrameLevel() + 1)
	b.count = b.over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.keyText = b.over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	b.keyText:SetPoint("TOPRIGHT", -2, -2)
	-- The alerts' glow (Alerts.lua), above the swipe, below the text.
	b.glow = CreateFrame("Frame", nil, b)
	b.glow:SetAllPoints()
	b.glow:SetFrameLevel(b.cd:GetFrameLevel() + 1)
	b.over:SetFrameLevel(b.cd:GetFrameLevel() + 6) -- above the buff shown on it, too
	b:SetScript("OnEnter", B.ShowTooltip)
	b:SetScript("OnLeave", GameTooltip_Hide)
	frame.buttons[i] = b
	return b
end

-- The game's tooltip for an icon's spell, slot or item (the bar's choice).
function B.ShowTooltip(b)
	local bar = b.bar
	if not (bar and b.key) or bar.tooltip == "off" or (bar.tooltip == "ooc" and InCombatLockdown()) then return end
	local kind, id = B.Kind(b.key)
	if kind == "best" then kind, id = "item", B.ItemOf(b.key) end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	if kind == "spell" then
		pcall(GameTooltip.SetSpellByID, GameTooltip, id)
	elseif kind == "slot" then
		pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", id)
	elseif kind == "item" then
		pcall(GameTooltip.SetItemByID, GameTooltip, id)
	end
	GameTooltip:Show()
end

-- A charge spell's count (secret in combat: the game shows it), the recharge swipe while one is
-- coming back, and whether it's at full charges (b.fullCharges: the max is never secret, nor is
-- whether it's recharging).
local function Charges(b, bar, id, onCooldown)
	local ok, ch = pcall(C_Spell.GetSpellCharges, id)
	local max = ok and type(ch) == "table" and not ns.IsSecret(ch.maxCharges) and ch.maxCharges
	if not (type(max) == "number" and max > 1) then
		b.count:SetText("")
		b.fullCharges = nil
		return
	end
	local recharging = not ns.IsSecret(ch.isActive) and ch.isActive == true
	b.fullCharges = not ns.IsSecret(ch.isActive) and ch.isActive == false
	if recharging and not onCooldown then
		local okD, dur = pcall(C_Spell.GetSpellChargeDuration, id)
		if okD and (ns.IsSecret(dur) or dur) then
			pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)
			Countdown(b, dur)
		end
	end
	local n = ch.currentCharges
	if not ns.IsSecret(n) and n == 0 and not bar.zeroCharges then
		b.count:SetText("")
	else
		pcall(b.count.SetText, b.count, n)
	end
end

-- A spell's own buff on its icon -----------------------------------------------------------
-- While the buff a spell gives you is up (Death Wish, Shield Block, Slice and Dice), its icon can
-- show the buff instead (bar.active[key]): the game's own button over it, from an aura container
-- on the icon, so the game fills it in combat too and it hides with the icon. It has the buff's
-- time as a swipe in the bar's active colour, the time left, its stacks and the active glow (the
-- spell's alerts). The buff is the spell's name's (every rank; Auras.IDs). Containers are touched
-- only out of combat: a change in combat waits for its end.
local activePending = false

local function ActiveKey(bar, key)
	local Get = ns.Alerts.Get
	local own = B.Own(bar, key)
	return table.concat({ tostring(key), bar.size, tostring(bar.zoom), own.border or bar.border, own.borderColor or bar.borderColor,
		tostring(bar.countdown),
		tostring(bar.activeColor), tostring(bar.tooltip), Get("spells", key, "activeGlow"), Get("spells", key, "glowColor") }, ":")
end

local function ActiveStyler(bar, key)
	local own = B.Own(bar, key)
	local size, z, n = bar.size, bar.zoom or 0.08, own.border or bar.border or 1
	local er, eg, eb = B.BorderRGB(own.borderColor or bar.borderColor)
	local glow, color = ns.Alerts.Get("spells", key, "activeGlow"), ns.Alerts.Get("spells", key, "glowColor")
	local font = B.FONTS[bar.countdown]
	return function(button)
		if bar.tooltip == "off" then button:EnableMouse(false) end
		button:SetSize(size, size)
		local edge = button:CreateTexture(nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", -n, n)
		edge:SetPoint("BOTTOMRIGHT", n, -n)
		edge:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(z, 1 - z, z, 1 - z)
		button:SetIcon(icon)
		local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		cd:SetAllPoints()
		cd:SetDrawEdge(false)
		cd:SetReverse(true)
		cd:SetHideCountdownNumbers(true)
		cd:SetSwipeColor(B.SwipeRGBA(bar.activeColor))
		button:SetDurationCooldown(cd)
		local top = CreateFrame("Frame", nil, button)
		top:SetAllPoints()
		top:SetFrameLevel(button:GetFrameLevel() + 5)
		if font then
			local time = top:CreateFontString(nil, "OVERLAY", font)
			time:SetPoint("CENTER")
			button:SetDurationText(time)
		end
		local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		count:SetPoint("BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(count)
		if glow ~= "none" then
			local holder = CreateFrame("Frame", nil, button)
			holder:SetAllPoints()
			holder:SetFrameLevel(button:GetFrameLevel() + 2)
			local built = ns.Glow.Build(holder, glow, color, size)
			for _, g in ipairs(built.groups) do button:AddAuraShownAnimation(g) end
		end
	end
end

-- Sets an icon's buff slot for the spell it shows now (or none).
local function PlaceActive(b, bar)
	local want, ids
	if b.key and b.spellID and bar.active and bar.active[b.key] and ns.Auras and b.name then
		local set, count = ns.Auras.IDs(b.name)
		if count > 0 then want, ids = ActiveKey(bar, b.key), set end
	end
	if not (want or b.active) then return end
	if InCombatLockdown() then
		activePending = true
		return
	end
	if want and not b.active then
		local ok, c = pcall(CreateFrame, "AuraContainer", nil, b, "CustomAuraContainerTemplate")
		if not (ok and c) then return end
		c:SetUnit("player")
		c:SetSize(1, 1)
		c:SetPoint("TOPLEFT", b, "TOPLEFT")
		c:SetFrameLevel(b:GetFrameLevel() + 3)
		c:Show()
		b.active = { container = c, slots = {} }
	end
	local a = b.active
	if want then
		local slot = a.slots[want]
		if not slot then
			slot = a.container:AddAuraSlot(want, "HELPFUL", {
				candidateFilters = { includeSpellIDs = ids },
				initializeFrame = ActiveStyler(bar, b.key),
			})
			a.slots[want] = slot
		end
		a.container:SetAuraSlotCandidateFilters(want, { includeSpellIDs = ids })
		slot:ClearAllPoints()
		slot:SetAllPoints(b)
		a.container:SetAuraSlotEnabled(want, true)
	end
	for k in pairs(a.slots) do
		if k ~= want then a.container:SetAuraSlotEnabled(k, false) end
	end
end

-- A spell's own look on its bar (bar.looks[key]): border, borderColor, icon (a texture); nil
-- for the bar's.
function B.Own(bar, key)
	return bar.looks and bar.looks[key] or {}
end

function B.SetLook(bar, key, field, value)
	bar.looks = bar.looks or {}
	local own = bar.looks[key] or {}
	own[field] = value
	bar.looks[key] = next(own) and own or nil
	ns.Refresh()
end

function B.SetActive(bar, key, on)
	bar.active = bar.active or {}
	bar.active[key] = on or nil
	ns.Refresh()
end

-- A spell's state on its icon; returns whether it's on a real cooldown, and whether it's usable
-- (nil: the game didn't say).
local function SpellState(b, bar)
	local id = b.spellID
	local onCooldown, onGCD = false, false
	local ok, info = pcall(C_Spell.GetSpellCooldown, id)
	if ok and type(info) == "table" and not ns.IsSecret(info.isActive) and not ns.IsSecret(info.isOnGCD) then
		onGCD = info.isOnGCD == true
		onCooldown = info.isActive == true and not onGCD
	end
	b.icon:SetDesaturated(onCooldown and bar.grey)

	if onGCD and not bar.gcd then
		b.cd:Clear()
	else
		local okDur, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
		if not (okDur and (ns.IsSecret(dur) or dur) and pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)) then
			b.cd:Clear()
		end
		Countdown(b, onCooldown and okDur and dur or nil)
	end
	if onGCD then Countdown(b, nil) end

	local r, g, bl = 1, 1, 1
	local okRange, inRange = pcall(C_Spell.IsSpellInRange, id)
	local okUse, usable = pcall(C_Spell.IsSpellUsable, id)
	if not okUse or ns.IsSecret(usable) then usable = nil end
	if bar.red and okRange and not ns.IsSecret(inRange) and inRange == false then
		r, g, bl = 1, 0.3, 0.3
	elseif bar.dark and usable == false then
		r, g, bl = 0.4, 0.4, 0.4
	end
	b.icon:SetVertexColor(r, g, bl)
	Charges(b, bar, id, onCooldown)
	return onCooldown, usable
end

-- An equipment slot's or a bag item's state on its icon; returns whether it's on a real cooldown
-- (a 1.5 s one or shorter is the GCD).
local function ItemState(b, bar)
	local kind, id = B.Kind(b.key)
	if kind == "best" then kind, id = "item", B.ItemOf(b.key) end
	local ok, start, duration, enable
	if kind == "slot" then
		ok, start, duration, enable = pcall(GetInventoryItemCooldown, "player", id)
	else
		ok, start, duration, enable = pcall(C_Container.GetItemCooldown, id)
	end
	local plain = ok and not ns.IsSecret(start) and not ns.IsSecret(duration)
		and type(start) == "number" and type(duration) == "number"
	local enabled = ns.IsSecret(enable) or (enable ~= 0 and enable ~= false)
	local onCooldown, onGCD = false, false
	if plain and enabled and start > 0 and duration > 0 then
		onGCD = duration <= 1.5
		onCooldown = not onGCD
	end
	b.icon:SetDesaturated(onCooldown and bar.grey)
	if plain and (onCooldown or (onGCD and bar.gcd)) then
		b.cd:SetCooldown(start, duration)
	elseif not (ok and not plain and pcall(b.cd.SetCooldown, b.cd, start, duration)) then
		b.cd:Clear()
	end
	if b.useBinding then
		local dur
		if plain and onCooldown and C_DurationUtil.CreateDuration then
			local okD, d = pcall(C_DurationUtil.CreateDuration)
			if okD and d and pcall(d.SetTimeFromStart, d, start, duration) then dur = d end
		end
		Countdown(b, dur)
	end
	local okUse, usable = pcall(C_Item.IsUsableItem, B.ItemOf(b.key))
	if not okUse or ns.IsSecret(usable) then usable = nil end
	local v = (bar.dark and usable == false) and 0.4 or 1
	b.icon:SetVertexColor(v, v, v)
	local n = kind == "item" and B.ItemCount(id) or 0
	if kind == "item" and n == 0 then
		b.icon:SetDesaturated(true)
		b.icon:SetVertexColor(0.4, 0.4, 0.4)
		b.count:SetText("0")
	else
		b.count:SetText(n > 1 and tostring(n) or "")
	end
	if kind == "item" and n == 0 then usable = false end
	return onCooldown, usable
end

-- Reads an entry's state and shows it. Returns whether the icon should be shown.
local function Update(b, bar)
	if not b.known then return false end
	if b.space then return true end
	local onCooldown, usable = (b.spellID and SpellState or ItemState)(b, bar)
	if ns.Alerts then ns.Alerts.OnIcon(b, bar, onCooldown, usable) end
	b:SetAlpha(onCooldown and bar.cdAlpha or 1)
	if not (FormAllows(bar, b.key) and TalentAllows(bar, b.key)) then return false end
	local show = bar.show[b.key] or "always"
	if show == "ready" then return not onCooldown end
	if show == "usable" then return not onCooldown and usable ~= false end
	if show == "cooldown" then return onCooldown end
	return true
end

-- Places the shown icons, closing the gaps of hidden ones.
local function Layout(frame, bar)
	local step = bar.size + bar.gap
	local per = math.max(1, bar.perRow)
	local shown = {}
	for _, b in ipairs(frame.buttons) do
		if b.wanted then shown[#shown + 1] = b else b:Hide() end
	end
	local n = #shown
	local rows = math.ceil(n / per)
	for k, b in ipairs(shown) do
		local line, pos = math.floor((k - 1) / per), (k - 1) % per
		local count = (line == rows - 1) and (n - line * per) or per
		b:SetSize(bar.size, bar.size)
		b:ClearAllPoints()
		if not bar.vertical then
			if bar.grow == "LEFT" then
				b:SetPoint("TOPLEFT", frame, "TOPLEFT", pos * step, -line * step)
			elseif bar.grow == "RIGHT" then
				b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pos * step, -line * step)
			else
				b:SetPoint("TOP", frame, "TOP", (pos - (count - 1) / 2) * step, -line * step)
			end
		else
			if bar.grow == "LEFT" then
				b:SetPoint("TOPLEFT", frame, "TOPLEFT", line * step, -pos * step)
			elseif bar.grow == "RIGHT" then
				b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", line * step, pos * step)
			else
				b:SetPoint("LEFT", frame, "LEFT", line * step, -(pos - (count - 1) / 2) * step)
			end
		end
		b:Show()
	end
end

local function UpdateBar(frame, bar)
	local changed = false
	for _, b in ipairs(frame.buttons) do
		if b.key then
			local wanted = Update(b, bar)
			if wanted ~= b.wanted then
				b.wanted = wanted
				changed = true
			end
		end
	end
	if changed then Layout(frame, bar) end
end

-- One spell's icon (a range change comes per spell); the bar is laid out again if it hid or showed.
function B.UpdateSpell(spellID)
	local bar = B.BarOf(spellID)
	local frame = bar and frames[bar.id]
	if not (frame and frame:IsShown()) then return end
	for _, b in ipairs(frame.buttons) do
		if b.spellID == spellID then
			local wanted = Update(b, bar)
			if wanted ~= b.wanted then
				b.wanted = wanted
				Layout(frame, bar)
			end
		end
	end
end

function B.UpdateAll()
	if not ns.db then return end
	for _, bar in ipairs(ns.db.bars.list) do
		local frame = frames[bar.id]
		if frame and frame:IsShown() then UpdateBar(frame, bar) end
	end
end

-- The default place of the i-th bar: under the middle of the screen, one under another.
local function DefaultPos(i)
	return { "CENTER", "CENTER", 0, -200 - (i - 1) * 52 }
end

local function SavePos(frame)
	local point, _, relPoint, x, y = frame:GetPoint()
	local bar = B.Get(frame.barID)
	if bar then bar.pos = { point, relPoint, x, y } end
end

local function Frame(bar)
	local frame = frames[bar.id]
	if frame then return frame end
	frame = CreateFrame("Frame", nil, UIParent)
	frame.buttons = {}
	frame.barID = bar.id
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePos(self)
	end)
	frame.shade = frame:CreateTexture(nil, "BACKGROUND")
	frame.shade:SetPoint("TOPLEFT", -4, 4)
	frame.shade:SetPoint("BOTTOMRIGHT", 4, -4)
	frame.shade:SetColorTexture(0.3, 0.75, 0.95, 0.3)
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
	frames[bar.id] = frame
	return frame
end

-- Builds every bar for the profile in use (at login, and whenever settings, spells or the
-- profile change).
function B.Build()
	if not ns.db then return end
	Seed()
	local live = {}
	for i, bar in ipairs(ns.Enabled() and ns.db.bars.list or {}) do
		live[bar.id] = true
		B.FillLook(bar) -- bars made before a setting existed
		local frame = Frame(bar)
		local step = bar.size + bar.gap
		local per = math.max(1, bar.perRow)
		local n = math.max(1, #bar.spells)
		local cols, rows = math.min(n, per), math.ceil(n / per)
		if bar.vertical then cols, rows = rows, cols end
		frame:SetSize(cols * step - bar.gap, rows * step - bar.gap)
		local pos = bar.pos or DefaultPos(i)
		frame:ClearAllPoints()
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
		for j, key in ipairs(bar.spells) do
			local b = Button(frame, j)
			local kind, id = B.Kind(key)
			b.key = key
			b.spellID = kind == "spell" and id or nil
			b.space = kind == "space" or nil
			b.name = kind == "spell" and B.SpellName(id) or B.EntryName(key)
			-- A bag item you have none of: hidden, or shown greyed with "0" (the bar's choice).
			b.known = B.EntryKnown(key) or ((kind == "item" or kind == "best") and bar.emptyItems == "grey")
			b.wanted = nil
			b.icon:SetTexture(B.Own(bar, key).icon or B.EntryIcon(key))
			if b.spellID then pcall(C_Spell.EnableSpellRangeCheck, id, true) end
			B.ApplyLook(b, bar)
			b.bar = bar
			b:EnableMouse(bar.tooltip ~= "off" and not unlocked)
			pcall(PlaceActive, b, bar)
		end
		for j = #bar.spells + 1, #frame.buttons do
			frame.buttons[j].key, frame.buttons[j].spellID = nil, nil
			frame.buttons[j].wanted = false
			pcall(PlaceActive, frame.buttons[j], bar)
		end
		frame.label:SetText(bar.name)
		frame.shade:SetShown(unlocked)
		frame.label:SetShown(unlocked)
		frame:EnableMouse(unlocked)
		frame:Show()
		frame:SetAlpha(ns.Visibility.Alpha(bar))
		UpdateBar(frame, bar)
		Layout(frame, bar)
	end
	for id, frame in pairs(frames) do
		if not live[id] then frame:Hide() end
	end
	B.ApplyBlizzard()
end

-- A button's look: border, zoom, countdown size, keybind text.
function B.ApplyLook(b, bar)
	local z = bar.zoom or 0.08
	b.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	local own = B.Own(bar, b.key)
	local n = own.border or bar.border or 1
	if b.space then n = 0 end
	b.edge:ClearAllPoints()
	b.edge:SetPoint("TOPLEFT", -n, n)
	b.edge:SetPoint("BOTTOMRIGHT", n, -n)
	b.edge:SetColorTexture(B.BorderRGB(own.borderColor or bar.borderColor))
	b.edge:SetShown(n > 0)
	if b.space then b.cd:Clear() b.count:SetText("") end
	b.cd:SetDrawSwipe(bar.swipe ~= "off")
	b.cd:SetReverse(bar.swipe == "reverse")
	b.cd:SetDrawEdge(bar.edge and true or false)
	b.cd:SetSwipeColor(B.SwipeRGBA(bar.swipeColor))
	local font = B.FONTS[bar.countdown]
	TimeBinding(b, bar)
	b.cd:SetHideCountdownNumbers(font == nil or b.useBinding)
	pcall(b.cd.SetCountdownMillisecondsThreshold, b.cd, bar.thresholdDecimals and bar.threshold or 0)
	if font then pcall(b.cd.SetCountdownFont, b.cd, font) end
	B.ShowKey(b, bar)
end

function B.ShowKey(b, bar)
	local text
	if bar.keybind and b.key and ns.Keybinds then
		local kind = B.Kind(b.key)
		text = ns.Keybinds.For(kind == "spell" and b.name or ("item:" .. tostring(B.ItemOf(b.key))))
	end
	b.keyText:SetText(text or "")
end

-- Every icon's keybind text again (Keybinds.lua, when bars or bindings change).
function B.ShowKeys()
	if not ns.db then return end
	for _, bar in ipairs(ns.db.bars.list) do
		local frame = frames[bar.id]
		if frame then
			for _, b in ipairs(frame.buttons) do
				if b.key then B.ShowKey(b, bar) end
			end
		end
	end
end

-- Every bar's opacity (Visibility.lua: combat and target changes).
function B.ApplyAlpha()
	if not ns.db then return end
	for _, bar in ipairs(ns.db.bars.list) do
		local frame = frames[bar.id]
		if frame then frame:SetAlpha(ns.Visibility.Alpha(bar)) end
	end
end

-- Unlock: every bar shows its name and a shade, and can be dragged; lock again to keep it.
function B.SetUnlocked(on)
	unlocked = on and true or false
	ns.Refresh()
	ns.Print(unlocked and "icon bars and buff groups unlocked: drag them, then /lecdm move (or Lock on their tab) to lock them."
		or "icon bars and buff groups locked.")
	if ns.Window then ns.Window.Refresh() end
end

function B.IsUnlocked()
	return unlocked
end

-- Blizzard's Essential and Utility viewers: invisible while Lecdm's bars are on and the setting
-- is on, given their own alpha back otherwise. Set again after Edit Mode, which reapplies its
-- opacity setting, and after loading screens.
local function Fade(globals, want)
	for _, global in ipairs(globals) do
		local viewer = _G[global]
		if viewer then
			if want then
				pcall(viewer.SetAlpha, viewer, 0)
				faded[viewer] = true
			elseif faded[viewer] then
				pcall(viewer.SetAlpha, viewer, 1)
				faded[viewer] = nil
			end
		end
	end
end

-- Blizzard's buff icons and timer bars: invisible only in "hide" mode (Buffs tab, Hosted.lua);
-- taken into Lecdm, they must stay visible. Hidden, they keep running, so the listener still
-- hears them.
function B.ApplyBlizzard()
	local on = ns.Enabled()
	Fade(B.BLIZZARD, on and ns.db.bars.hideBlizzard and #ns.db.bars.list > 0)
	for _, global in ipairs(B.BLIZZARD_BUFFS) do
		Fade({ global }, on and ns.Hosted and ns.Hosted.WantsHidden(global))
	end
end

-- Spellbook spells with a cooldown, by skill line: { name, spells = { spellID ... } }. Out of
-- combat (for the spell picker).
function B.Spellbook()
	local lines = {}
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return lines end
	local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
	local okN, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
	for i = 1, (okN and not ns.IsSecret(count) and count) or 0 do
		local okL, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, i)
		if okL and type(line) == "table" and not line.shouldHide then
			local entry = { name = line.name, spells = {} }
			for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
				local okI, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
				if okI and type(item) == "table" and item.itemType == spellType and not item.isPassive and item.spellID then
					local okCD, base = pcall(GetSpellBaseCooldown, item.spellID)
					if not okCD or ns.IsSecret(base) or (base or 0) > 0 then table.insert(entry.spells, item.spellID) end
				end
			end
			if #entry.spells > 0 then table.insert(lines, entry) end
		end
	end
	return lines
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE",
	"ACTIONBAR_UPDATE_USABLE", "PLAYER_TARGET_CHANGED", "SPELL_RANGE_CHECK_UPDATE", "BAG_UPDATE_COOLDOWN",
	"UPDATE_SHAPESHIFT_FORM" }) do
	pcall(events.RegisterEvent, events, e)
end
for _, e in ipairs({ "SPELLS_CHANGED", "COOLDOWN_VIEWER_DATA_LOADED", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
	"BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if not ns.db then return end
	if event == "SPELL_RANGE_CHECK_UPDATE" and not ns.IsSecret(arg) and type(arg) == "number" then
		B.UpdateSpell(arg)
		return
	end
	if event == "SPELLS_CHANGED" or event == "COOLDOWN_VIEWER_DATA_LOADED" then
		ns.Catalogue.Build()
		B.Build()
		-- The buff groups seed from Blizzard's list too, and learn a spell's highest rank.
		if ns.Auras then ns.Auras.Build() end
	elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
		B.Build()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if activePending then
			activePending = false
			B.Build()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		B.ApplyBlizzard()
	else
		B.UpdateAll()
	end
end)
