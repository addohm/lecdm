# Testing

What to check in game, and what's been confirmed. Results go under Confirmed or Problems, with
the build and date.

## To check (test build 1, 0.0.1-dev)

Install with `tools\install_forever.cmd`, fully restart the game (first install), then
`/lecdm help` should show the build you installed.

1. **Status.** `/lecdm`. Note what it says:
   - "Blizzard's Cooldown Manager: available" or not, and the reason.
   - The spec (Forever may answer nil).
   - Blizzard's list: how many entries per section.
   - The viewers: shown or hidden, and how many icons each. Then the number of Blizzard icons
     being listened to.
2. **Blizzard's list.** `/lecdm list`. Does it match what `/cdm` shows? Any spells missing?
3. **The listener, out of combat.** Track a buff in Blizzard's Cooldown Manager (Battle Shout,
   say, in Tracked Buffs). Cast it and let it run out. Chat should say "applied: Battle Shout
   (Buffs)" and "removed: ...", with a raid warning on removal.
4. **The listener, in combat, in the open world.** Same, but let it drop mid-fight. Do the
   lines (marked [combat]) and the sound come at the moment the icon changes?
5. **The listener, in combat, inside a dungeon.** The one that matters most. Lines marked
   [combat] [instance].
6. **Your effects on the target.** Track a DoT or HoT of yours in the Cooldown Manager (if it
   lists one). Apply it, let it fall off. Is it heard?
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

Then `/lecdm log`, Ctrl+C, and paste it here. The log keeps the last 500 lines and is saved
at /reload or logout (`WTF\Account\<account>\SavedVariables\Lecdm.lua`).

## Confirmed

Nothing yet.

## Problems

None yet.
