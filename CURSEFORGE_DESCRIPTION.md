# Better Forever XP

**By Dezolve Labs — World of Warcraft: Forever**

A customizable Blizzard-inspired experience tube that keeps your leveling progress visible without crowding the game. Built for **WoW Forever 1.60.1 (interface 16001)**.

## XP bar

- 20 visible five-percent segments with full-height brushed-steel dividers and an optional Blizzard-style silver midpoint marker
- Rounded metallic tube with blue earned XP while rested, purple when not rested, dark-navy rested coverage, and a dark empty track
- **Three text modes:** Tooltip only (clean default), Text on hover, or Always visible
- Current XP, remaining XP, completion percentage, and bars left with compact or exact number formatting
- Responsive text that stays within the bar; small percentages show two decimal places

## Detailed XP tooltip

Hover over the bar to see:

- Current level, total/current/remaining XP, and bars left
- Rested XP and remaining rested coverage
- XP from completed quests, projected progress after turn-ins, and overflow into the next level where its XP curve is known
- Session XP, XP/hour, time spent leveling, and estimated time to level

Session statistics survive `/reload`, without requiring additional libraries or addons.

## In-game settings

Type **`/bfxp`** or **right-click the XP bar** to open Settings → AddOns. Adjust width (300–1600px), height (10–120px), overall scale (0.5–3×), position, text mode, number format, midpoint marker, lock, and Blizzard bar visibility.

Drag the unlocked bar to move it; Shift-drag works while locked. Hover just below the middle or over the right/bottom-right edge to reveal resize handles.

## Useful commands

- `/bfxp` — open settings
- `/bfxp lock` / `/bfxp unlock` — lock or unlock
- `/bfxp reset` — reset position and dimensions
- `/bfxp width 300-1600`
- `/bfxp height 10-120`
- `/bfxp scale 0.5-3`
- `/bfxp show` / `/bfxp hide`

No external dependencies. Compatible with **WoW Forever 1.60.1**.
