extends Control

const ExpeditionSystem  := preload("res://scenes/expedition/ExpeditionSystem.gd")
const QuestionEventUIScene := preload("res://scenes/expedition/QuestionEventUI.tscn")
const QuestionEvents    := preload("res://data/question_events.gd")
const CatData           := preload("res://resources/CatData.gd")
const GameConsts        := preload("res://data/constants.gd")
const ArtIcon           := preload("res://scenes/common/ArtIcon.gd")
const UISkin            := preload("res://scenes/common/UISkin.gd")
const CAMP_SCENE_PATH   := "res://scenes/camp/CampScene.tscn"
@onready var _panel: PanelContainer = $Panel
@onready var _cat_option: OptionButton = $Panel/VBox/SetupRow/CatOption
@onready var _start_button: Button = $Panel/VBox/SetupRow/StartButton
@onready var _back_button: Button = $Panel/VBox/SetupRow/BackToCampButton
@onready var _title_label: Label = $Panel/VBox/Title
@onready var _layer_label: Label = $Panel/VBox/LayerLabel
@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _node_row: HBoxContainer = $Panel/VBox/NodeRow
@onready var _log_text: RichTextLabel = $Panel/VBox/LogText

var _current_nodes: Array[Dictionary] = []
var _eligible_cats: Array[CatData] = []
var _system := ExpeditionSystem.new()

func _ready() -> void:
	randomize()
	_apply_skin()
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
		_cat_option.add_item("缺少游戏状态")
		_cat_option.disabled = true
		_start_button.disabled = true
		return
	if game_state.expedition_active:
		var expedition_cat := _find_expedition_cat(game_state)
		var label := "远征进行中"
		if expedition_cat != null:
			label = "远征进行中：%s" % expedition_cat.cat_name
		_cat_option.add_item(label)
		_cat_option.disabled = true
		_start_button.disabled = false
		return
	_eligible_cats = _get_expedition_candidates(game_state)
	if _eligible_cats.is_empty():
		_cat_option.add_item("当前没有可出征的猫")
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
		_status_label.text = "缺少游戏状态。"
		return
	if game_state.expedition_active:
		_status_label.text = "远征已经在进行中。"
		_generate_nodes_for_current_layer()
		_refresh_nodes()
		return
	var cat := _selected_cat()
	var start_error := _system.can_start_expedition(game_state, cat)
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
	_status_label.text = "商店结束，继续前进。"
	_generate_nodes_for_current_layer()

func _process_returned_battle() -> void:
	var result := _system.process_returned_battle(_get_scene_manager(), _get_game_state())
	if not bool(result.get("handled", false)):
		return
	if bool(result.get("finished", false)):
		_finish_expedition(bool(result.get("success", false)), result)
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
		_layer_label.text = "层数: -"
		_log_text.text = "缺少游戏状态。"
		_clear_nodes()
		return
	# 远征中仍可返回营地（远征状态保留，回来继续）
	_back_button.visible = true
	if not game_state.expedition_active:
		_layer_label.text = "层数: -"
		if _eligible_cats.is_empty():
			_log_text.text = "当前没有可出征的猫。"
		else:
			_log_text.text = "请选择一只猫开始远征。"
		_clear_nodes()
		return
	_layer_label.text = "层数: %d / %d" % [game_state.expedition_layer, GameConsts.EXPEDITION_TOTAL_LAYERS]
	_log_text.text = "胜场: %d\n增益: %s\n获得主动基因: %d" % [
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
		button.text = "\n\n" + str(node_data.get("label", "节点"))
		UISkin.apply_button(button, _node_color(str(node_data.get("type", "battle_normal"))))
		button.pressed.connect(_on_node_pressed.bind(idx))
		_node_row.add_child(button)
		var icon := ArtIcon.new()
		icon.setup(str(node_data.get("type", "battle_normal")))
		icon.size = Vector2(52.0, 52.0)
		icon.position = Vector2(104.0, 14.0)
		button.add_child(icon)

func _apply_skin() -> void:
	UISkin.apply_panel(_panel)
	UISkin.apply_button(_start_button, Color(0.58, 0.74, 0.38, 1.0))
	UISkin.apply_button(_back_button, Color(0.72, 0.58, 0.42, 1.0))
	UISkin.apply_button(_cat_option, Color(0.92, 0.78, 0.52, 1.0))
	UISkin.apply_label(_title_label)
	UISkin.apply_label(_layer_label)
	UISkin.apply_label(_status_label)
	UISkin.apply_rich_text(_log_text)

func _node_color(node_type: String) -> Color:
	match node_type:
		"battle_elite":
			return Color(0.66, 0.48, 0.86, 1.0)
		"battle_boss":
			return Color(0.86, 0.38, 0.32, 1.0)
		"event_question":
			return Color(0.42, 0.66, 0.86, 1.0)
		"shop":
			return Color(0.86, 0.66, 0.34, 1.0)
	return Color(0.58, 0.72, 0.42, 1.0)

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
			_show_question_event()
			return  # 等待玩家选择，不立即推层
		"shop":
			var scene_manager := _get_scene_manager()
			if scene_manager != null:
				scene_manager.go_to_shop()
			else:
				_status_label.text = "商店当前不可用。"
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

## 奇遇：弹出选择 UI
func _show_question_event() -> void:
	var event_data := QuestionEvents.get_random_event()
	var ui: Control = QuestionEventUIScene.instantiate()
	add_child(ui)
	ui.setup(event_data)
	# 等待玩家选择完毕后推层
	ui.choice_made.connect(func(_effects): _advance_non_battle_layer(), CONNECT_ONE_SHOT)

func _finish_expedition(success: bool, result: Dictionary = {}) -> void:
	var game_state := _get_game_state()
	# 收集结算数据（clear_expedition_state 之前）
	var cat := _find_expedition_cat(game_state)
	var level_from: int = int(cat.level) if cat else 1
	var active_genes_gained: Array = []
	if game_state:
		for g: String in game_state.expedition_active_genes:
			active_genes_gained.append(g)
	var battle_result: Dictionary = result.get("battle_result", {})
	var cat_retired: bool = bool(battle_result.get("cat_retired", false))
	var layers: int = int(game_state.expedition_layer) if game_state else 0
	var wins: int = int(game_state.expedition_battle_wins) if game_state else 0
	# 执行结算逻辑（写金币、清状态）
	var reward := _system.finish_expedition(game_state, _get_event_bus(), success, battle_result)
	# 组装结算数据传给结算场景
	var result_data := {
		"success": success,
		"cat_retired": cat_retired,
		"cat_name": cat.cat_name if cat else "猫咪",
		"profession_zh": GameConsts.profession_zh(cat.profession) if cat else "",
		"level_from": level_from,
		"level_to": cat.level if cat else level_from,
		"layers_reached": layers,
		"battle_wins": wins,
		"reward": reward,
		"active_genes": active_genes_gained,
	}
	var scene_manager := _get_scene_manager()
	if scene_manager and scene_manager.has_method("go_to_expedition_result"):
		scene_manager.go_to_expedition_result(result_data)
	else:
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
		# 通过 Node 引用调用时返回 Variant，用 assign() 安全转换为 Array[CatData]
		var raw = game_state.get_expedition_candidates()
		var result: Array[CatData] = []
		result.assign(raw)
		return result
	var candidates: Array[CatData] = []
	for cat: CatData in game_state.get_living_cats():
		if cat != null and cat.status != GameConsts.LIFECYCLE_STATUS_RETIRED and cat.health == GameConsts.HEALTH_STATE_HEALTHY:
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
			return "普通战斗"
		"battle_elite":
			return "精英战斗"
		"battle_boss":
			return "首领战斗"
		"event_question":
			return "问号事件"
		"shop":
			return "商店"
		_:
			return "节点"

func _expedition_buffs_text(buffs: Array) -> String:
	if buffs.is_empty():
		return "无"
	var labels: PackedStringArray = []
	for buff in buffs:
		var buff_id := str(buff)
		if buff_id == "hp_cap_minus_5":
			labels.append("生命上限 -5%")
		elif buff_id.begins_with("mystery_buff_"):
			labels.append("神秘祝福")
		else:
			labels.append(buff_id)
	return ", ".join(labels)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")
