class_name ExpeditionSystem
extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CatFactory := preload("res://data/cat_factory.gd")

const NODE_PICK_ORDER := ["battle_normal", "battle_elite", "event_question", "shop"]
const QUESTION_EVENT_ORDER := ["coin_bonus", "mystery_buff", "stray_kitten", "trouble", "story"]

func can_start_expedition(cat: CatData) -> String:
	if cat == null:
		return "没有可出征的猫咪。"
	if cat.has_expeditioned:
		return "该猫已完成过一次远征。"
	if cat.age_days < GameConstants.KITTEN_DAYS:
		return "幼猫不能出征。"
	if cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
		return "老年猫不能出征。"
	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		return "仅健康状态可出征。"
	return ""

func start_expedition(game_state: Node, cat: CatData) -> bool:
	if game_state == null:
		return false
	return game_state.start_expedition(cat)

func process_returned_battle(scene_manager: Node, game_state: Node) -> Dictionary:
	var output := {"handled": false, "finished": false, "success": false, "status": ""}
	if scene_manager == null or game_state == null or not game_state.expedition_active:
		return output
	var result: Dictionary = scene_manager.last_battle_result
	if result.is_empty():
		return output
	scene_manager.last_battle_result = {}
	game_state.record_expedition_battle_result(result)
	output.handled = true
	var was_boss_battle := str(result.get("battle_node_type", "")) == "battle_boss"
	if was_boss_battle:
		output.finished = true
		output.success = bool(result.get("victory", false))
		return output
	var next_layer: int = game_state.advance_expedition_layer()
	if next_layer > GameConstants.EXPEDITION_TOTAL_LAYERS:
		output.finished = true
		output.success = false
		return output
	output.status = "战斗结束，进入下一层。"
	return output

func generate_nodes_for_current_layer(game_state: Node) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if game_state == null or not game_state.expedition_active:
		return nodes
	var layer: int = int(game_state.expedition_layer)
	if layer >= GameConstants.EXPEDITION_BOSS_LAYER:
		nodes.append({"type": "battle_boss"})
		return nodes
	# 固定生成2个节点，玩家二选一
	var probs: Dictionary = GameConstants.EXPEDITION_NODE_PROBABILITIES.get(layer, {})
	while nodes.size() < 2:
		var picked: String = _weighted_pick(probs, NODE_PICK_ORDER, "battle_normal")
		# 避免两个节点完全相同（至少尝试差异化，最多3次）
		if nodes.size() == 1 and str(nodes[0].get("type", "")) == picked:
			var attempts := 0
			while attempts < 3 and str(nodes[0].get("type", "")) == picked:
				picked = _weighted_pick(probs, NODE_PICK_ORDER, "battle_normal")
				attempts += 1
		nodes.append({"type": picked})
	return nodes

func resolve_question_event(game_state: Node) -> String:
	if game_state == null:
		return ""
	var event_key := _weighted_pick(GameConstants.QUESTION_EVENT_PROBABILITIES, QUESTION_EVENT_ORDER, "story")
	match event_key:
		"coin_bonus":
			var amount := randi_range(GameConstants.EXPEDITION_QUESTION_COIN_MIN, GameConstants.EXPEDITION_QUESTION_COIN_MAX)
			game_state.add_coins(amount)
			return "问号事件：获得 %d 金币。" % amount
		"mystery_buff":
			var buff := "mystery_buff_%d" % randi_range(1, GameConstants.EXPEDITION_MYSTERY_BUFF_VARIANTS)
			game_state.add_expedition_buff(buff)
			return "问号事件：获得一个远征增益。"
		"stray_kitten":
			var cat := CatFactory.create_random_stray_cat("event_stray", "奇遇猫")
			if game_state.enqueue_stray_cat(cat):
				return "问号事件：发现流浪幼崽，已加入等待队列。"
			return "问号事件：流浪猫队列已满。"
		"trouble":
			game_state.add_expedition_buff("hp_cap_minus_5")
			return "问号事件：本次远征生命上限-5%。"
		_:
			return "问号事件：遭遇剧情事件。"

func resolve_shop_event() -> String:
	return "商店节点：换卡功能预留（下一轮细化）。"

func advance_non_battle_layer(game_state: Node) -> bool:
	if game_state == null:
		return false
	var next_layer: int = game_state.advance_expedition_layer()
	return next_layer > GameConstants.EXPEDITION_TOTAL_LAYERS

func finish_expedition(game_state: Node, event_bus: Node, success: bool) -> int:
	if game_state == null:
		return 0
	var reward_mult := GameConstants.EXPEDITION_BATTLE_REWARD_SUCCESS_MULT if success else GameConstants.EXPEDITION_BATTLE_REWARD_FAIL_MULT
	var reward: int = int(reward_mult * game_state.expedition_battle_wins)
	game_state.add_coins(reward)
	var cat := _find_expedition_cat(game_state)
	if cat != null:
		_write_active_genes(cat, game_state.expedition_active_genes)
		cat.has_expeditioned = true
		cat.status = GameConstants.LIFECYCLE_STATUS_RETIRED  # 远征后退休，不可再出征
	game_state.clear_expedition_state()
	if event_bus != null:
		event_bus.expedition_ended.emit(success, reward)
	return reward

func _find_expedition_cat(game_state: Node) -> CatData:
	for cat: CatData in game_state.cats:
		if cat.id == game_state.expedition_cat_id:
			return cat
	return null

func _write_active_genes(cat: CatData, genes: Array[String]) -> void:
	for gene_id: String in genes:
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

func _weighted_pick(weights: Dictionary, ordered_keys: Array, fallback: String) -> String:
	var roll := randf()
	var cumulative := 0.0
	for key in ordered_keys:
		var key_str := str(key)
		cumulative += float(weights.get(key_str, 0.0))
		if roll <= cumulative:
			return key_str
	return fallback
