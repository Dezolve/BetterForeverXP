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

-- Inline-only preferences. The tooltip never consumes this list.
addon.InlineFieldSettings = {
    "showBarIdentity", "showBarProgress", "showBarPercent", "showBarRemaining", "showBarCounts",
}

function addon.IsInlineFieldSetting(key)
    for _, setting in ipairs(addon.InlineFieldSettings) do
        if key == setting then return true end
    end
    return false
end

-- Bulk changes affect only these five preferences, not modes or formatting.
function addon.ApplyInlineFieldSelection(settings, value)
    if type(value) ~= "boolean" then return false end
    for _, key in ipairs(addon.InlineFieldSettings) do settings[key] = value end
    return true
end

function addon.AllInlineFieldsEnabled(settings)
    for _, key in ipairs(addon.InlineFieldSettings) do
        if not settings[key] then return false end
    end
    return true
end

-- Keep identity, progress, and remaining information in separate regions
-- when space permits. Collapse empty groups before assigning pixel widths.
function addon.BuildInlineGroups(settings, width, fields)
    local groups = {}
    local names = {"identity", "progress", "percent", "remaining", "counts"}
    local function AddGroup(...)
        local group = {}
        for i = 1, select("#", ...) do
            local index = select(i, ...)
            local name = names[index]
            if settings[addon.InlineFieldSettings[index]] and fields[name] then
                group[#group + 1] = fields[name]
            end
        end
        if #group > 0 then groups[#groups + 1] = group end
    end
    local enabled = 0
    for index, key in ipairs(addon.InlineFieldSettings) do
        if settings[key] and fields[names[index]] then enabled = enabled + 1 end
    end
    -- Minimal layouts read best as a single centered line at any width.
    if width < 530 or enabled <= 2 then
        AddGroup(1, 2, 3, 4, 5)
    elseif width < 830 then
        AddGroup(1)
        AddGroup(2, 3, 4, 5)
    else
        AddGroup(1)
        AddGroup(2, 3)
        AddGroup(4, 5)
    end
    return groups
end

-- Candidates contain only enabled fields, with no orphan separators.
-- Try full wording, then shorter wording, then remove the least important
-- field until the measured text fits. Never substitute a disabled field.
function addon.InlineLabelCandidates(group)
    local candidates, seen, active = {}, {}, {}
    local function Add(short)
        local parts = {}
        for _, field in ipairs(active) do
            parts[#parts + 1] = short and field[2] or field[1]
        end
        local value = table.concat(parts, "  •  ")
        if value ~= "" and not seen[value] then
            candidates[#candidates + 1] = value
            seen[value] = true
        end
    end
    for _, field in ipairs(group) do active[#active + 1] = field end
    Add(false)
    while #active > 0 do
        Add(true)
        local lowest = 1
        for i = 2, #active do
            if active[i][3] < active[lowest][3] then lowest = i end
        end
        table.remove(active, lowest)
    end
    return candidates
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
