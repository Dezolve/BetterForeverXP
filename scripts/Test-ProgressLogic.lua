-- Runs under plain Lua 5.4 in CI, no WoW client dependencies.
local addon = {}
assert(loadfile("BetterForeverXP/ProgressLogic.lua"))("BetterForeverXP", addon)

local cases = 0
local function Equal(actual, expected, name)
    cases = cases + 1
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Twenty visible segments. Half-bars are deliberately rounded once so
-- progress and the "left" value always total exactly twenty.
Equal(addon.BarsProgressText(0), "0/20 bars (20 left)", "zero")
Equal(addon.BarsProgressText(0.25), "5/20 bars (15 left)", "quarter")
Equal(addon.BarsProgressText(0.75), "15/20 bars (5 left)", "three-quarters")
Equal(addon.BarsProgressText(0.775), "15.5/20 bars (4.5 left)", "partial")
Equal(addon.BarsProgressText(1), "20/20 bars (0 left)", "complete")
Equal(addon.BarsProgressText(-1), "0/20 bars (20 left)", "negative clamped")
Equal(addon.BarsProgressText(2), "20/20 bars (0 left)", "overfull clamped")

-- The visible bar omits the already obvious /20 while still showing both
-- earned and remaining divisions. Tooltip text above stays explicit.
Equal(addon.CompactBarsProgressText(0), "0 bars • 20 left", "compact zero")
Equal(addon.CompactBarsProgressText(0.25), "5 bars • 15 left", "compact quarter")
Equal(addon.CompactBarsProgressText(0.467), "9.5 bars • 10.5 left", "compact screenshot fraction")
Equal(addon.CompactBarsProgressText(0.75), "15 bars • 5 left", "compact three-quarters")
Equal(addon.CompactBarsProgressText(0.775), "15.5 bars • 4.5 left", "compact partial")
Equal(addon.CompactBarsProgressText(1), "20 bars • 0 left", "compact complete")

-- Character manually clicked back from Rep to XP, then reloaded. During
-- initialization the watched faction is missing and arrives via UPDATE_FACTION.
-- That first non-nil watcher must be baseline only; never force Rep.
local relog = addon.NewWatchedSelection(true)
relog:Prime(nil)
Equal(relog:Observe(nil), false, "reload missing faction")
Equal(relog:Observe(72), false, "late faction restoration respects saved XP")
Equal(relog:Observe(72), false, "rep gain with same watched ID")
Equal(relog:Observe(73), true, "select different watched faction")
Equal(relog:Observe(73), false, "additional rep gain")
Equal(relog:Observe(nil), false, "unwatch")
Equal(relog:Observe(73), true, "recheck same faction requests Rep")

-- If the API has already returned faction data on ADDON_LOADED or
-- PLAYER_ENTERING_WORLD, that data is also a baseline rather than a click.
local immediate = addon.NewWatchedSelection(true)
immediate:Prime(72)
Equal(immediate:Observe(72), false, "present on login")
Equal(immediate:Observe(74), true, "later explicit selection")

-- Re-entering a zone with a temporarily nil faction cannot wipe an existing
-- baseline via Prime(nil). Explicit UPDATE_FACTION(nil) still supports unwatch.
local zone = addon.NewWatchedSelection(true)
zone:Prime(72)
zone:Prime(nil)
Equal(zone:Observe(72), false, "zone entry nil does not steal focus")

-- A fresh character has no saved mode to override, so choosing a watched
-- faction can still switch to Reputation automatically.
local fresh = addon.NewWatchedSelection(false)
fresh:Prime(nil)
Equal(fresh:Observe(72), true, "new install selects tracked Reputation")
Equal(fresh:Observe(72), false, "new install duplicate unchanged")

print("ProgressLogic regression PASS: " .. cases .. " behavioral assertions")
