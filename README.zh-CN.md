# 英雄联盟简体中文启动器

[English](README.md) | **简体中文**

这是一个适用于 Windows 的小型启动器。它可以让国际服《英雄联盟》客户端以
简体中文（`zh_CN`）启动，并在 Riot 启动期间重写配置时自动恢复中文设置。

> [!IMPORTANT]
> 这是由社区制作的非官方解决方案，与 Riot Games 无隶属、认可或支持关系。
> Riot Client 未来的更新可能会改变配置格式，届时本项目也需要相应更新。

## 功能

- 从 Riot 元数据中自动检测英雄联盟和 Riot Client 的安装路径。
- 将 `zh_CN` 添加到语言列表，并设置为当前及默认语言。
- 修改英雄联盟自身的 `LeagueClientSettings.yaml` 语言设置。
- 在启动期间监控两个配置文件；如果 Riot 重写设置，会立即恢复简体中文。
- 在 Riot 更新游戏的整个过程中持续保持 `zh_CN`，避免先按 `en_US` 更新、随后又
  重复下载约 3 GB 的中文语言资源。
- 创建桌面快捷方式，并使用本机英雄联盟客户端的图标。
- 不会把 Riot 配置文件设为只读，因此不会故意阻止正常更新或修复。

## 系统要求

- Windows 10 或 Windows 11
- 已安装 Riot Client 和国际服《英雄联盟》正式服客户端
- 至少正常启动过一次英雄联盟

## 安装方法

1. 从最新的 [GitHub Release](../../releases/latest) 下载
   `League-zh_CN-Portable-v1.1.0.zip`。
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

启动器会在相应文件存在时修改以下 Riot 配置：

```text
C:\ProgramData\Riot Games\Metadata\league_of_legends.live\league_of_legends.live.product_settings.yaml
<英雄联盟安装目录>\Config\LeagueClientSettings.yaml
```

随后，它使用正式服的正常启动参数运行 `RiotClientServices.exe`，并在客户端
交接完成前持续监控语言设置。

## 许可证

本项目目前没有授予开源许可证。除非仓库所有者以后添加许可证文件，否则保留
所有权利。
