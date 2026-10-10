[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = Join-Path $repositoryRoot 'BetterForeverXP'
$tocPath = Join-Path $addonRoot 'BetterForeverXP.toc'

& (Join-Path $PSScriptRoot 'Test-Addon.ps1')

$toc = Get-Content -LiteralPath $tocPath -Raw
$versionMatch = [regex]::Match($toc, '(?m)^## Version:\s*(\S+)\s*$')
if (-not $versionMatch.Success) {
    throw 'Could not read the addon version.'
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot 'dist'
}

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$archivePath = Join-Path $OutputDirectory "BetterForeverXP-$($versionMatch.Groups[1].Value).zip"

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bfxp-package-" + [guid]::NewGuid().ToString('N'))
$stagedAddon = Join-Path $stagingRoot 'BetterForeverXP'

try {
    [System.IO.Directory]::CreateDirectory($stagedAddon) | Out-Null
    foreach ($name in 'BetterForeverXP.lua', 'BetterForeverXP.toc', 'CHANGELOG.md', 'README.md') {
        Copy-Item -LiteralPath (Join-Path $addonRoot $name) -Destination $stagedAddon
    }

    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath
    }
    Compress-Archive -LiteralPath $stagedAddon -DestinationPath $archivePath -CompressionLevel Optimal
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

Write-Host "Created $archivePath" -ForegroundColor Green
