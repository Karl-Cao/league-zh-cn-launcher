[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$metadataPath = 'C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml'
$installRoot = Join-Path $env:LOCALAPPDATA 'League-zh_CN-Launcher'
$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath 'League of Legends - Simplified Chinese.lnk'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

function Get-YamlValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Key)):\s*['`"]?(.+?)['`"]?\s*$")
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

try {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw 'League of Legends live metadata was not found. Install League before running this installer.'
    }

    $metadata = [System.IO.File]::ReadAllText($metadataPath)
    $leagueRoot = Get-YamlValue -Text $metadata -Key 'product_install_full_path'
    if ([string]::IsNullOrWhiteSpace($leagueRoot)) {
        throw 'Could not determine the League installation folder from Riot metadata.'
    }
    $leagueClient = Join-Path $leagueRoot.Replace('/', '\').TrimEnd('\') 'LeagueClient.exe'
    if (-not (Test-Path -LiteralPath $leagueClient -PathType Leaf)) {
        throw "LeagueClient.exe was not found at $leagueClient"
    }

    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'League-zh_CN-Launcher.ps1') -Destination $installRoot -Force
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'Uninstall-League-zh_CN.ps1') -Destination $installRoot -Force
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'Uninstall League zh_CN.cmd') -Destination $installRoot -Force

    $installedLauncher = Join-Path $installRoot 'League-zh_CN-Launcher.ps1'
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershellExe
    $shortcut.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installedLauncher`""
    $shortcut.WorkingDirectory = $installRoot
    $shortcut.IconLocation = "$leagueClient,0"
    $shortcut.Description = 'Launch League of Legends in Simplified Chinese (zh_CN)'
    $shortcut.Save()

    & $powershellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installedLauncher -NoLaunch
    if ($LASTEXITCODE -ne 0) { throw 'Launcher validation failed.' }

    if (-not $Quiet) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Installation complete.`n`nUse the new desktop shortcut:`nLeague of Legends - Simplified Chinese",
            'League zh_CN launcher',
            'OK',
            'Information'
        ) | Out-Null
    }
}
catch {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Installation failed.`n`n$($_.Exception.Message)",
        'League zh_CN launcher',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}
