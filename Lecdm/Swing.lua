-- Lecdm: the swing timer on on-next-swing attacks (Heroic Strike, Cleave, Maul, Raptor Strike).
-- PLAYER_SWING gives each main-hand swing's duration, readable in combat (TESTING.md, test build
-- 1): a sweep of it runs over their icons on icon bars (bar.swingSweep) and over the action
-- buttons holding them (ns.db.swing.buttons). While one is queued for the next swing
-- (C_Spell.IsCurrentSpell), it's highlighted (ns.db.swing.queued). Lecdm's own frames only: on
-- the action buttons, a Cooldown and a texture of Lecdm's are laid over them.
local _, ns = ...

local S = {}
ns.Swing = S

S.ATTACKS = { ["Heroic Strike"] = true, ["Cleave"] = true, ["Maul"] = true, ["Raptor Strike"] = true }

local overlays = setmetatable({}, { __mode = "k" }) -- action button -> { swing, queued }
local lastSwing -- { start, duration } of the last main-hand swing in this fight

local function Sweep(owner, region)
	local cd = CreateFrame("Cooldown", nil, owner, "CooldownFrameTemplate")
	cd:SetAllPoints(region or owner)
	cd:SetDrawEdge(true)
	cd:SetDrawSwipe(true)
	cd:SetSwipeColor(1, 1, 1, 0.25)
	cd:SetReverse(true)
	cd:SetHideCountdownNumbers(true)
	cd:SetFrameLevel(owner:GetFrameLevel() + 4)
	return cd
end

local function Highlight(owner, region)
	local t = owner:CreateTexture(nil, "OVERLAY", nil, 7)
	t:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	t:SetBlendMode("ADD")
	t:SetAllPoints(region or owner)
	t:Hide()
	return t
end

-- The overlays on one of Lecdm's icons (an icon bar button).
local function IconParts(b)
	if not b.swingSweep then
		b.swingSweep = Sweep(b.over or b, b.icon)
		b.swingQueued = Highlight(b.over or b, b.icon)
	end
	return b.swingSweep, b.swingQueued
end

local function ButtonParts(button)
	local o = overlays[button]
	if not o then
		o = { swing = Sweep(button), queued = Highlight(button) }
		overlays[button] = o
	end
	return o.swing, o.queued
end

-- Every place an attack shows: (sweep, highlight, spellID or name) for Lecdm's icons on bars
-- that want it, and the action buttons holding one.
local function Places(fn)
	if not ns.db then return end
	if ns.Bars and ns.Bars.EachIcon then
		ns.Bars.EachIcon(function(b, bar)
			if b.spellID and b.name and S.ATTACKS[b.name] and bar.swingSweep then
				local sweep, queued = IconParts(b)
				fn(sweep, queued, b.spellID)
			end
		end)
	end
	if ns.db.swing.buttons and ns.Keybinds then
		for name in pairs(S.ATTACKS) do
			for _, button in ipairs(ns.Keybinds.Buttons(name)) do
				local sweep, queued = ButtonParts(button)
				fn(sweep, queued, name)
			end
		end
	end
end

function S.Update()
	local now = GetTime()
	Places(function(sweep, queued, spell)
		if lastSwing and now < lastSwing[1] + lastSwing[2] then
			sweep:SetCooldown(lastSwing[1], lastSwing[2])
		else
			sweep:Clear()
		end
		local ok, current = pcall(C_Spell.IsCurrentSpell, spell)
		queued:SetShown(ns.db.swing.queued and ok and not ns.IsSecret(current) and current == true)
	end)
end

-- After a rescan of the action buttons: the overlays on buttons no longer holding an attack go.
function S.ButtonsChanged()
	local holding = {}
	if ns.db and ns.db.swing.buttons and ns.Keybinds then
		for name in pairs(S.ATTACKS) do
			for _, button in ipairs(ns.Keybinds.Buttons(name)) do holding[button] = true end
		end
	end
	for button, o in pairs(overlays) do
		if not holding[button] then
			o.swing:Clear()
			o.queued:Hide()
		end
	end
	S.Update()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_SWING", "PLAYER_REGEN_ENABLED", "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, duration, swingType)
	if not (ns.db and ns.Enabled()) then return end
	if event == "PLAYER_SWING" then
		if ns.IsSecret(duration) or ns.IsSecret(swingType) or type(duration) ~= "number" then return end
		if swingType ~= 0 and swingType ~= nil then return end -- the main hand's
		lastSwing = { GetTime(), duration }
	elseif event == "PLAYER_REGEN_ENABLED" then
		lastSwing = nil
	end
	S.Update()
end)
