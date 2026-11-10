local _, addon = ...

-- Progress is divided into the same twenty 5%-wide divisions shown by the
-- tube. Round to the nearest half division for a readable chat/tooltip count;
-- derive the remainder from that same rounded value so the two always sum 20.
local function BarsParts(fraction)
    local progress = math.max(0, math.min(1, tonumber(fraction) or 0))
    local filled = math.floor(progress * 40 + 0.5) / 2
    local remaining = 20 - filled

    local function Number(value)
        return value == math.floor(value) and tostring(math.floor(value))
            or string.format("%.1f", value)
    end

    return Number(filled), Number(remaining)
end

-- The hover tooltip keeps the explicit twenty-division reference.
function addon.BarsProgressText(fraction)
    local filled, remaining = BarsParts(fraction)
    return filled .. "/20 bars (" .. remaining .. " left)"
end

-- The visible bar is already divided into 20 segments, so it doesn't
-- need to repeat the denominator. Keep earned and remaining in view.
function addon.CompactBarsProgressText(fraction)
    local filled, remaining = BarsParts(fraction)
    return filled .. " bars • " .. remaining .. " left"
end

-- In Forever, ADDON_LOADED/PLAYER_ENTERING_WORLD can precede a populated
-- GetWatchedFactionData(). That first UPDATE_FACTION is often cache restoration,
-- NOT a new Show as Experience Bar click. Preserve a per-character XP override
-- across that restoration; later true faction changes still auto-select Rep.
--
-- Starting with no saved mode is treated as a first install, so a newly watched
-- faction may opt into Rep immediately. Mode persistence remains in charDB.
function addon.NewWatchedSelection(savedModeExists)
    local tracker = { ready = false, key = nil }

    function tracker:Prime(key)
        if key ~= nil then
            self.key = key
            self.ready = true
        end
    end

    function tracker:Observe(key)
        if not self.ready then
            if key == nil then return false end
            self.key = key
            self.ready = true
            -- For an existing character, first valid data may be late login
            -- restoration. It must not undo saved progressMode == "xp".
            return not savedModeExists
        end
        local changed = key ~= self.key
        self.key = key
        -- Clearing a watched faction doesn't force Rep; rechecking it or
        -- watching a different faction during play does.
        return changed and key ~= nil
    end

    return tracker
end
