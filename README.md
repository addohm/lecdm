# lecdm

Lecdm is a WoW: Forever addon that makes Blizzard's Cooldown Manager better and simpler to
manage: bars of your cooldowns, buffs and procs, laid out and styled your way from one window,
with sounds and glows that work in combat. The plan is in [ROADMAP.md](ROADMAP.md).

**Status:** 0.1.0-dev, not released. The icon bars are in (tried in game 2026-11-21), and the
buffs' parts 1 and 3: buff groups, and Blizzard's icons and timer bars taken in (not tried in
game yet); then "keep up" buffs, looks and alerts. Test build 1's checks are still on the Test build tab.
[TESTING.md](TESTING.md) has what to try.

## Getting started

You need git and the WoW: Forever client on Windows.

1. Clone the repo:

   ```sh
   git clone https://github.com/addohm/lecdm.git
   ```

2. Check `WOW` at the top of `tools\install_forever.cmd`. It defaults to
   `C:\Program Files (x86)\World of Warcraft\_forever_`.
3. Run `tools\install_forever.cmd` from a terminal. It pulls, copies `Lecdm` into the client's
   `Interface\AddOns`, stamps the build, and packs `Lecdm-<version>.zip` on your desktop.
4. Fully restart the game the first time (and whenever the script says so); otherwise `/reload`.
   `/lecdm help` shows the build you're running.

## Usage

`/lecdm` (or `/lcdm`), the minimap button, the addon menu by the minimap, or Options > AddOns >
Lecdm opens the options window:

- **General:** Enable Lecdm, the minimap button, the login reminder, a class-coloured window,
  Reset all settings, the chat commands.
- **Icon bars:** your cooldowns in rows of icons. The dropdown at the top picks an icon bar,
  and its last entry, "New icon bar...", makes one (it asks for a name). Below it, everything
  is about the bar picked:
  - its name and layout (icon size, spacing, grow from, vertical, icons per row, the GCD sweep);
  - its look: border and border colour, icon zoom, countdown text size, keybind text (from any
    bar addon's buttons), grey on cooldown, red out of range, dark when unusable;
  - when it shows: always, only in combat, or in combat or with a target; its opacity, and out
    of combat the same, faded or hidden; and Delete;
  - its spells and items: tick them in the checklist (Blizzard's Essential and Utility lists,
    your spellbook, your equipped trinkets and on-use gear, and usable items in your bags such
    as potions and healthstones; an entry on another icon bar says "(on ...)" and ticking moves
    it), order them with the arrows, and choose when each shows: always, only when ready, or
    only on cooldown. A trinket slot shows whatever's equipped there while it has a use effect;
    a bag item shows its count; "Items you have none of" hides it then, or shows it greyed
    with a 0.

  Unlock to drag the icon bars. Blizzard's own Essential and Utility icons are made invisible
  while Lecdm's icon bars are on; untick "Hide Blizzard's Essential and Utility icons" to keep
  them. (Timer bars, Blizzard's "tracked bars", come with the buffs.)
- **Buffs:** buffs on you, from anyone (your own, another priest's Fortitude, world buffs),
  while they're up, in buff groups. Laid out like Icon bars: the dropdown picks a buff group
  ("New buff group..." makes one); below it, its name, **Show as** icons (a swipe and the time
  left) or **timer bars** (the icon, then a bar draining to the right with the name and the
  time left), its look, Delete, and its buffs: tick them from your buffs in Blizzard's list or
  from the buffs on you now (out of combat), and order them with the arrows. Its look: border,
  icon zoom, time text size; timer bars also texture, colour (class colour among them),
  background, and the icon, name and time each on or off. When it shows: as for icon bars. Every rank of a
  buff, whoever cast it, is learned the first time Lecdm sees it on you out of combat.
  Changes made in combat apply when it ends.

  The dropdown also has **Blizzard's icons** and **Blizzard's timer bars**: what Blizzard's
  Cooldown Manager tracks in its Buffs tab, your debuffs on the target among them (only Blizzard
  can time those). For each: **take them into Lecdm** (the default: they sit in Lecdm's own
  place, which you drag with the rest, spaced and grown your way, gaps closed, following each
  target), **hide them**, or **leave them** where Blizzard shows them. Which ones, and their
  order, are picked in `/cdm` (Tracked Buffs for icons, Tracked Bars for timer bars; "Open
  /cdm" is right there); their size is Edit Mode's. When they show, as for icon bars.
- **Alerts:** the sounds and glows every spell and buff gets, unless it has its own (the ⚙ on
  its row on the Icon bars and Buffs tabs: a submenu per setting, "Default (...)" first).
  Sounds are the game's (raid warning, ready check, alarm clock ...) or "Say it", which speaks
  the name.
  - Icon bars: a sound when it's ready (off cooldown, not the GCD), a glow while it's ready and
    usable, a glow while the game highlights it (a proc); glow colour.
  - Buff groups: sounds when it's applied and when it drops (in combat only for buffs Blizzard's
    `/cdm` also tracks; out of combat for every buff on you), a glow while it's up, the time
    turning red under a few seconds, and a warning glow then (icons; it needs the buff's full
    duration, learned the first time Lecdm sees it on you out of combat).
  - Blizzard's icons and timer bars: sounds when it's applied and when it drops, quiet when your
    target dies unless "Also when your target dies".
- **Test build:** test build 1's settings and tools (the same as its chat commands below), and
  where its debug lines go: "Show them in" the main chat window, a chat tab you've made (say
  one named Lecdm: right-click a chat tab, Create New Window), or nowhere (the log keeps them).
  Replies to your commands and errors always use the main chat.
- **Profiles:** each character starts with its own ("First Last"); pick another to share it,
  copy, rename, delete, reset, or switch automatically by your talents or group role.

Chat commands:

| Command | What it does |
|---|---|
| `/lecdm` | Open or close the options window |
| `/lecdm general` ... `profiles` | Open that tab (`bars`, `buffs`, `alerts`, `test` too) |
| `/lecdm profile` | The profile in use, and the Profiles tab |
| `/lecdm minimap` | Show or hide the minimap button |
| `/lecdm move` | Unlock the icon bars and buff groups to drag them; again to lock them |
| `/lecdm on` / `off` | Turn Lecdm on or off |
| `/lecdm help` | The commands, and the build |
| `/lecdm status` | Is Blizzard's Cooldown Manager available, what it lists, what's listened to |
| `/lecdm list` | Every entry Blizzard's Cooldown Manager lists for you, by section |
| `/lecdm check` | What an addon can read about your spells right now (try it in combat) |
| `/lecdm blizz hide` / `show` | Make Blizzard's cooldown viewers invisible, or bring them back (a test) |
| `/lecdm log` | The log in a window, ready to copy; `/lecdm log clear` empties it |

What it does on its own:

- **Listens to Blizzard's Cooldown Manager.** Whenever it notices a tracked buff applied or
  removed, or a spell going on cooldown, the log says so (and the alerts hear it). It only
  listens; it changes nothing in the Cooldown Manager.
- **Logs proc glows** (Overpower, Revenge, Clearcasting ...).

## Docs

- [ROADMAP.md](ROADMAP.md): the plan, what's done and what's next
- [TESTING.md](TESTING.md): what to check in game, and the results
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): installing on the test PC, and releases
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
