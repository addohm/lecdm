# Security

## Reporting a problem

TODO: who to tell, and how (an email address?). Please don't open a public
issue for a vulnerability.

## Secrets

None: Lecdm is a game addon with no keys or accounts. If secrets are ever added, list each one
here by name (never its value), where it lives and how to rotate it. Never commit them.

## Access

- Source: `addohm/lecdm` on GitHub, owned by addohm. Claude's workspace
  pushes with a per-repo deploy key (`deploy-ws-lecdm`).
- No production: the addon runs in each player's game client.
- In game, Lecdm only reads and displays. It doesn't call protected functions, and it never
  writes Blizzard's Cooldown Manager data or Edit Mode layouts.

TODO: is the repo public or private, and does anyone else get push access?
