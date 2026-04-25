extends Node

const GameConstants := preload("res://data/constants.gd")
const StarterCatPreviewScript := preload("res://scenes/camp/ui/StarterCatPreview.gd")

signal starter_choice_pressed(index: int)

var choice_buttons: Array[Button] = []

var _ui_layer: CanvasLayer = null
var _game_state: Node = null
var _time_manager: Node = null
var _overlay: Control = null
var _hint_label: Label = null
var _previews: Array[Control] = []
var _info_labels: Array[Label] = []
var _paused_time: bool = false

func setup(ui_layer: CanvasLayer, game_state: Node, time_manager: Node) -> void:
	_ui_layer = ui_layer
	_game_state = game_state
	_time_manager = time_manager
	_build_overlay()

func get_overlay() -> Control:
	return _overlay

func refresh() -> void:
	if _overlay == null or _game_state == null:
		return
	var needs_choice: bool = bool(_game_state.starter_selection_pending)
	_overlay.visible = needs_choice
	if not needs_choice:
		if _paused_time and _time_manager != null and bool(_time_manager.time_paused):
			_time_manager.resume()
		_paused_time = false
		return

	if _time_manager != null and not bool(_time_manager.time_paused):
		_time_manager.pause()
		_paused_time = true

	var candidates: Array = _game_state.starter_candidates
	for index in choice_buttons.size():
		var btn := choice_buttons[index]
		var has_cat: bool = index < candidates.size()
		btn.disabled = not has_cat
		if index < _previews.size():
			var preview: Control = _previews[index]
			if preview.has_method("setup"):
				preview.call("setup", candidates[index] if has_cat else null)
		if index < _info_labels.size():
			var lbl: Label = _info_labels[index]
			lbl.text = _starter_card_info_text(candidates[index]) if has_cat else ""

func _build_overlay() -> void:
	if _ui_layer == null or _overlay != null:
		return

	var overlay := ColorRect.new()
	overlay.name = "StarterOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.06, 0.10, 0.90)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980.0, 500.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -490.0
	panel.offset_top = -250.0
	panel.offset_right = 490.0
	panel.offset_bottom = 250.0
	overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)

	var title := Label.new()
	title.text = "✦ 选择你的第一只猫 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "从三只候选猫中选一只。选完后，一只异性流浪猫将很快到访营地。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	root.add_child(hint)
	_hint_label = hint

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 20)
	root.add_child(choices)

	for index in GameConstants.STARTER_CHOICE_COUNT:
		var card := _build_starter_card(index)
		choices.add_child(card)

	_ui_layer.add_child(overlay)
	_overlay = overlay

func _build_starter_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280.0, 390.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	var preview: Control = StarterCatPreviewScript.new()
	preview.custom_minimum_size = Vector2(280.0, 170.0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(preview)
	_previews.append(preview)

	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("int_as_enum_without_cast")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 13)
	inner.add_child(info)
	_info_labels.append(info)

	var btn := Button.new()
	btn.text = "选择此猫"
	btn.custom_minimum_size = Vector2(0.0, 40.0)
	btn.pressed.connect(_on_starter_choice_pressed.bind(index))
	inner.add_child(btn)
	choice_buttons.append(btn)

	return card

func _starter_card_info_text(cat) -> String:
	var gene_names: PackedStringArray = []
	for gene_id: String in cat.get_special_genes():
		var gene_info: Dictionary = GameConstants.GENE_DISPLAY_ZH.get(gene_id, {})
		var gene_name: String = str(gene_info.get("name", gene_id))
		gene_names.append(gene_name)
	var trait_text := "、".join(gene_names) if not gene_names.is_empty() else "无"
	return (
		"%s\n" % cat.cat_name
		+ "%s  %s  %s\n" % [GameConstants.sex_display(cat.sex), GameConstants.profession_zh(cat.profession), GameConstants.breed_zh(cat.breed)]
		+ "生命 %.0f  攻击 %.0f\n" % [cat.base_hp, cat.base_attack]
		+ "射程 %.1f  攻速 %.2f/s\n" % [cat.base_range, cat.base_attack_speed]
		+ "特性：%s" % trait_text
	)

func _on_starter_choice_pressed(index: int) -> void:
	starter_choice_pressed.emit(index)
