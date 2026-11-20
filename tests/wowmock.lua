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
	function f:ClearAllPoints() self.points = {} end
	function f:GetPoint() local p = self.points[1] or {} return p[1], p[2], p[3], p[4], p[5] end
	function f:SetScript(event, fn) self.scripts[event] = fn end
	function f:GetScript(event) return self.scripts[event] end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:SetChecked(v) self.checked = v end
	function f:GetChecked() return self.checked end
	function f:SetDesaturated(v) self.desaturated = v end
	function f:SetVertexColor(r) self.vertex = r end
	function f:SetTexture(t) self.texture = t end
	function f:SetBackdropBorderColor(r, g, b) self.border = { r, g, b } end
	function f:EnableMouse(v) self.mouse = v end
	function f:CreateTexture() return NewRegion("Texture", nil, self) end
	function f:CreateFontString() return NewRegion("FontString", nil, self) end
	function f:SetCooldownFromDurationObject(dur)
		if dur == SECRET then error("secret duration refused") end
		self.duration = dur
	end
	function f:Clear() self.duration = nil end
	return f
end

function CreateFrame(kind, name, parent, _template)
	local f = NewRegion(kind, name, parent)
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
Minimap = CreateFrame("Frame", "Minimap")
Minimap:SetSize(140, 140)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
SettingsPanel = CreateFrame("Frame", "SettingsPanel")
ChatFontNormal = {}
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 8959 }
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
function UnitClass() return "Warrior", "WARRIOR" end
M.name, M.surname = "Brenna", "Ashford"
function UnitName() return M.name, M.surname end
function IsInGroup() return false end
M.target = nil -- nil: no target; { dead = true/false }
function UnitExists(unit) return unit == "target" and M.target ~= nil end
function UnitIsDead(unit) return unit == "target" and M.target ~= nil and M.target.dead == true end
M.trinkets = { [13] = 12345 }
function GetInventoryItemID(_, slot) return M.trinkets[slot] end
function GetInventoryItemCooldown() return M.combat and SECRET or 0, M.combat and SECRET or 0, 1 end
C_Item = {
	GetItemNameByID = function() return "Satchel of Potions" end,
	GetItemCooldown = function() return 0, 0, true end,
}
function UnitGroupRolesAssigned() return "NONE" end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetCursorPosition() return 0, 0 end
function GetMinimapShape() return "ROUND" end
function ReloadUI() M.reloaded = true end
function HideUIPanel(f) f:Hide() end
function GameTooltip_Hide() end
YES, NO = "Yes", "No"
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
C_ClassColor = { GetClassColor = function(class) return RAID_CLASS_COLORS[class] end }
StaticPopupDialogs = {}
function StaticPopup_Show(which, text, _, data) M.popup = { which = which, text = text, data = data } end
function M.Accept()
	local p = M.popup
	M.popup = nil
	StaticPopupDialogs[p.which].OnAccept(nil, p.data)
end
M.timers = {}
C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }
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

Enum = {
	CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, GroupBuff = 4 },
	CooldownViewerAlertEventType = { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4,
		OnAuraApplied = 5, OnAuraRemoved = 6 },
}

-- Spells by ID, and Blizzard's list: section value -> cooldown IDs, cooldown ID -> info.
M.spells = {
	[6673] = { name = "Battle Shout", texture = 1 },
	[100] = { name = "Charge", texture = 2, active = true },
	[6572] = { name = "Revenge", texture = 3, usable = false },
	[12292] = { name = "Death Wish", texture = 4 },
}
M.sections = { [0] = { 11, 12 }, [1] = { 13 }, [2] = { 14, 15 }, [3] = {} }
M.info = {
	[11] = { cooldownID = 11, spellID = 100, isKnown = true, category = 0, linkedSpellIDs = {} },
	[12] = { cooldownID = 12, spellID = 6572, isKnown = true, category = 0, linkedSpellIDs = {} },
	[13] = { cooldownID = 13, spellID = 12292, isKnown = false, category = 1, linkedSpellIDs = {} },
	[14] = { cooldownID = 14, spellID = 6673, isKnown = true, hasAura = true, category = 2, linkedSpellIDs = {} },
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
	GetSpellName = function(id) return M.spells[id] and M.spells[id].name end,
	GetSpellTexture = function(id) return M.spells[id] and M.spells[id].texture end,
	GetSpellCooldown = function(id)
		local s = M.spells[id]
		return { isActive = s.active or false, isOnGCD = false, isEnabled = true,
			startTime = M.secretCooldowns and SECRET or 0, duration = M.secretCooldowns and SECRET or 0 }
	end,
	GetSpellCooldownDuration = function(id)
		if M.secretDuration then return SECRET end
		return { spell = id }
	end,
	GetSpellCharges = function() return nil end,
	IsSpellUsable = function(id)
		if M.combat then return SECRET end
		return M.spells[id].usable ~= false
	end,
	IsSpellInRange = function() return M.combat and SECRET or true end,
}

C_UnitAuras = {
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

function M.Printed(pattern)
	for _, line in ipairs(M.printed) do
		if line:find(pattern) then return line end
	end
	return nil
end

return M
