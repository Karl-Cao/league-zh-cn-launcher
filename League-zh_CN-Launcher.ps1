[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [ValidateRange(1, 720)]
    [int]$MaxWatchMinutes = 180,
    [ValidateRange(15, 600)]
    [int]$StableSeconds = 120
)

$ErrorActionPreference = 'Stop'
$targetLocale = 'zh_CN'
$metadataPath = 'C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml'
$updateStatusPath = 'C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.update-status.json'
$appDataRoot = Join-Path $env:LOCALAPPDATA 'League-zh_CN-Launcher'
$logPath = Join-Path $appDataRoot 'launcher.log'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $appDataRoot)) {
    New-Item -ItemType Directory -Path $appDataRoot -Force | Out-Null
}

function Write-LauncherLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding UTF8
}

function Get-YamlValue {
    param(
        [string]$Text,
        [string]$Key
    )
    $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Key)):\s*['`"]?(.+?)['`"]?\s*$")
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Find-RiotInstallation {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "League live metadata was not found at $metadataPath"
    }

    $metadata = [System.IO.File]::ReadAllText($metadataPath)
    $leagueRoot = Get-YamlValue -Text $metadata -Key 'product_install_full_path'
    $productRoot = Get-YamlValue -Text $metadata -Key 'product_install_root'

    if ([string]::IsNullOrWhiteSpace($leagueRoot)) {
        throw 'Riot metadata does not contain product_install_full_path.'
    }

    $leagueRoot = $leagueRoot.Replace('/', '\').TrimEnd('\')
    $leagueClient = Join-Path $leagueRoot 'LeagueClient.exe'
    $leagueSettings = Join-Path $leagueRoot 'Config\LeagueClientSettings.yaml'

    $riotCandidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($productRoot)) {
        $riotCandidates.Add((Join-Path $productRoot.Replace('/', '\') 'Riot Client\RiotClientServices.exe'))
    }
    $riotCandidates.Add((Join-Path (Split-Path -Parent $leagueRoot) 'Riot Client\RiotClientServices.exe'))

    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq 'Fixed' -and $drive.IsReady) {
            $riotCandidates.Add((Join-Path $drive.RootDirectory.FullName 'Riot Games\Riot Client\RiotClientServices.exe'))
        }
    }

    $riotClient = $riotCandidates |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not (Test-Path -LiteralPath $leagueClient -PathType Leaf)) {
        throw "LeagueClient.exe was not found at $leagueClient"
    }
    if (-not (Test-Path -LiteralPath $leagueSettings -PathType Leaf)) {
        throw "LeagueClientSettings.yaml was not found at $leagueSettings"
    }
    if ([string]::IsNullOrWhiteSpace($riotClient)) {
        throw 'RiotClientServices.exe could not be located automatically.'
    }

    return [pscustomobject]@{
        LeagueClient = $leagueClient
        LeagueSettings = $leagueSettings
        RiotClient = $riotClient
    }
}

function Set-LocaleFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$SetDefaultLocale,
        [switch]$EnsureAvailableLocale,
        [switch]$Required
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($Required) { throw "Required file was not found: $Path" }
        return $false
    }

    try {
        $original = [System.IO.File]::ReadAllText($Path)
        $updated = [regex]::Replace(
            $original,
            '(?m)^(\s*locale:\s*).+$',
            "`$1`"$targetLocale`""
        )

        if ($SetDefaultLocale) {
            $updated = [regex]::Replace(
                $updated,
                '(?m)^(\s*default_locale:\s*).+$',
                "`$1`"$targetLocale`""
            )
        }

        if ($EnsureAvailableLocale -and $updated -notmatch '(?m)^\s*-\s*["'']?zh_CN["'']?\s*$') {
            $newline = if ($updated.Contains("`r`n")) { "`r`n" } else { "`n" }
            $updated = [regex]::Replace(
                $updated,
                '(?m)^(\s*default_locale:)',
                "    - `"$targetLocale`"$newline`$1",
                1
            )
        }

        if ($updated -ne $original) {
            [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
            Write-LauncherLog "Applied $targetLocale to $Path"
            return $true
        }
        return $false
    }
    catch {
        if ($Required) { throw }
        # Riot briefly removes or locks these files while replacing them.
        return $false
    }
}

function Apply-LeagueLocale {
    param(
        [pscustomobject]$Paths,
        [switch]$RequireFiles
    )
    $metadataChanged = Set-LocaleFile -Path $metadataPath -SetDefaultLocale -EnsureAvailableLocale -Required:$RequireFiles
    $settingsChanged = Set-LocaleFile -Path $Paths.LeagueSettings -Required:$RequireFiles
    return ($metadataChanged -or $settingsChanged)
}

function Test-LeagueUpdatePending {
    if (-not (Test-Path -LiteralPath $updateStatusPath -PathType Leaf)) {
        return $false
    }

    try {
        $updateState = [System.IO.File]::ReadAllText($updateStatusPath) | ConvertFrom-Json
        return [bool]($updateState.status.updateAvailable -or $updateState.status.updateRequired)
    }
    catch {
        # Riot can briefly replace this file. Locale enforcement continues either way.
        return $false
    }
}

try {
    Write-LauncherLog 'Launcher started.'
    $paths = Find-RiotInstallation
    Apply-LeagueLocale -Paths $paths -RequireFiles | Out-Null

    if ($NoLaunch) {
        Write-LauncherLog 'Validation completed without launching League.'
        exit 0
    }

    $existingRendererIds = @(Get-Process -Name 'LeagueClientUxRender' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)

    Start-Process -FilePath $paths.RiotClient -ArgumentList @(
        '--launch-product=league_of_legends',
        '--launch-patchline=live'
    )
    Write-LauncherLog 'Riot Client launch requested.'

    $deadline = (Get-Date).AddMinutes($MaxWatchMinutes)
    $leagueDetectedAt = $null
    $lastCorrectionAt = Get-Date
    $updateWasPending = $false

    while ((Get-Date) -lt $deadline) {
        $localeCorrected = Apply-LeagueLocale -Paths $paths
        if ($localeCorrected) {
            $lastCorrectionAt = Get-Date
        }

        $updatePending = Test-LeagueUpdatePending
        if ($updatePending) {
            $lastCorrectionAt = Get-Date
            if (-not $updateWasPending) {
                Write-LauncherLog 'League update detected; protecting zh_CN throughout the update.'
            }
            $updateWasPending = $true
        }

        $rendererProcesses = @(Get-Process -Name 'LeagueClientUxRender' -ErrorAction SilentlyContinue)
        $newRendererDetected = @($rendererProcesses | Where-Object { $_.Id -notin $existingRendererIds }).Count -gt 0
        $existingClientStillOpen = $existingRendererIds.Count -gt 0 -and $rendererProcesses.Count -gt 0

        if ($newRendererDetected -or $existingClientStillOpen) {
            if ($null -eq $leagueDetectedAt) {
                $leagueDetectedAt = Get-Date
                Write-LauncherLog "League client detected; waiting for $StableSeconds stable seconds after patching and locale corrections finish."
            }

            $stableSince = if ($lastCorrectionAt -gt $leagueDetectedAt) { $lastCorrectionAt } else { $leagueDetectedAt }
            if (-not $updatePending -and (Get-Date) -ge $stableSince.AddSeconds($StableSeconds)) {
                break
            }
        }

        Start-Sleep -Milliseconds 300
    }

    Apply-LeagueLocale -Paths $paths | Out-Null
    if ((Get-Date) -ge $deadline) {
        Write-LauncherLog "Maximum watch time of $MaxWatchMinutes minutes reached; locale was applied one final time."
    }
    else {
        Write-LauncherLog 'Update/startup cycle is stable; launcher finished.'
    }
}
catch {
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Could not launch League in Simplified Chinese.`n`n$($_.Exception.Message)`n`nLog: $logPath",
        'League zh_CN launcher',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}
