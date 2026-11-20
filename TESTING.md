# Testing

What to check in game, and what's been confirmed. Results go under Confirmed or Problems, with
the build and date.

## To check (test build 1, 0.0.1-dev)

Install with `tools\install_forever.cmd`, fully restart the game (first install), then
`/lecdm help` should show the build you installed.

0. **The window.** `/lecdm` opens it (so do the minimap button, the addon menu by the minimap
   and Options > AddOns > Lecdm). Every tab opens; the window moves, resizes and closes with
   Escape; the title shows the version without the build. Profiles tab: your profile is named
   "First Last"; make a new one, switch back, delete it.
1. **Status.** `/lecdm status`. Note what it says:
   - "Blizzard's Cooldown Manager: available" or not, and the reason.
   - The spec (Forever may answer nil).
   - Blizzard's list: how many entries per section.
   - The viewers: shown or hidden, and how many icons each. Then the number of Blizzard icons
     being listened to.
2. **Blizzard's list.** `/lecdm list`. Does it match what `/cdm` shows? Any spells missing?
3. **The listener, out of combat.** Track a buff in Blizzard's Cooldown Manager (`/cdm`, the
   Buffs tab, which holds every aura you cast: buffs on you and your debuffs on the target. Put
   Battle Shout, say, in Tracked Buffs; anything left in "Not in bar" has no icon to hear). Cast it and let it run out. Chat should say "applied: Battle Shout
   (Buffs)" and "removed: ...", with a raid warning on removal.
4. **The listener, in combat, in the open world.** Same, but let it drop mid-fight. Do the
   lines (marked [combat]) and the sound come at the moment the icon changes?
5. **The listener, in combat, inside a dungeon.** The one that matters most. Lines marked
   [combat] [instance].
6. **Your effects on the target.** Track a debuff, DoT or HoT of yours in the Buffs tab (a
   warrior: Thunder Clap, Sunder Armor, Hamstring, if Blizzard lists them). Apply it, keep the
   target, let it fall off. Is it heard?
7. **Invisible viewers.** `/lecdm blizz hide`. The viewers vanish. Repeat 3 and 4: still heard?
   Does the log say "Blizzard set the ... viewer's alpha" (Blizzard putting them back)? Then
   `/lecdm blizz show`. It isn't kept after /reload.
8. **What's readable in combat.** Make a macro `/lecdm check` and press it out of combat, then
   in combat (open world, then a dungeon). Each spell line shows on cooldown, GCD, start,
   duration object, usable, in range, charges, proc: which say SECRET?
9. **Test icons.** The row under your character (`/lecdm move` to drag it): one icon per
   learned Essential/Utility spell. In combat, inside a dungeon too:
   - Does the swipe and countdown run when a spell goes on cooldown?
   - Does the icon go grey on a real cooldown, but not for the GCD?
   - Does it go dark when you can't cast it (no rage or mana)?
   - Any "refused the duration object" line?
10. **Procs.** Any "proc glow on: ..." lines when something procs (Overpower, Revenge,
    Clearcasting)? Is the spell named or SECRET?
11. **Errors.** Any Lua errors (`/console scriptErrors 1`) or "blocked" messages?

Added 2026-11-20, for a second dungeon run (`/reload` after the install script is enough):

12. **Expired, or the target died?** Each "removed" line now ends with "target exists ...,
    dead ...", and the next line ("a frame later: ...") looks again one frame later. Let a
    debuff run out on a live mob, and kill a debuffed mob: do the two read differently?
13. **Trinkets.** `/lecdm check` now also logs trinket slots 13 and 14 (and every spell, and
    "no power"). Press it in combat, ideally with an on-use trinket on cooldown: SECRET or not?
14. **Blizzard's icons in a Lecdm row.** `/lecdm host on` (or the Test build tab) places
    Blizzard's own buff icons and bars (Battle Shout, Sunder Armor, Thunder Clap ...) in a faint
    blue row above the test icons. Fight: do they stay in that row the whole time, in combat,
    as buffs come and go and targets change? Any "blocked" or "refused" line? `/lecdm status`
    shows how often Blizzard laid them out again. `/lecdm host off`, then `/reload`, puts them
    back. (It needs the buff viewers visible; it makes them visible if `/lecdm blizz hide` was on.)
15. **Swings.** The log notes the first three swings of each fight (PLAYER_SWING): is the
    duration a number or SECRET?

Then `/lecdm log`, Ctrl+C, and paste it here. The log keeps the last 500 lines and is saved
at /reload or logout (`WTF\Account\<account>\SavedVariables\Lecdm.lua`).

## Confirmed

From the owner's warrior, test build 1 (e865554), 2026-11-20: open world, then a dungeon.

- **The listener works in combat inside a dungeon** (steps 3-6). Lines marked `[combat]
  [instance]` for applied and removed of Bloodrage, Battle Shout, Sunder Armor, Thunder Clap,
  Demoralizing Shout and Eureka!, from the Essential, Utility, Buffs and Bars viewers; "on
  cooldown" for Charge, Bloodrage and Eureka!. In the open world the raid warning for Thunder
  Clap came at virtually the same moment its icon went. A spell in Essential or Utility also
  announces its own aura (Bloodrage).
- **Target debuffs are announced too, also when the target dies:** Sunder Armor, Thunder Clap
  and Demoralizing Shout were all "removed" in the same second when the mob died.
- **What an addon can read in combat, inside a dungeon** (step 8): "cooldowns secret" and
  "auras secret" are true in any combat (open world too). Still readable: on cooldown
  (isActive), GCD (isOnGCD), usable, in range; a duration object is there for every spell. The
  start time is SECRET. In combat an aura's ID is secret and timing it ourselves is refused;
  out of combat it's readable and works.
- **Blizzard's list** (step 2): Essential 17, Utility 20, TrackedBuff 38 (buffs on you and
  your debuffs on the target, together), TrackedBar 0, three spec-agnostic entries with no
  spell (cooldowns 200345-200347), and equipment slots. These are Blizzard's default sections,
  not where the player put things: Sunder Armor is listed under TrackedBuff while the player's
  layout shows it in the Bars viewer.
- **No proc glow events** for a warrior (step 10): none logged while Overpower and Revenge
  became usable. Usable covers them.
- **No listener errors** in the log.

- **Lecdm's own icons work in combat, inside a dungeon too** (step 9): the swipe and countdown
  from the duration object ran for spells on their own cooldown, the icons went grey while
  cooling down and back to colour when ready, and the GCD showed as a short sweep.
- **The listener keeps hearing with Blizzard's viewers invisible** (step 7): after `/lecdm blizz
  hide` they stayed invisible through every fight, the dungeon included, Blizzard never put
  their alpha back, and every change above was heard while they were.
- **No Lua errors** (step 11).

Test build 1 is done: everything the plan relies on works in game.

Second dungeon run (870f69d, 2026-11-20):

- **Swings are readable in combat, in an instance** (step 15): PLAYER_SWING gave "duration
  2.261, type 0".
- **At the moment of a removal, a dying target isn't dead yet** (step 12): Sunder Armor and
  Thunder Clap went together 5 s after Thunder Clap was applied (a kill, by the look of it),
  with "target exists true, dead false". The frame-later look (f115a4e) is to check next.
- Not in that log yet: the trinket check (13) and the host test (14).

## Problems

None yet.
