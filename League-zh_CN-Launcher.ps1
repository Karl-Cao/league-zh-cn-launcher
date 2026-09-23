[CmdletBinding()]
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$targetLocale = 'zh_CN'
$metadataPath = 'C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml'
$appDataRoot = Join-Path $env:LOCALAPPDATA 'League-zh_CN-Launcher'
$logPath = Join-Path $appDataRoot 'launcher.log'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$processNames = @(
    'RiotClientServices',
    'RiotClientUx',
    'RiotClientUxRender',
    'LeagueClient',
    'LeagueClientUx',
    'LeagueClientUxRender',
    'League of Legends',
    'TFTClient-Win64-Shipping'
)

if (-not (Test-Path -LiteralPath $appDataRoot)) {
    New-Item -ItemType Directory -Path $appDataRoot -Force | Out-Null
}

function Write-LauncherLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding UTF8
}

function Get-YamlValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Key)):\s*['`"]?(.+?)['`"]?\s*$")
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Find-RiotClient {
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
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($productRoot)) {
        $candidates.Add((Join-Path $productRoot.Replace('/', '\') 'Riot Client\RiotClientServices.exe'))
    }
    $candidates.Add((Join-Path (Split-Path -Parent $leagueRoot) 'Riot Client\RiotClientServices.exe'))

    $riotClient = $candidates |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($riotClient)) {
        throw 'RiotClientServices.exe could not be located automatically.'
    }
    return $riotClient
}

function Set-ActiveLeagueLocale {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $false
    }

    try {
        $original = [System.IO.File]::ReadAllText($metadataPath)
        $locale = Get-YamlValue -Text $original -Key 'locale'
        if ($locale -eq $targetLocale) {
            return $false
        }

        $updated = [regex]::Replace(
            $original,
            '(?m)^(\s*locale:\s*).+$',
            "`$1`"$targetLocale`""
        )
        if ($updated -eq $original) {
            return $false
        }

        [System.IO.File]::WriteAllText($metadataPath, $updated, $utf8NoBom)
        Write-LauncherLog "Restored active metadata locale to $targetLocale."
        return $true
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $false
    }
}

function Get-ActiveLeagueLocale {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $null
    }

    try {
        $metadata = [System.IO.File]::ReadAllText($metadataPath)
        return Get-YamlValue -Text $metadata -Key 'locale'
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $null
    }
}

function Get-MetadataLastWriteUtc {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return [datetime]::MinValue
    }

    try {
        return (Get-Item -LiteralPath $metadataPath).LastWriteTimeUtc
    }
    catch [System.IO.IOException] {
        return [datetime]::MinValue
    }
}

function Test-MatchRunning {
    return @(Get-Process -Name 'League of Legends', 'TFTClient-Win64-Shipping' -ErrorAction SilentlyContinue).Count -gt 0
}

function Test-LeagueClientRunning {
    return @(Get-Process -Name 'LeagueClient', 'LeagueClientUx', 'LeagueClientUxRender' -ErrorAction SilentlyContinue).Count -gt 0
}

function Restart-RiotClientOnce {
    param([string]$RiotClient)

    Write-LauncherLog 'EN update state detected; restarting Riot Client once after restoring zh_CN.'
    @('RiotClientUxRender', 'RiotClientUx', 'RiotClientServices') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        $riotProcesses = @(
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $_.ProcessName -in @('RiotClientServices', 'RiotClientUx', 'RiotClientUxRender') }
        )
        if ($riotProcesses.Count -eq 0) {
            break
        }
        $riotProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    Start-Sleep -Seconds 2
    Start-Process -FilePath $RiotClient
    Write-LauncherLog 'Riot Client restarted normally; active-locale watcher is still running.'
}

function Test-RiotOrLeagueRunning {
    return @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -in $processNames }
    ).Count -gt 0
}

try {
    Write-LauncherLog 'Launcher started.'
    $riotClient = Find-RiotClient

    if ($NoLaunch) {
        Write-LauncherLog 'Validation completed without launching Riot Client.'
        exit 0
    }

    if (Test-MatchRunning) {
        Write-LauncherLog 'A League or TFT match is already running; locale monitoring is not needed.'
        exit 0
    }

    $alreadyRunning = Test-RiotOrLeagueRunning
    $baselineMetadataWriteUtc = Get-MetadataLastWriteUtc
    $initialLocale = Get-ActiveLeagueLocale
    $restartPerformed = $false
    if (-not $alreadyRunning) {
        Start-Process -FilePath $riotClient
        Write-LauncherLog 'Riot Client started normally.'
    }
    else {
        Write-LauncherLog 'Attached to the existing Riot/League session.'
    }

    if (Test-MatchRunning) {
        Write-LauncherLog 'League or TFT match started; locale monitoring finished.'
        exit 0
    }
    Set-ActiveLeagueLocale | Out-Null

    if ($alreadyRunning -and $initialLocale -eq 'en_US' -and -not (Test-LeagueClientRunning) -and -not (Test-MatchRunning)) {
        Restart-RiotClientOnce -RiotClient $riotClient
        $restartPerformed = $true
    }

    Write-LauncherLog 'Watching active metadata locale until a League or TFT match starts.'

    $noProcessSince = $null
    while ($true) {
        if (Test-MatchRunning) {
            Write-LauncherLog 'League or TFT match started; locale monitoring finished.'
            break
        }

        $observedLocale = Get-ActiveLeagueLocale
        $metadataWriteUtc = Get-MetadataLastWriteUtc
        $freshEnReset = (
            -not $alreadyRunning -and
            -not $restartPerformed -and
            $observedLocale -eq 'en_US' -and
            $metadataWriteUtc -gt $baselineMetadataWriteUtc
        )

        if (Test-MatchRunning) {
            Write-LauncherLog 'League or TFT match started; locale monitoring finished.'
            break
        }
        Set-ActiveLeagueLocale | Out-Null

        if ($freshEnReset -and -not (Test-LeagueClientRunning) -and -not (Test-MatchRunning)) {
            Restart-RiotClientOnce -RiotClient $riotClient
            $restartPerformed = $true
        }

        if (Test-RiotOrLeagueRunning) {
            $noProcessSince = $null
        }
        elseif ($null -eq $noProcessSince) {
            $noProcessSince = Get-Date
        }
        elseif ((Get-Date) -ge $noProcessSince.AddSeconds(10)) {
            Write-LauncherLog 'Riot Client closed before a match started; locale monitoring finished.'
            break
        }

        Start-Sleep -Milliseconds 250
    }

}
catch {
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Could not keep League in Simplified Chinese.`n`n$($_.Exception.Message)`n`nLog: $logPath",
        'League zh_CN launcher',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}
