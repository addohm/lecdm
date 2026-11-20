-- Lecdm test build 1: checks, in game, what Lecdm's plan relies on (ROADMAP.md):
--  * Blizzard's Cooldown Manager announces what it notices (a buff applied or removed, a spell
--    going on cooldown), in combat too, and an addon can listen without changing anything.
--  * What Blizzard's Cooldown Manager lists for the class on Forever.
--  * Which spell facts an addon can read in combat, and whether the game draws an addon's own
--    cooldown swipe from a duration object.
-- It only reads and logs. Nothing here writes Blizzard's Cooldown Manager data or Edit Mode.
local addonName, ns = ...

ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

local DEFAULTS = { sound = true, icons = true, log = {} }

function ns.Print(msg)
	print("|cff4fc3f7Lecdm|r " .. msg)
end

-- A value may be secret in combat. Never compare, concatenate or index with one: ask first.
function ns.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Text for a value that may be secret.
function ns.Show(v)
	if ns.IsSecret(v) then return "SECRET" end
	if v == nil then return "nil" end
	return tostring(v)
end

-- "[combat] [instance] " while fighting or inside an instance.
function ns.Where()
	local text = InCombatLockdown() and "[combat] " or ""
	local inInstance = IsInInstance()
	if inInstance then text = text .. "[instance] " end
	return text
end

-- Version alone in the UI; the build only in chat (login line, /lecdm help).
function ns.Version(withBuild)
	if withBuild and ns.build then return "v" .. ns.version .. " build " .. ns.build end
	return "v" .. ns.version
end

local function Status()
	ns.Print(ns.Version(true) .. ", test build 1")
	local okAvail, available, reason = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
	if okAvail then
		local text = available and "available" or "not available"
		if reason and reason ~= "" then text = text .. " (" .. ns.Show(reason) .. ")" end
		ns.Print("Blizzard's Cooldown Manager: " .. text .. ", setting cooldownViewerEnabled = "
			.. ns.Show(C_CVar.GetCVar("cooldownViewerEnabled")))
	else
		ns.Print("Blizzard's Cooldown Manager: couldn't ask (" .. tostring(available) .. ")")
	end
	local _, class = UnitClass("player")
	local okSpec, spec = pcall(C_SpecializationInfo.GetSpecialization)
	ns.Print("class " .. tostring(class) .. ", spec " .. (okSpec and ns.Show(spec) or "error"))
	ns.Catalogue.PrintCounts()
	ns.Listen.PrintStatus()
	ns.Print(#LecdmDB.log .. " lines in the log (/lecdm log to copy it)")
end

local function Help()
	ns.Print(ns.Version(true) .. ", test build 1. TESTING.md has what to try.")
	ns.Print("/lecdm: status: Cooldown Manager, Blizzard's list, what's being listened to")
	ns.Print("/lecdm list: every spell Blizzard's Cooldown Manager lists for you, by section")
	ns.Print("/lecdm check: what an addon can read about your spells right now (try it in combat)")
	ns.Print("/lecdm sound: sound on/off when a tracked buff drops (on: raid warning)")
	ns.Print("/lecdm icons: test icons on/off; /lecdm move: drag them (out of combat)")
	ns.Print("/lecdm blizz hide | show: make Blizzard's cooldown viewers invisible, or back")
	ns.Print("/lecdm log: the log, ready to copy; /lecdm log clear empties it")
end

local function Slash(msg)
	local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" or cmd == "status" then
		Status()
	elseif cmd == "help" then
		Help()
	elseif cmd == "list" then
		ns.Catalogue.PrintAll()
	elseif cmd == "check" then
		ns.Check.Run()
	elseif cmd == "sound" then
		LecdmDB.sound = not LecdmDB.sound
		ns.Print("sound when a tracked buff drops: " .. (LecdmDB.sound and "on" or "off"))
	elseif cmd == "icons" then
		ns.Icons.Toggle()
	elseif cmd == "move" then
		ns.Icons.Move()
	elseif cmd == "blizz" then
		ns.Blizz.Set(rest)
	elseif cmd == "log" then
		if rest == "clear" then ns.LogWindow.Clear() else ns.LogWindow.Show() end
	else
		ns.Print("unknown command. /lecdm help lists them.")
	end
end

SLASH_LECDM1 = "/lecdm"
SLASH_LECDM2 = "/lcdm"
SlashCmdList.LECDM = Slash

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		LecdmDB = LecdmDB or {}
		for k, v in pairs(DEFAULTS) do
			if LecdmDB[k] == nil then LecdmDB[k] = type(v) == "table" and {} or v end
		end
	elseif event == "ADDON_LOADED" and name == "Blizzard_CooldownViewer" then
		ns.Listen.Setup()
	elseif event == "PLAYER_LOGIN" then
		ns.Catalogue.Build()
		ns.Listen.Setup()
		ns.Icons.Build()
		ns.Print(ns.Version(true) .. " (test build 1) loaded. /lecdm help lists what to try.")
	end
end)
