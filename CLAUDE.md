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

Now: 0.9.0-alpha (2026-11-21), the first alpha: icon bars, buff groups, Blizzard's icons
taken in, alerts, looks and visibility, profiles, diagnostics. Test build 1 (in game,
2026-11-20) confirmed what the plan relies on (TESTING.md).

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
    window (`LecdmLog`). `toChat` lines are the test build's debug output: `ns.Debug(line)`
    sends them where `ns.db.test.chat` says ("main", a chat tab's name from `ns.ChatTabs()`,
    or "off"). Replies to commands and real errors use `ns.Print` (always the main chat).
  - `BuffList.lua`: Lecdm's own list of buffs (`ns.BuffList.sections`, `.byName`, `.Entry`,
    `.Names`, `.IsFor(e, class, race)`): entries `{ name, other names..., class, race, castBy,
    warn, note }`; `BuffData.lua` (generated: `ns.BuffIDs[name]`, every spell ID with that name,
    from `tools/gen_data.py`; run it after changing names in BuffList.lua).
  - `Catalogue.lua`: Blizzard's list through `C_CooldownViewer` (`ns.Catalogue.byID` by cooldown
    ID, `.bySpell`, `.sections`, `.Spells(sections, all)`, `.Name(cooldownID)`), `/lecdm list`.
    It gives Blizzard's default sections, not where the player put things in `/cdm`.
  - `Glow.lua`: the owner's glow styles (`Glow.STYLES`, `Glow.COLORS`, `Glow.Build`, `Glow.Show`):
    textures and Alpha/Translation/Rotation/FlipBook animations only.
  - `Visibility.lua`: `V.Alpha(cfg)` from `showWhen` / `alpha` / `oocAlpha` (bars, groups,
    Blizzard's places), `V.Apply()` on combat and target changes (opacity only).
  - `Keybinds.lua`: action buttons from any bar addon (EnumerateFrames, out of combat, one scan
    per frame), the key of the first one on screen holding a spell or item (its HotKey text,
    else its click binding), `K.For(name)`.
  - `Alerts.lua`: sounds (`A.SOUNDS`, `A.Play`: SOUNDKIT names or "say", text to speech) and
    when they play; `ns.db.alerts`: `defaults.spells / .buffs / .blizzard` and each spell's
    (`spells[key]`) or buff's (`buffs[name]`, `blizzard[name]`) own (`A.Get`, `A.Set`,
    `A.HasOwn`). `A.OnIcon` (Bars.lua calls it per icon: the ready sound on the change off
    cooldown, the ready / proc glow on `b.glow`), `A.OnAnnounced` (Listen.lua: Blizzard's
    applied / removed; a target aura's removal waits a frame and is quiet if the target is
    gone), `A.OnBuffsRead` (Auras.lua, out of combat: buffs that came or went, unless Blizzard
    announced them within a second). `A.Warn(name)` (the warning time; "auto" is a tenth of the
    learned duration). Running out: a `C_Timer.NewTimer` per buff to its warning time, from its
    expiration read out of combat or your own cast (`UNIT_SPELLCAST_SUCCEEDED`) with the learned
    duration; quiet in combat when someone of the buff's `castBy` class (else yours) is grouped;
    stopped by Blizzard's "removed"; `A.Reschedule()` on each `ns.Refresh()`. Going into combat: the keep-up buffs
    missing at the last look (`combatMissing`, `combatChat`).
  - `Bars.lua`: the icon bars (`ns.db.bars`: `list` of bars, each `{ id, name, spells =
    { key ... }, show = { [key] = "ready" | "cooldown" }, size, gap, grow, vertical, perRow,
    gcd, pos }`; `seeded`, `nextID`, `hideBlizzard`). A key is a spellID (number), `"slot:N"`
    (an equipment slot: what's equipped there, shown while it has a use effect) or
    `"item:ID"` (a bag item, shown while you have one, with the count): `B.Kind`,
    `B.EntryName`, `B.EntryIcon`, `B.EntryKnown`, `B.Missing`, `B.ItemOf`, `B.Equipped()`,
    `B.BagItems()`. Spells draw from duration objects (`SpellState`); items from plain numbers
    with `Cooldown:SetCooldown` (`ItemState`: item cooldowns aren't secret). `B.Build()` (frames, buttons,
    seeding from Blizzard's list once per profile), `Update` (one icon: swipe from the duration
    object, grey, dark, red; returns whether it shows), `Layout` (closes gaps), `B.UpdateAll` /
    `B.UpdateSpell` on events, `B.SetOnBar`, `B.MoveSpell`, `B.NewBar`, `B.Delete`,
    `B.StartOver`, `B.SetUnlocked`, `B.ApplyBlizzard`, `B.Spellbook()` (spells with a cooldown,
    by skill line, for the checklist), `B.Known`.
  - `Auras.lua`: the buff groups (`ns.db.buffs`: `list` of groups `{ id, name, style =
    "icons" | "bars", entries = { buff name ... }, size, gap, grow, vertical, perRow, barWidth,
    pos }`; `seeded`, `nextID`). One aura container per group (`CustomAuraContainerTemplate`,
    unit player), one aura group per entry (key `"<name>/<style>:<size>:<width>"`, layoutIndex =
    its place; a changed look makes new keys, old ones disabled). `Styler(group)` builds a
    button's parts (icons: swipe, time, stacks; bars: icon, StatusBar via `SetDurationBar`,
    `SetSpellName`, time, stacks). `A.IDs(name)`: learned + Blizzard's list + the spell's own;
    `A.ReadBuffs()` (out of combat only) and learning on `UNIT_AURA`; `A.Build()` waits for the
    end of combat (`pending`). `A.BlizzardBuffs()` (selfAura entries), `A.SetInGroup`,
    `A.MoveEntry`, `A.NewGroup`, `A.Delete`, `A.StartOver`. Modes (`group.modes[name]`: "up",
    "keep", "missing"; `A.Mode`, `A.SetMode`): keep-up buffs get an aura slot in the group's
    `keep` container at a fixed place, and keep / missing ones a presence container (one
    invisible 1 px button sized by the game) with the copy (`StyleCopy`: `missingLook` red,
    normal or grey, `missingAlpha`) and missing glow clipped to its edge (`PlaceMissing`); while
    up, a button's face has `upAlpha` / `upGrey`, an icon revealed at the warning time
    (`AddTimedGlow`'s reveal); the rest flow in the group's container after them. Weapon
    enchants (`A.EnchantSlot`, BuffList's `enchant`) always have a fixed place: the game's
    button in a container of their own per look (`AddItemEnchantment`, `hidePermanent`), the
    presence container by item enchantment; `A.ReadEnchants()` (out of combat,
    `GetWeaponEnchantInfo`) feeds the alerts with the buffs.
  - `Hosted.lua`: Blizzard's icons and timer bars, hidden by default (the owner: Lecdm shows
    only what the player sets up; profiles from 0.9.0-alpha switch once, `hiddenByDefault`),
    or taken in (`ns.db.buffs.blizzard.icons` / `.bars`: `mode` "hide" | "take" | "leave", `gap`, `grow`, `vertical`, `perRow`, `pos`).
    In "take", each item of the BuffIcon / BuffBar viewer is anchored into Lecdm's place
    (`Layout`, in Blizzard's layoutIndex order, hidden ones skipped, offsets converted by
    effective scale), after each `RefreshLayout` / `Layout` of the viewer and each item's
    `UpdateShownState` (hooks). `H.WantsHidden(global)` for `B.ApplyBlizzard`,
    `H.OpenBlizzard()` (CooldownViewerSettings:TogglePanel, out of combat).
  - `Listen.lua`: hooks `OnAcquireItemFrame` on the four viewers and `TriggerAlertEvent` on each
    icon (weak table of hooked icons), logs what the Cooldown Manager announces (with the
    target's state on "removed"), the raid warning on "removed"; proc glow events, blocked
    actions and the first swings of each fight. `L.ActiveItems(viewer)`.
  - `Check.lua`: `/lecdm check` (what's readable about the Essential/Utility spells and trinket
    slots now, into the log) and `/lecdm status`.
  - `Blizz.lua`: `/lecdm blizz hide|show`, the invisible-viewers test (a test only: not kept
    after a reload).
  - `UI/Theme.lua`, `UI/Widgets.lua` (option rows and `UI.Stack`), `UI/Window.lua` (the options
    window `LecdmFrame`: tabs, Defaults, resize grip; pages register with `ns.Window.Page`; the
    Options > AddOns entry), `UI/Minimap.lua` (`LecdmMinimapButton`, angle 350, the addon
    compartment): the owner's house code, from leproc.
  - `UI/Pages/`: `General.lua`, `Alerts.lua` (the Alerts tab's defaults, `ns.AlertsMenu` and
    `ns.AlertsGear`: a row's ⚙ context menu, `ns.ALERT_FIELDS`), `Buffs.lua` (the Buffs tab, laid out like Icon bars:
    `LECDM_NEW_BUFFS` popup, Show as, look rows shown by style, the checklist of Blizzard's
    buffs and the buffs on you now, a row per buff), `Bars.lua` (the Icon bars tab: a `DropdownButton` picks the
    bar, its "New icon bar..." entry opens the `LECDM_NEW_BAR` popup with a name box; below,
    only the bar picked: name field, look, Delete, then the spell checklist (MenuUtil) and a
    row per spell rebuilt each refresh with `UI.Stack` Reset/Add/Done), `Test.lua` (the
    Diagnostics tab, id "test": where diagnostic lines go, and the tools), `Profiles.lua`.
- `art/`: `make_logo.py` (Pillow; Inter from `.scratch/fonts`) and what it draws: the icon
  PNGs (512, 400 for the listing avatar, 256, 128), `lecdm-banner.png` (1600x500), and
  `Lecdm/Media/Icon.tga` (128 px, the TOC's IconTexture; never edit by hand).
- `LISTING.md`: the CurseForge / Wago page text; keep its feature list in step with README.md.
- `release/`: `Lecdm-<version>.zip` packages, from `tools/make_release.py`, committed with each
  release.
- `tools/install_forever.cmd`: pulls (and explains a rewritten history), copies the addon into
  the Windows client, stamps the build, packs `Lecdm-<version>.zip` on the desktop. Keep it CRLF
  (`.gitattributes`).
- `tools/make_release.py`: `release/Lecdm-<version>.zip` from the committed `Lecdm/` folder.
- `tools/gen_data.py`: `Lecdm/BuffData.lua` from wago.tools' SpellName table (product wowf,
  cached in `.scratch/` for a day; reports names with no spell).
- `tests/`: `wowmock.lua` (a fake client: viewers with item pools, a secret value that errors
  when misused, enough UI for the window), `smoke.lua` (scenarios), `run_tests.py`.
- `TESTING.md`: what to check in game, and what's been confirmed.
- Reference material, outside the repo:
  - Blizzard's Forever UI source (Gethe/wow-ui-source, `forever` branch, sparse):
    `/srv/claude/workspaces/_wfscratch/lecdm/ui`; the aura container's
    (`Blizzard_CustomAuraContainer.lua`, `Blizzard_AuraContainerShared.lua`, ...) in
    `/srv/claude/workspaces/leboof/.scratch/ui`.
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
   `python3 -m venv .venv && .venv/bin/pip install lupa pillow`; Pillow is for the art). Then commit and push, and say
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
  while Lecdm's bars are on, the Essential and Utility viewers get alpha 0, and the buff
  viewers too in "hide" mode (never `Hide()`, which stops their events; set again after Edit
  Mode and loading screens, not fought: `B.ApplyBlizzard`); and in "take" mode the buff
  viewers' icons are anchored into Lecdm's places after each of Blizzard's layouts
  (`Hosted.lua`; the host test proved it in the open world and a dungeon).
- **A two-value call only passes both values when it's last** in an argument list: give
  getter/setter pairs their own locals (UI/Pages/Bars.lua).
- Events, not timers or retry ladders.
- The version alone in any UI; the build only in chat (login line, `/lecdm help`).
- New settings go in `ns.DEFAULTS` (so in every profile). Account-wide, not settings: the log,
  `welcomed`, and what's learned about buffs (`LecdmDB.auraIDs[name]`, `LecdmDB.auraIcons`,
  `LecdmDB.auraDur`: full durations). A setting change calls `ns.Refresh()`.
- A buff group button's parts are fixed when the game makes it, so its aura group key carries
  everything they depend on: the look and the alerts (`A.AlertLook(name)`).
- **Aura containers are touched only out of combat** (their buttons are closed to addons
  while auras are secret): `ns.Auras.Build()` waits for `PLAYER_REGEN_ENABLED`.
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
