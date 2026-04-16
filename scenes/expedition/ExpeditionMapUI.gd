extends Control
const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const ExpeditionSystem := preload("res://scenes/expedition/ExpeditionSystem.gd")
@onready var _cat_option: OptionButton = $Panel/VBox/SetupRow/CatOption
@onready var _start_button: Button = $Panel/VBox/SetupRow/StartButton
@onready var _back_button: Button = $Panel/VBox/SetupRow/BackToCampButton
@onready var _layer_label: Label = $Panel/VBox/LayerLabel
@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _node_row: HBoxContainer = $Panel/VBox/NodeRow
@onready var _log_text: RichTextLabel = $Panel/VBox/LogText

var _current_nodes: Array[Dictionary] = []
var _system := ExpeditionSystem.new()

func _ready() -> void:
	randomize()
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_cat_options()
	_process_returned_battle()
	_refresh_view()

func _refresh_cat_options() -> void:
	_cat_option.clear()
	var game_state := _get_game_state()
	if game_state == null:
		return
	var idx := 0
	for cat: CatData in game_state.get_living_cats():
		var label := "%s，%s/%s" % [cat.cat_name, _profession_zh(cat.profession), _breed_zh(cat.breed)]
		_cat_option.add_item(label, idx)
		idx += 1

func _on_start_pressed() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	if game_state.expedition_active:
		_status_label.text = "远征已在进行中。"
		_generate_nodes_for_current_layer()
		_refresh_nodes()
		return
	var cat := _selected_cat()
	var start_error := _system.can_start_expedition(cat)
	if not start_error.is_empty():
		_status_label.text = start_error
		return
	if not _system.start_expedition(game_state, cat):
		_status_label.text = "远征开始失败。"
		return
	_status_label.text = "已派遣 %s 出征。" % cat.cat_name
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.expedition_started.emit(cat)
	_generate_nodes_for_current_layer()
	_refresh_view()

func _on_back_pressed() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.go_to_camp()

func _process_returned_battle() -> void:
	var result := _system.process_returned_battle(_get_scene_manager(), _get_game_state())
	if not bool(result.get("handled", false)):
		return
	if bool(result.get("finished", false)):
		_finish_expedition(bool(result.get("success", false)))
		return
	_status_label.text = str(result.get("status", ""))
	_generate_nodes_for_current_layer()

func _generate_nodes_for_current_layer() -> void:
	_current_nodes = _system.generate_nodes_for_current_layer(_get_game_state())
	for node_data in _current_nodes:
		node_data["label"] = _node_label(str(node_data.get("type", "")))

func _refresh_view() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	if not game_state.expedition_active:
		_layer_label.text = "层数: -"
		_log_text.text = "请选择一只猫开始远征。"
		_clear_nodes()
		return
	_layer_label.text = "层数: %d / %d" % [game_state.expedition_layer, GameConstants.EXPEDITION_TOTAL_LAYERS]
	_log_text.text = "胜场: %d\n远征Buff: %s\n获得主动基因: %d" % [
		game_state.expedition_battle_wins,
		_expedition_buffs_text(game_state.expedition_buffs),
		game_state.expedition_active_genes.size()
	]
	if _current_nodes.is_empty():
		_generate_nodes_for_current_layer()
	_refresh_nodes()

func _refresh_nodes() -> void:
	_clear_nodes()
	for idx in _current_nodes.size():
		var node_data: Dictionary = _current_nodes[idx]
		var button := Button.new()
		button.custom_minimum_size = Vector2(220.0, 110.0)
		button.text = str(node_data.get("label", "节点"))
		button.pressed.connect(_on_node_pressed.bind(idx))
		_node_row.add_child(button)

func _clear_nodes() -> void:
	for child: Node in _node_row.get_children():
		child.queue_free()

func _on_node_pressed(idx: int) -> void:
	if idx < 0 or idx >= _current_nodes.size():
		return
	var game_state := _get_game_state()
	if game_state == null or not game_state.expedition_active:
		return
	var node_type: String = str(_current_nodes[idx].get("type", "battle_normal"))
	match node_type:
		"battle_normal", "battle_elite", "battle_boss":
			var scene_manager := _get_scene_manager()
			if scene_manager != null:
				scene_manager.go_to_battle(node_type)
		"event_question":
			_status_label.text = _system.resolve_question_event(game_state)
			_advance_non_battle_layer()
		"shop":
			_status_label.text = _system.resolve_shop_event()
			_advance_non_battle_layer()

func _advance_non_battle_layer() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	if _system.advance_non_battle_layer(game_state):
		_finish_expedition(false)
		return
	_generate_nodes_for_current_layer()
	_refresh_view()

func _finish_expedition(success: bool) -> void:
	var reward := _system.finish_expedition(_get_game_state(), _get_event_bus(), success)
	_status_label.text = "远征结束，获得金币：%d。" % reward
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.go_to_camp()

func _selected_cat() -> CatData:
	var game_state := _get_game_state()
	if game_state == null:
		return null
	var living: Array[CatData] = game_state.get_living_cats()
	if living.is_empty():
		return null
	var index := clampi(_cat_option.selected, 0, living.size() - 1)
	return living[index]

func _node_label(node_type: String) -> String:
	match node_type:
		"battle_normal":
			return "⚔️ 普通战（90秒生存）"
		"battle_elite":
			return "💀 精英战（120-180秒）"
		"battle_boss":
			return "👑 首领战（猩猩大王）"
		"event_question":
			return "❓ 问号事件"
		"shop":
			return "🛒 商店（换卡）"
		_:
			return "节点"

func _profession_zh(profession_id: String) -> String:
	return str(GameConstants.PROFESSION_DISPLAY_ZH.get(profession_id, profession_id))

func _breed_zh(breed_id: String) -> String:
	return str(GameConstants.BREED_DISPLAY_ZH.get(breed_id, breed_id))

func _expedition_buffs_text(buffs: Array) -> String:
	if buffs.is_empty():
		return "无"
	var labels: PackedStringArray = []
	for buff in buffs:
		var buff_id := str(buff)
		if buff_id == "hp_cap_minus_5":
			labels.append("生命上限-5%")
		elif buff_id.begins_with("mystery_buff_"):
			labels.append("神秘祝福")
		else:
			labels.append(buff_id)
	return "，".join(labels)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")
