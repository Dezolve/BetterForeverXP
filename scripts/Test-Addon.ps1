[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = Join-Path $repositoryRoot 'BetterForeverXP'
$tocPath = Join-Path $addonRoot 'BetterForeverXP.toc'
$luaPath = Join-Path $addonRoot 'BetterForeverXP.lua'
$optionsPath = Join-Path $addonRoot 'Options.lua'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

Assert-Condition (Test-Path -LiteralPath $tocPath -PathType Leaf) 'Missing BetterForeverXP.toc.'
Assert-Condition (Test-Path -LiteralPath $luaPath -PathType Leaf) 'Missing BetterForeverXP.lua.'
Assert-Condition (Test-Path -LiteralPath $optionsPath -PathType Leaf) 'Missing Options.lua.'

if ($failures.Count -eq 0) {
    $toc = Get-Content -LiteralPath $tocPath -Raw
    $lua = Get-Content -LiteralPath $luaPath -Raw
    $options = Get-Content -LiteralPath $optionsPath -Raw

    foreach ($field in 'Interface', 'Title', 'Notes', 'Author', 'Version', 'SavedVariables') {
        Assert-Condition ($toc -match "(?m)^## $([regex]::Escape($field)):\s*\S") "TOC metadata is missing '$field'."
    }

    $versionMatch = [regex]::Match($toc, '(?m)^## Version:\s*(\S+)\s*$')
    Assert-Condition $versionMatch.Success 'Could not read a version from the TOC file.'
    if ($versionMatch.Success) {
        Assert-Condition ($versionMatch.Groups[1].Value -match '^\d+\.\d+\.\d+$') 'TOC version must use semantic versioning (for example, 2.4.1).'
    }

    $listedFiles = $toc -split "`r?`n" |
        Where-Object { $_ -and -not $_.StartsWith('##') } |
        ForEach-Object { $_.Trim() }

    Assert-Condition ($listedFiles.Count -gt 0) 'The TOC does not load any addon files.'
    foreach ($listedFile in $listedFiles) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $addonRoot $listedFile) -PathType Leaf) "TOC references missing file '$listedFile'."
    }

    Assert-Condition ($lua -match 'ADDON_LOADED') 'Addon does not register an initialization event.'
    Assert-Condition ($lua -match 'SLASH_BETTERFOREVERXP1') 'Addon slash command is not registered.'
    Assert-Condition ($lua -match 'local function OpenBarOptions\(button\)') 'Missing shared right-click options handler.'
    Assert-Condition ($lua -match 'if button ~= "RightButton" then return end') 'Options shortcut must only respond to right click.'
    Assert-Condition ($lua -match 'bar:SetScript\("OnMouseUp", function\(_, button\)') 'XP bar body must support right click.'
    Assert-Condition ($lua -match 'handle:SetScript\("OnMouseUp", function\(self, button\)') 'Resize zones must also support right click.'
    Assert-Condition ($lua -match 'if addon[.]OpenOptions then addon[.]OpenOptions\(\) end') 'Right click should open existing settings.'
    Assert-Condition ($lua -match 'Right-click for options') 'Tooltip should advertise right-click settings.'
    Assert-Condition ($lua -match 'if rested > 0 then\s+fill:SetStatusBarColor\(0[.]22, 0[.]48, 1[.]00, 1[.]00\)') 'Earned XP must be blue when rested XP remains.'
    Assert-Condition ($lua -match 'else\s+fill:SetStatusBarColor\(0[.]48, 0[.]19, 0[.]61, 1[.]00\)') 'Earned XP must turn purple when rested XP is zero.'
    Assert-Condition ($lua -match 'fillSheen:SetColorTexture\(0[.]78, 0[.]56, 0[.]88, 0[.]16\)') 'Unrested highlight must be tinted purple rather than blue.'
    Assert-Condition ($lua -match 'fillSheen = fill:CreateTexture') 'Earned XP highlight should be dynamically recolorable.'
    Assert-Condition ($lua -match 'eventFrame:RegisterEvent\("PLAYER_LEVEL_UP"\); eventFrame:RegisterEvent\("UPDATE_EXHAUSTION"\)') 'The XP bar must refresh when rested state changes.'
    Assert-Condition ($lua -match 'restedFill:SetShown\(rested > 0\)') 'Rested coverage must disappear when rested XP reaches zero.'

    Assert-Condition ($lua -match 'local nextLevelXP = xpMax > 0 and math[.]max\(0, xp [+] questXP - xpMax\) or 0') 'Next-level carryover must be the positive excess XP beyond the current level cap.'
    Assert-Condition ($lua -match 'local classicXPToNext = \{') 'Classic leveling XP curve data must be present.'
    Assert-Condition ($lua -match '400, 900, 1400, 2100, 2800, 3600') 'Classic table should match early-level XP values.'
    Assert-Condition ($lua -match '202300, 209800,') 'Classic table should cover levels 58 and 59.'
    Assert-Condition ($lua -match 'local function NextLevelXPRequirement\(level, currentXPMax\)') 'Missing validated next-level XP lookup.'
    Assert-Condition ($lua -match 'if not okCurrent or current ~= currentXPMax then return nil end') 'Runtime API data must match the current level.'
    Assert-Condition ($lua -match 'if classicXPToNext\[level\] == currentXPMax and classicXPToNext\[level [+] 1\] then') 'Only use a table percentage when the current cap matches the in-game cap.'
    Assert-Condition ($lua -match 'return classicXPToNext\[level [+] 1\], true') 'Table-based percent must use next-level XP cap.'
    Assert-Condition ($lua -match 'FromAPI\(C_PlayerInfo and C_PlayerInfo[.]GetXPForLevel\)') 'Check optional game XP API safely.'
    Assert-Condition ($lua -match 'FromAPI\(C_Experience and C_Experience[.]GetXPForLevel\)') 'Check alternative game XP API safely.'
    Assert-Condition ($lua -match 'local projectedXP = math[.]min\(xpMax, xp [+] questXP\)') 'Existing after-turn-ins progress remains capped at the current level.'
    Assert-Condition ($lua -match 'local nextXPMax, estimatedNextCap = NextLevelXPRequirement\(UnitLevel\("player"\), xpMax\)') 'Next-level XP percentage must use the next-level requirement.'
    Assert-Condition ($lua -match 'local nextLevelDisplay = Commas\(nextLevelXP\) \.\. " XP"') 'Tooltip must retain the raw carryover XP.'
    Assert-Condition ($lua -match 'if nextLevelXP == 0 then\s+nextLevelDisplay = nextLevelDisplay \.\. "  \(0[.]0%\)"') 'No overflow must display 0.0%.'
    Assert-Condition ($lua -match 'nextLevelXP / nextXPMax \* 100') 'Percentage must divide by NEXT level XP cap.'
    Assert-Condition ($lua -match 'estimatedNextCap and "  \(~%.1f%%\)" or "  \(%.1f%%\)"') 'Table-based percent should be visibly approximate.'
    Assert-Condition ($lua -match 'nextLevelDisplay = nextLevelDisplay \.\. "  \(—\)"') 'Unknown next-level cap must not invent a percentage.'
    Assert-Condition ($lua -match 'GameTooltip:AddDoubleLine\("XP into next level", nextLevelDisplay') 'Tooltip must include next-level percent.'
    $afterTurnInsIndex = $lua.IndexOf('GameTooltip:AddDoubleLine("After turn-ins"')
    $nextLevelIndex = $lua.IndexOf('GameTooltip:AddDoubleLine("XP into next level"')
    Assert-Condition ($afterTurnInsIndex -ge 0 -and $nextLevelIndex -gt $afterTurnInsIndex -and ($nextLevelIndex - $afterTurnInsIndex) -lt 370) 'Next-level XP should appear immediately beneath After turn-ins.'

    Assert-Condition ($lua -notmatch '(?i)\b(TODO|FIXME)\b') 'Release source contains TODO or FIXME markers.'

    Assert-Condition ($lua -match 'enabled = true, locked = false') 'New installs should start unlocked.'
    Assert-Condition ($lua -match 'MIN_HEIGHT, MAX_HEIGHT = 10, 120') 'On-bar height dragging should allow 120px.'
    Assert-Condition ($lua -match 'value < 10 or value > 120 then return false') 'Height setting should accept 120px.'
    Assert-Condition ($options -match 'AddSlider\("height", "Height", -273, 10, 120, 1, " px"\)') 'Height slider should allow 120px.'
    Assert-Condition ($lua -match 'height 10-120') 'Slash command help should advertise height 120px.'
    Assert-Condition ($lua -match 'if db[.]height > 40 then') 'Tall bars must enlarge text beyond its old font-size cap.'
    Assert-Condition ($lua -match 'db[.]height - 40') 'Tall bar font scaling should depend on height above 40.'
    Assert-Condition ($lua -match 'value < 0[.]5 or value > 3 then return false') 'Scale setting must accept 3x.'
    Assert-Condition ($options -match 'AddSlider\("scale", "Overall UI scale \(including text\)", -337, 0[.]5, 3, 0[.]05, "x"\)') 'Scale slider must expose 3x.'
    Assert-Condition ($lua -match 'scale 0[.]5-3') 'Slash command help must document 3x.'
    Assert-Condition ($lua -match 'width = 1100, height = 16, scale = 1') 'Default scale must remain 1x.'
    Assert-Condition ($lua -match 'AddResizeHandle\("width", "RIGHT"') 'Missing right-edge width resize zone.'
    Assert-Condition ($lua -match 'AddResizeHandle\("height", "BOTTOM", 0, -14\)') 'Height resize zone must be below the bar, not over it.'
    Assert-Condition ($lua -notmatch 'AddResizeHandle\("heightTop"') 'Do not restore top chevron resize handles.'
    Assert-Condition ($lua -match 'local function AddMetalMidpointMarker\(\)') 'Missing classic-WoW metal midpoint chevron builder.'
    Assert-Condition ($lua -match 'AddMetalMidpointMarker\(\)') 'Metal midpoint chevron should be built during bar creation.'
    Assert-Condition ($lua -notmatch 'AddStoneMidpointMarker|AddStoneMidpointNotch') 'Old stone-arrow implementations must not return.'
    Assert-Condition ($lua -notmatch 'local widths = \{20, 20, 18, 16') 'Do not draw the former solid stone triangle.'
    Assert-Condition ($lua -match 'midpointMarker = CreateFrame\("Frame", nil, bar\)') 'Midpoint ornament should belong to the XP bar.'
    Assert-Condition ($lua -match 'midpointMarker:SetSize\(32, 32\)') 'Original Blizzard exhaustion tick uses a 32px native texture.'
    Assert-Condition ($lua -match 'midpointMarker:SetPoint\("CENTER", bar, "TOP", 0, -4\)') 'One centered anchor must align the native arrow with 50-percent division.'
    Assert-Condition ($lua -match 'local arrow = midpointMarker:CreateTexture\(nil, "OVERLAY"\)') 'Midpoint should draw from one continuous native texture.'
    Assert-Condition ($lua -match 'arrow:SetAllPoints\(midpointMarker\)') 'The native texture must stay centered and follow UI scaling.'
    Assert-Condition ($lua -match 'arrow:SetTexture\("Interface\\\\MainMenuBar\\\\UI-ExhaustionTickNormal"\)') 'Midpoint must use Blizzard original filled silver exhaustion-tick artwork.'
    Assert-Condition ($lua -match 'arrow:SetVertexColor\(1, 1, 1, 1\)') 'Original silver and dark-steel palette must remain untinted.'
    Assert-Condition ($lua -notmatch 'local arms = \{|shadowLeft|shadowRight|centerFill|tipHighlight|local tipShadow =') 'Do not reintroduce disjoint rotated rectangle fragments.'
    Assert-Condition ($lua -notmatch 'midpointMarker:SetAllPoints\(bar\)') 'Midpoint marker frame must not clip its out-of-bar ornament.'
    Assert-Condition ($lua -match 'midpointMarker:EnableMouse\(false\)') 'Midpoint marker frame must not capture dragging, tooltips or right clicks.'
    Assert-Condition ($lua -match 'showMidpointMarker = true') 'Midpoint marker must default to enabled on existing and new installs.'
    Assert-Condition ($lua -match 'midpointMarker:SetShown\(db[.]showMidpointMarker\)') 'Midpoint marker must follow the persisted checkbox value.'
    Assert-Condition ($lua -match 'elseif key == "showMidpointMarker" then midpointMarker:SetShown\(value\)') 'Midpoint marker visibility must update without a reload.'
    Assert-Condition ($lua -match 'db[.]showMidpointMarker = defaults[.]showMidpointMarker') 'Reset all defaults must re-enable the midpoint marker.'
    Assert-Condition ($options -match 'AddCheckbox\("showMidpointMarker", "Show 50% marker"') 'Settings panel needs the classic metal marker checkbox.'
    Assert-Condition ($options -match 'for key, check in pairs\(checkboxes\) do check:SetChecked\(db\[key\]\) end') 'Checkbox must refresh from persistent settings.'

    Assert-Condition ($lua -notmatch 'AddResizeHandle\("height", "TOP"') 'Top-edge resize zone blocks the bar tooltip and movement.'
    Assert-Condition ($lua -match 'height - dy') 'Bottom-edge downward mouse movement must increase bar height.'
    Assert-Condition ($lua -notmatch 'fromTop and -dy or dy') 'Do not retain the old top-edge resize direction.'
    Assert-Condition ($lua -match 'db[.]point, db[.]relativePoint, db[.]x, db[.]y = "TOPLEFT", "TOPLEFT", x, y') 'Resizing should preserve the top-left screen anchor.'
    Assert-Condition ($lua -match 'AddResizeHandle\("corner", "BOTTOMRIGHT"') 'Missing bottom-right two-axis resize zone.'
    Assert-Condition ($lua -notmatch 'AddResizeHandle\("corner", "TOPRIGHT"') 'Top-right should not capture corner resizing.'
    Assert-Condition ($lua -match 'resizeHandles[.]corner:SetSize\(30, 30\)') 'Corner target must be at least 30 by 30.'
    Assert-Condition ($lua -match 'resizeHandles[.]width:SetSize\(24,') 'Right-edge grab area must be enlarged.'
    Assert-Condition ($lua -match 'resizeHandles[.]height:SetSize\(96, 18\)') 'Height-resize hitbox should be compact and centered, not full-width.'
    Assert-Condition ($lua -notmatch 'resizeHandles[.]height:SetSize\(db[.]width,') 'Height grab zone must never span the bar.'
    Assert-Condition ($lua -notmatch 'resizeHandles[.]height:SetWidth\(db[.]width\)') 'Resizing width must not expand the height hit zone.'
    Assert-Condition ($lua -match 'AddResizeHandle\("height", "BOTTOM", 0, -14\)') 'Height hitbox should be below the bar.'
    Assert-Condition ($lua -match 'if mode == "height" then\s+handle:SetHitRectInsets\(0, 0, 0, 0\)') 'Height hitbox must not expand over thin XP bars.'
    Assert-Condition ($lua -match 'handle:SetHitRectInsets\(-2, -2, -2, -2\)') 'Other resize handles retain their forgiving insets.'
    Assert-Condition ($lua -match 'grip:SetSize\(40, 5\)') 'Compact height grabber should keep the familiar gold line.'
    Assert-Condition ($lua -match 'height - dy') 'Bottom-right drag must increase height on downward cursor motion.'
    Assert-Condition ($lua -match 'shadow:SetSize\(44, 7\)') 'Top-center shadow should remain compact and thin.'
    Assert-Condition ([regex]::Matches($lua, 'local gripBack = MakeTexture\(indicator, "OVERLAY", 0[.]06, 0[.]09, 0[.]13, 1\)').Count -eq 1) 'Only the right edge should retain its solid navy grip backing.'
    Assert-Condition ($lua -match 'local shadow = MakeTexture\(indicator, "OVERLAY", 0[.]02, 0[.]03, 0[.]05, 0[.]35\)') 'Top grabber should use only a faint translucent shadow.'
    Assert-Condition ($lua -notmatch 'local upper = MakeTexture') 'Top grabber should not have the mismatched pale accent.'
    Assert-Condition ($lua -match 'grip:SetSize\(40, 5\)') 'Top-center grip should be visible without a full-width line.'
    Assert-Condition ($lua -match 'grip:SetSize\(4, 24\)') 'Right-edge grip should be clearly visible.'
    Assert-Condition ($lua -match 'backing:SetPoint\("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1\)') 'Corner visual must sit on the external hit handle.'
    Assert-Condition ($lua -match 'local backing = MakeTexture\(indicator, "BACKGROUND", 0[.]06, 0[.]09, 0[.]13, 0[.]76\)') 'Corner background must be lighter and render underneath the gold lines.'
    Assert-Condition ([regex]::Matches($lua, 'MakeTexture\(indicator, "OVERLAY", 1, 0[.]84, 0[.]42, 1\)').Count -eq 2) 'Both corner gold arms must be bright and match.'
    Assert-Condition ([regex]::Matches($lua, 'MakeTexture\(indicator, "OVERLAY", 1, 0[.]94, 0[.]67, 1\)').Count -eq 2) 'Both corner highlight arms must be visible.'
    Assert-Condition ($lua -match 'horizontal:SetDrawLayer\("OVERLAY", 3\)') 'Corner horizontal gold stroke should draw above the background.'
    Assert-Condition ($lua -match 'vertical:SetDrawLayer\("OVERLAY", 3\)') 'Corner vertical gold stroke should draw above the background.'
    Assert-Condition ($lua -match 'detailH:SetDrawLayer\("OVERLAY", 4\)') 'Corner horizontal highlight should draw above the main gold stroke.'
    Assert-Condition ($lua -match 'detailV:SetDrawLayer\("OVERLAY", 4\)') 'Corner vertical highlight should draw above the main gold stroke.'
    Assert-Condition ($lua -match 'glyphLength = math[.]max\(12, math[.]min\(24, db[.]height [*] 1[.]5\)\)') 'Corner glyph must adapt to bar height.'
    Assert-Condition ($lua -match 'corner[.]resizeCornerVisuals[.]backing:SetSize\(glyphLength [+] 6, glyphLength [+] 6\)') 'Corner background must scale with glyph.'
    Assert-Condition ($lua -match 'corner[.]resizeCornerVisuals[.]horizontal:SetSize\(glyphLength, stroke\)') 'Corner horizontal stroke must resize.'
    Assert-Condition ($lua -match 'corner[.]resizeCornerVisuals[.]vertical:SetSize\(stroke, glyphLength\)') 'Corner vertical stroke must resize.'
    Assert-Condition ($lua -match 'corner[.]resizeCornerVisuals[.]detailH:SetSize') 'Corner highlight detail must scale.'
    Assert-Condition ($lua -match 'corner[.]resizeCornerVisuals[.]detailV:SetSize') 'Corner vertical highlight detail must scale.'
    Assert-Condition ($lua -match 'indicator:Hide\(\)') 'Resize indicators should be hidden by default.'
    Assert-Condition ($lua -match 'SetScript\("OnEnter"') 'Resize indicators should only appear on hover.'
    Assert-Condition ($lua -notmatch 'AddResizeHandle\("width", "W"') 'Persistent labeled resize buttons must not return.'
    Assert-Condition ($lua -match 'GetCursorPosition\(\)') 'Resize controls must track pointer position.'
    Assert-Condition ($lua -match 'activeResize[.]effectiveScale') 'Resize movements must honor effective UI scale.'
    Assert-Condition ($lua -match 'AnchorForResizing') 'Resizing must preserve its opposite corner.'
    Assert-Condition ($lua -match 'if IsMouseButtonDown') 'Resize capture must stop when mouse releases.'

    Assert-Condition ($lua -match 'local hiddenDefaultFrames = \{\}') 'Track native XP frames our addon actually hid.'
    Assert-Condition ($lua -match 'if frame:IsShown\(\) then') 'Only hide and track Blizzard frames which are shown.'
    Assert-Condition ($lua -match 'hiddenDefaultFrames\[frame\] = true') 'Remember frames hidden by the addon.'
    Assert-Condition ($lua -match 'hiddenDefaultFrames\[self\] = true') 'Record Blizzard frames forcibly hidden by the Show hook.'
    Assert-Condition ($lua -match 'elseif hiddenDefaultFrames\[frame\] then') 'Unchecking hide must restore previously hidden frames.'
    Assert-Condition ($lua -match 'hiddenDefaultFrames\[frame\] = nil\s+frame:Show\(\)') 'Restore native XP frames with Show and clear tracking.'
    Assert-Condition ($lua -match 'if db and db[.]hideBlizzard then') 'Show hook must stop hiding when the checkbox is unchecked.'
    Assert-Condition ($lua -match 'eventFrame:RegisterEvent\("PLAYER_REGEN_ENABLED"\)') 'Defer protected native UI changes during combat.'
    Assert-Condition ($lua -match 'elseif event == "PLAYER_REGEN_ENABLED" then\s+ApplyDefaultBarVisibility\(\)') 'Apply deferred native bar toggles after combat.'
    Assert-Condition ($lua -match 'else ApplyDefaultBarVisibility\(\) end') 'Settings boolean change must apply Blizzard visibility immediately.'
    Assert-Condition ($options -match 'Show or hide Blizzard') 'Settings must communicate immediate restoration.'
    Assert-Condition ($lua -match 'addon.SetSetting = SetSetting') 'Settings panel and commands must share an update path.'
    Assert-Condition ($lua -match 'addon.InitializeOptions') 'Addon does not initialize the options panel.'
    Assert-Condition ($options -match 'Settings.RegisterCanvasLayoutCategory') 'Options panel must register in native Settings.'
    Assert-Condition ($options -match 'Settings.OpenToCategory') 'Options shortcut must open the Settings category.'
    Assert-Condition ($options -match 'Lock position and resizing') 'Options panel is missing its lock control.'
    Assert-Condition ($toc -match '(?m)^Options[.]lua$') 'Options.lua must be listed in the addon TOC.'
    Assert-Condition ($options -notmatch '(?i)\\b(TODO|FIXME)\\b') 'Options source contains TODO or FIXME markers.'
    $optionsNulBytes = [System.IO.File]::ReadAllBytes($optionsPath) | Where-Object { $_ -eq 0 } | Select-Object -First 1
    Assert-Condition ($null -eq $optionsNulBytes) 'Options.lua contains a NUL byte.'

    $nulBytes = [System.IO.File]::ReadAllBytes($luaPath) | Where-Object { $_ -eq 0 } | Select-Object -First 1
    Assert-Condition ($null -eq $nulBytes) 'Lua source contains a NUL byte.'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Better Forever XP validation passed.' -ForegroundColor Green
