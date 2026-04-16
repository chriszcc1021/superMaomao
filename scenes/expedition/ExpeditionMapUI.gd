extends Control

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

@onready var _cat_option: OptionButton = $Panel/VBox/SetupRow/CatOption
@onready var _start_button: Button = $Panel/VBox/SetupRow/StartButton
@onready var _back_button: Button = $Panel/VBox/SetupRow/BackToCampButton
@onready var _layer_label: Label = $Panel/VBox/LayerLabel
@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _node_row: HBoxContainer = $Panel/VBox/NodeRow
@onready var _log_text: RichTextLabel = $Panel/VBox/LogText

var _current_nodes: Array[Dictionary] = []

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
	for cat: CatData in game_state.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		var label := "%s（%s/%s）" % [cat.cat_name, _profession_zh(cat.profession), _breed_zh(cat.breed)]
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
	if cat == null:
		_status_label.text = "没有可出征的猫咪。"
		return
	if cat.has_expeditioned:
		_status_label.text = "该猫已完成过一次远征。"
		return
	if cat.age_days < GameConstants.KITTEN_DAYS:
		_status_label.text = "幼猫不能出征。"
		return
	if cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
		_status_label.text = "老年猫不能出征。"
		return
	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		_status_label.text = "仅健康状态可出征。"
		return

	game_state.expedition_active = true
	game_state.expedition_cat_id = cat.id
	game_state.expedition_layer = 1
	game_state.expedition_battle_wins = 0
	game_state.expedition_buffs.clear()
	game_state.expedition_active_genes.clear()
	cat.status = GameConstants.LIFECYCLE_STATUS_EXPEDITION
	_status_label.text = "已派遣 %s 出征。" % cat.cat_name
	_generate_nodes_for_current_layer()
	_refresh_nodes()
	_refresh_view()

func _on_back_pressed() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.go_to_camp()

func _process_returned_battle() -> void:
	var scene_manager := _get_scene_manager()
	var game_state := _get_game_state()
	if scene_manager == null or game_state == null:
		return
	if not game_state.expedition_active:
		return
	var result: Dictionary = scene_manager.last_battle_result
	if result.is_empty():
		return
	scene_manager.last_battle_result = {}
	game_state.expedition_battle_wins += int(result.get("battle_wins", 0))
	for gene_id: String in result.get("active_genes_gained", []):
		game_state.expedition_active_genes.append(gene_id)
	var was_boss_battle := str(result.get("battle_node_type", "")) == "battle_boss"
	if was_boss_battle:
		_finish_expedition(bool(result.get("victory", false)))
		return
	game_state.expedition_layer += 1
	if game_state.expedition_layer > GameConstants.EXPEDITION_TOTAL_LAYERS:
		_finish_expedition(false)
		return
	_status_label.text = "战斗结束，进入下一层。"
	_generate_nodes_for_current_layer()

func _generate_nodes_for_current_layer() -> void:
	_current_nodes.clear()
	var game_state := _get_game_state()
	if game_state == null or not game_state.expedition_active:
		return
	var layer: int = int(game_state.expedition_layer)
	if layer >= GameConstants.EXPEDITION_BOSS_LAYER:
		_current_nodes.append({"type": "battle_boss", "label": "👑 首领战（猩猩大王）"})
		return
	var count := randi_range(2, 3)
	var probs: Dictionary = GameConstants.EXPEDITION_NODE_PROBABILITIES.get(layer, {})
	for _i in count:
		var node_type := _weighted_pick_node(probs)
		_current_nodes.append({"type": node_type, "label": _node_label(node_type)})

func _weighted_pick_node(probs: Dictionary) -> String:
	var roll := randf()
	var cumulative := 0.0
	for key: String in ["battle_normal", "battle_elite", "event_question", "shop"]:
		cumulative += float(probs.get(key, 0.0))
		if roll <= cumulative:
			return key
	return "battle_normal"

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
	_log_text.text = (
		"胜场: %d\n远征Buff: %s\n获得主动基因: %d"
		% [
			game_state.expedition_battle_wins,
			_expedition_buffs_text(game_state.expedition_buffs),
			game_state.expedition_active_genes.size()
		]
	)
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
			_resolve_question_event()
			_advance_non_battle_layer()
		"shop":
			_resolve_shop_event()
			_advance_non_battle_layer()

func _advance_non_battle_layer() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	game_state.expedition_layer += 1
	if game_state.expedition_layer > GameConstants.EXPEDITION_TOTAL_LAYERS:
		_finish_expedition(false)
		return
	_generate_nodes_for_current_layer()
	_refresh_view()

func _resolve_question_event() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var event_key := _weighted_pick_question_event()
	match event_key:
		"coin_bonus":
			var amount := randi_range(15, 35)
			game_state.add_coins(amount)
			_status_label.text = "问号事件：获得 %d 金币。" % amount
		"mystery_buff":
			var buff := "mystery_buff_%d" % randi_range(1, 3)
			game_state.expedition_buffs.append(buff)
			_status_label.text = "问号事件：获得一个远征增益。"
		"stray_kitten":
			var cat := _create_random_stray_cat()
			if game_state.enqueue_stray_cat(cat):
				_status_label.text = "问号事件：发现流浪幼崽，已加入等待队列。"
			else:
				_status_label.text = "问号事件：流浪猫队列已满。"
		"trouble":
			game_state.expedition_buffs.append("hp_cap_minus_5")
			_status_label.text = "问号事件：本次远征生命上限-5%。"
		_:
			_status_label.text = "问号事件：遭遇剧情事件。"

func _weighted_pick_question_event() -> String:
	var roll := randf()
	var cumulative := 0.0
	for key: String in ["coin_bonus", "mystery_buff", "stray_kitten", "trouble", "story"]:
		cumulative += float(GameConstants.QUESTION_EVENT_PROBABILITIES.get(key, 0.0))
		if roll <= cumulative:
			return key
	return "story"

func _resolve_shop_event() -> void:
	_status_label.text = "商店节点：换卡功能预留（下一轮细化）。"

func _finish_expedition(success: bool) -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var reward_mult := GameConstants.EXPEDITION_BATTLE_REWARD_SUCCESS_MULT if success else GameConstants.EXPEDITION_BATTLE_REWARD_FAIL_MULT
	var reward: int = int(reward_mult * game_state.expedition_battle_wins)
	game_state.add_coins(reward)

	var cat := _find_expedition_cat()
	if cat != null:
		_write_active_genes(cat, game_state.expedition_active_genes)
		cat.has_expeditioned = true
		cat.status = GameConstants.LIFECYCLE_STATUS_IDLE

	game_state.expedition_active = false
	game_state.expedition_cat_id = ""
	game_state.expedition_layer = 0
	game_state.expedition_battle_wins = 0
	game_state.expedition_buffs.clear()
	game_state.expedition_active_genes.clear()

	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.expedition_ended.emit(success, reward)

	_status_label.text = "远征结束，获得金币：%d。" % reward
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.go_to_camp()

func _write_active_genes(cat: CatData, genes: Array[String]) -> void:
	for gene_id in genes:
		if gene_id.is_empty():
			continue
		if cat.gene_slot_1 == gene_id or cat.gene_slot_2 == gene_id or cat.gene_slot_3 == gene_id:
			continue
		if cat.gene_slot_1.is_empty():
			cat.gene_slot_1 = gene_id
			continue
		if cat.gene_slot_2.is_empty():
			cat.gene_slot_2 = gene_id
			continue
		if cat.gene_slot_3.is_empty():
			cat.gene_slot_3 = gene_id
			continue
		break

func _selected_cat() -> CatData:
	var game_state := _get_game_state()
	if game_state == null:
		return null
	var filtered: Array[CatData] = []
	for cat: CatData in game_state.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		filtered.append(cat)
	if filtered.is_empty():
		return null
	var index := clampi(_cat_option.selected, 0, filtered.size() - 1)
	return filtered[index]

func _find_expedition_cat() -> CatData:
	var game_state := _get_game_state()
	if game_state == null:
		return null
	for cat: CatData in game_state.cats:
		if cat.id == game_state.expedition_cat_id:
			return cat
	return null

func _create_random_stray_cat() -> CatData:
	var cat := CatData.new()
	cat.id = "event_stray_%d" % int(Time.get_unix_time_from_system())
	cat.cat_name = "奇遇猫-%03d" % int(randi() % 1000)
	var breeds: Array = GameConstants.BREED_MODIFIERS.keys()
	var professions: Array = GameConstants.PROFESSION_BASE.keys()
	cat.breed = str(breeds[randi() % breeds.size()])
	cat.profession = str(professions[randi() % professions.size()])
	cat.calculate_stats()
	return cat

func _node_label(node_type: String) -> String:
	match node_type:
		"battle_normal":
			return "⚔️ 普通战（90秒生存）"
		"battle_elite":
			return "💀 精英战（120-180秒）"
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
		match buff_id:
			"hp_cap_minus_5":
				labels.append("生命上限-5%")
			_:
				if buff_id.begins_with("mystery_buff_"):
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
