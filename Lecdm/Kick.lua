-- Lecdm: the interrupt bar (ns.db.kick). While your focus (or target) casts: its cast as a bar
-- the game fills (UnitCastingDuration / UnitChannelDuration: duration objects, secret in combat,
-- handed on as they are), its name (secret text, shown as it is), a shield while it can't be
-- interrupted (SetAlphaFromBoolean takes the secret flag), and your interrupt's icon with its
-- cooldown. A sound as it starts casting: the event says the unit cast, whatever its payload.
local _, ns = ...

local K = {}
ns.Kick = K

-- Each class's interrupts, the first you know shows.
K.SPELLS = {
	WARRIOR = { "Pummel", "Shield Bash" }, ROGUE = { "Kick" }, MAGE = { "Counterspell" },
	SHAMAN = { "Earth Shock" }, PRIEST = { "Silence" }, DRUID = { "Feral Charge", "Bash" },
	PALADIN = { "Hammer of Justice" }, HUNTER = { "Scatter Shot" }, WARLOCK = { "Death Coil" },
}
K.UNITS = { { "focus", "Your focus" }, { "target", "Your target" } }

local frame
local casting = false

local function Settings()
	return ns.db.kick
end

-- Your interrupt now: the first of your class's you know (and can use, if one can be).
function K.Spell()
	local _, class = UnitClass("player")
	local first
	for _, name in ipairs(K.SPELLS[class] or {}) do
		local ok, info = pcall(C_Spell.GetSpellInfo, name)
		local id = ok and type(info) == "table" and not ns.IsSecret(info.spellID) and info.spellID
		if id and ns.Bars.Known(id) then
			first = first or id
			local okU, usable = pcall(C_Spell.IsSpellUsable, id)
			if okU and not ns.IsSecret(usable) and usable then return id end
		end
	end
	return first
end

local function Build()
	if frame then return frame end
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		Settings().pos = { point, relPoint, x, y }
	end)
	frame.shade = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	frame.shade:SetPoint("TOPLEFT", -4, 4)
	frame.shade:SetPoint("BOTTOMRIGHT", 4, -4)
	frame.shade:SetColorTexture(0.3, 0.75, 0.95, 0.3)
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
	frame.label:SetText("Lecdm: the interrupt bar")
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("LEFT")
	frame.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	frame.cd:SetAllPoints(frame.icon)
	frame.cd:SetHideCountdownNumbers(false)
	frame.bar = CreateFrame("StatusBar", nil, frame)
	frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.bar:SetStatusBarColor(1, 0.7, 0.1)
	frame.bg = frame.bar:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetColorTexture(0, 0, 0, 0.6)
	frame.name = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.name:SetPoint("LEFT", 4, 0)
	frame.name:SetPoint("RIGHT", -4, 0)
	frame.name:SetJustifyH("LEFT")
	frame.shield = frame.bar:CreateTexture(nil, "OVERLAY")
	frame.shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
	frame.shield:SetPoint("CENTER", frame.bar, "LEFT", -2, 0)
	frame.shield:SetSize(20, 20)
	frame.shield:SetAlpha(0)
	return frame
end

-- Its place, size and whether it shows (unlocked: always, to drag).
function K.Apply()
	if not ns.db then return end
	local s = Settings()
	if not (s.enabled and ns.Enabled()) then
		if frame then frame:Hide() end
		return
	end
	local f = Build()
	local h = s.height or 18
	f:SetSize((s.width or 220) + h + 2, h)
	f.icon:SetSize(h, h)
	f.bar:ClearAllPoints()
	f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", h + 2, 0)
	f.bar:SetPoint("BOTTOMRIGHT")
	local pos = s.pos or { "CENTER", "CENTER", 0, 120 }
	f:ClearAllPoints()
	f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	local unlocked = ns.Bars.IsUnlocked()
	f.shade:SetShown(unlocked)
	f.label:SetShown(unlocked)
	f:EnableMouse(unlocked)
	f:Show()
	K.Update()
end

-- The interrupt's icon and cooldown, and the cast (or nothing).
function K.Update()
	if not (frame and frame:IsShown()) then return end
	local s = Settings()
	local id = K.Spell()
	frame.icon:SetTexture(id and ns.Bars.SpellIcon(id) or 134400)
	frame.icon:SetShown(id ~= nil)
	if id then
		local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
		if not (ok and (ns.IsSecret(dur) or dur) and pcall(frame.cd.SetCooldownFromDurationObject, frame.cd, dur)) then frame.cd:Clear() end
		local okCD, info = pcall(C_Spell.GetSpellCooldown, id)
		local onCD = okCD and type(info) == "table" and not ns.IsSecret(info.isActive) and info.isActive and not info.isOnGCD
		frame.bar:SetStatusBarColor(onCD and 0.6 or 1, onCD and 0.6 or 0.7, onCD and 0.6 or 0.1)
	end
	frame:SetAlpha((casting or ns.Bars.IsUnlocked()) and 1 or 0)
end

local function CastStarted(channel)
	local s = Settings()
	local unit = s.unit or "focus"
	local f = frame
	if not f then return end
	local okD, dur = pcall(channel and UnitChannelDuration or UnitCastingDuration, unit)
	if okD and dur then
		pcall(f.bar.SetTimerDuration, f.bar, dur, Enum.StatusBarInterpolation.Immediate,
			channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
	end
	local info = { pcall(channel and UnitChannelInfo or UnitCastingInfo, unit) }
	if info[1] then
		pcall(f.name.SetText, f.name, info[2] or "")
		-- UnitCastingInfo's 8th value, UnitChannelInfo's 7th: can't be interrupted.
		local flag = info[channel and 8 or 9]
		if flag ~= nil then pcall(f.shield.SetAlphaFromBoolean, f.shield, flag, 1, 0) else f.shield:SetAlpha(0) end
	end
	casting = true
	K.Update()
	ns.Alerts.Play(s.sound, "Interrupt", "the " .. unit .. " is casting")
end

local function CastStopped()
	casting = false
	K.Update()
end

local events = CreateFrame("Frame")
local unitEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }
function K.Listen()
	if not ns.db then return end
	events:UnregisterAllEvents()
	for _, e in ipairs({ "PLAYER_FOCUS_CHANGED", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE" }) do
		pcall(events.RegisterEvent, events, e)
	end
	for _, e in ipairs(unitEvents) do pcall(events.RegisterUnitEvent, events, e, Settings().unit or "focus") end
end
events:SetScript("OnEvent", function(_, event)
	if not (ns.db and Settings().enabled and frame) then return end
	local unit = Settings().unit or "focus"
	if event == "UNIT_SPELLCAST_START" then
		CastStarted(false)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		CastStarted(true)
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED"
		or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		CastStopped()
	elseif (event == "PLAYER_FOCUS_CHANGED" and unit == "focus") or (event == "PLAYER_TARGET_CHANGED" and unit == "target") then
		CastStopped()
	else
		K.Update()
	end
end)
