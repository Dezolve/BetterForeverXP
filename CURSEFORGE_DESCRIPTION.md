# Better Forever XP

**By Dezolve Labs**

Better Forever XP is a slim, modern experience bar designed for WoW Forever. It keeps the bar itself compact while putting detailed leveling information one hover away.

## Bar display

- Current level and percentage
- Exact XP values with commas plus compact notation, such as `4,500 (4.5K)`
- Remaining XP
- Remaining Blizzard-style bars, rounded to the nearest half-bar
- Twenty subtle 5% divisions
- Distinct colors for earned XP, rested coverage, and unearned XP

## Hover details

The tooltip is divided into Progress, Bonuses & Ready Quests, and Leveling Pace sections. It includes:

- Current, remaining, and percentage progress
- Bars left
- Rested XP, rested percentage, and rested coverage in bars
- XP from completed quests and projected progress after turning them in
- Time spent on the current level
- Session time and XP
- XP per hour and estimated time to level

Session rate data survives `/reload` and resets on a fresh character login.

## Position and sizing

Use `/bfxp unlock` and drag the bar, then `/bfxp lock` when finished. Shift-drag always moves it, even while locked.

Additional commands:

- `/bfxp width 300-1600`
- `/bfxp height 10-30`
- `/bfxp scale 0.5-2`
- `/bfxp reset`
- `/bfxp show` or `/bfxp hide`
- `/bfxp default on|off`

No libraries or other addons are required.
