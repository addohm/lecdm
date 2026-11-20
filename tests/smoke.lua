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

-- Login: settings made, Blizzard's list read, every icon there already is gets listened to.
local shout = M.AddItem("BuffIconCooldownViewer", 14)
M.Fire("ADDON_LOADED", "Lecdm")
check(LecdmDB and LecdmDB.sound == true and LecdmDB.icons == true, "defaults not set")
M.Fire("PLAYER_LOGIN")
check(M.Printed("loaded"), "no login line")
check(ns.Catalogue.byID[14] and ns.Catalogue.byID[14].name == "Battle Shout", "Blizzard's list not read")
check(ns.Catalogue.byID[15].name == "equipment slot 13", "an equipment entry has no name")

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
check(LecdmDB.sound == false, "sound didn't turn off")
local sounds = #M.sounds
shout:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnAuraRemoved)
check(#M.sounds == sounds, "sound played while off")
M.Slash("sound")

-- Proc events are logged with the spell's name.
M.Fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 6572)
check(Logged("proc glow on: Revenge %(6572%)"), "proc not logged")

-- Test icons: learned Essential/Utility spells only, grey on cooldown, swipe from the duration.
local icons = {}
for _, f in ipairs(M.frames) do
	if f.spellID and f.icon then icons[f.spellID] = f end
end
check(icons[100] and icons[6572], "test icons missing")
check(not icons[12292], "an unlearned spell got a test icon")
check(icons[100].icon.desaturated == true, "spell on cooldown not grey")
check(icons[6572].icon.vertex == 0.4, "unusable spell not dark")
check(icons[100].cd.duration and icons[100].cd.duration.spell == 100, "swipe not given the duration")
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
check(Logged("usable SECRET, in range SECRET"), "secret usable/range not shown")
M.combat, M.secretCooldowns = false, false

-- The other commands run.
M.Slash("")
check(M.Printed("Cooldown Manager: available"), "status missing availability")
check(M.Printed("listening to %d+ Blizzard icons"), "status missing listener count")
M.Slash("help")
M.Slash("list")
check(Logged("TrackedBuff %(2%): Battle Shout, equipment slot 13"), "list wrong")
check(Logged("Utility %(1%): %*Death Wish"), "unlearned entry not marked")
M.Slash("move")
M.Slash("move")
M.Slash("icons")
check(LecdmDB.icons == false, "icons didn't turn off")
M.Slash("icons")
M.Slash("nonsense")
check(M.Printed("unknown command"), "unknown command not reported")

-- blizz hide/show: alpha 0 and back; Blizzard putting it back is logged.
local essential = M.viewers.EssentialCooldownViewer
essential:SetAlpha(0.8)
M.Slash("blizz hide")
check(essential.alpha == 0, "viewer not invisible")
essential:SetAlpha(1)
check(Logged("Blizzard set the Essential viewer's alpha to 1"), "Blizzard's alpha change not logged")
M.Slash("blizz show")
check(essential.alpha == 0.8, "viewer alpha not restored: " .. tostring(essential.alpha))

-- The log window and clear.
M.Slash("log")
check(LecdmLog and LecdmLog.box.text:find("Lecdm v0.0.1%-dev"), "log window empty")
check(not LecdmLog.box.text:find("build"), "the build shows in the log window")
M.Slash("log clear")
check(#LecdmDB.log == 0, "log not cleared")
