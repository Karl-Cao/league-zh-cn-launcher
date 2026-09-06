# League of Legends zh_CN Launcher

**English** | [简体中文](README.zh-CN.md)

A small Windows launcher that starts the global League of Legends client in
Simplified Chinese (`zh_CN`) and restores the locale when Riot rewrites its
configuration during startup.

> [!IMPORTANT]
> This is an unofficial community workaround. It is not affiliated with,
> endorsed by, or supported by Riot Games. A future Riot Client update may
> change the configuration format and require changes to this project.

## What it does

- Detects the League and Riot Client installation paths from Riot metadata.
- Adds `zh_CN` to the locale list and sets it as the active/default locale.
- Updates League's own `LeagueClientSettings.yaml` locale.
- Watches both files during startup and reapplies the locale after Riot rewrites
  them.
- Creates a desktop shortcut using the installed League client icon.
- Leaves Riot configuration files writable so normal patching and repair are
  not intentionally blocked.

## Requirements

- Windows 10 or Windows 11
- Riot Client and the live League of Legends client already installed
- League launched normally at least once

## Installation

1. Download `League-zh_CN-Portable-v1.0.0.zip` from the latest
   [GitHub Release](../../releases/latest).
2. Extract the ZIP. Do not run the installer from inside the ZIP preview.
3. Double-click **`Install League zh_CN.cmd`**.
4. Launch League from **League of Legends - Simplified Chinese** on the desktop.

The launcher is installed for the current Windows user under:

```text
%LOCALAPPDATA%\League-zh_CN-Launcher
```

## Uninstallation

Double-click **`Uninstall League zh_CN.cmd`** in the installed folder shown
above. This removes the launcher and its desktop shortcut. It does not remove
Riot Client or League of Legends.

## Troubleshooting

The launcher writes a diagnostic log to:

```text
%LOCALAPPDATA%\League-zh_CN-Launcher\launcher.log
```

If Windows blocks downloaded script files, right-click the extracted ZIP or
script, open **Properties**, select **Unblock** if shown, and extract/run it
again.

## How it works

The launcher updates these Riot-managed files when present:

```text
C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml
<League install>\Config\LeagueClientSettings.yaml
```

It then starts `RiotClientServices.exe` with the normal League live-product
arguments and keeps watching through the League client handoff.

## License

No license has been granted yet. All rights are reserved by the repository
owner unless a license file is added later.
