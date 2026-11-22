-- A small fake WoW: Forever client for Lecdm's tests. Frames accept any method call; Blizzard's
-- four cooldown viewers have an item pool and an OnAcquireItemFrame like the real ones, and items
-- run TriggerAlertEvent. Secret values are a userdata that errors on tostring, concatenation,
-- comparison and indexing, so code that touches one without asking issecretvalue fails a test.
local M = { printed = {}, sounds = {}, frames = {}, combat = false, instance = false, secretCooldowns = false }

local SECRET = newproxy(true)
do
	local mt = getmetatable(SECRET)
	local function refuse() error("used a secret value", 2) end
	mt.__tostring, mt.__concat, mt.__lt, mt.__le, mt.__index = refuse, refuse, refuse, refuse, refuse
end
M.SECRET = SECRET
function issecretvalue(v) return v == SECRET end

-- Unknown methods (capitalised names) do nothing; unknown fields are nil, as on a real frame.
local function Permissive(t)
	return setmetatable(t, { __index = function(_, k)
		if type(k) == "string" and k:match("^%u") then return function() return nil end end
	end })
end

local function NewRegion(kind, name, parent)
	local f = Permissive({ kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {},
		events = {}, alpha = 1, w = 0, h = 0 })
	function f:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function f:Hide() self.shown = false end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:IsShown() return self.shown end
	function f:SetParent(p) self.parent = p end
	function f:GetName() return self.name end
	function f:SetAlpha(a) self.alpha = a end
	function f:GetAlpha() return self.alpha end
	function f:SetSize(w, h) self.w, self.h = w, h end
	function f:GetSize() return self.w, self.h end
	function f:SetWidth(w) self.w = w end
	function f:SetHeight(h) self.h = h end
	function f:GetWidth() return self.w end
	function f:GetHeight() return self.h end
	function f:GetCenter() return 0, 0 end
	function f:GetEffectiveScale() return 1 end
	function f:GetStringWidth() return 60 end
	function f:HasFocus() return false end
	function f:SetPoint(...) table.insert(self.points, { ... }) end
	function f:ClearAllPoints() self.points, self.allPoints = {}, nil end
	function f:SetAllPoints(rel) self.allPoints = rel or self.parent end
	function f:GetPoint() local p = self.points[1] or {} return p[1], p[2], p[3], p[4], p[5] end
	function f:SetScript(event, fn) self.scripts[event] = fn end
	function f:GetScript(event) return self.scripts[event] end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:RegisterUnitEvent(e) self.events[e] = true end
	function f:SetText(t) self.text = t end
	function f:SetFont(file, size, flags) self.font = { file, size, flags } end
	function f:GetText() return self.text end
	function f:SetChecked(v) self.checked = v end
	function f:GetChecked() return self.checked end
	function f:SetDesaturated(v) self.desaturated = v end
	function f:SetVertexColor(r) self.vertex = r end
	function f:SetTexture(t) self.texture = t end
	function f:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
	function f:SetBackdropBorderColor(r, g, b) self.border = { r, g, b } end
	function f:EnableMouse(v) self.mouse = v end
	function f:CreateTexture() return NewRegion("Texture", nil, self) end
	function f:CreateMaskTexture() return NewRegion("MaskTexture", nil, self) end
	function f:AddMaskTexture(m) self.masks = self.masks or {} self.masks[m] = true end
	function f:RemoveMaskTexture(m) if self.masks then self.masks[m] = nil end end
	function f:SetSwipeTexture(t) self.swipeTexture = t end
	function f:CreateAnimationGroup()
		local g = Permissive({ animations = {}, playing = false })
		function g:CreateAnimation(kind)
			local a = Permissive({ kind = kind })
			table.insert(self.animations, a)
			return a
		end
		function g:Play() self.playing = true end
		function g:Stop() self.playing = false end
		function g:IsPlaying() return self.playing end
		return g
	end
	function f:CreateFontString() return NewRegion("FontString", nil, self) end
	function f:SetupMenu(generator) self.generator = generator end
	function f:SetTexCoord(...) self.texcoord = { ... } end
	function f:SetHideCountdownNumbers(v) self.hideNumbers = v end
	function f:SetReverse(v) self.reverse = v end
	function f:SetTimerDuration(d) self.timerDuration = d end
	function f:SetCountdownMillisecondsThreshold(v) self.msThreshold = v end
	function f:SetDrawEdge(v) self.edge = v end
	function f:SetDrawSwipe(v) self.drawSwipe = v end
	function f:SetSwipeColor(...) self.swipeColor = { ... } end
	function f:IsForbidden() return false end
	function f:IsObjectType(kind2) return self.kind == kind2 end
	function f:GetAttribute(k) return self.attributes and self.attributes[k] end
	function f:IsVisible()
		local r = self
		while r do
			if not r.shown then return false end
			r = r.parent
		end
		return true
	end
	function f:EnableMouse(v) self.mouse = v end
	function f:SetCooldownFromDurationObject(dur)
		if dur == SECRET then error("secret duration refused") end
		self.duration = dur
	end
	function f:SetCooldown(start, duration)
		if start == SECRET or duration == SECRET then error("secret cooldown refused") end
		self.cooldown = { start, duration }
	end
	function f:Clear() self.duration, self.cooldown = nil, nil end
	function f:GetFrameLevel() return self.level or 1 end
	function f:SetFrameLevel(l) self.level = l end
	return f
end

-- Blizzard's aura containers, as CustomAuraContainer checks them: unique group keys, a filter
-- string, spell IDs required; touching one in combat is an error (its buttons are closed to
-- addons then). A group's button records what the addon bound to it.
local BINDERS = { "SetIcon", "SetDurationCooldown", "SetDurationText", "SetApplicationCount", "SetDurationBar", "SetSpellName",
	"SetApplicationBar" }
local function Container(c)
	c.groups = {}
	local function Open()
		if M.combat then error("aura container touched in combat", 3) end
	end
	function c:SetUnit(u) self.unit = u end
	function c:AddAuraGroup(key, filter, options)
		Open()
		assert(not self.groups[key], "aura group '" .. key .. "' already exists")
		assert(filter == "HELPFUL" or filter == "HARMFUL", "bad filter string")
		local ids = options.candidateFilters and options.candidateFilters.includeSpellIDs
		assert(ids and next(ids), "includeSpellIDs required")
		local b = NewRegion("Button", nil, self)
		b.bound = {}
		for _, binder in ipairs(BINDERS) do b[binder] = function(btn, x) btn.bound[binder] = x end end
		if options.initializeFrame then options.initializeFrame(b) end
		self.groups[key] = { ids = ids, enabled = true, button = b, sort = options.sortMethod }
	end
	c.slots = {}
	function c:AddAuraSlot(key, filter, options)
		Open()
		assert(not self.slots[key], "aura slot '" .. key .. "' already exists")
		assert(filter == "HELPFUL" or filter == "HARMFUL", "bad filter string")
		local ids = options.candidateFilters and options.candidateFilters.includeSpellIDs
		assert(ids and next(ids), "includeSpellIDs required")
		local b = NewRegion("Button", nil, self)
		b.bound = {}
		for _, binder in ipairs(BINDERS) do b[binder] = function(btn, x) btn.bound[binder] = x end end
		if options.initializeFrame then options.initializeFrame(b) end
		self.slots[key] = { ids = ids, enabled = true, button = b }
		return b
	end
	function c:SetAuraSlotCandidateFilters(key, filters)
		Open()
		self.slots[key].ids = filters.includeSpellIDs
	end
	function c:SetAuraSlotEnabled(key, on)
		Open()
		self.slots[key].enabled = on
	end
	function c:SetAuraGroupCandidateFilters(key, filters)
		Open()
		self.groups[key].ids = filters.includeSpellIDs
	end
	function c:SetAuraGroupLayout(key, layout)
		Open()
		self.groups[key].layout = layout
	end
	function c:SetAuraGroupEnabled(key, on)
		Open()
		self.groups[key].enabled = on
	end
	c.enchants = {}
	function c:AddItemEnchantment(slot, options)
		Open()
		assert(not self.enchants[slot], "item enchantment already exists with this slot.")
		local b = NewRegion("Button", nil, self)
		b.bound = {}
		for _, binder in ipairs(BINDERS) do b[binder] = function(btn, x) btn.bound[binder] = x end end
		if options.initializeFrame then options.initializeFrame(b) end
		self.enchants[slot] = { enabled = true, button = b, hidePermanent = options.hidePermanent }
		return b
	end
	function c:SetItemEnchantmentLayout(layout)
		Open()
		self.enchantLayout = layout
	end
	function c:SetItemEnchantmentEnabled(slot, on)
		Open()
		self.enchants[slot].enabled = on
	end
	function c:SetFlowLayoutAxis(axis) self.axis = axis end
	function c:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
	function c:SetFlowLayoutAnchorPoint(point) self.flowPoint = point end
	function c:SetFlowLayoutMaximumLineSize(n) self.lineSize = n end
	return c
end

-- Every frame, in the order made, as the game's EnumerateFrames walks them.
function EnumerateFrames(prev)
	if not prev then return M.frames[1] end
	for i, f in ipairs(M.frames) do
		if f == prev then return M.frames[i + 1] end
	end
end

-- Action slots: M.actions[slot] = { kind, id, sub }; bindings by command.
M.actions, M.bindings = {}, {}
function GetActionInfo(slot)
	local a = M.actions[slot]
	if a then return a[1], a[2], a[3] end
end
function GetBindingKey(command) return M.bindings[command] end
RANGE_INDICATOR = "●"

function CreateFrame(kind, name, parent, template)
	local f = NewRegion(kind, name, parent)
	if kind == "AuraContainer" then
		assert(template == "CustomAuraContainerTemplate", "aura containers need CustomAuraContainerTemplate")
		Container(f)
		M.containers = M.containers or {}
		table.insert(M.containers, f)
	end
	table.insert(M.frames, f)
	if name then _G[name] = f end
	return f
end

function hooksecurefunc(a, b, c)
	local t, name, fn = a, b, c
	if type(a) == "string" then t, name, fn = _G, a, b end
	local orig = t[name]
	assert(type(orig) == "function", "hooksecurefunc on a missing function " .. tostring(name))
	t[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end
end

UIParent = CreateFrame("Frame", "UIParent")
-- Chat windows: General (the main one) and a tab the player made, "Lecdm".
NUM_CHAT_WINDOWS = 3
M.chatTabs = { "General", "Combat Log", "Lecdm" }
for i = 1, 3 do
	local f = CreateFrame("Frame", "ChatFrame" .. i)
	f.messages = {}
	function f:AddMessage(text) table.insert(self.messages, text) end
end
DEFAULT_CHAT_FRAME = ChatFrame1
function GetChatWindowInfo(i)
	local name = M.chatTabs[i]
	if not name then return nil end
	return name, 14, 1, 1, 1, 1, true, false, true, false
end
Minimap = CreateFrame("Frame", "Minimap")
Minimap:SetSize(140, 140)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
function GameTooltip:SetSpellByID(id) self.spell = id end
SettingsPanel = CreateFrame("Frame", "SettingsPanel")
ChatFontNormal = {}
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960, MAP_PING = 3175, ALARM_CLOCK_WARNING_3 = 12889 }
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function date() return "12:00:00" end
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	table.insert(M.printed, table.concat(parts, " "))
end
function PlaySound(kit) table.insert(M.sounds, kit) end
function InCombatLockdown() return M.combat end
function IsInInstance() return M.instance, M.instance and "party" or "none" end
-- The group: M.party = { class file name ... } for party1, party2 ...
M.party = {}
function UnitClass(unit)
	local n = unit and unit:match("^party(%d)$")
	if n then
		local c = M.party[tonumber(n)]
		return c, c
	end
	return "Warrior", "WARRIOR"
end
function IsInRaid() return false end
-- Talents: one trait tree; M.talentsTaken[nodeID] = true for a talent with a rank bought.
M.talentsTaken = { [501] = true }
local TALENTS = { [501] = { "Tactical Mastery", 1 }, [502] = { "Improved Overpower", 1 }, [601] = { "Flurry", 2 } }
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
	GetConfigInfo = function() return { treeIDs = { 70 } } end,
	GetGroupDisplayInfoByTreeID = function() return { { groupID = 1, displayName = "Arms", orderIndex = 1 }, { groupID = 2, displayName = "Fury", orderIndex = 2 } } end,
	GetTreeNodes = function() return { 501, 502, 601 } end,
	GetNodeInfo = function(_, nodeID)
		return { entryIDs = { nodeID * 10 }, groupIDs = { TALENTS[nodeID][2] }, isVisible = true,
			ranksPurchased = M.talentsTaken[nodeID] and 1 or 0 }
	end,
	GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
	GetDefinitionInfo = function(definitionID) return { overrideName = TALENTS[definitionID / 10][1] } end,
	GetGroupCurrencyInfo = function() return {} end,
}
-- Stances: M.forms = { form spell IDs }, M.form = the index in (0: none).
M.forms, M.form = { 2457, 71, 2458 }, 1
function GetNumShapeshiftForms() return #M.forms end
function GetShapeshiftForm() return M.form end
function GetShapeshiftFormInfo(i) return 1, i == M.form, true, M.forms[i] end
function UnitRace() return "Human", "Human" end
function GetNumSubgroupMembers() return #M.party end
function GetNumGroupMembers() return #M.party + 1 end
function UnitIsUnit(a, b) return a == b end
M.name, M.surname = "Brenna", "Ashford"
function UnitName() return M.name, M.surname end
function IsInGroup() return #M.party > 0 end
M.target = nil -- nil: no target; { dead = true/false }
function UnitExists(unit) return unit == "target" and M.target ~= nil end
function UnitIsDead(unit) return unit == "target" and M.target ~= nil and M.target.dead == true end
-- Items: the Satchel (12345, on use) in the top trinket slot; in the bags 2 Healthstones (5512,
-- on use) and a Linen Cloth (2589, no use); M.slotCD / M.itemCD give cooldowns.
M.trinkets = { [13] = 12345 }
M.bag = { [5512] = 2, [2589] = 5 }
M.bagSlots = { 5512, 2589, 5512 }
M.slotCD, M.itemCD = {}, {}
local ITEMS = { [12345] = { "Satchel of Potions", true }, [5512] = { "Healthstone", true }, [2589] = { "Linen Cloth", false } }
function GetInventoryItemID(_, slot) return M.trinkets[slot] end
function GetInventoryItemCooldown(_, slot)
	if M.combat then return SECRET, SECRET, 1 end
	local cd = M.slotCD[slot]
	if cd then return cd[1], cd[2], 1 end
	return 0, 0, 1
end
C_Item = {
	GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][1] end,
	GetItemCooldown = function() return 0, 0, true end,
	GetItemSpell = function(id) return ITEMS[id] and ITEMS[id][2] and "Use" or nil end,
	GetItemCount = function(id) return M.bag[id] or 0 end,
	IsUsableItem = function() return true end,
	GetItemIconByID = function() return 7 end,
	GetItemQualityByID = function() return 3 end,
}
C_Container = {
	GetContainerNumSlots = function(bag) return bag == 0 and #M.bagSlots or 0 end,
	GetContainerItemInfo = function(_, slot) return M.bagSlots[slot] and { itemID = M.bagSlots[slot] } end,
	GetItemCooldown = function(id)
		local cd = M.itemCD[id]
		if cd then return cd[1], cd[2], 1 end
		return 0, 0, 1
	end,
}
function UnitGroupRolesAssigned() return "NONE" end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetCursorPosition() return 0, 0 end
function MouseIsOver(f) return M.mouseOver == f end
function GetMinimapShape() return "ROUND" end
function ReloadUI() M.reloaded = true end
function HideUIPanel(f) f:Hide() end
function GameTooltip_Hide() end
YES, NO, OKAY, CANCEL = "Yes", "No", "Okay", "Cancel"
ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 } }
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
C_ClassColor = { GetClassColor = function(class) return RAID_CLASS_COLORS[class] end }
StaticPopupDialogs = {}
function StaticPopup_Show(which, text, _, data) M.popup = { which = which, text = text, data = data } end
-- Accept the popup shown; text is what's typed in its edit box, if it has one.
function M.Accept(text)
	local p = M.popup
	M.popup = nil
	local dialog = { GetEditBox = function() return { GetText = function() return text end } end }
	StaticPopupDialogs[p.which].OnAccept(dialog, p.data)
end
M.now = 1000
function GetTime() return M.now end
M.timers = {}
-- C_Timer.NewTimer: due at M.now + seconds; M.Advance moves the clock and runs what's due.
M.delayed = {}
C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }
function C_Timer.NewTimer(seconds, fn)
	local t = { due = M.now + seconds, fn = fn }
	function t:Cancel() self.cancelled = true end
	table.insert(M.delayed, t)
	return t
end
function M.Advance(seconds)
	M.now = M.now + seconds
	local due, keep = {}, {}
	for _, t in ipairs(M.delayed) do
		if not t.cancelled then table.insert(t.due <= M.now and due or keep, t) end
	end
	M.delayed = keep
	table.sort(due, function(a, b) return a.due < b.due end)
	for _, t in ipairs(due) do t.fn() end
end
function M.RunTimers()
	local list = M.timers
	M.timers = {}
	for _, fn in ipairs(list) do fn() end
end
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name) M.settingsPanel = panel return { name = name } end,
	RegisterAddOnCategory = function(category) M.settingsCategory = category end,
}

C_AddOns = { GetAddOnMetadata = function() return "0.0.1-dev" end, IsAddOnLoaded = function() return true end }
C_CVar = { GetCVar = function() return "1" end }
C_SpecializationInfo = { GetSpecialization = function() return 1 end }
C_Secrets = {
	ShouldCooldownsBeSecret = function() return M.combat end,
	ShouldAurasBeSecret = function() return M.combat end,
}
C_SpellActivationOverlay = { IsSpellOverlayed = function() return false end }

AuraContainerSortMethod = { Default = 0, Expiration = 2 }
AuraContainerItemEnchantmentSlot = { MainHand = 0, OffHand = 1, Ranged = 2 }
-- M.enchant = { mainMs = ... } while the main hand has a temporary enchant.
function GetWeaponEnchantInfo()
	local e = M.enchant
	if not e then return false, 0, 0, 0, false, 0, 0, 0 end
	return e.mainMs ~= nil, e.mainMs or 0, 0, 1, e.offMs ~= nil, e.offMs or 0, 0, 2
end
function GetInventoryItemTexture(_, slot) return slot == 16 and 135225 or nil end
C_CurveUtil = {
	CreateColorCurve = function()
		local c = { points = {} }
		function c:SetType(kind) self.kind = kind end
		function c:AddPoint(x, color) table.insert(self.points, { x, color }) end
		return c
	end,
}
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
-- The game's duration text bindings and durations: what they were given.
C_DurationUtil = {
	CreateDurationTextBinding = function()
		local t = { enabled = false }
		function t:SetFontString(fs) self.fontString = fs end
		function t:SetTextColorCurve(curve, property) self.curve, self.property = curve, property end
		function t:SetDuration(d) self.duration = d end
		function t:SetEnabled(v) self.enabled = v end
		return t
	end,
	CreateDuration = function()
		local d = {}
		function d:SetTimeFromStart(start, duration) self.start, self.span = start, duration end
		return d
	end,
}
AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 }, FlowDirection = { Right = 1, Left = 2, Down = 3, Up = 4 } }
Enum = {
	StatusBarTimerDirection = { RemainingTime = 1, ElapsedTime = 0 },
	LuaCurveType = { Linear = 0, Step = 1 },
	DurationTextBindingProperty = { RemainingDuration = 1 },
	TtsVoiceType = { Standard = 0 },
	StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
	SpellBookSpellBank = { Player = 0 },
	SpellBookItemType = { None = 0, Spell = 1 },
	CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, GroupBuff = 4 },
	CooldownViewerAlertEventType = { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4,
		OnAuraApplied = 5, OnAuraRemoved = 6 },
}

M.range, M.rangeChecked = {}, {}

-- Learned: Blizzard's list's isKnown, and the spellbook (M.book: one Protection line).
C_SpellBook = {
	IsSpellKnown = function(id)
		for _, info in pairs(M.info) do
			if info.spellID == id then return info.isKnown end
		end
		return id == 2565
	end,
	GetNumSpellBookSkillLines = function() return 1 end,
	GetSpellBookSkillLineInfo = function() return { name = "Protection", itemIndexOffset = 0, numSpellBookItems = 3, shouldHide = false } end,
	GetSpellBookItemInfo = function(slot)
		return ({ { spellID = 2565, itemType = 1, isPassive = false }, { spellID = 12345, itemType = 1, isPassive = true },
			{ spellID = 100, itemType = 1, isPassive = false } })[slot]
	end,
}
function GetSpellBaseCooldown(id) return id == 2565 and 5000 or 0 end

-- Spells by ID, and Blizzard's list: section value -> cooldown IDs, cooldown ID -> info.
M.spells = {
	[6673] = { name = "Battle Shout", texture = 1 },
	[100] = { name = "Charge", texture = 2, active = true },
	[6572] = { name = "Revenge", texture = 3, usable = false },
	[12292] = { name = "Death Wish", texture = 4 },
	[2565] = { name = "Shield Block", texture = 5 },
	[7386] = { name = "Sunder Armor", texture = 6 },
}
M.sections = { [0] = { 11, 12 }, [1] = { 13 }, [2] = { 14, 15, 16 }, [3] = {} }
M.info = {
	[11] = { cooldownID = 11, spellID = 100, isKnown = true, category = 0, linkedSpellIDs = {} },
	[12] = { cooldownID = 12, spellID = 6572, isKnown = true, category = 0, linkedSpellIDs = {} },
	[13] = { cooldownID = 13, spellID = 12292, isKnown = false, category = 1, linkedSpellIDs = {} },
	[14] = { cooldownID = 14, spellID = 6673, isKnown = true, hasAura = true, selfAura = true, category = 2, linkedSpellIDs = {} },
	[16] = { cooldownID = 16, spellID = 7386, isKnown = true, hasAura = true, selfAura = false, category = 2, linkedSpellIDs = {} },
	[15] = { cooldownID = 15, equipSlot = 13, isKnown = true, category = 2, linkedSpellIDs = {} },
}

C_CooldownViewer = {
	IsCooldownViewerAvailable = function() return true, "" end,
	GetCooldownViewerCategorySet = function(value)
		if value == 4 then error("not a category on this client") end
		return M.sections[value] or {}
	end,
	GetCooldownViewerCooldownInfo = function(id) return M.info[id] end,
}

C_Spell = {
	GetSpellInfo = function(name)
		for id, s in pairs(M.spells) do
			if s.name == name then return { spellID = id, iconID = s.texture, name = name } end
		end
	end,
	GetSpellName = function(id) return M.spells[id] and M.spells[id].name end,
	GetSpellTexture = function(id) return M.spells[id] and M.spells[id].texture end,
	GetSpellCooldown = function(id)
		local s = M.spells[id]
		return { isActive = s.active or s.gcd or false, isOnGCD = s.gcd or false, isEnabled = true,
			startTime = M.secretCooldowns and SECRET or 0, duration = M.secretCooldowns and SECRET or 0 }
	end,
	GetSpellCooldownDuration = function(id)
		if M.secretDuration then return SECRET end
		return { spell = id }
	end,
	-- M.charges[id] = { current, max, recharging }; the count is secret in combat.
	GetSpellCharges = function(id)
		local c = M.charges and M.charges[id]
		if not c then return nil end
		return { currentCharges = M.combat and SECRET or c[1], maxCharges = c[2], isActive = c[3],
			cooldownStartTime = M.combat and SECRET or 0, cooldownDuration = M.combat and SECRET or 0 }
	end,
	GetSpellChargeDuration = function(id) return { charge = id } end,
	IsSpellUsable = function(id)
		if M.combat then return SECRET end
		return M.spells[id].usable ~= false
	end,
	IsSpellInRange = function(id)
		if M.combat then return SECRET end
		if M.range[id] ~= nil then return M.range[id] end
		return true
	end,
	EnableSpellRangeCheck = function(id, on) M.rangeChecked[id] = on end,
}

M.buffsOnMe = {}
C_UnitAuras = {
	GetAuraDataByIndex = function(_, i)
		local b = M.buffsOnMe[i]
		if not b then return nil end
		if M.combat then return { name = SECRET, spellId = SECRET, icon = SECRET } end
		return { name = b.name, spellId = b.spellId, icon = b.icon, duration = b.duration, expirationTime = b.expires }
	end,
	GetAuraDuration = function(_, id)
		if id == SECRET then error("secret aura instance refused") end
		return {}
	end,
}

-- Blizzard's viewers: an item pool, and OnAcquireItemFrame as the real mixin has.
M.viewers = {}
for _, global in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
	local v = CreateFrame("Frame", global)
	v.itemFramePool = { active = {} }
	function v.itemFramePool:EnumerateActive() return pairs(self.active) end
	function v:OnAcquireItemFrame(item) item.viewerFrame = self end
	-- Blizzard's layout: every icon back where the viewer wants it.
	function v:RefreshLayout()
		for item in pairs(self.itemFramePool.active) do
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		end
	end
	function v:Layout() end
	M.viewers[global] = v
end

-- A Blizzard icon in a viewer, made the way the pool does: acquired, then given its entry.
function M.AddItem(global, cooldownID)
	local v = M.viewers[global]
	local item = CreateFrame("Frame")
	item:SetSize(40, 40)
	item.alerts = 0
	function item:TriggerAlertEvent() self.alerts = self.alerts + 1 end
	function item:UpdateShownState() end
	v:OnAcquireItemFrame(item)
	v.itemFramePool.active[item] = true
	item.cooldownID = cooldownID
	return item
end

function M.Fire(event, ...)
	for _, f in ipairs(M.frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end

function M.Slash(msg) SlashCmdList.LECDM(msg) end

-- A menu as Blizzard's MenuUtil hands a generator: buttons (submenus) and checkboxes.
function M.Menu()
	local function Node(text)
		local n = { text = text, children = {} }
		function n:CreateButton(t, onClick)
			local c = Node(t)
			c.onClick = onClick
			table.insert(self.children, c)
			return c
		end
		function n:CreateCheckbox(t, isSelected, setSelected)
			local c = Node(t)
			c.isSelected, c.setSelected = isSelected, setSelected
			function c:SetTooltip(fn) self.tooltip = fn end
			table.insert(self.children, c)
			return c
		end
		function n:CreateRadio(t, isSelected, setSelected)
			local c = Node(t)
			c.isSelected, c.setSelected = isSelected, setSelected
			table.insert(self.children, c)
			return c
		end
		function n:CreateDivider() end
		function n:CreateTitle() end
		return n
	end
	return Node("root")
end

-- MenuUtil's context menu: built at once into M.contextMenu.
MenuUtil = {
	CreateContextMenu = function(owner, generator)
		M.contextMenu = M.Menu()
		generator(owner, M.contextMenu)
	end,
}

function M.Printed(pattern)
	for _, line in ipairs(M.printed) do
		if line:find(pattern) then return line end
	end
	return nil
end

return M
