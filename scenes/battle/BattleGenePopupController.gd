extends RefCounted

const GameConstants := preload("res://data/constants.gd")

func show_choice(parent: Node, cat_name: String, level: int, gene_choices: Array[String], chosen_callback: Callable) -> Control:
	var popup := Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(popup)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480.0, 320.0)
	panel.position = Vector2(-240.0, -160.0)
	popup.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = "🎉 %s 升至 Lv%d！选择一个技能！" % [cat_name, level]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("int_as_enum_without_cast")
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title_lbl)

	var sep := HSeparator.new()
	vb.add_child(sep)

	for gene_id: String in gene_choices:
		var info: Dictionary = GameConstants.GENE_DISPLAY_ZH.get(gene_id, {"name": gene_id, "desc": ""})
		var rarity: String = str(GameConstants.GENE_RARITY.get(gene_id, "grey"))
		var rarity_zh: String = str(GameConstants.RARITY_DISPLAY_ZH.get(rarity, rarity))
		var is_active := GameConstants.ACTIVE_SKILL_GENE_POOL.has(gene_id)
		var type_tag := "[主动]" if is_active else "[被动]"
		var btn := Button.new()
		btn.text = "%s【%s】%s\n%s" % [str(info.get("name", gene_id)), rarity_zh, type_tag, str(info.get("desc", ""))]
		btn.clip_text = true
		@warning_ignore("int_as_enum_without_cast")
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.custom_minimum_size = Vector2(0.0, 60.0)
		btn.pressed.connect(chosen_callback.bind(gene_id))
		vb.add_child(btn)
	return popup

func show_replace(
	gene_popup: Control,
	new_gene_id: String,
	slot_genes: Array[String],
	replace_callback: Callable,
	abandon_callback: Callable
) -> void:
	if gene_popup == null:
		return
	for child: Node in gene_popup.get_children():
		if child is PanelContainer:
			child.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420.0, 280.0)
	panel.position = Vector2(-210.0, -140.0)
	gene_popup.add_child(panel)

	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var info: Dictionary = GameConstants.GENE_DISPLAY_ZH.get(new_gene_id, {"name": new_gene_id})
	var lbl := Label.new()
	lbl.text = "技能槽已满，选择替换或放弃「%s」：" % str(info.get("name", new_gene_id))
	@warning_ignore("int_as_enum_without_cast")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)

	for slot_idx in slot_genes.size():
		var slot_gene: String = slot_genes[slot_idx]
		var slot_info: Dictionary = GameConstants.GENE_DISPLAY_ZH.get(slot_gene, {"name": slot_gene})
		var btn := Button.new()
		btn.text = "替换 槽%d：「%s」" % [slot_idx + 1, str(slot_info.get("name", slot_gene))]
		btn.clip_text = true
		btn.pressed.connect(replace_callback.bind(slot_idx, new_gene_id))
		vb.add_child(btn)

	var abandon_btn := Button.new()
	abandon_btn.text = "放弃「%s」" % str(info.get("name", new_gene_id))
	abandon_btn.clip_text = true
	abandon_btn.pressed.connect(abandon_callback)
	vb.add_child(abandon_btn)
