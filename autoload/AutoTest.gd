## AutoTest.gd — 全流程自动化测试 v2（完整远征 + 营地解锁）
## 激活条件：AUTOTEST=1 环境变量
## 修复：Godot4 emit_signal→.emit()；HP读取时序；卡牌检测强化

extends Node

const SCREENSHOT_DIR := "user://autotest_screens/"

var _enabled := false
var _log: Array[String] = []
var _bugs: Array[String] = []
var _screenshots: Array[String] = []

func _ready() -> void:
	if OS.get_environment("AUTOTEST") != "1":
		return
	_enabled = true
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	_log_step("=== 喵喵远征 全流程测试 v2 ===")
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

## ── 主流程 ──────────────────────────────────────────────────────────────

func _run() -> void:
	# 1. 营地选猫
	await _wait(1.5)
	await _screenshot("01_camp_start")
	_log_step("Step 1: 选猫（灰烬·暹罗狙击）")
	await _select_starter(1)
	await _wait(2.0)
	await _screenshot("02_camp_after_select")

	# 检查选猫是否成功
	var gs := get_node_or_null("/root/GameState")
	if gs:
		var cat_count: int = gs.cats.size()
		_log_step("  GameState.cats 数量: %d" % cat_count)
		if cat_count == 0:
			_bug("选猫失败！cats 为空")

	# 2. 过3天
	for day in range(3):
		await _press_next_day()
		await _wait(2.5)
		_log_step("Day %d 结束" % (day + 2))
	await _screenshot("03_camp_day4")

	# 3. 出征
	_log_step("Step 3: 进入出征地图")
	await _open_expedition()
	await _wait(2.0)
	await _screenshot("04_expedition_before_start")

	_log_step("Step 4: 开始出征")
	await _start_expedition()
	await _wait(2.0)
	await _screenshot("05_expedition_started")

	# 4. 打通最多6层（每层最多等3分钟）
	for layer in range(1, 8):
		_log_step("=== 第 %d 层 ===" % layer)
		var r: String = await _do_layer(layer)
		if r == "ended":
			_log_step("远征已结束")
			break
		if r == "camp":
			_log_step("已回到营地")
			break

	await _wait(2.0)
	await _screenshot("99_final")
	_log_step("=== 测试结束 ===")
	_write_report()
	await _wait(1.0)
	get_tree().quit()

## ── 单层处理 ────────────────────────────────────────────────────────────

func _do_layer(layer: int) -> String:
	await _wait(1.5)
	var scene := get_tree().current_scene
	if scene == null:
		return "continue"
	var sname := scene.name

	if "Camp" in sname or "Result" in sname:
		return "ended"

	# 不在出征地图，等一下
	if "Expedition" not in sname:
		_log_step("  等待回到出征地图（当前: %s）" % sname)
		await _wait(3.0)
		scene = get_tree().current_scene
		sname = scene.name if scene else "?"
		if "Expedition" not in sname:
			return "continue"

	# 出征地图：选节点
	await _screenshot("L%d_expedition_map" % layer)
	var node_row: Node = scene.find_child("NodeRow", true, false)
	if node_row == null:
		_bug("Layer %d: 找不到 NodeRow" % layer)
		return "continue"

	# 收集可用按钮
	var node_btns: Array[Button] = []
	for c in node_row.get_children():
		if c is Button and not (c as Button).disabled:
			node_btns.append(c as Button)

	if node_btns.is_empty():
		_bug("Layer %d: 无可用节点按钮" % layer)
		return "continue"

	var nb: Button = node_btns[0]
	_log_step("  Layer %d 选节点: [%s]（共%d个）" % [layer, nb.text.substr(0, 20), node_btns.size()])
	nb.pressed.emit()  # Godot4: .emit() 而非 emit_signal()
	await _wait(2.0)

	# 检查进入了什么场景
	scene = get_tree().current_scene
	sname = scene.name if scene else "?"
	_log_step("  → 进入: %s" % sname)

	if "Battle" in sname:
		await _screenshot("L%d_battle_start" % layer)
		await _do_battle(layer)
	elif "Shop" in sname:
		await _screenshot("L%d_shop" % layer)
		await _do_shop(scene)
	elif "Expedition" in sname:
		# 奇遇（在当前场景弹出覆盖 UI）
		var eq: Node = scene.find_child("QuestionEventUI", true, false)
		if eq:
			_log_step("  奇遇弹窗")
			await _screenshot("L%d_event" % layer)
			await _do_event(eq)
	else:
		_log_step("  未知场景: %s" % sname)

	return "continue"

## ── 战斗处理 ────────────────────────────────────────────────────────────

func _do_battle(layer: int) -> void:
	var elapsed: float = 0.0
	var timeout: float = 150.0
	var snap_interval: float = 15.0
	var last_snap: float = 0.0

	while elapsed < timeout:
		await _wait(0.5)
		elapsed += 0.5

		var scene: Node = get_tree().current_scene
		if scene == null:
			break
		var sname: String = scene.name

		# 离开战斗场景 = 战斗结束
		if "Battle" not in sname:
			_log_step("  战斗结束（%.0fs），进入: %s" % [elapsed, sname])
			await _screenshot("L%d_battle_end" % layer)
			return

		# 方法1：检查 _battle_paused 状态
		var is_paused: bool = bool(scene.get("_battle_paused") if scene.get("_battle_paused") != null else false)

		# 方法2：直接用内部引用
		var cs_ref: Variant = scene.get("_card_select")
		var cs: Node = cs_ref as Node if cs_ref != null else null
		if cs == null:
			cs = scene.get_node_or_null("UI/CardSelectUI")
		if cs == null:
			cs = scene.find_child("CardSelectUI", true, false)

		var cs_visible: bool = cs != null and cs.visible

		if elapsed < 3.0:
			var tl: Variant = scene.get("_battle_time_left")
			_log_step("  [%.1fs] paused=%s cs=%s cs_visible=%s time_left=%s" % [elapsed, str(is_paused), str(cs != null), str(cs_visible), str(tl)])

		if cs_visible or is_paused:
			_log_step("  %.0fs: 战斗暂停！paused=%s cs_visible=%s" % [elapsed, str(is_paused), str(cs_visible)])
			await _screenshot("L%d_paused_%.0fs" % [layer, elapsed])
			if cs != null and cs.visible:
				await _do_card_select(cs, layer)
			elif is_paused:
				# 可能是 gene popup 或其他暂停，找所有弹出层的按钮
				await _handle_any_popup(scene, layer)
			await _wait(0.5)
			continue

		# 定期截图 + 读血量
		if elapsed - last_snap >= snap_interval:
			last_snap = elapsed
			await _screenshot("L%d_battle_%.0fs" % [layer, elapsed])
			_read_hp(scene, layer, int(elapsed))

	# 超时
	_bug("Layer %d 战斗超时 %ds" % [layer, 150])
	await _screenshot("L%d_timeout" % layer)

func _handle_any_popup(scene: Node, layer: int) -> void:
	## 尝试找任何可见的弹窗并点击第一个可用按钮
	var all_btns: Array[Button] = []
	_gather_buttons(scene, all_btns)
	for b in all_btns:
		if b.is_visible_in_tree() and not b.disabled and b.text != "" and b.text != "—":
			_log_step("  弹窗按钮: [%s]" % b.text.substr(0, 25))
			b.pressed.emit()
			return
	_log_step("  未找到可用弹窗按钮（共%d个）" % all_btns.size())

func _battle_timeout_report(layer: int) -> void:
	_bug("Layer %d 战斗超时 150s" % layer)
	await _screenshot("L%d_timeout" % layer)

func _read_hp(scene: Node, layer: int, t: int) -> void:
	var player: Node = scene.find_child("PlayerCat", true, false)
	if player == null:
		_log_step("  [HP] PlayerCat 节点未找到")
		return
	var chp: float = float(player.get("current_hp") if player.get("current_hp") != null else -1)
	var mhp: float = float(player.get("max_hp") if player.get("max_hp") != null else -1)
	var pct: int = int(chp / mhp * 100) if mhp > 0 else 0
	_log_step("  [HP t=%ds] %.0f / %.0f (%d%%)" % [t, chp, mhp, pct])
	if pct < 25 and mhp > 0:
		_bug("Layer %d t=%ds: 血量危急 %d%%" % [layer, t, pct])
		await _screenshot("L%d_lowhp_%ds" % [layer, t])

## ── 卡牌选择 ────────────────────────────────────────────────────────────

func _do_card_select(cs: Node, layer: int) -> void:
	# 找 OptionA/B/C 按钮
	var all_btns: Array[Button] = []
	_gather_buttons(cs, all_btns)

	# 过滤非禁用
	var active: Array[Button] = []
	for b in all_btns:
		if b.is_visible_in_tree() and not b.disabled and b.text != "—":
			active.append(b)

	if active.is_empty():
		_bug("Layer %d: 选卡弹窗无可用按钮（共找到%d个）" % [layer, all_btns.size()])
		return

	var pick: Button = active[0]
	_log_step("  选卡: [%s]" % pick.text.substr(0, 30))
	pick.pressed.emit()  # Godot4 正确做法

## ── 奇遇事件 ────────────────────────────────────────────────────────────

func _do_event(eq: Node) -> void:
	var cv: Node = eq.find_child("ChoicesVBox", true, false)
	if cv == null:
		_bug("奇遇：找不到 ChoicesVBox")
		return

	var btns: Array[Button] = []
	_gather_buttons(cv, btns)
	var active: Array[Button] = []
	for b in btns:
		if b.is_visible_in_tree() and not b.disabled:
			active.append(b)

	if active.is_empty():
		_bug("奇遇：无可用选项按钮")
		return

	_log_step("  奇遇选项: [%s]" % active[0].text.substr(0, 25))
	active[0].pressed.emit()
	await _wait(1.0)

	# 点「继续前行」
	var all_btns: Array[Button] = []
	_gather_buttons(eq, all_btns)
	for b in all_btns:
		if b.text == "继续前行" and b.is_visible_in_tree():
			_log_step("  奇遇：点继续")
			b.pressed.emit()
			break

## ── 商店 ────────────────────────────────────────────────────────────────

func _do_shop(scene: Node) -> void:
	var btns: Array[Button] = []
	_gather_buttons(scene, btns)
	for b in btns:
		if b.is_visible_in_tree() and ("跳过" in b.text or "Skip" in b.text) and not b.disabled:
			_log_step("  商店：跳过")
			b.pressed.emit()
			return
	_log_step("  商店：无操作（按钮: %d）" % btns.size())

## ── 营地操作 ────────────────────────────────────────────────────────────

func _select_starter(idx: int) -> void:
	var camp: Node = get_tree().current_scene
	if camp == null:
		return
	var btns: Variant = camp.get("_starter_choice_buttons")
	if btns == null or (btns as Array).size() <= idx:
		_bug("选猫按钮不存在（idx=%d）" % idx)
		return
	var b: Button = (btns as Array)[idx]
	_log_step("  → 按钮[%d]: %s" % [idx, b.text])
	b.pressed.emit()

func _press_next_day() -> void:
	var camp: Node = get_tree().current_scene
	if camp == null:
		return
	var btn: Variant = camp.get("_next_day_button")
	if btn != null and not (btn as Button).disabled:
		(btn as Button).pressed.emit()
		_log_step("  → 过一天")
	else:
		_log_step("  → 过一天按钮不可用或不存在")

func _open_expedition() -> void:
	var camp: Node = get_tree().current_scene
	if camp == null:
		return
	var btn: Variant = camp.get("_open_expedition_button")
	if btn != null and not (btn as Button).disabled:
		(btn as Button).pressed.emit()
		_log_step("  → 点击出征按钮")
	else:
		_bug("出征按钮不可用")
		get_tree().change_scene_to_file("res://scenes/expedition/ExpeditionMapUI.tscn")

func _start_expedition() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var btn: Node = scene.find_child("StartButton", true, false)
	if btn and btn is Button and not (btn as Button).disabled:
		(btn as Button).pressed.emit()
		_log_step("  → 点击「开始出征」")
	else:
		_bug("「开始出征」不可用，btn=%s" % str(btn))

## ── 工具 ────────────────────────────────────────────────────────────────

func _gather_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node as Button)
	for c in node.get_children():
		_gather_buttons(c, result)

func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout

func _screenshot(name: String) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		_log_step("  screenshot skipped: headless mode (%s)" % name)
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		_log_step("  screenshot skipped: no viewport texture (%s)" % name)
		return
	var img := texture.get_image()
	if img == null:
		_log_step("  screenshot skipped: no image in headless mode (%s)" % name)
		return
	var path := SCREENSHOT_DIR + name + ".png"
	if img.save_png(path) == OK:
		_screenshots.append(path)
		print("[AutoTest] 📸 " + name)
	else:
		_log_step("  screenshot skipped: save failed (%s)" % name)

func _log_step(msg: String) -> void:
	_log.append(msg)
	print("[AutoTest] " + msg)

func _bug(msg: String) -> void:
	_bugs.append("🐛 " + msg)
	_log.append("❌ BUG: " + msg)
	print("[AutoTest] ❌ BUG: " + msg)

func _write_report() -> void:
	var lines: Array[String] = []
	lines.append("# 喵喵远征 全流程测试报告")
	lines.append("## 执行日志")
	lines += _log
	lines.append("")
	lines.append("## Bug 汇总（共 %d 个）" % _bugs.size())
	if _bugs.is_empty():
		lines.append("✅ 无 bug")
	else:
		lines += _bugs
	lines.append("")
	lines.append("## 截图 %d 张" % _screenshots.size())
	lines += _screenshots
	var report := "\n".join(lines)
	var path := SCREENSHOT_DIR + "report.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
	print("[AutoTest] 报告写入: " + path)
	print(report)
