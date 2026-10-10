local ADDON_NAME, addon = ...

local defaults = {
    enabled = true, locked = false,
    point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 155,
    width = 1100, height = 16, scale = 1,
    numberFormat = "short", hideBlizzard = true, showMidpointMarker = true,
    hoverTextOnly = true,
    version = 6,
}

local db
local charDB
local bar, fill, restedFill, spark, fillSheen, fillShade
local resizeHandles = {}
local restedEndMarker
local midpointMarker
local textLayer
local tickLayer, tickMarks = nil, {}
local tubeRim, tubeBackground, endCapCuts, capPaints = nil, nil, {}, {}
local leftText, centerText, rightText
local textScrims = {}
local eventFrame = CreateFrame("Frame")
local sessionStart, sessionXP = GetTime(), 0
local lastXP, lastXPMax
local tooltipVisible = false
local levelClockLast = GetTime()

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff70d6ffBetter Forever XP:|r " .. tostring(message))
end

local function MergeDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then target[key] = value end
    end
end

local function Commas(value)
    local text = tostring(math.floor(math.max(0, tonumber(value) or 0) + 0.5))
    while true do
        local count
        text, count = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        if count == 0 then return text end
    end
end

local function Short(value)
    value = math.max(0, tonumber(value) or 0)
    local divisor, suffix
    if value >= 1000000000 then divisor, suffix = 1000000000, "B"
    elseif value >= 1000000 then divisor, suffix = 1000000, "M"
    elseif value >= 1000 then divisor, suffix = 1000, "K"
    else return tostring(math.floor(value + 0.5)) end

    local scaled = value / divisor
    if scaled >= 100 then return string.format("%.0f%s", scaled, suffix) end
    local text = string.format("%.1f", scaled):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    return text .. suffix
end

local function FormatNumber(value)
    if db and db.numberFormat == "commas" then return Commas(value) end
    if db and db.numberFormat == "exact" then
        return tostring(math.floor(math.max(0, tonumber(value) or 0) + 0.5))
    end
    return Short(value)
end

local function ExactAndShort(value)
    local exact = Commas(value)
    if (tonumber(value) or 0) >= 1000 then
        return exact .. " (" .. Short(value) .. ")"
    end
    return exact
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 or seconds == math.huge then return "—" end
    seconds = math.floor(seconds + 0.5)
    if seconds >= 3600 then
        return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
    elseif seconds >= 60 then
        return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    end
    return seconds .. "s"
end

local function RoundedHalfBars(value)
    return math.floor(math.max(0, value) * 2 + 0.5) / 2
end

local function FormatBars(value)
    local rounded = RoundedHalfBars(value)
    if rounded == math.floor(rounded) then return tostring(math.floor(rounded)) end
    return string.format("%.1f", rounded)
end

local function MakeTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- The modern Classic client can shade texture vertices directly. If an older
-- Forever client lacks SetGradient/CreateColor, retain solid XP fills while
-- still displaying the subtle top/bottom tube highlights.
local function ApplyVerticalGradient(texture, bottom, top)
    if not texture or not texture.SetGradient or not CreateColor then return false end
    local ok = pcall(texture.SetGradient, texture, "VERTICAL",
        CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
        CreateColor(top[1], top[2], top[3], top[4] or 1))
    return ok
end

local function ApplyTubeStatusColor(statusBar, bottom, top, flat)
    statusBar:SetStatusBarColor(1, 1, 1, 1)
    if not ApplyVerticalGradient(statusBar:GetStatusBarTexture(), bottom, top) then
        statusBar:SetStatusBarColor(flat[1], flat[2], flat[3], 1)
    end
end

-- A shallow recessed groove in the tube: the dark one-pixel core has
-- top-to-bottom shading, and an adjacent faint highlight catches the upper
-- curve. Dark notches and white glints stay readable across blue, purple,
-- rested navy, and the empty track without becoming bright full-height bars.
local tickPalettes = {
    earned = {
        coreBottom = {0.00, 0.00, 0.00, 0.88}, coreTop = {0.08, 0.10, 0.16, 0.62},
        rimBottom = {0.70, 0.78, 0.90, 0.12}, rimTop = {1.00, 1.00, 1.00, 0.38},
        coreFlat = {0.00, 0.00, 0.00, 0.72}, rimFlat = {1.00, 1.00, 1.00, 0.24},
    },
    rested = {
        coreBottom = {0.00, 0.00, 0.00, 0.90}, coreTop = {0.07, 0.09, 0.14, 0.66},
        rimBottom = {0.62, 0.72, 0.86, 0.13}, rimTop = {1.00, 1.00, 1.00, 0.40},
        coreFlat = {0.00, 0.00, 0.00, 0.74}, rimFlat = {1.00, 1.00, 1.00, 0.25},
    },
    empty = {
        coreBottom = {0.00, 0.00, 0.00, 0.92}, coreTop = {0.09, 0.10, 0.13, 0.68},
        rimBottom = {0.58, 0.66, 0.78, 0.12}, rimTop = {1.00, 1.00, 1.00, 0.42},
        coreFlat = {0.00, 0.00, 0.00, 0.76}, rimFlat = {1.00, 1.00, 1.00, 0.26},
    },
}
local function ApplyBeveledTick(tick, region)
    if tick.region == region then return end
    tick.region = region
    local palette = tickPalettes[region]
    -- The center groove is the main landmark underneath Blizzard's silver
    -- marker; keep it a touch stronger without increasing its physical width.
    local coreTop, rimTop = palette.coreTop, palette.rimTop
    if tick.isCenter then
        coreTop = {coreTop[1], coreTop[2], coreTop[3], math.min(1, coreTop[4] + 0.18)}
        rimTop = {rimTop[1], rimTop[2], rimTop[3], math.min(1, rimTop[4] + 0.16)}
    end
    if not ApplyVerticalGradient(tick.core, palette.coreBottom, coreTop) then
        local flat = palette.coreFlat
        tick.core:SetColorTexture(flat[1], flat[2], flat[3], flat[4])
    end
    if not ApplyVerticalGradient(tick.rim, palette.rimBottom, rimTop) then
        local flat = palette.rimFlat
        tick.rim:SetColorTexture(flat[1], flat[2], flat[3], flat[4])
    end
    -- The white reflection is intentionally strongest in the center, with
    -- near-black sockets at both ends of every recessed 5% groove.
    tick.glint:SetColorTexture(1, 1, 1,
        tick.isCenter and 0.82 or (region == "earned" and 0.64 or 0.76))
end

-- The visible rounded tube is a continuous center track with two shaped
-- endcaps. All fills, the 5% divisions and the steel frame use this geometry.
local MAX_CORNER_RADIUS = 16

local function TubeGeometry(height, width)
    local radius = math.min(MAX_CORNER_RADIUS, math.max(3, math.floor(height * 0.44 + 0.5)))
    return radius, radius, math.max(1, width - radius * 2)
end

-- Rested earned XP matches the deeper, saturated Blizzard Classic cobalt.
-- Both the center StatusBar and rounded cap strips use these exact stops.
local earnedBlue = {
    bottom = {0.025, 0.105, 0.50},
    top = {0.11, 0.31, 0.90},
    flat = {0.065, 0.22, 0.75},
}

local capColors = {
    blue = earnedBlue,
    purple = {
        bottom = {0.29, 0.10, 0.40}, top = {0.64, 0.36, 0.77}, flat = {0.48, 0.19, 0.61},
    },
    rested = {
        bottom = {0.013, 0.042, 0.105}, top = {0.085, 0.17, 0.31}, flat = {0.025, 0.075, 0.18},
    },
}

-- Gradient coordinates on trimmed endcap columns need to match the full
-- height of the StatusBar: otherwise the gradient stretches into a stripe.
local function TrimmedGradientStops(colors, fraction)
    local function Between(top, bottom)
        return {
            top[1] * (1 - fraction) + bottom[1] * fraction,
            top[2] * (1 - fraction) + bottom[2] * fraction,
            top[3] * (1 - fraction) + bottom[3] * fraction,
        }
    end
    return Between(colors.bottom, colors.top), Between(colors.top, colors.bottom)
end

local function SetCapPaint(cap, region)
    if cap.region == region then return end
    cap.region = region
    if not region then
        cap.paint:Hide()
        return
    end
    local colors = capColors[region]
    -- Reset the original base tint before shading. SetGradient multiplies
    -- SetColorTexture, which previously darkened caps twice.
    cap.paint:SetColorTexture(1, 1, 1, 1)
    local bottom, top = TrimmedGradientStops(colors, cap.trimFraction or 0)
    if not ApplyVerticalGradient(cap.paint, bottom, top) then
        cap.paint:SetColorTexture(colors.flat[1], colors.flat[2], colors.flat[3], 1)
    end
    cap.paint:Show()
end

local function UpdateTubeCaps(height, width)
    local radius, visualLeft, visualWidth = TubeGeometry(height, width)
    local cuts = {}
    local railInset = radius
    for i = 0, MAX_CORNER_RADIUS - 1 do
        local trimHeight = 0
        if i < radius then
            local x = radius - i - 0.5
            trimHeight = math.max(0,
                math.floor(radius - math.sqrt(radius * radius - x * x) + 0.5))
            trimHeight = math.min(trimHeight, math.floor((height - 2) / 2))
        end
        cuts[i] = trimHeight
        if i < radius and trimHeight == 0 and railInset == radius then
            railInset = i
        end
    end

    -- The track background is NOT a rectangle hiding behind opaque black
    -- corners. Its center is rectangular and only the actual visible pixels
    -- of each rounded end are painted. Outside those columns is transparent.
    tubeBackground:ClearAllPoints()
    tubeBackground:SetPoint("TOPLEFT", bar, "TOPLEFT", visualLeft, 0)
    tubeBackground:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", visualLeft + visualWidth, 0)
    restedFill:ClearAllPoints()
    restedFill:SetPoint("TOPLEFT", bar, "TOPLEFT", visualLeft, -1)
    restedFill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", visualLeft + visualWidth, 1)

    for _, cap in ipairs(capPaints) do
        local trim = cuts[cap.column]
        if cap.column < radius then
            local trimFraction = trim / math.max(1, height)
            if cap.trimFraction ~= trimFraction then
                cap.trimFraction = trimFraction
                cap.region = nil
            end
            local backgroundBottom, backgroundTop = TrimmedGradientStops(
                {bottom = {0.006, 0.012, 0.022}, top = {0.055, 0.077, 0.12}},
                trimFraction)
            cap.background:SetColorTexture(1, 1, 1, 1)
            if not ApplyVerticalGradient(cap.background, backgroundBottom, backgroundTop) then
                cap.background:SetColorTexture(0.012, 0.017, 0.025, 0.97)
            end
            for _, texture in ipairs({cap.background, cap.paint}) do
                texture:ClearAllPoints()
                if cap.right then
                    texture:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -cap.column, -trim)
                else
                    texture:SetPoint("TOPLEFT", bar, "TOPLEFT", cap.column, -trim)
                end
                texture:SetSize(1, math.max(1, height - 2 * trim))
            end
            cap.background:Show()
            cap.paint:SetShown(cap.region ~= nil)
        else
            cap.background:Hide()
            cap.paint:Hide()
        end
    end

    local outerTrim = cuts[0]
    for _, cap in ipairs(endCapCuts) do
        local trim = cuts[cap.column]
        if cap.column < radius and trim > 0 then
            cap.edge:Show()
            cap.edge:SetSize(1, 1)
            cap.edge:ClearAllPoints()
            local offset = cap.right and -cap.column or cap.column
            if cap.top then
                local anchor = cap.right and "TOPRIGHT" or "TOPLEFT"
                cap.edge:SetPoint(anchor, cap.host, anchor, offset, -trim)
            else
                local anchor = cap.right and "BOTTOMRIGHT" or "BOTTOMLEFT"
                cap.edge:SetPoint(anchor, cap.host, anchor, offset, trim)
            end
        else
            cap.edge:Hide()
        end
    end

    local function SetHorizontalRail(texture, top, inset, y)
        texture:ClearAllPoints()
        if top then
            texture:SetPoint("TOPLEFT", tubeRim, "TOPLEFT", inset, y)
            texture:SetPoint("TOPRIGHT", tubeRim, "TOPRIGHT", -inset, y)
        else
            texture:SetPoint("BOTTOMLEFT", tubeRim, "BOTTOMLEFT", inset, y)
            texture:SetPoint("BOTTOMRIGHT", tubeRim, "BOTTOMRIGHT", -inset, y)
        end
    end
    SetHorizontalRail(tubeRim.topEdge, true, railInset, 0)
    SetHorizontalRail(tubeRim.bottomEdge, false, railInset, 0)
    SetHorizontalRail(tubeRim.topInsetShade, true, railInset + 1, -1)
    SetHorizontalRail(tubeRim.innerTopHighlight, true, railInset + 2, -2)
    SetHorizontalRail(tubeRim.innerBottomShade, false, railInset + 2, 2)

    for _, side in ipairs({{tubeRim.leftEdge, "LEFT"}, {tubeRim.rightEdge, "RIGHT"}}) do
        local edge, align = side[1], side[2]
        edge:ClearAllPoints()
        edge:SetPoint("TOP" .. align, tubeRim, "TOP" .. align, 0, -outerTrim - 1)
        edge:SetPoint("BOTTOM" .. align, tubeRim, "BOTTOM" .. align, 0, outerTrim + 1)
    end
    tubeRim.topEdge:SetHeight(1)
    tubeRim.bottomEdge:SetHeight(1)
    tubeRim.topInsetShade:SetHeight(math.max(1, math.min(3, math.floor(height * 0.08 + 0.5))))
    tubeRim.innerTopHighlight:SetHeight(1)
    tubeRim.innerBottomShade:SetHeight(math.max(1, math.min(5, math.floor(height * 0.11 + 0.5))))
end

local function MakeLabel(parent, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local fontPath, fontSize = text:GetFont()
    if fontPath and fontSize then
        text:SetFont(fontPath, fontSize, "OUTLINE")
    end
    text:SetJustifyH(justify); text:SetJustifyV("MIDDLE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1); text:SetShadowOffset(1, -1)
    text:SetWordWrap(false)
    return text
end

-- Keep exact XP figures available in the tooltip, but never allow the
-- bar's three text regions to overflow into one another at large font sizes.
local function SetFittingLabel(label, candidates)
    local available = math.max(1, (label:GetWidth() or 0) - 8)
    for _, value in ipairs(candidates) do
        label:SetText(value)
        local width
        if label.GetUnboundedStringWidth then
            width = label:GetUnboundedStringWidth()
        elseif label.GetStringWidth then
            width = label:GetStringWidth()
        end
        if not width or width <= available then return end
    end
    -- Last candidate is deliberately very short. If even that cannot fit,
    -- leave a blank label rather than drawing into an adjacent region.
    label:SetText("")
end

-- The bar itself is the default information display; detailed labels
-- appear on hover. Users who prefer permanent text can disable this option.
-- The tooltip still contains the full, exact XP values in either mode.
local function UpdateTextVisibility()
    if textLayer then
        textLayer:SetShown(not db.hoverTextOnly or tooltipVisible)
    end
end

local function UpdateTextScrims()
    for label, scrim in pairs(textScrims) do
        if not label:IsShown() or not label:GetText() or label:GetText() == "" or db.height < 26 then
            scrim:Hide()
        else
            local textWidth = label.GetUnboundedStringWidth
                and label:GetUnboundedStringWidth() or label:GetStringWidth()
            local width = math.max(0, math.min(label:GetWidth(), textWidth + 14))
            if width < 4 then
                scrim:Hide()
            else
                scrim:SetWidth(width)
                scrim:SetHeight(math.min(db.height - 4, math.max(16, label:GetStringHeight() + 8)))
                scrim:Show()
            end
        end
    end
end

local function UpdateResizeHandles()
    for _, handle in pairs(resizeHandles) do
        handle:SetShown(db and not db.locked)
    end
end

-- Resize from the bottom or right while fixing the top-left corner.
-- The height hit zone stays OUTSIDE the bottom edge so the entire bar
-- remains available for movement and the regular XP tooltip.
local function AnchorForResizing()
    local parentScale = UIParent:GetEffectiveScale()
    local frameScale = bar:GetEffectiveScale()
    if not parentScale or parentScale <= 0 or not frameScale or frameScale <= 0 then
        return false
    end
    local left, top = bar:GetLeft(), bar:GetTop()
    local parentLeft, parentTop = UIParent:GetLeft(), UIParent:GetTop()
    if not left or not top or not parentLeft or not parentTop then return false end
    local ratio = parentScale / frameScale
    local x = left - parentLeft * ratio
    local y = top - parentTop * ratio
    db.point, db.relativePoint, db.x, db.y = "TOPLEFT", "TOPLEFT", x, y
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    return true
end

local ApplyResizeLayout

local function CreateBar()
    if bar then return end
    bar = CreateFrame("Frame", "BetterForeverXPBar", UIParent)
    bar:SetClampedToScreen(true); bar:SetMovable(true); bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton"); bar:SetFrameStrata("MEDIUM")

    -- A shallow vertical gradient gives the empty track some depth while
    -- keeping its original dark, readable appearance.
    tubeBackground = MakeTexture(bar, "BACKGROUND", 1, 1, 1, 1)
    if not ApplyVerticalGradient(tubeBackground,
        {0.006, 0.012, 0.022, 0.98}, {0.055, 0.077, 0.12, 0.98}) then
        tubeBackground:SetColorTexture(0.012, 0.017, 0.025, 0.97)
    end
    -- The rounded track has no full-width background to leave square corners.

    restedFill = CreateFrame("StatusBar", nil, bar)
    -- Its horizontal anchors are assigned from TubeGeometry at layout time.
    -- The matching cap strips extend the earned/rested fill to the very ends.
    restedFill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    restedFill:SetFrameLevel(bar:GetFrameLevel() + 1)
    -- Blizzard-style hierarchy: earned XP is blue while rested, purple
    -- when not rested; remaining rested coverage is dark navy, and
    -- untouched space is near-black.
    ApplyTubeStatusColor(restedFill,
        {0.013, 0.042, 0.105}, {0.085, 0.17, 0.31}, {0.025, 0.075, 0.18})
    restedFill:EnableMouse(false)
    local restedSheen = restedFill:CreateTexture(nil, "ARTWORK")
    restedSheen:SetColorTexture(0.40, 0.58, 0.84, 0.16)
    restedSheen:SetPoint("TOPLEFT", restedFill:GetStatusBarTexture(), "TOPLEFT")
    restedSheen:SetPoint("TOPRIGHT", restedFill:GetStatusBarTexture(), "TOPRIGHT")
    restedSheen:SetHeight(2)

    fill = CreateFrame("StatusBar", nil, bar)
    fill:SetAllPoints(restedFill); fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetFrameLevel(bar:GetFrameLevel() + 2)
    ApplyTubeStatusColor(fill, earnedBlue.bottom, earnedBlue.top, earnedBlue.flat)
    fill:EnableMouse(false)
    -- Both bevel bands follow the moving status-bar texture, not the whole
    -- bar frame, so highlights stop precisely where the earned XP stops.
    fillSheen = fill:CreateTexture(nil, "ARTWORK")
    fillSheen:SetColorTexture(0.78, 0.90, 1, 0.22)
    fillSheen:SetPoint("TOPLEFT", fill:GetStatusBarTexture(), "TOPLEFT")
    fillSheen:SetPoint("TOPRIGHT", fill:GetStatusBarTexture(), "TOPRIGHT")
    fillSheen:SetHeight(2)
    fillShade = fill:CreateTexture(nil, "ARTWORK")
    fillShade:SetColorTexture(0.015, 0.035, 0.075, 0.24)
    fillShade:SetPoint("BOTTOMLEFT", fill:GetStatusBarTexture(), "BOTTOMLEFT")
    fillShade:SetPoint("BOTTOMRIGHT", fill:GetStatusBarTexture(), "BOTTOMRIGHT")
    fillShade:SetHeight(3)

    spark = fill:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(0.78, 0.67, 0.43, 0.98); spark:SetWidth(2)
    spark:SetPoint("TOP"); spark:SetPoint("BOTTOM")

    -- Complete both rounded ends with genuinely shaped track and fill
    -- columns. No opaque corner covers or unsupported alpha-mask APIs.
    local capFillLayer = CreateFrame("Frame", nil, bar)
    capFillLayer:SetAllPoints(bar)
    capFillLayer:SetFrameLevel(bar:GetFrameLevel() + 3)
    capFillLayer:EnableMouse(false)
    for _, right in ipairs({false, true}) do
        for column = 0, MAX_CORNER_RADIUS - 1 do
            local backgroundCap = MakeTexture(bar, "BACKGROUND", 1, 1, 1, 1)
            local paint = MakeTexture(capFillLayer, "ARTWORK", 1, 1, 1, 1)
            paint:Hide()
            capPaints[#capPaints + 1] = {
                background = backgroundCap, paint = paint,
                right = right, column = column,
            }
        end
    end

    -- Add a restrained metal tube frame above the status-bar fills. Using a
    -- separate mouse-transparent frame keeps these lines visible on earned,
    -- rested, and empty sections without covering the XP text or 5% grooves.
    tubeRim = CreateFrame("Frame", nil, bar)
    tubeRim:SetAllPoints(bar)
    tubeRim:SetFrameLevel(bar:GetFrameLevel() + 4)
    tubeRim:EnableMouse(false)

    -- Metallic outer rails and curved endcaps share one contour palette.
    -- Positions are set together by UpdateTubeCaps, never independently.
    local topEdge = MakeTexture(tubeRim, "OVERLAY", 0.40, 0.47, 0.58, 0.96)
    tubeRim.topEdge = topEdge

    local bottomEdge = MakeTexture(tubeRim, "OVERLAY", 0.28, 0.34, 0.44, 0.96)
    tubeRim.bottomEdge = bottomEdge

    local leftEdge = MakeTexture(tubeRim, "OVERLAY", 0.30, 0.37, 0.47, 0.96)
    leftEdge:SetWidth(1)
    tubeRim.leftEdge = leftEdge
    local rightEdge = MakeTexture(tubeRim, "OVERLAY", 0.30, 0.37, 0.47, 0.96)
    rightEdge:SetWidth(1)
    tubeRim.rightEdge = rightEdge

    local topInsetShade = MakeTexture(tubeRim, "OVERLAY", 0.005, 0.008, 0.016, 0.89)
    tubeRim.topInsetShade = topInsetShade

    local innerTopHighlight = MakeTexture(tubeRim, "OVERLAY", 1.00, 1.00, 1.00, 0.18)
    tubeRim.innerTopHighlight = innerTopHighlight

    local innerBottomShade = MakeTexture(tubeRim, "OVERLAY", 0.00, 0.00, 0.00, 0.24)
    tubeRim.innerBottomShade = innerBottomShade

    tickLayer = CreateFrame("Frame", nil, bar)
    tickLayer:SetAllPoints(); tickLayer:SetFrameLevel(bar:GetFrameLevel() + 5); tickLayer:EnableMouse(false)
    -- Twenty XP segments: each separator has a deep full-height groove,
    -- a highlight immediately beside it, a brighter white center reflection,
    -- and short, nearly black sockets at the tube's top and bottom.
    for index = 1, 19 do
        local core = MakeTexture(tickLayer, "OVERLAY", 0.0, 0.0, 0.0, 0.8)
        local rim = MakeTexture(tickLayer, "OVERLAY", 1, 1, 1, 0.28)
        rim:SetPoint("TOPLEFT", core, "TOPRIGHT", 0, 0)
        rim:SetPoint("BOTTOMLEFT", core, "BOTTOMRIGHT", 0, 0)
        local glint = MakeTexture(tickLayer, "OVERLAY", 1, 1, 1, 0.68)
        glint:SetPoint("CENTER", rim, "CENTER", 0, 0)
        tickMarks[index] = {
            core = core, rim = rim, glint = glint,
            isCenter = index == 10,
        }
    end
    -- Draw only the curved metallic contour over each genuinely shaped end.
    -- No cap.cut overlays: the empty rounded corners stay transparent.
    local endCapTrim = CreateFrame("Frame", nil, bar)
    endCapTrim:SetAllPoints(bar)
    endCapTrim:SetFrameLevel(bar:GetFrameLevel() + 7)
    endCapTrim:EnableMouse(false)
    for _, right in ipairs({false, true}) do
        for _, top in ipairs({false, true}) do
            for column = 0, MAX_CORNER_RADIUS - 1 do
                local edge
                if top then
                    edge = MakeTexture(endCapTrim, "OVERLAY", 0.40, 0.47, 0.58, 0.96)
                else
                    edge = MakeTexture(endCapTrim, "OVERLAY", 0.28, 0.34, 0.44, 0.96)
                end
                endCapCuts[#endCapCuts + 1] = {
                    edge = edge, column = column, right = right,
                    top = top, host = endCapTrim,
                }
            end
        end
    end

    restedEndMarker = tickLayer:CreateTexture(nil, "OVERLAY")
    restedEndMarker:SetColorTexture(0.78, 0.67, 0.43, 0.96)
    restedEndMarker:SetWidth(2)

    -- Use Blizzard's own single-piece, filled silver exhaustion-tick art.
    -- A native texture has a seamless silhouette at all UI scales; dozens of
    -- rotated rectangles produced a hollow-looking, misaligned chevron.
    -- Keep this decorative marker pinned to the exact center of the XP track.
    midpointMarker = CreateFrame("Frame", nil, bar)
    midpointMarker:SetSize(32, 32)
    -- Anchor the native artwork to the actual 50% divider, not an
    -- independently calculated position on the frame.
    midpointMarker:SetPoint("CENTER", tickMarks[10].core, "TOP", 0, -4)
    midpointMarker:SetFrameLevel(tickLayer:GetFrameLevel() + 1)
    midpointMarker:EnableMouse(false)

    local function AddMetalMidpointMarker()
        local arrow = midpointMarker:CreateTexture(nil, "OVERLAY")
        arrow:SetAllPoints(midpointMarker)
        arrow:SetTexture("Interface\\MainMenuBar\\UI-ExhaustionTickNormal")
        arrow:SetVertexColor(1, 1, 1, 1)
    end
    AddMetalMidpointMarker()
    midpointMarker:SetShown(db.showMidpointMarker)

    -- A separate child frame keeps every label above both status-bar fills.
    textLayer = CreateFrame("Frame", nil, bar)
    textLayer:SetAllPoints(); textLayer:SetFrameLevel(bar:GetFrameLevel() + 10); textLayer:EnableMouse(false)
    UpdateTextVisibility()
    leftText, centerText, rightText = MakeLabel(textLayer, "LEFT"), MakeLabel(textLayer, "CENTER"), MakeLabel(textLayer, "RIGHT")
    -- Small, soft scrims sit behind the actual rendered words, not across
    -- the bar. They tone down white divider glints under tall XP labels.
    for _, label in ipairs({leftText, centerText, rightText}) do
        local scrim = MakeTexture(textLayer, "ARTWORK", 0, 0, 0, 0.30)
        ApplyVerticalGradient(scrim, {0, 0, 0, 0.30}, {0, 0, 0, 0.18})
        if label == leftText then
            scrim:SetPoint("LEFT", label, "LEFT")
        elseif label == rightText then
            scrim:SetPoint("RIGHT", label, "RIGHT")
        else
            scrim:SetPoint("CENTER", label, "CENTER")
        end
        textScrims[label] = scrim
        scrim:Hide()
    end

    -- Invisible edge hit zones, with subtle affordances shown only while the
    -- pointer is hovering or dragging. No permanent floating W/H/+ buttons.
    -- Bottom edge grows downward; right edge grows rightward; bottom-right grows down/right.
    local MIN_WIDTH, MAX_WIDTH = 300, 1600
    local MIN_HEIGHT, MAX_HEIGHT = 10, 120
    local activeResize

    -- Right-click from the bar body or its hover-resize hit zones opens the
    -- existing Settings panel, including when the bar is locked.
    local function OpenBarOptions(button)
        if button ~= "RightButton" then return end
        if GameTooltip:GetOwner() == bar then GameTooltip:Hide() end
        if addon.OpenOptions then addon.OpenOptions() end
    end

    local function FinishResize(handle)
        if not activeResize or activeResize.handle ~= handle then return end
        handle:SetScript("OnUpdate", nil)
        activeResize = nil
        if not handle:IsMouseOver() and handle.resizeIndicator then
            handle.resizeIndicator:Hide()
        end
        if addon.RefreshOptions then addon.RefreshOptions() end
    end

    local function BeginResize(handle, mode, button)
        if button ~= "LeftButton" or not db or db.locked then return end
        if not AnchorForResizing() then return end
        local cursorX, cursorY = GetCursorPosition()
        local scale = bar:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        activeResize = {
            handle = handle, mode = mode, startX = cursorX, startY = cursorY,
            startWidth = db.width, startHeight = db.height, effectiveScale = scale
        }
        handle.resizeIndicator:Show()
        handle:SetScript("OnUpdate", function(self)
            if not activeResize or activeResize.handle ~= self then return end
            -- Release must finish even when the mouse ends outside the zone.
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                FinishResize(self)
                return
            end
            local mx, my = GetCursorPosition()
            local dx = (mx - activeResize.startX) / activeResize.effectiveScale
            local dy = (my - activeResize.startY) / activeResize.effectiveScale
            local width, height = activeResize.startWidth, activeResize.startHeight
            if mode ~= "height" then
                -- Respect the screen boundary and the supported width range.
                local available = math.max(MIN_WIDTH, UIParent:GetWidth() / db.scale - db.x)
                width = math.floor(math.max(MIN_WIDTH,
                    math.min(MAX_WIDTH, available, width + dx)) + 0.5)
            end
            if mode ~= "width" then
                -- Both the bottom edge and bottom-right corner follow the
                -- cursor downward, growing from a stationary top-left corner.
                local available = math.max(MIN_HEIGHT,
                    UIParent:GetHeight() / db.scale + db.y)
                height = math.floor(math.max(MIN_HEIGHT,
                    math.min(MAX_HEIGHT, available, height - dy)) + 0.5)
            end
            if width ~= db.width or height ~= db.height then
                db.width, db.height = width, height
                ApplyResizeLayout()
            end
        end)
    end

    local function AddResizeHandle(mode, point, x, y)
        local handle = CreateFrame("Button", nil, bar)
        handle:SetPoint(point, bar, point, x, y)
        handle:SetFrameLevel(bar:GetFrameLevel() + (mode == "corner" and 30 or 25))
        handle:EnableMouse(true)
        -- Keep the height handle strictly outside the bar, with no expanded
        -- hit rectangle. The other controls retain their forgiving insets.
        if mode == "height" then
            handle:SetHitRectInsets(0, 0, 0, 0)
        else
            handle:SetHitRectInsets(-2, -2, -2, -2)
        end
        -- Keep the hit area invisible until hovered, but make its feedback
        -- genuinely discoverable. Prior 28x2/2x10/12x2 marks were so small
        -- that the user could barely tell which edge was interactive.
        local indicator = CreateFrame("Frame", nil, handle)
        indicator:SetAllPoints()
        indicator:EnableMouse(false)
        if mode == "height" then
            -- Only a compact center grab target is interactive: the rest of
            -- the bar remains available for drag and XP tooltip at 10px height.
            -- The small gold line and faint shadow are hover-only.
            local shadow = MakeTexture(indicator, "OVERLAY", 0.02, 0.03, 0.05, 0.35)
            shadow:SetPoint("CENTER", 0, 0)
            shadow:SetSize(44, 7)
            local grip = MakeTexture(indicator, "OVERLAY", 1, 0.82, 0.38, 1)
            grip:SetPoint("CENTER", 0, 0)
            grip:SetSize(40, 5)
        elseif mode == "width" then
            -- A proper vertical edge highlight, with a thicker central grip.
            local backing = MakeTexture(indicator, "OVERLAY", 0.03, 0.06, 0.10, 0.85)
            backing:SetPoint("TOP", 0, -1)
            backing:SetPoint("BOTTOM", 0, 1)
            backing:SetWidth(11)
            local edge = MakeTexture(indicator, "OVERLAY", 1, 0.76, 0.28, 1)
            edge:SetPoint("TOP", 0, -1)
            edge:SetPoint("BOTTOM", 0, 1)
            edge:SetWidth(3)
            local gripBack = MakeTexture(indicator, "OVERLAY", 0.06, 0.09, 0.13, 1)
            gripBack:SetPoint("CENTER", 0, 0)
            gripBack:SetSize(16, 30)
            local grip = MakeTexture(indicator, "OVERLAY", 1, 0.82, 0.38, 1)
            grip:SetPoint("CENTER", 0, 0)
            grip:SetSize(4, 24)
        else
            -- Put the corner artwork back on its easy-to-grab, outside
            -- bottom-right handle. Scale only the visible glyph/plate with
            -- bar height; the 30px invisible hit target never shrinks.
            -- The old near-black plate swallowed the gold L-grip against
            -- an empty XP segment. Put the backing BEHIND the golden strokes,
            -- with explicit overlay sublayers so no panel can dim their color.
            local backing = MakeTexture(indicator, "BACKGROUND", 0.06, 0.09, 0.13, 0.76)
            backing:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1)
            local horizontal = MakeTexture(indicator, "OVERLAY", 1, 0.84, 0.42, 1)
            horizontal:SetDrawLayer("OVERLAY", 3)
            horizontal:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -3, 3)
            local vertical = MakeTexture(indicator, "OVERLAY", 1, 0.84, 0.42, 1)
            vertical:SetDrawLayer("OVERLAY", 3)
            vertical:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -3, 3)
            local detailH = MakeTexture(indicator, "OVERLAY", 1, 0.94, 0.67, 1)
            detailH:SetDrawLayer("OVERLAY", 4)
            detailH:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -9, 10)
            local detailV = MakeTexture(indicator, "OVERLAY", 1, 0.94, 0.67, 1)
            detailV:SetDrawLayer("OVERLAY", 4)
            detailV:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -10, 9)
            handle.resizeCornerVisuals = {
                backing = backing, horizontal = horizontal, vertical = vertical,
                detailH = detailH, detailV = detailV,
            }
        end
        indicator:Hide()
        handle.resizeIndicator = indicator
        handle:SetScript("OnEnter", function(self)
            if db and not db.locked then self.resizeIndicator:Show() end
        end)
        handle:SetScript("OnLeave", function(self)
            if not activeResize or activeResize.handle ~= self then
                self.resizeIndicator:Hide()
            end
        end)
        handle:SetScript("OnMouseDown", function(self, button)
            BeginResize(self, mode, button)
        end)
        handle:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then OpenBarOptions(button)
            else FinishResize(self) end
        end)
        handle:SetScript("OnHide", function(self)
            FinishResize(self)
            self.resizeIndicator:Hide()
        end)
        resizeHandles[mode] = handle
    end

    -- Small, external resize targets leave the entire XP bar available for
    -- dragging and tooltip interactions, especially at 10–16px bar heights.
    -- Bottom-right corner has a higher frame level than the width zone.
    AddResizeHandle("width", "RIGHT", 10, 0)
    -- Center-only 96×18px height hitbox, 5px clear of the bottom border.
    -- No full-width invisible hit strip to intercept a click on the bar.
    AddResizeHandle("height", "BOTTOM", 0, -14)
    AddResizeHandle("corner", "BOTTOMRIGHT", 12, -10)
    resizeHandles.width:SetSize(24, math.max(28, db.height + 12))
    resizeHandles.height:SetSize(96, 18)
    resizeHandles.corner:SetSize(30, 30)
    UpdateResizeHandles()

    bar:SetScript("OnMouseUp", function(_, button)
        OpenBarOptions(button)
    end)
    bar:SetScript("OnDragStart", function(self)
        -- Shift-drag is an escape hatch that always works, even after the bar
        -- has been locked to prevent accidental movement.
        if not db.locked or IsShiftKeyDown() then self:StartMoving() end
    end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
    end)
    bar:SetScript("OnEnter", function()
        tooltipVisible = true
        UpdateTextVisibility()
        UpdateTextScrims()
        if bar.ShowDetails then bar:ShowDetails() end
    end)
    bar:SetScript("OnLeave", function()
        tooltipVisible = false
        UpdateTextVisibility()
        if GameTooltip:GetOwner() == bar then GameTooltip:Hide() end
    end)
end

local function ApplyLayout()
    CreateBar(); bar:SetScale(db.scale); bar:SetSize(db.width, db.height)
    midpointMarker:SetShown(db.showMidpointMarker)
    UpdateTextVisibility()
    bar:ClearAllPoints(); bar:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    -- Never allow the three text regions to overlap. Compact layouts
    -- progressively remove secondary detail as available width shrinks.
    -- Keep the established text sizes for 10-40 px bars, but let larger
    -- bars grow their labels rather than leaving 18 px text in a 120 px bar.
    local fontSize = math.max(8, math.min(18, db.height - 4))
    if db.height > 40 then
        fontSize = math.min(32, math.floor(18 + (db.height - 40) * 0.175 + 0.5))
    end
    for _, label in ipairs({ leftText, centerText, rightText }) do
        local fontPath = label:GetFont()
        -- Thick black outlines at larger sizes keep white XP labels legible
        -- even when a bright 5% glint happens to cross a glyph.
        if fontPath then
            label:SetFont(fontPath, fontSize,
                fontSize >= 14 and "THICKOUTLINE" or "OUTLINE")
        end
        label:ClearAllPoints()
    end
    -- Disjoint layout regions: never center a wide label over the right
    -- label's region. Every region gets its own padding and hard width.
    local inset = math.max(6, math.floor(db.width * 0.009 + 0.5))
    if db.width < 530 then
        leftText:Hide(); rightText:Hide(); centerText:Show()
        centerText:SetPoint("CENTER", textLayer, "CENTER")
        centerText:SetSize(db.width - inset * 2, db.height)
    elseif db.width < 830 then
        leftText:Show(); centerText:Show(); rightText:Hide()
        local leftZone = db.width * 0.25
        leftText:SetPoint("LEFT", textLayer, "LEFT", inset, 0)
        leftText:SetSize(leftZone - inset * 2, db.height)
        centerText:SetPoint("LEFT", textLayer, "LEFT", leftZone + inset, 0)
        centerText:SetSize(db.width - leftZone - inset * 2, db.height)
    else
        leftText:Show(); centerText:Show(); rightText:Show()
        local leftZone = db.width * 0.17
        local centerZone = db.width * 0.45
        leftText:SetPoint("LEFT", textLayer, "LEFT", inset, 0)
        leftText:SetSize(leftZone - inset * 2, db.height)
        centerText:SetPoint("LEFT", textLayer, "LEFT", leftZone + inset, 0)
        centerText:SetSize(centerZone - inset * 2, db.height)
        rightText:SetPoint("RIGHT", textLayer, "RIGHT", -inset, 0)
        rightText:SetSize(db.width - leftZone - centerZone - inset * 2, db.height)
    end
    resizeHandles.width:SetHeight(math.max(28, db.height + 12))
    -- Height handle stays centered at a fixed, compact width on every resize.
    -- Keep the original external corner-grab position and L shape, but
    -- resize the ARTWORK when the bar gets thin. This avoids a huge corner
    -- icon on a 10px bar without sacrificing the generous 30px hit area.
    local corner = resizeHandles.corner
    local glyphLength = math.max(12, math.min(24, db.height * 1.5))
    local stroke = db.height <= 12 and 2 or 4
    corner.resizeCornerVisuals.backing:SetSize(glyphLength + 6, glyphLength + 6)
    corner.resizeCornerVisuals.horizontal:SetSize(glyphLength, stroke)
    corner.resizeCornerVisuals.vertical:SetSize(stroke, glyphLength)
    corner.resizeCornerVisuals.detailH:SetSize(glyphLength * 0.5, math.max(2, stroke - 1))
    corner.resizeCornerVisuals.detailV:SetSize(math.max(2, stroke - 1), glyphLength * 0.5)
    UpdateResizeHandles()
    UpdateTubeCaps(db.height, db.width)

    -- Pixel-snap only the dark core; the softer highlight stays anchored to
    -- its edge. Width is exactly one physical pixel for each layer.
    local effectiveScale = tickLayer:GetEffectiveScale()
    if not effectiveScale or effectiveScale <= 0 then effectiveScale = 1 end
    local pixel = 1 / effectiveScale
    local _, visualLeft, visualWidth = TubeGeometry(db.height, db.width)
    for index, tick in ipairs(tickMarks) do
        tick.core:SetWidth(pixel)
        tick.rim:SetWidth(pixel)
        tick.glint:SetWidth(pixel)
        -- A single continuous groove, with a central white reflection.
        -- Removing stacked black end-blocks eliminates the dark gaps.
        local grooveHeight = math.max(2, db.height - 2)
        tick.glint:SetHeight(math.max(1, math.floor(grooveHeight * 0.65 + 0.5)))
        -- Every divider, including 50%, shares this exact physical-pixel
        -- grid. The Blizzard arrow follows tickMarks[10].core automatically.
        local x = math.floor(db.width * index / 20 * effectiveScale + 0.5) * pixel
        tick.core:ClearAllPoints()
        tick.core:SetPoint("TOP", tickLayer, "TOPLEFT", x, -1)
        tick.core:SetPoint("BOTTOM", tickLayer, "BOTTOMLEFT", x, 1)
    end
end

-- Called only when dimensions actually change during a drag. Keep the
-- same layout and marker calculations as the options panel and slash commands.
ApplyResizeLayout = function()
    ApplyLayout()
    if addon.UpdateBar then addon.UpdateBar() end
end

local hookedDefaultFrames = {}
-- Restore ONLY Blizzard frames our addon actually hid. Some native frames are
-- legitimately hidden by Blizzard (or another addon), so showing every known
-- status-bar frame when the checkbox is unchecked would be disruptive.
local hiddenDefaultFrames = {}
local defaultFrameNames = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "MainMenuExpBar", "MainMenuBarXPBar", "MainMenuBarExpBar" }
local function ApplyDefaultBarVisibility()
    -- Blizzard may protect managed UI frames during combat. Defer the toggle
    -- until combat ends instead of leaving a checkbox that seems ineffective.
    if InCombatLockdown and InCombatLockdown() then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for _, name in ipairs(defaultFrameNames) do
        local frame = _G[name]
        if frame and frame ~= bar and frame.Hide and frame.Show then
            if not hookedDefaultFrames[frame] then
                hookedDefaultFrames[frame] = true
                hooksecurefunc(frame, "Show", function(self)
                    if db and db.hideBlizzard then
                        if InCombatLockdown and InCombatLockdown() then
                            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                            return
                        end
                        hiddenDefaultFrames[self] = true
                        self:Hide()
                    end
                end)
            end
            if db.hideBlizzard then
                if frame:IsShown() then
                    hiddenDefaultFrames[frame] = true
                    frame:Hide()
                end
            elseif hiddenDefaultFrames[frame] then
                hiddenDefaultFrames[frame] = nil
                frame:Show()
            end
        end
    end
end

local function CompletedQuestXP()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return 0 end
    local total, count = 0, C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, count do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID then
            local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(info.questID)
            if ready and GetQuestLogRewardXP then
                local ok, reward = pcall(GetQuestLogRewardXP, info.questID)
                if ok and type(reward) == "number" then total = total + reward end
            end
        end
    end
    return total
end

-- XP needed to advance FROM each level in the original Vanilla/Classic curve.
-- Data: https://warcraft.wiki.gg/wiki/Experience_to_level (Vanilla/Classic).
-- WoW Forever may change progression: only use this table if the game's
-- ACTUAL UnitXPMax at the current level agrees with the table.
local classicXPToNext = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
    8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
    25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
    95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
    153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}

-- Prefer a runtime XP-by-level function when the current-level result matches
-- the in-game XP requirement; no such API is guaranteed on Classic clients.
-- If unavailable, the Classic table provides an estimated next-level percent.
-- Never silently divide by the current level requirement: that is incorrect.
local function NextLevelXPRequirement(level, currentXPMax)
    if type(level) ~= "number" or type(currentXPMax) ~= "number"
        or level < 1 or currentXPMax <= 0 then return nil end

    local function FromAPI(fn)
        if type(fn) ~= "function" then return nil end
        local okCurrent, current = pcall(fn, level)
        if not okCurrent or current ~= currentXPMax then return nil end
        local okNext, nextXPMax = pcall(fn, level + 1)
        if okNext and type(nextXPMax) == "number" and nextXPMax > 0 then
            return nextXPMax
        end
    end

    local nextXPMax =
        FromAPI(GetXPForLevel)
        or FromAPI(C_PlayerInfo and C_PlayerInfo.GetXPForLevel)
        or FromAPI(C_Experience and C_Experience.GetXPForLevel)
    if nextXPMax then return nextXPMax, false end

    if classicXPToNext[level] == currentXPMax and classicXPToNext[level + 1] then
        return classicXPToNext[level + 1], true
    end
    return nil
end

local function AccumulateLevelTime()
    local now = GetTime()
    if charDB then
        local elapsed = now - (levelClockLast or now)
        if elapsed > 0 and elapsed < 120 then
            charDB.levelSeconds = (charDB.levelSeconds or 0) + elapsed
        end
    end
    levelClockLast = now
end

local function SessionRate()
    local elapsed = math.max(1, GetTime() - sessionStart)
    if elapsed < 10 or sessionXP <= 0 then return 0 end
    return sessionXP / elapsed * 3600
end

local function ShowDetails()
    if not db or not bar or not bar:IsShown() then return end
    local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 0
    local remaining = math.max(0, xpMax - xp)
    local rested = GetXPExhaustion and (GetXPExhaustion() or 0) or 0
    local rate, questXP = SessionRate(), CompletedQuestXP()
    local questPercent = xpMax > 0 and questXP / xpMax * 100 or 0
    local projectedXP = math.min(xpMax, xp + questXP)
    local projectedPercent = xpMax > 0 and projectedXP / xpMax * 100 or 0
    -- Ready-quest XP beyond the current threshold belongs to the next
    -- level. Its percentage requires THAT level's XP cap, not this one's.
    local nextLevelXP = xpMax > 0 and math.max(0, xp + questXP - xpMax) or 0
    local nextXPMax, estimatedNextCap = NextLevelXPRequirement(UnitLevel("player"), xpMax)
    local nextLevelDisplay = Commas(nextLevelXP) .. " XP"
    if nextLevelXP == 0 then
        nextLevelDisplay = nextLevelDisplay .. "  (0.0%)"
    elseif nextXPMax then
        local percentNext = math.min(100, nextLevelXP / nextXPMax * 100)
        nextLevelDisplay = nextLevelDisplay .. string.format(estimatedNextCap and "  (~%.1f%%)" or "  (%.1f%%)", percentNext)
    else
        nextLevelDisplay = nextLevelDisplay .. "  (—)"
    end
    local restedPercent = xpMax > 0 and rested / xpMax * 100 or 0
    local restedBars = xpMax > 0 and rested / xpMax * 20 or 0
    local barsLeft = xpMax > 0 and remaining / xpMax * 20 or 0

    local function AddSection(title, r, g, b)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(title:upper(), r, g, b)
    end

    GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 8); GameTooltip:ClearLines()
    GameTooltip:AddLine("Better Forever XP  |cff8499b8• by Dezolve Labs|r", 0.45, 0.84, 1)
    GameTooltip:AddLine("Level " .. (UnitLevel("player") or 0) .. " Experience", 0.88, 0.92, 1)

    AddSection("Progress", 0.45, 0.84, 1)
    GameTooltip:AddDoubleLine("Current XP", Commas(xp) .. " / " .. Commas(xpMax), 0.72, 0.77, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("Complete", xpMax > 0 and string.format("%.2f%%", xp / xpMax * 100) or "—", 0.72, 0.77, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("Remaining", Commas(remaining), 0.72, 0.77, 0.86, 1, 0.82, 0.42)
    GameTooltip:AddDoubleLine("Bars left", FormatBars(barsLeft), 0.72, 0.77, 0.86, 1, 0.82, 0.42)

    AddSection("Bonuses & Ready Quests", 1, 0.76, 0.30)
    GameTooltip:AddDoubleLine("Rested XP", Commas(rested) .. string.format("  (%.1f%%)", restedPercent), 0.72, 0.77, 0.86, 0.42, 0.78, 1)
    GameTooltip:AddDoubleLine("Rested coverage", string.format("%.1f bars", restedBars), 0.72, 0.77, 0.86, 0.42, 0.78, 1)
    GameTooltip:AddDoubleLine("Completed quests", Commas(questXP) .. string.format(" XP  (+%.1f%%)", questPercent), 0.72, 0.77, 0.86, 1, 0.78, 0.32)
    GameTooltip:AddDoubleLine("After turn-ins", Commas(projectedXP) .. " / " .. Commas(xpMax) .. string.format("  (%.1f%%)", projectedPercent), 0.72, 0.77, 0.86, 1, 0.88, 0.48)
    GameTooltip:AddDoubleLine("XP into next level", nextLevelDisplay, 0.72, 0.77, 0.86, 0.55, 1, 0.64)

    AddSection("Leveling Pace", 0.55, 1, 0.64)
    GameTooltip:AddDoubleLine("Time this level", FormatTime(charDB and charDB.levelSeconds or 0), 0.72, 0.77, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session time", FormatTime(GetTime() - sessionStart), 0.72, 0.77, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session XP", Commas(sessionXP), 0.72, 0.77, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("XP per hour", Commas(rate), 0.72, 0.77, 0.86, 0.55, 1, 0.64)
    GameTooltip:AddDoubleLine("Estimated level", rate > 0 and FormatTime(remaining / rate * 3600) or "Waiting for XP gain", 0.72, 0.77, 0.86, 0.55, 1, 0.64)
    GameTooltip:AddLine(" ")
    if db.locked then
        GameTooltip:AddLine("Right-click for options • Shift-drag to move • /bfxp unlock", 0.55, 0.62, 0.72)
    else
        GameTooltip:AddLine("Right-click for options • drag to move • resize below/right edge", 0.55, 0.62, 0.72)
    end
    GameTooltip:Show()
end

local function XPAvailable()
    if not db.enabled then return false end
    if IsXPUserDisabled and IsXPUserDisabled() then return false end
    return (UnitXPMax("player") or 0) > 0
end

local function UpdateBar()
    CreateBar()
    if not XPAvailable() then bar:Hide(); return end
    local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 1
    local rested = GetXPExhaustion and (GetXPExhaustion() or 0) or 0
    -- Keep Blizzard's blue-when-rested / purple-when-unrested distinction,
    -- but shade each fill from a lighter upper arc to a darker lower arc.
    if rested > 0 then
        ApplyTubeStatusColor(fill, earnedBlue.bottom, earnedBlue.top, earnedBlue.flat)
        fillSheen:SetColorTexture(0.55, 0.72, 1.00, 0.18)
    else
        ApplyTubeStatusColor(fill,
            {0.29, 0.10, 0.40}, {0.64, 0.36, 0.77}, {0.48, 0.19, 0.61})
        fillSheen:SetColorTexture(0.88, 0.74, 0.96, 0.22)
    end
    local remaining, percent = math.max(0, xpMax - xp), xp / xpMax * 100
    local barsLeft = remaining / xpMax * 20
    local _, visualLeft, innerWidth = TubeGeometry(db.height, db.width)
    -- The visible tube runs from x=0 to the full configured width, including
    -- rounded caps. Convert absolute XP boundaries to inner StatusBar values
    -- so each 5% groove and the color change agree at exactly the same x.
    local earnedX = db.width * xp / xpMax
    local restedAmount = math.min(rested, remaining)
    local restedEndX = db.width * math.min(xpMax, xp + restedAmount) / xpMax
    local function InnerPosition(absoluteX)
        return math.max(0, math.min(innerWidth, absoluteX - visualLeft))
    end
    local earnedWidth = InnerPosition(earnedX)
    local restedEndWidth = InnerPosition(restedEndX)
    local restedWidth = math.max(0, restedEndWidth - earnedWidth)
    fill:SetMinMaxValues(0, innerWidth); fill:SetValue(earnedWidth)
    restedFill:SetMinMaxValues(0, innerWidth); restedFill:SetValue(restedEndWidth); restedFill:SetShown(rested > 0)
    restedEndMarker:ClearAllPoints()
    restedEndMarker:SetPoint("TOP", restedFill, "TOPLEFT", earnedWidth + restedWidth, 0)
    restedEndMarker:SetPoint("BOTTOM", restedFill, "BOTTOMLEFT", earnedWidth + restedWidth, 0)
    restedEndMarker:SetShown(restedWidth >= 2)
    -- Paint the curved ends with the SAME status colors as the inner tube:
    -- left end follows the first earned/rested pixel; the right end only
    -- colors in when progress (earned or rested) reaches the tube's end.
    local earnedCapColor = rested > 0 and "blue" or "purple"
    for _, cap in ipairs(capPaints) do
        local region
        local capX = cap.right and (db.width - cap.column - 0.5)
            or (cap.column + 0.5)
        if capX <= earnedX then
            region = earnedCapColor
        elseif rested > 0 and capX <= restedEndX then
            region = "rested"
        end
        SetCapPaint(cap, region)
    end
    -- Recolor only when a tick crosses an earned/rested/empty boundary.
    -- Each region gets its own low-contrast metallic groove gradient.
    for index, tick in ipairs(tickMarks) do
        local division = index / 20
        if division <= xp / xpMax then
            ApplyBeveledTick(tick, "earned")
        elseif division <= (xp + rested) / xpMax then
            ApplyBeveledTick(tick, "rested")
        else
            ApplyBeveledTick(tick, "empty")
        end
    end
    spark:ClearAllPoints(); spark:SetPoint("CENTER", fill, "LEFT", earnedWidth, 0)
    spark:SetShown(xp > 0 and xp < xpMax)
    local level = UnitLevel("player") or 0
    if leftText:IsShown() then
        SetFittingLabel(leftText, {"Level " .. level, "Lv " .. level, tostring(level)})
    end
    local pct = string.format("%.1f%%", percent)
    if db.width < 530 then
        SetFittingLabel(centerText, {
            pct .. "  •  " .. Short(remaining) .. " left",
            pct .. "  •  " .. Short(remaining),
            pct,
        })
    elseif db.width < 830 then
        SetFittingLabel(centerText, {
            Short(xp) .. " / " .. Short(xpMax) .. "  •  " .. pct,
            Short(xp) .. "/" .. Short(xpMax) .. " " .. pct,
            pct,
        })
    else
        local display = db.numberFormat == "short" and ExactAndShort or FormatNumber
        SetFittingLabel(centerText, {
            display(xp) .. " / " .. display(xpMax) .. "  •  " .. pct,
            Commas(xp) .. " / " .. Commas(xpMax) .. "  •  " .. pct,
            Short(xp) .. " / " .. Short(xpMax) .. "  •  " .. pct,
            Short(xp) .. "/" .. Short(xpMax),
            pct,
        })
        SetFittingLabel(rightText, {
            display(remaining) .. " XP left  •  " .. FormatBars(barsLeft) .. " bars left",
            Commas(remaining) .. " left  •  " .. FormatBars(barsLeft) .. " bars",
            Short(remaining) .. " left  •  " .. FormatBars(barsLeft) .. " bars",
            Short(remaining) .. " XP left",
            Short(remaining) .. " left",
            FormatBars(barsLeft) .. " bars",
        })
    end
    UpdateTextScrims()
    bar:Show()
    if tooltipVisible then ShowDetails() end
end

addon.UpdateBar = UpdateBar

local function RecordXP()
    local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 0
    if lastXP and lastXPMax then
        local gained = (xpMax ~= lastXPMax and xp < lastXP) and (math.max(0, lastXPMax - lastXP) + xp) or (xp - lastXP)
        if gained and gained > 0 then
            sessionXP = sessionXP + gained
            if charDB then charDB.sessionXP = sessionXP end
        end
    end
    lastXP, lastXPMax = xp, xpMax
end

local function ResetPosition()
    db.point, db.relativePoint, db.x, db.y = defaults.point, defaults.relativePoint, defaults.x, defaults.y
    db.width, db.height, db.scale = defaults.width, defaults.height, defaults.scale
    ApplyLayout(); UpdateBar()
end

-- Shared mutation path for the Settings panel and legacy slash commands.
local function SetSetting(key, value)
    if not db then return false end
    if key == "width" then
        if type(value) ~= "number" or value < 300 or value > 1600 then return false end
        db.width = math.floor(value + 0.5)
        ApplyLayout(); UpdateBar()
    elseif key == "height" then
        if type(value) ~= "number" or value < 10 or value > 120 then return false end
        db.height = math.floor(value + 0.5)
        ApplyLayout(); UpdateBar()
    elseif key == "scale" then
        if type(value) ~= "number" or value < 0.5 or value > 3 then return false end
        db.scale = math.floor(value * 100 + 0.5) / 100
        ApplyLayout()
    elseif key == "locked" or key == "enabled" or key == "hideBlizzard" or key == "showMidpointMarker" or key == "hoverTextOnly" then
        if type(value) ~= "boolean" then return false end
        db[key] = value
        if key == "locked" then UpdateResizeHandles()
        elseif key == "enabled" then UpdateBar()
        elseif key == "showMidpointMarker" then midpointMarker:SetShown(value)
        elseif key == "hoverTextOnly" then UpdateTextVisibility(); UpdateTextScrims()
        else ApplyDefaultBarVisibility() end
    elseif key == "numberFormat" then
        if value ~= "short" and value ~= "commas" and value ~= "exact" then return false end
        db.numberFormat = value
        UpdateBar()
    else
        return false
    end
    if addon.RefreshOptions then addon.RefreshOptions() end
    return true
end

addon.GetSettings = function() return db end
addon.SetSetting = SetSetting
addon.ResetPosition = ResetPosition
addon.ResetAll = function()
    if not db then return end
    db.enabled, db.locked = defaults.enabled, defaults.locked
    db.numberFormat, db.hideBlizzard = defaults.numberFormat, defaults.hideBlizzard
    db.showMidpointMarker = defaults.showMidpointMarker
    db.hoverTextOnly = defaults.hoverTextOnly
    ResetPosition()
    UpdateResizeHandles(); ApplyDefaultBarVisibility(); UpdateBar()
    if addon.RefreshOptions then addon.RefreshOptions() end
end

local function Help()
    Print("/bfxp lock | unlock | show | hide | reset")
    Print("/bfxp (open options) • width 300-1600 • height 10-120 • scale 0.5-3")
    Print("/bfxp format short | commas | exact")
    Print("/bfxp default on|off  (show or hide Blizzard's bar)")
end

SLASH_BETTERFOREVERXP1, SLASH_BETTERFOREVERXP2 = "/bfxp", "/betterforeverxp"
SlashCmdList.BETTERFOREVERXP = function(message)
    local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local number = tonumber(argument)
    if command == "" or command == "options" or command == "config" then
        if addon.OpenOptions then addon.OpenOptions() else Help() end
    elseif command == "lock" then SetSetting("locked", true); Print("bar locked")
    elseif command == "unlock" then SetSetting("locked", false); Print("bar unlocked; drag to move, hover edges to resize")
    elseif command == "show" then SetSetting("enabled", true)
    elseif command == "hide" then SetSetting("enabled", false)
    elseif command == "reset" then ResetPosition(); if addon.RefreshOptions then addon.RefreshOptions() end; Print("position and size reset")
    elseif command == "width" then
        if not SetSetting("width", number) then Help() end
    elseif command == "height" then
        if not SetSetting("height", number) then Help() end
    elseif command == "scale" then
        if not SetSetting("scale", number) then Help() end
    elseif command == "format" then
        if SetSetting("numberFormat", argument) then Print("number format: " .. argument) else Help() end
    elseif command == "default" and (argument == "on" or argument == "off") then
        SetSetting("hideBlizzard", argument == "off")
        Print("Blizzard bar: " .. argument .. " (applies immediately outside combat)")
    else Help() end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BetterForeverXPDB = BetterForeverXPDB or {}
        local oldVersion = BetterForeverXPDB.version or 0
        MergeDefaults(BetterForeverXPDB, defaults); db = BetterForeverXPDB
        BetterForeverXPCharDB = BetterForeverXPCharDB or {}
        charDB = BetterForeverXPCharDB
        local currentLevel = UnitLevel("player") or 0
        if charDB.level ~= currentLevel then
            charDB.level = currentLevel
            charDB.levelSeconds = 0
        end
        charDB.levelSeconds = charDB.levelSeconds or 0
        levelClockLast = GetTime()
        local now = GetTime()
        if charDB.sessionStartClock and charDB.sessionStartClock <= now then
            sessionStart = charDB.sessionStartClock
            sessionXP = charDB.sessionXP or 0
        else
            sessionStart = now
            sessionXP = 0
            charDB.sessionStartClock = sessionStart
            charDB.sessionXP = 0
        end
        -- Version 2 originally shipped locked, which made the new standalone
        -- bar feel immovable. Unlock existing installs once for easy placement.
        if oldVersion < 2 then db.locked = false end
        if oldVersion < 3 then
            if db.width == 820 then db.width = 1000 end
        end
        if oldVersion < 5 and db.width == 1000 then db.width = 1100 end
        db.version = 6
        CreateBar(); bar.ShowDetails = ShowDetails; ApplyLayout(); ApplyDefaultBarVisibility()
        if addon.InitializeOptions then addon.InitializeOptions() end
        lastXP, lastXPMax = UnitXP("player"), UnitXPMax("player")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
        eventFrame:RegisterEvent("PLAYER_LEVEL_UP"); eventFrame:RegisterEvent("UPDATE_EXHAUSTION"); eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
        UpdateBar()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyDefaultBarVisibility()
    elseif event == "PLAYER_XP_UPDATE" then RecordXP(); UpdateBar()
    elseif event == "PLAYER_LEVEL_UP" then
        AccumulateLevelTime()
        if charDB then
            charDB.level = tonumber(arg1) or UnitLevel("player") or 0
            charDB.levelSeconds = 0
        end
        lastXP, lastXPMax = nil, nil
        C_Timer.After(0.2, function() lastXP, lastXPMax = UnitXP("player"), UnitXPMax("player"); UpdateBar() end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- PLAYER_ENTERING_WORLD's first flag is true for a real login and
        -- false for /reload. Only a real login starts a new rate session.
        if arg1 and charDB then
            sessionStart = GetTime()
            sessionXP = 0
            charDB.sessionStartClock = sessionStart
            charDB.sessionXP = 0
        end
        ApplyDefaultBarVisibility(); C_Timer.After(0.5, UpdateBar)
    else UpdateBar() end
end)

C_Timer.NewTicker(1, function()
    AccumulateLevelTime()
    if charDB then
        charDB.sessionStartClock = sessionStart
        charDB.sessionXP = sessionXP
    end
    if db and tooltipVisible then ShowDetails() end
end)
