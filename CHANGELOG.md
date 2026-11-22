# Changelog

All notable changes to lecdm. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- How a buff looks (the owner's look, 2026-11-22), on the Alerts tab and each buff's ⚙: grey
  and an opacity while it's up, the icon coming back to full strength at the warning time (in
  combat too, timed by the game once the buff's duration is known); and a keep-up buff's place
  while it's missing: the copy in full colour, grey or dimmed red (the default), at its own
  opacity. Glows stay at full strength.
- Buff sounds: as a buff runs out, at the warning time (out of combat from its own timer; in
  combat from its time when the fight started or from your own cast with the duration learned
  out of combat; quiet in combat when another of your class is in the group; once per cast);
  going into combat without a keep-up buff, a sound and the missing ones in chat. The warning
  time can be each buff's own, and goes up to 2 min.
- Lecdm's list of buffs in the Buffs tab's checklist: your class's buffs, your procs and
  cooldowns, buffs other classes put on you, your race's, world buffs and consumables, for every
  class, with every rank and their group versions (Prayer of Fortitude counts as Power Word:
  Fortitude), each with its own warning time, and which class can recast it (the running-out
  sound's in-combat timing). Spell IDs from Forever's spell names (`tools/gen_data.py`).
- Tooltips on hover: the game's tooltip for an icon bar's spells and items (off by default, so
  clicks go through; on; or out of combat only), and the choice for buff groups (on by default).
- Icon bars: an opacity while on cooldown, a glow while on cooldown, and "only when ready and
  usable" (Overpower, Revenge, Execute: hidden until you can use them).
- Icon bars, in a spell's ⚙ menu: show it only in (or out of) a stance or form, and only with
  (or without) a talent, read from Forever's talent tree.
- A spell's own buff on its icon (its ⚙: "While its buff is up"): while Death Wish, Shield
  Block or Slice and Dice is on you, the icon shows the buff, from an aura container on the
  icon (in combat too): its time as a swipe in the bar's colour for it, its stacks, a glow.
- Icon bars: near the end of a cooldown (under a time you pick), the countdown in a colour (the
  game's duration text binding, so in combat too) or with a decimal (8.7).
- The Icon bars tab's preview: the bar's icons in order; drag one onto another to move it,
  right-click for its ⚙ menu, middle-click to take it off.
- Icon bars as timer bars: the icon at the left, then a bar the game fills from the
  cooldown's duration (full when ready), the name and the time left; height, width, texture,
  colour.
- Icon bars: best in your bags: one entry for healing potions, mana potions, healthstones (the
  improved ones too) or runes, showing the best you carry, in an order you can change.
- Icon bars: empty spaces that keep a place, and a spell or item added by its ID.
- A spell's own look on its icon bar (its ⚙): border, border colour, and its icon (another
  spell's, an item's, or any icon by file ID).
- The swipe, for icon bars and buff groups: normal, reversed or none, its colour, and (icon
  bars) a bright edge.
- Charges on icon bars: the count (shown by the game, so in combat too), the recharge swipe while
  one comes back, a glow at full charges, and 0 shown or not.
- A sample icon next to each glow picker on the Alerts tab, showing the glow and colour.
- The sound log (Diagnostics, `/lecdm soundlog on`): every sound any addon plays goes in the
  log, with the addon that played it and, for Lecdm's own, why.
- `/lecdm buff`: your buff groups' buffs; `/lecdm buff <name> keep | missing | up | out` (any
  part of a name: `fort`) sets one, putting a buff from Lecdm's list in the first group.
- Weapon enchants in buff groups (main and off hand: oils, sharpening stones, poisons, shaman
  weapon spells), shown by the game in a place of their own, kept up or only while missing like
  a buff, with their sounds (applied, dropped, running out) out of combat.

### Changed

- Blizzard's own buff icons and timer bars are hidden by default, and profiles from
  0.9.0-alpha switch to hidden once (the owner: Lecdm shows only what you set up). They keep
  running, so in-combat sounds still hear them; taking them in or leaving them is still a
  choice on the Buffs tab. Version 0.9.1-dev.

## [0.9.0-alpha] - 2026-11-21

The first alpha. The development notes from 2026-11-20 and 2026-11-21 (test build 1, then
each feature as it landed) are folded into this entry.

### Added

- **Icon bars:** Lecdm's own icons for your cooldowns, in any number of bars (two filled from
  Blizzard's Essential and Utility lists at first). Each icon: the swipe and countdown (drawn by
  the game from a duration object), a GCD sweep or none, grey on cooldown, dark when unusable,
  red out of range. Per spell: always, only when ready, or only on cooldown, gaps closing. A
  checklist of Blizzard's list, the spellbook, equipped trinkets and on-use gear (a slot shows
  what's equipped there) and usable bag items (with the count; hidden or greyed when you have
  none), up/down order. Per bar: size, spacing, grow from, vertical, icons per row, border,
  zoom, countdown text, keybind text from any bar addon. Blizzard's Essential and Utility
  viewers are made invisible while the bars are on (they keep running).
- **Buff groups:** buffs on you from anyone, through Blizzard's aura containers (in combat
  too), as icons or timer bars; while up, keep up (a fixed place with a dimmed red copy and a
  glow while missing) or only while missing. Every rank, caster and full duration of a buff is
  learned by name out of combat. Timer bars: texture, colour, background, icon, name, time.
- **Blizzard's icons and timer bars** (what `/cdm` tracks in its Buffs tab, your debuffs on the
  target among them): taken into Lecdm's own places (spacing, grow from, vertical, per row,
  gaps closed, re-placed after each of Blizzard's layouts), hidden, or left as they are.
- **Alerts:** defaults on the Alerts tab, and each spell's or buff's own (⚙). Sounds (the game's
  or "Say it") when ready, applied or dropped; glows while ready, on a proc, while up, at the
  warning time and while missing; time red near the end; quiet when the target dies. Seven
  glow styles, eleven colours and class colour.
- **Visibility:** for every icon bar, buff group and Blizzard place: always, only in combat, or
  in combat or with a target; opacity; out of combat the same, faded or hidden.
- **Options window** (`/lecdm`, the minimap button, the addon compartment, Options > AddOns):
  General, Icon bars, Buffs, Alerts, Diagnostics and Profiles tabs. Profiles per character
  ("First Last"), shareable, switched by talents or group role. `/lecdm move` drags everything.
- **Diagnostics:** what Lecdm hears from Blizzard's Cooldown Manager and can read about your
  spells, in a copyable log (`/lecdm status`, `list`, `check`, `log`), with its chat lines sent
  to the main chat, a chat tab of yours, or nowhere.
- **Release kit:** the icon and banner (`art/make_logo.py`), `LISTING.md`,
  `tools/make_release.py`, `tools/install_forever.cmd`.

### Found in game (test build 1, 2026-11-20)

- Blizzard's Cooldown Manager announces applied and removed for what it tracks, in combat,
  inside a dungeon, with its viewers invisible too; a kill reads as "the target gone a frame
  later".
- Spells' cooldown state (on cooldown, GCD), usable and range are readable in combat; the start
  time is secret; duration objects draw an addon's own swipes; item cooldowns aren't secret.
- Blizzard's own buff icons and timer bars can live in an addon's frames, re-placed after each
  of Blizzard's layouts, in combat and in a dungeon.
