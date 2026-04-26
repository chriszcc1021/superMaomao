# 《喵喵远征》重构后架构说明

本文档对应 GPT-5.5 重写清单 Phase 1-6 完成后的结构。项目仍保持 Godot 4 + GDScript 技术栈，运行入口为 `res://scenes/camp/CampScene.tscn`。

## 目录边界

```text
res://
├── autoload/       全局状态、跨场景服务、自动回归入口
├── data/           常量、卡牌、敌人、奇遇等静态数据
├── docs/           设计文档、重构清单、数据审计和架构说明
├── resources/      CatData、CardData、GeneData 等 Resource 类型
├── scenes/         营地、远征、战斗和通用 UI/实体
└── tools/          MCP 服务、数据校验、UI 布局校验
```

## Autoload 职责

- `GameState.gd`：唯一的持久化状态持有者，保存资源、猫咪、建筑、繁育、远征等字段；对外提供小型 API，避免外部直接改远征状态。
- `SceneManager.gd`：统一场景跳转入口，负责营地、远征、战斗、结算之间的切换。
- `EventBus.gd`：跨场景信号总线，只传递事件，不保存业务状态。
- `BuildingService.gd`：建筑建造、升级、猫窝容量等规则服务。
- `BreedingSlotService.gd`：繁育坑位启动、推进、完成和清理规则服务。
- `AutoTest.gd`：`AUTOTEST=1` 时运行的全流程回归测试入口。
- `Preloader.gd`、`TimeManager.gd`：保留现有职责，作为资源预载和时间辅助模块。

## 营地模块

- `CampScene.gd`：营地主协调器，连接 UI、建筑、猫咪列表、拖拽分配和日结算，不再承载所有细节。
- `CampBuildingPresenter.gd`：建筑展示、按钮状态、建造和升级刷新。
- `CampAssignmentController.gd`：猫咪拖拽、建筑投放、分配交互。
- `CampCatListPresenter.gd`：猫咪列表刷新和出征选择入口。
- `CampCatVisualController.gd`：营地猫咪节点生成、位置刷新和视觉同步。
- `StarterOverlayController.gd`、`StarterCatPreview.gd`：初始选猫弹窗与预览。
- `CampDaySummary.gd`：过天后的摘要弹窗。
- `DayManager.gd`、`BreedingSystem.gd`、`BreedingUI.gd`：保留营地推进、繁育计算和繁育界面职责。

## 战斗模块

- `BattleScene.gd`：战斗主协调器，负责生命周期、战斗暂停、升级时机、胜负结算和返回远征。
- `BattleCardController.gd`：升级选卡的抽取与应用。
- `BattleGeneSelector.gd`：Lv5、Lv10、Lv15 的基因候选生成。
- `BattleGenePopupController.gd`：基因选择/替换弹窗交互。
- `BattleExpeditionBuffs.gd`：远征 Buff 对战斗属性的应用。
- `BattleResultBuilder.gd`：战斗结束结果字典的组装。
- `PlayerCat.gd`、`WeaponSystem.gd`、`SpawnManager.gd`：继续分别负责玩家移动属性、武器攻击、敌人生成。
- `BattleHUD.gd`：血量、经验、倒计时、已选卡显示；新增稳定尺寸的 HP/XP 条。
- `CardSelectUI.gd`：升级选卡弹窗；按钮保持固定高度和文本裁切，避免溢出撑坏布局。

## 远征模块

- `ExpeditionMapUI.gd`：远征地图、节点选择、战斗/商店/奇遇跳转。
- `ExpeditionSystem.gd`：远征路线和节点规则。
- `QuestionEventUI.gd`：奇遇展示与选项执行。
- `ShopScene.gd`：远征商店。
- `ExpeditionResultScene.gd`：远征结算展示。

## 数据层

- `data/constants.gd`：设计文档对应的核心数值、显示名和阶段规则。
- `data/cards/*.gd`：武器卡、Buff 卡定义。
- `data/enemies/enemy_data.gd` 与 JSON 数据：敌人基础数值和波次数据。
- `data/events/question_events.gd`：奇遇事件与选项效果。
- `tools/DataValidator.gd`：校验卡牌、敌人、奇遇、常量是否重复或缺字段。
- `tools/CampFlowValidator.gd`：校验建筑建造/升级、猫咪建筑分配、繁育坑位启动到出生。

## 回归与校验

常用命令：

```powershell
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --check-only --script res://scenes/battle/BattleScene.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/DataValidator.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/CampFlowValidator.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/UILayoutValidator.gd
$env:AUTOTEST='1'; .\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --path .
```

`UILayoutValidator.gd` 当前检查项目默认 1280x720 画布、`canvas_items` 伸缩设置，以及主要场景可见控件是否越界。完整流程仍以 `AutoTest.gd` 报告为准。
