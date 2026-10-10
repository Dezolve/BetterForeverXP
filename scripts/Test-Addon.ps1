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
    Assert-Condition ($lua -match 'AddResizeHandle\("height", "TOP"') 'Missing top-edge height resize zone.'
    Assert-Condition ($lua -match 'AddResizeHandle\("corner", "BOTTOMRIGHT"') 'Missing bottom-right two-axis resize zone.'
    Assert-Condition ($lua -notmatch 'AddResizeHandle\("corner", "TOPRIGHT"') 'Top-right should not capture corner resizing.'
    Assert-Condition ($lua -match 'resizeHandles[.]corner:SetSize\(30, 30\)') 'Corner target must be at least 30 by 30.'
    Assert-Condition ($lua -match 'resizeHandles[.]width:SetSize\(24,') 'Right-edge grab area must be enlarged.'
    Assert-Condition ($lua -match 'resizeHandles[.]height:SetSize\(db[.]width, 24\)') 'Entire top edge must respond to hover.'
    Assert-Condition ($lua -match 'resizeHandles[.]height:SetWidth\(db[.]width\)') 'Top hover target must track bar width.'
    Assert-Condition ($lua -match 'handle:SetHitRectInsets') 'Resize zones must have forgiving hit insets.'
    Assert-Condition ($lua -match 'fromTop and -dy or dy') 'Bottom-right drag must increase height on downward cursor motion.'
    Assert-Condition ($lua -match 'gripBack:SetSize\(58, 20\)') 'Top-center grip background should be compact and tall.'
    Assert-Condition ([regex]::Matches($lua, 'local gripBack = MakeTexture\(indicator, "OVERLAY", 0[.]06, 0[.]09, 0[.]13, 1\)').Count -eq 2) 'Top and right grips must share the same dark backing.'
    Assert-Condition ($lua -notmatch 'local upper = MakeTexture') 'Top grabber should not have the mismatched pale accent.'
    Assert-Condition ($lua -match 'grip:SetSize\(40, 5\)') 'Top-center grip should be visible without a full-width line.'
    Assert-Condition ($lua -match 'grip:SetSize\(4, 24\)') 'Right-edge grip should be clearly visible.'
    Assert-Condition ($lua -match 'backing:SetPoint\("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1\)') 'Corner visual must sit on the external hit handle.'
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
