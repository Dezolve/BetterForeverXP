local ADDON_NAME, addon = ...

local defaults = {
    enabled = true, locked = false,
    point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 155,
    width = 1100, height = 16, scale = 1,
    numberFormat = "short", hideBlizzard = true, showMidpointMarker = true,
    version = 6,
}

local db
local charDB
local bar, fill, restedFill, spark
local resizeHandles = {}
local restedEndMarker
local midpointMarker
local textLayer
local tickLayer, tickMarks = nil, {}
local leftText, centerText, rightText
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

local function AddBorder(frame)
    local top = MakeTexture(frame, "BORDER", 0.33, 0.42, 0.55, 0.9)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    local bottom = MakeTexture(frame, "BORDER", 0.01, 0.02, 0.04, 1)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    local left = MakeTexture(frame, "BORDER", 0.08, 0.10, 0.14, 1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    local right = MakeTexture(frame, "BORDER", 0.08, 0.10, 0.14, 1)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
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

    local background = MakeTexture(bar, "BACKGROUND", 0.012, 0.017, 0.025, 0.97)
    background:SetAllPoints(); AddBorder(bar)

    restedFill = CreateFrame("StatusBar", nil, bar)
    restedFill:SetPoint("TOPLEFT", 1, -1); restedFill:SetPoint("BOTTOMRIGHT", -1, 1)
    restedFill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    restedFill:SetFrameLevel(bar:GetFrameLevel() + 1)
    -- Blizzard-style hierarchy: earned XP is bright electric blue, rested
    -- coverage is secondary dark navy, and untouched space is near-black.
    restedFill:SetStatusBarColor(0.025, 0.075, 0.18, 0.99); restedFill:EnableMouse(false)

    fill = CreateFrame("StatusBar", nil, bar)
    fill:SetAllPoints(restedFill); fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetFrameLevel(bar:GetFrameLevel() + 2)
    fill:SetStatusBarColor(0.22, 0.48, 1.00, 1.00); fill:EnableMouse(false)
    local sheen = fill:CreateTexture(nil, "ARTWORK")
    sheen:SetColorTexture(0.55, 0.80, 1, 0.16)
    sheen:SetPoint("TOPLEFT"); sheen:SetPoint("TOPRIGHT"); sheen:SetHeight(2)

    spark = fill:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(0.78, 0.67, 0.43, 0.98); spark:SetWidth(2)
    spark:SetPoint("TOP"); spark:SetPoint("BOTTOM")

    tickLayer = CreateFrame("Frame", nil, bar)
    tickLayer:SetAllPoints(); tickLayer:SetFrameLevel(bar:GetFrameLevel() + 5); tickLayer:EnableMouse(false)
    for index = 1, 19 do
        -- A dark stroke reads over earned XP; its faint light edge reads over
        -- rested and empty sections. Together they remain visible everywhere.
        local dark = tickLayer:CreateTexture(nil, "OVERLAY")
        dark:SetColorTexture(0.01, 0.025, 0.07, 0.52)
        dark:SetWidth(1)
        local light = tickLayer:CreateTexture(nil, "OVERLAY")
        light:SetColorTexture(0.72, 0.84, 1, 0.18)
        light:SetWidth(1)
        tickMarks[index] = { dark = dark, light = light }
    end
    restedEndMarker = tickLayer:CreateTexture(nil, "OVERLAY")
    restedEndMarker:SetColorTexture(0.78, 0.67, 0.43, 0.96)
    restedEndMarker:SetWidth(2)

    -- The 50% stone ornament gets its own mouse-transparent frame so players
    -- can hide every layer of the chip without affecting XP ticks or text.
    -- Dedicated marker frame includes the part ABOVE the XP bar: a frame
    -- bounded to the bar itself can clip the colored stone/bevel there.
    -- Keep it mouse-transparent and separate from the text/resize layers.
    midpointMarker = CreateFrame("Frame", nil, bar)
    midpointMarker:SetSize(32, 18)
    midpointMarker:SetPoint("BOTTOM", bar, "TOP", 0, -4)
    midpointMarker:SetFrameLevel(tickLayer:GetFrameLevel() + 1)
    midpointMarker:EnableMouse(false)
    -- Slate stone inside aged bronze. Keep the previously lowered 1.5px
    -- position, now with all of the ornament inside its rendering bounds.
    local function AddStoneMidpointMarker()
        local widths = {20, 20, 18, 16, 14, 12, 10, 8, 6, 4}
        for index, width in ipairs(widths) do
            local y = 7.5 - index -- lowered 1.5px: 6.5px above to 2.5px inside

            -- Recessed shadow: creates the look of a metal fitting mounted
            -- directly to the XP bar instead of floating over the terrain.
            local shadow = MakeTexture(midpointMarker, "BACKGROUND", 0.015, 0.022, 0.035, 0.66)
            shadow:SetPoint("CENTER", bar, "TOP", 0, y - 0.8)
            shadow:SetSize(width + 2, 1.8)

            -- Warm, desaturated bronze silhouette follows the tapered tip.
            local rim = MakeTexture(midpointMarker, "BORDER", 0.58, 0.46, 0.29, 1)
            rim:SetPoint("CENTER", bar, "TOP", 0, y)
            rim:SetSize(width, 1.5)

            -- Real stone-colored inset, with the bronze edge still showing
            -- on each side. The final tip stays solid bronze.
            if index > 1 and index < #widths then
                local shade = 0.40 - (index - 2) * 0.018
                local stone = MakeTexture(midpointMarker, "ARTWORK", shade * 0.97, shade * 1.05, shade * 1.11, 1)
                stone:SetPoint("CENTER", bar, "TOP", 0, y + 0.05)
                stone:SetSize(width - 3, 1.15)

                -- Edge lighting adds a beveled, hand-carved appearance.
                local light = MakeTexture(midpointMarker, "OVERLAY", 0.75, 0.73, 0.64, 0.85)
                light:SetPoint("CENTER", bar, "TOP", -(width / 2) + 1.15, y + 0.15)
                light:SetSize(1.2, 1.1)
                local recess = MakeTexture(midpointMarker, "OVERLAY", 0.23, 0.19, 0.15, 0.75)
                recess:SetPoint("CENTER", bar, "TOP", (width / 2) - 1.0, y - 0.1)
                recess:SetSize(1, 1.1)
            end
        end

        -- A bright top lip and a tiny dark seam fasten the chip to the bar.
        local bevel = MakeTexture(midpointMarker, "OVERLAY", 0.81, 0.70, 0.48, 0.95)
        bevel:SetPoint("CENTER", bar, "TOP", 0, 6.9)
        bevel:SetSize(17, 1.1)
        local seam = MakeTexture(midpointMarker, "BACKGROUND", 0.04, 0.055, 0.08, 0.8)
        seam:SetPoint("CENTER", bar, "TOP", 0, -2)
        seam:SetSize(7, 0.8)
    end
    AddStoneMidpointMarker()
    midpointMarker:SetShown(db.showMidpointMarker)

    -- A separate child frame keeps every label above both status-bar fills.
    textLayer = CreateFrame("Frame", nil, bar)
    textLayer:SetAllPoints(); textLayer:SetFrameLevel(bar:GetFrameLevel() + 10); textLayer:EnableMouse(false)
    leftText, centerText, rightText = MakeLabel(textLayer, "LEFT"), MakeLabel(textLayer, "CENTER"), MakeLabel(textLayer, "RIGHT")

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
        -- Slightly extend the interactive rectangle without changing visuals.
        handle:SetHitRectInsets(-2, -2, -2, -2)
        -- Keep the hit area invisible until hovered, but make its feedback
        -- genuinely discoverable. Prior 28x2/2x10/12x2 marks were so small
        -- that the user could barely tell which edge was interactive.
        local indicator = CreateFrame("Frame", nil, handle)
        indicator:SetAllPoints()
        indicator:EnableMouse(false)
        if mode == "height" then
            -- Keep the wide bottom-edge hover area but show only a compact,
            -- centered gold line with a faint shadow. This handle is below
            -- the bar and cannot intercept the bar's drag or XP tooltip.
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
            local backing = MakeTexture(indicator, "OVERLAY", 0.025, 0.045, 0.075, 0.90)
            backing:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1)
            local horizontal = MakeTexture(indicator, "OVERLAY", 1, 0.78, 0.30, 1)
            horizontal:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -3, 3)
            local vertical = MakeTexture(indicator, "OVERLAY", 1, 0.78, 0.30, 1)
            vertical:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -3, 3)
            local detailH = MakeTexture(indicator, "OVERLAY", 1, 0.87, 0.53, 1)
            detailH:SetPoint("BOTTOMRIGHT", backing, "BOTTOMRIGHT", -9, 10)
            local detailV = MakeTexture(indicator, "OVERLAY", 1, 0.87, 0.53, 1)
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

    -- Larger, mostly external hover zones are easier to discover/catch while
    -- preserving the bar body for movement and XP tooltip interactions.
    -- Bottom-right corner has a higher frame level than the width zone.
    AddResizeHandle("width", "RIGHT", 10, 0)
    -- The 24px-high hitbox and its 2px insets end at the bottom border.
    -- Nothing overlaps the XP bar's draggable and tooltip-bearing body.
    AddResizeHandle("height", "BOTTOM", 0, -14)
    AddResizeHandle("corner", "BOTTOMRIGHT", 12, -10)
    resizeHandles.width:SetSize(24, math.max(28, db.height + 12))
    -- Hover anywhere just BELOW the bar to reveal the centered grip.
    -- The visual stays compact; the invisible target spans the bar width.
    resizeHandles.height:SetSize(db.width, 24)
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
        if bar.ShowDetails then bar:ShowDetails() end
    end)
    bar:SetScript("OnLeave", function()
        tooltipVisible = false
        if GameTooltip:GetOwner() == bar then GameTooltip:Hide() end
    end)
end

local function ApplyLayout()
    CreateBar(); bar:SetScale(db.scale); bar:SetSize(db.width, db.height)
    midpointMarker:SetShown(db.showMidpointMarker)
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
        if fontPath then label:SetFont(fontPath, fontSize, "OUTLINE") end
        label:ClearAllPoints()
    end
    if db.width < 530 then
        leftText:Hide(); rightText:Hide(); centerText:Show()
        centerText:SetPoint("CENTER", textLayer, "CENTER")
        centerText:SetSize(db.width - 12, db.height)
    elseif db.width < 830 then
        leftText:Show(); centerText:Show(); rightText:Hide()
        leftText:SetPoint("LEFT", textLayer, "LEFT", 6, 0)
        leftText:SetSize(db.width * 0.23 - 12, db.height)
        centerText:SetPoint("RIGHT", textLayer, "RIGHT", -6, 0)
        centerText:SetSize(db.width * 0.77 - 12, db.height)
    else
        leftText:Show(); centerText:Show(); rightText:Show()
        leftText:SetPoint("LEFT", textLayer, "LEFT", 6, 0)
        leftText:SetSize(db.width * 0.15 - 12, db.height)
        centerText:SetPoint("CENTER", textLayer, "CENTER")
        centerText:SetSize(db.width * 0.43 - 12, db.height)
        rightText:SetPoint("RIGHT", textLayer, "RIGHT", -6, 0)
        rightText:SetSize(db.width * 0.42 - 12, db.height)
    end
    resizeHandles.width:SetHeight(math.max(28, db.height + 12))
    resizeHandles.height:SetWidth(db.width)
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

    for index, tick in ipairs(tickMarks) do
        local x = db.width * index / 20
        tick.dark:ClearAllPoints()
        tick.dark:SetPoint("TOP", tickLayer, "TOPLEFT", x, -1)
        tick.dark:SetPoint("BOTTOM", tickLayer, "BOTTOMLEFT", x, 1)
        tick.light:ClearAllPoints()
        tick.light:SetPoint("TOP", tickLayer, "TOPLEFT", x + 1, -1)
        tick.light:SetPoint("BOTTOM", tickLayer, "BOTTOMLEFT", x + 1, 1)
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
    local remaining, percent = math.max(0, xpMax - xp), xp / xpMax * 100
    local barsLeft = remaining / xpMax * 20
    local innerWidth = math.max(1, db.width - 2)
    local earnedWidth = innerWidth * xp / xpMax
    local restedAmount = math.min(rested, remaining)
    local restedWidth = innerWidth * restedAmount / xpMax
    fill:SetMinMaxValues(0, xpMax); fill:SetValue(xp)
    restedFill:SetMinMaxValues(0, xpMax); restedFill:SetValue(math.min(xpMax, xp + rested)); restedFill:SetShown(rested > 0)
    restedEndMarker:ClearAllPoints()
    restedEndMarker:SetPoint("TOP", restedFill, "TOPLEFT", earnedWidth + restedWidth, 0)
    restedEndMarker:SetPoint("BOTTOM", restedFill, "BOTTOMLEFT", earnedWidth + restedWidth, 0)
    restedEndMarker:SetShown(restedWidth >= 2)
    spark:ClearAllPoints(); spark:SetPoint("CENTER", fill, "LEFT", earnedWidth, 0)
    spark:SetShown(xp > 0 and xp < xpMax)
    leftText:SetText("Level " .. (UnitLevel("player") or 0))
    if db.width < 530 then
        centerText:SetText(string.format("%.1f%%  •  %s XP left", percent, Short(remaining)))
    elseif db.width < 830 then
        centerText:SetText(Short(xp) .. " / " .. Short(xpMax) .. string.format("  •  %.1f%%", percent))
    else
        local display = db.numberFormat == "short" and ExactAndShort or FormatNumber
        centerText:SetText(display(xp) .. " / " .. display(xpMax) .. string.format("  •  %.1f%%", percent))
        rightText:SetText(display(remaining) .. " XP left  •  " .. FormatBars(barsLeft) .. " bars left")
    end
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
    elseif key == "locked" or key == "enabled" or key == "hideBlizzard" or key == "showMidpointMarker" then
        if type(value) ~= "boolean" then return false end
        db[key] = value
        if key == "locked" then UpdateResizeHandles()
        elseif key == "enabled" then UpdateBar()
        elseif key == "showMidpointMarker" then midpointMarker:SetShown(value)
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
