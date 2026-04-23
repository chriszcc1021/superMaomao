## AutoTest.gd — 自动化测试脚本，游戏启动后自动执行完整玩法循环并截图
## 仅在 AUTOTEST=1 环境变量时激活
extends Node

var _step := 0
var _screenshots := []
var _enabled := false
var _screenshot_dir := "user://autotest_screens/"
var _log := []

func _ready() -> void:
	# 检查环境变量激活
	if OS.get_environment("AUTOTEST") != "1":
		return
	_enabled = true
	print("[AutoTest] 启动自动化测试")
	DirAccess.make_dir_recursive_absolute(_screenshot_dir)
	# 等待首帧渲染完成再开始
	await get_tree().process_frame
	await get_tree().process_frame
	_run_test()

func _screenshot(name: String) -> void:
	if not _enabled:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := _screenshot_dir + name + ".png"
	img.save_png(path)
	_screenshots.append(path)
	_log.append("[截图] " + name + " -> " + path)
	print("[AutoTest] 截图: " + name)

func _log_step(msg: String) -> void:
	_log.append(msg)
	print("[AutoTest] " + msg)

func _run_test() -> void:
	_log_step("=== 喵喵远征 全量自动化测试开始 ===")
	
	# ── Step 1: 营地初始状态截图 ──
	_log_step("Step 1: 营地初始状态")
	await _screenshot("01_camp_starter_select")
	
	# ── Step 2: 选择第一只猫（index=1，灰烬·暹罗狙击猫）──
	_log_step("Step 2: 选择初始猫 灰烬（狙击猫·暹罗）")
	await _select_starter_cat(1)
	await get_tree().create_timer(1.0).timeout
	await _screenshot("02_camp_after_select")
	
	# ── Step 3: 过一天（清晨→黄昏）──
	_log_step("Step 3: 推进时间 - 过一天")
	await _press_next_day()
	await get_tree().create_timer(1.5).timeout
	await _screenshot("03_camp_day2")
	
	# ── Step 4: 查看猫咪列表 ──
	_log_step("Step 4: 营地猫队列表")
	await _screenshot("04_cat_list")
	
	# ── Step 5: 再过一天 ──
	_log_step("Step 5: 再推进一天")
	await _press_next_day()
	await get_tree().create_timer(1.5).timeout
	await _screenshot("05_camp_day3")
	
	# ── Step 6: 打开出征地图 ──
	_log_step("Step 6: 打开出征地图")
	await _open_expedition_map()
	await get_tree().create_timer(2.0).timeout
	await _screenshot("06_expedition_map")
	
	# ── Step 7: 选择第一个关卡 ──
	_log_step("Step 7: 选择关卡并进入战斗")
	await _select_first_node()
	await get_tree().create_timer(2.0).timeout
	await _screenshot("07_battle_start")
	
	# ── Step 8: 战斗运行10秒 ──
	_log_step("Step 8: 战斗进行中（等待10秒）")
	await get_tree().create_timer(5.0).timeout
	await _screenshot("08_battle_mid")
	await get_tree().create_timer(5.0).timeout
	await _screenshot("09_battle_10s")
	
	# ── Step 9: 结算 ──
	_log_step("Step 9: 战斗结算")
	await get_tree().create_timer(3.0).timeout
	await _screenshot("10_battle_result")
	
	_log_step("=== 测试流程完成 ===")
	_write_report()
	
	# 退出
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

## ── 辅助函数 ──

func _select_starter_cat(index: int) -> void:
	# 找到 CampScene 并触发按钮
	var camp := _find_camp_scene()
	if camp == null:
		_log_step("ERROR: 找不到 CampScene")
		return
	# 找 _starter_choice_buttons
	var buttons = camp.get("_starter_choice_buttons")
	if buttons == null or buttons.size() <= index:
		_log_step("ERROR: 找不到选猫按钮，尝试直接点击")
		# 尝试直接操作 GameState
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.has_method("select_starter_cat"):
			gs.select_starter_cat(index)
		return
	_log_step("点击按钮 index=" + str(index) + " 猫名: " + str(buttons[index].text if buttons[index].text != "" else "?"))
	buttons[index].emit_signal("pressed")

func _press_next_day() -> void:
	var camp := _find_camp_scene()
	if camp == null:
		return
	var btn = camp.get("_next_day_button")
	if btn == null:
		btn = _find_button_by_text("过一天")
	if btn != null:
		btn.emit_signal("pressed")
		_log_step("  → 点击 '过一天' 按钮")
	else:
		_log_step("  WARNING: 找不到 '过一天' 按钮")

func _open_expedition_map() -> void:
	var camp := _find_camp_scene()
	if camp == null:
		return
	var btn = camp.get("_open_expedition_button")
	if btn != null and not btn.disabled:
		btn.emit_signal("pressed")
		_log_step("  → 点击 '出征地图' 按钮")
	else:
		_log_step("  WARNING: 出征按钮不可用或未找到，尝试直接切换场景")
		get_tree().change_scene_to_file("res://scenes/expedition/ExpeditionMapUI.tscn")

func _select_first_node() -> void:
	# 在出征地图找第一个可点击节点
	var map_ui := get_tree().get_nodes_in_group("expedition_map")
	if map_ui.size() > 0:
		if map_ui[0].has_method("_on_node_selected"):
			map_ui[0]._on_node_selected(0)
			return
	# 用按钮查找
	var buttons := get_tree().get_nodes_in_group("expedition_node_buttons")
	if buttons.size() > 0:
		buttons[0].emit_signal("pressed")
		return
	# 直接切换到战斗场景测试
	_log_step("  → 直接进入战斗场景（跳过关卡选择UI）")
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _find_camp_scene() -> Node:
	return get_tree().get_nodes_in_group("camp_scene")[0] if get_tree().get_nodes_in_group("camp_scene").size() > 0 else get_tree().current_scene

func _find_button_by_text(text: String) -> Button:
	for node in get_tree().get_nodes_in_group(""):
		if node is Button and node.text.contains(text):
			return node
	return null

func _write_report() -> void:
	var report := "[AutoTest] 测试报告\n"
	report += "=" .repeat(50) + "\n"
	for entry in _log:
		report += entry + "\n"
	report += "\n截图列表:\n"
	for s in _screenshots:
		report += "  " + s + "\n"
	var path := _screenshot_dir + "test_report.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
	print(report)
	print("[AutoTest] 报告已写入: " + path)
