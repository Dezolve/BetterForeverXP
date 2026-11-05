[CmdletBinding()]
param(
    # Omit -Tag for a read-only metadata check on PRs and ordinary pushes.
    # Supply -Tag for a publishing preflight; releases through 2.6.1 are blocked.
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $root 'BetterForeverXP/BetterForeverXP.toc'
$notesPath = Join-Path $root 'CURSEFORGE_RELEASE_NOTES.md'
$changelogPath = Join-Path $root 'BetterForeverXP/CHANGELOG.md'

foreach ($path in @($tocPath, $notesPath, $changelogPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release metadata is missing: $path"
    }
}

$toc = Get-Content -LiteralPath $tocPath -Raw -Encoding UTF8
$match = [regex]::Match($toc, '(?m)^## Version:\s*(\S+)\s*$')
if (-not $match.Success) { throw 'Missing addon version in TOC.' }
$version = $match.Groups[1].Value
$strictSemver = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'
if ($version -cnotmatch $strictSemver) {
    throw "The TOC version must be a stable numeric MAJOR.MINOR.PATCH value: $version"
}
if ($toc -notmatch '(?m)^## Interface:\s*16001\s*$') {
    throw 'The WoW Forever release requires TOC Interface 16001.'
}

$expectedHeading = "# Better Forever XP $version"
foreach ($item in @(
    @{ Name = 'CURSEFORGE_RELEASE_NOTES.md'; Path = $notesPath },
    @{ Name = 'BetterForeverXP/CHANGELOG.md'; Path = $changelogPath }
)) {
    $firstLine = (Get-Content -LiteralPath $item.Path -TotalCount 1 -Encoding UTF8).TrimStart([char]0xFEFF).Trim()
    if ($firstLine -cne $expectedHeading) {
        throw "$($item.Name) must start with '$expectedHeading' (found '$firstLine')."
    }
}

if ($PSBoundParameters.ContainsKey('Tag')) {
    if ($Tag -cnotmatch '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
        throw "Invalid release tag '$Tag'. Use an exact tag such as v2.7.0 (no prerelease or build suffix)."
    }
    if ($Tag -cne "v$version") {
        throw "Tag $Tag does not match TOC and release notes version $version."
    }

    # Historical versions were already sent to CurseForge through the older workflow.
    # Never republish v2.6.1 or earlier using the new automatic tag workflow.
    if ([version]$version -le [version]'2.6.1') {
        throw "Version $version was released before tag automation. First eligible automatic tag is v2.6.2 or newer."
    }
}

Write-Host "Release metadata PASS: $version | interface 16001 | matching release notes/changelog" -ForegroundColor Green
if ($PSBoundParameters.ContainsKey('Tag')) {
    Write-Host "Tag publishing preflight PASS: $Tag" -ForegroundColor Green
}
