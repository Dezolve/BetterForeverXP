# Better Forever XP - local Windows test deployment bridge.
# Requires GitHub CLI (gh), logged in to GitHub as a user with repo access.
# It never executes downloaded content: only validated addon files are copied.
[CmdletBinding(DefaultParameterSetName = 'Sync')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(Mandatory = $true, ParameterSetName = 'Install')]
    [string]$TargetPath,

    [Parameter(ParameterSetName = 'Install')]
    [string]$Branch = 'feature/options-and-scaling',

    [Parameter(ParameterSetName = 'Sync')]
    [switch]$Sync,

    [Parameter(Mandatory = $true, ParameterSetName = 'Uninstall')]
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$taskName = 'BetterForeverXP-AutoDeploy'
$dataDir = Join-Path $env:LOCALAPPDATA 'BetterForeverXP-AutoDeploy'
$configPath = Join-Path $dataDir 'config.json'
$scriptPath = Join-Path $dataDir 'AutoDeploy-Windows.ps1'
$logPath = Join-Path $dataDir 'deploy.log'

function Write-DeployLog {
    param([string]$Message)
    [System.IO.Directory]::CreateDirectory($dataDir) | Out-Null
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Output $line
}

function Save-DeployConfig {
    param($Settings)
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Report-InstalledStatus {
    param($Settings, [string]$Sha)
    $endpoint = 'repos/{0}/statuses/{1}' -f $Settings.repo, $Sha
    & $Settings.ghPath api -X POST $endpoint -f 'state=success' -f 'context=BetterForeverXP/local-install' -f 'description=Installed on Windows; ready for WoW /reload' --silent 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-DeployLog "GitHub confirmed Windows installation of commit $Sha."
        return $true
    }
    Write-DeployLog 'Installed successfully, but could not report GitHub status (check gh authentication and repository permissions).'
    return $false
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "Auto-deploy task removed. Logs and configuration remain at $dataDir."
    return
}

if ($Install) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'GitHub CLI (gh) was not found. Install it with: winget install --id GitHub.cli -e'
    }
    & $gh.Source auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Sign in to GitHub CLI first: gh auth login'
    }

    $resolvedTarget = [System.IO.Path]::GetFullPath(
        [Environment]::ExpandEnvironmentVariables($TargetPath))
    if ((Split-Path $resolvedTarget -Leaf) -ne 'BetterForeverXP') {
        throw "TargetPath must point to the BetterForeverXP addon directory, not its parent: $resolvedTarget"
    }
    if ($resolvedTarget -notmatch '(?i)[\/\\]Interface[\/\\]AddOns[\/\\]BetterForeverXP$') {
        Write-Warning "This does not look like a game's Interface\AddOns folder. /reload only works if WoW actually loads addons from this location (or it is linked to that directory)."
    }
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $resolvedTarget) -PathType Container)) {
        throw "The parent folder does not exist: $resolvedTarget"
    }

    [System.IO.Directory]::CreateDirectory($dataDir) | Out-Null
    if ([System.IO.Path]::GetFullPath($PSCommandPath) -ne [System.IO.Path]::GetFullPath($scriptPath)) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $scriptPath -Force
    }
    $settings = [pscustomobject]@{
        repo = 'Dezolve/BetterForeverXP'
        branch = $Branch
        targetPath = $resolvedTarget
        ghPath = $gh.Source
        lastRunId = 0
        lastHeadSha = ''
        statusReported = $false
    }
    Save-DeployConfig $settings

    # A user-level task, not a privileged machine service. Runs while the
    # developer is logged into Windows, including when WoW is running.
    # Running powershell.exe directly as a user-level task causes an annoying
    # console window to flash every minute. wscript.exe starts PowerShell with
    # WindowStyle=0 (hidden), including child processes such as gh.exe.
    $powershellExe = (Get-Process -Id $PID).Path
    $wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'
    if (-not (Test-Path -LiteralPath $wscriptExe -PathType Leaf)) {
        throw "Windows Script Host was not found: $wscriptExe"
    }
    $launcherPath = Join-Path $dataDir 'AutoDeploy-Hidden.vbs'
    $commandLine = '"{0}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -Sync' -f $powershellExe, $scriptPath
    # VBScript escapes quotes by doubling them inside a string literal.
    $escapedCommandLine = $commandLine.Replace('"', '""')
    $launcher = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "$escapedCommandLine", 0, True
"@
    Set-Content -LiteralPath $launcherPath -Value $launcher -Encoding ASCII
    $arguments = '//B //Nologo "{0}"' -f $launcherPath
    $action = New-ScheduledTaskAction -Execute $wscriptExe -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
    $taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $taskSettings -Description 'Install latest successful Better Forever XP feature-branch build every minute' -Force | Out-Null

    Write-DeployLog "Installed automatic sync. Target: $resolvedTarget. Watching branch: $Branch."
    Write-Output "Scheduled task: $taskName (every minute)"
    Write-Output "Deployment log: $logPath"
    Write-Output 'Running an initial synchronization now...'
    & $scriptPath -Sync
    return
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "No configuration found. Run .\scripts\AutoDeploy-Windows.ps1 -Install -TargetPath '<your AddOns\BetterForeverXP path>' first."
}

# Do not overlap downloads or interrupt an earlier copy operation.
$mutex = New-Object System.Threading.Mutex($false, 'Local\BetterForeverXP-AutoDeploy')
$lockHeld = $false
try {
    $lockHeld = $mutex.WaitOne(0)
    if (-not $lockHeld) { return }

    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $settings.ghPath -PathType Leaf)) {
        throw "GitHub CLI executable no longer exists: $($settings.ghPath)"
    }

    $result = & $settings.ghPath run list --repo $settings.repo --workflow validate.yml --branch $settings.branch --event push --limit 8 --json databaseId,headSha,status,conclusion,createdAt 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Cannot query GitHub workflow runs: $($result | Out-String)" }
    $runs = @(($result | Out-String | ConvertFrom-Json))
    $run = $runs | Sort-Object -Property { [datetime]$_.createdAt } -Descending | Select-Object -First 1
    if (-not $run) { Write-DeployLog 'No workflow runs found for the configured branch.'; return }
    if ($run.status -ne 'completed' -or $run.conclusion -ne 'success') {
        Write-DeployLog "Newest run $($run.databaseId) is $($run.status)/$($run.conclusion); waiting for a successful build."
        return
    }

    if ([string]$settings.lastRunId -eq [string]$run.databaseId -and
        $settings.lastHeadSha -eq $run.headSha -and
        (Test-Path -LiteralPath (Join-Path $settings.targetPath 'BetterForeverXP.toc'))) {
        if (-not $settings.statusReported) {
            $settings.statusReported = Report-InstalledStatus $settings $run.headSha
            Save-DeployConfig $settings
        }
        return
    }

    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('bfxp-test-' + [guid]::NewGuid().ToString('N'))
    $outer = Join-Path $temp 'artifact'
    $unpacked = Join-Path $temp 'unpacked'
    [System.IO.Directory]::CreateDirectory($outer) | Out-Null
    [System.IO.Directory]::CreateDirectory($unpacked) | Out-Null

    try {
        & $settings.ghPath run download ([string]$run.databaseId) --repo $settings.repo --name BetterForeverXP --dir $outer
        if ($LASTEXITCODE -ne 0) { throw "Failed to download GitHub artifact from run $($run.databaseId)." }

        $archive = Get-ChildItem -LiteralPath $outer -Filter 'BetterForeverXP-*.zip' -File | Select-Object -First 1
        if (-not $archive) { throw "GitHub artifact does not contain the addon release ZIP." }
        Expand-Archive -LiteralPath $archive.FullName -DestinationPath $unpacked -Force

        $source = Join-Path $unpacked 'BetterForeverXP'
        $tocPath = Join-Path $source 'BetterForeverXP.toc'
        if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
            throw 'The release ZIP does not contain BetterForeverXP/BetterForeverXP.toc.'
        }
        # Refuse to install an incomplete addon. This also catches a new Lua
        # file added to the TOC but omitted from the archive.
        $loadFiles = Get-Content -LiteralPath $tocPath |
            Where-Object { $_ -and $_ -notmatch '^\s*##' } |
            ForEach-Object { $_.Trim() }
        foreach ($file in $loadFiles) {
            if (-not (Test-Path -LiteralPath (Join-Path $source $file) -PathType Leaf)) {
                throw "Missing TOC-listed addon file: $file"
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $source 'Options.lua') -PathType Leaf)) {
            throw 'Options.lua is missing; refusing to install the incomplete v2.5 test build.'
        }

        [System.IO.Directory]::CreateDirectory($settings.targetPath) | Out-Null
        # Copy in place so existing junctions/symlinks to WoW's AddOns folder
        # keep pointing at the correct files. Never touch WTF/SavedVariables.
        Copy-Item -Path (Join-Path $source '*') -Destination $settings.targetPath -Recurse -Force
        $settings.lastRunId = $run.databaseId
        $settings.lastHeadSha = $run.headSha
        $settings.statusReported = $false
        Save-DeployConfig $settings
        Write-DeployLog "Installed successful build $($run.databaseId) ($($run.headSha)) into $($settings.targetPath). Type /reload in WoW."
        $settings.statusReported = Report-InstalledStatus $settings $run.headSha
        Save-DeployConfig $settings
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    Write-DeployLog "ERROR: $($_.Exception.Message)"
    throw
}
finally {
    if ($lockHeld) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
