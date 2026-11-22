-- Lecdm: alerts. Sounds and glows for what's on Lecdm's icon bars, buff groups and Blizzard's
-- icons and timer bars it takes in. Each setting has a default (ns.db.alerts.defaults, the Alerts
-- tab) and may be set per spell or buff (ns.db.alerts.spells[key] / .buffs[name] /
-- .blizzard[name], the ⚙ menus).
--   Icon bars (Lecdm's own icons: Lua knows their state, in combat too):
--     ready      a sound when a spell or item comes off a real cooldown;
--     readyGlow  a glow while it's ready (and usable);
--     procGlow   a glow while the game highlights it (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW);
--     cdGlow     a glow while it's on a real cooldown;
--     fullGlow   a glow while a charge spell is at full charges;
--     activeGlow a glow while its buff is up, for a spell showing its buff on it (the game's
--                button, so in combat too).
--   Buff groups (the game fills them; Lua only hears what Blizzard's Cooldown Manager announces
--   in combat, and reads your buffs out of combat):
--     applied, removed   sounds; in combat only for buffs Blizzard also tracks (its announcement);
--     upGlow             a glow while it's up (part of the game's button);
--     warn, warnGlow     the time turns red under `warn` seconds, and the glow comes then (timed
--                        by the game from the buff's duration, learned out of combat);
--     runningOut         a sound at the warning time: out of combat from the buff's own timer;
--                        in combat from that, or from your own cast with the learned duration,
--                        unless someone else in the group could have recast it (your class);
--                        once per cast;
--     combatMissing, combatChat
--                        going into combat without a keep-up buff (from the last look out of
--                        combat): a sound, and the missing ones in chat;
--     stackGlow, stackOp, stackCount
--                        a glow at a number of stacks (fewer than, at most, exactly, at least,
--                        more than N), drawn by the game from the stacks, in combat too;
--     upAlpha, upGrey    how it looks while it's up: its opacity, greyed or not (icons come back
--                        to full strength at the warning time);
--     missingLook, missingAlpha, missingGlow, missingColor
--                        a keep-up buff's place while it's missing: a copy in full colour, grey
--                        or dimmed red, its opacity, and its glow.
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
A.ALPHAS = { { 1, "100%" }, { 0.9, "90%" }, { 0.75, "75%" }, { 0.6, "60%" }, { 0.5, "50%" }, { 0.4, "40%" }, { 0.25, "25%" } }
-- While a buff is up its opacity can be 0: hidden until the warning time, then shown (its last
-- seconds), as the warning glow is timed.
A.UP_ALPHAS = {}
for i, v in ipairs(A.ALPHAS) do A.UP_ALPHAS[i] = v end
A.UP_ALPHAS[#A.UP_ALPHAS + 1] = { 0, "Hidden until the warning time" }
A.WARNS = { { 0, "Off" }, { "auto", "Each buff's own" }, { 3, "3 s" }, { 5, "5 s" }, { 10, "10 s" }, { 15, "15 s" },
	{ 30, "30 s" }, { 60, "1 min" }, { 120, "2 min" } }

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

-- A buff's warning time in seconds. "auto": its own from Lecdm's list (BuffList.lua), else a
-- tenth of its learned duration, 3 s to 2 min (5 s until the duration is known).
function A.Warn(name)
	local warn = A.Get("buffs", name, "warn")
	if warn == "auto" then
		local e = ns.BuffList and ns.BuffList.Entry(name)
		if e and e.warn then return e.warn end
		local total = ns.Auras and ns.Auras.Duration(name)
		if not total then return 5 end
		return math.max(3, math.min(120, math.floor(total / 10 + 0.5)))
	end
	return tonumber(warn) or 0
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
	if ns.SoundLog then ns.SoundLog.Reason(why or words) end
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
		if style == "none" and b.fullCharges then
			style = A.Get("spells", key, "fullGlow") or "none"
		end
		if style == "none" and not onCooldown and usable ~= false then
			style = A.Get("spells", key, "readyGlow")
		end
		if style == "none" and onCooldown then
			style = A.Get("spells", key, "cdGlow") or "none"
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
		if category == "buffs" and not onTarget then A.StopRunningOut(name) end
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

-- Running out: one sound at a buff's warning time. Out of combat its own timer is read; in
-- combat nothing can be, so the time last read stands, and your own casts start it again with
-- the duration learned out of combat. A shared buff may have been recast by someone else since,
-- so in combat it only plays when nobody else in the group is of the class that casts it (Lecdm's
-- list's castBy; a buff not on it counts as your class's; a class the game won't tell counts as
-- one: better quiet than wrong). Never twice for one cast.
local runOut = {}   -- buff name -> { ends = GetTime() at its end, timer }
local playedFor = {} -- buff name -> the end it was played for
local lastRead      -- the buffs from the last look out of combat (Auras.ReadBuffs)

-- Whether someone else in the group is of this class.
local function OtherOfClass(mine)
	if not (IsInGroup and IsInGroup()) then return false end
	local raid = IsInRaid and IsInRaid()
	local ok, count = pcall(raid and GetNumGroupMembers or GetNumSubgroupMembers)
	if not ok or ns.IsSecret(count) or type(count) ~= "number" then return true end
	for i = 1, count do
		local unit = (raid and "raid" or "party") .. i
		local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
		if not (okSelf and isSelf == true) then
			local okClass, _, class = pcall(UnitClass, unit)
			if not okClass or ns.IsSecret(class) or class == mine then return true end
		end
	end
	return false
end

local function Near(a, b) return a and b and math.abs(a - b) < 3 end

local function PlayRunningOut(name, ends, why)
	if Near(playedFor[name], ends) then return end
	local e = ns.BuffList and ns.BuffList.Entry(name)
	local castBy = e and e.castBy
	if not e then castBy = select(2, UnitClass("player")) end
	if InCombatLockdown() and castBy and OtherOfClass(castBy) then
		ns.Log("quiet: " .. name .. " running out (someone else could have recast it)")
		return
	end
	playedFor[name] = ends
	A.Play(A.Get("buffs", name, "runningOut"), name, "running out: " .. name .. why)
end

function A.StopRunningOut(name)
	local r = runOut[name]
	if r then r.timer:Cancel() end
	runOut[name] = nil
end

-- Times the sound for a buff ending at `ends` (GetTime()); why: for the log.
local function RunOut(name, ends, why)
	local r = runOut[name]
	if r and math.abs(r.ends - ends) < 1 then return end
	A.StopRunningOut(name)
	if A.Get("buffs", name, "runningOut") == "none" then return end
	local warn = A.Warn(name)
	local left = ends - GetTime()
	if warn <= 0 or left <= 0 then return end
	if left <= warn then
		PlayRunningOut(name, ends, why)
		return
	end
	runOut[name] = { ends = ends, timer = C_Timer.NewTimer(left - warn, function()
		runOut[name] = nil
		PlayRunningOut(name, ends, why)
	end) }
end

-- Times every buff of the last look again (after a setting changed, out of combat: in combat
-- your casts since the last look would be lost).
function A.Reschedule()
	if not (lastRead and ns.Auras) or InCombatLockdown() then return end
	for _, b in ipairs(lastRead) do
		if b.expires and b.expires > 0 and ns.Auras.GroupOf(b.name) then
			A.StopRunningOut(b.name)
			RunOut(b.name, b.expires, "")
		end
	end
end

-- Your own cast of a buff in a group: it runs from now for its learned duration.
local function OnCast(spellID)
	local name = SpellName(spellID)
	if not (name and ns.Auras and ns.Auras.GroupOf(name)) then return end
	local total = ns.Auras.Duration(name)
	if total then RunOut(name, GetTime() + total, " (timed from your cast)") end
end

-- Going into combat: the keep-up buffs that weren't on you at the last look.
local function CombatStarted()
	if not (lastRead and ns.Auras and ns.Enabled()) then return end
	local on = {}
	for _, b in ipairs(lastRead) do on[b.name] = true end
	local missing, sound, chat = {}, nil, false
	for _, group in ipairs(ns.db.buffs.list) do
		for _, name in ipairs(group.entries) do
			local mode = ns.Auras.Mode(group, name)
			if (mode == "keep" or mode == "missing") and not on[name] then
				local s = A.Get("buffs", name, "combatMissing")
				local c = A.Get("buffs", name, "combatChat")
				if s ~= "none" or c then
					missing[#missing + 1] = name
					if s ~= "none" then sound = sound or s end
					chat = chat or c
				end
			end
		end
	end
	if #missing == 0 then return end
	local list = table.concat(missing, ", ")
	if sound then A.Play(sound, missing[1], "into combat without: " .. list) end
	if chat then ns.Print("into combat without " .. list) end
end

-- Out of combat, buffs coming and going on you are read directly (for buffs Blizzard doesn't
-- track), unless Blizzard announced the same one just now.
local shownBefore -- name -> true: the buffs in a group that were on you, last time
function A.OnBuffsRead(buffs)
	if not ns.Auras then return end
	lastRead = buffs
	local now = {}
	for _, b in ipairs(buffs) do
		if ns.Auras.GroupOf(b.name) then
			now[b.name] = true
			if b.expires and b.expires > 0 then RunOut(b.name, b.expires, "") else A.StopRunningOut(b.name) end
		end
	end
	for name in pairs(runOut) do
		if not now[name] then A.StopRunningOut(name) end
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
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, spellID, _, castSpellID)
	if event == "PLAYER_REGEN_DISABLED" then
		CombatStarted()
		A.ForgetBuffs()
		return
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if ns.db and ns.Enabled() then OnCast(castSpellID) end
		return
	end
	local name = SpellName(spellID)
	if not name then return end
	procs[name] = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or nil
	if ns.Bars then ns.Bars.UpdateAll(true) end
end)
