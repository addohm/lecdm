# Testing

What to check in game, and what's been confirmed. Results go under Confirmed or Problems, with
the build and date.

## To check (0.9.1-dev, 2026-11-21)

1. After installing: Blizzard's buff icons and timer bars are gone (the Buffs tab's dropdown,
   "Blizzard's icons": What happens to them: Hide them), and stay gone after `/reload`. Lecdm's
   own buff groups and icon bars are all that shows. In-combat drop sounds for buffs tracked in
   /cdm still play.
2. The owner's look (2026-11-22), with Battle Shout on **Keep up** in a buff group (Buffs tab),
   and on the Alerts tab under "Buff groups: how a buff looks": Grey while it's up: Yes;
   Opacity while it's up: 40%; Look while it's missing: Full colour; a glow while it's missing.
   - While it's up: the icon is grey and faded (border and swipe too), the time text faded;
     glows at full strength.
   - Under the warning time (5 s by default; the buff's duration must have been seen out of
     combat once): the icon comes back to full colour, in combat too, and the time turns red.
   - Let it drop: the place shows the icon in full colour, at full strength, glowing; cast it:
     the grey faded icon is back, the copy and glow gone.
   - Each buff's ⚙ (Buffs tab) has the same choices; as timer bars: grey bar and faded while
     up, the copy a full-colour bar while missing.
3. Running out (Alerts tab: "Sound as it runs out", Warning time 15 s), Battle Shout in a buff
   group: out of combat it plays once at 15 s left. Recast it in combat (after seeing it once
   out of combat): it plays 15 s before the end, once. Grouped with another warrior: quiet in
   combat (the log says why). `/lecdm log`: "sound: running out: Battle Shout (timed from your
   cast)" for the in-combat one. If nothing is timed from casts in combat, the game hides your
   own casts there: say so.
4. Lecdm's list (Buffs tab, "Add or remove buffs", the first submenu): your class's buffs and
   procs are there, other classes' buffs they can put on you, your race's, world buffs and
   consumables; a world buff's tooltip says where it comes from. Tick Power Word: Fortitude:
   a priest's Prayer of Fortitude on you shows in its place, in combat too. Missing from
   Forever's data, so left out: Blessing of Salvation and Sanctuary, Greater Blessing of Light,
   Elemental Mastery; say if any of them do exist in game.
5. Weapon enchants (Lecdm's list, "Weapon enchants", Main hand enchant, on Keep up): with no
   oil or stone, the weapon's icon as the missing copy; apply one: the game's button with the
   time left, in combat too, and the copy gone. On "While it's up", the place stays empty
   without one. With "Sound when it's applied" set, applying one out of combat plays it.
6. Going into combat without a keep-up buff ("Sound going into combat without it", "Say in
   chat which ones are missing then"): pull without Battle Shout: the sound, and "into combat
   without Battle Shout" in chat.

## To check (0.9.0-alpha, 2026-11-21)

Install the release zip or run `tools\install_forever.cmd`, then fully restart the game.
`/lecdm help` shows the version (and the build, with the install script). The sections below,
newest first, are what the alpha needs tried; the ones that matter most:

1. Alerts in combat, in a dungeon: ready sounds, "Say it", glows (ready, proc, while up, at the
   warning time); quiet when a mob dies.
2. Keep-up buffs: the red copy shows while the buff is down and is completely gone while it's
   up, in combat too.
3. Blizzard's icons and timer bars taken in: they stay in Lecdm's places and follow each
   target.
4. A trinket or potion used in combat: its swipe runs (item cooldowns not secret).
5. The new icon (AddOns list, minimap button, addon compartment, the window's title).
6. Any Lua error or "blocked" line (Diagnostics, the log).

## To check (keep-up buffs, 2026-11-21)

1. **Buffs tab:** Battle Shout's row: "Keep up". It gets a fixed place at the start; let it
   drop: a dimmed red copy with a red pixel glow takes its place; cast it: the copy is gone
   (completely, no red around it), in combat too, in a dungeon too.
2. "Only while missing": the place is empty while it's up, the red copy while it's down.
3. As timer bars: the red copy is a dim red bar with the name.

## To check (looks and visibility, 2026-11-21)

New files: install, then fully restart the game.

1. **Icon bars tab, "Its look":** border (thick, class colour), icon zoom, countdown text
   (off, large), keybind text (on: the keys from your bars, EllesmereUI's too), grey / red /
   dark each off and on.
2. **"When it shows":** "Only in combat": the bar appears when you pull, goes when combat ends.
   "Out of combat: 30%": faded between pulls.
3. **Buffs tab:** a group as timer bars: texture, colour (class colour), background, icon /
   name / time off and on; border and zoom on icon groups. Same "When it shows" options, and
   for Blizzard's icons and timer bars.

## To check (alerts, 2026-11-21)

New files: install, then fully restart the game.

1. **Icon bars.** Alerts tab: "Sound when it's ready: Ready check". Use Charge: the sound comes
   when it's ready again (not after a GCD). "Glow while it's ready": pick Pixel glow: ready,
   usable spells glow; using one stops it. A proc (Overpower, Revenge, if the game highlights
   them on Forever) glows Modern by default.
2. **A spell's own:** its ⚙ on the Icon bars tab: "Sound when it's ready: Say it": it speaks
   the name. Default puts it back; the row says "(own alerts)" while it has its own.
3. **Buffs.** "Sound when it drops: Raid warning": Battle Shout dropping out of combat plays it;
   in combat only if Battle Shout is also tracked in /cdm (Buffs tab). "Time turns red under
   5 s"; "Warning glow: Pixel": at 5 s left the icon glows (after Lecdm has seen Battle Shout on
   you once out of combat). "Glow while it's up" glows the whole time.
4. **Blizzard's icons and timer bars.** "Sound when it drops": Sunder Armor expiring plays it;
   killing the mob doesn't, unless "Also when your target dies".
5. In combat, in a dungeon: any of it missing, late, or doubled? Lua errors?

## To check (buffs, part 3, 2026-11-21)

New files: install, then fully restart the game.

1. **Taken in.** Without touching anything, Blizzard's buff icons and timer bars (Sunder Armor,
   Thunder Clap ...) now sit in Lecdm's places: icons left of the middle, timer bars right of
   it. `/lecdm move` shows them as "Blizzard's icons" and "Blizzard's timer bars": drag them.
2. **In combat, in a dungeon:** do they stay there, follow each target, and close up as they
   come and go? Any "blocked" line or Lua error?
3. **Buffs tab, the dropdown:** "Blizzard's icons (picked in /cdm)": What happens to them: Take
   them in / Hide them / Leave them. Space between, grow from, vertical, icons per row change
   the place at once. "Open /cdm" opens Blizzard's window.
4. **Hide them:** gone, and still gone after `/reload` and a loading screen; the raid warning on
   a drop still comes. **Leave them:** back where Blizzard puts them (at its next layout, or
   `/reload`).

## To check (buffs, part 1, 2026-11-21)

New files: install, then fully restart the game.

1. **First look.** A buff group "Buffs" above the middle of the screen with your buffs from
   Blizzard's list (Battle Shout, Bloodrage, Berserker Rage ...): each shows while it's on you,
   with a swipe and the time left, and the others close up. In combat too, in a dungeon too.
2. **Learning ranks.** Cast Battle Shout out of combat (or get one from another warrior): from
   then on it shows whoever cast it. A buff from someone else (Fortitude, Mark of the Wild):
   Buffs tab, "Add or remove buffs", "On you now", tick it.
3. **Timer bars.** Show as: Timer bars. Each buff is a bar with its icon, name and time left,
   draining to the right, stacked top to bottom. Bar height, bar width, spacing, grow from.
4. **A change in combat** (tick a buff, switch Show as) applies when combat ends.
5. **Move.** `/lecdm move`: the buff group shows its name on a blue shade with the icon bars.
6. **Bag items** (Icon bars tab): "Items you have none of: Show them greyed": a potion you've
   run out of stays, greyed, with a 0.
7. Any Lua errors?
8. **Test messages** (Test build tab, "Show them in"): make a chat tab named Lecdm (right-click
   a chat tab, Create New Window), pick it: the applied / removed lines go there, `/lecdm help`
   still answers in the main chat. "Nowhere": no lines in chat, but `/lecdm log` has them.

## To check (cooldown bars, 0.1.0-dev)

New files: run `tools\install_forever.cmd`, then fully restart the game. `/lecdm help` shows the
build.

1. **First look.** Two bars under your character: Cooldowns (your Essential spells) and Utility.
   Spells you haven't learned don't show. Blizzard's own Essential and Utility icons are gone
   (its buff icons and bars are still there).
2. **In combat** (a dungeon too): each icon's swipe and countdown, grey while on cooldown and
   back to colour when ready, a short GCD sweep, dark when you can't cast it (no rage), red
   when your target is out of range (Charge, Intercept). No Lua errors.
3. **Icon bars tab** (`/lecdm bars`; since 2026-11-21: the dropdown picks a bar, its "New icon
   bar..." entry asks for a name in a popup, the name field renames, Delete asks first; a spell
   on another bar says "(on ...)" in the checklist):
   - "Add or remove spells": the checklist opens with Blizzard's Essential, Blizzard's
     Utility and Spellbook sections; ticking adds a spell to the bar shown (moving it from
     another bar), unticking takes it off; the list stays open while you tick.
   - The arrows move a spell up and down; the X takes it off.
   - "Only when ready" on Charge: it vanishes while cooling down and the others close up;
     "Only on cooldown": the other way round.
   - Icon size, spacing, grow from, vertical, icons per row, GCD sweep: each changes the bar
     at once.
   - New bar, rename, delete; Start over brings back the two bars.
4. **Move.** `/lecdm move`: each bar shows its name on a blue shade; drag them; `/lecdm move`
   again. After `/reload` they're where you left them.
5. **Blizzard's icons.** Untick "Hide Blizzard's Essential and Utility icons": they come back.
   Tick it: gone again. Do they stay gone after Edit Mode and a loading screen? Does the
   listener (raid warning on a drop) still work with them gone?
6. **Items** (2026-11-21). Your profile was made before items, so tick them yourself: Icon
   bars tab, "Add or remove spells", "Equipped": tick the top trinket (Satchel of Potions);
   "In your bags": tick a potion or healthstone. Then:
   - the trinket's icon shows; using it, its swipe runs and it goes grey, in combat too (this
     is the first real test of item cooldowns in combat: no swipe in combat means they're
     secret after all);
   - the bag item shows its count, and disappears when you have none left;
   - swapping trinkets: the slot shows the new one (or hides, if it has no use effect).

Owner, 2026-11-21 (e835f70): two blue bars filled with the right warrior spells; the rest
"seems fine". Asked for: a dropdown instead of the arrows, a popup for a new bar, no look-alike
controls side by side, and the name "icon bar". Done in the build after.

## Checked (test build 1, 0.0.1-dev)

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
- **Trinket slots are readable in combat, in an instance** (step 13): "Satchel of Potions: slot
  cooldown start 0, duration 0, enabled 1". It wasn't on cooldown, so whether a running item
  cooldown reads as numbers or SECRET is still open.
- **`/lecdm check` covers every spell:** 26 lines, "no power" readable; Eureka! read "on
  cooldown true", so racials behave like spells.

Open world, 34d86ec, 2026-11-20:

- **Blizzard's icons live in a Lecdm row** (step 14): with `/lecdm host on` for 7 minutes of
  fights, Blizzard's buff icons and bars stayed in Lecdm's row the whole time, and the bars
  followed each target, showing that target's own debuff time left. No blocked, refused or Lua
  errors.
- **An expiry on a live target reads "dead false"**, at the moment and a frame later (Thunder
  Clap, Sunder Armor). Kills in that log logged no "removed" at all (in the first dungeon they
  did, all of a target's debuffs in the same second), so what a kill reads is still open.

Dungeon, 34d86ec, 2026-11-20 (about 15 kills):

- **A kill reads as "target gone a frame later"** (step 12): all of the target's debuffs are
  "removed" in the same second, "target exists true, dead false" at that moment, then "a
  frame later: target exists false" (10 kills). An expiry on a live mob: one debuff, and a
  frame later the target still exists, alive. "Dead" never read true at a kill. Three
  same-second pairs kept "target exists true" a frame later (most likely already on the next
  mob). So: a target debuff's "removed" waits a frame and is a kill if the target is gone.

- **The host test holds in a dungeon too** (step 14): the owner reports Blizzard's bars stayed
  in Lecdm's row the whole run.
- **A trinket on cooldown** (step 13) wasn't tried; assumed to read like a spell (numbers
  SECRET, the item's cooldown state usable). To confirm once the bars show trinkets.

Test build 1 is finished (2026-11-20).

## Problems

None yet.
