# Better Forever XP

![Better Forever XP logo](Brand/BetterForeverXP-CurseForge-Logo.png)

A slim, standalone experience bar for WoW Forever, by Dezolve Labs.

Better Forever XP keeps the always-visible interface compact and puts the
details one hover away. It shows exact and abbreviated XP values, rested XP,
completed-quest XP, session pace, time to level, and progress in Blizzard-style
five-percent bars. It has no external dependencies.

A small silver-and-dark-steel WoW Classic-style V arrow marks 50% along the
top border without covering labels or capturing mouse input. It is on by default
and can be hidden with **Show 50% marker** in the Options panel.

## Install

1. Download the latest `BetterForeverXP-<version>.zip` from GitHub Releases.
2. Extract it into the game's `Interface/AddOns` directory.
3. Confirm the resulting path is `Interface/AddOns/BetterForeverXP/BetterForeverXP.toc`.
4. Enable **Better Forever XP** from the AddOns screen.

This addon targets the WoW Forever beta client interface listed in
[`BetterForeverXP.toc`](BetterForeverXP/BetterForeverXP.toc).

## In-game customization

Type **`/bfxp`** or **right-click the XP bar** to open its Options panel under **Settings → AddOns**. Right-click also works when locked.
The XP bar starts **unlocked on new installations**. Drag its body to move it.
Hover **just below the center** of the bar to reveal the gold height grip,
then drag downward to increase thickness. Only a compact 96×18px target
below the bar can resize height; the rest of the bar remains available for
click-dragging and its XP tooltip, even at minimal heights. Hover the
**right edge** to resize width, or the **bottom-right corner** to resize both. The corner grip sits outside the bar
for easy grabbing, and its artwork shrinks with thin bars. The
separate scale slider adjusts the entire bar and its text up to 3×.
At large scales the bar may exceed the screen width; `/bfxp reset` restores
its default size and position.
Lock the bar from Settings or with `/bfxp lock` to hide the resize controls and
prevent accidental movement. Existing users keep their saved lock preference.

The Height control supports 10–120px, while the overall UI scale is separate.
The panel also provides separate width, height, scale, 50% marker visibility,
default-bar visibility, and XP number-format controls. Unchecking **Hide Blizzard's XP bar**
restores frames hidden by the addon immediately (or after combat). At smaller widths the bar reduces
text detail automatically to avoid overlap.

## Commands

| Command | Action |
| --- | --- |
| `/bfxp` / `/bfxp options` | Open the in-game settings panel. |
| `/bfxp lock` / `/bfxp unlock` | Lock or unlock dragging and the edge resize zones. Shift-drag still moves the bar. |
| `/bfxp show` / `/bfxp hide` | Show or hide the addon bar. |
| `/bfxp reset` | Restore the default position and dimensions. |
| `/bfxp width 300-1600` | Set the bar width. |
| `/bfxp height 10-120` | Set the bar height. |
| `/bfxp scale 0.5-3` | Set the UI scale. |
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

## Automatic Windows test deployment

GitHub-hosted Actions can build and package the addon, but cannot access a
Windows PC's C: drive. Instead, the optional local updater
[scripts/AutoDeploy-Windows.ps1](scripts/AutoDeploy-Windows.ps1) checks the
**latest successful push build** of the feature branch every minute and
installs the packaged addon locally. No GitHub self-hosted runner is needed.

**One-time setup on the Windows PC:**

1. Install [GitHub CLI](https://cli.github.com/) (or run
   `winget install --id GitHub.cli -e`) and complete `gh auth login`.
2. Clone or switch your local repo to `feature/options-and-scaling`.
3. From the repository root in PowerShell, run:

```powershell
.\scripts\AutoDeploy-Windows.ps1 -Install -TargetPath 'C:\PATH\TO\WoWForever\Interface\AddOns\BetterForeverXP'
```

Use the **actual** WoW Forever `Interface\AddOns\BetterForeverXP` folder,
not a copy in Downloads, unless that Downloads folder is explicitly linked to
the live AddOns folder. The updater warns when the path doesn't resemble a
live AddOns directory.

Installation copies the updater into `%LOCALAPPDATA%\BetterForeverXP-AutoDeploy`
and creates a **user-level Windows Scheduled Task** that runs every minute.
The task runs through a hidden Windows Script Host launcher so it does not
flash a console window while you're playing.
The initial sync runs immediately. The updater downloads the GitHub Actions
artifact, extracts the versioned release ZIP inside it, validates all files
listed in the TOC (including `Options.lua`), and copies the addon into the
selected path. It never touches `WTF` or SavedVariables.

After successfully installing a new build, it posts the
`BetterForeverXP/local-install` status to the matching GitHub commit. Once
both CI and that status pass, the installed addon is ready for `/reload`
in the WoW client. This status only indicates file deployment, **not**
that the in-game UI has been verified.

To upgrade an older updater that flashed a command window, download the latest
AutoDeploy-Windows.ps1 from this branch and repeat the `-Install` command with
your existing target path. That replaces the scheduled task with the silent
launcher.

Troubleshooting:

```powershell
Get-Content "$env:LOCALAPPDATA\BetterForeverXP-AutoDeploy\deploy.log" -Tail 30
Get-ScheduledTask -TaskName BetterForeverXP-AutoDeploy
.\scripts\AutoDeploy-Windows.ps1 -Uninstall
```

Uninstalling removes the scheduled task and leaves logs and configuration for
diagnosis. The task requires the Windows user to be logged in and the
authenticated GitHub CLI to remain available. Builds are never applied
unless their GitHub Actions workflow completed successfully.

## License

Copyright © Dezolve Labs. All rights reserved. No license is granted for
redistribution or modification beyond rights provided by applicable law.
