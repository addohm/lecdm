-- Lecdm's scenarios, run by run_tests.py against the fake client in wowmock.lua (WM).
-- ns is the addon's namespace after every file has loaded.
local M = WM

local function check(cond, msg)
	if not cond then error(msg, 2) end
end

local function Logged(pattern)
	for _, line in ipairs(LecdmDB.log) do
		if line:find(pattern) then return line end
	end
	return nil
end

-- Login, with test build 0.0.1's flat settings saved: they move into the character's profile.
LecdmDB = { sound = false, icons = true, pos = { "CENTER", 10, -100 }, log = { "old line" } }
local shout = M.AddItem("BuffIconCooldownViewer", 14)
M.Fire("ADDON_LOADED", "Lecdm")
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
check(ns.Profiles.Current() == "Brenna Ashford", "profile not named First Last: " .. tostring(ns.Profiles.Current()))
check(ns.db.test.sound == false and ns.db.test.pos[2] == 10, "0.0.1 settings not moved into the profile")
check(LecdmDB.sound == nil and LecdmDB.icons == nil and LecdmDB.pos == nil, "0.0.1 settings left at the top")
check(LecdmDB.log[1] == "old line", "the log was lost")
check(M.Printed("thanks for installing"), "no welcome the first time")
check(ns.Catalogue.byID[14] and ns.Catalogue.byID[14].name == "Battle Shout", "Blizzard's list not read")
check(ns.Catalogue.byID[15].name == "equipment slot 13", "an equipment entry has no name")
check(M.settingsCategory and M.settingsCategory.name == "Lecdm", "no Options > AddOns entry")
check(LecdmMinimapButton and LecdmMinimapButton.shown, "no minimap button")
ns.db.test.sound = true

-- A tracked buff dropping is heard: named through its cooldown ID, logged, raid warning played.
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(shout.alerts == 1, "Blizzard's own TriggerAlertEvent didn't run")
check(Logged("removed: Battle Shout %(Buffs%)"), "removal not logged")
check(M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no sound on removal")

-- In combat, in an instance, with a secret aura ID: still named, tagged, and the attempt to time
-- the aura ourselves is reported as refused.
M.combat, M.instance = true, true
shout.auraInstanceID, shout.auraDataUnit = M.SECRET, "player"
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraApplied)
local line = Logged("%[combat%] %[instance%] applied: Battle Shout")
check(line and line:find("aura ID secret") and line:find("is refused"), "secret aura not handled: " .. tostring(line))

-- Removed: whether the target is dead at that moment is in the line.
M.target = { dead = true }
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(Logged("removed: Battle Shout %(Buffs%).-target exists true, dead true"), "target state missing: " .. tostring(Logged("removed: Battle Shout")))
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
M.RunTimers()
local again = 0
for _, l in ipairs(LecdmDB.log) do if l:find("a frame later: target exists true, dead true") then again = again + 1 end end
check(again == 1, "a frame later logged " .. again .. " times for two removals, not once")
M.target = nil

-- A reused icon is named by the entry it has now, not the one it had.
shout.cooldownID = 11
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown)
check(Logged("on cooldown: Charge %(Buffs%)"), "reused icon named after its old entry")

-- A secret cooldown ID or event doesn't break the listener.
shout.cooldownID = M.SECRET
shout:TriggerAlertEvent(M.SECRET)
check(Logged("SECRET: SECRET cooldown ID"), "secret cooldown ID not handled")
check(not Logged("listener error"), "listener error: " .. tostring(Logged("listener error")))
shout.cooldownID = 14
M.combat, M.instance = false, false

-- Icons Blizzard makes later are hooked once, however often they're acquired.
local late = M.AddItem("EssentialCooldownViewer", 11)
M.viewers.EssentialCooldownViewer:OnAcquireItemFrame(late)
ns.Listen.Setup()
local before = #LecdmDB.log
late:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown)
check(#LecdmDB.log == before + 1, "a late icon logged " .. (#LecdmDB.log - before) .. " times, not once")
check(Logged("on cooldown: Charge %(Essential%)"), "late icon not heard")

-- Sound toggle.
M.Slash("sound")
check(ns.db.test.sound == false, "sound didn't turn off")
local sounds = #M.sounds
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(#M.sounds == sounds, "sound played while off")
M.Slash("sound")

-- Proc events are logged with the spell's name.
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 6572)
check(Logged("proc glow on: Revenge %(6572%)"), "proc not logged")

-- Test icons: learned Essential/Utility spells only, grey on cooldown, swipe from the duration,
-- at the position the profile has.
local function Icons()
	local icons = {}
	for _, f in ipairs(M.frames) do
		if f.spellID and f.icon and f.shown then icons[f.spellID] = f end
	end
	return icons
end
local icons = Icons()
check(icons[100] and icons[6572], "test icons missing")
check(not icons[12292], "an unlearned spell got a test icon")
check(icons[100].icon.desaturated == true, "spell on cooldown not grey")
check(icons[6572].icon.vertex == 0.4, "unusable spell not dark")
check(icons[100].cd.duration and icons[100].cd.duration.spell == 100, "swipe not given the duration")
local anchor = icons[100].parent
check(anchor.points[1][4] == 10, "test icons not where the profile has them")
M.secretDuration = true
M.Fire("SPELL_UPDATE_COOLDOWN")
check(Logged("refused the duration object"), "a refused duration not reported")
M.secretDuration = false
M.combat = true
M.Fire("SPELL_UPDATE_USABLE")
M.combat = false

-- /lecdm check, in combat with secret cooldown times: SECRET shown, nothing compared.
M.combat, M.secretCooldowns = true, true
M.Slash("check")
check(Logged("Charge: on cooldown true, GCD false, start SECRET"), "check line wrong: " .. tostring(Logged("Charge:")))
check(Logged("usable SECRET %(no power nil%), in range SECRET"), "secret usable/range not shown: " .. tostring(Logged("Charge:")))
check(Logged("trinket slot 13 Satchel of Potions: slot cooldown start SECRET, duration SECRET, enabled 1"), "trinket line wrong: " .. tostring(Logged("trinket slot 13")))
check(Logged("trinket slot 14: empty"), "empty trinket slot not reported")
check(M.Printed("check: 2 spells and the trinket slots logged"), "check summary missing")
M.combat, M.secretCooldowns = false, false

-- Off: nothing heard, no icons; on again: back.
M.Slash("off")
before = #LecdmDB.log
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(#LecdmDB.log == before, "heard while off")
check(not anchor.shown, "test icons shown while off")
M.Slash("on")
check(anchor.shown, "test icons not back")

-- The chat commands.
M.Slash("status")
check(M.Printed("Cooldown Manager: available"), "status missing availability")
check(M.Printed("listening to %d+ Blizzard icons"), "status missing listener count")
M.Slash("help")
check(M.Printed("/lecdm general | bars"), "help missing the tabs")
M.Slash("list")
check(Logged("TrackedBuff %(2%): Battle Shout, equipment slot 13"), "list wrong")
check(Logged("Utility %(1%): %*Death Wish"), "unlearned entry not marked")
M.Slash("move")
check(ns.Icons.IsMoving(), "move didn't unlock")
M.Slash("move")
M.Slash("icons")
check(ns.db.test.icons == false and not anchor.shown, "icons didn't turn off")
M.Slash("icons")
M.Slash("nonsense")
check(M.Printed("unknown command"), "unknown command not reported")

-- blizz hide/show: alpha 0 and back; Blizzard putting it back is logged.
local essential = M.viewers.EssentialCooldownViewer
essential:SetAlpha(0.8)
M.Slash("blizz hide")
check(essential.alpha == 0 and ns.Blizz.IsHidden(), "viewer not invisible")
essential:SetAlpha(1)
check(Logged("Blizzard set the Essential viewer's alpha to 1"), "Blizzard's alpha change not logged")
M.Slash("blizz show")
check(essential.alpha == 0.8, "viewer alpha not restored: " .. tostring(essential.alpha))

-- Blocked actions are logged (in chat when they're Lecdm's), and the first swings of a fight.
M.Fire("ADDON_ACTION_BLOCKED", "SomeAddon", "CastSpellByName()")
check(Logged("blocked: SomeAddon tried CastSpellByName%(%)"), "blocked action not logged")
M.Fire("PLAYER_REGEN_DISABLED")
for _ = 1, 5 do M.Fire("PLAYER_SWING", 2.6, 0) end
local swingLines = 0
for _, l in ipairs(LecdmDB.log) do if l:find("swing %d of this fight: duration 2.6") then swingLines = swingLines + 1 end end
check(swingLines == 3, "logged " .. swingLines .. " swings, not 3")

-- The host test: Blizzard's buff icons placed in Lecdm's row, and again after Blizzard's layout.
M.Slash("blizz hide")
local buffs = M.viewers.BuffIconCooldownViewer
shout.cooldownID = 14
M.Slash("host on")
check(ns.Blizz.IsHosting(), "host test not on")
check(buffs.alpha == 1, "the buff viewer wasn't made visible for the host test")
check(M.viewers.EssentialCooldownViewer.alpha == 0, "Essential lost its invisibility")
local hostFrame = shout.points[1][2]
check(hostFrame and hostFrame ~= buffs, "buff icon not placed in Lecdm's row")
M.combat = true
buffs:RefreshLayout()
check(shout.points[1][2] == hostFrame, "Blizzard's layout took the icon back")
M.combat = false
M.Slash("status")
check(M.Printed("host test on: Buffs placed %d+ times %(1 in combat%)"), "host counts missing")
M.Slash("host off")
check(not ns.Blizz.IsHosting(), "host test not off")
M.Slash("blizz show")

-- The options window: /lecdm opens it; every tab builds; the Test build tab's Defaults.
M.Slash("")
check(ns.Window.IsShown(), "/lecdm didn't open the window")
check(not (LecdmFrame.version.text or ""):find("build"), "the build shows in the window")
for _, id in ipairs(ns.Window.PageIds()) do
	ns.Window.Select(id)
	check(ns.Window.CurrentPanel().built, "tab " .. id .. " didn't build")
end
for _, word in ipairs({ "general", "bars", "buffs", "alerts", "test", "profiles" }) do
	M.Slash(word)
end
M.Slash("test")
ns.db.test.sound = false
ns.Window.RunDefaults()
check(ns.db.test.sound == true, "Test build Defaults didn't reset")
M.Slash("")
check(not ns.Window.IsShown(), "/lecdm didn't close the window")
Lecdm_OnAddonCompartmentClick()
check(ns.Window.IsShown(), "the addon compartment didn't open the window")
ns.Window.Hide()

-- Profiles: a new one starts at the defaults; switching back brings the old settings back.
ns.db.test.sound = false
check(ns.Profiles.New("Tank"), "couldn't make a profile")
check(ns.Profiles.Current() == "Tank" and ns.db.test.sound == true, "new profile not at the defaults")
check(ns.Profiles.Switch("Brenna Ashford"), "couldn't switch back")
check(ns.db.test.sound == false and ns.db.test.pos[2] == 10, "old profile's settings lost")
check(ns.Profiles.Delete("Tank"), "couldn't delete")
M.Slash("profile")
check(M.Printed("profile: Brenna Ashford"), "/lecdm profile wrong")

-- Reset all asks first, then clears everything and reloads.
ns.ResetAll()
M.Accept()
check(LecdmDB == nil and M.reloaded, "reset all didn't clear and reload")
LecdmDB = { log = {} }

-- The log window and clear.
M.Slash("log")
check(LecdmLog and LecdmLog.box.text:find("Lecdm v0.0.1%-dev"), "log window empty")
check(not LecdmLog.box.text:find("build"), "the build shows in the log window")
M.Slash("log clear")
check(#LecdmDB.log == 0, "log not cleared")
