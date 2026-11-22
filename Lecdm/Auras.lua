-- Lecdm: buff groups (the Buffs tab). Buffs on you, from anyone, shown by Blizzard's aura
-- containers (CustomAuraContainerTemplate): Lecdm names the spell IDs, the game fills the icons
-- or timer bars itself, in combat too (proven on Forever by the owner's buff addon). Lecdm never
-- reads aura data to show them; the one reader is A.ReadBuffs(), out of combat only, for the
-- checklist and for learning a buff's IDs.
-- ns.db.buffs.list: groups { id, name, style = "icons" | "bars", entries = { buff name ... },
-- size, gap, grow, vertical, perRow, barWidth, pos }. An entry is a buff's name. Its spell IDs
-- (every rank, whoever cast it) are Blizzard's list's, the spell's own (C_Spell.GetSpellInfo by
-- name: your highest rank) and every ID seen on you under that name out of combat
-- (LecdmDB.auraIDs[name], account-wide, learned as you play).
-- Each entry is its own aura group in the group's container, with layoutIndex = its place, so the
-- player's order holds and the container closes the gaps of buffs that aren't up. A button's
-- parts are fixed when the game creates it (initializeFrame), so aura group keys carry the look
-- (style and size); a changed look switches to new aura groups (they can't be removed, only
-- disabled). Containers are touched only out of combat; a change in combat waits for its end
-- (their buttons are closed to addons while auras are secret).
local _, ns = ...

local A = {}
ns.Auras = A

A.STYLES = { { "icons", "Icons" }, { "bars", "Timer bars" } }

local frames = {} -- group id -> { anchor, container, made = { [aura group key] = true } }
local pending = false
local unavailable = false

-- Groups ---------------------------------------------------------------------------------

function A.NewGroup(name)
	local buffs = ns.db.buffs
	buffs.nextID = (buffs.nextID or 1) + 1
	local group = { id = "buffs" .. buffs.nextID, name = name, entries = {} }
	A.FillLook(group)
	table.insert(buffs.list, group)
	return group
end

function A.Get(id)
	for i, group in ipairs(ns.db.buffs.list) do
		if group.id == id then return group, i end
	end
end

-- The group a buff is in, and its place there.
function A.GroupOf(name)
	for _, group in ipairs(ns.db.buffs.list) do
		for i, n in ipairs(group.entries) do
			if n == name then return group, i end
		end
	end
end

-- Puts a buff in a group (taking it out of any other) or takes it out.
function A.SetInGroup(group, name, on)
	local other, i = A.GroupOf(name)
	if other then table.remove(other.entries, i) end
	if on then table.insert(group.entries, name) end
	ns.Refresh()
end

function A.MoveEntry(group, index, dir)
	local j = index + dir
	if j < 1 or j > #group.entries then return end
	group.entries[index], group.entries[j] = group.entries[j], group.entries[index]
	ns.Refresh()
end

-- How a buff in a group shows: "up" (while it's up; the rest close up), "keep" (a fixed place:
-- the game's icon while it's up, a copy and the missing glow while it isn't) or "missing" (a
-- fixed place showing only the copy, while it's missing). The looks are the buff's alerts'.
A.MODES = { { "up", "While it's up" }, { "keep", "Keep up" }, { "missing", "Only while missing" } }

function A.Mode(group, name)
	return group.modes and group.modes[name] or "up"
end

function A.SetMode(group, name, mode)
	group.modes = group.modes or {}
	group.modes[name] = mode ~= "up" and mode or nil
	ns.Refresh()
end

-- /lecdm buff ----------------------------------------------------------------------------

-- The buff a typed name means (any case): a buff group's or Lecdm's list's, exactly, else the
-- first whose name has it in it (so "fort" is Power Word: Fortitude).
function A.FindName(text)
	text = (text or ""):lower()
	if text == "" then return nil end
	local candidates = {}
	for _, group in ipairs(ns.db.buffs.list) do
		for _, n in ipairs(group.entries) do candidates[#candidates + 1] = n end
	end
	for _, section in ipairs(ns.BuffList.sections) do
		for _, e in ipairs(section.entries) do candidates[#candidates + 1] = e.name end
	end
	for _, n in ipairs(candidates) do
		if n:lower() == text then return n end
	end
	for _, n in ipairs(candidates) do
		if n:lower():find(text, 1, true) then return n end
	end
end

local MODE_WORDS = { keep = true, missing = true, up = true, out = true }

-- /lecdm buff: every group's buffs and how each shows. /lecdm buff <name> keep | missing | up:
-- how it shows (a buff in no group goes in the first); out: takes it out.
function A.Slash(rest)
	local text, word = (rest or ""):match("^(.-)%s+(%S+)$")
	if not (text and MODE_WORDS[word]) then text, word = rest or "", nil end
	if text == "" then
		for _, group in ipairs(ns.db.buffs.list) do
			local parts = {}
			for _, n in ipairs(group.entries) do parts[#parts + 1] = n .. " (" .. ns.Alerts.Label(A.MODES, A.Mode(group, n)):lower() .. ")" end
			ns.Print(group.name .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "no buffs"))
		end
		if #ns.db.buffs.list == 0 then ns.Print("no buff groups.") end
		ns.Print("/lecdm buff <name> keep | missing | up | out, e.g. /lecdm buff fort keep")
		return
	end
	local name = A.FindName(text)
	if not name then
		ns.Print("no buff called '" .. text .. "' in a buff group or Lecdm's list.")
		return
	end
	local group = A.GroupOf(name)
	if word == "out" then
		if group then A.SetInGroup(group, name, false) end
		ns.Print(name .. ": in no buff group.")
		return
	end
	if word then
		if not group then
			group = ns.db.buffs.list[1]
			if not group then
				ns.Print("there's no buff group to put " .. name .. " in: make one on the Buffs tab.")
				return
			end
			local _, count = A.IDs(name)
			if count == 0 and not A.EnchantSlot(name) then
				ns.Print("Lecdm doesn't know " .. name .. "'s spell yet: add it from the buffs on you (Buffs tab).")
				return
			end
			A.SetInGroup(group, name, true)
		end
		A.SetMode(group, name, word)
	end
	if group then
		ns.Print(name .. ": " .. ns.Alerts.Label(A.MODES, A.Mode(group, name)):lower() .. ", in " .. group.name .. ".")
	else
		ns.Print(name .. ": in no buff group.")
	end
end

function A.Delete(id)
	local _, i = A.Get(id)
	if i then table.remove(ns.db.buffs.list, i) end
	ns.Refresh()
end

-- Blizzard's list: its entries for auras on you (selfAura), learned or not.
function A.BlizzardBuffs()
	local list, seen = {}, {}
	for _, section in ipairs(ns.Catalogue.sections) do
		if section.value == 2 or section.value == 3 then -- Tracked buffs, tracked bars
			for _, id in ipairs(section.ids) do
				local e = ns.Catalogue.byID[id]
				if e.selfAura and e.spellID and not seen[e.name] then
					seen[e.name] = true
					list[#list + 1] = e
				end
			end
		end
	end
	return list
end

-- The first buff group, filled with your learned buffs from Blizzard's list, once per profile.
local function Seed()
	local buffs = ns.db.buffs
	if buffs.seeded then return end
	local blizzard = A.BlizzardBuffs()
	if #blizzard == 0 then return end
	buffs.seeded = true
	local group = A.NewGroup("Buffs")
	for _, e in ipairs(blizzard) do
		if e.known and not A.GroupOf(e.name) then table.insert(group.entries, e.name) end
	end
end

function A.StartOver()
	ns.db.buffs.list = {}
	ns.db.buffs.seeded = false
	Seed()
	ns.Refresh()
end

-- A buff's spell IDs and icon --------------------------------------------------------------

local function Learned()
	LecdmDB.auraIDs = LecdmDB.auraIDs or {}
	return LecdmDB.auraIDs
end

-- Remembers an ID seen under a name; true if it's new.
function A.Learn(name, spellID)
	local learned = Learned()
	learned[name] = learned[name] or {}
	if learned[name][spellID] then return false end
	learned[name][spellID] = true
	return true
end

-- Every spell ID for a buff name (a set), and how many: Lecdm's list's (every rank, and its
-- other names: Prayer of Fortitude for Power Word: Fortitude), what's been seen on you,
-- Blizzard's list's, and the spell's own.
function A.IDs(name)
	local ids, n = {}, 0
	local function Add(id)
		if type(id) == "number" and not ns.IsSecret(id) and not ids[id] then
			ids[id] = true
			n = n + 1
		end
	end
	for _, n in ipairs(ns.BuffList.Names(name)) do
		for _, id in ipairs(ns.BuffIDs[n] or {}) do Add(id) end
	end
	for id in pairs(Learned()[name] or {}) do Add(id) end
	for _, e in pairs(ns.Catalogue.byID) do
		if e.name == name then
			for _, id in ipairs(e.ids or {}) do Add(id) end
		end
	end
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	if ok and type(info) == "table" then Add(info.spellID) end
	return ids, n
end

-- A weapon enchant entry's container slot (AuraContainerItemEnchantmentSlot), or nil.
function A.EnchantSlot(name)
	local e = ns.BuffList.Entry(name)
	if e and e.enchant and AuraContainerItemEnchantmentSlot then return AuraContainerItemEnchantmentSlot[e.enchant] end
end

local INVSLOT = { MainHand = 16, OffHand = 17 }

-- The weapon enchants on you now, out of combat: { name, expires } for each.
function A.ReadEnchants()
	local list = {}
	if InCombatLockdown() or not GetWeaponEnchantInfo then return list end
	local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
	if not ok then return list end
	local now = GetTime()
	local function Add(has, ms, name)
		if ns.IsSecret(has) or ns.IsSecret(ms) or not has then return end
		list[#list + 1] = { name = name, expires = type(ms) == "number" and now + ms / 1000 or nil, enchant = true }
	end
	Add(hasMain, mainMs, "Main hand enchant")
	Add(hasOff, offMs, "Off hand enchant")
	return list
end

function A.Icon(name)
	local e = ns.BuffList.Entry(name)
	if e and e.enchant then
		local ok, icon = pcall(GetInventoryItemTexture, "player", INVSLOT[e.enchant])
		return ok and not ns.IsSecret(icon) and icon or 136244
	end
	local icons = LecdmDB.auraIcons or {}
	if icons[name] then return icons[name] end
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	if ok and type(info) == "table" and not ns.IsSecret(info.iconID) and info.iconID then return info.iconID end
	for _, e in pairs(ns.Catalogue.byID) do
		if e.name == name and e.spellID then return ns.Bars.SpellIcon(e.spellID) end
	end
	local ids = ns.BuffIDs[name]
	if ids and ids[1] then return ns.Bars.SpellIcon(ids[1]) end
	return 134400
end

-- The buffs on you now, out of combat (in combat, and where the game refuses, nothing): each
-- { name, spellID, icon, duration, expires }, once per name (expires: GetTime() at its end, 0 or
-- nil for none).
function A.ReadBuffs()
	local list, seen = {}, {}
	if InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
	for i = 1, 40 do
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or type(aura) ~= "table" then break end
		local name, id, icon, duration, expires = aura.name, aura.spellId, aura.icon, aura.duration, aura.expirationTime
		if not (ns.IsSecret(name) or ns.IsSecret(id) or ns.IsSecret(icon)) and name and id and not seen[name] then
			seen[name] = true
			if ns.IsSecret(duration) or type(duration) ~= "number" then duration = nil end
			if ns.IsSecret(expires) or type(expires) ~= "number" then expires = nil end
			list[#list + 1] = { name = name, spellID = id, icon = icon, duration = duration, expires = expires }
		end
	end
	return list
end

-- A buff's full duration, learned out of combat (for the warning glow's timing).
function A.Duration(name)
	return LecdmDB.auraDur and LecdmDB.auraDur[name]
end

-- Out of combat, each buff on you that's in a group teaches its ID (another rank, another
-- caster's) and its full duration; the containers are set again when one is new. The alerts
-- hear what came and went.
local function LearnFromBuffs()
	local changed = false
	LecdmDB.auraIcons = LecdmDB.auraIcons or {}
	LecdmDB.auraDur = LecdmDB.auraDur or {}
	local buffs = A.ReadBuffs()
	for _, b in ipairs(buffs) do
		if A.GroupOf(b.name) then
			if A.Learn(b.name, b.spellID) then changed = true end
			LecdmDB.auraIcons[b.name] = b.icon
			if b.duration and b.duration > 0 and LecdmDB.auraDur[b.name] ~= b.duration then
				LecdmDB.auraDur[b.name] = b.duration
				changed = true
			end
		end
	end
	if ns.Alerts then
		local all = {}
		for _, b in ipairs(buffs) do all[#all + 1] = b end
		for _, b in ipairs(A.ReadEnchants()) do all[#all + 1] = b end
		ns.Alerts.OnBuffsRead(all)
	end
	return changed
end

-- The display -----------------------------------------------------------------------------

-- The time text's colour: red under `warn` seconds, white above (the game applies the curve in
-- combat too); faded above with the icon while it's up (alpha), full strength under.
local function WarnCurve(warn, alpha)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, CreateColor(1, 0.25, 0.25, 1))
	curve:AddPoint(warn, CreateColor(1, 1, 1, alpha or 1))
	return curve
end

local function Margin(size)
	return math.ceil(size * 0.25) + 3 -- how far any glow style reaches past the icon
end

-- The warning glow, at the warning time, in combat too (the owner's own technique, proven on
-- Forever): the game drives an invisible bar from the buff's time left (SetDurationBar,
-- RemainingTime), its fill shrinking k px a second, placed so the fill's end crosses the glow's
-- area as the time left goes from warn + T to warn. A window frame runs from the fill's end to
-- the bar's end inside a frame clipped to the glow's area, so what's in it shows only under the
-- warning time. Lecdm never learns the time left: the game does the sizing. total: the buff's
-- full duration (learned out of combat); without one there's no warning glow.
-- reveal (an icon faded or grey while it's up): { z, n, r, g, b } (zoom, border size and colour);
-- the window then also holds the real icon at full strength, so the icon "comes back" at the
-- warning time. Returns the window's host (its icon in host.icon), or nil if it can't be timed.
local function AddTimedGlow(button, glow, color, size, warn, total, reveal)
	if (glow == "none" and not reveal) or not total or warn <= 0 or total - warn < 2 then return end
	local margin = Margin(size)
	local span = size + 2 * margin
	local k = math.min(span / 0.5, 100000 / total) -- px per second; caps the bar near 100000 px
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(1, 1, 1, 0)
	bar:SetMinMaxValues(0, total)
	bar:SetSize(k * total, 1)
	bar:SetPoint("LEFT", button, "LEFT", -margin - k * warn, 0)
	button:SetDurationBar(bar, {
		direction = Enum.StatusBarTimerDirection.RemainingTime,
		interpolation = Enum.StatusBarInterpolation.Immediate,
	})
	local area = CreateFrame("Frame", nil, button)
	area:SetFrameLevel(button:GetFrameLevel() + 3)
	area:SetPoint("TOPLEFT", button, "TOPLEFT", -margin, margin)
	area:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", margin, -margin)
	area:SetClipsChildren(true)
	local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
	window:SetHeight(span)
	window:SetPoint("LEFT", bar:GetStatusBarTexture(), "RIGHT")
	window:SetPoint("RIGHT", bar, "RIGHT", 1, 0)
	window:SetClipsChildren(true)
	local host = CreateFrame("Frame", nil, window)
	host:SetAllPoints(button)
	if reveal then
		local z, n = reveal[1], reveal[2]
		local edge = host:CreateTexture(nil, "BACKGROUND")
		edge:SetPoint("TOPLEFT", -n, n)
		edge:SetPoint("BOTTOMRIGHT", n, -n)
		edge:SetColorTexture(reveal[3], reveal[4], reveal[5], n > 0 and 1 or 0)
		host.icon = host:CreateTexture(nil, "ARTWORK")
		host.icon:SetAllPoints()
		host.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	end
	if glow ~= "none" then
		local built = ns.Glow.Build(host, glow, color, size)
		-- Its animations start with the buff; the clipping keeps them out of sight until the warning.
		for _, g in ipairs(built.groups) do button:AddAuraShownAnimation(g) end
	end
	return host
end

-- The glow at a number of stacks, in combat too: the game drives an invisible bar from the buff's
-- stacks (SetApplicationBar), its fill growing k px a stack (k: the glow's span). Windows run
-- from the bar's start to the fill's end ("at least N": open once the fill passes N) and from the
-- fill's end to the bar's end ("fewer than N"), each inside a frame clipped to the glow's area;
-- "exactly N" nests one in the other. The game does the sizing; Lecdm never learns the stacks.
A.STACK_OPS = { { "<", "Fewer than" }, { "<=", "At most" }, { "=", "Exactly" }, { ">=", "At least" }, { ">", "More than" } }
A.STACK_COUNTS = {}
for i = 1, 20 do A.STACK_COUNTS[i] = { i, tostring(i) } end

local function AddStackGlow(button, glow, color, size, op, n)
	if glow == "none" or not op or not n then return end
	-- As thresholds: open at least from `from` stacks, and below `below` (nil: no limit).
	local from, below
	if op == "<" then below = n elseif op == "<=" then below = n + 1
	elseif op == "=" then from, below = n, n + 1 elseif op == ">=" then from = n else from = n + 1 end
	local margin = Margin(size)
	local span = size + 2 * margin
	local k = span
	local max = math.max(n + 2, 30)
	local edge = from or below
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(1, 1, 1, 0)
	bar:SetSize(k * max, 1)
	-- The fill's end at `edge` stacks sits at the area's right edge.
	bar:SetPoint("LEFT", button, "LEFT", -margin + span - k * edge, 0)
	button:SetApplicationBar(bar, { minApplications = 0, maxApplications = max,
		interpolation = Enum.StatusBarInterpolation.Immediate })
	local fill = bar:GetStatusBarTexture()
	local parent = button
	local function Area()
		local area = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
		area:SetFrameLevel(button:GetFrameLevel() + 3)
		area:SetPoint("TOPLEFT", button, "TOPLEFT", -margin, margin)
		area:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", margin, -margin)
		area:SetClipsChildren(true)
		return area
	end
	if from then
		local area = Area()
		local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
		window:SetHeight(span)
		window:SetPoint("LEFT", bar, "LEFT")
		window:SetPoint("RIGHT", fill, "RIGHT", k * (edge - from), 0)
		window:SetClipsChildren(true)
		parent = window
	end
	if below then
		local area = Area()
		local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
		window:SetHeight(span)
		window:SetPoint("LEFT", fill, "RIGHT", k * (edge - below), 0)
		window:SetPoint("RIGHT", bar, "RIGHT", 1, 0)
		window:SetClipsChildren(true)
		parent = window
	end
	local host = CreateFrame("Frame", nil, parent)
	host:SetAllPoints(button)
	local built = ns.Glow.Build(host, glow, color, size)
	for _, g in ipairs(built.groups) do button:AddAuraShownAnimation(g) end
end

-- A buff entry's alert look: what its button's parts depend on (part of its aura group's key).
function A.AlertLook(name)
	local Get = ns.Alerts.Get
	local total = A.Duration(name) or 0
	return Get("buffs", name, "upGlow") .. ":" .. Get("buffs", name, "glowColor") .. ":" .. ns.Alerts.Warn(name)
		.. ":" .. Get("buffs", name, "warnGlow") .. ":" .. total
		.. ":" .. Get("buffs", name, "upAlpha") .. ":" .. tostring(Get("buffs", name, "upGrey"))
		.. ":" .. Get("buffs", name, "stackGlow") .. ":" .. Get("buffs", name, "stackOp") .. Get("buffs", name, "stackCount")
end

-- A group's look and visibility (also for groups made before a setting existed).
A.LOOK = {
	style = "icons", size = 32, gap = 4, grow = "CENTER", vertical = false, perRow = 12, barWidth = 200,
	border = 1, borderColor = "black", zoom = 0.08, timeText = "small",
	barTexture = "blizzard", barColor = "blue", barBg = 0.5, barIcon = true, barName = true, barTime = true,
	showWhen = "always", alpha = 1, oocAlpha = 1, tooltip = "on", swipe = "normal", swipeColor = "dark",
}
function A.FillLook(group)
	for k, v in pairs(A.LOOK) do
		if group[k] == nil then group[k] = v end
	end
end

A.TEXTURES = { { "blizzard", "Blizzard" }, { "flat", "Flat" }, { "smooth", "Smooth" } }
local TEXTURE_FILES = {
	blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
	flat = "Interface\\Buttons\\WHITE8X8",
	smooth = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}
A.BAR_COLORS = { { "blue", "Blue" }, { "class", "Class colour" }, { "gold", "Gold" }, { "green", "Green" },
	{ "red", "Red" }, { "purple", "Purple" }, { "white", "White" } }
local BAR_RGB = { blue = { 0.25, 0.6, 1 }, gold = { 1, 0.75, 0.1 }, green = { 0.25, 0.8, 0.3 }, red = { 0.9, 0.25, 0.2 },
	purple = { 0.65, 0.4, 1 }, white = { 0.85, 0.85, 0.85 } }
A.BG = { { 0, "None" }, { 0.25, "25%" }, { 0.5, "50%" }, { 0.75, "75%" } }

local function BarRGB(color)
	if color == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	local c = BAR_RGB[color] or BAR_RGB.blue
	return c[1], c[2], c[3]
end

-- What a group's buttons' parts depend on, besides the alerts (part of the aura group key).
function A.LookKey(group)
	local bars = group.style == "bars"
	local parts = { group.style, group.size, bars and group.barWidth or 0, group.border, group.borderColor,
		group.zoom, group.timeText, group.tooltip, group.swipe, group.swipeColor }
	if bars then
		for _, k in ipairs({ "barTexture", "barColor", "barBg", "barIcon", "barName", "barTime" }) do
			parts[#parts + 1] = tostring(group[k])
		end
	end
	for i, v in ipairs(parts) do parts[i] = tostring(v) end
	return table.concat(parts, ":")
end

-- The parts of one of the game's aura buttons, built once when the game makes it.
-- While the buff is up, its "face" (border, icon, swipe, timer bar) has the buff's look: its
-- opacity (upAlpha) and greyed or not (upGrey); the glows stay at full strength. An icon comes
-- back to full strength at the warning time, in combat too, once the buff's duration is known:
-- the timed glow's window then holds the real icon (the game fills it; the face shows the buff's
-- own icon, faded), and the time text brightens with the curve. Timer bars keep their look.
local function Styler(group, name)
	local size, bars, width = group.size, group.style == "bars", group.barWidth
	local Get = ns.Alerts.Get
	local upGlow, color = Get("buffs", name, "upGlow"), Get("buffs", name, "glowColor")
	local warn, warnGlow = ns.Alerts.Warn(name), Get("buffs", name, "warnGlow")
	local alpha, grey = Get("buffs", name, "upAlpha") or 1, Get("buffs", name, "upGrey") and true or false
	local faded = alpha < 1 or grey
	local total = A.Duration(name)
	local timeOptions = warn > 0 and { textColor = { curve = WarnCurve(warn, bars and 1 or alpha), property = Enum.DurationTextBindingProperty.RemainingDuration } } or nil
	local font = ns.Bars.FONTS[group.timeText]
	local z, n = group.zoom or 0.08, group.border or 1
	local er, eg, eb = ns.Bars.BorderRGB(group.borderColor)
	local iconTexture = A.Icon(name)
	return function(button)
		-- The game's tooltip on hover (its own): off lets clicks through.
		if group.tooltip == "off" then
			button:EnableMouse(false)
		elseif group.tooltip == "ooc" and button.SetHideTooltipInCombat then
			button:SetHideTooltipInCombat(true)
		end
		local face = CreateFrame("Frame", nil, button)
		face:SetAllPoints(button)
		face:SetFrameLevel(button:GetFrameLevel() + 1)
		face:SetAlpha(alpha)
		local edge = face:CreateTexture(nil, "BACKGROUND")
		local icon = face:CreateTexture(nil, "ARTWORK")
		icon:SetTexCoord(z, 1 - z, z, 1 - z)
		icon:SetDesaturated(grey)
		local top = CreateFrame("Frame", nil, button)
		top:SetAllPoints(button)
		top:SetFrameLevel(button:GetFrameLevel() + 5)
		local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		count:SetAlpha(alpha)
		button:SetApplicationCount(count)
		if bars then
			-- A timer bar: the icon at the left (or none), the bar draining to the right with the
			-- buff's name and the time left; the game drives the bar (SetTimerDuration).
			button:SetIcon(icon)
			button:SetSize(width, size)
			local iconW = group.barIcon and size or 0
			icon:SetSize(math.max(iconW, 1), size)
			icon:SetPoint("LEFT")
			icon:SetShown(group.barIcon)
			edge:SetPoint("TOPLEFT", button, -n, n)
			edge:SetPoint("BOTTOMRIGHT", button, n, -n)
			edge:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
			local bar = CreateFrame("StatusBar", nil, face)
			bar:SetPoint("TOPLEFT", button, "TOPLEFT", iconW > 0 and (iconW + 1) or 0, 0)
			bar:SetPoint("BOTTOMRIGHT")
			bar:SetStatusBarTexture(TEXTURE_FILES[group.barTexture] or TEXTURE_FILES.blizzard)
			if grey then bar:SetStatusBarColor(0.5, 0.5, 0.5) else bar:SetStatusBarColor(BarRGB(group.barColor)) end
			local bg = bar:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0, 0, 0, group.barBg or 0.5)
			button:SetDurationBar(bar, {
				direction = Enum.StatusBarTimerDirection.RemainingTime,
				interpolation = Enum.StatusBarInterpolation.Immediate,
			})
			local barTop = CreateFrame("Frame", nil, bar)
			barTop:SetAllPoints(bar)
			barTop:SetFrameLevel(bar:GetFrameLevel() + 2)
			if group.barName then
				local label = barTop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				label:SetPoint("LEFT", 4, 0)
				label:SetPoint("RIGHT", -40, 0)
				label:SetJustifyH("LEFT")
				button:SetSpellName(label)
			end
			if group.barTime and font then
				local time = barTop:CreateFontString(nil, "OVERLAY", font)
				time:SetPoint("RIGHT", -4, 0)
				button:SetDurationText(time, timeOptions)
			end
			count:SetPoint("BOTTOMRIGHT", icon, -1, 1)
		else
			button:SetSize(size, size)
			icon:SetAllPoints()
			edge:SetPoint("TOPLEFT", -n, n)
			edge:SetPoint("BOTTOMRIGHT", n, -n)
			edge:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
			local host = AddTimedGlow(button, warnGlow, color, size, warn, total,
				faded and { z, n, er, eg, eb } or nil)
			-- The swipe: on the face; above the revealed icon when there is one (still faded).
			local cooldown
			if host and host.icon then
				cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
				cooldown:SetFrameLevel(button:GetFrameLevel() + 4)
				cooldown:SetAlpha(alpha)
				icon:SetTexture(iconTexture)
				button:SetIcon(host.icon)
			else
				cooldown = CreateFrame("Cooldown", nil, face, "CooldownFrameTemplate")
				button:SetIcon(icon)
			end
			cooldown:SetAllPoints(button)
			cooldown:SetDrawEdge(false)
			-- A buff's swipe fills as it runs out ("reversed" from a cooldown's); the group's
			-- "Reversed" flips that.
			cooldown:SetReverse(group.swipe ~= "reverse")
			cooldown:SetDrawSwipe(group.swipe ~= "off")
			cooldown:SetSwipeColor(ns.Bars.SwipeRGBA(group.swipeColor))
			cooldown:SetHideCountdownNumbers(true)
			button:SetDurationCooldown(cooldown)
			if font then
				local time = top:CreateFontString(nil, "OVERLAY", font)
				time:SetPoint("BOTTOM", 0, 1)
				if not timeOptions then time:SetAlpha(alpha) end
				button:SetDurationText(time, timeOptions)
			end
			count:SetPoint("TOPRIGHT", -1, -1)
		end
		AddStackGlow(button, Get("buffs", name, "stackGlow"), color, size, Get("buffs", name, "stackOp"), Get("buffs", name, "stackCount"))
		-- The glow while it's up: part of the button, so it shows with it; its animations play
		-- when the game shows the button.
		if upGlow ~= "none" then
			local holder = CreateFrame("Frame", nil, button)
			holder:SetAllPoints(button)
			holder:SetFrameLevel(button:GetFrameLevel() + 2)
			local built = ns.Glow.Build(holder, upGlow, color, size)
			for _, g in ipairs(built.groups) do button:AddAuraShownAnimation(g) end
		end
	end
end

local function Ready()
	if unavailable then return false end
	if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	return true
end

local function SavePos(anchor)
	local point, _, relPoint, x, y = anchor:GetPoint()
	local group = A.Get(anchor.groupID)
	if group then group.pos = { point, relPoint, x, y } end
end

local function Frame(group)
	local f = frames[group.id]
	if f then return f end
	local anchor = CreateFrame("Frame", nil, UIParent)
	anchor.groupID = group.id
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetScript("OnDragStart", anchor.StartMoving)
	anchor:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePos(self)
	end)
	anchor.shade = anchor:CreateTexture(nil, "BACKGROUND")
	anchor.shade:SetPoint("TOPLEFT", -4, 4)
	anchor.shade:SetPoint("BOTTOMRIGHT", 4, -4)
	anchor.shade:SetColorTexture(0.3, 0.75, 0.95, 0.3)
	anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	anchor.label:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
	if not ok or not container then
		unavailable = true
		ns.Print("the game's aura containers aren't available, so buff groups can't be shown: " .. tostring(container))
		return nil
	end
	container:SetUnit("player")
	container:SetSize(1, 1)
	container:SetFrameLevel(anchor:GetFrameLevel() + 5)
	container:Show()
	local keep = CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
	keep:SetUnit("player")
	keep:SetSize(1, 1)
	keep:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	keep:SetFrameLevel(anchor:GetFrameLevel() + 6)
	keep:Show()
	f = { anchor = anchor, container = container, made = {}, keep = keep, slots = {}, presence = {}, enchants = {} }
	frames[group.id] = f
	return f
end

-- The missing look ------------------------------------------------------------------------
-- A keep-up buff's place shows a copy of the buff (and the missing glow) while the buff is down:
-- in full colour, grey, or a dimmed red copy (the buff's missingLook), at its opacity
-- (missingAlpha); the glow stays at full strength.
-- It must be gone, not just covered, while the buff is up, and Lecdm can't know when that is in
-- combat. So each such buff has its own "presence" container holding only it, with an invisible
-- 1 px button: empty it's 1 px wide, with the buff span + 1. The copy sits in a clipping frame
-- stretched from that container's right edge to the far side of its place: full size while the
-- buff is missing, squeezed to nothing while it's up. The game does the sizing (secret); Blizzard
-- allows anchoring addon frames to a container made with DisableUntrustedLayoutScriptsTemplate.
-- The owner's technique, proven on Forever.
A.MISSING_LOOKS = { { "red", "Dimmed red copy" }, { "normal", "Full colour" }, { "grey", "Grey" } }

local function Invisible(button)
	button:SetSize(1, 1)
	button:EnableMouse(false)
end

local function Copy(parent)
	local c = CreateFrame("Frame", nil, parent)
	c.border = c:CreateTexture(nil, "BACKGROUND")
	c.bar = c:CreateTexture(nil, "BORDER")
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.name:SetJustifyH("LEFT")
	return c
end

-- The copy's look: "red" (desaturated, tinted red, a red edge, dimmed), "normal" (as the buff
-- shows when it's up: the group's border, bar texture and colour) or "grey".
local function StyleCopy(c, group, look, alpha)
	local z = group.zoom or 0.08
	local n = look == "red" and 1 or (group.border or 1)
	c.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	c.border:ClearAllPoints()
	c.border:SetPoint("TOPLEFT", -n, n)
	c.border:SetPoint("BOTTOMRIGHT", n, -n)
	if look == "red" then
		c.border:SetColorTexture(0.7, 0, 0, 1)
		c.bar:SetColorTexture(0.35, 0.05, 0.05, 0.85)
		c.bar:SetVertexColor(1, 1, 1)
		c.icon:SetDesaturated(true)
		c.icon:SetVertexColor(1, 0.4, 0.4)
		c.name:SetTextColor(1, 0.5, 0.5)
		c:SetAlpha(0.85 * alpha)
		return
	end
	local er, eg, eb = ns.Bars.BorderRGB(group.borderColor)
	c.border:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
	c.icon:SetVertexColor(1, 1, 1)
	c.icon:SetDesaturated(look == "grey")
	if look == "grey" then
		c.bar:SetColorTexture(0.5, 0.5, 0.5, 1)
		c.bar:SetVertexColor(1, 1, 1)
		c.name:SetTextColor(0.8, 0.8, 0.8)
	else
		c.bar:SetTexture(TEXTURE_FILES[group.barTexture] or TEXTURE_FILES.blizzard)
		c.bar:SetVertexColor(BarRGB(group.barColor))
		c.name:SetTextColor(1, 1, 1)
	end
	c:SetAlpha(alpha)
end

local function Presence(f, name)
	local p = f.presence[name]
	if p then return p end
	p = {}
	p.container = CreateFrame("AuraContainer", nil, f.anchor, "CustomAuraContainerTemplate")
	p.container:SetUnit("player")
	p.container:SetSize(1, 1)
	p.container:Show()
	p.slot = A.EnchantSlot(name)
	if p.slot then
		p.container:AddItemEnchantment(p.slot, { initializeFrame = Invisible, hidePermanent = true })
	else
		p.container:AddAuraGroup("buff", "HELPFUL", {
			candidateFilters = { includeSpellIDs = A.IDs(name) },
			maxFrameCount = 1,
			initializeFrame = Invisible,
		})
	end
	p.clip = CreateFrame("Frame", nil, f.anchor, "DisableUntrustedLayoutScriptsTemplate")
	p.clip:SetClipsChildren(true)
	p.clip:SetFrameLevel(f.anchor:GetFrameLevel() + 2)
	p.host = CreateFrame("Frame", nil, p.clip)
	p.copy = Copy(p.host)
	p.copy:SetAllPoints(p.host)
	p.glow = CreateFrame("Frame", nil, p.host)
	p.glow:SetAllPoints(p.host)
	p.glow:SetFrameLevel(p.copy:GetFrameLevel() + 2)
	f.presence[name] = p
	return p
end

-- The copy and the missing glow for a buff's place: x, y from the group's top left (y down).
local function PlaceMissing(f, group, name, x, y, w, h)
	local p = Presence(f, name)
	local margin = Margin(h)
	local span = w + 2 * margin
	if p.slot then
		p.container:SetItemEnchantmentLayout({ elementWidth = span + 1, elementHeight = 1 })
		p.container:SetItemEnchantmentEnabled(p.slot, true)
	else
		p.container:SetAuraGroupCandidateFilters("buff", { includeSpellIDs = A.IDs(name) })
		p.container:SetAuraGroupLayout("buff", { elementWidth = span + 1, elementHeight = 1 })
		p.container:SetAuraGroupEnabled("buff", true)
	end
	p.container:ClearAllPoints()
	p.container:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", x - margin - 1, -y + margin)
	p.clip:ClearAllPoints()
	p.clip:SetPoint("TOPLEFT", p.container, "TOPRIGHT")
	p.clip:SetPoint("BOTTOMRIGHT", f.anchor, "TOPLEFT", x + w + margin, -y - h - margin)
	p.clip:Show()
	p.host:ClearAllPoints()
	p.host:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", x, -y)
	p.host:SetSize(w, h)
	local c = p.copy
	c.icon:ClearAllPoints()
	c.icon:SetPoint("TOPLEFT")
	c.icon:SetSize(h, h)
	c.icon:SetTexture(A.Icon(name))
	local bars = group.style == "bars"
	c.bar:SetShown(bars)
	c.name:SetShown(bars)
	if bars then
		c.bar:ClearAllPoints()
		c.bar:SetPoint("TOPLEFT", h + 1, 0)
		c.bar:SetPoint("BOTTOMRIGHT")
		c.name:ClearAllPoints()
		c.name:SetPoint("LEFT", h + 5, 0)
		c.name:SetPoint("RIGHT", -4, 0)
		c.name:SetText(name)
	end
	StyleCopy(c, group, ns.Alerts.Get("buffs", name, "missingLook") or "red", ns.Alerts.Get("buffs", name, "missingAlpha") or 1)
	ns.Glow.Show(p.glow, ns.Alerts.Get("buffs", name, "missingGlow"), ns.Alerts.Get("buffs", name, "missingColor"), h)
end

local function HideMissing(f, name)
	local p = f.presence[name]
	if not p then return end
	p.clip:Hide()
	if p.slot then
		p.container:SetItemEnchantmentEnabled(p.slot, false)
	else
		p.container:SetAuraGroupEnabled("buff", false)
	end
end

-- A weapon enchant's button: its own small container (one per look: a button's parts are fixed
-- when the game makes it, and a container takes each enchant slot once).
local function Enchant(f, group, name, key, slot)
	local en = f.enchants[key]
	if not en then
		en = { slot = slot }
		en.container = CreateFrame("AuraContainer", nil, f.anchor, "CustomAuraContainerTemplate")
		en.container:SetUnit("player")
		en.container:SetSize(1, 1)
		en.container:SetFrameLevel(f.anchor:GetFrameLevel() + 6)
		en.container:Show()
		en.button = en.container:AddItemEnchantment(slot, { initializeFrame = Styler(group, name), hidePermanent = true })
		f.enchants[key] = en
	end
	return en
end

-- The default place of the i-th group: above the middle of the screen, one above another.
local function DefaultPos(i)
	return { "CENTER", "CENTER", 0, -120 + (i - 1) * 50 }
end

local DIRS -- AnchorUtil.FlowDirection values, read when first needed

local function PlaceGroup(f, group, i)
	A.FillLook(group)
	local gap, h = group.gap, group.size
	local bars = group.style == "bars"
	local w = bars and group.barWidth or group.size
	local per = bars and 1 or math.max(1, group.perRow)
	local vertical = bars or group.vertical
	-- Keep-up and only-while-missing buffs have fixed places on the first line (column, for
	-- vertical groups; the top rows, for timer bars); the rest flow after them, closing gaps.
	local fixed, flow = {}, {}
	for j, name in ipairs(group.entries) do
		if A.Mode(group, name) == "up" and not A.EnchantSlot(name) then flow[#flow + 1] = name else fixed[#fixed + 1] = name end
	end
	local K, F = #fixed, #flow
	local stepX, stepY = w + gap, h + gap
	local width, height
	if bars then
		width, height = w, math.max(1, K + F) * stepY - gap
	elseif vertical then
		local tall = math.max(K, math.min(F, per), 1)
		local cols = (K > 0 and 1 or 0) + math.ceil(F / per)
		width, height = math.max(1, cols) * stepX - gap, tall * stepY - gap
	else
		local wide = math.max(K, math.min(F, per), 1)
		local rows = (K > 0 and 1 or 0) + math.ceil(F / per)
		width, height = wide * stepX - gap, math.max(1, rows) * stepY - gap
	end
	f.anchor:SetSize(width, height)
	local pos = group.pos or DefaultPos(i)
	f.anchor:ClearAllPoints()
	f.anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])

	local look = A.LookKey(group)
	-- The fixed places.
	local wantSlot, keepNames, wantEnchant = {}, {}, {}
	for k, name in ipairs(fixed) do
		local x, y
		if bars then
			x, y = 0, (k - 1) * stepY
		elseif vertical then
			local keepH = K * stepY - gap
			local y0 = group.grow == "RIGHT" and (height - keepH) or group.grow == "LEFT" and 0 or (height - keepH) / 2
			x, y = 0, y0 + (k - 1) * stepY
		else
			local keepW = K * stepX - gap
			local x0 = group.grow == "RIGHT" and (width - keepW) or group.grow == "LEFT" and 0 or (width - keepW) / 2
			x, y = x0 + (k - 1) * stepX, 0
		end
		keepNames[name] = true
		local ids, count = A.IDs(name)
		local slot, mode = A.EnchantSlot(name), A.Mode(group, name)
		if slot then
			-- A weapon enchant: "up" leaves its place empty while there's none.
			if mode == "up" then HideMissing(f, name) else PlaceMissing(f, group, name, x, y, w, h) end
			if mode ~= "missing" then
				local key = name .. "/" .. look .. "/" .. A.AlertLook(name)
				wantEnchant[key] = true
				local en = Enchant(f, group, name, key, slot)
				en.container:ClearAllPoints()
				en.container:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", x, -y)
				en.container:SetItemEnchantmentLayout({ elementWidth = w, elementHeight = h })
				en.container:SetItemEnchantmentEnabled(slot, true)
			end
		elseif count > 0 then
			PlaceMissing(f, group, name, x, y, w, h)
			if mode == "keep" then
				local key = name .. "/" .. look .. "/" .. A.AlertLook(name)
				wantSlot[key] = true
				local button = f.slots[key]
				if not button then
					button = f.keep:AddAuraSlot(key, "HELPFUL", {
						candidateFilters = { includeSpellIDs = ids },
						initializeFrame = Styler(group, name),
					})
					f.slots[key] = button
				end
				f.keep:SetAuraSlotCandidateFilters(key, { includeSpellIDs = ids })
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", f.anchor, "TOPLEFT", x, -y)
				f.keep:SetAuraSlotEnabled(key, true)
			end
		end
	end
	for key in pairs(f.slots) do
		if not wantSlot[key] then f.keep:SetAuraSlotEnabled(key, false) end
	end
	for key, en in pairs(f.enchants) do
		if not wantEnchant[key] then en.container:SetItemEnchantmentEnabled(en.slot, false) end
	end
	for name in pairs(f.presence) do
		if not keepNames[name] then HideMissing(f, name) end
	end

	-- The rest flow, after the fixed places.
	DIRS = DIRS or (AnchorUtil and AnchorUtil.FlowDirection) or {}
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local c = f.container
	c:ClearAllPoints()
	local shiftX = (vertical and not bars and K > 0) and stepX or 0
	local shiftY = ((bars or not vertical) and K > 0) and -K * stepY or 0
	if not bars and not vertical then shiftY = K > 0 and -stepY or 0 end
	if vertical then
		pcall(c.SetFlowLayoutAxis, c, axis and axis.Vertical)
		if group.grow == "RIGHT" and not bars then
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Up)
			pcall(c.SetFlowLayoutAnchorPoint, c, "BOTTOMLEFT")
			c:SetPoint("BOTTOMLEFT", f.anchor, "BOTTOMLEFT", shiftX, 0)
		else
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
			local point = (bars or group.grow == "LEFT") and "TOPLEFT" or "LEFT"
			c:SetPoint(point, f.anchor, point, shiftX, shiftY)
		end
	else
		pcall(c.SetFlowLayoutAxis, c, axis and axis.Horizontal)
		if group.grow == "RIGHT" then
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Left, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPRIGHT")
			c:SetPoint("TOPRIGHT", f.anchor, "TOPRIGHT", 0, shiftY)
		else
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
			local point = group.grow == "LEFT" and "TOPLEFT" or "TOP"
			c:SetPoint(point, f.anchor, point, 0, shiftY)
		end
	end
	pcall(c.SetFlowLayoutMaximumLineSize, c, bars and math.huge or (per * stepX - gap))

	local wanted = {}
	for j, name in ipairs(flow) do
		local ids, count = A.IDs(name)
		if count > 0 then
			local key = name .. "/" .. look .. "/" .. A.AlertLook(name)
			wanted[key] = true
			if not f.made[key] then
				c:AddAuraGroup(key, "HELPFUL", {
					candidateFilters = { includeSpellIDs = ids },
					initializeFrame = Styler(group, name),
					sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or nil,
				})
				f.made[key] = true
			end
			c:SetAuraGroupCandidateFilters(key, { includeSpellIDs = ids })
			c:SetAuraGroupLayout(key, {
				elementSpacing = gap, lineSpacing = gap,
				groupSpacing = gap, groupLineSpacing = gap,
				elementWidth = w, elementHeight = h, layoutIndex = j,
			})
			c:SetAuraGroupEnabled(key, true)
		end
	end
	for key in pairs(f.made) do
		if not wanted[key] then c:SetAuraGroupEnabled(key, false) end
	end
	local unlocked = ns.Bars.IsUnlocked()
	f.anchor.label:SetText(group.name)
	f.anchor.shade:SetShown(unlocked)
	f.anchor.label:SetShown(unlocked)
	f.anchor:EnableMouse(unlocked)
	f.anchor:SetAlpha(ns.Visibility.Alpha(group))
	f.anchor:Show()
end

-- Every group's opacity (Visibility.lua: combat and target changes; our frames only, so in
-- combat too).
function A.ApplyAlpha()
	if not ns.db then return end
	for i, group in ipairs(ns.db.buffs.list) do
		local f = frames[group.id]
		if f then f.anchor:SetAlpha(ns.Visibility.Alpha(group)) end
	end
end

-- Sets up every group for the profile in use (at login, and whenever settings, buffs or the
-- profile change). In combat it waits for the end of combat.
function A.Build()
	if not ns.db then return end
	Seed()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	if not Ready() then return end
	local live = {}
	for i, group in ipairs(ns.Enabled() and ns.db.buffs.list or {}) do
		local f = Frame(group)
		if not f then return end
		live[group.id] = true
		local ok, err = pcall(PlaceGroup, f, group, i)
		if not ok then
			ns.Print("buff group " .. group.name .. " couldn't be set up: " .. tostring(err))
			ns.Log("buff group " .. group.name .. " couldn't be set up: " .. tostring(err))
		end
	end
	for id, f in pairs(frames) do
		if not live[id] then
			f.anchor:Hide()
			for key in pairs(f.made) do pcall(f.container.SetAuraGroupEnabled, f.container, key, false) end
			for key in pairs(f.slots) do pcall(f.keep.SetAuraSlotEnabled, f.keep, key, false) end
			for name in pairs(f.presence) do pcall(HideMissing, f, name) end
			for _, en in pairs(f.enchants) do pcall(en.container.SetItemEnchantmentEnabled, en.container, en.slot, false) end
		end
	end
end

function A.IsPending()
	return pending
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
	if not ns.db then return end
	if event == "UNIT_AURA" or event == "WEAPON_ENCHANT_CHANGED" then
		if (event == "UNIT_AURA" and unit ~= "player") or InCombatLockdown() then return end
		if LearnFromBuffs() then A.Build() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		local learned = LearnFromBuffs()
		if pending or learned then A.Build() end
	end
end)
