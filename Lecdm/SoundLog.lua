-- Lecdm: the sound log (/lecdm soundlog, the Diagnostics tab). While it's on, every sound any
-- addon plays goes in the log (and to the diagnostics' chat lines): the sound's name if it's a
-- standard one, the addon that played it (from the call stack), and for Lecdm's own, why. It only
-- watches: hooksecurefunc runs after the game has played the sound.
local _, ns = ...

local S = {}
ns.SoundLog = S

local hooked = false
local kitNames -- sound kit ID -> SOUNDKIT name, made when first needed
local reason   -- set by Lecdm just before it plays a sound

local function On()
	return ns.db and ns.db.test.sounds
end

local function KitName(id)
	if not kitNames then
		kitNames = {}
		for name, kit in pairs(SOUNDKIT or {}) do
			if type(kit) == "number" then kitNames[kit] = name end
		end
	end
	return kitNames[id]
end

-- The addon in the call stack that played it: the first AddOns path that isn't this file.
local function Source()
	local ok, stack = pcall(debugstack, 3)
	if not ok or type(stack) ~= "string" then return "unknown" end
	for line in stack:gmatch("[^\n]+") do
		if not line:find("SoundLog.lua", 1, true) then
			local addon = line:match("AddOns[/\\]([^/\\]+)")
			if addon then return addon end
		end
	end
	return "the game (no addon in the call stack)"
end

function S.Reason(text)
	reason = On() and hooked and text or nil
end

local function Add(kind, what)
	if not On() then return end
	local why = reason
	reason = nil
	ns.Log(string.format("%s%s: %s, from %s%s", InCombatLockdown() and "[combat] " or "", kind, what, Source(),
		why and (" (" .. why .. ")") or ""), true)
end

local function Describe(id)
	if ns.IsSecret(id) then return "a hidden sound" end
	local name = type(id) == "number" and KitName(id)
	return name and (name .. " (" .. id .. ")") or tostring(id)
end

local function Hook()
	if hooked then return end
	hooked = true
	hooksecurefunc("PlaySound", function(id) pcall(Add, "sound", Describe(id)) end)
	if PlaySoundFile then
		hooksecurefunc("PlaySoundFile", function(file) pcall(Add, "sound file", Describe(file)) end)
	end
	if C_Sound and C_Sound.PlaySoundWithOptions then
		-- Blizzard's Cooldown Manager alerts play this way.
		hooksecurefunc(C_Sound, "PlaySoundWithOptions", function(params)
			pcall(Add, "sound", Describe(type(params) == "table" and params.soundKitID))
		end)
	end
	if C_VoiceChat and C_VoiceChat.SpeakText then
		hooksecurefunc(C_VoiceChat, "SpeakText", function(_, text) pcall(Add, "speech", Describe(text)) end)
	end
end

function S.IsOn()
	return On() and true or false
end

function S.SetOn(on)
	ns.db.test.sounds = on and true or false
	if on then
		Hook()
		ns.Print("sound log on: every sound any addon plays goes in the log (/lecdm log), with the addon that played it. /lecdm soundlog off stops it.")
	else
		ns.Print("sound log off. /lecdm log still has what was logged.")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	if On() then Hook() end
end)
