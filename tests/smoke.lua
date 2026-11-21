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

-- The bars: two, filled from Blizzard's list once; learned spells shown, grey on cooldown, dark
-- when unusable, red out of range, the swipe from the duration object; Blizzard's Essential and
-- Utility viewers invisible.
local function BarFrame(name)
	for _, f in ipairs(M.frames) do
		if f.barID and f.label and f.label.text == name and f.shown then return f end
	end
end
local function Button(frame, spellID)
	for _, b in ipairs(frame.buttons) do
		if b.spellID == spellID then return b end
	end
end
local list = ns.db.bars.list
check(ns.db.bars.seeded and #list == 2, "bars not seeded: " .. #list)
check(list[1].name == "Cooldowns" and list[1].spells[1] == 100 and list[1].spells[2] == 6572, "Cooldowns bar wrong")
check(list[2].name == "Utility" and list[2].spells[1] == 12292, "Utility bar wrong")
local cooldowns, utility = BarFrame("Cooldowns"), BarFrame("Utility")
check(cooldowns and cooldowns.shown and utility, "bar frames missing")
local charge, revenge = Button(cooldowns, 100), Button(cooldowns, 6572)
check(charge.shown and revenge.shown, "learned spells not shown")
check(not Button(utility, 12292).shown, "an unlearned spell is shown")
check(charge.icon.desaturated == true and revenge.icon.desaturated == false, "grey on cooldown wrong")
check(revenge.icon.vertex == 0.4, "unusable spell not dark")
check(charge.cd.duration and charge.cd.duration.spell == 100, "swipe not given the duration")
check(M.viewers.EssentialCooldownViewer.alpha == 0 and M.viewers.UtilityCooldownViewer.alpha == 0, "Blizzard's Essential/Utility not invisible")
check(M.viewers.BuffIconCooldownViewer.alpha == 1, "Blizzard's buff viewer touched")
M.range[100] = false
M.Fire("SPELL_RANGE_CHECK_UPDATE", 100, false, true)
check(charge.icon.vertex == 1, "out of range not red")
M.range[100] = nil

-- Learning a spell shows it.
M.info[13].isKnown = true
M.Fire("SPELLS_CHANGED")
check(Button(utility, 12292).shown, "a newly learned spell not shown")
M.info[13].isKnown = false
M.Fire("SPELLS_CHANGED")
check(not Button(utility, 12292).shown, "an unlearned spell still shown")

-- Only when ready: Charge (on cooldown) hides and Revenge takes its place; only on cooldown: the
-- other way round.
list[1].show[100] = "ready"
ns.Refresh()
check(not charge.shown and revenge.shown, "only-when-ready didn't hide a spell on cooldown")
check(revenge.points[1][4] == 0, "the gap didn't close: " .. tostring(revenge.points[1][4]))
M.spells[100].active = false
M.Fire("SPELL_UPDATE_COOLDOWN")
check(charge.shown, "only-when-ready didn't show a ready spell")
list[1].show[6572] = "cooldown"
ns.Refresh()
check(not revenge.shown, "only-on-cooldown showed a ready spell")
M.spells[6572].active = true
M.Fire("SPELL_UPDATE_COOLDOWN")
check(revenge.shown and revenge.icon.desaturated, "only-on-cooldown didn't show a spell on cooldown")
list[1].show[100], list[1].show[6572] = nil, nil
M.spells[100].active, M.spells[6572].active = true, false

-- The GCD: swept unless the bar turns it off; never grey.
M.spells[6572].gcd = true
list[1].gcd = false
ns.Refresh()
check(revenge.cd.duration == nil and not revenge.icon.desaturated, "GCD swept or grey with the sweep off")
list[1].gcd = true
ns.Refresh()
check(revenge.cd.duration ~= nil, "no GCD sweep with it on")
M.spells[6572].gcd = nil

-- A refused duration object clears the swipe instead of erroring.
M.secretDuration = true
M.Fire("SPELL_UPDATE_COOLDOWN")
check(charge.cd.duration == nil, "a refused duration left a swipe")
M.secretDuration = false
M.combat = true
M.Fire("SPELL_UPDATE_USABLE")
M.combat = false

-- Moving spells between bars, ordering, a new bar, deleting it, starting over.
ns.Bars.SetOnBar(list[1], 12292, true)
check(#list[2].spells == 0 and list[1].spells[3] == 12292, "a spell didn't move bars")
ns.Bars.MoveSpell(list[1], 3, -1)
check(list[1].spells[2] == 12292 and list[1].spells[3] == 6572, "move up didn't")
local extra = ns.Bars.NewBar("Defensives")
ns.Refresh()
check(BarFrame("Defensives") and #list == 3, "new bar missing")
ns.Bars.Delete(extra.id)
check(#list == 2 and not BarFrame("Defensives"), "deleted bar still shown")
ns.Bars.StartOver()
list = ns.db.bars.list
check(#list == 2 and list[2].spells[1] == 12292 and list[1].spells[3] == nil, "start over didn't refill the bars")
cooldowns, utility = BarFrame("Cooldowns"), BarFrame("Utility")
charge, revenge = Button(cooldowns, 100), Button(cooldowns, 6572)

-- Unlock to drag: the bars catch the mouse and show their names only while unlocked.
check(not cooldowns.mouse and not cooldowns.shade.shown, "bars catch the mouse while locked")
M.Slash("move")
check(ns.Bars.IsUnlocked() and cooldowns.mouse and cooldowns.shade.shown and cooldowns.label.shown, "move didn't unlock")
M.Slash("move")
check(not ns.Bars.IsUnlocked() and not cooldowns.mouse, "move didn't lock")

-- Blizzard's icons back when the setting is off.
ns.db.bars.hideBlizzard = false
ns.Refresh()
check(M.viewers.EssentialCooldownViewer.alpha == 1, "Blizzard's Essential not given back")
ns.db.bars.hideBlizzard = true
ns.Refresh()
check(M.viewers.EssentialCooldownViewer.alpha == 0, "Blizzard's Essential not invisible again")

-- The spellbook in the checklist: spells with a cooldown, not passives, not Blizzard's.
local lines = ns.Bars.Spellbook()
check(#lines == 1 and lines[1].name == "Protection" and #lines[1].spells == 1 and lines[1].spells[1] == 2565, "spellbook wrong")

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
check(not cooldowns.shown, "bars shown while off")
check(M.viewers.EssentialCooldownViewer.alpha == 1, "Blizzard's icons still invisible while off")
M.Slash("on")
check(cooldowns.shown and M.viewers.EssentialCooldownViewer.alpha == 0, "bars not back")

-- The chat commands.
M.Slash("status")
check(M.Printed("Cooldown Manager: available"), "status missing availability")
check(M.Printed("listening to %d+ Blizzard icons"), "status missing listener count")
M.Slash("help")
check(M.Printed("/lecdm general | bars"), "help missing the tabs")
M.Slash("list")
check(Logged("TrackedBuff %(2%): Battle Shout, equipment slot 13"), "list wrong")
check(Logged("Utility %(1%): %*Death Wish"), "unlearned entry not marked")
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

-- The Bars tab: a row per spell of the bar shown; the checklist ticks spells on and off it, from
-- Blizzard's sections and the spellbook.
M.Slash("bars")
local panel = ns.Window.CurrentPanel()
local first = ns.db.bars.list[1]
check(panel.parts.spellRows[#first.spells] and panel.parts.spellRows[1].spellID == first.spells[1], "spell rows missing")
local root = M.Menu()
panel.parts.top[#panel.parts.top].dropdown.generator(nil, root)
check(root.children[1].text == "Blizzard's Essential" and root.children[2].text == "Blizzard's Utility", "checklist sections wrong")
local book = root.children[3]
check(book and book.text == "Spellbook: Protection" and #book.children == 1, "spellbook section wrong")
local chargeItem = root.children[1].children[1]
check(chargeItem.isSelected() == true, "Charge not ticked")
chargeItem.setSelected()
check(not ns.Bars.BarOf(100), "unticking didn't take Charge off")
chargeItem.setSelected()
check(ns.Bars.BarOf(100) == first, "ticking didn't put Charge back")
book.children[1].setSelected()
check(ns.Bars.BarOf(2565) == first and #panel.parts.spellRows >= #first.spells, "spellbook spell not added")

-- A spell on another icon bar says which, in the checklist.
root = M.Menu()
panel.parts.top[#panel.parts.top].dropdown.generator(nil, root)
local deathWish = root.children[2].children[1]
check(deathWish.text:find("Death Wish") and deathWish.text:find("%(on Utility%)"), "no (on Utility) label: " .. tostring(deathWish.text))
check(not root.children[1].children[1].text:find("%(on "), "a spell on this bar got an (on ...) label")

-- The icon bar dropdown: one entry per bar, the one shown ticked; picking another shows it;
-- "New icon bar..." opens the popup, which makes the bar (an empty name gets a number).
local picker = panel.parts.picker
check(picker.dropdown.text == "Cooldowns", "picker text wrong: " .. tostring(picker.dropdown.text))
local menu = M.Menu()
picker.dropdown.generator(nil, menu)
check(#menu.children == 3 and menu.children[1].text == "Cooldowns" and menu.children[1].isSelected(), "picker entries wrong")
menu.children[2].setSelected()
check(picker.dropdown.text == "Utility", "picking Utility didn't show it")
check(menu.children[3].text == "New icon bar..." and menu.children[3].onClick, "no New icon bar entry")
menu.children[3].onClick()
check(M.popup and M.popup.which == "LECDM_NEW_BAR", "no new-bar popup")
M.Accept("Defensives")
check(#ns.db.bars.list == 3 and picker.dropdown.text == "Defensives", "new bar not made and shown")
menu.children[3].onClick()
M.Accept("  ")
check(ns.db.bars.list[4].name == "Icon bar 4", "empty name not numbered: " .. tostring(ns.db.bars.list[4].name))

-- The name field renames the bar shown; Delete asks first.
local nameRow = panel.parts.top[3]
nameRow.box.text = "Big ones"
nameRow.box.scripts.OnEnterPressed(nameRow.box)
check(ns.db.bars.list[4].name == "Big ones" and picker.dropdown.text == "Big ones", "rename didn't")
local deleteRow = panel.parts.top[10]
check(deleteRow.button.text == "Delete this icon bar", "delete button not where expected: " .. tostring(deleteRow.button.text))
deleteRow.button.scripts.OnClick()
M.Accept()
check(#ns.db.bars.list == 3 and picker.dropdown.text == "Cooldowns", "delete didn't, or didn't show the first bar")
ns.Bars.Delete(ns.db.bars.list[3].id)

-- No icon bars at all: only the dropdown and a note.
local saved = ns.db.bars.list
ns.db.bars.list = {}
ns.Window.Refresh()
check(panel.parts.none.shown and not panel.parts.top[2].shown, "the no-bars note isn't shown alone")
ns.db.bars.list = saved
ns.Refresh()
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
