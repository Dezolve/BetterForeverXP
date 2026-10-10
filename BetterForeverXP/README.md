# Better Forever XP

By Dezolve Labs

A standalone, modern, low-profile experience bar for WoW Forever beta.

The bar is 1,100 pixels wide and 16 pixels high by default. It shows level,
percent, remaining XP, and current/maximum XP. Values always use commas and
also show shorthand at 1,000 or above, such as `4,500 (4.5K)`.

Earned XP uses a subtle vertical tube gradient: light blue above and deeper
blue below while rested, switching to light/deep classic purple when the rested
bonus ends. The remaining rested coverage has a secondary navy gradient;
unearned XP sits in a softly shaded near-black channel. Dark upper and lower
tube rims, a thin white inner reflection, and deeper bottom shading add
visible depth. The ends now use height-aware stepped circular contours,
with a matching metallic edge; the curve increases up to a restrained 16px
radius at large bar heights instead of disappearing at 2px. The straight metal
rails now terminate exactly where the curved cap begins, with no overlapping
rectangular border or stray black corners. The background and both colored XP
fills are now painted inside the same genuinely rounded silhouette: transparent
outside the corners, with blue/purple earned and navy rested XP continuing into
the visible endcaps rather than stopping at a squared-off track. On older clients
without gradient support, solid XP colors and bevel highlights remain.
Hover for exact progress, rested XP, completed quest
XP ready to turn in, session XP, XP/hour, and estimated time to level.

The hover card also tracks online time spent on the current level, shows how
much of a level completed quests are worth, projects progress after turn-ins,
and directly underneath shows **XP into next level** (the positive excess of
completed-quest XP beyond the current level requirement, or 0 XP if none).
That line also displays the percentage of the **following level's** XP
requirement. When the client provides a validated XP-by-level API, the
percentage uses it directly; otherwise a matching Classic level curve gives
an approximate percentage (prefixed with ~). Unknown level curves show the
raw XP and an unavailable percentage rather than using the wrong denominator.
The hover card also expresses rested coverage in 5%-sized bars.

The hover card is organized into Progress, Bonuses & Ready Quests, and Leveling
Pace sections. Rested percentage, XP/hour, and ETA remain visible at zero so
the layout does not jump around as values become available.

Session XP and its start time survive `/reload`, so XP/hour and ETA do not reset
while adjusting the UI. A genuine fresh character login starts a new session.

The classic **20 visible 5%-XP segments** remain part of the tube design.
Each 5% divider is a continuous recessed groove with a black core, silver
edge, and white center reflection. Removing the separate black end blocks
prevents dark gaps showing through the marks. All 19 dividers are positioned
across the same **inner visible track** used by the XP fills, and snapped to
physical pixels as the bar changes width/scale. The 50% divider remains centered
beneath the native silver Blizzard arrow.
The right-hand text still reports bars remaining, rounded to the nearest
half-bar, such as `8.5 bars left`.

The exact **native WoW Classic silver exhaustion-tick texture** now marks the
50% position along the bar's top border. A single 32px texture replaces the
previous patchwork of rotated rectangles, so the arrow is seamless, filled,
and centered. It's decorative, cannot capture mouse input, and remains hidden
when **Show 50% marker** is unchecked in Settings. The setting persists
across logins and /reload; the separate resize handles are unchanged.

## Customization

Open **Settings → AddOns → Better Forever XP**, type `/bfxp`, or **right-click the XP bar** (even when locked).

- New installs start unlocked. Drag the bar body to move it, or hover over it
  to view the XP details. Resize zones are invisible until hovered:
  **below the bottom edge** changes height, **right edge** changes width,
  and **bottom-right corner** changes both independently. Hover just below
  the **center** of the bar to reveal the gold height grip. Its 96×18px mouse
  target is separated from the bar by a small gap, instead of occupying the
  entire bottom edge. This leaves thin bars fully available for dragging and
  XP tooltips. The right edge has a narrow gold grip; the bottom-right corner
  has an external gold L-shaped grip that scales down on thin bars.
  Resize hints hide off hover.
- Lock the bar in Settings or via `/bfxp lock`. This disables all resize zones and
  prevents ordinary dragging. Shift-drag remains an intentional move shortcut.
- Set width (300–1600), height (10–120), and overall scale (0.5–3) independently
  using sliders. Height above 40 also grows the XP text (up to a readable cap).
  Width/height change the layout; scale proportionally grows
  or shrinks the entire presentation. Larger scales can exceed your screen
  width; use `/bfxp reset` to restore the defaults if needed.
- Toggle the custom bar, the decorative 50% metal marker, and Blizzard's XP
  bar; choose the XP number format or reset position and size. **Reset all
  defaults** also restores the marker to visible.
- The bar changes text density as width shrinks to avoid overlapping labels.
- Existing installs keep their saved lock preference. Settings persist through
  relogs and `/reload`.
- Unchecking **Hide Blizzard's XP bar** restores the native bar immediately;
  changes made during combat apply as soon as combat ends.

## Commands

* `/bfxp` or `/bfxp options` to open the Settings panel

* `/bfxp lock` or `/bfxp unlock` (drag while unlocked; Shift-drag always works)
* `/bfxp show` or `/bfxp hide`
* `/bfxp reset`
* `/bfxp width 300-1600`
* `/bfxp height 10-120`
* `/bfxp scale 0.5-3`
* `/bfxp format short|commas|exact`
* `/bfxp default on|off` to show or hide Blizzard's default tracking bar
