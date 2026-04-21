extends Control

const ExpeditionSystem := preload("res://scenes/expedition/ExpeditionSystem.gd")
const GameConsts := preload("res://data/constants.gd")
const CAMP_SCENE_PATH := "res://scenes/camp/CampScene.tscn"

@onready var _cat_option: OptionButton = $Panel/VBox/SetupRow/CatOption
@onready var _start_button: Button = $Panel/VBox/SetupRow/StartButton
@onready var _back_button: Button = $Panel/VBox/SetupRow/BackToCampButton
@onready var _layer_label: Label = $Panel/VBox/LayerLabel
@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _node_row: HBoxContainer = $Panel/VBox/NodeRow
@onready var _log_text: RichTextLabel = $Panel/VBox/LogText

var _current_nodes: Array[Dictionary] = []
var _eligible_cats: Array[CatData] = []
var _system := ExpeditionSystem.new()

func _ready() -> void:
	randomize()
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_refresh_cat_options()
	_process_returned_battle()
	_process_returned_shop()
	_refresh_view()

func _refresh_cat_options() -> void:
	_eligible_cats.clear()
	_cat_option.clear()
	var game_state := _get_game_state()
	if game_state == null:
		_cat_option.add_item("Missing game state")
		_cat_option.disabled = true
		_start_button.disabled = true
		return
	if game_state.expedition_active:
		var expedition_cat := _find_expedition_cat(game_state)
		var label := "Expedition in progress"
		if expedition_cat != null:
			label = "Expedition in progress: %s" % expedition_cat.cat_name
		_cat_option.add_item(label)
		_cat_option.disabled = true
		_start_button.disabled = false
		return
	_eligible_cats = _get_expedition_candidates(game_state)
	if _eligible_cats.is_empty():
		_cat_option.add_item("No expedition cat available")
		_cat_option.disabled = true
		_start_button.disabled = true
		return
	for idx in _eligible_cats.size():
		var cat: CatData = _eligible_cats[idx]
		var label := "%s - %s/%s" % [
			cat.cat_name,
			GameConsts.profession_zh(cat.profession),
			GameConsts.breed_zh(cat.breed)
		]
		_cat_option.add_item(label, idx)
	_cat_option.disabled = false
	_start_button.disabled = false

func _on_start_pressed() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		_status_label.text = "Game state missing."
		return
	if game_state.expedition_active:
		_status_label.text = "Expedition already in progress."
		_generate_nodes_for_current_layer()
		_refresh_nodes()
		return
	var cat := _selected_cat()
	var start_error := _system.can_start_expedition(game_state, cat)
	if not start_error.is_empty():
		_status_label.text = start_error
		return
	if not _system.start_expedition(game_state, cat):
		_status_label.text = "Failed to start expedition."
		return
	_status_label.text = "Sent %s on expedition." % cat.cat_name
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.expedition_started.emit(cat)
	_refresh_cat_options()
	_generate_nodes_for_current_layer()
	_refresh_view()

func _on_back_pressed() -> void:
	_go_to_camp()

func _process_returned_shop() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager == null or not bool(scene_manager.get("returned_from_shop")):
		return
	scene_manager.set("returned_from_shop", false)
	_status_label.text = "Shop finished. Continue forward."
	_generate_nodes_for_current_layer()

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
		_layer_label.text = "Layer: -"
		_log_text.text = "Game state missing."
		_clear_nodes()
		return
	if not game_state.expedition_active:
		_layer_label.text = "Layer: -"
		if _eligible_cats.is_empty():
			_log_text.text = "No cat can join an expedition right now."
		else:
			_log_text.text = "Pick one cat to start an expedition."
		_clear_nodes()
		return
	_layer_label.text = "Layer: %d / %d" % [game_state.expedition_layer, GameConsts.EXPEDITION_TOTAL_LAYERS]
	_log_text.text = "Wins: %d\nBuffs: %s\nActive genes: %d" % [
		game_state.expedition_battle_wins,
		_expedition_buffs_text(game_state.expedition_buffs),
		game_state.expedition_active_genes.size()
	]
	if _current_nodes.is_empty():
		_generate_nodes_for_current_layer()
	_refresh_nodes()

func _refresh_nodes() -> void:
	_clear_nodes()
	var display_count := mini(_current_nodes.size(), 2)
	for idx in display_count:
		var node_data: Dictionary = _current_nodes[idx]
		var button := Button.new()
		button.custom_minimum_size = Vector2(260.0, 120.0)
		button.text = str(node_data.get("label", "Node"))
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
			var scene_manager := _get_scene_manager()
			if scene_manager != null:
				scene_manager.go_to_shop()
			else:
				_status_label.text = "Shop unavailable."
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
	_status_label.text = "Expedition finished. Coins earned: %d." % reward
	_go_to_camp()

func _selected_cat() -> CatData:
	if _eligible_cats.is_empty():
		return null
	var index := clampi(_cat_option.selected, 0, _eligible_cats.size() - 1)
	return _eligible_cats[index]

func _get_expedition_candidates(game_state: Node) -> Array[CatData]:
	if game_state == null:
		return []
	if game_state.has_method("get_expedition_candidates"):
		return game_state.get_expedition_candidates()
	var candidates: Array[CatData] = []
	for cat: CatData in game_state.get_living_cats():
		if cat != null and cat.health == GameConsts.HEALTH_STATE_HEALTHY:
			candidates.append(cat)
	return candidates

func _find_expedition_cat(game_state: Node) -> CatData:
	if game_state == null:
		return null
	for cat: CatData in game_state.cats:
		if cat != null and cat.id == game_state.expedition_cat_id:
			return cat
	return null

func _go_to_camp() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager != null and scene_manager.has_method("go_to_camp"):
		scene_manager.call_deferred("go_to_camp")
		return
	get_tree().call_deferred("change_scene_to_file", CAMP_SCENE_PATH)

func _node_label(node_type: String) -> String:
	match node_type:
		"battle_normal":
			return "Normal battle"
		"battle_elite":
			return "Elite battle"
		"battle_boss":
			return "Boss battle"
		"event_question":
			return "Question event"
		"shop":
			return "Shop"
		_:
			return "Node"

func _expedition_buffs_text(buffs: Array) -> String:
	if buffs.is_empty():
		return "None"
	var labels: PackedStringArray = []
	for buff in buffs:
		var buff_id := str(buff)
		if buff_id == "hp_cap_minus_5":
			labels.append("Max HP -5%")
		elif buff_id.begins_with("mystery_buff_"):
			labels.append("Mystery buff")
		else:
			labels.append(buff_id)
	return ", ".join(labels)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")
