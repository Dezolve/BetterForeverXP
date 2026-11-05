local ADDON_NAME, addon = ...

-- Native Settings canvas with a scrollable, intentionally spaced layout.
-- All controls remain hand-built for WoW Forever's 1.60.1 client.
local panel
local category
local content
local checkboxes = {}
local sliders = {}
local formatButtons = {}
local textModeButtons = {}
local refreshing = false

local CARD_WIDTH = 540
local BUTTON_WIDTH = 158
local BUTTON_GAP = 12

local function Label(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function Paint(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function AddSection(title, subtitle, offset, height)
    local section = CreateFrame("Frame", nil, content)
    section:SetSize(CARD_WIDTH, height)
    section:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -offset)

    local background = Paint(section, "BACKGROUND", 0.065, 0.085, 0.13, 0.54)
    background:SetAllPoints()

    local hairline = Paint(section, "BORDER", 0.34, 0.46, 0.59, 0.46)
    hairline:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    hairline:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    hairline:SetHeight(1)

    local accent = Paint(section, "BORDER", 0.31, 0.72, 0.96, 0.85)
    accent:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -1)
    accent:SetSize(3, 36)

    Label(section, title, 18, -14, "GameFontNormal")
    local description = Label(section, subtitle, 18, -38, "GameFontHighlightSmall")
    description:SetTextColor(0.74, 0.78, 0.84, 1)
    return section
end

local function ShowTooltip(control, description)
    GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
    GameTooltip:SetText(description, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function AddCheckbox(key, text, y, description, x, host)
    local check = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", host, "TOPLEFT", x or 18, y)
    check:SetSize(24, 24)
    local title = host:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("LEFT", check, "RIGHT", 6, 0)
    title:SetWidth(210)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(text)

    -- A transparent button over the caption makes the full option row clickable.
    local hit = CreateFrame("Button", nil, host)
    hit:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 3)
    hit:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, -3)
    hit:SetScript("OnClick", function() check:Click() end)
    if description then
        local enter = function(self) ShowTooltip(self, description) end
        local leave = function() GameTooltip:Hide() end
        check:SetScript("OnEnter", enter)
        check:SetScript("OnLeave", leave)
        hit:SetScript("OnEnter", enter)
        hit:SetScript("OnLeave", leave)
    end
    check:SetScript("OnClick", function(self)
        if not refreshing then addon.SetSetting(key, not not self:GetChecked()) end
    end)
    checkboxes[key] = check
    return check
end

local function AddSlider(key, text, y, low, high, step, suffix, host)
    local heading = Label(host, text, 22, y, "GameFontHighlight")
    heading:SetTextColor(0.86, 0.9, 0.96, 1)
    local valueLabel = host:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    valueLabel:SetPoint("TOPRIGHT", host, "TOPRIGHT", -25, y)
    valueLabel:SetWidth(105)
    valueLabel:SetJustifyH("RIGHT")
    local slider = CreateFrame("Slider", nil, host, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", host, "TOPLEFT", 30, y - 27)
    slider:SetSize(480, 17)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetScript("OnValueChanged", function(self, value)
        if refreshing then return end
        local rounded = math.floor(value / step + 0.5) * step
        rounded = math.max(low, math.min(high, rounded))
        if addon.SetSetting(key, rounded) then
            valueLabel:SetText((key == "scale" and string.format("%.2f", rounded) or tostring(rounded)) .. suffix)
        end
    end)
    sliders[key] = { control = slider, value = valueLabel, suffix = suffix }
end

-- Restrained blue highlight for the selected value; no disabled gray buttons.
local function ChoiceButton(parent, title, x, y, description, action)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_WIDTH, 29)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local base = Paint(button, "BACKGROUND", 0.09, 0.12, 0.17, 0.92)
    base:SetAllPoints()
    local selected = Paint(button, "ARTWORK", 0.13, 0.28, 0.42, 0.90)
    selected:SetAllPoints()
    selected:Hide()

    local selectedEdge = Paint(button, "OVERLAY", 0.41, 0.79, 0.99, 0.95)
    selectedEdge:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    selectedEdge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    selectedEdge:SetWidth(3)
    selectedEdge:Hide()

    local hover = Paint(button, "OVERLAY", 0.56, 0.71, 0.87, 0.15)
    hover:SetAllPoints()
    hover:Hide()

    local caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("CENTER", button, "CENTER", 0, 0)
    caption:SetWidth(BUTTON_WIDTH - 12)
    caption:SetJustifyH("CENTER")
    caption:SetText(title)

    button:SetScript("OnClick", action)
    button:SetScript("OnEnter", function(self)
        hover:Show()
        if description then ShowTooltip(self, description) end
    end)
    button:SetScript("OnLeave", function()
        hover:Hide()
        if description then GameTooltip:Hide() end
    end)
    return {control = button, caption = caption, selected = selected, edge = selectedEdge, label = title}
end

local function AddTextModeButton(mode, title, x, description, host)
    textModeButtons[mode] = ChoiceButton(host, title, x, -79, description,
        function() addon.SetSetting("textMode", mode) end)
end

local function AddFormatButton(key, text, x, host)
    formatButtons[key] = ChoiceButton(host, text, x, -138, nil,
        function() addon.SetSetting("numberFormat", key) end)
end

local function RefreshChoice(choice, isSelected)
    choice.selected:SetShown(isSelected)
    choice.edge:SetShown(isSelected)
    choice.caption:SetTextColor(isSelected and 1 or 0.79,
        isSelected and 0.95 or 0.84, isSelected and 0.78 or 0.91, 1)
end

function addon.InitializeOptions()
    if panel then return end

    panel = CreateFrame("Frame", "BetterForeverXPOptionsPanel")
    panel.name = "Better Forever XP"
    panel:SetSize(630, 520)

    local scroll = CreateFrame("ScrollFrame", "BetterForeverXPOptionsScrollFrame",
        panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -33, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(572, 889)
    scroll:SetScrollChild(content)

    Label(content, "Better Forever XP", 20, -17, "GameFontNormalLarge")
    local subtitle = Label(content, "CLASSIC PROGRESS  |cff748ba7•|r  PERSONALIZED FOR YOU", 21, -49, "GameFontHighlightSmall")
    subtitle:SetTextColor(0.72, 0.81, 0.93, 1)
    local line = Paint(content, "ARTWORK", 0.34, 0.58, 0.78, 0.50)
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -77)
    line:SetSize(536, 1)

    local behavior = AddSection("DISPLAY & INTERACTION",
        "Choose how your XP and watched reputation bar behaves.", 92, 196)
    AddCheckbox("enabled", "Enable progress bar", -67,
        "Display Better Forever XP for experience or watched reputation.", 18, behavior)
    AddCheckbox("showMidpointMarker", "Show 50% marker", -67,
        "Show the classic silver-steel chevron marking the bar's halfway point.", 280, behavior)
    AddCheckbox("locked", "Lock position and resizing", -108,
        "Prevent accidental movement and resizing. Shift-drag still moves the bar.", 18, behavior)
    AddCheckbox("hideBlizzard", "Hide Blizzard's XP bar", -108,
        "Show or hide Blizzard's XP bar immediately (or after combat).", 280, behavior)
    AddCheckbox("showQuestPreview", "Preview completed quest XP", -149,
        "Show XP from quests ready to turn in as a gold extension of your current XP. Does not include unfinished quests.", 18, behavior)
    AddCheckbox("enableReputation", "Enable XP / Reputation", -149,
        "Left-click the bar to switch modes. Choosing Show as Experience Bar in WoW's Reputation panel also switches directly to that faction. Right-click opens options. Your choice is saved per character.", 280, behavior)

    local textCard = AddSection("TEXT & NUMBERS",
        "Pick how much detail appears directly on the bar.", 305, 176)
    Label(textCard, "Bar text", 22, -63, "GameFontNormalSmall")
    AddTextModeButton("tooltip", "Tooltip only", 20,
        "Clean bar. Hover to see detailed progress in the tooltip.", textCard)
    AddTextModeButton("hover", "Text on hover", 20 + BUTTON_WIDTH + BUTTON_GAP,
        "Show labels on the bar while hovering, plus the tooltip.", textCard)
    AddTextModeButton("always", "Always visible", 20 + (BUTTON_WIDTH + BUTTON_GAP) * 2,
        "Keep progress labels on the bar at all times.", textCard)
    Label(textCard, "XP number format", 22, -123, "GameFontNormalSmall")
    AddFormatButton("short", "Compact", 20, textCard)
    AddFormatButton("commas", "With commas", 20 + BUTTON_WIDTH + BUTTON_GAP, textCard)
    AddFormatButton("exact", "Exact", 20 + (BUTTON_WIDTH + BUTTON_GAP) * 2, textCard)

    local dimensions = AddSection("BAR DIMENSIONS",
        "Adjust the bar's size, height, and visual scale.", 498, 275)
    AddSlider("width", "Width", -68, 300, 1600, 10, " px", dimensions)
    AddSlider("height", "Height", -141, 10, 120, 1, " px", dimensions)
    AddSlider("scale", "Overall UI scale (including text)", -214, 0.5, 3, 0.05, "x", dimensions)

    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetSize(186, 28)
    reset:SetPoint("TOPLEFT", content, "TOPLEFT", 34, -802)
    reset:SetText("Reset position & size")
    reset:SetScript("OnClick", function() addon.ResetPosition(); addon.RefreshOptions() end)

    local resetAll = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetAll:SetSize(180, 28)
    resetAll:SetPoint("LEFT", reset, "RIGHT", 14, 0)
    resetAll:SetText("Reset all defaults")
    resetAll:SetScript("OnClick", function() addon.ResetAll() end)

    local footnote = Label(content,
        "Changes apply immediately. Right-click the bar to return to these settings.",
        34, -850, "GameFontHighlightSmall")
    footnote:SetTextColor(0.69, 0.77, 0.86, 1)

    panel.OnRefresh = function()
        local db = addon.GetSettings()
        if not db then return end
        refreshing = true
        for key, check in pairs(checkboxes) do check:SetChecked(db[key]) end
        for key, data in pairs(sliders) do
            data.control:SetValue(db[key])
            data.value:SetText((key == "scale" and string.format("%.2f", db[key]) or tostring(db[key])) .. data.suffix)
        end
        for key, data in pairs(formatButtons) do
            local selected = db.numberFormat == key
            RefreshChoice(data, selected)
        end
        for mode, data in pairs(textModeButtons) do
            local selected = db.textMode == mode
            RefreshChoice(data, selected)
        end
        refreshing = false
    end
    panel.OnDefault = function() addon.ResetAll() end
    panel.OnCommit = function() end -- All settings apply and save immediately.

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    panel.OnRefresh()
end

addon.RefreshOptions = function()
    if panel and panel.OnRefresh then panel.OnRefresh() end
end

addon.OpenOptions = function()
    if not panel then addon.InitializeOptions() end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
