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
local TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

-- Groups ---------------------------------------------------------------------------------

function A.NewGroup(name)
	local buffs = ns.db.buffs
	buffs.nextID = (buffs.nextID or 1) + 1
	local group = { id = "buffs" .. buffs.nextID, name = name, style = "icons", entries = {},
		size = 32, gap = 4, grow = "CENTER", vertical = false, perRow = 12, barWidth = 200 }
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

-- Every spell ID for a buff name (a set), and how many.
function A.IDs(name)
	local ids, n = {}, 0
	local function Add(id)
		if type(id) == "number" and not ns.IsSecret(id) and not ids[id] then
			ids[id] = true
			n = n + 1
		end
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

function A.Icon(name)
	local icons = LecdmDB.auraIcons or {}
	if icons[name] then return icons[name] end
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	if ok and type(info) == "table" and not ns.IsSecret(info.iconID) and info.iconID then return info.iconID end
	for _, e in pairs(ns.Catalogue.byID) do
		if e.name == name and e.spellID then return ns.Bars.SpellIcon(e.spellID) end
	end
	return 134400
end

-- The buffs on you now, out of combat (in combat, and where the game refuses, nothing): each
-- { name, spellID, icon }, once per name.
function A.ReadBuffs()
	local list, seen = {}, {}
	if InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
	for i = 1, 40 do
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or type(aura) ~= "table" then break end
		local name, id, icon = aura.name, aura.spellId, aura.icon
		if not (ns.IsSecret(name) or ns.IsSecret(id) or ns.IsSecret(icon)) and name and id and not seen[name] then
			seen[name] = true
			list[#list + 1] = { name = name, spellID = id, icon = icon }
		end
	end
	return list
end

-- Out of combat, each buff on you that's in a group teaches its ID (another rank, another
-- caster's); the containers are set again when one is new.
local function LearnFromBuffs()
	local changed = false
	LecdmDB.auraIcons = LecdmDB.auraIcons or {}
	for _, b in ipairs(A.ReadBuffs()) do
		if A.GroupOf(b.name) then
			if A.Learn(b.name, b.spellID) then changed = true end
			LecdmDB.auraIcons[b.name] = b.icon
		end
	end
	return changed
end

-- The display -----------------------------------------------------------------------------

-- The parts of one of the game's aura buttons, built once when the game makes it.
local function Styler(group)
	local size, bars, width = group.size, group.style == "bars", group.barWidth
	return function(button)
		local edge = button:CreateTexture(nil, "BACKGROUND")
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetTexCoord(unpack(TEXCOORD))
		button:SetIcon(icon)
		local top = CreateFrame("Frame", nil, button)
		top:SetAllPoints(button)
		top:SetFrameLevel(button:GetFrameLevel() + 5)
		local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		button:SetApplicationCount(count)
		if bars then
			-- A timer bar: the icon at the left, the bar draining to the right with the buff's name and
			-- the time left; the game drives the bar (SetTimerDuration).
			button:SetSize(width, size)
			icon:SetSize(size, size)
			icon:SetPoint("LEFT")
			edge:SetPoint("TOPLEFT", icon, -1, 1)
			edge:SetPoint("BOTTOMRIGHT", button, 1, -1)
			edge:SetColorTexture(0, 0, 0, 0.8)
			local bar = CreateFrame("StatusBar", nil, button)
			bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
			bar:SetPoint("BOTTOMRIGHT")
			bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
			bar:SetStatusBarColor(0.25, 0.6, 1)
			button:SetDurationBar(bar, {
				direction = Enum.StatusBarTimerDirection.RemainingTime,
				interpolation = Enum.StatusBarInterpolation.Immediate,
			})
			local barTop = CreateFrame("Frame", nil, bar)
			barTop:SetAllPoints(bar)
			barTop:SetFrameLevel(bar:GetFrameLevel() + 2)
			local name = barTop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			name:SetPoint("LEFT", 4, 0)
			name:SetPoint("RIGHT", -40, 0)
			name:SetJustifyH("LEFT")
			button:SetSpellName(name)
			local time = barTop:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			time:SetPoint("RIGHT", -4, 0)
			button:SetDurationText(time)
			count:SetPoint("BOTTOMRIGHT", icon, -1, 1)
		else
			button:SetSize(size, size)
			icon:SetAllPoints()
			edge:SetPoint("TOPLEFT", -1, 1)
			edge:SetPoint("BOTTOMRIGHT", 1, -1)
			edge:SetColorTexture(0, 0, 0, 1)
			local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
			cooldown:SetAllPoints()
			cooldown:SetDrawEdge(false)
			cooldown:SetReverse(true)
			cooldown:SetHideCountdownNumbers(true)
			button:SetDurationCooldown(cooldown)
			local time = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			time:SetPoint("BOTTOM", 0, 1)
			button:SetDurationText(time)
			count:SetPoint("TOPRIGHT", -1, -1)
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
	f = { anchor = anchor, container = container, made = {} }
	frames[group.id] = f
	return f
end

-- The default place of the i-th group: above the middle of the screen, one above another.
local function DefaultPos(i)
	return { "CENTER", "CENTER", 0, -120 + (i - 1) * 50 }
end

local DIRS -- AnchorUtil.FlowDirection values, read when first needed

local function PlaceGroup(f, group, i)
	local step = group.size + group.gap
	local bars = group.style == "bars"
	local w = bars and group.barWidth or group.size
	local per = bars and 1 or math.max(1, group.perRow)
	local n = math.max(1, #group.entries)
	local vertical = bars or group.vertical
	-- The anchor is the area the group can fill: the shade and the drag handle while unlocked.
	local across = math.min(n, per)
	local lines = math.ceil(n / per)
	local width = vertical and (lines * (w + group.gap) - group.gap) or (across * step - group.gap)
	local height = vertical and (across * step - group.gap) or (lines * step - group.gap)
	if bars then width, height = w, n * step - group.gap end
	f.anchor:SetSize(width, height)
	local pos = group.pos or DefaultPos(i)
	f.anchor:ClearAllPoints()
	f.anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])

	DIRS = DIRS or (AnchorUtil and AnchorUtil.FlowDirection) or {}
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local c = f.container
	c:ClearAllPoints()
	if vertical then
		pcall(c.SetFlowLayoutAxis, c, axis and axis.Vertical)
		if group.grow == "RIGHT" then
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Up)
			pcall(c.SetFlowLayoutAnchorPoint, c, "BOTTOMLEFT")
			c:SetPoint("BOTTOMLEFT", f.anchor, "BOTTOMLEFT")
		else
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
			c:SetPoint(group.grow == "LEFT" and "TOPLEFT" or "LEFT", f.anchor, group.grow == "LEFT" and "TOPLEFT" or "LEFT")
		end
	else
		pcall(c.SetFlowLayoutAxis, c, axis and axis.Horizontal)
		if group.grow == "RIGHT" then
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Left, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPRIGHT")
			c:SetPoint("TOPRIGHT", f.anchor, "TOPRIGHT")
		else
			pcall(c.SetFlowLayoutGrowthDirection, c, DIRS.Right, DIRS.Down)
			pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
			c:SetPoint(group.grow == "LEFT" and "TOPLEFT" or "TOP", f.anchor, group.grow == "LEFT" and "TOPLEFT" or "TOP")
		end
	end
	pcall(c.SetFlowLayoutMaximumLineSize, c, bars and math.huge or (per * step - group.gap))

	local look = group.style .. ":" .. group.size .. ":" .. (bars and group.barWidth or 0)
	local wanted = {}
	for j, name in ipairs(group.entries) do
		local ids, count = A.IDs(name)
		if count > 0 then
			local key = name .. "/" .. look
			wanted[key] = true
			if not f.made[key] then
				c:AddAuraGroup(key, "HELPFUL", {
					candidateFilters = { includeSpellIDs = ids },
					initializeFrame = Styler(group),
					sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Expiration or nil,
				})
				f.made[key] = true
			end
			c:SetAuraGroupCandidateFilters(key, { includeSpellIDs = ids })
			c:SetAuraGroupLayout(key, {
				elementSpacing = group.gap, lineSpacing = group.gap,
				groupSpacing = group.gap, groupLineSpacing = group.gap,
				elementWidth = w, elementHeight = group.size, layoutIndex = j,
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
	f.anchor:Show()
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
		end
	end
end

function A.IsPending()
	return pending
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event, unit)
	if not ns.db then return end
	if event == "UNIT_AURA" then
		if unit ~= "player" or InCombatLockdown() then return end
		if LearnFromBuffs() then A.Build() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		local learned = LearnFromBuffs()
		if pending or learned then A.Build() end
	end
end)
