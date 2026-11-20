# Deploying lecdm

Lecdm is a WoW: Forever addon: it runs in the player's game client, not on a server. The
source is `addohm/lecdm` on GitHub, branch `main`. Code is written and tested here (the
automated tests run against a fake client); it's tried in game on the owner's Windows PC.

## First-time setup

On the Windows PC:

1. `git clone https://github.com/addohm/lecdm.git` somewhere.
2. Check `WOW` at the top of `tools\install_forever.cmd` (default
   `C:\Program Files (x86)\World of Warcraft\_forever_`).
3. Run `tools\install_forever.cmd` from a terminal, then fully restart the game.

## Shipping a change

1. The change is committed and pushed to `main` here (tests pass first).
2. On the PC, run `tools\install_forever.cmd`. It:
   - pulls (`--ff-only`); if GitHub's history was rewritten, it prints the two commands that
     move the copy onto it;
   - mirrors `Lecdm\` into `<WOW>\Interface\AddOns\Lecdm`;
   - writes the commit into the installed `Build.lua` ("-dirty" with uncommitted changes);
   - packs `Lecdm-<version>.zip` from the last commit on the desktop;
   - says whether a full restart is needed (the `.toc` changed) or `/reload` will do.
3. In game, `/lecdm help` shows the build.

Rolling back: check out an older commit in the PC's copy and run the script's copy steps, or
ask for a revert commit on `main` and run the script.

## Releases

None yet. Releases will follow the owner's other addons: `## Version` bumped, CHANGELOG moved
under the version, `tools/make_release.py` builds `release/Lecdm-<version>.zip` from the
committed folder (no build stamp, no LICENSE), the zip is committed, the commit tagged
`v<version>`, and the zip published on both CurseForge and Wago with LISTING.md's text.

## Configuration

No server settings. In game, Lecdm keeps its settings and log in the saved variable `LecdmDB`
(`WTF\Account\<account>\SavedVariables\Lecdm.lua`).

## Troubleshooting

- `/lecdm help` shows the build: check it's the one you just installed before reading a log.
- `/lecdm log` shows the log, ready to copy.
- Lua errors: `/console scriptErrors 1`.
