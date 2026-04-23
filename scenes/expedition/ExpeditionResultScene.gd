## ExpeditionResultScene.gd — 独立出征结算场景
extends Control

const GameConstants := preload("res://data/constants.gd")

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var scene_manager := get_node_or_null("/root/SceneManager")
	var result_data: Dictionary = {}
	if scene_manager and "expedition_result_data" in scene_manager:
		result_data = scene_manager.expedition_result_data
	_build_ui(result_data)

func _build_ui(data: Dictionary) -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# 中央容器
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(640, 0)
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -320
	center.offset_top = -280
	center.offset_right = 320
	center.offset_bottom = 280
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var success: bool = bool(data.get("success", false))
	var cat_retired: bool = bool(data.get("cat_retired", false))
	var cat_name: String = str(data.get("cat_name", "猫咪"))
	var profession: String = str(data.get("profession_zh", ""))
	var level_from: int = int(data.get("level_from", 1))
	var level_to: int = int(data.get("level_to", 1))
	var layers_reached: int = int(data.get("layers_reached", 0))
	var battle_wins: int = int(data.get("battle_wins", 0))
	var reward: int = int(data.get("reward", 0))
	var active_genes: Array = data.get("active_genes", [])
	var buffs_gained: Array = data.get("buffs_gained", [])

	# ── 大标题 ──
	var title_label := Label.new()
	if cat_retired:
		title_label.text = "💀  英勇落败"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
	elif success:
		title_label.text = "🏆  远征凯旋"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	else:
		title_label.text = "🏕️  平安归来"
		title_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title_label)

	# ── 猫的信息 ──
	var cat_info := Label.new()
	var cat_info_text := cat_name
	if not profession.is_empty():
		cat_info_text += "  ·  %s" % profession
	if level_from > 0:
		cat_info_text += "  ·  Lv %d" % level_to
	cat_info.text = cat_info_text
	cat_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_info.add_theme_font_size_override("font_size", 18)
	cat_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	center.add_child(cat_info)

	var sep1 := HSeparator.new()
	center.add_child(sep1)

	# ── 战果 ──
	var stats_label := Label.new()
	stats_label.text = "── 战果 ──"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	center.add_child(stats_label)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 60)
	center.add_child(stats_row)

	_add_stat(stats_row, "到达层数", str(layers_reached))
	_add_stat(stats_row, "胜利场次", str(battle_wins))

	# ── 成长 ──
	var sep2 := HSeparator.new()
	center.add_child(sep2)

	var growth_label := Label.new()
	growth_label.text = "── 成长 ──"
	growth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	growth_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	center.add_child(growth_label)

	var level_label := Label.new()
	if level_to > level_from:
		level_label.text = "等级  %d  →  %d  ⬆" % [level_from, level_to]
		level_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	else:
		level_label.text = "等级  %d" % level_to
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 16)
	center.add_child(level_label)

	if active_genes.size() > 0:
		var genes_label := Label.new()
		genes_label.text = "获得主动基因：" + "  ".join(active_genes)
		genes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		genes_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7))
		center.add_child(genes_label)
	elif not cat_retired:
		var no_gene_label := Label.new()
		no_gene_label.text = "本次未获得新主动基因"
		no_gene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_gene_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		center.add_child(no_gene_label)

	# ── 奖励 ──
	var sep3 := HSeparator.new()
	center.add_child(sep3)

	var reward_title := Label.new()
	reward_title.text = "── 奖励 ──"
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	center.add_child(reward_title)

	var reward_label := Label.new()
	reward_label.text = "💰  +%d  金币" % reward
	reward_label.add_theme_font_size_override("font_size", 28)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	center.add_child(reward_label)

	if cat_retired:
		var retire_label := Label.new()
		retire_label.text = "%s 已退休，不会再出征了。" % cat_name
		retire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		retire_label.add_theme_color_override("font_color", Color(0.75, 0.45, 0.45))
		center.add_child(retire_label)

	var sep4 := HSeparator.new()
	center.add_child(sep4)

	# ── 返回按钮 ──
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "返回营地"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_to_camp)
	btn_row.add_child(back_btn)

func _add_stat(parent: HBoxContainer, title: String, value: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var val_label := Label.new()
	val_label.text = value
	val_label.add_theme_font_size_override("font_size", 28)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(val_label)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(title_label)

	parent.add_child(vbox)

func _on_back_to_camp() -> void:
	var scene_manager := get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_method("go_to_camp"):
		scene_manager.go_to_camp()
	else:
		get_tree().change_scene_to_file("res://scenes/camp/CampScene.tscn")
