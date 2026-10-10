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
    Assert-Condition ($lua -match 'if rested > 0 then\s+ApplyTubeStatusColor\(fill,\s+\{0[.]12, 0[.]31, 0[.]72\}, \{0[.]41, 0[.]66, 1[.]00\}') 'Earned XP should have a blue tube gradient while rested.'
    Assert-Condition ($lua -match 'else\s+ApplyTubeStatusColor\(fill,\s+\{0[.]29, 0[.]10, 0[.]40\}, \{0[.]64, 0[.]36, 0[.]77\}') 'Earned XP should have a purple tube gradient when unrested.'
    Assert-Condition ($lua -match 'fillSheen:SetColorTexture\(0[.]88, 0[.]74, 0[.]96, 0[.]22\)') 'Unrested top highlight must be tinted purple rather than blue.'
    Assert-Condition ($lua -match 'fillSheen = fill:CreateTexture') 'Earned XP highlight should be dynamically recolorable.'

    Assert-Condition ($lua -match 'local function ApplyVerticalGradient\(texture, bottom, top\)') 'Need a reusable gradient helper.'
    Assert-Condition ($lua -match 'if not texture or not texture[.]SetGradient or not CreateColor then return false end') 'Older clients should fall back when gradient APIs are missing.'
    Assert-Condition ($lua -match 'pcall\(texture[.]SetGradient, texture, "VERTICAL"') 'Gradient calls should be protected on uncertain Classic clients.'
    Assert-Condition ($lua -match 'statusBar:SetStatusBarColor\(flat\[1\], flat\[2\], flat\[3\], 1\)') 'Unsupported clients should retain readable classic solid fill colors.'
    Assert-Condition ($lua -match 'ApplyTubeStatusColor\(restedFill,') 'Rested coverage needs matching tube shading.'
    Assert-Condition ($lua -match 'ApplyVerticalGradient\(background,') 'The unearned track should have a dark channel gradient.'
    Assert-Condition ($lua -match 'fillSheen:SetPoint\("TOPLEFT", fill:GetStatusBarTexture\(\), "TOPLEFT"\)') 'XP bevel should follow earned fill width rather than entire frame.'
    Assert-Condition ($lua -match 'fillShade:SetPoint\("BOTTOMLEFT", fill:GetStatusBarTexture\(\), "BOTTOMLEFT"\)') 'XP bottom shade should follow earned fill width.'
    Assert-Condition ($lua -match 'restedSheen:SetPoint\("TOPLEFT", restedFill:GetStatusBarTexture\(\), "TOPLEFT"\)') 'Rested bevel should follow rested coverage.'
    Assert-Condition ($lua -match 'local MAX_CORNER_RADIUS = 16') 'Tube needs visibly curved endcaps rather than static two-pixel corner cuts.'
    Assert-Condition ($lua -match 'local function UpdateTubeCaps\(height, width\)') 'Cap curvature must adapt to live bar height.'
    Assert-Condition ($lua -match 'math[.]sqrt\(radius [*] radius - x [*] x\)') 'Cap steps must approximate circular curvature.'
    Assert-Condition ($lua -match 'trimHeight = math[.]min\(trimHeight, math[.]floor\(\(height - 2\) / 2\)\)') 'Corner cuts must not swallow short XP bars.'
    Assert-Condition ($lua -match 'UpdateTubeCaps\(db[.]height, db[.]width\)') 'Resizing must relayout the tube endcaps.'
    Assert-Condition ($lua -match 'for column = 0, MAX_CORNER_RADIUS - 1 do') 'Rounded ends should be drawn with multiple contour columns.'
    Assert-Condition ($lua -match 'endCapTrim:SetFrameLevel\(bar:GetFrameLevel\(\) [+] 7\)') 'Curved cap contours must draw over the fills but beneath text.'
    Assert-Condition ($lua -match 'endCapTrim:EnableMouse\(false\)') 'Rounded caps must not block dragging and tooltips.'
    Assert-Condition ($lua -match 'cap[.]edge:SetPoint\(anchor, cap[.]host, anchor, offset, -trimHeight\)') 'Top metal rim must follow the curved cap.'
    Assert-Condition ($lua -match 'cap[.]edge:SetPoint\(anchor, cap[.]host, anchor, offset, trimHeight\)') 'Bottom metal rim must follow the curved cap.'
    Assert-Condition ($lua -notmatch 'trim:SetSize\(2, 2\)') 'Old static corner cuts should be removed.'
    Assert-Condition ($lua -match 'local tickLayer, tickMarks = nil, \{\}') 'The complete set of classic 5-percent divisions must exist.'
    Assert-Condition ($lua -match 'for index = 1, 19 do\s+local core = MakeTexture\(tickLayer, "OVERLAY"') 'The tube must keep all 19 dividers for 20 classic XP sections.'
    Assert-Condition ($lua -match 'local rim = MakeTexture\(tickLayer, "OVERLAY"') 'Each groove needs a faint beveled highlight.'
    Assert-Condition ($lua -match 'rim:SetPoint\("TOPLEFT", core, "TOPRIGHT", 0, 0\)') 'Highlight must stay attached to the core, not drift with scaling.'
    Assert-Condition ($lua -match 'rim:SetPoint\("BOTTOMLEFT", core, "BOTTOMRIGHT", 0, 0\)') 'Highlight and core must have the same height.'
    Assert-Condition ($lua -match 'if index == 10 then\s+core:SetPoint\("TOP", tickLayer, "TOP", 0, -1\)') '50-percent core must align with Blizzard midpoint arrow.'
    Assert-Condition ($lua -match 'tickMarks\[index\] = \{\s+core = core, rim = rim, glint = glint,\s+topNotch = topNotch, bottomNotch = bottomNotch,\s+isCenter = index == 10,') 'Each groove must track a visible middle reflection and recessed dark ends.'
    Assert-Condition ($lua -match 'local effectiveScale = tickLayer:GetEffectiveScale\(\)') 'Grooves must use actual UI scale.'
    Assert-Condition ($lua -match 'local pixel = 1 / effectiveScale') 'Grooves must use a physical-pixel unit.'
    Assert-Condition ($lua -match 'tick[.]core:SetWidth\(pixel\)') 'Core groove must stay one physical pixel wide.'
    Assert-Condition ($lua -match 'tick[.]rim:SetWidth\(pixel\)') 'Its bevel highlight must also stay one physical pixel wide.'
    Assert-Condition ($lua -match 'tick[.]glint:SetWidth\(pixel\)') 'Middle glint must stay one pixel wide.'
    Assert-Condition ($lua -match 'tick[.]topNotch:SetWidth\(pixel\)') 'Top socket must stay one pixel wide.'
    Assert-Condition ($lua -match 'tick[.]bottomNotch:SetWidth\(pixel\)') 'Bottom socket must stay one pixel wide.'
    Assert-Condition ($lua -match 'tick[.]topNotch:SetHeight\(notchHeight\)') 'Top dark notch must respond to bar height.'
    Assert-Condition ($lua -match 'tick[.]bottomNotch:SetHeight\(notchHeight\)') 'Bottom dark notch must respond to bar height.'
    Assert-Condition ($lua -match 'tick[.]glint:SetHeight\(math[.]max\(1, grooveHeight - notchHeight [*] 2 - 2\)\)') 'Bright groove section should occupy the center between dark ends.'
    Assert-Condition ($lua -match 'if index ~= 10 then\s+local x = math[.]floor\(db[.]width [*] index / 20 [*] effectiveScale [+] 0[.]5\) [*] pixel') 'All other segments must snap to even spacing in physical pixels.'
    Assert-Condition ($lua -match 'tick[.]core:SetPoint\("TOP", tickLayer, "TOPLEFT", x, -1\)') 'Non-midpoint groove positions must be relative to bar width.'
    Assert-Condition ($lua -match 'local tickPalettes = \{') 'Groove palettes must be provided for all three XP surfaces.'
    Assert-Condition ($lua -match 'local function ApplyBeveledTick\(tick, region\)') 'Grooves need a shared gradient styling function.'
    Assert-Condition ($lua -match 'if tick[.]region == region then return end') 'Unchanged regions should not rebuild gradients on every XP update.'
    Assert-Condition ($lua -match 'ApplyVerticalGradient\(tick[.]core, palette[.]coreBottom, coreTop\)') 'Dark recessed groove must shade vertically.'
    Assert-Condition ($lua -match 'ApplyVerticalGradient\(tick[.]rim, palette[.]rimBottom, rimTop\)') 'Beveled highlight must fade vertically.'
    Assert-Condition ($lua -match 'tick[.]core:SetColorTexture\(flat\[1\], flat\[2\], flat\[3\], flat\[4\]\)') 'Missing gradient APIs must fall back to readable core strokes.'
    Assert-Condition ($lua -match 'tick[.]rim:SetColorTexture\(flat\[1\], flat\[2\], flat\[3\], flat\[4\]\)') 'Missing gradient APIs must fall back to readable highlights.'
    Assert-Condition ($lua -match 'if tick[.]isCenter then') '50-percent groove should be subtly more visible.'

    Assert-Condition ($lua -match 'coreBottom = \{0[.]00, 0[.]00, 0[.]00, 0[.]88\}, coreTop = \{0[.]08, 0[.]10, 0[.]16, 0[.]62\}') 'Earned XP groove needs a dark upper/lower contrast.'
    Assert-Condition ($lua -match 'rimBottom = \{0[.]70, 0[.]78, 0[.]90, 0[.]12\}, rimTop = \{1[.]00, 1[.]00, 1[.]00, 0[.]38\}') 'Earned XP marker needs a bright white highlight that fades downward.'
    Assert-Condition ($lua -match 'coreBottom = \{0[.]00, 0[.]00, 0[.]00, 0[.]90\}') 'Rested navy needs a dark groove core.'
    Assert-Condition ($lua -match 'rimTop = \{1[.]00, 1[.]00, 1[.]00, 0[.]40\}') 'Rested navy must retain a visible white edge.'
    Assert-Condition ($lua -match 'coreBottom = \{0[.]00, 0[.]00, 0[.]00, 0[.]92\}') 'Empty track needs a dark groove core.'
    Assert-Condition ($lua -match 'rimTop = \{1[.]00, 1[.]00, 1[.]00, 0[.]42\}') 'Empty track needs its own white highlight.'
    Assert-Condition ($lua -match 'coreTop\[4\] [+] 0[.]18') 'Center core should be slightly bolder below the Blizzard arrow.'
    Assert-Condition ($lua -match 'rimTop\[4\] [+] 0[.]16') 'Center glint should be slightly bolder below the Blizzard arrow.'
    Assert-Condition ($lua -match 'tubeRim = CreateFrame\("Frame", nil, bar\)') 'Tube frame must persist for live height-aware relayout.'
    Assert-Condition ($lua -match 'tubeRim:SetFrameLevel\(bar:GetFrameLevel\(\) [+] 4\)') 'Frame accents must draw above fills and below segment ticks and labels.'
    Assert-Condition ($lua -match 'tubeRim:EnableMouse\(false\)') 'Tube frame must not interrupt mouse drag and tooltip.'
    Assert-Condition ($lua -match 'local topEdge = MakeTexture\(tubeRim, "OVERLAY", 0[.]40, 0[.]47, 0[.]58, 0[.]96\)') 'Straight upper steel rim must match its rounded cap edge.'
    Assert-Condition ($lua -match 'local bottomEdge = MakeTexture\(tubeRim, "OVERLAY", 0[.]28, 0[.]34, 0[.]44, 0[.]96\)') 'Straight lower steel rim must match its rounded cap edge.'
    Assert-Condition ($lua -match 'local leftEdge = MakeTexture\(tubeRim, "OVERLAY", 0[.]30, 0[.]37, 0[.]47, 0[.]96\)') 'Rounded frame needs a connecting left side edge.'
    Assert-Condition ($lua -match 'local rightEdge = MakeTexture\(tubeRim, "OVERLAY", 0[.]30, 0[.]37, 0[.]47, 0[.]96\)') 'Rounded frame needs a connecting right side edge.'
    Assert-Condition ($lua -match 'local topInsetShade = MakeTexture\(tubeRim, "OVERLAY", 0[.]005, 0[.]008, 0[.]016, 0[.]89\)') 'Tube retains the dark inner rim without stacking another rectangular outline.'
    Assert-Condition ($lua -match 'local innerTopHighlight = MakeTexture\(tubeRim, "OVERLAY", 1[.]00, 1[.]00, 1[.]00, 0[.]18\)') 'Tube retains the subtle white upper reflection.'
    Assert-Condition ($lua -match 'local innerBottomShade = MakeTexture\(tubeRim, "OVERLAY", 0[.]00, 0[.]00, 0[.]00, 0[.]24\)') 'Tube retains the subdued interior shadow.'
    Assert-Condition ($lua -match 'local cuts = \{\}') 'Tube caps and horizontal rails must derive from a single radius profile.'
    Assert-Condition ($lua -match 'if i < radius and trimHeight == 0 and railInset == radius then') 'Horizontal rail must begin at the first untrimmed cap column.'
    Assert-Condition ($lua -match 'SetHorizontalRail\(tubeRim[.]topEdge, true, railInset, 0\)') 'Top outer rail must meet the rounded contour without overhang.'
    Assert-Condition ($lua -match 'SetHorizontalRail\(tubeRim[.]bottomEdge, false, railInset, 0\)') 'Bottom outer rail must meet the rounded contour without overhang.'
    Assert-Condition ($lua -match 'SetHorizontalRail\(tubeRim[.]topInsetShade, true, railInset [+] 1, -1\)') 'Inner dark bevel must not protrude into rounded corners.'
    Assert-Condition ($lua -match 'SetHorizontalRail\(tubeRim[.]innerTopHighlight, true, railInset [+] 2, -2\)') 'White glint must be inset from the rounded caps.'
    Assert-Condition ($lua -match 'SetHorizontalRail\(tubeRim[.]innerBottomShade, false, railInset [+] 2, 2\)') 'Lower shadow must be inset from the rounded caps.'
    Assert-Condition ($lua -match 'edge:SetPoint\("TOP" [.][.] align, tubeRim, "TOP" [.][.] align, 0, -outerTrim - 1\)') 'Vertical sides must start where rounded upper edge ends.'
    Assert-Condition ($lua -match 'edge:SetPoint\("BOTTOM" [.][.] align, tubeRim, "BOTTOM" [.][.] align, 0, outerTrim [+] 1\)') 'Vertical sides must end where rounded lower edge begins.'
    Assert-Condition ($lua -match 'tubeRim[.]topEdge:SetHeight\(1\)') 'Steel outline should use exactly one top border rather than multiple conflicting rails.'
    Assert-Condition ($lua -match 'tubeRim[.]bottomEdge:SetHeight\(1\)') 'Steel outline should use exactly one bottom border rather than multiple conflicting rails.'
    Assert-Condition ($lua -match 'tubeRim[.]topInsetShade:SetHeight\(math[.]max\(1, math[.]min\(3,') 'Dark inner shadow must adapt to tube height.'
    Assert-Condition ($lua -notmatch 'AddBorder\(bar\)') 'Never draw a second rectangular border through the rounded endcaps.'
    Assert-Condition ($lua -match 'tick[.]glint:SetColorTexture\(1, 1, 1,') 'Each segment should have a white center highlight.'
    Assert-Condition ($lua -match 'tick[.]topNotch:SetColorTexture\(0[.]0, 0[.]0, 0[.]0, 0[.]93\)') 'Top of each segment marker should be nearly black.'
    Assert-Condition ($lua -match 'tick[.]bottomNotch:SetColorTexture\(0[.]0, 0[.]0, 0[.]0, 0[.]96\)') 'Bottom of each segment marker should be nearly black.'
    Assert-Condition ($lua -match 'ApplyBeveledTick\(tick, "earned"\)') 'Earned XP should have correctly shaded dividers.'
    Assert-Condition ($lua -match 'ApplyBeveledTick\(tick, "rested"\)') 'Rested XP should have correctly shaded dividers.'
    Assert-Condition ($lua -match 'ApplyBeveledTick\(tick, "empty"\)') 'Empty track should have correctly shaded dividers.'
    Assert-Condition ($lua -notmatch 'tick[.]dark|tick[.]light') 'Do not restore unanchored double strokes.'
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
