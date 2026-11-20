-- Lecdm: listening to Blizzard's Cooldown Manager. Every icon in Blizzard's four viewers runs
-- TriggerAlertEvent when the Cooldown Manager notices something: a tracked aura applied or
-- removed (for every tracked aura, whether or not the player set an alert), a spell going on
-- cooldown, a charge back, the cooldown ready (that one only for spells with an alert). Lecdm
-- hooks it on each icon with hooksecurefunc, which runs after Blizzard's code and changes
-- nothing. The icon's cooldown ID, read when the hook fires, names the entry; icons are reused
-- for other entries, so it's never cached per icon. Hooked icons are kept in a weak table: no
-- field is ever written on a Blizzard frame.
-- Proc events (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW / HIDE), blocked actions (ADDON_ACTION_BLOCKED /
-- FORBIDDEN, any addon's) and the first swings of each fight (PLAYER_SWING) are logged too.
local _, ns = ...

local L = {}
ns.Listen = L

L.VIEWERS = {
	{ global = "EssentialCooldownViewer", name = "Essential" },
	{ global = "UtilityCooldownViewer", name = "Utility" },
	{ global = "BuffIconCooldownViewer", name = "Buffs" },
	{ global = "BuffBarCooldownViewer", name = "Bars" },
}

local viewerNames = {} -- viewer frame -> short name
local hookedItems = setmetatable({}, { __mode = "k" })
local hookCount, eventCount = 0, 0
local eventNames -- alert event value -> name
local errorShown = false

local LABELS = {
	OnAuraApplied = "applied", OnAuraRemoved = "removed", OnCooldown = "on cooldown",
	Available = "ready", ChargeGained = "charge back", PandemicTime = "refresh window",
}

local function EventName(event)
	if ns.IsSecret(event) then return "SECRET" end
	if not eventNames then
		eventNames = {}
		for name, value in pairs(Enum.CooldownViewerAlertEventType or {}) do eventNames[value] = name end
	end
	return eventNames[event] or tostring(event)
end

local function Describe(item, event)
	local name = EventName(event)
	local id = item.cooldownID
	local entry = ns.IsSecret(id) and "SECRET cooldown ID" or ns.Catalogue.Name(id)
	local viewer = viewerNames[item.viewerFrame] or "?"
	local text = string.format("%s: %s (%s), shown=%s", LABELS[name] or name, entry, viewer, ns.Show(item:IsShown()))
	local isAura = name == "OnAuraApplied" or name == "OnAuraRemoved"
	if isAura then
		-- A secret can't even be tested for nil: ask first.
		local aura = item.auraInstanceID
		local state = "none"
		if ns.IsSecret(aura) then state = "secret" elseif aura then state = "readable" end
		text = text .. ", aura ID " .. state
		local unit = item.auraDataUnit
		if name == "OnAuraApplied" and state ~= "none" and not ns.IsSecret(unit) and unit and C_UnitAuras.GetAuraDuration then
			-- Can an addon time this aura itself? Blizzard's docs say not with a secret ID.
			local ok = pcall(C_UnitAuras.GetAuraDuration, unit, aura)
			text = text .. ", timing it ourselves " .. (ok and "works" or "is refused")
		end
		if name == "OnAuraRemoved" then
			-- Expired, or the target died? Can an addon tell at this moment?
			local okE, exists = pcall(UnitExists, "target")
			local okD, dead = pcall(UnitIsDead, "target")
			text = text .. ", target exists " .. (okE and ns.Show(exists) or "error")
				.. ", dead " .. (okD and ns.Show(dead) or "error")
		end
	end
	return text, name, isAura
end

-- At a removal the game may not have marked a dying target dead yet: one more look a frame later
-- (once per frame, however many auras went at once).
local lookPending = false
local function LookAgain()
	if lookPending or not (C_Timer and C_Timer.After) then return end
	lookPending = true
	C_Timer.After(0, function()
		lookPending = false
		local okE, exists = pcall(UnitExists, "target")
		local okD, dead = pcall(UnitIsDead, "target")
		ns.Log("  a frame later: target exists " .. (okE and ns.Show(exists) or "error")
			.. ", dead " .. (okD and ns.Show(dead) or "error"))
	end)
end

local function OnAlertEvent(item, event)
	if not ns.Enabled() then return end
	local ok, text, name, isAura = pcall(Describe, item, event)
	if not ok then
		if not errorShown then
			errorShown = true
			ns.Log("listener error (shown once): " .. tostring(text), true)
		end
		return
	end
	eventCount = eventCount + 1
	ns.Log(text, isAura)
	if name == "OnAuraRemoved" then
		if ns.db.test.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
		LookAgain()
	end
end

local function HookItem(item)
	if hookedItems[item] or type(item) ~= "table" or type(item.TriggerAlertEvent) ~= "function" then return end
	hookedItems[item] = true
	hookCount = hookCount + 1
	hooksecurefunc(item, "TriggerAlertEvent", OnAlertEvent)
end

function L.ActiveItems(viewer)
	local items = {}
	local pool = viewer.itemFramePool
	if pool and pool.EnumerateActive then
		pcall(function()
			for item in pool:EnumerateActive() do table.insert(items, item) end
		end)
	end
	return items
end

-- Hook the viewers once (new icons as Blizzard makes them), and every icon there already is.
function L.Setup()
	for _, v in ipairs(L.VIEWERS) do
		local viewer = _G[v.global]
		if viewer and not viewerNames[viewer] and type(viewer.OnAcquireItemFrame) == "function" then
			viewerNames[viewer] = v.name
			hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item) HookItem(item) end)
		end
		if viewer then
			for _, item in ipairs(L.ActiveItems(viewer)) do HookItem(item) end
		end
	end
end

function L.PrintStatus()
	local parts = {}
	for _, v in ipairs(L.VIEWERS) do
		local viewer = _G[v.global]
		if viewer then
			table.insert(parts, string.format("%s %s, alpha %s, %d icons", v.name,
				viewer:IsShown() and "shown" or "hidden", ns.Show(viewer:GetAlpha()), #L.ActiveItems(viewer)))
		else
			table.insert(parts, v.name .. " missing")
		end
	end
	ns.Print("Blizzard's viewers: " .. table.concat(parts, "; "))
	ns.Print("listening to " .. hookCount .. " Blizzard icons; " .. eventCount .. " changes heard so far")
end

local function SpellText(spellID)
	if ns.IsSecret(spellID) then return "SECRET spell" end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	return (ok and not ns.IsSecret(name) and name or "?") .. " (" .. tostring(spellID) .. ")"
end

local SWINGS = 3 -- swings logged per fight
local swings = 0

local events = CreateFrame("Frame")
for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
	"ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_SWING", "PLAYER_REGEN_DISABLED" }) do
	pcall(events.RegisterEvent, events, e) -- some may not exist on every client
end
events:SetScript("OnEvent", function(_, event, a, b)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		-- Logged even while Lecdm is off: any addon's, in chat when it's Lecdm's.
		local who = ns.Show(a)
		ns.Log((event == "ADDON_ACTION_BLOCKED" and "blocked: " or "forbidden: ") .. who .. " tried " .. ns.Show(b), who == "Lecdm")
		return
	end
	if not ns.Enabled() then return end
	if event == "PLAYER_REGEN_DISABLED" then
		swings = 0
	elseif event == "PLAYER_SWING" then
		swings = swings + 1
		if swings <= SWINGS then
			ns.Log("swing " .. swings .. " of this fight: duration " .. ns.Show(a) .. ", type " .. ns.Show(b))
		end
	else
		local on = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
		ns.Log("proc glow " .. (on and "on" or "off") .. ": " .. SpellText(a), on)
	end
end)
