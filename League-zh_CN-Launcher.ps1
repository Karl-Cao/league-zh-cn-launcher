[CmdletBinding()]
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$targetLocale = 'zh_CN'
$metadataPath = 'C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml'
$metadataProducts = @(
    @{ Name = 'League'; Path = $metadataPath },
    @{ Name = 'TFT'; Path = 'C:\ProgramData\Riot Games\Metadata\teamfighttactics.live\teamfighttactics.live.product_settings.yaml' }
)
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
    $candidates = New-Object System.Collections.Generic.List[string]
    $installsPath = Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json'
    if (Test-Path -LiteralPath $installsPath -PathType Leaf) {
        try {
            $installs = [System.IO.File]::ReadAllText($installsPath) | ConvertFrom-Json
            foreach ($path in @($installs.rc_live, $installs.patchlines.KeystoneFoundationLiveWin, $installs.rc_default)) {
                if (-not [string]::IsNullOrWhiteSpace($path)) {
                    $candidates.Add($path.Replace('/', '\'))
                }
            }
        }
        catch {
            Write-LauncherLog 'Riot installation registry could not be read; trying metadata paths.'
        }
    }

    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        try {
            $metadata = [System.IO.File]::ReadAllText($metadataPath)
            $leagueRoot = Get-YamlValue -Text $metadata -Key 'product_install_full_path'
            $productRoot = Get-YamlValue -Text $metadata -Key 'product_install_root'
            if (-not [string]::IsNullOrWhiteSpace($productRoot)) {
                $candidates.Add((Join-Path $productRoot.Replace('/', '\') 'Riot Client\RiotClientServices.exe'))
            }
            if (-not [string]::IsNullOrWhiteSpace($leagueRoot)) {
                $leagueRoot = $leagueRoot.Replace('/', '\').TrimEnd('\')
                $candidates.Add((Join-Path (Split-Path -Parent $leagueRoot) 'Riot Client\RiotClientServices.exe'))
            }
        }
        catch [System.IO.IOException] {
            # Riot may replace metadata during discovery; the installation registry remains usable.
        }
    }

    $riotClient = $candidates |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($riotClient)) {
        throw 'RiotClientServices.exe could not be located from Riot installation records or metadata.'
    }
    Write-LauncherLog "Located Riot Client: $riotClient"
    return $riotClient
}

function Set-ActiveLocale {
    param([string]$Path, [string]$Product)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        $original = [System.IO.File]::ReadAllText($Path)
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

        [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
        Write-LauncherLog "Restored $Product active metadata locale to $targetLocale."
        return $true
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $false
    }
}

function Set-ActiveLocales {
    foreach ($product in $metadataProducts) {
        Set-ActiveLocale -Path $product.Path -Product $product.Name | Out-Null
    }
}

function Get-ActiveLocale {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $metadata = [System.IO.File]::ReadAllText($Path)
        return Get-YamlValue -Text $metadata -Key 'locale'
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $null
    }
}

function Get-MetadataLastWriteUtc {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [datetime]::MinValue
    }

    try {
        return (Get-Item -LiteralPath $Path).LastWriteTimeUtc
    }
    catch [System.IO.IOException] {
        return [datetime]::MinValue
    }
    catch [System.Management.Automation.ItemNotFoundException] {
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

    Write-LauncherLog 'EN metadata reset detected; restarting Riot Client once after restoring zh_CN.'
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

    $alreadyRunning = Test-RiotOrLeagueRunning
    $baselineMetadataWriteUtc = @{}
    $initialLocales = @{}
    foreach ($product in $metadataProducts) {
        $baselineMetadataWriteUtc[$product.Name] = Get-MetadataLastWriteUtc -Path $product.Path
        $initialLocales[$product.Name] = Get-ActiveLocale -Path $product.Path
    }
    $restartPerformed = $false
    if (-not $alreadyRunning) {
        Start-Process -FilePath $riotClient
        Write-LauncherLog 'Riot Client started normally.'
    }
    else {
        Write-LauncherLog 'Attached to the existing Riot/League session.'
    }

    if (-not (Test-MatchRunning)) {
        Set-ActiveLocales
    }

    $initialEnLocale = @($metadataProducts | Where-Object { $initialLocales[$_.Name] -eq 'en_US' }).Count -gt 0
    if ($alreadyRunning -and $initialEnLocale -and -not (Test-LeagueClientRunning) -and -not (Test-MatchRunning)) {
        Restart-RiotClientOnce -RiotClient $riotClient
        $restartPerformed = $true
    }

    Write-LauncherLog 'Watching League and TFT active metadata locales while Riot or League is open; pausing during matches.'

    $noProcessSince = $null
    $matchWasRunning = $false
    while ($true) {
        if (Test-MatchRunning) {
            if (-not $matchWasRunning) {
                Write-LauncherLog 'League or TFT match started; locale monitoring paused.'
                $matchWasRunning = $true
            }
            $noProcessSince = $null
            Start-Sleep -Milliseconds 250
            continue
        }
        if ($matchWasRunning) {
            Write-LauncherLog 'League or TFT match ended; locale monitoring resumed.'
            $matchWasRunning = $false
        }

        $freshEnReset = $false
        foreach ($product in $metadataProducts) {
            $observedLocale = Get-ActiveLocale -Path $product.Path
            $metadataWriteUtc = Get-MetadataLastWriteUtc -Path $product.Path
            if (-not $alreadyRunning -and -not $restartPerformed -and
                $observedLocale -eq 'en_US' -and
                $metadataWriteUtc -gt $baselineMetadataWriteUtc[$product.Name]) {
                $freshEnReset = $true
            }
        }

        if (Test-MatchRunning) {
            continue
        }
        Set-ActiveLocales

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
            Write-LauncherLog 'Riot and League are closed; locale monitoring finished.'
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
