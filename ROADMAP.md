# Roadmap

What's done for lecdm, and what's next. Update it in the same commit as the
change.

## The plan (agreed 2026-11-20)

Lecdm is a WoW: Forever addon that makes Blizzard's Cooldown Manager better and simpler to
manage: what EllesmereUI's Cooldown Manager tries to do, complete and without its breakage. It
stands on its own; nothing is left out because another addon does something similar.

**Why Blizzard's Cooldown Manager is hard to live with**

- It's managed in three places: what's tracked in its settings window, look and position in Edit
  Mode, on/off in Options.
- Only Blizzard's list for the class; buffs only the player cast, on the player or the target.
- Looks are per viewer (four of them), not per spell; hidden buffs keep their gap.
- Alerts: 3 per spell, about 5 clicks each, fixed sounds. Hiding a viewer also silences them.

**Why EllesmereUI's version breaks** (from its code and about 50 issues and 380 PRs)

- It moves Blizzard's own icons into its bars, then fights every re-layout (parks frames
  off-screen, re-pins viewers, re-applies alpha): icons vanish after battlegrounds, order snaps
  back, layout jumps, blocked-action errors.
- It keeps its own spell list next to Blizzard's and syncs them by deleting what doesn't match:
  users lost spells.
- It rewrites the Edit Mode layout at login and forces a reload.
- It matches icons by spell ID in combat, where IDs can be secret: wrong names and icons.
- Timers and retries (1, 3, 6 s) instead of events.

**How Lecdm works: Blizzard knows, Lecdm shows.** Three engines, each used for what only it can do:

1. **Blizzard's Cooldown Manager:** Blizzard's code reads the secret values itself. It gives
   Lecdm the class's list (with ranks), and it announces what it notices, in combat too: a
   tracked buff applied or removed, a spell going on cooldown, a charge back. Lecdm listens
   (hooksecurefunc on each icon's `TriggerAlertEvent`) and changes nothing. It also covers what
   nothing else can: the player's own effects on the target, and totems.
2. **The spell API:** whether a spell is on cooldown or the GCD is never secret; usable, range
   and proc events can be read; the game draws an addon's own swipe and countdown from a
   duration object. So Lecdm's own icons can act on cooldown state in combat (hide when ready,
   glow when ready, a sound when ready).
3. **Aura containers:** buffs on the player from anyone (another priest's Fortitude, another
   warrior's Battle Shout, world buffs, consumables), which the Cooldown Manager doesn't track.

All of it is managed in one Lecdm window: bars, spells, looks, alerts, profiles, placed by
dragging. No trips to Blizzard's settings window or Edit Mode.

**Rules, from EllesmereUI's failures**

- Never write Blizzard's Cooldown Manager data, its frames' fields, Edit Mode layouts or its
  CVars; no forced reloads.
- Never park, re-pin or alpha-fight Blizzard's frames.
- One source of truth per thing; never delete anything Lecdm can't place.
- Identify Blizzard's icons by cooldown ID, read when needed (icons are reused).
- Events, not timers.
- A feature that would need a Lua decision on a secret value needs an engine-side way, or it's
  shown greyed out with the reason. Test in an instance in combat, and in the open world.

**Can't be done on Forever, by anyone:** rotation assist, hero talents, the pandemic glow
(no time carries over on refresh), timing other players' buffs in combat.

## Done

- The plan above (2026-11-20), and test build 1 tried in game (2026-11-20, TESTING.md): the
  listener hears applied and removed in combat inside a dungeon, with Blizzard's viewers
  invisible too; cooldown state, GCD, usable and range are readable there; Lecdm's own icons
  swipe and grey in combat; Blizzard's buff icons and timer bars can live in Lecdm's frames.
- **0.9.0-alpha (2026-11-21), the first alpha** (CHANGELOG.md has the details):
  - the core: the options window, profiles, minimap button, Options > AddOns entry;
  - icon bars: spells, trinkets and on-use gear, bag items; per-spell when it shows; looks,
    keybind text, visibility. Naming (owner, 2026-11-21): ours are **icon bars**; Blizzard's
    "tracked bars" (icon left, a draining fill right) are **timer bars**;
  - buffs: buff groups as icons or timer bars (owner's pick 2026-11-21: buffs on you from aura
    containers, picked in Lecdm), keep-up and only-while-missing buffs, Blizzard's icons and
    timer bars taken in (your debuffs on the target, picked in `/cdm`);
  - alerts: sounds ("Say it" too) and glows, defaults and per spell or buff;
  - diagnostics; the release kit (icon, banner, LISTING.md, zip, tag).

## Next

1. **The alpha in game** (TESTING.md): above all the alerts, keep-up buffs, Blizzard's icons
   taken in, and item cooldowns in combat.
2. **Icon bars:** drag to order in the window, per-spell looks (its own border, glow colour),
   charges, a cooldown shown as a timer bar.
3. **Items:** "best in your bags" (one entry for any healing potion or healthstone, the best you
   carry).
4. **Timer bars:** thresholds and ticks, a colour change at the warning time.
5. **Blizzard's icons taken in:** their size from Lecdm instead of Edit Mode, if it can be done
   without fighting Blizzard's scale; their own alerts per aura from Lecdm's window.
6. **Alerts:** a warning sound as a buff runs out (out of combat from its real time; in combat
   only where it can be timed), on-screen text, charges.
7. **The rest of the feature reference's list:** glows on action-bar buttons by buff state, a
   focus interrupt bar, a swing-timer sweep for on-next-swing attacks (Heroic Strike, Cleave),
   a queued-attack highlight, a key-press mirror, import/export.
8. **Release:** the first upload to CurseForge and Wago (LISTING.md), then a beta.

## Ideas

- A preview while the window is open, so buff groups can be laid out without the buffs.
