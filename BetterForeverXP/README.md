# Better Forever XP

By Dezolve Labs

A standalone, modern, low-profile experience bar for WoW Forever beta.

The bar is 1,100 pixels wide and 16 pixels high by default. It shows level,
percent, remaining XP, and current/maximum XP. Values always use commas and
also show shorthand at 1,000 or above, such as `4,500 (4.5K)`.

Earned XP is solid royal blue; rested XP extends beyond it in dark navy with
a warm metallic end marker; unearned XP is near-black. The hierarchy follows
Blizzard's proven light-to-dark treatment. Hover for exact progress, rested XP, completed quest
XP ready to turn in, session XP, XP/hour, and estimated time to level.

The hover card also tracks online time spent on the current level, shows how
much of a level completed quests are worth, projects progress after turn-ins,
and expresses rested coverage in 5%-sized bars.

The hover card is organized into Progress, Bonuses & Ready Quests, and Leveling
Pace sections. Rested percentage, XP/hour, and ETA remain visible at zero so
the layout does not jump around as values become available.

Session XP and its start time survive `/reload`, so XP/hour and ETA do not reset
while adjusting the UI. A genuine fresh character login starts a new session.

The track has 20 subtle divisions (5% each), and the right-hand text shows how
many Blizzard-style bars remain, rounded to the nearest half-bar, such as
`8.5 bars left`.

## Customization

Open **Settings → AddOns → Better Forever XP** or type `/bfxp`.

- New installs start unlocked. Drag the bar body to move it. The resize zones
  are invisible until hovered: **top edge** changes height, **right edge**
  changes width, and **bottom-right corner** changes both independently.
  Hovering the center of the top edge reveals a compact, taller grab tab.
  The right edge shows a narrow gold grip. At bottom-right, a small gold corner
  indicator sits inside the bar and shrinks automatically with the bar's height.
  The invisible click targets remain forgiving, and all hints hide off hover.
- Lock the bar in Settings or via `/bfxp lock`. This disables all resize zones and
  prevents ordinary dragging. Shift-drag remains an intentional move shortcut.
- Set width (300–1600), height (10–40), and overall scale (0.5–2) independently
  using sliders. Width/height change the layout; scale proportionally grows
  or shrinks the entire presentation.
- Toggle the custom bar and Blizzard's own XP bar, choose the XP number
  format, or reset position and size.
- The bar changes text density as width shrinks to avoid overlapping labels.
- Existing installs keep their saved lock preference. Settings persist through
  relogs and `/reload`.
- Re-enabling Blizzard's native bar may require `/reload`.

## Commands

* `/bfxp` or `/bfxp options` to open the Settings panel

* `/bfxp lock` or `/bfxp unlock` (drag while unlocked; Shift-drag always works)
* `/bfxp show` or `/bfxp hide`
* `/bfxp reset`
* `/bfxp width 300-1600`
* `/bfxp height 10-40`
* `/bfxp scale 0.5-2`
* `/bfxp format short|commas|exact`
* `/bfxp default on|off` to show or hide Blizzard's default tracking bar
