# 英雄联盟简体中文启动器

[English](README.md) | **简体中文**

这是一个适用于 Windows 的小工具。它会打开 Riot Client，并持续保持英雄联盟
元数据中的当前语言为简体中文（`zh_CN`）。

> [!IMPORTANT]
> 这是由社区制作的非官方解决方案，与 Riot Games 无隶属、认可或支持关系。
> Riot Client 未来的更新可能会改变配置格式，届时本项目也需要相应更新。

## 功能

- 正常打开 Riot Client，不自动启动英雄联盟。
- 在 Riot 启动期间监控 `league_of_legends.live.product_settings.yaml`；
  Riot 将当前 `locale` 改回 `en_US` 时，立即恢复为 `zh_CN`。
- 当新的 Riot 会话把语言重置为 `en_US` 时，启动器会先恢复 `zh_CN`，再自动重启
  Riot Client 一次，并在重启后继续监控，直到英雄联盟客户端打开。这样重新打开的客户端会选择中文更新，
  而不是继续下载完整的英文语言包。
- Riot Client 重新打开后，用户可以手动点击 **更新** 或 **开始游戏**。
- 不修改 Riot Client 设置、`default_locale`、`available_locales` 或
  `LeagueClientSettings.yaml`。
- 创建桌面快捷方式，并使用本机英雄联盟客户端的图标。
- 不会把 Riot 配置文件设为只读，因此不会故意阻止正常更新或修复。

## 系统要求

- Windows 10 或 Windows 11
- 已安装 Riot Client 和国际服《英雄联盟》正式服客户端
- 至少正常启动过一次英雄联盟

## 安装方法

1. 从最新的 [GitHub Release](../../releases/latest) 下载
   `League-zh_CN-Portable-v1.2.1.zip`。
2. 完整解压 ZIP；不要直接在压缩包预览窗口中运行安装程序。
3. 双击 **`Install League zh_CN.cmd`**。
4. 以后使用桌面上的 **League of Legends - Simplified Chinese** 启动游戏。

启动器会安装到当前 Windows 用户的以下目录：

```text
%LOCALAPPDATA%\League-zh_CN-Launcher
```

## 卸载方法

进入上述安装目录，双击 **`Uninstall League zh_CN.cmd`**。这只会删除启动器及其
桌面快捷方式，不会删除 Riot Client 或英雄联盟。

## 故障排查

启动器的诊断日志位于：

```text
%LOCALAPPDATA%\League-zh_CN-Launcher\launcher.log
```

如果 Windows 阻止运行下载的脚本，请右键单击下载的 ZIP 或脚本，打开
**属性**。如果看到 **解除锁定** 选项，请勾选它，然后重新解压并运行。

## 工作原理

启动器正常打开 Riot Client，并且只监控英雄联盟产品元数据中的当前 `locale`
字段。当它发现 Riot 刚把语言重置为 `en_US` 时，会恢复 `zh_CN` 并自动重启
Riot Client 一次。重启后，它会继续保持 `zh_CN`，直到英雄联盟客户端打开，
随后监控程序立即退出。如果英雄联盟尚未打开、Riot Client 就已关闭，
监控程序会在十秒后退出。启动器不会反复重启 Riot Client。

## 许可证

本项目目前没有授予开源许可证。除非仓库所有者以后添加许可证文件，否则保留
所有权利。
