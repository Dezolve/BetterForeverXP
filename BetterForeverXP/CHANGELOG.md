# Better Forever XP 2.5.0

By Dezolve Labs

## In-game settings and proportional scaling

- Adds a built-in Settings → AddOns panel, accessible through `/bfxp`, `/bfxp options`, or right-clicking the XP bar (including while locked or over a resize zone).
- New installations start unlocked; existing installations retain their previous lock setting.
- Matches Blizzard's rested-state colors: earned XP stays electric blue while rested XP remains, then turns purple when the rested bonus reaches zero. The thin top highlight changes with it, and updates on `UPDATE_EXHAUSTION` without a reload.
- **Tube appearance pass:** replaces flat XP and background fills with vertical shading (light upper arc, dark lower edge) for blue rested, purple unrested, navy rested coverage and the empty track. Bevel highlights follow filled XP widths, and unsupported older clients gracefully retain solid colors.
- **Premium grooved segment markers:** preserves all 20 classic 5%-XP sections with 19 subtle two-layer dividers. A vertically shaded recessed core and faint glint give the lines a cylindrical/metallic feel matching the tube gradient. Both layers remain a fixed rendered-pixel width and share one snapped anchor, with earned/rested/empty contrast palettes and flat-color fallbacks. The 50% line stays slightly stronger under the native Blizzard arrow. XP values and the bar's shading are unchanged.
- **High-contrast groove and frame polish:** darkens the divider cores toward black and brightens their fading white edge so every 5% tick remains legible over blue/purple, navy and near-black. Slightly strengthens the 50% divider. Adds mouse-transparent dark inner top/bottom tube lines, a narrow white upper reflection and lower shadow drawn above the fills but below the markers and text; retains the existing tube gradient and corner trims.
- **Clean idle XP bar:** hides the large XP labels until the mouse hovers over the bar, with a persisted **Show XP text only on hover** checkbox (default on) to restore always-visible text as desired. The hover tooltip continues to contain every exact XP value. The silver Blizzard arrow now anchors directly to the same physical-pixel-snapped 50% divider as the other 19 markers, preventing marker/line drift at different dimensions and scales. All 20 segments, UI drag/resize controls, and XP calculation logic are unchanged.
- **Responsive XP text fix:** prevents the center and right strings from drawing into each other at taller font sizes by giving all three columns non-overlapping widths. Every label tests its actual unbounded rendered width and progressively shortens the content (without losing exact XP information in the tooltip). Adds faint per-word-size dark scrims above the dividers and below large white text, avoiding full-width panels. Keeps thin XP bars scrim-free, the 20 segments visible and the silver midpoint marker intact.
- **Cobalt + readability refinement:** corrects a double-tinted 1px gradient on the rounded cap strips, removing the mismatched blue band at the left edge. Uses one shared deep Blizzard-style cobalt palette and samples trimmed endcap gradients at the same vertical positions as the main bar. The 20 segment boundaries and earned/rested fill boundaries now use precise absolute percentages of the full rounded tube width, while retaining physical-pixel snapping. XP labels gain a heavier black outline at larger text sizes without obscuring any 5% marker.
- **Shared tube geometry fix:** removes square background corners instead of hiding them under black textures. Paints the gradient background and blue/purple/rested fill through genuinely rounded, height-adjusting end strips. The main StatusBars, progress/spark positions and 19 scale-snapped 5% dividers share the same inner visual width. Replaces stacked black notch blocks with continuous black/silver groove strokes and centered white reflections. A single rounded metallic border and native Blizzard 50% arrow remain intact; dragging, tooltips and resize handles are unchanged.
- **Unified rounded-border alignment:** removes the redundant full-width rectangular border and derives the straight steel rails and side edges from the same radius profile as the curved tube caps. Insets the dark/white inner highlights so they cannot protrude through the caps, with consistent steel colors and mouse-transparent decorative layers. Keeps the taller tube, 20 beveled XP divisions, 50% arrow and all controls intact.
- **Structural tube rebuild:** replaces barely-visible 2px corner cuts with height-aware stepped circular endcaps (up to 16px radius) and matching metal contours. The dark top/bottom rims and lower shading now adapt to bar height instead of disappearing on large bars. Each of the 19 groove dividers also gets a strong white center reflection between solid dark top/bottom sockets, scaling correctly from 10px to 120px high. Original Blizzard 50% art, all 20 segments, rested color switching, tooltip and drag controls remain unchanged. The contours are decorative rather than game-window clipping masks.
- Adds invisible hover-resize zones: **a compact target below the center** adjusts height, **right edge** adjusts width, and **bottom-right corner** adjusts both. The height target is 96×18px with a clear gap from the bar and no expanded mouse hit rect, preserving click-drag and tooltips even at 10px height.
- Uses the **original Blizzard UI silver exhaustion-tick texture** for the permanent 50% marker: one filled, symmetric 32px image instead of multiple rotated rectangles. The artwork is centered over the halfway tick, remains mouse-transparent, and can be switched off instantly through **Show 50% marker** (enabled by default; persisted and resettable).
- Refines hover affordances: hovering just below the midpoint reveals a compact gold line; the right edge shows a vertical grip; the bottom-right gold L-grip sits outside the bar and adapts to its height. All resize hints hide off hover or when locked.
- Improves visibility of the bottom-right resize corner on the unearned/empty portion of the bar: a softer translucent navy plate sits behind brighter gold L-shaped strokes and highlights with explicitly higher draw layers. No changes to mouse hit targets or earned XP colors.
- Keeps the height grabber as a standalone warm-gold line with a thin translucent shadow instead of a bulky black plate.
- Keeps direct mouse tracking and fixed opposite edges, and increases the proportional bar/text scale slider maximum from 2× to 3× (default remains 1×).
- Locking the bar disables edge resizing and disables ordinary dragging; Shift-drag remains available.
- Adds panel controls for enabled state, bar lock, Blizzard bar visibility, width, height, scale, number format, and resets.
- Fixes the **Hide Blizzard's XP bar** checkbox so unchecking actually restores frames previously hidden by Better Forever XP without a reload. Only addon-hidden frames are restored, and changes made in combat apply afterward.
- Expands configurable bar height up to 120 pixels (three times the previous 40px limit), with taller bars gradually enlarging their text. The default height remains 16px.
- Adapts text layout across narrow, medium, and wide bar widths so labels do not overlap.
- Connects the number format option to the main bar's visible XP values.
- Adds **XP into next level** immediately below **After turn-ins** in the XP hover tooltip. Shows ready-quest XP carried beyond the current level threshold (0 XP if no overflow), along with the following level's percentage using a verified in-game XP curve or an explicitly approximate Classic XP lookup. Never divides by the current XP cap or invents percentages for unknown XP curves.
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
