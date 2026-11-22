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
-- On cooldown: its own opacity and glow; "only when ready and usable" hides an unusable one.
local cdBar = ns.Bars.Get(cooldowns.barID)
cdBar.cdAlpha = 0.5
ns.db.alerts.defaults.spells.cdGlow = "pixel"
ns.Refresh()
check(charge.alpha == 0.5 and revenge.alpha == 1, "opacity on cooldown wrong")
check(charge.glow.glows and charge.glow.glows["pixel:gold:40"] and charge.glow.glows["pixel:gold:40"].regions[1].shown, "no glow on cooldown")
cdBar.show[6572] = "usable"
ns.Refresh()
check(not revenge.shown, "an unusable spell shown with only when ready and usable")
cdBar.show[6572], cdBar.cdAlpha, ns.db.alerts.defaults.spells.cdGlow = nil, 1, "none"
ns.Refresh()
-- A spell's own buff on its icon: an aura container on the icon, a slot for the spell's buff
-- (every rank by name), anchored to the icon; in combat the change waits; off: the slot goes.
local function ActiveOf(b)
	for _, c in ipairs(M.containers) do
		if c.parent == b then
			for k, s2 in pairs(c.slots) do
				if s2.enabled then return s2, c end
			end
			return nil, c
		end
	end
end
M.combat = true
ns.Bars.SetActive(cdBar, 100, true)
check(not ActiveOf(charge), "a buff slot made in combat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
local activeSlot = ActiveOf(charge)
check(activeSlot and activeSlot.ids[100] and activeSlot.button.bound.SetDurationCooldown and activeSlot.button.bound.SetApplicationCount,
	"no buff slot on the icon after combat")
check(activeSlot.button.allPoints == charge.icon, "the buff slot isn't on the icon")
ns.Bars.SetActive(cdBar, 100, false)
check(not ActiveOf(charge), "the buff slot stayed after turning it off")
-- The countdown near the end: a colour (the game's text binding, given the cooldown's duration;
-- the Cooldown's numbers hidden), or a decimal (the Cooldown's own) with no colour.
cdBar.threshold, cdBar.thresholdColor = 5, "red"
ns.Refresh()
check(charge.useBinding and charge.timeBinding.enabled and charge.timeBinding.duration and charge.timeBinding.duration.spell == 100
	and charge.cd.hideNumbers == true, "the countdown's colour near the end isn't the game's binding")
cdBar.thresholdColor, cdBar.thresholdDecimals = "none", true
ns.Refresh()
check(not charge.useBinding and charge.cd.msThreshold == 5 and charge.cd.hideNumbers == false, "the decimal near the end wrong")
cdBar.threshold, cdBar.thresholdColor, cdBar.thresholdDecimals = 0, "red", false
ns.Refresh()
-- A spell's own look: its border and colour, its icon; Default (nil) back to the bar's.
ns.Bars.SetLook(cdBar, 100, "border", 3)
ns.Bars.SetLook(cdBar, 100, "icon", 132333)
check(charge.edge.points[1][2] == -3 and charge.icon.texture == 132333 and revenge.edge.points[1][2] == -1, "a spell's own look wrong")
ns.Bars.SetLook(cdBar, 100, "border", nil)
ns.Bars.SetLook(cdBar, 100, "icon", nil)
check(charge.edge.points[1][2] == -1 and charge.icon.texture ~= 132333 and cdBar.looks[100] == nil, "a spell's look didn't go back to the bar's")
-- An empty space keeps a place, showing nothing; a spell or item added by its ID.
local spellsBefore = #cdBar.spells
ns.Bars.AddSpace(cdBar)
local spaceKey = cdBar.spells[#cdBar.spells]
local spaceButton = cooldowns.buttons[#cdBar.spells]
check(spaceKey == "space:1" and spaceButton.shown and not spaceButton.edge.shown and ns.Bars.EntryName(spaceKey) == "Empty space", "the empty space wrong")
check(ns.Bars.AddByID(cdBar, "item:5512") and ns.Bars.BarOf("item:5512") == cdBar and not ns.Bars.AddByID(cdBar, "424242"), "adding by ID wrong")
ns.Bars.SetOnBar(cdBar, "item:5512", false)
ns.Bars.SetOnBar(cdBar, spaceKey, false)
check(#cdBar.spells == spellsBefore, "the space or the item stayed")
-- Saved styles: a bar's look under a name, given to another; deleted.
cdBar.size, cdBar.barColor = 32, "red"
ns.Bars.SaveStyle("bars", cdBar, "Red")
cdBar.size, cdBar.barColor = 40, "blue"
ns.Bars.ApplyStyle("bars", ns.db.bars.list[2], "Red")
check(ns.db.bars.list[2].size == 32 and ns.db.bars.list[2].barColor == "red" and cdBar.size == 40, "a saved style wrong")
ns.Bars.DeleteStyle("bars", "Red")
check(ns.db.styles.bars.Red == nil, "a style wasn't deleted")
ns.db.bars.list[2].size, ns.db.bars.list[2].barColor = 40, "blue"
-- Import and export: the text reads back to the same; a shared bar joins with its spells
-- (taken from the bar they were on); damaged or foreign text is refused; nothing is run.
local T = ns.Transfer
local sample = { name = "Q \"x\"\nline", n = 3, f = 1.5, yes = true, no = false, list = { 100, "item:5512", { deep = -2 } } }
local back = T.Parse(T.Serialize(sample))
check(back and back.name == sample.name and back.n == 3 and back.f == 1.5 and back.yes == true and back.no == false
	and back.list[2] == "item:5512" and back.list[3].deep == -2, "the text didn't read back the same")
local text = T.Export("bar", ns.DeepCopy(cdBar))
local kind, data = T.Decode(text)
check(kind == "bar" and data.name == cdBar.name, "an exported bar didn't decode")
local before = #ns.db.bars.list
local ok, imported = T.Apply(kind, data)
check(ok and #ns.db.bars.list == before + 1 and imported.id ~= cdBar.id and ns.Bars.BarOf(100) == imported and #cdBar.spells == 0,
	"an imported bar wrong")
for _, key in ipairs(imported.spells) do table.insert(cdBar.spells, key) end
ns.Bars.Delete(imported.id)
check(ns.Bars.BarOf(100) == cdBar, "the spells didn't go back")
check(not T.Decode("Lecdm1:bar:{\"name\"=os.exit();}") and not T.Decode("hello") and not T.Decode("Lecdm1:bar:{\"a\"=1;"),
	"damaged or foreign text was taken")
local profileText = T.Export("profile", ns.db)
local pk, pdata = T.Decode(profileText)
local current = ns.Profiles.Current()
check(pk == "profile" and T.Apply(pk, pdata, "Shared one") and ns.Profiles.Current() == "Shared one", "a profile didn't import")
ns.Profiles.Switch(current)
ns.Profiles.Delete("Shared one")
-- The same in every profile: a bar copied into another profile, kept in step; there its spells
-- leave the bar they were on.
local mineProfile = ns.Profiles.Current()
ns.Profiles.New("Other one")
local otherDB = ns.db
ns.Profiles.Switch(mineProfile)
cdBar = ns.Bars.Get(cooldowns.barID)
ns.Bars.SetEverywhere(cdBar, true)
local copied
for _, bar in ipairs(otherDB.bars.list) do
	if bar.syncID == cdBar.syncID then copied = bar end
end
check(copied and copied.spells[1] == cdBar.spells[1] and copied.id ~= nil, "the bar wasn't copied to the other profile")
local holders = 0
for _, bar in ipairs(otherDB.bars.list) do
	for _, key in ipairs(bar.spells) do if key == 100 then holders = holders + 1 end end
end
check(holders == 1, "Charge on two bars in the other profile")
cdBar.size = 36
ns.Refresh()
check(copied.size == 36, "the copy wasn't kept in step")
ns.Bars.SetEverywhere(cdBar, false)
cdBar.size = 40
ns.Refresh()
check(copied.size == 36 and cdBar.syncID == nil, "turning it off changed the copy")
ns.Profiles.Delete("Other one")
-- Copying a bar's look to every bar: the look, not the spells or place.
cdBar.size, cdBar.shape = 36, "Round"
ns.Bars.CopyLook(cdBar)
check(ns.db.bars.list[2].size == 36 and ns.db.bars.list[2].shape == "Round" and ns.db.bars.list[2].spells ~= cdBar.spells, "copying the look wrong")
for _, bar in ipairs(ns.db.bars.list) do bar.size, bar.shape = 40, "square" end
ns.Refresh()
-- Best in your bags: one entry showing the best you carry (a Healthstone in the bags here), in
-- the bar's order for it.
ns.Bars.SetOnBar(cdBar, "best:3", true)
check(ns.Bars.ItemOf("best:3") == 5512 and ns.Bars.EntryKnown("best:3"), "the best healthstone isn't the one in the bags")
M.bag[9421] = 1
check(ns.Bars.ItemOf("best:3") == 9421, "a Major Healthstone isn't the best")
for i = 15, 2, -1 do ns.Bars.MoveBest(cdBar, "best:3", i, -1) end
check(ns.Bars.BestOrder(cdBar, "best:3")[1] == 5512 and ns.Bars.ItemOf("best:3") == 5512, "the order set didn't pick first")
M.bag[9421] = nil
ns.Bars.SetOnBar(cdBar, "best:3", false)
check(cdBar.bestOrder == nil or cdBar.bestOrder["best:3"] == nil, "the order stayed after taking it off")
-- As timer bars: the icon at the left, the bar filling from the cooldown's duration (full when
-- ready), the name; the bar's width.
cdBar.style = "bars"
ns.Refresh()
check(charge.w == 180 and charge.timer and charge.timer.shown and charge.timer.timerDuration and charge.timer.timerDuration.spell == 100,
	"a cooldown's timer bar wrong")
check(revenge.timerFull.shown and not revenge.timer.shown and revenge.timerName.text == "Revenge", "a ready spell's timer bar isn't full")
cdBar.barIconRight, cdBar.barReverse = true, true
ns.Bars.SetLook(cdBar, 100, "label", "Go!")
check(charge.icon.points[1][1] == "TOPRIGHT" and charge.timer.reverseFill and charge.spark and charge.spark.shown
	and charge.timerName.text == "Go!", "the timer bar's extras or its own name wrong")
ns.Bars.SetLook(cdBar, 100, "label", nil)
cdBar.barIconRight, cdBar.barReverse = false, false
cdBar.style = "icons"
ns.Refresh()
check(charge.w == 40 and not charge.timer.shown and not charge.timerFull.shown and not charge.spark.shown, "back to icons wrong")
-- Shapes: a mask on the icon and the swipe, a ring instead of the square border; square again;
-- a background behind the bar.
cdBar.shape, cdBar.background = "Round", 0.5
ns.Refresh()
local parts = charge.shapeParts
check(parts and charge.icon.masks[parts.mask] and parts.ring.shown and not charge.edge.shown
	and charge.cd.swipeTexture:find("Mask%-Round$") and cooldowns.bg.shown, "the round shape or the background wrong")
cdBar.shape, cdBar.background = "square", 0
ns.Refresh()
check(not charge.icon.masks[parts.mask] and not parts.ring.shown and charge.edge.shown and not cooldowns.bg.shown, "back to square wrong")
-- Anchored: an icon bar to a buff group, a buff group to an icon bar; the cursor; strata.
cdBar.anchorTo, cdBar.strata = ns.db.buffs.list[1].id, "HIGH"
ns.Refresh()
check(cooldowns.points[1][2] == ns.Auras.AnchorOf(ns.db.buffs.list[1].id) and cooldowns.points[1][1] == "TOP", "an icon bar anchored to a buff group wrong")
cdBar.anchorTo = "cursor"
ns.Refresh()
check(cooldowns.scripts.OnUpdate ~= nil, "an icon bar doesn't follow the cursor")
cdBar.anchorTo, cdBar.strata = nil, "MEDIUM"
ns.db.buffs.list[1].anchorTo, ns.db.buffs.list[1].anchorSide = cdBar.id, "right"
ns.Refresh()
check(ns.Auras.AnchorOf(ns.db.buffs.list[1].id).points[1][2] == cooldowns and cooldowns.scripts.OnUpdate == nil, "a buff group anchored to an icon bar wrong")
ns.db.buffs.list[1].anchorTo, ns.db.buffs.list[1].anchorSide = nil, "below"
ns.Refresh()
-- Items: the count always, never, or out of combat only; the border in the item's quality colour.
ns.Bars.SetOnBar(cdBar, "item:5512", true)
local stone
for _, b in ipairs(cooldowns.buttons) do
	if b.key == "item:5512" then stone = b end
end
check(stone and stone.count.text == "2", "the item count isn't shown")
cdBar.itemCount = "ooc"
ns.Refresh()
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(stone.count.text == "", "the item count shown in combat with out of combat only")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(stone.count.text == "2", "the item count not back out of combat")
cdBar.itemCount, cdBar.itemQuality = "always", true
ns.Refresh()
check(stone.edge.color[3] == 0.87 and charge.edge.color[1] == 0, "the quality border wrong")
cdBar.itemQuality = false
ns.Bars.SetOnBar(cdBar, "item:5512", false)
-- Key presses: using the action holding a spell shows its icon pressed for a moment.
cdBar.pressMirror = true
ns.Refresh()
M.actions[9] = { "spell", 100 }
UseAction(9)
check(charge.pushed and charge.pushed.shown, "the pressed look didn't show")
M.RunTimers()
check(not charge.pushed.shown, "the pressed look didn't go")
cdBar.pressMirror = false
M.actions[9] = nil
-- The interrupt bar: your interrupt's icon, the focus's cast (its duration to the bar, its name,
-- the can't-interrupt shield from the secret flag in combat), a sound as it starts; gone as it stops.
M.known = { [6552] = true }
M.spells[6552] = { name = "Pummel", texture = 5 }
ns.db.kick.enabled, ns.db.kick.sound = true, "RAID_WARNING"
ns.Refresh()
local kickFrame
for _, f in ipairs(M.frames) do
	if f.bar and f.shield and f.cd then kickFrame = f end
end
check(kickFrame and kickFrame.shown and kickFrame.alpha == 0 and kickFrame.icon.texture == 5, "the interrupt bar wrong before a cast")
M.casting.focus = { "Shadow Bolt", true }
M.combat = true
heard = #M.sounds
M.Fire("UNIT_SPELLCAST_START", "focus")
check(kickFrame.alpha == 1 and kickFrame.bar.timerDuration and kickFrame.bar.timerDuration.cast == "focus"
	and kickFrame.name.text == M.SECRET and kickFrame.shield.alpha == "secret", "the focus's cast not on the interrupt bar")
check(M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no sound as the focus started casting")
M.casting.focus = nil
M.Fire("UNIT_SPELLCAST_STOP", "focus")
check(kickFrame.alpha == 0, "the interrupt bar stayed after the cast")
M.combat = false
ns.db.kick.enabled, ns.db.kick.sound = false, "none"
ns.Refresh()
check(not kickFrame.shown, "the interrupt bar shown when off")
M.known = nil
-- Blizzard's sounds in the choices, by group; a kit plays; the name on screen with a sound.
ns.Alerts.AddBlizzardSounds()
check(#ns.Alerts.SOUND_GROUPS == 2 and ns.Alerts.SOUND_GROUPS[1][1] == "Animals" and ns.Alerts.Label(ns.Alerts.SOUNDS, "kit:316415") == "Animals: Wolf",
	"Blizzard's sounds not in the choices")
heard = #M.sounds
ns.Alerts.Play("kit:316500", "Charge", "test")
check(M.sounds[#M.sounds] == 316500, "a Blizzard sound didn't play")
ns.db.alerts.defaults.spells.screen = true
ns.Alerts.Play("MAP_PING", "Charge", "test", "spells", 100, "ready")
check(ns.Alerts.lastText == "Charge ready", "the name didn't show on screen with its sound")
ns.db.alerts.defaults.spells.screen = false
-- Charges: back to full plays its sound.
M.charges = { [6572] = { 1, 2, true } }
ns.Bars.UpdateAll()
ns.db.alerts.defaults.spells.fullSound = "READY_CHECK"
M.charges[6572] = { 2, 2, false }
heard = #M.sounds
ns.Bars.UpdateAll()
check(M.sounds[#M.sounds] == SOUNDKIT.READY_CHECK, "no sound back at full charges")
M.charges, ns.db.alerts.defaults.spells.fullSound = nil, "none"
ns.Bars.UpdateAll()
-- The swing timer: Heroic Strike's icon sweeps the main hand's swing, and is highlighted while
-- queued; on an action button holding it too, when asked.
M.known = { [78] = true }
ns.Bars.SetOnBar(cdBar, 78, true)
local hs
for _, b in ipairs(cooldowns.buttons) do
	if b.spellID == 78 then hs = b end
end
M.Fire("PLAYER_SWING", 2.4, 0)
check(hs and hs.swingSweep and hs.swingSweep.cooldown and hs.swingSweep.cooldown[2] == 2.4, "no swing sweep on Heroic Strike")
M.queuedSpell = 78
M.Fire("CURRENT_SPELL_CAST_CHANGED")
check(hs.swingQueued.shown, "a queued Heroic Strike isn't highlighted")
M.queuedSpell = nil
M.Fire("CURRENT_SPELL_CAST_CHANGED")
check(not hs.swingQueued.shown, "the highlight stayed")
local actionButton = CreateFrame("Button", "LecdmTestActionButton")
actionButton.action = 10
M.actions[10] = { "spell", 78 }
ns.db.swing.buttons = true
ns.Keybinds.Scan()
M.Fire("PLAYER_SWING", 2.2, 0)
local overlay
for _, f in ipairs(M.frames) do
	if f.parent == actionButton and f.cooldown then overlay = f end
end
check(overlay and overlay.cooldown[2] == 2.2, "no swing sweep on the action button")
ns.db.swing.buttons = false
M.actions[10] = nil
actionButton:Hide()
ns.Keybinds.Scan()
M.Fire("PLAYER_REGEN_ENABLED")
ns.Bars.SetOnBar(cdBar, 78, false)
M.known = nil
-- Glows on action buttons: a rule for the buttons holding a spell; while usable (Lecdm decides),
-- while a buff is missing (a presence container), under a health mark (a bar given the health),
-- late in a swing (timed from PLAYER_SWING), only in combat (faded out of it).
local glowButton = CreateFrame("Button", "LecdmTestGlowButton")
glowButton.action = 11
M.actions[11] = { "spell", 6673 }
ns.Keybinds.Scan()
local rule = ns.ButtonGlows.New("Battle Shout")
local function HolderOf()
	for _, f in ipairs(M.frames) do
		if f.parent == glowButton and f.glows then return f end
	end
end
local holder = HolderOf()
check(holder and holder.glows["pixel:gold:36"] and holder.glows["pixel:gold:36"].regions[1].shown, "no glow while Battle Shout is usable")
ns.ButtonGlows.Set(rule, "when", "buffMissing")
ns.ButtonGlows.Set(rule, "buff", "Battle Shout")
local presenceC
for _, c in ipairs(M.containers) do
	if c.groups.buff and c.parent and c.parent.parent == glowButton and c.groups.buff.enabled then presenceC = c end
end
check(presenceC and presenceC.groups.buff.ids[6673], "no presence container for a buff-missing glow")
ns.ButtonGlows.Set(rule, "when", "targetBelow")
local healthBar
for _, f in ipairs(M.frames) do
	if f.kind == "StatusBar" and f.parent and f.parent.parent == glowButton then healthBar = f end
end
check(healthBar, "no health bar for a health glow")
ns.ButtonGlows.Set(rule, "when", "swing")
ns.ButtonGlows.Set(rule, "seconds", 0.5)
holder = nil
for _, f in ipairs(M.frames) do
	if f.parent == glowButton and f.glows == nil and f.shown and f.kind == "Frame" then holder = f end
end
M.Fire("PLAYER_SWING", 2, 0)
local function SwingGlow()
	for _, f in ipairs(M.frames) do
		if f.parent == glowButton and f.glows and f.shown then
			local g = f.glows["pixel:gold:36"]
			if g and g.regions[1].shown then return true end
		end
	end
	return false
end
check(not SwingGlow(), "a late-in-swing glow early in the swing")
M.Advance(1.6)
check(SwingGlow(), "no late-in-swing glow late in the swing")
M.Advance(0.5)
check(not SwingGlow(), "the late-in-swing glow stayed after the swing")
ns.ButtonGlows.Set(rule, "when", "usable")
ns.ButtonGlows.Set(rule, "combat", true)
local faded
for _, f in ipairs(M.frames) do
	if f.parent == glowButton and f.glows and f.shown then faded = f end
end
check(faded and faded.alpha == 0, "a combat-only button glow showed out of combat")
ns.ButtonGlows.Delete(1)
check(#ns.db.buttonGlows == 0, "the rule wasn't deleted")
M.actions[11] = nil
glowButton:Hide()
ns.Keybinds.Scan()

-- Fonts: a face with an outline on the count and keybind; the count's place; the badge.
cdBar.fontFace, cdBar.fontOutline, cdBar.countPos, cdBar.keyBadge = "arial", "THICKOUTLINE", "TOPLEFT", 0.5
ns.Refresh()
check(charge.count.font and charge.count.font[1]:find("ARIALN") and charge.count.font[3] == "THICKOUTLINE"
	and charge.count.points[1][1] == "TOPLEFT" and charge.keyBadge.alpha == 0.5, "fonts, the count's place or the badge wrong")
cdBar.fontFace, cdBar.fontOutline, cdBar.countPos, cdBar.keyBadge = "default", "OUTLINE", "BOTTOMRIGHT", 0
ns.Refresh()
-- Conditions: hidden while mounted; only when resting and solo (all), or either (any).
cdBar.hideIf = { mounted = true }
M.mounted = true
ns.Refresh()
check(cooldowns.alpha == 0, "shown while mounted with hide when mounted")
M.mounted = false
M.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(cooldowns.alpha == 1, "not back after dismounting")
cdBar.hideIf, cdBar.showIf = nil, { resting = true, solo = true }
ns.Refresh()
check(cooldowns.alpha == 0, "shown with only when resting and solo, not resting")
cdBar.showMatch = "any"
ns.Refresh()
check(cooldowns.alpha == 1, "not shown with only when resting or solo, solo")
cdBar.showIf, cdBar.showMatch = nil, nil
ns.Refresh()
-- Glows: the pixel glow's dashes in its key; a solid fill; only in combat.
ns.db.alerts.defaults.spells.cdGlow = "pixel"
ns.db.alerts.pixel.lines = 3
ns.Refresh()
check(charge.glow.glows["pixel:gold:40:px3-2-0.6"] and #charge.glow.glows["pixel:gold:40:px3-2-0.6"].regions == 12, "the pixel glow's dashes wrong")
ns.db.alerts.pixel.lines = 2
ns.db.alerts.defaults.spells.cdGlow = "fill"
ns.Refresh()
check(charge.glow.glows["fill:gold:40"] and charge.glow.glows["fill:gold:40"].regions[1].shown, "no solid fill glow")
ns.db.alerts.combatOnly = true
ns.Refresh()
check(not charge.glow.glows["fill:gold:40"].regions[1].shown, "a glow out of combat with glows only in combat")
ns.db.alerts.combatOnly, ns.db.alerts.defaults.spells.cdGlow = false, "none"
ns.Refresh()
-- Overflow: past the most, the rest go on to another bar, after its own; rows up.
cdBar.maxIcons, cdBar.overflowTo = 1, ns.db.bars.list[2].id
ns.Refresh()
check(revenge.shown and revenge.points[1][2] == utility, "an icon past the most didn't go on to the other bar")
cdBar.maxIcons, cdBar.overflowTo = 0, nil
cdBar.rowsBack = true
ns.Refresh()
check(charge.points[1][1] == "BOTTOM" and revenge.points[1][2] == cooldowns, "rows going up wrong")
cdBar.rowsBack = false
ns.Refresh()
-- The swipe: reversed, its colour, the edge; none.
cdBar.swipe, cdBar.swipeColor, cdBar.edge = "reverse", "gold", true
ns.Refresh()
check(charge.cd.reverse and charge.cd.edge and charge.cd.swipeColor[1] == 1 and charge.cd.drawSwipe, "the swipe's look wrong")
cdBar.swipe = "off"
ns.Refresh()
check(charge.cd.drawSwipe == false, "the swipe drawn with None")
cdBar.swipe, cdBar.swipeColor, cdBar.edge = "normal", "dark", false
ns.Refresh()
-- Charges: the count (the game's, secret in combat), the recharge swipe while one comes back, a
-- glow at full charges; 0 hidden out of combat if the bar says so.
M.charges = { [6572] = { 1, 2, true } }
ns.Refresh()
check(revenge.count.text == 1 and revenge.cd.duration and revenge.cd.duration.charge == 6572, "charges count or recharge swipe wrong")
ns.db.alerts.defaults.spells.fullGlow = "pixel"
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 6572)
M.charges[6572] = { 2, 2, false }
ns.Refresh()
local glowKeys = {}
for k, v in pairs(revenge.glow.glows or {}) do glowKeys[#glowKeys + 1] = k .. "=" .. tostring(v.regions[1] and v.regions[1].shown) end
check(revenge.glow.glows["pixel:gold:40"] and revenge.glow.glows["pixel:gold:40"].regions[1].shown, "no glow at full charges: "
	.. table.concat(glowKeys, ",") .. " full=" .. tostring(revenge.fullCharges) .. " shown=" .. tostring(revenge.shown))
M.combat = true
ns.Bars.UpdateAll()
check(revenge.count.text == M.SECRET, "the secret count not handed to the game in combat")
M.combat = false
M.charges[6572] = { 0, 2, true }
cdBar.zeroCharges = false
ns.Refresh()
check(revenge.count.text == "", "0 charges shown with the bar hiding them")
M.charges, cdBar.zeroCharges, ns.db.alerts.defaults.spells.fullGlow = nil, true, "none"
ns.Refresh()
-- Stances: only in Defensive Stance hides it in Battle Stance; not in Battle Stance too; back
-- when the stance changes. The ⚙ menu lists the class's stances.
ns.Bars.SetForm(cdBar, 100, "in:71")
check(not charge.shown, "an only-in-Defensive spell shown in Battle Stance")
M.form = 2
M.Fire("UPDATE_SHAPESHIFT_FORM")
check(charge.shown, "an only-in-Defensive spell not shown in Defensive Stance")
ns.Bars.SetForm(cdBar, 100, "out:71")
check(not charge.shown, "a not-in-Defensive spell shown in Defensive Stance")
M.form = 1
ns.Bars.SetForm(cdBar, 100, nil)
check(charge.shown, "the stance condition didn't clear")
-- Tooltips on hover: off by default (clicks go through); on, the game's tooltip for the spell;
-- out of combat only, none in combat.
check(not charge.mouse, "an icon takes the mouse with tooltips off")
local chargeBar = ns.Bars.Get(cooldowns.barID) or ns.db.bars.list[1]
chargeBar.tooltip = "on"
ns.Refresh()
GameTooltip.spell = nil
charge.scripts.OnEnter(charge)
check(charge.mouse and GameTooltip.spell == 100, "no tooltip on hover")
chargeBar.tooltip = "ooc"
GameTooltip.spell = nil
M.combat = true
charge.scripts.OnEnter(charge)
check(GameTooltip.spell == nil, "a tooltip in combat with out of combat only")
M.combat = false
chargeBar.tooltip = "off"
ns.Refresh()
check(M.viewers.BuffIconCooldownViewer.alpha == 0 and M.viewers.BuffBarCooldownViewer.alpha == 0, "Blizzard's buff icons and timer bars not hidden by default")
-- A profile from 0.9.0-alpha (Blizzard's taken in) switches to hidden once; a later choice holds.
ns.db.buffs.hiddenByDefault = nil
ns.db.buffs.blizzard.icons.mode = "take"
ns.Refresh()
check(ns.db.buffs.blizzard.icons.mode == "hide", "an old profile didn't switch to hidden")
ns.db.buffs.blizzard.icons.mode = "take"
ns.Refresh()
check(ns.db.buffs.blizzard.icons.mode == "take", "a later choice was switched back")
ns.db.buffs.blizzard.icons.mode = "hide"
ns.Refresh()
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

-- Blizzard's icons and timer bars, taken in (when chosen; hidden is the default): each sits in Lecdm's place, again
-- after each of Blizzard's layouts (in combat too); a hidden one's gap closes; "hide" makes the
-- viewer invisible; "leave" lets Blizzard keep them.
local iconViewer, barViewer = M.viewers.BuffIconCooldownViewer, M.viewers.BuffBarCooldownViewer
local function PlaceOf(item) return item.points[1] and item.points[1][2] end
ns.db.buffs.blizzard.icons.mode, ns.db.buffs.blizzard.bars.mode = "take", "take"
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

-- Icon bar looks: border, zoom, countdown text; keybind text from any action button on screen.
list[1].border, list[1].zoom, list[1].countdown = 2, 0.15, "off"
ns.Refresh()
check(charge.edge.points[1][2] == -2 and charge.icon.texcoord[1] == 0.15 and charge.cd.hideNumbers == true, "look not applied")
list[1].border, list[1].zoom, list[1].countdown = 1, 0.08, "normal"
local actionButton = CreateFrame("CheckButton", "SomeBarButton1", UIParent)
actionButton.action = 5
actionButton.HotKey = actionButton:CreateFontString()
actionButton.HotKey:SetText("S1")
M.actions[5] = { "spell", 100 }
list[1].keybind = true
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()
check(charge.keyText.text == "S1", "keybind text missing: " .. tostring(charge.keyText.text))
actionButton.HotKey:SetText(RANGE_INDICATOR)
M.bindings["CLICK SomeBarButton1:LeftButton"] = "CTRL-MOUSEWHEELUP"
M.Fire("UPDATE_BINDINGS")
M.RunTimers()
check(charge.keyText.text == "CMwU", "click binding not used: " .. tostring(charge.keyText.text))
list[1].keybind = false
ns.Refresh()
check(charge.keyText.text == "", "keybind text shown while off")

-- Visibility: only in combat; faded out of combat.
list[1].showWhen = "combat"
ns.Refresh()
check(cooldowns.alpha == 0, "a combat-only bar showed out of combat")
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(cooldowns.alpha == 1, "a combat-only bar didn't show in combat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
list[1].showWhen, list[1].oocAlpha = "always", 0.3
ns.Refresh()
check(math.abs(cooldowns.alpha - 0.3) < 0.001, "out-of-combat fade wrong: " .. tostring(cooldowns.alpha))
list[1].oocAlpha = 1
ns.Refresh()

-- A spell's ⚙ menu: a submenu per setting, Default first; picking sets its own, Default clears.
local alertMenu = M.Menu()
ns.AlertsMenu("spells", 100, "Charge", alertMenu)
check(#alertMenu.children == #ns.ALERT_FIELDS.spells and alertMenu.children[1].text == "Sound when it's ready", "alert menu wrong")
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
local shoutGroup = G("Battle Shout/icons:32:0:")
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
check(G("Power Word: Fortitude/icons:32:0:").layout.layoutIndex == 2, "added buff not second")
M.combat = true
buffs[1].style = "bars"
ns.Refresh()
check(ns.Auras.IsPending() and not G("Battle Shout/bars:32:200:"), "a buff group was changed in combat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
local barGroup = G("Battle Shout/bars:32:200:")
check(barGroup and not G("Battle Shout/icons:32:0:"), "the timer bar look didn't replace the icons after combat")
check(barGroup.button.bound.SetDurationBar and barGroup.button.bound.SetSpellName and barGroup.layout.elementWidth == 200, "timer bar parts wrong")
check(container.axis == AnchorUtil.FlowLayoutAxis.Vertical, "timer bars not stacked")
buffs[1].style = "icons"
ns.Refresh()

-- A buff with no ID known yet waits; moving and taking out.
ns.Auras.SetInGroup(buffs[1], "Unheard Of", true)
check(not G("Unheard Of/"), "a buff with no IDs got an aura group")
ns.Auras.MoveEntry(buffs[1], 2, -1)
check(buffs[1].entries[1] == "Power Word: Fortitude" and G("Power Word: Fortitude/icons:32:0:").layout.layoutIndex == 1, "move up didn't reorder")
ns.Auras.SetInGroup(buffs[1], "Unheard Of", false)
check(#buffs[1].entries == 2, "taking a buff out didn't")

-- Unlocked, buff groups show their shade too; off, they're hidden and their groups disabled.
M.Slash("move")
check(container.parent.shade.shown and container.parent.mouse, "buff group not unlocked with the bars")
M.Slash("move")
M.Slash("off")
check(not container.parent.shown and not G("Battle Shout/icons:32:0:"), "buff group shown while off")
M.Slash("on")
check(container.parent.shown and G("Battle Shout/icons:32:0:"), "buff group not back")

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
local warned = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/autocast:gold:5:pixel:120")
check(warned and warned.button.bound.SetDurationBar, "the warning glow isn't timed on the button")
check(warned.button.bound.SetDurationText, "no time text")
BD.warnGlow, BD.upGlow = "none", "none"
ns.Refresh()
-- Grey and faded while it's up (in the key too): the face is faded and grey; with a known
-- duration and a warning time the game fills the real icon, revealed at the warning time (timed
-- even with no warning glow); without one, the face's own icon.
BD.upGrey, BD.upAlpha = true, 0.4
ns.Refresh()
local faded = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/none:gold:5:none:120:0.4:true")
check(faded, "the look while up isn't in the key")
local fb = faded.button.bound
check(fb.SetDurationBar and fb.SetIcon and fb.SetIcon.parent.alpha == 1 and not fb.SetIcon.desaturated, "the real icon isn't revealed at the warning time")
local facedIcon
for _, f in ipairs(M.frames) do
	if f.parent == faded.button and f.alpha == 0.4 then facedIcon = f end
end
check(facedIcon, "no faded face on the button")
local fort = G("Power Word: Fortitude/icons:32:0:")
check(fort and fort.button.bound.SetIcon.desaturated and fort.button.bound.SetIcon.parent.alpha == 0.4 and not fort.button.bound.SetDurationBar,
	"without a duration the face's icon isn't grey and faded")
BD.upGrey, BD.upAlpha = false, 1
ns.Refresh()
check(G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/none:gold:5:none:120:1:false"), "back to the plain look")
-- Hidden until the warning time: the face invisible, the swipe with the revealed icon.
BD.upAlpha = 0
ns.Refresh()
local lastSeconds = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/none:gold:5:none:120:0:false")
check(lastSeconds and lastSeconds.button.bound.SetDurationBar and lastSeconds.button.bound.SetDurationCooldown.parent == lastSeconds.button.bound.SetIcon.parent,
	"hidden until the warning time wrong")
BD.upAlpha = 1
ns.Refresh()
-- A buff group's font and stacks' place: in the key; the face on the time text.
buffs[1].fontFace, buffs[1].countPos = "friz", "BOTTOMLEFT"
ns.Refresh()
local fonted = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark:friz-OUTLINE:BOTTOMLEFT/")
check(fonted and fonted.button.bound.SetDurationText.font and fonted.button.bound.SetDurationText.font[1]:find("FRIZQT")
	and fonted.button.bound.SetApplicationCount.points[1][1] == "BOTTOMLEFT", "a buff group's font or stacks' place wrong")
buffs[1].fontFace, buffs[1].countPos = "default", "TOPRIGHT"
ns.Refresh()
-- A buff group's shape: in the key, the mask on the button's icon; a background.
buffs[1].shape, buffs[1].background = "Hexagon", 0.25
ns.Refresh()
local hex = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark:Hexagon/")
check(hex and hex.button.shapeParts and hex.button.bound.SetIcon.masks[hex.button.shapeParts.mask] and container.parent.bg.shown,
	"a buff group's shape or background wrong")
buffs[1].shape, buffs[1].background = "square", 0
ns.Refresh()
-- A buff's own look: in its key; Default back to the group's.
ns.Auras.SetLook(buffs[1], "Battle Shout", "border", 3)
ns.Auras.SetLook(buffs[1], "Battle Shout", "timePos", "CENTER")
local ownLook = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/none:gold:5:none:120:1:false:none:>=5:3:nil:nil:CENTER:nil")
check(ownLook, "a buff's own look not in its key")
ns.Auras.SetLook(buffs[1], "Battle Shout", "border", nil)
ns.Auras.SetLook(buffs[1], "Battle Shout", "timePos", nil)
check(buffs[1].looks == nil or buffs[1].looks["Battle Shout"] == nil, "a buff's look didn't go back to the group's")
-- A glow at a number of stacks: an application bar the game drives, in the key.
BD.stackGlow, BD.stackOp, BD.stackCount = "pixel", "=", 3
ns.Refresh()
local stacked = G("Battle Shout/icons:32:0:1:black:0.08:small:on:normal:dark/none:gold:5:none:120:1:false:pixel:=3")
check(stacked and stacked.button.bound.SetApplicationBar, "no stack glow on the button")
BD.stackGlow = "none"
ns.Refresh()
buffs[1].tooltip = "off"
ns.Refresh()
local noTip = G("Battle Shout/icons:32:0:1:black:0.08:small:off:normal:dark/")
check(noTip and noTip.button.mouse == false, "a buff button with tooltips off takes the mouse")
buffs[1].tooltip = "on"
ns.Refresh()
-- A group's look is in its aura groups' keys; timer bars' own options too.
buffs[1].style, buffs[1].barColor, buffs[1].barIcon = "bars", "class", false
ns.Refresh()
check(G("Battle Shout/bars:32:200:1:black:0.08:small:on:normal:dark:blizzard:class:0.5:false:true:true:true:none:false:false:small/"), "timer bar look not in the key")
ns.Auras.SetLook(buffs[1], "Battle Shout", "label", "Shout!")
local labelled = G("Battle Shout/bars:")
check(labelled and not labelled.button.bound.SetSpellName and labelled.button.spark and labelled.button.spark.shown, "a buff timer bar's own name or spark wrong")
ns.Auras.SetLook(buffs[1], "Battle Shout", "label", nil)
-- A stack bar: the game fills it from the stacks (no duration bar), with ticks and a colour zone.
ns.Auras.SetLook(buffs[1], "Battle Shout", "stackMax", 5)
ns.Auras.SetLook(buffs[1], "Battle Shout", "ticks", true)
ns.Auras.SetZone(buffs[1], "Battle Shout", 1, 3, "red")
local stackBar = G("Battle Shout/bars:")
check(stackBar and stackBar.button.bound.SetApplicationBar and not stackBar.button.bound.SetDurationBar
	and buffs[1].looks["Battle Shout"].zones[1].from == 3, "the stack bar wrong")
ns.Auras.SetZone(buffs[1], "Battle Shout", 1, nil)
ns.Auras.SetLook(buffs[1], "Battle Shout", "ticks", nil)
ns.Auras.SetLook(buffs[1], "Battle Shout", "stackMax", nil)
check(buffs[1].looks == nil or buffs[1].looks["Battle Shout"] == nil, "the stack bar's settings stayed")
buffs[1].style, buffs[1].barColor, buffs[1].barIcon = "icons", "blue", true
buffs[1].showWhen = "combat"
ns.Refresh()
check(container.parent.alpha == 0, "a combat-only buff group showed out of combat")
buffs[1].showWhen = "always"
ns.Refresh()
-- Blizzard's places fade through the viewer, in take mode.
ns.db.buffs.blizzard.icons.showWhen = "combat"
ns.Refresh()
check(M.viewers.BuffIconCooldownViewer.alpha == 0, "Blizzard's icons showed out of combat")
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(M.viewers.BuffIconCooldownViewer.alpha == 1, "Blizzard's icons didn't show in combat")
M.combat = false
ns.db.buffs.blizzard.icons.showWhen = "always"
M.Fire("PLAYER_REGEN_ENABLED")
check(M.viewers.BuffIconCooldownViewer.alpha == 1, "Blizzard's icons not back")
M.buffsOnMe = { { name = "Battle Shout", spellId = 25289, icon = 1 }, { name = "Power Word: Fortitude", spellId = 1243, icon = 8 } }

-- Running out: one sound at the warning time, out of combat from the buff's own timer; in combat
-- from your own cast (its learned duration); quiet in combat when another warrior could have
-- recast it; stopped when Blizzard says it's gone; never twice for one cast.
BD.runningOut = "ALARM_CLOCK_WARNING_3"
M.buffsOnMe = { { name = "Battle Shout", spellId = 6673, icon = 1, duration = 120, expires = M.now + 120 } }
M.Fire("UNIT_AURA", "player")
heard = #M.sounds
M.Advance(114)
check(#M.sounds == heard, "running out played early")
M.Advance(1)
check(#M.sounds == heard + 1 and M.sounds[#M.sounds] == SOUNDKIT.ALARM_CLOCK_WARNING_3, "no running-out sound at the warning time")
M.Fire("UNIT_AURA", "player")
M.Advance(1)
check(#M.sounds == heard + 1, "running out played twice for one cast")
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6673)
M.Advance(114)
check(#M.sounds == heard + 1, "running out (from a cast) played early")
M.Advance(1)
check(#M.sounds == heard + 2, "no running-out sound timed from your cast in combat")
M.party = { "WARRIOR" }
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 6673)
M.Advance(115)
check(#M.sounds == heard + 2, "running out played with another warrior along, who could have recast it")
check(Logged("quiet: Battle Shout running out"), "the quiet running-out not logged")
M.party = { "PRIEST" }
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 6673)
M.Advance(115)
check(#M.sounds == heard + 3, "a priest along silenced Battle Shout's running out")
M.party = {}
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 6673)
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
M.Advance(115)
check(#M.sounds == heard + 3, "running out after Blizzard said it was gone")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
BD.warn = "auto"
check(ns.Alerts.Warn("Power Word: Fortitude") == 120 and ns.Alerts.Warn("Unheard Of") == 5, "auto warning time wrong")
LecdmDB.auraDur["Unheard Of"] = 600
check(ns.Alerts.Warn("Unheard Of") == 60, "a tenth of the duration for a buff not on Lecdm's list wrong")
LecdmDB.auraDur["Unheard Of"] = nil
BD.warn, BD.runningOut = 5, "none"
-- Going into combat without a keep-up buff (at the last look): a sound, and in chat.
BD.combatMissing, BD.combatChat = "RAID_WARNING", true
ns.Auras.SetMode(buffs[1], "Power Word: Fortitude", "keep")
M.buffsOnMe = { { name = "Battle Shout", spellId = 6673, icon = 1, duration = 120 } }
M.Fire("UNIT_AURA", "player")
heard = #M.sounds
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sounds == heard + 1 and M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no sound going into combat without a keep-up buff")
check(M.Printed("into combat without Power Word: Fortitude"), "the missing keep-up buff not said in chat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
ns.Auras.SetMode(buffs[1], "Power Word: Fortitude", "up")
BD.combatMissing, BD.combatChat = "none", false
M.buffsOnMe = { { name = "Battle Shout", spellId = 25289, icon = 1 }, { name = "Power Word: Fortitude", spellId = 1243, icon = 8 } }
M.Fire("UNIT_AURA", "player")

-- Keep up: a fixed place (an aura slot, first) and the missing look (a presence container the
-- game sizes, and the red copy clipped to it); the others flow a line below. Only while
-- missing: the presence alone. While it's up again: neither.
local anchorFrame = container.parent
local function Keep()
	for _, c in ipairs(M.containers) do
		if c.parent == anchorFrame and next(c.slots) then return c end
	end
end
local function PresenceOf()
	for _, c in ipairs(M.containers) do
		if c.parent == anchorFrame and c.groups.buff and c.groups.buff.ids[6673] then return c end
	end
end
ns.Auras.SetMode(buffs[1], "Battle Shout", "keep")
local keepC = Keep()
local slotKey, slot
for k, s2 in pairs(keepC and keepC.slots or {}) do
	if k:find("^Battle Shout/") and s2.enabled then slotKey, slot = k, s2 end
end
check(slot and slot.ids[6673], "no fixed place for a keep-up buff")
check(slot.button.points[1][1] == "TOPLEFT" and slot.button.points[1][5] == 0, "fixed place not on the first line")
local presence = PresenceOf()
check(presence and presence.groups.buff.enabled and presence.groups.buff.layout.elementWidth == 32 + 2 * 11 + 1, "no presence for the missing look")
check(not G("Battle Shout/icons:32:0:"), "a keep-up buff also flows")
-- The copy while it's missing: dimmed red by default; full colour or grey, at its opacity.
local function CopyOf()
	local found
	for _, f in ipairs(M.frames) do
		if f.border and f.bar and f.name and f.icon and f.icon.texture == ns.Auras.Icon("Battle Shout") then found = f end
	end
	return found
end
local copy = CopyOf()
check(copy and copy.alpha == 0.85 and copy.icon.desaturated, "the missing copy isn't dimmed red")
BD.missingLook = "normal"
ns.Refresh()
check(copy.alpha == 1 and not copy.icon.desaturated and copy.icon.vertex == 1, "the missing copy isn't in full colour")
ns.Alerts.Set("buffs", "Battle Shout", "missingAlpha", 0.5)
check(copy.alpha == 0.5, "the missing copy's own opacity wasn't used")
ns.Alerts.Set("buffs", "Battle Shout", "missingLook", "grey")
check(copy.icon.desaturated and copy.alpha == 0.5, "the grey missing copy wrong")
ns.Alerts.Set("buffs", "Battle Shout", "missingLook", nil)
ns.Alerts.Set("buffs", "Battle Shout", "missingAlpha", nil)
BD.missingLook = "red"
ns.Refresh()
check(container.points[1][5] == -36, "the flowing buffs aren't a line below: " .. tostring(container.points[1][5]))
ns.Auras.SetMode(buffs[1], "Battle Shout", "missing")
check(not keepC.slots[slotKey].enabled and presence.groups.buff.enabled, "only-while-missing wrong")
ns.Auras.SetMode(buffs[1], "Battle Shout", "up")
check(not presence.groups.buff.enabled and G("Battle Shout/icons:32:0:") and container.points[1][5] == 0, "back to while-up wrong")

-- Weapon enchants: always a fixed place, the game's button in a container of its own; keep up
-- adds the missing look; while up only, the place stays empty without one; the alerts hear them
-- come and go out of combat.
local MH = AuraContainerItemEnchantmentSlot.MainHand
local function EnchantOf(display)
	for _, c in ipairs(M.containers) do
		local en = c.parent == anchorFrame and c.enchants[MH]
		if en and (en.button.bound.SetIcon ~= nil) == display and en.enabled then return c end
	end
end
ns.Auras.SetInGroup(buffs[1], "Main hand enchant", true)
local enC = EnchantOf(true)
check(enC and enC.points[1][5] == 0 and enC.enchants[MH].hidePermanent, "no fixed place for the main hand enchant")
check(container.points[1][5] == -36, "the flowing buffs aren't after the enchant's place")
check(not EnchantOf(false), "a while-up enchant has the missing look")
ns.Auras.SetMode(buffs[1], "Main hand enchant", "keep")
local enP = EnchantOf(false)
check(enP and enP.enchantLayout.elementWidth == 32 + 2 * 11 + 1, "a keep-up enchant has no missing look")
check(ns.Auras.Icon("Main hand enchant") == 135225, "the enchant's icon isn't the weapon's")
BD.applied, BD.removed = "MAP_PING", "RAID_WARNING"
M.now = M.now + 10
M.enchant = { mainMs = 1800000 }
heard = #M.sounds
M.Fire("WEAPON_ENCHANT_CHANGED")
check(#M.sounds == heard + 1 and M.sounds[#M.sounds] == SOUNDKIT.MAP_PING, "no sound when a weapon enchant came")
M.enchant = nil
M.Fire("WEAPON_ENCHANT_CHANGED")
check(M.sounds[#M.sounds] == SOUNDKIT.RAID_WARNING, "no sound when a weapon enchant went")
BD.applied, BD.removed = "none", "none"
ns.Auras.SetInGroup(buffs[1], "Main hand enchant", false)
check(not EnchantOf(true) and not EnchantOf(false), "the enchant's place stayed after taking it out")

-- /lecdm check, in combat with secret cooldown times: SECRET shown, nothing compared.
M.combat, M.secretCooldowns = true, true
M.Slash("check")
check(Logged("Charge: on cooldown true, GCD false, start SECRET"), "check line wrong: " .. tostring(Logged("Charge:")))
check(Logged("usable SECRET %(no power nil%), in range SECRET"), "secret usable/range not shown: " .. tostring(Logged("Charge:")))
check(Logged("trinket slot 13 Satchel of Potions: slot cooldown start SECRET, duration SECRET, enabled 1"), "trinket line wrong: " .. tostring(Logged("trinket slot 13")))
check(Logged("trinket slot 14: empty"), "empty trinket slot not reported")
check(M.Printed("check: 2 spells and the trinket slots logged"), "check summary missing")
M.combat, M.secretCooldowns = false, false

-- /lecdm buff: the groups' buffs; a name (any part of it) and how it shows; out.
M.Slash("buff")
check(M.Printed("Buffs: .*Battle Shout %(while it's up%)"), "/lecdm buff didn't list the buffs")
M.Slash("buff fort keep")
check(ns.Auras.Mode(ns.db.buffs.list[1], "Power Word: Fortitude") == "keep" and M.Printed("Power Word: Fortitude: keep up, in Buffs"), "/lecdm buff fort keep didn't")
M.Slash("buff arcane int up")
check(ns.Auras.GroupOf("Arcane Intellect") == ns.db.buffs.list[1], "/lecdm buff didn't add a buff from Lecdm's list")
M.Slash("buff arcane intellect out")
M.Slash("buff fort up")
check(not ns.Auras.GroupOf("Arcane Intellect") and ns.Auras.Mode(ns.db.buffs.list[1], "Power Word: Fortitude") == "up", "/lecdm buff out or up didn't")
M.Slash("buff nothing like it")
check(M.Printed("no buff called 'nothing like it'"), "an unknown buff not said")

-- The sound log: every sound any addon plays, with the addon (from the call stack) and, for
-- Lecdm's own, why; off, nothing more.
function debugstack() return "Interface/AddOns/OtherAddon/Main.lua:10: in function <x>\n" end
M.Slash("soundlog on")
PlaySound(SOUNDKIT.READY_CHECK)
check(Logged("sound: READY_CHECK %(8960%), from OtherAddon$"), "sound log line wrong: " .. tostring(Logged("sound: READY")))
function debugstack() return "Interface/AddOns/Lecdm/Alerts.lua:80: in function <x>\n" end
ns.Alerts.Play("MAP_PING", "Battle Shout", "ready: Battle Shout")
check(Logged("sound: MAP_PING %(3175%), from Lecdm %(ready: Battle Shout%)"), "Lecdm's reason not in the sound log")
M.Slash("soundlog off")
before = #LecdmDB.log
PlaySound(SOUNDKIT.READY_CHECK)
check(#LecdmDB.log == before, "the sound log still logging when off")
debugstack = nil

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
local sampled
for _, f in ipairs(M.frames) do
	if f.sample and f.sample.glow.glows and f.sample.glow.glows["modern:gold:22"] then sampled = true end
end
check(sampled, "no glow sample on the Alerts tab (the proc glow's Modern, gold)")
-- The Button glows tab: a row per rule, the new-glow picker.
ns.ButtonGlows.New("Charge")
M.Slash("buttons")
local glowPanel = ns.Window.CurrentPanel()
check(glowPanel.parts.new and glowPanel.parts.rows[1] and glowPanel.parts.rows[1].label.text:find("Charge"), "the Button glows tab wrong")
ns.ButtonGlows.Delete(1)
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
-- The saved styles row: save the bar's look by name from its menu; it lists it.
local styleRow
for _, row in ipairs(panel.parts.top) do
	if row.label and row.label.text == "Saved styles" then styleRow = row end
end
local styleMenu = M.Menu()
styleRow.dropdown.generator(nil, styleMenu)
styleMenu.children[1].onClick()
M.Accept("Mine")
check(ns.db.styles.bars.Mine and ns.db.styles.bars.Mine.size == first.size, "saving a style from the tab didn't")
styleMenu = M.Menu()
styleRow.dropdown.generator(nil, styleMenu)
check(styleMenu.children[2].text == "Mine" and styleMenu.children[2].children[1].text == "Give it to this one", "the saved style isn't listed")
ns.Bars.DeleteStyle("bars", "Mine")
-- The conditions rows: ticking one in "Hide it when" sets it, unticking clears it.
local hideRow
for _, row in ipairs(panel.parts.top) do
	if row.label and row.label.text == "Hide it when" then hideRow = row end
end
local condMenu = M.Menu()
hideRow.dropdown.generator(nil, condMenu)
local mountedBox
for _, c in ipairs(condMenu.children) do
	if c.text == "Mounted" then mountedBox = c end
end
mountedBox.setSelected()
check(first.hideIf and first.hideIf.mounted and hideRow.dropdown.text == "1 thing", "ticking a condition didn't set it")
mountedBox.setSelected()
check(first.hideIf == nil and hideRow.dropdown.text == "Nothing", "unticking a condition didn't clear it")
-- An empty space on the bar shows in the tab's rows and the preview.
ns.Bars.AddSpace(first)
ns.Window.Refresh()
local spaceRow = panel.parts.spellRows[#first.spells]
check(spaceRow and spaceRow.key == first.spells[#first.spells] and spaceRow.label.text:find("Empty space"), "an empty space's row wrong")
ns.Bars.SetOnBar(first, first.spells[#first.spells], false)
-- The preview: an icon per entry; drag one onto another moves it there; right-click opens its ⚙;
-- middle-click takes it off.
local preview = panel.parts.preview
check(preview and #preview.icons >= #first.spells and preview.icons[1].shown, "no preview icons")
local firstKey, secondKey = first.spells[1], first.spells[2]
preview.icons[1].scripts.OnDragStart(preview.icons[1])
M.mouseOver = panel.parts.preview.icons[2]
preview.icons[1].scripts.OnDragStop(preview.icons[1])
M.mouseOver = nil
check(first.spells[2] == firstKey and first.spells[1] == secondKey, "dragging in the preview didn't move it")
ns.Bars.MoveTo(first, 2, 1)
check(first.spells[1] == firstKey, "moving back didn't")
panel.parts.preview.icons[1].scripts.OnClick(panel.parts.preview.icons[1], "RightButton")
check(M.contextMenu.children[1].text == "Sound when it's ready", "right-click didn't open its ⚙ menu")
local count = #first.spells
local lastKey = first.spells[count]
panel.parts.preview.icons[count].scripts.OnClick(panel.parts.preview.icons[count], "MiddleButton")
check(#first.spells == count - 1 and not ns.Bars.BarOf(lastKey), "middle-click didn't take it off")
ns.Bars.SetOnBar(first, lastKey, true)
-- A spell's ⚙: its alerts, then when it shows: any stance, or only in or not in each of the class's.
panel.parts.spellRows[1].gear.scripts.OnClick(panel.parts.spellRows[1].gear)
local stanceMenu
for _, c in ipairs(M.contextMenu.children) do
	if c.text == "In a stance or form" then stanceMenu = c end
end
check(stanceMenu and #stanceMenu.children == 9 and stanceMenu.children[1].isSelected(), "the stance menu wrong")
stanceMenu.children[2].setSelected()
check(first.forms[first.spells[1]] == "in:2457", "picking a stance didn't set it")
stanceMenu.children[1].setSelected()
check(first.forms[first.spells[1]] == nil, "Any didn't clear the stance")
-- ... and with a talent: by tree, each talent with or without; the condition hides and shows.
panel.parts.spellRows[1].gear.scripts.OnClick(panel.parts.spellRows[1].gear)
local talentMenu
for _, c in ipairs(M.contextMenu.children) do
	if c.text == "With a talent" then talentMenu = c end
end
check(talentMenu and talentMenu.children[2].text == "Arms" and talentMenu.children[3].text == "Fury", "the talent menu's trees wrong")
local improved = talentMenu.children[2].children[1]
check(improved.text == "Improved Overpower" and talentMenu.children[2].children[2].text:find("^Tactical Mastery .*taken"), "the talent menu's talents wrong")
local spellKey = first.spells[1]
improved.children[1].setSelected()
check(first.talents[spellKey] == "with:502", "picking a talent didn't set it")
local firstButton
for _, b in ipairs(BarFrame(first.name).buttons) do
	if b.key == spellKey then firstButton = b end
end
check(firstButton and not firstButton.shown, "a spell shown without the talent it needs")
M.talentsTaken[502] = true
M.Fire("TRAIT_CONFIG_UPDATED")
check(firstButton.shown, "a spell not shown with the talent it needs")
M.talentsTaken[502] = nil
ns.Bars.SetTalent(first, spellKey, nil)
M.Fire("TRAIT_CONFIG_UPDATED")
-- ... its own icon, from a popup: an item's; empty: its own again.
panel.parts.spellRows[1].gear.scripts.OnClick(panel.parts.spellRows[1].gear)
local iconItem
for _, c in ipairs(M.contextMenu.children) do
	if c.text:find("^Icon%.%.%.") then iconItem = c end
end
iconItem.onClick()
check(M.popup and M.popup.which == "LECDM_ICON", "the icon popup didn't open")
M.Accept("item:5512")
check(first.looks[spellKey].icon == 7 and firstButton.icon.texture == 7, "the item's icon wasn't used")
iconItem.onClick()
M.Accept("")
check(first.looks == nil or first.looks[spellKey] == nil, "empty didn't give it its own icon back")
local root = M.Menu()
panel.parts.top[#panel.parts.top].dropdown.generator(nil, root)
check(root.children[1].text == "Blizzard's Essential" and root.children[2].text == "Blizzard's Utility", "checklist sections wrong")
local book = root.children[3]
check(book and book.text == "Spellbook: Protection" and #book.children == 1, "spellbook section wrong")
check(root.children[4].text:find("^Equipped") and #root.children[4].children == 2, "equipped section wrong")
check(root.children[5].text:find("^Best in your bags") and #root.children[5].children == #ns.Bars.BEST, "best-in-bags section wrong")
check(root.children[6].text:find("^In your bags") and root.children[6].children[1].text:find("Healthstone"), "bags section wrong")
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
local deleteRow
for _, row in ipairs(panel.parts.top) do
	if row.button and row.button.text == "Delete this icon bar" then deleteRow = row end
end
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
check(buffMenu.children[2].text == "Yours, from Blizzard's list" and #buffMenu.children[2].children == 1, "Blizzard's buffs section wrong")
local onYou = buffMenu.children[3]
check(onYou.text:find("^On you now") and #onYou.children == 2, "on-you section wrong")
-- Lecdm's list, for a human warrior: your class's buffs and procs, other classes' buffs they can
-- put on you, your race's; a buff's other names count as it (Prayer of Fortitude).
local listMenu = buffMenu.children[1]
local function MenuNamed(menu, text)
	for _, c in ipairs(menu.children) do
		if c.text:find(text, 1, true) then return c end
	end
end
check(listMenu.text:find("^Lecdm's list") and MenuNamed(listMenu, "Your class's buffs") and MenuNamed(MenuNamed(listMenu, "Your class's buffs"), "Battle Shout"), "Lecdm's list: no Battle Shout for a warrior")
check(MenuNamed(MenuNamed(listMenu, "Your procs and cooldowns"), "Flurry"), "Lecdm's list: no Flurry for a warrior")
local others = MenuNamed(listMenu, "From other classes")
check(MenuNamed(others, "Arcane Intellect") and not MenuNamed(others, "Inner Fire"), "Lecdm's list: other classes' buffs wrong")
check(MenuNamed(MenuNamed(listMenu, "Your race's"), "Perception") and not MenuNamed(MenuNamed(listMenu, "Your race's"), "Berserking"), "Lecdm's list: racials wrong")
check(MenuNamed(listMenu, "World buffs") and MenuNamed(listMenu, "Consumables") and MenuNamed(MenuNamed(listMenu, "Weapon enchants"), "Main hand enchant"), "Lecdm's list: world buffs, consumables or weapon enchants missing")
check(ns.Auras.IDs("Power Word: Fortitude")[21562] and ns.Auras.IDs("Battle Shout")[11551], "every rank and the group version aren't the buff's IDs")
MenuNamed(others, "Arcane Intellect").setSelected()
check(ns.Auras.GroupOf("Arcane Intellect") == ns.db.buffs.list[1] and G("Arcane Intellect/") and G("Arcane Intellect/").ids[23028], "ticking Lecdm's list's Arcane Intellect didn't add it with Arcane Brilliance")
ns.Auras.SetInGroup(ns.db.buffs.list[1], "Arcane Intellect", false)
ns.db.alerts.defaults.buffs.warn = "auto"
check(ns.Alerts.Warn("Battle Shout") == 15 and ns.Alerts.Warn("Unheard Of") == 5, "each buff's own warning time wrong")
ns.db.alerts.defaults.buffs.warn = 5
M.buffsOnMe[3] = { name = "Rallying Cry of the Dragonslayer", spellId = 22888, icon = 9 }
buffMenu = M.Menu()
buffPanel.parts.checklist.dropdown.generator(nil, buffMenu)
buffMenu.children[3].children[3].setSelected()
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
