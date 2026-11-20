# CLAUDE.md

Orientation for Claude working on lecdm. Read this first.

## What this is

A new, empty project: as of 2026-11-20 the repo (`addohm/lecdm`) holds only
the standard docs. Nothing is decided yet about what it does; ask the owner
before writing code, and record the answers here and in README.md.

## Layout

- `README.md`, `CHANGELOG.md`, `DEPLOY.md`, `SECURITY.md`, `ROADMAP.md`:
  the standard docs
- `CLAUDE.md`: this file

No code folders yet; list them here as they're added.

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
   - this file: when the layout, workflow or conventions change
4. Run the checks (TODO: none yet; add the lint and test commands with the
   first code), then commit.

## Conventions

- Dates in the docs are absolute (2026-11-20), never "today" or "last week".
- CHANGELOG entries go under *Unreleased* in Keep a Changelog style.

TODO: coding style and naming, once the language is chosen.

## Don't

- Commit secrets (`.env`, keys, tokens).
