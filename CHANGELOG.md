# Changelog

All notable changes to lecdm. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
