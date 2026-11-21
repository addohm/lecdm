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
check(#M.sounds == 0, "a sound played with no alert set")

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

-- Alerts on Blizzard's announcements: a buff in a buff group goes by the buff groups' settings,
-- anything else by Blizzard's icons'; its own setting wins; a target debuff that went with its
-- target is quiet.
local D = ns.db.alerts.defaults
D.buffs.removed = "RAID_WARNING"
D.blizzard.removed = "MAP_PING"
shout.cooldownID = 14
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no sound for a removal")
ns.Alerts.Set("buffs", "Battle Shout", "removed", "READY_CHECK")
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(M.sounds[#M.sounds] == SOUNDKIT.READY_CHECK, "a buff's own sound didn't win")
ns.Alerts.Set("buffs", "Battle Shout", "removed", nil)
D.buffs.removed = "none"
local sunderItem = M.AddItem("BuffIconCooldownViewer", 16)
M.target = { dead = false }
local before = #M.sounds
sunderItem:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
M.target = nil
M.RunTimers()
check(#M.sounds == before and Logged("quiet: Sunder Armor went with its target"), "a kill wasn't quiet")
M.target = { dead = false }
sunderItem:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
M.RunTimers()
check(#M.sounds == before + 1 and M.sounds[#M.sounds] == SOUNDKIT.MAP_PING, "an expiry on a live target was quiet")
M.target = nil
D.blizzard.removed = "none"
M.viewers.BuffIconCooldownViewer.itemFramePool.active[sunderItem] = nil

-- The test build's chat lines go where the Test build tab says: a chat tab by name, or nowhere;
-- replies to commands stay in the main chat.
check(#ns.ChatTabs() == 3 and ns.ChatTabs()[3].name == "Lecdm", "chat tabs not listed")
ns.db.test.chat = "Lecdm"
local printed = #M.printed
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(ChatFrame3.messages[#ChatFrame3.messages]:find("removed: Battle Shout") and #M.printed == printed, "debug line not in the Lecdm tab")
M.Slash("help")
check(#M.printed > printed, "a command's reply left the main chat")
M.chatTabs[3] = nil
printed = #M.printed
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(#M.printed == printed + 1, "with the tab gone, the line didn't fall back to the main chat")
M.chatTabs[3] = "Lecdm"
ns.db.test.chat = "off"
printed = #M.printed
local logged = #LecdmDB.log
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(#M.printed == printed and #LecdmDB.log == logged + 1, "with Nowhere, a debug line reached chat, or left the log")
ns.db.test.chat = "main"

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
local function Button(frame, key)
	for _, b in ipairs(frame.buttons) do
		if b.key == key then return b end
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
check(list[2].spells[1] == "slot:13" and list[1].spells[3] == 12292, "a spell didn't move bars")
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

-- Blizzard's icons and timer bars, taken in (the default): each sits in Lecdm's place, again
-- after each of Blizzard's layouts (in combat too); a hidden one's gap closes; "hide" makes the
-- viewer invisible; "leave" lets Blizzard keep them.
local iconViewer, barViewer = M.viewers.BuffIconCooldownViewer, M.viewers.BuffBarCooldownViewer
local function PlaceOf(item) return item.points[1] and item.points[1][2] end
local sunderBar = M.AddItem("BuffBarCooldownViewer", 16)
local second = M.AddItem("BuffIconCooldownViewer", 14)
second.layoutIndex, shout.layoutIndex = 2, 1
ns.Refresh()
check(PlaceOf(shout) and PlaceOf(shout).kindKey == "icons", "Blizzard's icon not in Lecdm's place")
check(PlaceOf(sunderBar) and PlaceOf(sunderBar).kindKey == "bars", "Blizzard's timer bar not in Lecdm's place")
check(iconViewer.alpha == 1 and barViewer.alpha == 1, "a taken-in viewer was made invisible")
M.combat = true
iconViewer:RefreshLayout()
check(PlaceOf(shout).kindKey == "icons" and PlaceOf(second).kindKey == "icons", "Blizzard's layout took the icons back")
M.combat = false
ns.db.buffs.blizzard.icons.grow = "LEFT"
ns.Refresh()
check(second.points[1][4] == 44, "second icon not after the first: " .. tostring(second.points[1][4]))
shout.shown = false
shout:UpdateShownState()
check(second.points[1][4] == 0, "a hidden icon's gap didn't close")
shout.shown = true
shout:UpdateShownState()
ns.db.buffs.blizzard.icons.grow = "CENTER"
ns.db.buffs.blizzard.bars.mode = "hide"
ns.Refresh()
check(barViewer.alpha == 0, "hide didn't make the timer bars invisible")
M.Fire("PLAYER_ENTERING_WORLD")
check(barViewer.alpha == 0, "hide not kept after a loading screen")
ns.db.buffs.blizzard.bars.mode = "leave"
ns.Refresh()
barViewer:RefreshLayout()
check(barViewer.alpha == 1 and PlaceOf(sunderBar) == barViewer, "leave didn't give Blizzard its bars back")
ns.db.buffs.blizzard.bars.mode = "take"
ns.Refresh()
check(PlaceOf(sunderBar).kindKey == "bars", "take didn't take the bars back")
iconViewer.itemFramePool.active[second] = nil
ns.Refresh()

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

-- Icon bar alerts: a sound when a spell comes off cooldown (once, not the GCD), a glow while
-- it's ready and usable, a proc glow while the game highlights it; a spell's own choice wins.
local function Glowing(frame)
	for _, built in pairs(frame.glows or {}) do
		for _, g in ipairs(built.groups) do
			if g.playing then return true end
		end
	end
	return false
end
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 6572) -- the proc from earlier ends
local SD = ns.db.alerts.defaults.spells
SD.ready = "READY_CHECK"
M.spells[100].active = true
M.Fire("SPELL_UPDATE_COOLDOWN")
local heard = #M.sounds
M.spells[100].active = false
M.Fire("SPELL_UPDATE_COOLDOWN")
check(#M.sounds == heard + 1 and M.sounds[#M.sounds] == SOUNDKIT.READY_CHECK, "no ready sound")
M.Fire("SPELL_UPDATE_COOLDOWN")
check(#M.sounds == heard + 1, "the ready sound repeated")
M.spells[100].gcd = true
M.Fire("SPELL_UPDATE_COOLDOWN")
M.spells[100].gcd = nil
M.Fire("SPELL_UPDATE_COOLDOWN")
check(#M.sounds == heard + 1, "the end of a GCD played the ready sound")
SD.ready = "none"
SD.readyGlow = "pixel"
ns.Refresh()
check(Glowing(charge.glow) and not Glowing(revenge.glow), "glow while ready wrong (ready and usable only)")
SD.readyGlow = "none"
ns.Alerts.Set("spells", 100, "readyGlow", "action")
check(Glowing(charge.glow) and charge.glow.glows["action:gold:40"], "a spell's own glow didn't win")
ns.Alerts.Set("spells", 100, "readyGlow", nil)
check(not Glowing(charge.glow), "glow not cleared")
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 6572)
check(Glowing(revenge.glow) and revenge.glow.glows["modern:gold:40"], "no proc glow")
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 6572)
check(not Glowing(revenge.glow), "proc glow not cleared")
M.spells[100].active = true
M.Fire("SPELL_UPDATE_COOLDOWN")

-- A spell's ⚙ menu: a submenu per setting, Default first; picking sets its own, Default clears.
local alertMenu = M.Menu()
ns.AlertsMenu("spells", 100, "Charge", alertMenu)
check(#alertMenu.children == 4 and alertMenu.children[1].text == "Sound when it's ready", "alert menu wrong")
local soundSub = alertMenu.children[1]
check(soundSub.children[1].text == "Default (None)" and soundSub.children[1].isSelected(), "Default not first and ticked")
soundSub.children[4].setSelected()
check(ns.Alerts.HasOwn("spells", 100) and ns.Alerts.Get("spells", 100, "ready") == "RAID_WARNING", "picking in the menu didn't set it")
soundSub.children[1].setSelected()
check(not ns.Alerts.HasOwn("spells", 100), "Default didn't clear it")

-- Items: the trinket slots go on the Utility bar. A slot shows what's equipped there while it has
-- a use effect, its cooldown drawn with SetCooldown (grey past 1.5 s); a bag item shows its count
-- and hides when you have none; a secret item cooldown is cleared, not an error.
list = ns.db.bars.list
check(list[2].spells[2] == "slot:13" and list[2].spells[3] == "slot:14", "trinket slots not seeded")
utility = BarFrame("Utility")
local topTrinket, bottomTrinket = Button(utility, "slot:13"), Button(utility, "slot:14")
check(topTrinket.shown and topTrinket.icon.texture == 7, "top trinket not shown")
check(not bottomTrinket.shown, "an empty trinket slot is shown")
M.slotCD[13] = { 100, 120 }
M.Fire("BAG_UPDATE_COOLDOWN")
check(topTrinket.cd.cooldown and topTrinket.cd.cooldown[2] == 120 and topTrinket.icon.desaturated, "trinket cooldown not drawn")
M.slotCD[13] = { 100, 1.5 }
M.Fire("BAG_UPDATE_COOLDOWN")
check(topTrinket.cd.cooldown and not topTrinket.icon.desaturated, "a GCD-length item cooldown went grey")
M.slotCD[13] = nil
M.combat = true
M.Fire("BAG_UPDATE_COOLDOWN")
check(topTrinket.cd.cooldown == nil, "a secret item cooldown left a swipe")
M.combat = false
ns.Bars.SetOnBar(list[2], "item:5512", true)
local stone = Button(utility, "item:5512")
check(stone and stone.shown and stone.count.text == "2", "bag item not shown with its count")
M.bag[5512] = 0
M.Fire("BAG_UPDATE_DELAYED")
check(not Button(utility, "item:5512").shown, "an item you have none of is shown")
M.bag[5512] = 2
M.Fire("BAG_UPDATE_DELAYED")
check(ns.Bars.EntryName("slot:13") == "Top trinket: Satchel of Potions" and ns.Bars.EntryName("item:5512") == "Healthstone", "entry names wrong")
local equipped, bags = ns.Bars.Equipped(), ns.Bars.BagItems()
check(#equipped == 2 and equipped[1] == "slot:13" and equipped[2] == "slot:14", "equipped list wrong")
check(#bags == 1 and bags[1] == "item:5512", "bag list wrong (once each, usable only)")

-- A bag item you have none of can show greyed with a 0 instead of hiding (the bar's choice).
list[2].emptyItems = "grey"
M.bag[5512] = 0
M.Fire("BAG_UPDATE_DELAYED")
stone = Button(utility, "item:5512")
check(stone.shown and stone.icon.desaturated and stone.count.text == "0", "an empty item isn't shown greyed with 0")
list[2].emptyItems = "hide"
M.bag[5512] = 2
M.Fire("BAG_UPDATE_DELAYED")

-- Buff groups: the first one is filled with your learned buffs from Blizzard's list (on you:
-- Battle Shout; not Sunder Armor, a debuff on the target). Each buff is an aura group in the
-- group's container, with every ID known for it, and an icon's parts bound.
local function BuffContainer()
	for _, c in ipairs(M.containers or {}) do
		if c.parent and c.parent.groupID == ns.db.buffs.list[1].id then return c end
	end
end
local buffs = ns.db.buffs.list
check(ns.db.buffs.seeded and #buffs == 1 and buffs[1].name == "Buffs", "buff group not seeded")
check(#buffs[1].entries == 1 and buffs[1].entries[1] == "Battle Shout", "seeded buffs wrong: " .. table.concat(buffs[1].entries, ", "))
local container = BuffContainer()
check(container and container.unit == "player", "no container for the buff group")
local function G(prefix)
	for key, g in pairs(container.groups) do
		if key:sub(1, #prefix) == prefix and g.enabled then return g, key end
	end
end
local keys = {}
for key, g in pairs(container.groups) do keys[#keys + 1] = key .. "=" .. tostring(g.enabled) end
local shoutGroup = G("Battle Shout/icons:32:0/")
check(shoutGroup and shoutGroup.enabled and shoutGroup.ids[6673], "Battle Shout's aura group missing: " .. table.concat(keys, ", ") .. tostring(M.Printed("set up")))
local bound = shoutGroup.button.bound
check(bound.SetIcon and bound.SetDurationCooldown and bound.SetDurationText and bound.SetApplicationCount, "icon parts not bound")
check(shoutGroup.layout.layoutIndex == 1 and shoutGroup.layout.elementWidth == 32, "aura group layout wrong")

-- Out of combat, a buff seen on you teaches its ID (another rank, another caster's).
M.buffsOnMe = { { name = "Battle Shout", spellId = 25289, icon = 1 }, { name = "Power Word: Fortitude", spellId = 1243, icon = 8 } }
M.Fire("UNIT_AURA", "player")
check(shoutGroup.ids[25289], "a rank seen on you wasn't learned")
check(not LecdmDB.auraIDs["Power Word: Fortitude"], "a buff in no group was learned")

-- Adding a buff from the ones on you; a change in combat waits for the end of combat.
ns.Auras.Learn("Power Word: Fortitude", 1243)
ns.Auras.SetInGroup(buffs[1], "Power Word: Fortitude", true)
check(G("Power Word: Fortitude/icons:32:0/").layout.layoutIndex == 2, "added buff not second")
M.combat = true
buffs[1].style = "bars"
ns.Refresh()
check(ns.Auras.IsPending() and not G("Battle Shout/bars:32:200/"), "a buff group was changed in combat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
local barGroup = G("Battle Shout/bars:32:200/")
check(barGroup and not G("Battle Shout/icons:32:0/"), "the timer bar look didn't replace the icons after combat")
check(barGroup.button.bound.SetDurationBar and barGroup.button.bound.SetSpellName and barGroup.layout.elementWidth == 200, "timer bar parts wrong")
check(container.axis == AnchorUtil.FlowLayoutAxis.Vertical, "timer bars not stacked")
buffs[1].style = "icons"
ns.Refresh()

-- A buff with no ID known yet waits; moving and taking out.
ns.Auras.SetInGroup(buffs[1], "Unheard Of", true)
check(not G("Unheard Of/"), "a buff with no IDs got an aura group")
ns.Auras.MoveEntry(buffs[1], 2, -1)
check(buffs[1].entries[1] == "Power Word: Fortitude" and G("Power Word: Fortitude/icons:32:0/").layout.layoutIndex == 1, "move up didn't reorder")
ns.Auras.SetInGroup(buffs[1], "Unheard Of", false)
check(#buffs[1].entries == 2, "taking a buff out didn't")

-- Unlocked, buff groups show their shade too; off, they're hidden and their groups disabled.
M.Slash("move")
check(container.parent.shade.shown and container.parent.mouse, "buff group not unlocked with the bars")
M.Slash("move")
M.Slash("off")
check(not container.parent.shown and not G("Battle Shout/icons:32:0/"), "buff group shown while off")
M.Slash("on")
check(container.parent.shown and G("Battle Shout/icons:32:0/"), "buff group not back")

-- Buff alerts: out of combat, a buff in a group coming or going on you plays its sounds; its
-- full duration is learned; the glow while up and the warning glow are part of the game's
-- button (so its aura group's key changes with them).
local BD = ns.db.alerts.defaults.buffs
BD.applied, BD.removed = "MAP_PING", "RAID_WARNING"
M.now = M.now + 10
M.buffsOnMe = {}
M.Fire("UNIT_AURA", "player")
M.buffsOnMe = { { name = "Battle Shout", spellId = 6673, icon = 1, duration = 120 } }
heard = #M.sounds
M.Fire("UNIT_AURA", "player")
check(#M.sounds == heard + 1 and M.sounds[#M.sounds] == SOUNDKIT.MAP_PING, "no applied sound out of combat")
check(LecdmDB.auraDur["Battle Shout"] == 120, "duration not learned")
M.buffsOnMe = {}
M.Fire("UNIT_AURA", "player")
check(M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no removed sound out of combat")
M.now = M.now + 10
M.buffsOnMe = { { name = "Battle Shout", spellId = 6673, icon = 1, duration = 120 } }
shout.cooldownID = 14
heard = #M.sounds
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraApplied)
M.Fire("UNIT_AURA", "player")
check(#M.sounds == heard + 1, "Blizzard's announcement and Lecdm's own reading both played")
BD.applied, BD.removed = "none", "none"
BD.warnGlow, BD.upGlow = "pixel", "autocast"
ns.Refresh()
local warned = G("Battle Shout/icons:32:0/autocast:gold:5:pixel:120")
check(warned and warned.button.bound.SetDurationBar, "the warning glow isn't timed on the button")
check(warned.button.bound.SetDurationText, "no time text")
BD.warnGlow, BD.upGlow = "none", "none"
ns.Refresh()
M.buffsOnMe = { { name = "Battle Shout", spellId = 25289, icon = 1 }, { name = "Power Word: Fortitude", spellId = 1243, icon = 8 } }

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
check(Logged("TrackedBuff %(3%): Battle Shout, equipment slot 13, Sunder Armor"), "list wrong")
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
ns.db.test.chat = "off"
ns.Window.RunDefaults()
check(ns.db.test.chat == "main", "Test build Defaults didn't reset")
M.Slash("alerts")
ns.db.alerts.defaults.spells.ready = "RAID_WARNING"
ns.Window.RunDefaults()
check(ns.db.alerts.defaults.spells.ready == "none", "Alerts Defaults didn't reset")
M.Slash("")
check(not ns.Window.IsShown(), "/lecdm didn't close the window")
Lecdm_OnAddonCompartmentClick()
check(ns.Window.IsShown(), "the addon compartment didn't open the window")

-- The Bars tab: a row per spell of the bar shown; the checklist ticks spells on and off it, from
-- Blizzard's sections and the spellbook.
M.Slash("bars")
local panel = ns.Window.CurrentPanel()
local first = ns.db.bars.list[1]
check(panel.parts.spellRows[#first.spells] and panel.parts.spellRows[1].key == first.spells[1], "spell rows missing")
local root = M.Menu()
panel.parts.top[#panel.parts.top].dropdown.generator(nil, root)
check(root.children[1].text == "Blizzard's Essential" and root.children[2].text == "Blizzard's Utility", "checklist sections wrong")
local book = root.children[3]
check(book and book.text == "Spellbook: Protection" and #book.children == 1, "spellbook section wrong")
check(root.children[4].text:find("^Equipped") and #root.children[4].children == 2, "equipped section wrong")
check(root.children[5].text:find("^In your bags") and root.children[5].children[1].text:find("Healthstone"), "bags section wrong")
check(root.children[4].children[2].text:find("Bottom trinket: empty") and root.children[4].children[2].text:find("nothing with a use effect"), "empty slot not explained: " .. tostring(root.children[4].children[2].text))
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
check(picker.dropdown.w == 150 and picker.dropdown.h == 24 and picker.dropdown.points[1][2] == 330, "picker not the buttons' size and place")
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
local deleteRow = panel.parts.top[11]
check(deleteRow.button.text == "Delete this icon bar", "delete button not where expected: " .. tostring(deleteRow.button.text))
deleteRow.button.scripts.OnClick()
M.Accept()
check(#ns.db.bars.list == 3 and picker.dropdown.text == "Cooldowns", "delete didn't, or didn't show the first bar")
ns.Bars.Delete(ns.db.bars.list[3].id)

-- The Test build tab's chat picker: main, each tab made by the player, nowhere.
M.Slash("test")
local testPanel = ns.Window.CurrentPanel()
local chatMenu = M.Menu()
local chatRow
for _, row in ipairs(testPanel.stack.rows) do
	if row.dropdown then chatRow = row end
end
chatRow.dropdown.generator(nil, chatMenu)
check(#chatMenu.children == 4 and chatMenu.children[1].text == "Main chat window" and chatMenu.children[4].text:find("Nowhere"), "chat picker entries wrong")
chatMenu.children[3].setSelected()
check(ns.db.test.chat == "Lecdm" and chatRow.dropdown.text == "Lecdm", "picking the Lecdm tab didn't")
ns.db.test.chat = "main"

-- The Buffs tab: the group picker, a row per buff, the checklist from Blizzard's list and the
-- buffs on you now (ticking one adds it, and learns its ID).
M.Slash("buffs")
local buffPanel = ns.Window.CurrentPanel()
check(buffPanel.parts.picker.dropdown.text == "Buffs", "buff group picker wrong")
check(buffPanel.parts.buffRows[1].name == ns.db.buffs.list[1].entries[1], "buff rows missing")
local buffMenu = M.Menu()
buffPanel.parts.checklist.dropdown.generator(nil, buffMenu)
check(buffMenu.children[1].text == "Yours, from Blizzard's list" and #buffMenu.children[1].children == 1, "Blizzard's buffs section wrong")
local onYou = buffMenu.children[2]
check(onYou.text:find("^On you now") and #onYou.children == 2, "on-you section wrong")
M.buffsOnMe[3] = { name = "Rallying Cry of the Dragonslayer", spellId = 22888, icon = 9 }
buffMenu = M.Menu()
buffPanel.parts.checklist.dropdown.generator(nil, buffMenu)
buffMenu.children[2].children[3].setSelected()
check(ns.Auras.GroupOf("Rallying Cry of the Dragonslayer") == ns.db.buffs.list[1] and LecdmDB.auraIDs["Rallying Cry of the Dragonslayer"][22888], "ticking a buff on you didn't add and learn it")
check(buffPanel.parts.style.box.text == "Icons", "show-as picker wrong")
-- The dropdown's Blizzard places: picking one shows what happens to them, and its layout.
local groupMenu = M.Menu()
buffPanel.parts.picker.dropdown.generator(nil, groupMenu)
local blizzIcons = groupMenu.children[2]
check(blizzIcons.text:find("^Blizzard's icons") and groupMenu.children[3].text:find("^Blizzard's timer bars"), "Blizzard places not in the dropdown")
blizzIcons.setSelected()
check(buffPanel.parts.picker.dropdown.text == "Blizzard's icons" and buffPanel.parts.blizzMode.shown, "Blizzard's icons page not shown")
check(buffPanel.parts.blizzMode.box.text == "Take them into Lecdm" and buffPanel.parts.blizzPerRow.shown, "Blizzard place rows wrong")
check(not buffPanel.parts.style.shown, "a buff group's rows shown on a Blizzard page")
groupMenu.children[1].setSelected()
M.Slash("bars")

-- No icon bars at all: only the dropdown and a note.
local saved = ns.db.bars.list
ns.db.bars.list = {}
ns.Window.Refresh()
check(panel.parts.none.shown and not panel.parts.top[2].shown, "the no-bars note isn't shown alone")
ns.db.bars.list = saved
ns.Refresh()
ns.Window.Hide()

-- Profiles: a new one starts at the defaults; switching back brings the old settings back.
ns.db.test.chat = "off"
check(ns.Profiles.New("Tank"), "couldn't make a profile")
check(ns.Profiles.Current() == "Tank" and ns.db.test.chat == "main", "new profile not at the defaults")
check(ns.Profiles.Switch("Brenna Ashford"), "couldn't switch back")
check(ns.db.test.chat == "off" and ns.db.test.pos[2] == 10, "old profile's settings lost")
ns.db.test.chat = "main"
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
