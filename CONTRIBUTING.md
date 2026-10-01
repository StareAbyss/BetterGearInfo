# 开发与 PR 规范

本项目采用独立的 `main` 分支，首次建立仓库直接提交初始版本；后续功能和修复通过分支与 PR 管理。

## 提交与标题

提交和 PR 标题使用中文 conventional commits 风格：`type(范围): 中文说明`。

* `feat`：功能；`fix`：修复；`perf`：体验或性能优化。
* `build`：打包、资源或配置；`docs`：文档；`refactor`：重构；`style`：代码格式。
* 范围可使用 `角色界面`、`装备详情`、`观察`、`打包`、`文档`。
* 用户明确指定标题时，保留其原文。

示例：`fix(观察): 修复切换观察对象时装备清单未刷新`。

## PR

* 从最新 `origin/main` 建立功能分支，只提交当前任务相关的内容；保留工作区里的其他改动。
* 正文用中文，使用 `*` 简短说明改动；无需列出检查过程，无需复杂章节。
* 负责人设置为 `StareAbyss`；至少添加一个变更分类和一个模块标签。
* 变更分类：`Git-Feat`、`Git-Fix`、`Git-Perf`、`Git-Build`、`Git-Docs`、`Git-Refactor`、`Git-Style`。
* 模块：`Module-UI`、`Module-Gear`、`Module-Inspect`、`Module-Build`、`Module-Docs`。
* 按玩家可感知的功能拆分 PR。相关文档、资源与回归检查随功能一起提交；零散维护可合为 `build: 杂项`。
* 发布前确认检查通过、差异符合任务范围，然后使用 merge commit 合并；不强推共享分支，不绕过失败的检查。
* 创建 PR 时优先使用 GitHub CLI。多行正文保存为 UTF-8 文件，再用 `--body-file` 传入；通过 API 提交中文时使用 UTF-8 请求体。

这些约定参考 FoodsVsMiceAutoAssistant 的 PR 规范，并针对独立插件精简。

## 检查与打包

使用 Python 3.11 或更新版本：

```text
python -m pip install -r tests/requirements.txt
python tests/test_inventory.py
python tests/test_close_initialization.py
python tests/test_equipment_slots.py
python scripts/package.py
git diff --check
```

检查包含 Lua 5.1 语法、装备汇总和关闭按钮初始化的回归场景。它们使用模拟游戏 API，不能替代正式服内验证。修改界面后，需在游戏里检查角色、观察、同时打开两窗、声望和货币页以及悬停关闭行为。

打包脚本只收录运行所需文件、说明和协议，输出 `dist/BetterGearInfo-<版本>.zip`；不会打包 Git 数据、开发脚本或本地实验资源。
