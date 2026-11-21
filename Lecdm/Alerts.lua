-- Lecdm: alerts. Sounds and glows for what's on Lecdm's icon bars, buff groups and Blizzard's
-- icons and timer bars it takes in. Each setting has a default (ns.db.alerts.defaults, the Alerts
-- tab) and may be set per spell or buff (ns.db.alerts.spells[key] / .buffs[name] /
-- .blizzard[name], the ⚙ menus).
--   Icon bars (Lecdm's own icons: Lua knows their state, in combat too):
--     ready      a sound when a spell or item comes off a real cooldown;
--     readyGlow  a glow while it's ready (and usable);
--     procGlow   a glow while the game highlights it (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW).
--   Buff groups (the game fills them; Lua only hears what Blizzard's Cooldown Manager announces
--   in combat, and reads your buffs out of combat):
--     applied, removed   sounds; in combat only for buffs Blizzard also tracks (its announcement);
--     upGlow             a glow while it's up (part of the game's button);
--     warn, warnGlow     the time turns red under `warn` seconds, and the glow comes then (timed
--                        by the game from the buff's duration, learned out of combat).
--   Blizzard's icons and timer bars (your debuffs on the target among them):
--     applied, removed   sounds, from Blizzard's announcement; deaths: also when the target died
--                        (a kill reads as "the target is gone a frame later", TESTING.md).
local _, ns = ...

local A = {}
ns.Alerts = A

A.SOUNDS = {
	{ "none", "None" },
	{ "say", "Say it (its name)" },
	{ "RAID_WARNING", "Raid warning" },
	{ "READY_CHECK", "Ready check" },
	{ "RAID_BOSS_EMOTE_WARNING", "Boss emote" },
	{ "UI_RAID_BOSS_WHISPER_WARNING", "Boss whisper" },
	{ "ALARM_CLOCK_WARNING_3", "Alarm clock" },
	{ "TELL_MESSAGE", "Whisper" },
	{ "MAP_PING", "Map ping" },
}
A.WARNS = { { 0, "Off" }, { 3, "3 s" }, { 5, "5 s" }, { 10, "10 s" }, { 15, "15 s" }, { 30, "30 s" }, { 60, "1 min" } }

-- A setting: the spell's or buff's own, else the default.
function A.Get(category, key, field)
	local own = ns.db.alerts[category][key]
	if own and own[field] ~= nil then return own[field] end
	return ns.db.alerts.defaults[category][field]
end

-- Sets (or, with nil, clears) a spell's or buff's own setting.
function A.Set(category, key, field, value)
	local all = ns.db.alerts[category]
	all[key] = all[key] or {}
	all[key][field] = value
	if next(all[key]) == nil then all[key] = nil end
	ns.Refresh()
end

function A.HasOwn(category, key)
	return ns.db.alerts[category][key] ~= nil
end

function A.Label(list, value)
	for _, v in ipairs(list) do
		if v[1] == value then return v[2] end
	end
	return tostring(value)
end

local function Speak(text)
	if not text or text == "" or not (C_VoiceChat and C_VoiceChat.SpeakText and C_TTSSettings) then return end
	pcall(function()
		local voice = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
		C_VoiceChat.SpeakText(voice, text, C_TTSSettings.GetSpeechRate(), C_TTSSettings.GetSpeechVolume(), true)
	end)
end

-- Plays a sound choice; "say" speaks `words` (a spell's or buff's name).
function A.Play(sound, words, why)
	if not sound or sound == "none" then return end
	if why then ns.Log("sound: " .. why) end
	if sound == "say" then
		Speak(words)
		return
	end
	local id = SOUNDKIT and SOUNDKIT[sound]
	if id then PlaySound(id, "Master") end
end

-- Icon bars ------------------------------------------------------------------------------

local procs = {}  -- spell name -> true while the game highlights it
local last = setmetatable({}, { __mode = "k" }) -- icon -> { key, onCooldown } last seen

-- Called for each icon after Bars.lua has updated it: the ready sound on the change off
-- cooldown, and which glow it has now.
function A.OnIcon(b, bar, onCooldown, usable)
	local key, name = b.key, b.name
	local seen = last[b]
	if seen and seen.key == key and seen.onCooldown and not onCooldown then
		A.Play(A.Get("spells", key, "ready"), name, "ready: " .. tostring(name))
	end
	last[b] = { key = key, onCooldown = onCooldown }
	local style = "none"
	if b.shown ~= false then
		if name and procs[name] then
			style = A.Get("spells", key, "procGlow")
		end
		if style == "none" and not onCooldown and usable ~= false then
			style = A.Get("spells", key, "readyGlow")
		end
	end
	if b.glow then ns.Glow.Show(b.glow, style or "none", A.Get("spells", key, "glowColor"), bar.size) end
end

local function SpellName(spellID)
	if ns.IsSecret(spellID) then return nil end
	local ok, name = pcall(C_Spell.GetSpellName, spellID)
	if ok and not ns.IsSecret(name) then return name end
end

-- Buffs and Blizzard's icons: Blizzard's announcements --------------------------------------

local heardAt = {} -- buff name -> GetTime() of Blizzard's last announcement for it

-- Which settings a name's announcement goes by: a buff group's, else Blizzard's icons'.
local function Category(name)
	if ns.Auras and ns.Auras.GroupOf(name) then return "buffs" end
	return "blizzard"
end

-- From Listen.lua: Blizzard's Cooldown Manager announced "OnAuraApplied" / "OnAuraRemoved" for
-- an icon (named through its cooldown ID). onTarget: the aura is on the target, not on you.
function A.OnAnnounced(event, name, onTarget)
	if not (name and ns.Enabled()) then return end
	heardAt[name] = GetTime()
	local category = Category(name)
	if event == "OnAuraApplied" then
		A.Play(A.Get(category, name, "applied"), name, "applied: " .. name)
	elseif event == "OnAuraRemoved" then
		local sound = A.Get(category, name, "removed")
		if sound == "none" then return end
		if onTarget and not (category == "blizzard" and A.Get(category, name, "deaths")) then
			-- A kill takes every debuff off at once: quiet if the target is gone a frame later.
			C_Timer.After(0, function()
				local ok, exists = pcall(UnitExists, "target")
				if ok and not ns.IsSecret(exists) and not exists then
					ns.Log("quiet: " .. name .. " went with its target")
					return
				end
				A.Play(sound, name, "removed: " .. name)
			end)
		else
			A.Play(sound, name, "removed: " .. name)
		end
	end
end

-- Out of combat, buffs coming and going on you are read directly (for buffs Blizzard doesn't
-- track), unless Blizzard announced the same one just now.
local shownBefore -- name -> true: the buffs in a group that were on you, last time
function A.OnBuffsRead(buffs)
	if not ns.Auras then return end
	local now = {}
	for _, b in ipairs(buffs) do
		if ns.Auras.GroupOf(b.name) then now[b.name] = true end
	end
	if shownBefore then
		local t = GetTime()
		for name in pairs(now) do
			if not shownBefore[name] and not (heardAt[name] and t - heardAt[name] < 1) then
				A.Play(A.Get("buffs", name, "applied"), name, "applied: " .. name)
			end
		end
		for name in pairs(shownBefore) do
			if not now[name] and not (heardAt[name] and t - heardAt[name] < 1) then
				A.Play(A.Get("buffs", name, "removed"), name, "removed: " .. name)
			end
		end
	end
	shownBefore = now
end

-- Combat: what was on you going in is unknown coming out; start afresh.
function A.ForgetBuffs()
	shownBefore = nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, spellID)
	if event == "PLAYER_REGEN_DISABLED" then
		A.ForgetBuffs()
		return
	end
	local name = SpellName(spellID)
	if not name then return end
	procs[name] = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or nil
	if ns.Bars then ns.Bars.UpdateAll(true) end
end)
