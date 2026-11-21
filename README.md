# lecdm

Lecdm is a WoW: Forever addon that makes Blizzard's Cooldown Manager better and simpler to
manage: bars of your cooldowns, buffs and procs, laid out and styled your way from one window,
with sounds and glows that work in combat. The plan is in [ROADMAP.md](ROADMAP.md).

**Status:** 0.1.0-dev, not released. The icon bars are in (tried in game 2026-11-21); buffs
and alerts come next. Test build 1's checks are still on the Test build tab.
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
  - its name, look (icon size, spacing, grow from, vertical, icons per row, the GCD sweep) and
    Delete;
  - its spells: tick them in the checklist (Blizzard's Essential and Utility lists, and your
    spellbook; a spell on another icon bar says "(on ...)" and ticking moves it), order them
    with the arrows, and choose when each shows: always, only when ready, or only on cooldown.

  Unlock to drag the icon bars. Blizzard's own Essential and Utility icons are made invisible
  while Lecdm's icon bars are on; untick "Hide Blizzard's Essential and Utility icons" to keep
  them. (Timer bars, Blizzard's "tracked bars", come with the buffs.)
- **Buffs, Alerts:** not built yet; each says what's coming.
- **Test build:** test build 1's settings and tools (the same as its chat commands below).
- **Profiles:** each character starts with its own ("First Last"); pick another to share it,
  copy, rename, delete, reset, or switch automatically by your talents or group role.

Chat commands:

| Command | What it does |
|---|---|
| `/lecdm` | Open or close the options window |
| `/lecdm general` ... `profiles` | Open that tab (`bars`, `buffs`, `alerts`, `test` too) |
| `/lecdm profile` | The profile in use, and the Profiles tab |
| `/lecdm minimap` | Show or hide the minimap button |
| `/lecdm move` | Unlock the icon bars to drag them; again to lock them |
| `/lecdm on` / `off` | Turn Lecdm on or off |
| `/lecdm help` | The commands, and the build |
| `/lecdm status` | Is Blizzard's Cooldown Manager available, what it lists, what's listened to |
| `/lecdm list` | Every entry Blizzard's Cooldown Manager lists for you, by section |
| `/lecdm check` | What an addon can read about your spells right now (try it in combat) |
| `/lecdm sound` | Sound on/off when a tracked buff drops (on by default: raid warning) |
| `/lecdm blizz hide` / `show` | Make Blizzard's cooldown viewers invisible, or bring them back (a test) |
| `/lecdm host on` / `off` | Place Blizzard's buff icons and bars in a row Lecdm controls (a test; `/reload` after off) |
| `/lecdm log` | The log in a window, ready to copy; `/lecdm log clear` empties it |

What it does on its own:

- **Listens to Blizzard's Cooldown Manager.** Whenever it notices a tracked buff applied or
  removed, or a spell going on cooldown, the log says so (buffs in chat too), and a raid warning
  plays when a tracked buff drops. It only listens; it changes nothing in the Cooldown Manager.
- **Logs proc glows** (Overpower, Revenge, Clearcasting ...).

## Docs

- [ROADMAP.md](ROADMAP.md): the plan, what's done and what's next
- [TESTING.md](TESTING.md): what to check in game, and the results
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): installing on the test PC, and releases
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
