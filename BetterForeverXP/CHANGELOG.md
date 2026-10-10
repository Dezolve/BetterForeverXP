# Better Forever XP 2.5.0

By Dezolve Labs

## In-game settings and proportional scaling

- Adds a built-in Settings → AddOns panel, accessible through `/bfxp`, `/bfxp options`, or right-clicking the XP bar (including while locked or over a resize zone).
- New installations start unlocked; existing installations retain their previous lock setting.
- Adds invisible hover-resize zones: **a compact target below the center** adjusts height, **right edge** adjusts width, and **bottom-right corner** adjusts both. The height target is 96×18px with a clear gap from the bar and no expanded mouse hit rect, preserving click-drag and tooltips even at 10px height.
- Replaces the former bronze stone-chip ornament with a small WoW Classic-inspired **silver-and-dark-steel V-shaped midpoint arrow**, with bright beveled highlights, a recessed dark center, and a tip integrated with the top border. **Show 50% marker** in Settings toggles it instantly, defaults to on, persists across sessions, and is restored by Reset all defaults. The ornament remains mouse-transparent; the XP tooltip, dragging, right-click options, and bottom-center height resizing are preserved.
- Keeps a dedicated rendering frame that extends above the XP bar to avoid clipping, and draws the new silver, dark steel, shadow and highlight layers separately for clear detail at normal UI scale.
- Refines hover affordances: hovering just below the midpoint reveals a compact gold line; the right edge shows a vertical grip; the bottom-right gold L-grip sits outside the bar and adapts to its height. All resize hints hide off hover or when locked.
- Keeps the height grabber as a standalone warm-gold line with a thin translucent shadow instead of a bulky black plate.
- Keeps direct mouse tracking and fixed opposite edges, and increases the proportional bar/text scale slider maximum from 2× to 3× (default remains 1×).
- Locking the bar disables edge resizing and disables ordinary dragging; Shift-drag remains available.
- Adds panel controls for enabled state, bar lock, Blizzard bar visibility, width, height, scale, number format, and resets.
- Fixes the **Hide Blizzard's XP bar** checkbox so unchecking actually restores frames previously hidden by Better Forever XP without a reload. Only addon-hidden frames are restored, and changes made in combat apply afterward.
- Expands configurable bar height up to 120 pixels (three times the previous 40px limit), with taller bars gradually enlarging their text. The default height remains 16px.
- Adapts text layout across narrow, medium, and wide bar widths so labels do not overlap.
- Connects the number format option to the main bar's visible XP values.
- Preserves previous XP calculations, tooltip details, session tracking, and slash commands.

# Better Forever XP 2.4.1

By Dezolve Labs

Initial public release for WoW Forever beta.

## Highlights

- Slim, standalone modern XP bar with a configurable position, width, height, and scale.
- Wider 1,100-pixel default better matches Blizzard's full-width presentation.
- Twenty visible 5% divisions with bars-left estimates rounded to the nearest half-bar.
- All 5% dividers now use a consistent visual weight.
- Distinct earned, rested, and unearned XP colors.
- Blizzard-inspired hierarchy uses electric-blue earned XP, dark-navy rested coverage, near-black empty space, and warm metallic boundary markers.
- Explicit status-bar layering keeps earned XP visibly above rested coverage.
- Outlined bar labels remain readable across bright, rested, and empty segments.
- Remaining XP label now explicitly reads “XP left” for faster scanning.
- Subtle Dezolve Labs branding integrated into the tooltip title.
- Exact comma-formatted values alongside compact values such as `4,500 (4.5K)`.
- Sectioned hover details for progress, rested XP, completed quest turn-ins, leveling pace, XP/hour, and ETA.
- Session XP and rate survive `/reload` while fresh logins begin a new session.
- Blizzard's default tracking bar can be hidden or restored.
