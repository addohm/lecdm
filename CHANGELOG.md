# Changelog

All notable changes to lecdm. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Standard docs: README, CLAUDE, CHANGELOG, DEPLOY, SECURITY and ROADMAP (2026-11-20),
  filled in with what's known so far.
- The plan in ROADMAP.md: Blizzard knows, Lecdm shows (2026-11-20).
- Test build 1, 0.0.1-dev (2026-11-20): listens to Blizzard's Cooldown Manager (applied,
  removed, on cooldown ...), with a raid warning when a tracked buff drops; `/lecdm list` shows
  Blizzard's list; `/lecdm check` shows what's readable now; test icons from duration objects;
  `/lecdm blizz hide|show` tests invisible viewers; a copyable log. TESTING.md has what to try.
- `tools/install_forever.cmd`, `tools/make_release.py` and the tests (`tests/run_tests.py`).
- The core (2026-11-20): an options window (`/lecdm`, the minimap button, the addon compartment,
  or Options > AddOns) with General, Bars, Buffs, Alerts, Test build and Profiles tabs; profiles
  per character ("First Last"), shareable, switched by talents or group role; Enable Lecdm, the
  login reminder, a class-coloured window, Reset all settings.

- Test build 1, more checks (2026-11-20): "removed" lines say whether the target exists and is
  dead, at that moment and again a frame later; `/lecdm check` covers every spell, "no power" and trinket slots 13 and 14 (into the log,
  with a summary in chat); blocked actions (any addon's) and the first swings of each fight are
  logged; `/lecdm host on|off` places Blizzard's buff icons and bars in a row Lecdm controls.

- Cooldown bars (0.1.0-dev, 2026-11-20): your cooldowns in bars of Lecdm's own icons, set up on
  the Bars tab. The first time, two bars (Cooldowns, Utility) are filled from Blizzard's
  Essential and Utility lists. Each icon: the swipe and countdown (the GCD sweep can be turned
  off per bar), grey on cooldown, dark when you can't cast it, red when your target is out of
  range. Per spell: always, only when ready, or only on cooldown; hidden icons close the gap.
  Per bar: icon size, spacing, grow from, vertical, icons per row. Spells are added from a
  checklist of Blizzard's list and your spellbook, ordered with up and down, and not-learned
  ones appear once learned. `/lecdm move` (or Unlock on the Bars tab) lets you drag the bars.
  Blizzard's Essential and Utility icons are made invisible while Lecdm's bars are on (they
  keep running); a setting gives them back.

### Changed

- The Bars tab is now **Icon bars** (owner's naming, 2026-11-21: "timer bars" will be the
  other kind). A dropdown picks the icon bar, and its "New icon bar..." entry opens a popup
  for the name; the bar's name is a field under "This icon bar", with Delete at the end of
  that section. In the checklist, a spell on another icon bar says "(on ...)". Both dropdowns
  are the size of the window's buttons and line up with them.
- The test icons are gone: the bars replace them, and `/lecdm move` now moves the bars
  (`/lecdm icons` is gone).

- `/lecdm` opens the options window; the status is `/lecdm status`. The test build's settings
  (raid warning, test icons and their place) live in the profile; 0.0.1's move there once.
