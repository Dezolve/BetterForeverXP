# Better Forever XP 2.5.0

By Dezolve Labs

## In-game settings and proportional scaling

- Adds a built-in Settings → AddOns panel, also accessible through `/bfxp` or `/bfxp options`.
- New installations start unlocked; existing installations retain their previous lock setting.
- Adds invisible hover-resize zones: **top edge** adjusts height, **right edge** adjusts width, and **bottom-right corner** adjusts both. Large hit targets make the edges easy to catch.
- Refines hover affordances: hovering anywhere along the top edge reveals a 58×20 center tab; the right edge shows a vertical grip; the bottom-right gold L-grip is restored just outside the bar with its artwork adapting to bar height. All hide off hover or when locked.
- Aligns the top-center grip with the right and bottom-right controls: matching dark-navy backing and warm-gold highlight, with no pale accent stripe.
- Keeps direct mouse tracking and fixed opposite edges, and increases the proportional bar/text scale slider maximum from 2× to 3× (default remains 1×).
- Locking the bar disables edge resizing and disables ordinary dragging; Shift-drag remains available.
- Adds panel controls for enabled state, bar lock, Blizzard bar visibility, width, height, scale, number format, and resets.
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
