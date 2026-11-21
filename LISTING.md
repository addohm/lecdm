# Lecdm: CurseForge and Wago listing

Copy-paste material for the project pages. Placeholders are in [brackets]. Keep the feature list
in step with README.md.

---

## Basics

| Field | Value |
| --- | --- |
| Name | Lecdm |
| Slug | `lecdm` |
| Game version | WoW: Forever (Interface 16001) |
| Author | addohm |
| License | [choose: All Rights Reserved, MIT, GPLv3 ...] |
| Source | [https://github.com/addohm/lecdm, if the repo is public] |
| Issues | [https://github.com/addohm/lecdm/issues, if public] |

**Images**
- Avatar: `art/lecdm-icon-400.png`
- Banner / header: `art/lecdm-banner.png` (1600x500)

**Categories**
- CurseForge: Combat (main), Buffs & Debuffs, Action Bars, Audio & Video
- Wago: Combat (main), Buffs & Debuffs

**Summary** (the one-liner under the name)

> Blizzard's Cooldown Manager, made better and simple: your cooldowns, buffs and target debuffs
> in bars you lay out, with sounds and glows that work in combat.

**Short tagline** (for images or a Discord post)

> Your cooldowns and buffs, your way.

---

## Description

*(Paste as Markdown. Both sites accept it.)*

### Lecdm

**Blizzard's Cooldown Manager, made better and simpler to manage, for WoW: Forever.**

Blizzard's Cooldown Manager knows things no addon can see in combat. Lecdm builds on what it
knows instead of fighting it: your cooldowns, your buffs from anyone, and your debuffs on the
target, laid out and styled your way from one window. No trips to Edit Mode, no forced reloads,
no reading what the game hides.

**This is an alpha.** It works, it's tested in the open world and in dungeons for its core, and
plenty is still to come. Reports of anything wrong or missing are very welcome.

#### Icon bars: your cooldowns

- As many icon bars as you like; two are made for you from Blizzard's own list for your class.
- Each icon: the cooldown swipe and countdown, grey on cooldown, a short GCD sweep (or none),
  dark while you can't use it, red while your target is out of range.
- Per spell: always shown, only when ready, or only on cooldown, and the others close up.
- Add spells from a checklist: Blizzard's list, your spellbook, your trinkets and on-use gear,
  and potions, healthstones and other usable items in your bags (with the count).
- Per bar: icon size, spacing, grow from the centre or an edge, vertical, icons per row,
  border and colour, icon zoom, countdown text size, keybind text (from any bar addon).

#### Buffs: yours, everyone's, and your target's

- **Buff groups** show any buff on you, whoever cast it (another priest's Fortitude, world
  buffs, procs), while it's up, as **icons** or **timer bars**.
- **Keep up** buffs get a fixed place: a dimmed red copy with a glow while you're missing it.
- **Only what you set up shows:** Blizzard's own icons and timer bars are hidden. If you want
  your debuffs on the target (only Blizzard can time them), Lecdm can take Blizzard's in, into
  its own places, following each target.
- Timer bars: texture, colour (class colour too), background, icon, name and time each on or off.

#### Alerts

- Sounds when a spell is ready, when a buff is applied, and when it drops; from the game's
  sounds or "Say it" (the spell's name, spoken).
- Glows while a spell is ready, while the game highlights it (a proc), while a buff is up, as
  a buff runs out (timed by the game, in combat too), and while a keep-up buff is missing.
- Seven glow styles in eleven colours or your class colour.
- Quiet when a mob dies with your debuffs on it.
- Defaults for everything, and each spell or buff can have its own.

#### When it shows

- Every icon bar, buff group and Blizzard place: always, only in combat, or in combat or with a
  target; its opacity; faded or hidden out of combat.

#### Profiles

- Every setting is in a profile, one per character by default ("First Last"); share one between
  characters, copy, rename, delete, reset, or switch by your talents or group role.

#### Commands

| Command | |
| --- | --- |
| `/lecdm` | Open or close the options window |
| `/lecdm move` | Unlock everything to drag it; again to lock |
| `/lecdm bars`, `buffs`, `alerts`, `profiles` | Open that tab |
| `/lecdm status`, `check`, `log` | Diagnostics |
| `/lecdm help` | All commands |

The minimap button and the game's addon menu by the minimap open the options too.

#### Good to know

- **Does it read what the game hides in combat?** No. Spells' cooldown state is never hidden,
  and the game draws the swipes; Blizzard's aura containers and Blizzard's Cooldown Manager do
  the knowing for buffs; Lecdm says what and where.
- **Which debuffs on the target**, and their order, are picked in Blizzard's Cooldown Manager
  (`/cdm`, its Buffs tab): only Blizzard can time them. Lecdm has a button to open it.
- **In-combat sounds for buffs** come from Blizzard's Cooldown Manager's announcements, so they
  need the buff tracked there too; out of combat Lecdm sees every buff on you.
- No libraries, no automation: display and sound only.

---

## Screenshots to take

1. Two icon bars in combat: a spell on cooldown (grey, swiping), one glowing ready, one red out
   of range, keybind text on.
2. A buff group as timer bars next to Blizzard's timer bars taken in (Sunder Armor, Thunder Clap
   on the target).
3. A keep-up buff missing: its red copy and glow.
4. The Icon bars tab with the "Add or remove spells" checklist open.
5. The Alerts tab, and a spell's ⚙ menu.
6. Everything unlocked (the blue shades) being moved.

---

## Release notes

### 0.9.0-alpha (2026-11-21)

The first alpha: icon bars (spells, trinkets, on-use gear, bag items), buff groups (icons or
timer bars, keep-up buffs with a missing look), Blizzard's icons and timer bars taken in,
alerts (sounds, "Say it", glows), looks and visibility for all of them, profiles, and
diagnostics.
