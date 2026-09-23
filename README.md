# League of Legends zh_CN Launcher

**English** | [简体中文](README.zh-CN.md)

A small Windows helper that opens Riot Client and continuously keeps League's
active metadata locale set to Simplified Chinese (`zh_CN`).

> [!IMPORTANT]
> This is an unofficial community workaround. It is not affiliated with,
> endorsed by, or supported by Riot Games. A future Riot Client update may
> change the configuration format and require changes to this project.

## What it does

- Opens Riot Client normally without automatically starting League.
- Watches `league_of_legends.live.product_settings.yaml` while Riot is starting
  and restores its active `locale` whenever Riot changes it to `en_US`.
- When a fresh Riot session resets the locale to `en_US`, restores `zh_CN`,
  restarts Riot Client once, and continues watching until League opens. This makes
  the reopened client select the Chinese update path instead of continuing the
  full English language-package download.
- Allows the user to manually click **Update** or **Play** after Riot reopens.
- Does not modify Riot Client settings, `default_locale`, `available_locales`, or
  `LeagueClientSettings.yaml`.
- Creates a desktop shortcut using the installed League client icon.
- Leaves Riot configuration files writable so normal patching and repair are
  not intentionally blocked.

## Requirements

- Windows 10 or Windows 11
- Riot Client and the live League of Legends client already installed
- League launched normally at least once

## Installation

1. Download `League-zh_CN-Portable-v1.2.1.zip` from the latest
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

The launcher opens Riot Client normally and monitors only the active `locale`
field in League's product metadata. When it observes Riot's fresh `en_US` reset,
it restores `zh_CN` and restarts Riot Client once. It then keeps restoring
`zh_CN` until the League client opens, at which point the helper exits. If Riot
closes before League opens, the helper exits after ten seconds. It never
restarts Riot repeatedly.

## License

No license has been granted yet. All rights are reserved by the repository
owner unless a license file is added later.
