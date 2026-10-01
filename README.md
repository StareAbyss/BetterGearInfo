# BetterGearInfo

适用于《魔兽世界》正式服 12.x 的独立插件，美化角色界面，并展示自身及被观察玩家的装备、装等、属性、附魔、宝石和套装进度。<br>
A standalone addon for World of Warcraft Retail 12.x, featuring a styled character panel and equipped gear details for yourself and inspected players, including item levels, stats, enchantments, gems, and set progress.

## 界面预览

![BetterGearInfo 角色界面与装备详情展示](docs/images/character-panel.png)

## 功能

- **美化角色界面**：极简风，适配主流 UI 界面。
- **装备一览**：查看每件装备的装等、属性、附魔和宝石，也能观察其他玩家的装备。
- **装备完善提示**：汇总附魔、宝石和套装进度，用红色提醒缺失。
- **PvP 装等**：显示当前穿戴装备在 PvP 中的装等，使用蓝色区分。

## 注意事项

- 使用时请关闭集成 UI 美化插件对角色信息界面的美化。
- 请勿与 TinyInspect（及其修复版）、ElvUI WindTools 工具箱的类似功能同时使用。

## 安装

将 `BetterGearInfo` 文件夹放到：

```text
World of Warcraft/_retail_/Interface/AddOns/BetterGearInfo/
```

文件夹内应直接包含 `BetterGearInfo.toc`、`BetterGearInfo.lua`、本说明文件和 `LICENSE`。重启游戏，在插件列表启用 **BetterGearInfo**，按 `C` 打开角色界面。

GitHub 自动检查的 `BetterGearInfo` 构建产物内包含安装 ZIP。若下载的是 GitHub 源码 ZIP，解压后请将目录重命名为 `BetterGearInfo`；开发文件无需安装到游戏中。

支持正式服 12.x，界面文案目前主要为简体中文。插件使用游戏原生纹理与 API，无需安装其他界面插件。

## 命令

- `/bgi`：重新显示当前角色或观察窗口旁的装备清单。
- `/bgi status`：显示版本、初始化状态和具体错误。
- `/bettergearinfo`：与 `/bgi` 相同；也支持 `status` 参数。

## 设计来源

左侧角色界面风格参考了 **ElvUI**；右侧装备详情栏的灵感来源于 **TinyInspect**。在此基础上重新做了美化和修复。

## 开发与协议

源码仓库：[StareAbyss/BetterGearInfo](https://github.com/StareAbyss/BetterGearInfo)。开发、打包及 PR 约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

BetterGearInfo 的代码使用 [MIT 协议](LICENSE)。游戏原生纹理通过 API 引用，不随插件打包。
