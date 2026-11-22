-- Lecdm: the defaults, shared helpers, events, the login message and /lecdm. Every setting lives
-- in a profile (Profiles.lua); ns.db is the profile the character uses. LecdmDB.log (the log) and
-- LecdmDB.welcomed are account-wide.
local ADDON, ns = ...

ns.ICON = "Interface\\AddOns\\Lecdm\\Media\\Icon" -- art/make_logo.py

local DEFAULTS = {
	enabled = true,                     -- off: nothing shows or plays, the addon stays loaded
	loginMessage = true,                -- a one-line reminder of /lecdm in chat at login
	classColour = false,                -- the options window in your class colour
	window = {},                        -- the options window: pos, size, tab
	minimap = { angle = 350, hide = false }, -- clear of the owner's other addons (200-325)
	test = { chat = "main", sounds = false }, -- where the diagnostics' lines go (Log.lua: ns.Debug);
	                                    -- the sound log (SoundLog.lua)
	-- the alerts (Alerts.lua): defaults, and spells' and buffs' own settings by key or name
	alerts = {
		defaults = {
			spells = { ready = "none", readyGlow = "none", procGlow = "modern", cdGlow = "none", fullGlow = "none", activeGlow = "none",
				glowColor = "gold" },
			buffs = { applied = "none", removed = "none", upGlow = "none", warn = 5, warnGlow = "none", glowColor = "gold",
				runningOut = "none", combatMissing = "none", combatChat = false,
				upAlpha = 1, upGrey = false, missingLook = "red", missingAlpha = 1,
				stackGlow = "none", stackOp = ">=", stackCount = 5,
				missingGlow = "pixel", missingColor = "red" },
			blizzard = { applied = "none", removed = "none", deaths = false },
		},
		spells = {}, buffs = {}, blizzard = {},
	},
	-- saved looks by name (Bars.lua: B.SaveStyle), for icon bars and for buff groups
	styles = { bars = {}, buffs = {} },
	-- the cooldown bars (Bars.lua): list = { bar ... } (B.NewBar has a bar's fields), seeded once
	-- from Blizzard's list, and whether Blizzard's Essential and Utility viewers are made invisible
	bars = { list = {}, seeded = false, nextID = 1, hideBlizzard = true },
	-- the buff groups (Auras.lua): list = { group ... } (A.NewGroup has a group's fields), seeded once
	buffs = { list = {}, seeded = false, nextID = 1,
		-- Blizzard's two buff viewers (Hosted.lua): "hide" (the default: Lecdm shows only what the
		-- player sets up), "take" (into Lecdm's place) or "leave"
		blizzard = {
			icons = { mode = "hide", gap = 4, grow = "CENTER", vertical = false, perRow = 12, showWhen = "always", alpha = 1, oocAlpha = 1 },
			bars = { mode = "hide", gap = 2, grow = "LEFT", showWhen = "always", alpha = 1, oocAlpha = 1 },
		},
	},
}
ns.DEFAULTS = DEFAULTS

function ns.CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and ns.CopyDefaults({}, v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			ns.CopyDefaults(dst[k], v)
		end
	end
	return dst
end

function ns.DeepCopy(t)
	local copy = {}
	for k, v in pairs(t) do copy[k] = type(v) == "table" and ns.DeepCopy(v) or v end
	return copy
end

function ns.Print(msg)
	print("|cff4fc3f7Lecdm|r: " .. msg)
end

-- "v0.1.0"; with withBuild, the build too ("v0.1.0 build abc1234"). The build is for chat only,
-- never the window.
function ns.Version(withBuild)
	local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	return "v" .. v .. (withBuild and ns.build and (" build " .. ns.build) or "")
end

-- A value may be secret in combat. Never compare, concatenate, index or even test one for nil:
-- ask first.
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

function ns.Enabled()
	return ns.db ~= nil and ns.db.enabled ~= false
end

function ns.SetEnabled(on)
	ns.db.enabled = on and true or false
	ns.Refresh()
end

-- After any setting changes, and when the profile changes: everything shown follows ns.db.
function ns.Refresh()
	if ns.Bars then ns.Bars.Build() end
	if ns.Auras then ns.Auras.Build() end
	if ns.Hosted then ns.Hosted.Build() end
	if ns.Alerts then ns.Alerts.Reschedule() end
	if ns.Theme then ns.Theme.Apply() end
	if ns.Minimap then ns.Minimap.Apply() end
	if ns.Window then ns.Window.Apply() end
end

-- "Reset all settings": every profile, every character's choices, then a reload.
StaticPopupDialogs.LECDM_RESET_ALL = {
	text = "Reset every Lecdm setting, in every profile and for every character, and reload the interface?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		LecdmDB = nil
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function ns.ResetAll()
	StaticPopup_Show("LECDM_RESET_ALL")
end

-- Once per session, at the first PLAYER_ENTERING_WORLD: a welcome the first time, then a short
-- reminder unless it's turned off.
local greeted = false
local function Greet()
	if greeted then return end
	greeted = true
	if not LecdmDB.welcomed then
		LecdmDB.welcomed = true
		ns.Print("thanks for installing! Type |cffffd100/lecdm|r or click the minimap button for the options. "
			.. "Your cooldowns are in two icon bars under your character: /lecdm move to drag them.")
	elseif ns.db.loginMessage then
		ns.Print(ns.Version(true) .. " loaded. Type |cffffd100/lecdm|r to open the options.")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		ns.Profiles.Init()
	elseif event == "ADDON_LOADED" and arg == "Blizzard_CooldownViewer" then
		ns.Listen.Setup()
	elseif event == "PLAYER_LOGIN" then
		ns.Profiles.Init() -- again: the surname may only be known now
		ns.Catalogue.Build()
		ns.Listen.Setup()
		ns.Minimap.Init()
		ns.Window.Register()
		ns.Refresh()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Greet()
	end
end)

-- Slash commands ---------------------------------------------------------------------------

-- /lecdm <page> opens that tab.
local PAGE_WORDS = {
	general = "general", settings = "general",
	bars = "bars", iconbars = "bars", icons = "bars", cooldowns = "bars",
	buffs = "buffs", auras = "buffs",
	alerts = "alerts", sounds = "alerts", glows = "alerts", sound = "alerts",
	test = "test", diagnostics = "test", diag = "test",
	profiles = "profiles",
}

local function Help()
	ns.Print(ns.Version(true) .. ". /lecdm opens the options.")
	ns.Print("/lecdm - open or close the options window (/lcdm for short)")
	ns.Print("/lecdm general | bars | buffs | alerts | diagnostics | profiles - open that tab")
	ns.Print("/lecdm profile - the profile in use, and the Profiles tab (where they're managed)")
	ns.Print("/lecdm minimap - show or hide the minimap button; /lecdm on | off - turn Lecdm on or off")
	ns.Print("/lecdm move - unlock the icon bars and buff groups to drag them; again to lock them")
	ns.Print("/lecdm buff - your buff groups' buffs; /lecdm buff <name> keep | missing | up | out sets one")
	ns.Print("Diagnostics: /lecdm status - Blizzard's Cooldown Manager, its list, what's listened to")
	ns.Print("/lecdm list - every spell Blizzard's Cooldown Manager lists for you, by section")
	ns.Print("/lecdm check - what an addon can read about your spells right now (try it in combat)")
	ns.Print("/lecdm blizz hide | show - make Blizzard's cooldown viewers invisible, or bring them back")
	ns.Print("/lecdm log - the log, ready to copy; /lecdm log clear empties it")
	ns.Print("/lecdm soundlog on | off - log every sound any addon plays, and which addon")
end

SLASH_LECDM1 = "/lecdm"
SLASH_LECDM2 = "/lcdm"
SlashCmdList.LECDM = function(msg)
	local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" then
		ns.Window.Toggle()
	elseif PAGE_WORDS[cmd] then
		ns.Window.Show(PAGE_WORDS[cmd])
	elseif cmd == "help" then
		Help()
	elseif cmd == "profile" then
		-- profiles are managed on their tab, nowhere else
		ns.Print("profile: " .. ns.Profiles.Current() .. ". They're managed on the Profiles tab.")
		ns.Window.Show("profiles")
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "on" or cmd == "off" then
		ns.SetEnabled(cmd == "on")
		ns.Print(cmd == "on" and "on." or "off: nothing shows or plays until you turn it on again.")
	elseif cmd == "status" then
		ns.Check.Status()
	elseif cmd == "list" then
		ns.Catalogue.PrintAll()
	elseif cmd == "check" then
		ns.Check.Run()
	elseif cmd == "move" then
		ns.Bars.SetUnlocked(not ns.Bars.IsUnlocked())
	elseif cmd == "blizz" then
		ns.Blizz.Set(rest)
	elseif cmd == "log" then
		if rest == "clear" then ns.LogWindow.Clear() else ns.LogWindow.Show() end
	elseif cmd == "buff" then
		ns.Auras.Slash(rest)
	elseif cmd == "soundlog" then
		ns.SoundLog.SetOn(rest == "on" or (rest ~= "off" and not ns.SoundLog.IsOn()))
	else
		ns.Print("unknown command '" .. cmd .. "'. /lecdm help lists the commands.")
	end
end
