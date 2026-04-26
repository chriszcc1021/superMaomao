## QuestionEventUI.gd — 奇遇事件选择弹窗（全屏遮罩，代码驱动 UI）
extends Control

const QuestionEvents := preload("res://data/question_events.gd")
const CatFactory     := preload("res://data/cat_factory.gd")

## 选择完成后发出：传出已选效果列表，供调用方处理
signal choice_made(effects: Array)

var _event_data: Dictionary = {}
var _choice_buttons: Array[Button] = []
var _result_label: Label = null
var _confirm_btn: Button = null
var _pending_effects: Array = []

func _ready() -> void:
	_build_ui()

func setup(event_data: Dictionary) -> void:
	_event_data = event_data
	_refresh_ui()

## ── UI 构建 ──────────────────────────────────────────

func _build_ui() -> void:
	# 全屏半透明遮罩
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# 中央面板
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 460)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_top = -230
	panel.offset_right = 340
	panel.offset_bottom = 230
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_row)

	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.add_theme_font_size_override("font_size", 32)
	title_row.add_child(icon_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	title_row.add_child(spacer)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title_label)

	# 分割线
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 描述文字
	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(desc_label)

	# 选项容器
	var choices_vbox := VBoxContainer.new()
	choices_vbox.name = "ChoicesVBox"
	choices_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(choices_vbox)

	# 结果说明（选完后显示）
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_result_label.visible = false
	vbox.add_child(_result_label)

	# 继续按钮（选完后才显示）
	_confirm_btn = Button.new()
	_confirm_btn.text = "继续前行"
	_confirm_btn.custom_minimum_size = Vector2(160, 44)
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)

## ── 数据刷新 ──────────────────────────────────────────

func _refresh_ui() -> void:
	if _event_data.is_empty():
		return
	var icon_label := _find_node("IconLabel") as Label
	var title_label := _find_node("TitleLabel") as Label
	var desc_label := _find_node("DescLabel") as Label
	var choices_vbox := _find_node("ChoicesVBox") as VBoxContainer

	if icon_label:
		icon_label.text = str(_event_data.get("icon", "❓"))
	if title_label:
		title_label.text = str(_event_data.get("title", "奇遇"))
	if desc_label:
		desc_label.text = str(_event_data.get("description", ""))
	if choices_vbox == null:
		return

	# 清除旧选项
	for child in choices_vbox.get_children():
		child.queue_free()
	_choice_buttons.clear()

	var choices: Array = _event_data.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := _build_choice_button(choice, i)
		choices_vbox.add_child(btn)
		_choice_buttons.append(btn)

func _build_choice_button(choice: Dictionary, idx: int) -> Button:
	var btn := Button.new()
	var label: String = str(choice.get("label", "选项"))
	var desc: String = str(choice.get("desc", ""))
	btn.text = label + "\n" + desc
	btn.custom_minimum_size = Vector2(0, 54)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_choice_pressed.bind(idx))
	return btn

## ── 事件处理 ──────────────────────────────────────────

func _on_choice_pressed(idx: int) -> void:
	var choices: Array = _event_data.get("choices", [])
	if idx >= choices.size():
		return

	# 禁用所有选项按钮
	for btn in _choice_buttons:
		btn.disabled = true

	var choice: Dictionary = choices[idx]
	var effects: Array = choice.get("effects", [])

	# 应用所有效果，收集结果描述
	var result_lines: Array[String] = []
	var game_state := get_node_or_null("/root/GameState")
	for effect: Dictionary in effects:
		var result_desc := _apply_effect(effect, game_state)
		if not result_desc.is_empty():
			result_lines.append(result_desc)

	_pending_effects = effects

	# 显示结果
	if _result_label:
		_result_label.text = "\n".join(result_lines) if result_lines.size() > 0 else "无事发生。"
		_result_label.visible = true
	if _confirm_btn:
		_confirm_btn.visible = true

func _on_confirm_pressed() -> void:
	choice_made.emit(_pending_effects)
	queue_free()

## ── 效果应用 ──────────────────────────────────────────

func _apply_effect(effect: Dictionary, game_state: Node) -> String:
	var effect_type: String = str(effect.get("type", ""))
	var value: float = float(effect.get("value", 0))

	match effect_type:
		"immediate_coins":
			if value == -1:  # random coins 20-30
				value = float(randi_range(20, 30))
			if game_state:
				if value > 0:
					game_state.add_coins(int(value))
				else:
					game_state.spend_coins(int(-value))
			return "金币 %s%d" % ["+" if value > 0 else "", int(value)]

		"immediate_hp_pct":
			# 存储到 expedition_buffs，在战斗开始前由 BattleScene 处理
			# 但"立即回血"需要在进入战斗时以当前HP为基础计算
			if value > 0:
				_add_expedition_buff(game_state, "immediate_hp_restore_pct", value)
				return "HP 恢复 %d%%" % int(value * 100)
			else:
				_add_expedition_buff(game_state, "immediate_hp_cost_pct", -value)
				return "HP -%d%%" % int(-value * 100)

		"buff_attack":
			_add_expedition_buff(game_state, "attack", value)
			return "攻击 %s%d%%" % ["+" if value > 0 else "", int(value * 100)]

		"buff_crit_rate":
			_add_expedition_buff(game_state, "crit_rate", value)
			return "暴击率 +%d%%" % int(value * 100)

		"buff_crit_mult":
			_add_expedition_buff(game_state, "crit_mult", value)
			return "暴击伤害 +%d%%" % int(value * 100)

		"buff_move_speed":
			_add_expedition_buff(game_state, "move_speed", value)
			return "移速 +%d%%" % int(value * 100)

		"buff_aspd":
			_add_expedition_buff(game_state, "aspd", value)
			return "攻速 +%d%%" % int(value * 100)

		"buff_max_hp":
			_add_expedition_buff(game_state, "max_hp", value)
			return "HP上限 +%d%%" % int(value * 100)

		"next_battle_dmg_taken":
			_add_expedition_buff(game_state, "dmg_taken_next", value)
			if value < 0:
				return "下一场受到伤害 %d%%" % int(value * 100)
			else:
				return "下一场受到伤害 +%d%%" % int(value * 100)

		"buff_regen_per_battle":
			_add_expedition_buff(game_state, "regen_per_battle", value)
			return "每场战斗开始回 %d%% HP" % int(value * 100)

		"buff_immunity_next_debuff":
			_add_expedition_buff(game_state, "immunity_next_debuff", 1.0)
			return "免疫下一个负面效果"

		"stray_cat":
			var added := 0
			for _i in range(int(value)):
				var cat := CatFactory.create_random_stray_cat("event_stray", "流浪猫")
				if game_state and game_state.enqueue_stray_cat(cat):
					added += 1
			if added > 0:
				return "%d 只流浪猫将在营地等待你" % added
			else:
				return "营地队列已满，它们只能就此分别"

		"stray_cat_injured":
			var cat := CatFactory.create_random_stray_cat("event_stray", "受伤流浪猫")
			if "health" in cat:
				cat.health = "injured"
			if game_state and game_state.enqueue_stray_cat(cat):
				return "受伤的流浪猫将在营地等待"
			return "营地队列已满，它只能继续流浪"

		"unknown_buff":
			# 随机给一个好buff
			var buffs := [
				{"key": "max_hp",    "val": 0.15, "desc": "HP上限 +15%"},
				{"key": "attack",    "val": 0.15, "desc": "攻击 +15%"},
				{"key": "crit_rate", "val": 0.10, "desc": "暴击率 +10%"},
				{"key": "move_speed","val": 0.15, "desc": "移速 +15%"},
				{"key": "aspd",      "val": 0.15, "desc": "攻速 +15%"},
			]
			var chosen: Dictionary = buffs[randi() % buffs.size()]
			_add_expedition_buff(game_state, str(chosen["key"]), float(chosen["val"]))
			return "✨ 神秘祝福揭晓：%s" % str(chosen["desc"])

		"unknown_good_or_bad":
			# 50/50：好事或坏事
			if randi() % 2 == 0:
				# 好事
				_add_expedition_buff(game_state, "attack", 0.20)
				return "✨ 镜碎好运！攻击 +20%"
			else:
				# 坏事
				_add_expedition_buff(game_state, "max_hp", -0.20)
				return "💀 镜碎霉运！HP上限 -20%"

		"gain_card_rarity":
			# 标记：在进入下一场战斗时获得一张高稀有卡
			_add_expedition_buff(game_state, "grant_card_on_battle_start", 1.0)
			return "进入下一场战斗时将获得一张稀有卡"

		"exchange_card":
			# 标记：下场战斗开始时触发换卡逻辑
			_add_expedition_buff(game_state, "exchange_worst_card", 1.0)
			return "进入下一场战斗时将换出最差手牌"

		"discard_worst_card":
			_add_expedition_buff(game_state, "discard_worst_card", 1.0)
			return "最差的一张手牌将被弃置"

		"lose_random_buff":
			if game_state and game_state.has_method("pop_random_expedition_buff"):
				var removed: Dictionary = game_state.pop_random_expedition_buff()
				if removed.is_empty():
					return "没有可以失去的 buff"
				return "失去了 buff：%s" % str(removed.get("label", "某个增益"))
			return "没有可以失去的 buff"

		"gamble_all_coins":
			if game_state == null:
				return "无效"
			var coins: int = int(game_state.coins)
			if randi() % 2 == 0:
				game_state.add_coins(coins)
				return "🎉 大赢！金币从 %d → %d" % [coins, coins * 2]
			else:
				game_state.spend_coins(coins)
				return "💸 爆零！金币全没了"

		"gamble_small":
			if game_state == null:
				return "无效"
			if randf() < 0.60:
				game_state.add_coins(40)
				return "🎉 小赢！+40 金币"
			else:
				game_state.spend_coins(20)
				return "💸 小输。-20 金币"

		"gain_active_gene":
			# 随机给一个主动基因
			var active_genes := ["survival_rush", "coward", "desperado", "tenacity_revive",
				"self_heal", "lone_pride"]
			var cat := _get_expedition_cat(game_state)
			if cat:
				# 找空槽
				for slot_i in range(3):
					if str(cat.get_special_genes()[slot_i] if slot_i < cat.get_special_genes().size() else "") == "":
						cat.set_special_gene(slot_i, active_genes[randi() % active_genes.size()])
						return "获得主动基因写入基因槽"
			return "基因槽已满，无法写入"

	return ""

func _add_expedition_buff(game_state: Node, effect_key: String, value: float) -> void:
	if game_state == null:
		return
	if game_state.has_method("add_expedition_buff_dict"):
		game_state.add_expedition_buff_dict({"effect_key": effect_key, "value": value, "label": effect_key})
	elif game_state.has_method("add_expedition_buff"):
		# fallback: store as string (legacy)
		game_state.add_expedition_buff("%s:%.3f" % [effect_key, value])

func _get_expedition_cat(game_state: Node) -> Object:
	if game_state == null:
		return null
	var cat_id: String = str(game_state.expedition_cat_id)
	for cat in game_state.cats:
		if str(cat.id) == cat_id:
			return cat
	return null

func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)
