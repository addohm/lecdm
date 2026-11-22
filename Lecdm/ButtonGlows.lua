-- Lecdm: glows on your action buttons (any bar addon's: the buttons Keybinds.lua finds), by rule.
-- ns.db.buttonGlows: list of rules { spell (a name, or "item:ID": the buttons holding it), when,
-- buff, pct, op, count, seconds, combat (only in combat), glow, color }. `when`:
--   usable    while it's off cooldown and usable (Lua knows, in combat too);
--   swing     late in a swing: `seconds` before the next main-hand swing (PLAYER_SWING);
--   buffUp, buffMissing  while a buff on you (from anyone) is up / missing: a presence container
--             the game sizes, a glow clipped to it (the missing glow's technique);
--   stacks    while a buff's stacks compare (op, count): an aura slot's application bar opening
--             clipped windows (as the stack glow);
--   targetBelow, targetAbove, playerBelow, playerAbove  the health under / over `pct`: an
--             invisible bar given the health (secret in combat: the game takes it) opens a
--             window as its fill crosses the mark.
-- Every glow is on Lecdm's own frames, laid over the button (a holder made its child). Aura
-- containers are made and set out of combat only (a change in combat waits for its end); the
-- rest follows the buttons in combat too.
local _, ns = ...

local G = {}
ns.ButtonGlows = G

G.WHEN = {
	{ "usable", "While it's ready and usable" },
	{ "buffUp", "While a buff is on you" },
	{ "buffMissing", "While a buff is missing" },
	{ "stacks", "At a number of stacks of a buff" },
	{ "targetBelow", "While the target's health is under" },
	{ "targetAbove", "While the target's health is over" },
	{ "playerBelow", "While your health is under" },
	{ "playerAbove", "While your health is over" },
	{ "swing", "Late in a swing" },
}
G.PCTS = {}
for _, p in ipairs({ 10, 20, 25, 30, 35, 40, 50, 60, 70, 75, 80, 90 }) do G.PCTS[#G.PCTS + 1] = { p, p .. "%" } end
G.SECONDS = { { 0.3, "0.3 s" }, { 0.5, "0.5 s" }, { 0.8, "0.8 s" }, { 1, "1 s" }, { 1.5, "1.5 s" } }

local placed = {} -- rule -> { [action button] = parts }
local pending = false
local lastSwing  -- { start, duration }
local swingTimer

function G.Rules()
	return ns.db and ns.db.buttonGlows or {}
end

function G.New(spell)
	local rule = { spell = spell, when = "usable", glow = "pixel", color = "gold", combat = false,
		pct = 20, op = ">=", count = 3, seconds = 0.5 }
	table.insert(ns.db.buttonGlows, rule)
	G.Build()
	return rule
end

function G.Delete(index)
	local rule = table.remove(ns.db.buttonGlows, index)
	if rule then G.Clear(rule) end
	G.Build()
end

function G.Set(rule, field, value)
	G.Clear(rule)
	rule[field] = value
	G.Build()
end

-- What a rule's condition needs: "lua" (Lecdm decides), "aura" (a container), "health".
local function Kind(rule)
	local w = rule.when
	if w == "buffUp" or w == "buffMissing" or w == "stacks" then return "aura" end
	if w == "targetBelow" or w == "targetAbove" or w == "playerBelow" or w == "playerAbove" then return "health" end
	return "lua"
end
G.Kind = Kind

local function Margin(size)
	return math.ceil(size * 0.25) + 3
end

-- The holder over a button: the glow's frames live in it; out of combat it fades when the rule
-- is for combat only.
local function Holder(button)
	local h = CreateFrame("Frame", nil, button)
	h:SetAllPoints(button)
	h:SetFrameLevel(button:GetFrameLevel() + 8)
	return h
end

-- A clipped area at the button (the glow's reach), for a window to open in.
local function Area(parent, button, margin)
	local area = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
	area:SetPoint("TOPLEFT", button, "TOPLEFT", -margin, margin)
	area:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", margin, -margin)
	area:SetClipsChildren(true)
	return area
end

local function GlowIn(parent, button, rule, size)
	local host = CreateFrame("Frame", nil, parent)
	host:SetAllPoints(button)
	local built = ns.Glow.Build(host, rule.glow, rule.color, size)
	ns.Glow.SetActive(built, true)
	return host, built
end

local function Invisible(b)
	b:SetSize(1, 1)
	b:EnableMouse(false)
end

-- An aura rule on a button: a presence container for buff up / missing, an aura slot with an
-- application bar for stacks.
local function AuraParts(parts, rule, button, size)
	local ids, count = ns.Auras.IDs(rule.buff or "")
	if count == 0 then return end
	local margin = Margin(size)
	local span = size + 2 * margin
	local c = CreateFrame("AuraContainer", nil, parts.holder, "CustomAuraContainerTemplate")
	c:SetUnit("player")
	c:SetSize(1, 1)
	c:Show()
	parts.container = c
	if rule.when == "stacks" then
		local op, n = rule.op or ">=", rule.count or 3
		local from, below
		if op == "<" then below = n elseif op == "<=" then below = n + 1
		elseif op == "=" then from, below = n, n + 1 elseif op == ">=" then from = n else from = n + 1 end
		local edge, k, max = from or below, span, math.max(n + 2, 30)
		c:SetPoint("TOPLEFT", button, "TOPLEFT")
		c:AddAuraSlot("stacks", "HELPFUL", { candidateFilters = { includeSpellIDs = ids }, initializeFrame = function(slot)
			slot:SetSize(1, 1)
			slot:EnableMouse(false)
			local bar = CreateFrame("StatusBar", nil, slot)
			bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
			bar:SetStatusBarColor(1, 1, 1, 0)
			bar:SetSize(k * max, 1)
			bar:SetPoint("LEFT", button, "LEFT", -margin + span - k * edge, 0)
			slot:SetApplicationBar(bar, { minApplications = 0, maxApplications = max, interpolation = Enum.StatusBarInterpolation.Immediate })
			local fill = bar:GetStatusBarTexture()
			-- Everything inside the slot (the game wants a button's parts to be its own), anchored
			-- to the action button.
			local parent = slot
			if from then
				local area = Area(parent, button, margin)
				local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
				window:SetHeight(span)
				window:SetPoint("LEFT", bar, "LEFT")
				window:SetPoint("RIGHT", fill, "RIGHT", k * (edge - from), 0)
				window:SetClipsChildren(true)
				parent = window
			end
			if below then
				local area = Area(parent, button, margin)
				local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
				window:SetHeight(span)
				window:SetPoint("LEFT", fill, "RIGHT", k * (edge - below), 0)
				window:SetPoint("RIGHT", bar, "RIGHT", 1, 0)
				window:SetClipsChildren(true)
				parent = window
			end
			local host = CreateFrame("Frame", nil, parent)
			host:SetAllPoints(button)
			local built = ns.Glow.Build(host, rule.glow, rule.color, size)
			for _, g in ipairs(built.groups) do slot:AddAuraShownAnimation(g) end
		end })
		c:SetAuraSlotEnabled("stacks", true)
		return
	end
	-- Presence: 1 px wide while the buff is missing, span + 1 while it's up (the game sizes it).
	c:AddAuraGroup("buff", "HELPFUL", { candidateFilters = { includeSpellIDs = ids }, maxFrameCount = 1, initializeFrame = Invisible })
	c:SetAuraGroupLayout("buff", { elementWidth = span + 1, elementHeight = span })
	c:SetPoint("TOPLEFT", button, "TOPLEFT", -margin - 1, margin)
	local clip = CreateFrame("Frame", nil, parts.holder, "DisableUntrustedLayoutScriptsTemplate")
	clip:SetClipsChildren(true)
	if rule.when == "buffUp" then
		-- The container less its first pixel: nothing while missing (1 px), the glow's area while
		-- up (span + 1 by span).
		clip:SetPoint("TOPLEFT", c, "TOPLEFT", 1, 0)
		clip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT")
	else
		-- From the container's right edge to the far side: the glow while missing.
		clip:SetPoint("TOPLEFT", c, "TOPRIGHT")
		clip:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", margin, -margin)
	end
	parts.clip = clip
	GlowIn(clip, button, rule, size)
end

-- A health rule: an invisible bar 100 * span wide given the health; the fill's end crosses the
-- glow's area within about 1% of health at `pct`.
local function HealthParts(parts, rule, button, size)
	local margin = Margin(size)
	local span = size + 2 * margin
	local width = span * 100
	local pct = rule.pct or 20
	local bar = CreateFrame("StatusBar", nil, parts.holder)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(1, 1, 1, 0)
	bar:SetSize(width, 1)
	-- The fill's end at pct sits at the area's right edge.
	bar:SetPoint("LEFT", button, "LEFT", -margin + span - width * pct / 100, 0)
	parts.bar = bar
	local fill = bar:GetStatusBarTexture()
	local area = Area(parts.holder, button, margin)
	local window = CreateFrame("Frame", nil, area, "DisableUntrustedLayoutScriptsTemplate")
	window:SetHeight(span)
	if rule.when == "targetAbove" or rule.when == "playerAbove" then
		window:SetPoint("LEFT", bar, "LEFT")
		window:SetPoint("RIGHT", fill, "RIGHT")
	else
		window:SetPoint("LEFT", fill, "RIGHT", -span, 0)
		window:SetPoint("RIGHT", bar, "RIGHT", 1, 0)
	end
	window:SetClipsChildren(true)
	parts.unit = (rule.when == "targetBelow" or rule.when == "targetAbove") and "target" or "player"
	GlowIn(window, button, rule, size)
end

-- Gives a health bar the unit's health now (secret in combat: the bar takes it as it is).
local function Feed(parts)
	if not parts.bar then return end
	local unit = parts.unit
	local okE, exists = pcall(UnitExists, unit)
	if okE and not ns.IsSecret(exists) and not exists then return end
	local okM, max = pcall(UnitHealthMax, unit)
	local okH, health = pcall(UnitHealth, unit)
	if okM and okH then
		pcall(parts.bar.SetMinMaxValues, parts.bar, 0, max)
		pcall(parts.bar.SetValue, parts.bar, health)
	end
end

-- Whether a Lua rule holds now.
local function Holds(rule)
	if rule.when == "usable" then
		local name = rule.spell
		local ok, info = pcall(C_Spell.GetSpellInfo, name)
		local id = ok and type(info) == "table" and not ns.IsSecret(info.spellID) and info.spellID
		if not id then return false end
		local okCD, cd = pcall(C_Spell.GetSpellCooldown, id)
		if okCD and type(cd) == "table" and not ns.IsSecret(cd.isActive) and not ns.IsSecret(cd.isOnGCD)
			and cd.isActive and not cd.isOnGCD then return false end
		local okU, usable = pcall(C_Spell.IsSpellUsable, id)
		if not okU or ns.IsSecret(usable) then return true end
		return usable == true
	elseif rule.when == "swing" then
		return lastSwing ~= nil and GetTime() >= lastSwing[1] + lastSwing[2] - (rule.seconds or 0.5)
			and GetTime() < lastSwing[1] + lastSwing[2]
	end
	return false
end

local function SizeOf(button)
	local ok, w = pcall(button.GetWidth, button)
	return (ok and not ns.IsSecret(w) and type(w) == "number" and w > 0) and w or 36
end

-- Drops a rule's frames (they're hidden; aura containers are switched off).
function G.Clear(rule)
	for _, parts in pairs(placed[rule] or {}) do
		parts.holder:Hide()
		if parts.container then
			pcall(parts.container.SetAuraGroupEnabled, parts.container, "buff", false)
			pcall(parts.container.SetAuraSlotEnabled, parts.container, "stacks", false)
		end
	end
	placed[rule] = nil
end

-- Makes every rule's frames on the buttons holding its spell. Out of combat (aura containers).
function G.Build()
	if not ns.db then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	for rule, list in pairs(placed) do
		local still = false
		for _, r in ipairs(G.Rules()) do if r == rule then still = true end end
		if not still then G.Clear(rule) end
		for button, parts in pairs(list) do
			local holding = false
			for _, b in ipairs(ns.Keybinds and ns.Keybinds.Buttons(rule.spell) or {}) do
				if b == button then holding = true end
			end
			if not holding then
				parts.holder:Hide()
				if parts.container then
					pcall(parts.container.SetAuraGroupEnabled, parts.container, "buff", false)
					pcall(parts.container.SetAuraSlotEnabled, parts.container, "stacks", false)
				end
				list[button] = nil
			end
		end
	end
	if not ns.Enabled() then
		for rule in pairs(placed) do G.Clear(rule) end
		return
	end
	for _, rule in ipairs(G.Rules()) do
		placed[rule] = placed[rule] or {}
		for _, button in ipairs(ns.Keybinds and ns.Keybinds.Buttons(rule.spell) or {}) do
			if not placed[rule][button] then
				local parts = { holder = Holder(button) }
				local size = SizeOf(button)
				local kind = Kind(rule)
				if kind == "aura" then
					pcall(AuraParts, parts, rule, button, size)
				elseif kind == "health" then
					HealthParts(parts, rule, button, size)
					Feed(parts)
				end
				placed[rule][button] = parts
			end
		end
	end
	G.Update()
end

-- Lua rules' glows, health bars, and combat-only fading; in combat too.
function G.Update()
	if not ns.db then return end
	local combat = ns.InCombat()
	for _, rule in ipairs(G.Rules()) do
		local kind = Kind(rule)
		local on = kind == "lua" and Holds(rule)
		for button, parts in pairs(placed[rule] or {}) do
			parts.holder:SetShown(true)
			parts.holder:SetAlpha((rule.combat and not combat) and 0 or 1)
			if kind == "lua" then
				ns.Glow.Show(parts.holder, on and rule.glow or "none", rule.color, SizeOf(button))
			elseif kind == "health" then
				Feed(parts)
				if parts.unit == "target" then
					local ok, exists = pcall(UnitExists, "target")
					if ok and not ns.IsSecret(exists) and not exists then parts.holder:SetAlpha(0) end
				end
			end
		end
	end
end

function G.ButtonsChanged()
	if InCombatLockdown() then
		pending = true
		G.Update()
		return
	end
	G.Build()
end

-- Late in a swing: on at the mark, off at the swing (timers from PLAYER_SWING; the next swing
-- starts them again).
local swingEnd
local function OnSwing(duration)
	lastSwing = { GetTime(), duration }
	if swingTimer then swingTimer:Cancel() end
	if swingEnd then swingEnd:Cancel() end
	swingEnd = C_Timer.NewTimer(duration, function()
		swingEnd = nil
		G.Update()
	end)
	local soonest
	for _, rule in ipairs(G.Rules()) do
		if rule.when == "swing" then
			local at = duration - (rule.seconds or 0.5)
			if at > 0 and (not soonest or at < soonest) then soonest = at end
		end
	end
	G.Update()
	if soonest then
		swingTimer = C_Timer.NewTimer(soonest, function()
			swingTimer = nil
			G.Update()
		end)
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
	"PLAYER_TARGET_CHANGED", "PLAYER_SWING" }) do
	pcall(events.RegisterEvent, events, e)
end
pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "player", "target")
pcall(events.RegisterUnitEvent, events, "UNIT_MAXHEALTH", "player", "target")
events:SetScript("OnEvent", function(_, event, a, b)
	if not ns.db or #G.Rules() == 0 then return end
	if event == "PLAYER_REGEN_ENABLED" then
		lastSwing = nil
		if pending then G.Build() else G.Update() end
	elseif event == "PLAYER_SWING" then
		if ns.IsSecret(a) or ns.IsSecret(b) or type(a) ~= "number" or (b ~= 0 and b ~= nil) then return end
		OnSwing(a)
	else
		G.Update()
	end
end)
