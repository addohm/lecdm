# CLAUDE.md

Orientation for Claude working on lecdm. Read this first.

## What this is

Lecdm is a WoW: Forever addon (Interface 16001: the modern client with the Midnight "secret
values" addon API, running Classic level-60 content) that makes Blizzard's Cooldown Manager
better and simpler to manage. The plan, agreed on 2026-11-20, is in ROADMAP.md: "Blizzard
knows, Lecdm shows", with three engines (the Cooldown Manager's list and its announcements, the
spell API, aura containers) feeding Lecdm's own bars, all managed from one Lecdm window.
The remote is `addohm/lecdm` on GitHub (`origin`, branch `main`).

It stands on its own. leboof and leproc (the owner's other addons) are reference material only,
for what's proven on Forever and for house style; nothing is left out of Lecdm because they do
something similar. EllesmereUI's Cooldown Manager is the feature reference: it's "all rights
reserved", so ideas only, never its code, and it's never named in the addon or its docs for
players.

Now: 0.1.0-dev. Test build 1 (in game, 2026-11-20) confirmed what the plan relies on
(TESTING.md); the cooldown bars are the first real feature.

## Layout

- `Lecdm/`: the addon (what players copy into `Interface\AddOns`). `Lecdm.toc` sets the load
  order and holds `## Version`, the only version source.
  - `Build.lua`: build stamp, empty in the repo; the install script writes the commit into it.
  - `Core.lua`: the defaults (`ns.DEFAULTS`: enabled, loginMessage, classColour, window, minimap,
    test), `ns.Print`, `ns.IsSecret` / `ns.Show` (secret-safe text), `ns.Where`,
    `ns.Version(withBuild)`, `ns.Enabled` / `ns.SetEnabled`, `ns.Refresh()` (the bars, theme,
    minimap button and window follow `ns.db`), `ns.ResetAll()`, the login message, `/lecdm`.
  - `Profiles.lua`: profiles, in the owner's house style. `LecdmDB.profiles[name]` holds every
    setting; `LecdmDB.chars["First Last"]` is the profile each character uses (`P.CharKey`:
    UnitName's second value is the surname on Forever; no realm); `ns.db` is the one in use.
    Switching by talents or role: `LecdmDB.auto["First Last"]`. Init also moves 0.0.1's flat
    settings (`sound`, `icons`, `pos`) into the profile's `test` table once.
  - `Log.lua`: `ns.Log(text, toChat)` into `LecdmDB.log` (account-wide, last 500), and the copy
    window (`LecdmLog`).
  - `Catalogue.lua`: Blizzard's list through `C_CooldownViewer` (`ns.Catalogue.byID` by cooldown
    ID, `.bySpell`, `.sections`, `.Spells(sections, all)`, `.Name(cooldownID)`), `/lecdm list`.
    It gives Blizzard's default sections, not where the player put things in `/cdm`.
  - `Bars.lua`: the cooldown bars (`ns.db.bars`: `list` of bars, each `{ id, name, spells =
    { spellID ... }, show = { [spellID] = "ready" | "cooldown" }, size, gap, grow, vertical,
    perRow, gcd, pos }`; `seeded`, `nextID`, `hideBlizzard`). `B.Build()` (frames, buttons,
    seeding from Blizzard's list once per profile), `Update` (one icon: swipe from the duration
    object, grey, dark, red; returns whether it shows), `Layout` (closes gaps), `B.UpdateAll` /
    `B.UpdateSpell` on events, `B.SetOnBar`, `B.MoveSpell`, `B.NewBar`, `B.Delete`,
    `B.StartOver`, `B.SetUnlocked`, `B.ApplyBlizzard`, `B.Spellbook()` (spells with a cooldown,
    by skill line, for the checklist), `B.Known`.
  - `Listen.lua`: hooks `OnAcquireItemFrame` on the four viewers and `TriggerAlertEvent` on each
    icon (weak table of hooked icons), logs what the Cooldown Manager announces (with the
    target's state on "removed"), the raid warning on "removed"; proc glow events, blocked
    actions and the first swings of each fight. `L.ActiveItems(viewer)`.
  - `Check.lua`: `/lecdm check` (what's readable about the Essential/Utility spells and trinket
    slots now, into the log) and `/lecdm status`.
  - `Blizz.lua`: `/lecdm blizz hide|show`, the invisible-viewers test, and `/lecdm host on|off`,
    the hosting test (Blizzard's Buffs/Bars viewer icons re-placed into a Lecdm row after each
    `RefreshLayout`/`Layout`, counted). Both are tests only: they move or fade Blizzard frames.
  - `UI/Theme.lua`, `UI/Widgets.lua` (option rows and `UI.Stack`), `UI/Window.lua` (the options
    window `LecdmFrame`: tabs, Defaults, resize grip; pages register with `ns.Window.Page`; the
    Options > AddOns entry), `UI/Minimap.lua` (`LecdmMinimapButton`, angle 350, the addon
    compartment): the owner's house code, from leproc.
  - `UI/Pages/`: `General.lua`, `Bars.lua` (the Icon bars tab: a `DropdownButton` picks the
    bar, its "New icon bar..." entry opens the `LECDM_NEW_BAR` popup with a name box; below,
    only the bar picked: name field, look, Delete, then the spell checklist (MenuUtil) and a
    row per spell rebuilt each refresh with `UI.Stack` Reset/Add/Done), `Soon.lua` (Buffs, Alerts: what's coming), `Test.lua` (test
    build 1's settings and tools), `Profiles.lua`.
- `tools/install_forever.cmd`: pulls (and explains a rewritten history), copies the addon into
  the Windows client, stamps the build, packs `Lecdm-<version>.zip` on the desktop. Keep it CRLF
  (`.gitattributes`).
- `tools/make_release.py`: `release/Lecdm-<version>.zip` from the committed `Lecdm/` folder.
- `tests/`: `wowmock.lua` (a fake client: viewers with item pools, a secret value that errors
  when misused, enough UI for the window), `smoke.lua` (scenarios), `run_tests.py`.
- `TESTING.md`: what to check in game, and what's been confirmed.
- Reference material, outside the repo:
  - Blizzard's Forever UI source (Gethe/wow-ui-source, `forever` branch, sparse):
    `/srv/claude/workspaces/_wfscratch/lecdm/ui`.
  - EllesmereUI v9.9.1: `/srv/claude/workspaces/_wfscratch/eui/src`; notes on its Cooldown
    Manager in `/srv/claude/workspaces/_wfscratch/lecdm/notes/`.

## Workflow

1. Start from the latest: pull before changing anything.
2. Make the change with tests.
3. **Update the docs in the same commit.** Every change updates the docs it
   affects:
   - README.md: setup and usage
   - CHANGELOG.md: an entry under *Unreleased*
   - DEPLOY.md: when deploying or running it live changes
   - SECURITY.md: when secrets, access or permissions change
   - ROADMAP.md: when something on it is done, or new plans are made
   - TESTING.md: what needs checking in game, and results the owner reports
   - this file: when the layout, workflow or conventions change
4. Run the checks: `.venv/bin/python tests/run_tests.py` (set up with
   `python3 -m venv .venv && .venv/bin/pip install lupa`). Then commit and push, and say
   "Pushed: <commit>" so the owner can run the install script.
5. Discuss before building: changes need the owner's go-ahead.

## Conventions

- Lua 5.1, no libraries. Every file starts `local _, ns = ...`; shared state lives on `ns`.
  Globals only from the list in `tests/run_tests.py`.
- **Secret values:** never compare, concatenate, index or even test one for nil. Ask
  `ns.IsSecret` first; `ns.Show` gives text for any value. Wrap game calls that may refuse in
  `pcall`.
- **Blizzard's Cooldown Manager is read-only.** Never write its data, its frames' fields, Edit
  Mode layouts or its CVars; never call its refresh methods; no forced reloads. Listen with
  `hooksecurefunc`; keep per-frame state in weak tables. Identify an icon by its cooldown ID read
  when needed: icons are pooled and reused. Two exceptions, both confirmed harmless in game:
  while Lecdm's bars are on, the Essential and Utility viewers get alpha 0 (never `Hide()`,
  which stops their events; set again after Edit Mode and loading screens, not fought), and
  the host test re-places Buffs/Bars viewer icons into a Lecdm row.
- **A two-value call only passes both values when it's last** in an argument list: give
  getter/setter pairs their own locals (UI/Pages/Bars.lua).
- Events, not timers or retry ladders.
- The version alone in any UI; the build only in chat (login line, `/lecdm help`).
- New settings go in `ns.DEFAULTS` (so in every profile); only the log and `welcomed` are
  account-wide. A setting change calls `ns.Refresh()`.
- Example names in docs and tests are made up ("Brenna Ashford").
- **Words players see:** ours are "icon bars" (the code and settings say `bars`); Blizzard's
  tracked bars are "timer bars". Don't put two look-alike controls side by side (the owner
  confused New and Rename): creating lives in the picker, renaming is the bar's own field.
- Dates in the docs are absolute (2026-11-20), never "today" or "last week".
- CHANGELOG entries go under *Unreleased* in Keep a Changelog style.
- Check APIs against Blizzard's Forever source (path above) and its
  `Blizzard_APIDocumentationGenerated` flags (`SecretWhen...`, `NeverSecret`,
  `SecretArguments`, `HasRestrictions`).

## Don't

- Commit secrets (`.env`, keys, tokens).
- Copy code from other addons, or name them in the addon or its player docs.
