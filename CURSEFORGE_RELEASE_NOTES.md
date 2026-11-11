# Better Forever XP 2.8.0

**New: Automatic Instance XP Tracking** — see how much experience you've earned while running a dungeon without adding another bar or window.

## What's new

- **Current Instance** in the existing XP/Reputation hover tooltip shows the dungeon or raid name, XP earned in that run, actual time inside, run XP/hour, and equivalent 20-segment bars gained.
- **Last Instance** retains the finished run's summary after leaving, until the next instance begins.
- **Safe persistence:** run totals survive `/reload` and relogging. A brief exit and return to the *same* instance within two minutes continues the existing run; time and XP earned outside don't count.
- **Correct level-ups:** the tracker combines XP remaining before a level-up with XP earned on the next level. It also avoids counting a temporary XP reset as a new gain.
- **Optional and lightweight:** **Track dungeon XP** is enabled by default under `/bfxp` Settings → Display & Interaction. The feature uses normal game events and the existing tooltip, with no combat-log parser or extra dependencies.

## Unchanged

- Existing XP ↔ Reputation switching, per-character preference, quest-gold preview and rested colors.
- The Classic-inspired 20-segment bar layout and Compact number formatting.
- No separate window, run-history database, or new colors.

## Requirements

- World of Warcraft: Forever 1.60.1 (interface 16001)
- No external libraries.

*Better Forever XP by Dezolve Labs · © 2026 Dezolve Labs.*
