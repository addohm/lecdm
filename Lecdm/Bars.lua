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

B.SHOW = { { "always", "Always" }, { "ready", "Only when ready" }, { "cooldown", "Only on cooldown" } }
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
	local bar = { id = "bar" .. bars.nextID, name = name, spells = {}, show = {},
		size = 40, gap = 4, grow = "CENTER", vertical = false, perRow = 12, gcd = true, emptyItems = "hide" }
	table.insert(bars.list, bar)
	return bar
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
	end
	if on then table.insert(bar.spells, spellID) end
	ns.Refresh()
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
	if kind == "slot" then
		local itemID = SlotItem(id)
		return (B.SLOTS[id] or ("Slot " .. id)) .. ": " .. (itemID and ItemName(itemID) or "empty")
	end
	return ItemName(id)
end

function B.EntryIcon(key)
	local kind, id = B.Kind(key)
	if kind == "spell" then return B.SpellIcon(id) end
	local itemID = B.ItemOf(key)
	if not itemID then return 134400 end
	local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
	return ok and not ns.IsSecret(icon) and icon or 134400
end

-- Shown at all: a spell learned, an equipped item with a use effect, an item in the bags.
function B.EntryKnown(key)
	local kind, id = B.Kind(key)
	if kind == "spell" then return B.Known(id) end
	if kind == "slot" then return HasUse(SlotItem(id)) end
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
	-- The alerts' glow (Alerts.lua), above the swipe, below the text.
	b.glow = CreateFrame("Frame", nil, b)
	b.glow:SetAllPoints()
	b.glow:SetFrameLevel(b.cd:GetFrameLevel() + 1)
	b.over:SetFrameLevel(b.cd:GetFrameLevel() + 2)
	frame.buttons[i] = b
	return b
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
	b.icon:SetDesaturated(onCooldown)

	if onGCD and not bar.gcd then
		b.cd:Clear()
	else
		local okDur, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
		if not (okDur and (ns.IsSecret(dur) or dur) and pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)) then
			b.cd:Clear()
		end
	end

	local r, g, bl = 1, 1, 1
	local okRange, inRange = pcall(C_Spell.IsSpellInRange, id)
	local okUse, usable = pcall(C_Spell.IsSpellUsable, id)
	if not okUse or ns.IsSecret(usable) then usable = nil end
	if okRange and not ns.IsSecret(inRange) and inRange == false then
		r, g, bl = 1, 0.3, 0.3
	elseif usable == false then
		r, g, bl = 0.4, 0.4, 0.4
	end
	b.icon:SetVertexColor(r, g, bl)
	b.count:SetText("")
	return onCooldown, usable
end

-- An equipment slot's or a bag item's state on its icon; returns whether it's on a real cooldown
-- (a 1.5 s one or shorter is the GCD).
local function ItemState(b, bar)
	local kind, id = B.Kind(b.key)
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
	b.icon:SetDesaturated(onCooldown)
	if plain and (onCooldown or (onGCD and bar.gcd)) then
		b.cd:SetCooldown(start, duration)
	elseif not (ok and not plain and pcall(b.cd.SetCooldown, b.cd, start, duration)) then
		b.cd:Clear()
	end
	local okUse, usable = pcall(C_Item.IsUsableItem, B.ItemOf(b.key))
	if not okUse or ns.IsSecret(usable) then usable = nil end
	local v = usable == false and 0.4 or 1
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
	local onCooldown, usable = (b.spellID and SpellState or ItemState)(b, bar)
	if ns.Alerts then ns.Alerts.OnIcon(b, bar, onCooldown, usable) end
	local show = bar.show[b.key] or "always"
	if show == "ready" then return not onCooldown end
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
		bar.emptyItems = bar.emptyItems or "hide" -- bars made before the setting
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
			b.name = kind == "spell" and B.SpellName(id) or B.EntryName(key)
			-- A bag item you have none of: hidden, or shown greyed with "0" (the bar's choice).
			b.known = B.EntryKnown(key) or (kind == "item" and bar.emptyItems == "grey")
			b.wanted = nil
			b.icon:SetTexture(B.EntryIcon(key))
			if b.spellID then pcall(C_Spell.EnableSpellRangeCheck, id, true) end
		end
		for j = #bar.spells + 1, #frame.buttons do
			frame.buttons[j].key, frame.buttons[j].spellID = nil, nil
			frame.buttons[j].wanted = false
		end
		frame.label:SetText(bar.name)
		frame.shade:SetShown(unlocked)
		frame.label:SetShown(unlocked)
		frame:EnableMouse(unlocked)
		frame:Show()
		UpdateBar(frame, bar)
		Layout(frame, bar)
	end
	for id, frame in pairs(frames) do
		if not live[id] then frame:Hide() end
	end
	B.ApplyBlizzard()
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
	"ACTIONBAR_UPDATE_USABLE", "PLAYER_TARGET_CHANGED", "SPELL_RANGE_CHECK_UPDATE", "BAG_UPDATE_COOLDOWN" }) do
	pcall(events.RegisterEvent, events, e)
end
for _, e in ipairs({ "SPELLS_CHANGED", "COOLDOWN_VIEWER_DATA_LOADED", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
	"BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
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
	elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		B.ApplyBlizzard()
	else
		B.UpdateAll()
	end
end)
