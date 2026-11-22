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
- Since the alpha: Blizzard's own buff icons and timer bars hidden by default (2026-11-21: only
  what the player sets up shows); how a buff looks while up and while missing (2026-11-22).

## Next

1. **The alpha in game** (TESTING.md): above all the alerts, keep-up buffs and the looks,
   Blizzard's icons taken in, and item cooldowns in combat.
2. **Parity** (the owner, 2026-11-22: everything leBoof and the feature reference can do): the
   checklist below, top to bottom, a push at a time with tests. Anything that turns out not to
   work on Forever moves to "Can't be done" above, with the reason, before it's dropped.
3. **Release:** the first upload to CurseForge and Wago (LISTING.md), then a beta.

## Parity checklist

**From leBoof**

- [x] Grey and faded while up, the icon back at the warning time; the missing copy in full
      colour, grey or dimmed red, at its own opacity (2026-11-22)
- [ ] A sound as a buff runs out, at the warning time: out of combat from its timer; in combat
      timed from your own cast with the learned duration (not for shared buffs while another of
      that class is grouped); once per cast
- [ ] Going into combat with a keep-up buff missing: a sound, and the missing ones in chat
- [ ] Built-in buff lists per class, with every rank and group version (Prayer of Fortitude
      counts as Fortitude), world buffs, weapon enchants (oils, sharpening stones)
- [ ] Tooltips on hover (buff groups, icon bars)
- [ ] Glow previews on sample icons in the window
- [ ] A sound log: every sound any addon plays, and why Lecdm played its own
- [ ] Chat commands per buff (`/lecdm <buff> keep|missing|up`)

**Cooldown icons**

- [ ] Glow while on cooldown; lower opacity on cooldown; keep colour on cooldown (also when
      short of the resource)
- [ ] Hidden until usable; hidden in or outside a stance or form; shown only with talents
      taken or not
- [ ] Charges: the count (hidden at 0), a glow at max charges, swipe and edge options
- [ ] Swipe off or reversed, the cooldown edge always, swipe colour
- [ ] The spell's own buff on its icon: a swipe colour, glow or border while it's up, or the
      buff in its slot while up; the buff's stacks on the icon
- [ ] The countdown in a colour and with a decimal under a set time
- [ ] Per-spell looks: its own border and glow colour; its own icon
- [ ] Empty spacer slots, racials, custom spell and item IDs
- [ ] "Best in your bags": one entry for healing potions or healthstones, the best you carry, in
      a priority order you set
- [ ] A cooldown shown as a timer bar
- [ ] Drag to order, click for settings, in a preview in the window

**Buff icons**

- [ ] A glow at a number of stacks (fewer, at most, exactly, at least, more)
- [ ] Shown only for its last seconds
- [ ] Swipe colour, reversed swipe; text (size, colour, position) and border per buff

**Icon bars and layout**

- [ ] Icon shapes (square, round, ...) and a bar background
- [ ] Rows: how many, which way, a second row's size; overflow into another bar past a number
- [ ] Anchored to another bar or to the cursor; strata; a minimum width in icons
- [ ] Fonts, outline, sizes and positions for the countdown and the count; a keybind badge
      (background, border, padding)
- [ ] Item count never, always or out of combat; item quality; trinkets without a use
- [ ] Key-press mirror (the pressed look when you press its key)
- [ ] Copy a setting to all bars

**Timer bars**

- [ ] Spark, gradient fill, reverse fill, the icon left or right, height and width
- [ ] Ticks and stack thresholds (up to five, with colours), max stacks, stack-based bars
- [ ] A colour change at the warning time
- [ ] Custom names; name, time and stacks text size and position; a decimal under a set time
- [ ] Saved styles, applied to a bar or a group

**Visibility**

- [ ] Party, raid or solo; instances and dungeons; mounted; resting; in a vehicle; an enemy
      target; match all or any of them

**Glows**

- [ ] Pixel glow: line count, thickness, speed, background
- [ ] A solid fill style
- [ ] Glows only in combat (for everything)
- [ ] Glows on action-bar buttons (any bar addon): while a buff is up or missing, while usable,
      health above or below a %, at stacks, only in combat; late in a swing

**Sounds and alerts**

- [ ] On-screen text
- [ ] A sound when a charge comes back
- [ ] More sounds to pick from

**The rest**

- [ ] Swing sweep on Heroic Strike and Cleave (icons and action buttons); a queued-attack
      highlight
- [ ] A focus interrupt bar, with a sound when the focus starts casting
- [ ] Import and export (profiles, icon bars, buff groups)
- [ ] Shared entries (trinkets, potions, racials) kept in step across profiles
- [ ] Blizzard's icons taken in: their size from Lecdm instead of Edit Mode (if it can be done
      without fighting Blizzard's scale), their own alerts per aura from Lecdm's window

Not on the list, not in Classic: Skyriding and housing visibility, Bloodlust-style presets,
hero talents, rotation assist (see "Can't be done").

## Ideas

- A preview while the window is open, so buff groups can be laid out without the buffs.
