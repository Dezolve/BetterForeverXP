local ADDON_NAME, addon = ...

-- Hand-built canvas controls keep the panel compatible with modern Settings
-- without relying on patch-specific RegisterAddOnSetting signatures.
local panel
local category
local checkboxes = {}
local sliders = {}
local formatButtons = {}
local refreshing = false

local function Label(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function AddCheckbox(key, text, y, description, x)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", x or 24, y)
    check:SetSize(24, 24)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("LEFT", check, "RIGHT", 6, 0)
    title:SetText(text)
    if description then
        check.tooltipText = description
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(description, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    check:SetScript("OnClick", function(self)
        if not refreshing then addon.SetSetting(key, not not self:GetChecked()) end
    end)
    checkboxes[key] = check
    return check
end

local function AddSlider(key, text, y, low, high, step, suffix)
    Label(panel, text, 28, y)
    local valueLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueLabel:SetPoint("TOPRIGHT", panel, "TOPLEFT", 492, y)
    valueLabel:SetJustifyH("RIGHT")
    local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 34, y - 23)
    slider:SetSize(438, 17)
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

local function AddFormatButton(key, text, x)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(128, 26)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -421)
    button:SetText(text)
    button:SetScript("OnClick", function() addon.SetSetting("numberFormat", key) end)
    formatButtons[key] = { control = button, label = text }
end

function addon.InitializeOptions()
    if panel then return end

    panel = CreateFrame("Frame", "BetterForeverXPOptionsPanel")
    panel.name = "Better Forever XP"
    panel:SetSize(630, 520)
    Label(panel, "Better Forever XP", 20, -18, "GameFontNormalLarge")
    Label(panel, "Unlocked: drag to move. Hover below/right/bottom-right to resize.", 24, -46, "GameFontHighlightSmall")

    -- Two balanced rows avoid pushing the size sliders or reset buttons
    -- below the bottom of the Settings panel.
    AddCheckbox("enabled", "Enable custom XP bar", -72, "Display Better Forever XP when experience is available.")
    AddCheckbox("showMidpointMarker", "Show 50% stone marker", -72,
        "Show the carved-stone arrowhead at the halfway point of the XP bar.", 305)
    AddCheckbox("locked", "Lock position and resizing", -105, "Disable edge resizing and accidental movement.")
    AddCheckbox("hideBlizzard", "Hide Blizzard's XP bar", -105,
        "Restoring Blizzard's bar may require /reload.", 305)

    Label(panel, "Bar dimensions", 24, -179, "GameFontNormalLarge")
    AddSlider("width", "Width", -209, 300, 1600, 10, " px")
    AddSlider("height", "Height", -273, 10, 120, 1, " px")
    AddSlider("scale", "Overall UI scale (including text)", -337, 0.5, 3, 0.05, "x")

    Label(panel, "XP number format", 24, -396, "GameFontNormal")
    AddFormatButton("short", "Compact", 25)
    AddFormatButton("commas", "With commas", 165)
    AddFormatButton("exact", "Exact", 305)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(180, 26)
    reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -468)
    reset:SetText("Reset position & size")
    reset:SetScript("OnClick", function() addon.ResetPosition(); addon.RefreshOptions() end)

    local resetAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAll:SetSize(170, 26)
    resetAll:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    resetAll:SetText("Reset all defaults")
    resetAll:SetScript("OnClick", function() addon.ResetAll() end)

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
            data.control:SetText(selected and ("* " .. data.label) or data.label)
            data.control:SetEnabled(not selected)
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
