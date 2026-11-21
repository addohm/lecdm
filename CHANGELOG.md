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

- Items on icon bars (2026-11-21): equipment slots (the trinkets, and any gear with a use
  effect: whatever's equipped there, shown while it has one) and usable items from your bags
  (potions, healthstones ...: with the count, hidden while you have none), with their
  cooldown swipe, grey on cooldown and dark when unusable. New profiles get both trinket slots
  on the Utility bar; the checklist has "Equipped" and "In your bags" sections.

- Buffs, first part (2026-11-21): buff groups on the Buffs tab, showing buffs on you from
  anyone while they're up, as icons (swipe, time left, stacks) or timer bars (icon, a draining
  bar with the name and time left, stacks), through Blizzard's aura containers (in combat
  too). Each group: name, show as, icon size or bar height and width, spacing, grow from,
  vertical, icons per row. Buffs are ticked from your buffs in Blizzard's list or the buffs on
  you now, and ordered; every rank and caster of a buff is learned the first time it's seen on
  you out of combat. The first group is filled from Blizzard's list. Unlock moves buff groups
  with the icon bars.
- Icon bars: "Items you have none of": hide them (as before), or show them greyed with a 0.
- Test build tab: "Show them in": the test build's debug lines (applied, removed, procs,
  checks) go to the main chat window, a chat tab you've made, or nowhere (the log keeps them).
  Replies to commands and Lecdm's errors stay in the main chat.
- Buffs, part 3 (2026-11-21): Blizzard's icons and timer bars (what its Cooldown Manager
  tracks in its Buffs tab: your debuffs on the target among them) taken into Lecdm. Each has a
  place on the Buffs tab's dropdown: take them into Lecdm (the default: Lecdm's own movable
  place, spacing, grow from, vertical and per row for icons, gaps closed, re-placed after each
  of Blizzard's layouts, in combat too), hide them (invisible at every login and `/reload`,
  still running), or leave them. Which ones and their order are picked in `/cdm` ("Open /cdm").

- Alerts (2026-11-21): the Alerts tab sets the sounds and glows every spell and buff gets; a
  ⚙ on each row on the Icon bars and Buffs tabs sets its own. Icon bars: sound when ready,
  glow while ready (and usable), glow on a proc, colour. Buff groups: sounds when applied and
  when it drops (in combat for buffs Blizzard's `/cdm` also tracks, from its announcement; out
  of combat for any buff on you, read directly), glow while up, time red under a few seconds,
  a warning glow then (timed by the game from the buff's duration, learned out of combat),
  colour. Blizzard's icons and timer bars: sounds when applied and when it drops, quiet when
  the target died. Sounds: the game's, or "Say it" (text to speech). Glow styles: pulse,
  pixel, action button, auto-cast, GCD, modern, classic.

### Changed

- The test build's raid warning on a drop (and `/lecdm sound`) is gone: the alerts replace it.
- "Hide Blizzard's buff icons and timer bars" (added earlier on 2026-11-21) is replaced by
  part 3's "What happens to them", which can still hide them. The host test
  (`/lecdm host`) is gone: taking Blizzard's icons in replaces it.

- The Bars tab is now **Icon bars** (owner's naming, 2026-11-21: "timer bars" will be the
  other kind). A dropdown picks the icon bar, and its "New icon bar..." entry opens a popup
  for the name; the bar's name is a field under "This icon bar", with Delete at the end of
  that section. In the checklist, a spell on another icon bar says "(on ...)". Both dropdowns
  are the size of the window's buttons and line up with them.
- The test icons are gone: the bars replace them, and `/lecdm move` now moves the bars
  (`/lecdm icons` is gone).

- `/lecdm` opens the options window; the status is `/lecdm status`. The test build's settings
  (raid warning, test icons and their place) live in the profile; 0.0.1's move there once.
