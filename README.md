# lecdm

![Lecdm: your cooldowns and buffs, your way](art/lecdm-banner.png)

Lecdm is a **World of Warcraft: Forever** addon that makes Blizzard's Cooldown Manager better and
simpler to manage: your cooldowns in icon bars, your buffs from anyone as icons or timer bars,
your debuffs on the target, and sounds and glows that work in combat, all laid out and styled
your way from one window. It builds on what Blizzard's Cooldown Manager knows instead of fighting
it: no Edit Mode trips, no forced reloads, nothing read that the game hides.

**Status:** 0.9.0-alpha (2026-11-21), the first alpha. The core is tried in game, in the open
world and in dungeons (TESTING.md lists what's confirmed); the rest is checked against a
stand-in for the Forever API. The plan and what's next are in [ROADMAP.md](ROADMAP.md).

## Install

- **A release:** unzip `release/Lecdm-<version>.zip` (it holds the `Lecdm` folder) into
  `World of Warcraft\_forever_\Interface\AddOns\`, then restart the game.
- **For development on Windows:** clone the repo (`git clone https://github.com/addohm/lecdm.git`),
  check `WOW` at the top of `tools\install_forever.cmd` (default
  `C:\Program Files (x86)\World of Warcraft\_forever_`), and run it from a terminal. It pulls,
  copies `Lecdm` into the client, stamps the build and packs `Lecdm-<version>.zip` on your
  desktop. Fully restart the game when it says so, otherwise `/reload`. `/lecdm help` shows the
  build you're running.

## Usage

`/lecdm` (or `/lcdm`), the minimap button, the addon menu by the minimap, or Options > AddOns >
Lecdm opens the options window. `/lecdm move` unlocks everything Lecdm shows: each piece shows
its name on a blue shade and can be dragged; `/lecdm move` again locks it.

- **General:** Enable Lecdm, the minimap button, the login reminder, a class-coloured window,
  Reset all settings, the chat commands.
- **Icon bars:** your cooldowns in rows of icons. The dropdown at the top picks an icon bar;
  its last entry, "New icon bar...", makes one (it asks for a name). Everything below is about
  the bar picked:
  - its name and layout: icon size, spacing, grow from (centre, left or right), vertical, icons
    per row, the GCD sweep, and items you have none of (hidden, or greyed with a 0);
  - its look: border and colour, icon zoom, countdown text size, keybind text (the key of the
    first action button on screen holding it, from any bar addon), grey on cooldown, red out of
    range, dark when unusable;
  - when it shows: always, only in combat, or in combat or with a target; opacity; out of
    combat the same, faded or hidden; and Delete;
  - its spells and items: tick them in the checklist (Blizzard's Essential and Utility lists,
    your spellbook, your equipped trinkets and on-use gear, usable items in your bags; an entry
    on another bar says "(on ...)" and ticking moves it), order them with the arrows, choose
    when each shows (always, only when ready, only on cooldown; the others close up), and its
    own alerts (⚙). A trinket slot shows whatever's equipped there while it has a use effect;
    spells you haven't learned appear once you do.

  The first time, two icon bars are filled from Blizzard's list. Blizzard's own Essential and
  Utility icons are made invisible while Lecdm's icon bars are on (they keep running); untick
  "Hide Blizzard's Essential and Utility icons" to keep them.
- **Buffs:** laid out like Icon bars, for buff groups: buffs on you from anyone (your own,
  another priest's Fortitude, world buffs, procs). For the group picked: its name, **Show as**
  icons (a swipe, the time left, stacks) or **timer bars** (the icon, then a bar draining to the
  right with the name and the time left), its layout, look (border, zoom, time text; for timer
  bars texture, colour, background, and icon, name and time each on or off), when it shows, and
  its buffs: tick them from your buffs in Blizzard's list or from the buffs on you now (out of
  combat), order them, choose how each shows (**while it's up**, **keep up**: a fixed place with
  a dimmed red copy and a glow while it's down, or **only while missing**), and its own alerts.
  Every rank of a buff, whoever cast it, and its full duration are learned the first time Lecdm
  sees it on you out of combat. Changes made in combat apply when it ends.

  The dropdown also has **Blizzard's icons** and **Blizzard's timer bars**: what Blizzard's
  Cooldown Manager tracks in its Buffs tab, your debuffs on the target among them (only
  Blizzard can time those). For each: **take them into Lecdm** (the default: Lecdm's own place,
  spaced and grown your way, gaps closed, following each target), **hide them**, or **leave
  them** where Blizzard shows them; and when they show. Which ones and their order are picked in
  `/cdm` (Tracked Buffs for icons, Tracked Bars for timer bars; "Open /cdm" is right there);
  their size is Edit Mode's.
- **Alerts:** the sounds and glows every spell and buff gets unless it has its own (the ⚙ on
  its row: a submenu per setting, "Default (...)" first). Sounds are the game's (raid warning,
  ready check, alarm clock ...) or "Say it", which speaks the name.
  - Icon bars: a sound when it's ready (off cooldown, not the GCD), a glow while it's ready and
    usable, a glow while the game highlights it (a proc); glow colour.
  - Buff groups: sounds when it's applied and when it drops (in combat only for buffs
    Blizzard's `/cdm` also tracks, from its announcement; out of combat for every buff on you),
    a glow while it's up, the time turning red under a few seconds and a warning glow then
    (icons, timed by the game from the buff's learned duration), a glow while a keep-up buff is
    missing (red pixel glow by default); colours.
  - Blizzard's icons and timer bars: sounds when it's applied and when it drops; quiet when
    your target dies, unless "Also when your target dies".
- **Diagnostics:** where Lecdm's diagnostic lines go ("Show them in" the main chat window, a
  chat tab you've made, or nowhere: the log keeps them), and tools: Blizzard's viewers
  invisible (a test, not kept), status, Blizzard's list, what's readable now, and the log,
  ready to copy into a bug report.
- **Profiles:** each character starts with its own ("First Last"); pick another to share it,
  copy, rename, delete, reset, or switch automatically by your talents or group role.

Chat commands:

| Command | What it does |
|---|---|
| `/lecdm` | Open or close the options window |
| `/lecdm general` ... `profiles` | Open that tab (`bars`, `buffs`, `alerts`, `diagnostics` too) |
| `/lecdm move` | Unlock everything to drag it; again to lock |
| `/lecdm profile` | The profile in use, and the Profiles tab |
| `/lecdm minimap` | Show or hide the minimap button |
| `/lecdm on` / `off` | Turn Lecdm on or off |
| `/lecdm help` | The commands, and the build |
| `/lecdm status` | Is Blizzard's Cooldown Manager available, what it lists, what's listened to |
| `/lecdm list` | Every entry Blizzard's Cooldown Manager lists for you, by section |
| `/lecdm check` | What an addon can read about your spells right now (try it in combat) |
| `/lecdm blizz hide` / `show` | Make Blizzard's cooldown viewers invisible, or bring them back (a test) |
| `/lecdm log` | The log in a window, ready to copy; `/lecdm log clear` empties it |

## Docs

- [ROADMAP.md](ROADMAP.md): the plan, what's done and what's next
- [TESTING.md](TESTING.md): what to check in game, and the results
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [LISTING.md](LISTING.md): the CurseForge and Wago page text
- [DEPLOY.md](DEPLOY.md): installing on the test PC, and releases
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
