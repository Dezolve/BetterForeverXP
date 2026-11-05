# Better Forever XP

**By Dezolve Labs — World of Warcraft: Forever**

A customizable Blizzard-inspired experience tube that keeps your leveling progress visible without crowding the game. Built for **WoW Forever 1.60.1 (interface 16001)**.

## New in 2.7.0 — XP and Reputation in one bar

- **Left-click** the bar to switch between experience and the faction you're watching in WoW's Reputation panel.
- Check **Show as Experience Bar** on a faction to have Better Forever XP switch to its Reputation automatically, with no extra click.
- Blizzard's own standing colors, watched faction name, progress and remaining reputation, all in the existing curved 20-segment metallic bar.
- The chosen mode is remembered per character. Normal reputation gains don't pull you out of XP mode; watched Reputation can remain visible when XP is unavailable at max level.
- Refined, scrollable in-game options with grouped controls, translucent panels, intuitive selected states and Dezolve Labs attribution.
- No Honor or Gold modes. The focus remains XP and Reputation.

## XP bar

- 20 visible five-percent segments with full-height brushed-steel dividers and an optional Blizzard-style silver midpoint marker
- Rounded metallic tube with blue earned XP while rested, purple when not rested, dark-navy rested coverage, and a dark empty track
- **Updated in 2.6.1:** Optional rich golden-yellow completed quest XP preview directly on the bar. See how far ready-to-turn-in quests will advance you without confusing projected XP with earned XP. The preview stops at this level's end; carryover remains in the tooltip.
- **Updated in 2.6.2:** Three text modes: Tooltip only, Text on hover (the default for new installs and Reset all), or Always visible. Existing preferences are preserved.
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

Type **`/bfxp`** or **right-click the bar** to open Settings → AddOns. Left-click to cycle between XP and Reputation when a faction is watched. Adjust width (300–1600px), height (10–120px), overall scale (0.5–3×), position, text mode, number format, completed quest XP preview, midpoint marker, lock, and Blizzard bar visibility.

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
