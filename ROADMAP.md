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

- Standard docs (2026-11-20), filled in with what's known so far.
- The plan above (2026-11-20).
- Test build 1 (0.0.1-dev, 2026-11-20): listens to the Cooldown Manager, reads its list, checks
  what's readable in combat, test icons, an invisible-viewers test. Not tried in game yet.
- Test build 1 tried in game (2026-11-20, TESTING.md): the listener hears applied and removed
  in combat inside a dungeon, with Blizzard's viewers invisible too; cooldown state, GCD,
  usable and range are readable there; Lecdm's own icons swipe and grey in combat.
- Core (2026-11-20, in the owner's house style): the options window (General, Bars, Buffs,
  Alerts, Test build, Profiles tabs; Bars, Buffs and Alerts say what's coming), profiles ("First
  Last", shared, switched by talents or group role), the minimap button and addon compartment,
  an Options > AddOns entry, `/lecdm`. The icon is a stand-in (a pocket watch) until the release
  kit's art. Not tried in game yet.

## Next

1. **Cooldown bars:** any number, own icons, per-spell look and behaviour, a spell picker
   (Blizzard's list, spellbook), drag to order and place.
2. **Items:** trinkets and other on-use slots, racials, potions, healthstones.
3. **The display of what only the Cooldown Manager can show** (the player's effects on the
   target, its timers; an addon can't time them in combat): settled 2026-11-20 in the host
   test. Blizzard's own buff icons and bars live in Lecdm's bars, re-placed after each of
   Blizzard's layouts, and follow each target. Confirmed in the open world and in a dungeon.
4. **Buffs:** the Cooldown Manager's tracked buffs and procs, buffs from others (aura
   containers), missing state.
5. **Effects on the target:** the player's DoTs and HoTs.
6. **Alerts and effects:** sounds and glows on ready, applied, removed, charges; per-spell
   glow styles; keybind text; visibility rules (combat, group, instance, target, mounted ...).
7. **Status bars** (EllesmereUI's Tracking Bars): groups, thresholds, ticks.
8. **The rest of EllesmereUI's list:** action-bar button glows on buff state, focus interrupt
   bar, swing-timer sweep for on-next-swing attacks, queued-attack highlight, key-press mirror,
   import/export.
9. **Release kit:** icon and banner, LISTING.md, packaging, CurseForge and Wago.

## Ideas

TODO: things that might be worth doing later.
