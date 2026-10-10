# Better Forever XP

![Better Forever XP logo](Brand/BetterForeverXP-CurseForge-Logo.png)

A slim, standalone experience bar for WoW Forever, by Dezolve Labs.

Better Forever XP keeps the always-visible interface compact and puts the
details one hover away. It shows exact and abbreviated XP values, rested XP,
completed-quest XP, session pace, time to level, and progress in Blizzard-style
five-percent bars. It has no external dependencies.

## Install

1. Download the latest `BetterForeverXP-<version>.zip` from GitHub Releases.
2. Extract it into the game's `Interface/AddOns` directory.
3. Confirm the resulting path is `Interface/AddOns/BetterForeverXP/BetterForeverXP.toc`.
4. Enable **Better Forever XP** from the AddOns screen.

This addon targets the WoW Forever beta client interface listed in
[`BetterForeverXP.toc`](BetterForeverXP/BetterForeverXP.toc).

## Commands

| Command | Action |
| --- | --- |
| `/bfxp lock` / `/bfxp unlock` | Lock or unlock dragging. Shift-drag always moves the bar. |
| `/bfxp show` / `/bfxp hide` | Show or hide the addon bar. |
| `/bfxp reset` | Restore the default position and dimensions. |
| `/bfxp width 300-1600` | Set the bar width. |
| `/bfxp height 10-30` | Set the bar height. |
| `/bfxp scale 0.5-2` | Set the UI scale. |
| `/bfxp format short\|commas\|exact` | Choose the number format. |
| `/bfxp default on\|off` | Show or hide Blizzard's default tracking bar. |

See the [addon documentation](BetterForeverXP/README.md) and
[changelog](BetterForeverXP/CHANGELOG.md) for full details.

## Development

Run the repository checks from PowerShell:

```powershell
./scripts/Test-Addon.ps1
```

Build a release archive:

```powershell
./scripts/Package-Addon.ps1
```

The package script reads the version from the TOC file and writes a clean,
installable archive to `dist/`. GitHub Actions runs the same validation on
every push and pull request and publishes the archive as a workflow artifact.

## License

Copyright © Dezolve Labs. All rights reserved. No license is granted for
redistribution or modification beyond rights provided by applicable law.
