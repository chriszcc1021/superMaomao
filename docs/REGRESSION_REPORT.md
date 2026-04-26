# Phase 6 回归报告

执行日期：2026-04-26

## 结论

- Godot 解析检查通过。
- 数据层校验通过。
- 营地建筑、分配、繁育轻量回归通过。
- UI 布局校验通过。
- `AUTOTEST=1` 主流程已从新开局跑到远征结算。
- Headless 模式没有可用截图纹理，AutoTest 会记录跳过截图，不再产生脚本错误。

## 已执行命令

```powershell
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --check-only --script res://autoload/AutoTest.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --check-only --script res://scenes/battle/BattleScene.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/DataValidator.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/CampFlowValidator.gd
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/UILayoutValidator.gd
$env:AUTOTEST='1'; .\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --path .
```

## AutoTest 摘要

路径：`user://autotest_screens/report.txt`

流程：

- 选择初始猫。
- 连续过天到 Day 4。
- 进入远征地图并开始远征。
- 第 1 层普通战斗完成并返回远征地图。
- Lv5 基因选择完成，随后升级选卡继续。
- 第 2 层精英战斗结束后进入远征结算。

观察项：

- 第 2 层精英战斗后半段出现低血量记录，AutoTest 仍可进入结算；这是战斗平衡观察项，不是流程阻塞。
- Headless 模式不会产出截图；需要视觉验收时请用窗口模式运行。
