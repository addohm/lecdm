# lecdm

Lecdm is a WoW: Forever addon that makes Blizzard's Cooldown Manager better and simpler to
manage: bars of your cooldowns, buffs and procs, laid out and styled your way from one window,
with sounds and glows that work in combat. The plan is in [ROADMAP.md](ROADMAP.md).

**Status:** test build 1 (0.0.1-dev). It doesn't show bars yet: it checks, in game, what the
plan relies on. [TESTING.md](TESTING.md) has what to try. The options window and profiles are
in; the Bars, Buffs and Alerts tabs say what's coming.

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

## Usage (test build 1)

`/lecdm` (or `/lcdm`), the minimap button, the addon menu by the minimap, or Options > AddOns >
Lecdm opens the options window:

- **General:** Enable Lecdm, the minimap button, the login reminder, a class-coloured window,
  Reset all settings, the chat commands.
- **Bars, Buffs, Alerts:** not built yet; each says what's coming.
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
| `/lecdm on` / `off` | Turn Lecdm on or off |
| `/lecdm help` | The commands, and the build |
| `/lecdm status` | Is Blizzard's Cooldown Manager available, what it lists, what's listened to |
| `/lecdm list` | Every entry Blizzard's Cooldown Manager lists for you, by section |
| `/lecdm check` | What an addon can read about your spells right now (try it in combat) |
| `/lecdm sound` | Sound on/off when a tracked buff drops (on by default: raid warning) |
| `/lecdm icons` | Test icons on/off (on by default) |
| `/lecdm move` | Drag the test icons; again to lock them |
| `/lecdm blizz hide` / `show` | Make Blizzard's cooldown viewers invisible, or bring them back (a test) |
| `/lecdm host on` / `off` | Place Blizzard's buff icons and bars in a row Lecdm controls (a test; `/reload` after off) |
| `/lecdm log` | The log in a window, ready to copy; `/lecdm log clear` empties it |

What it does on its own:

- **Listens to Blizzard's Cooldown Manager.** Whenever it notices a tracked buff applied or
  removed, or a spell going on cooldown, the log says so (buffs in chat too), and a raid warning
  plays when a tracked buff drops. It only listens; it changes nothing in the Cooldown Manager.
- **Logs proc glows** (Overpower, Revenge, Clearcasting ...).
- **Test icons:** one per learned spell in Blizzard's Essential and Utility sections, with a
  swipe and countdown, grey on cooldown, dark when you can't cast it.

## Docs

- [ROADMAP.md](ROADMAP.md): the plan, what's done and what's next
- [TESTING.md](TESTING.md): what to check in game, and the results
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): installing on the test PC, and releases
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
