extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

const ACTION_BUILD := "build"
const ACTION_UPGRADE := "upgrade"
const ACTION_OPEN_NURSERY := "open_nursery"
const ACTION_SEND_SICK_TO_HOSPITAL := "send_sick_to_hospital"
const ACTION_BURY_DEAD_CATS := "bury_dead_cats"

func preview(building_id: String, game_state: Node) -> Dictionary:
	var cost := _effective_building_cost(int(GameConstants.BUILDING_COSTS.get(building_id, 0)), game_state)
	var lines: PackedStringArray = []
	match building_id:
		"food_farm":
			lines.append("🌱 猫粮田【未解锁】")
			lines.append("效果：每天根据分配猫数量产出猫粮")
			lines.append("解锁费用：%d金" % cost)
		"gold_mine":
			lines.append("⛏️ 金矿【未解锁】")
			lines.append("效果：每天根据分配猫数量产出金币")
			lines.append("解锁费用：%d金" % cost)
		"nursery":
			lines.append("🍼 产房【未解锁】")
			lines.append("效果：解锁繁育功能，当前成功率 %d%%" % int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100))
			lines.append("解锁费用：%d金" % cost)
		"hospital":
			lines.append("🏥 医院【未解锁】")
			lines.append("效果：每天治愈在此工作的病猫")
			lines.append("解锁费用：%d金" % cost)
		"heart_cat_house":
			lines.append("❤️ 爱心猫窝【未解锁】")
			lines.append("效果：流浪猫来访概率 +20%")
			lines.append("解锁费用：%d金" % cost)
		"cemetery":
			lines.append("🪦 墓地【未解锁】")
			lines.append("效果：记录死亡猫咪")
			lines.append("解锁费用：%d金" % cost)
		"fortune_cat":
			lines.append("🪙 招财猫神龛【未解锁】")
			lines.append("效果：分配猫每天产出金币")
			lines.append("解锁费用：%d金" % cost)
		_:
			lines.append("%s【未解锁】" % display_name(building_id))
			lines.append("解锁费用：%d金" % cost)
	if cost > 0:
		lines.append("")
		lines.append("💡 目前金币：%d" % game_state.coins)

	var actions: Array[Dictionary] = []
	actions.append({
		"label": "🔨 建造 %s（-%d金）" % [display_name(building_id), cost],
		"action": ACTION_BUILD,
		"building_id": building_id,
		"enabled": game_state.coins >= cost,
	})
	return {"text": "\n".join(lines), "actions": actions}

func sidebar(building_id: String, game_state: Node) -> Dictionary:
	var lines: PackedStringArray = []
	match building_id:
		"cat_house":
			_add_cat_house_lines(lines, game_state)
		"granary":
			_add_granary_lines(lines, game_state)
		"food_farm":
			_add_food_farm_lines(lines, game_state)
		"gold_mine":
			_add_gold_mine_lines(lines, game_state)
		"fortune_cat":
			_add_fortune_cat_lines(lines, game_state)
		"nursery":
			_add_nursery_lines(lines, game_state)
		"hospital":
			_add_hospital_lines(lines, game_state)
		"heart_cat_house":
			lines.append("❤️ 爱心猫窝")
			lines.append("流浪猫来访概率提升 +20%")
		"cemetery":
			_add_cemetery_lines(lines, game_state)
	if building_id in ["fortune_cat", "food_farm", "gold_mine", "hospital", "nursery", "heart_cat_house"]:
		_add_assignment_lines(lines, building_id, game_state)
	return {"text": "\n".join(lines), "actions": _sidebar_actions(building_id, game_state)}

func display_name(building_id: String) -> String:
	match building_id:
		"cat_house":
			return "猫窝"
		"granary":
			return "粮仓"
		"food_farm":
			return "猫粮田"
		"gold_mine":
			return "金矿"
		"nursery":
			return "产房"
		"hospital":
			return "医院"
		"heart_cat_house":
			return "爱心猫窝"
		"cemetery":
			return "墓地"
		"fortune_cat":
			return "招财猫"
	return building_id

func _add_cat_house_lines(lines: PackedStringArray, game_state: Node) -> void:
	var slots: int = game_state.cat_house_slots
	lines.append("🏠 猫窝 (上限 %d)" % slots)
	lines.append("已住：%d / %d" % [game_state.get_living_cats().size(), slots])
	if slots < GameConstants.MAX_CAT_HOUSE_SLOTS:
		var expand_cost: int = _effective_building_cost(int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60)), game_state)
		lines.append("扩建费用：%d金（当前 %d金）" % [expand_cost, game_state.coins])

func _add_granary_lines(lines: PackedStringArray, game_state: Node) -> void:
	var level: int = game_state.get_building_level("granary")
	lines.append("🌾 粮仓 Lv%d" % level)
	lines.append("猫粮：%d / %d" % [game_state.cat_food, game_state.cat_food_cap])
	if level < GameConstants.GRANARY_MAX_LEVEL:
		var next_cap: int = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(level + 1, game_state.cat_food_cap))
		var upgrade_cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[level - 1])
		lines.append("升级后粮仓上限：%d" % next_cap)
		lines.append("升级费用：%d金（当前 %d金）" % [upgrade_cost, game_state.coins])
	else:
		lines.append("✅ 已达最高等级")

func _add_food_farm_lines(lines: PackedStringArray, game_state: Node) -> void:
	var worker_count: int = _count_assigned_cats("food_farm", game_state)
	var output: int = int(GameConstants.FOOD_FARM_OUTPUT_BY_WORKERS.get(worker_count, 0))
	lines.append("🌱 猫粮田")
	lines.append("工作猫：%s" % _assigned_cats_text("food_farm", game_state))
	lines.append("今日预计产粮：%d" % output)

func _add_gold_mine_lines(lines: PackedStringArray, game_state: Node) -> void:
	var worker_count: int = _count_assigned_cats("gold_mine", game_state)
	var output: int = int(GameConstants.GOLD_MINE_OUTPUT_BY_WORKERS.get(worker_count, 0))
	lines.append("⛏️ 金矿")
	lines.append("工作猫：%s" % _assigned_cats_text("gold_mine", game_state))
	lines.append("今日预计产金：%d" % output)

func _add_fortune_cat_lines(lines: PackedStringArray, game_state: Node) -> void:
	var level: int = int(game_state.get_building_level("fortune_cat"))
	var per_worker: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(level, 15))
	var max_workers: int = int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level, 1))
	lines.append("🪙 招财猫神龛 Lv%d" % level)
	lines.append("每日产金：%d金/只" % per_worker)
	lines.append("工作猫：%d / %d（%s）" % [_count_assigned_cats("fortune_cat", game_state), max_workers, _assigned_cats_text("fortune_cat", game_state)])
	if level < GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
		var cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[level - 1])
		var next_max: int = int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level + 1, max_workers))
		var next_output: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(level + 1, per_worker))
		lines.append("升Lv%d：工作上限→%d，产金→%d金/只" % [level + 1, next_max, next_output])
		lines.append("升级费用：%d金（当前 %d金）" % [cost, game_state.coins])
	else:
		lines.append("✅ 已达最高等级")

func _add_nursery_lines(lines: PackedStringArray, game_state: Node) -> void:
	var slots: int = game_state.max_breeding_slots
	lines.append("🍼 产房")
	lines.append("繁育成功率：%d%%" % int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100.0))
	lines.append("当前坑位：%d / %d" % [slots, GameConstants.BREEDING_SLOT_MAX])
	lines.append("繁育周期：%d 天" % GameConstants.BREEDING_SLOT_CD_DAYS)
	if slots < GameConstants.BREEDING_SLOT_MAX:
		var upgrade_cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[slots - 1])
		lines.append("升级费用：%d金（当前 %d金）" % [upgrade_cost, game_state.coins])

func _add_hospital_lines(lines: PackedStringArray, game_state: Node) -> void:
	lines.append("🏥 医院")
	lines.append("每天治愈在此工作的病猫")
	lines.append("病态/濒危猫咪无法工作，需送医治疗。")
	var sick_cats := _sick_cats(game_state)
	if sick_cats.is_empty():
		lines.append("✅ 当前无病猫")
	else:
		lines.append("病猫列表：")
		for cat: CatData in sick_cats:
			var health_text := "病态" if cat.health == GameConstants.HEALTH_STATE_SICK else "濒危"
			lines.append("  %s（%s）" % [cat.cat_name, health_text])

func _add_cemetery_lines(lines: PackedStringArray, game_state: Node) -> void:
	lines.append("🪦 墓地")
	var dead_cats := _dead_cats(game_state)
	if dead_cats.is_empty():
		lines.append("暂无需要入葬的猫咪。")
	else:
		lines.append("以下猫咪已离世，等待入葬（占用猫窝坑位）：")
		for cat: CatData in dead_cats:
			lines.append("  💀 %s（%s）" % [cat.cat_name, GameConstants.breed_zh(cat.breed)])

func _add_assignment_lines(lines: PackedStringArray, building_id: String, game_state: Node) -> void:
	lines.append("")
	lines.append("── 分配猫咪（拖拽猫咪到建筑） ──")
	for cat: CatData in game_state.get_living_cats():
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		var mark: String = "✅" if str(cat.assigned_building) == building_id else "  "
		lines.append("%s %s（%s）" % [mark, cat.cat_name, GameConstants.profession_zh(cat.profession)])

func _sidebar_actions(building_id: String, game_state: Node) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	match building_id:
		"cat_house":
			var slots: int = game_state.cat_house_slots
			if slots < GameConstants.MAX_CAT_HOUSE_SLOTS:
				var cost: int = _effective_building_cost(int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60)), game_state)
				actions.append({
					"label": "🏠 扩建猫窝 -%d金（%d→%d格）" % [cost, slots, slots + 1],
					"action": ACTION_UPGRADE,
					"building_id": "cat_house",
					"enabled": game_state.coins >= cost,
				})
		"granary":
			var level: int = game_state.get_building_level("granary")
			if level < GameConstants.GRANARY_MAX_LEVEL:
				var cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[level - 1])
				var next_cap: int = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(level + 1, 0))
				actions.append({
					"label": "🌾 升级粮仓 Lv%d→%d -%d金（上限→%d）" % [level, level + 1, cost, next_cap],
					"action": ACTION_UPGRADE,
					"building_id": "granary",
					"enabled": game_state.coins >= cost,
				})
		"fortune_cat":
			var level: int = game_state.get_building_level("fortune_cat")
			if level < GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
				var cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[level - 1])
				actions.append({
					"label": "🪙 升级神龛 Lv%d→%d -%d金" % [level, level + 1, cost],
					"action": ACTION_UPGRADE,
					"building_id": "fortune_cat",
					"enabled": game_state.coins >= cost,
				})
		"nursery":
			actions.append({"label": "打开繁育界面", "action": ACTION_OPEN_NURSERY, "enabled": true})
			var slots: int = game_state.max_breeding_slots
			if slots < GameConstants.BREEDING_SLOT_MAX:
				var cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[slots - 1])
				actions.append({
					"label": "🍼 扩建产房坑位 %d→%d（-%d金）" % [slots, slots + 1, cost],
					"action": ACTION_UPGRADE,
					"building_id": "nursery",
					"enabled": game_state.coins >= cost,
				})
		"hospital":
			var sick_cats := _sick_cats(game_state)
			if not sick_cats.is_empty():
				actions.append({
					"label": "🏥 将所有病猫送入医院（%d只）" % sick_cats.size(),
					"action": ACTION_SEND_SICK_TO_HOSPITAL,
					"enabled": true,
				})
		"cemetery":
			var dead_cats := _dead_cats(game_state)
			if not dead_cats.is_empty():
				actions.append({
					"label": "🪦 入葬所有离世猫咪（%d只）" % dead_cats.size(),
					"action": ACTION_BURY_DEAD_CATS,
					"enabled": true,
				})
	return actions

func _assigned_cats_text(building_id: String, game_state: Node) -> String:
	var names: PackedStringArray = []
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			names.append(cat.cat_name)
	return ", ".join(names) if not names.is_empty() else "无"

func _count_assigned_cats(building_id: String, game_state: Node) -> int:
	var count := 0
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			count += 1
	return count

func _effective_building_cost(base_cost: int, game_state: Node) -> int:
	for cat: CatData in game_state.get_living_cats():
		if cat.has_gene("builder_discount"):
			return int(base_cost * 0.80)
	return base_cost

func _sick_cats(game_state: Node) -> Array[CatData]:
	var result: Array[CatData] = []
	for cat: CatData in game_state.get_living_cats():
		if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
			result.append(cat)
	return result

func _dead_cats(game_state: Node) -> Array[CatData]:
	var result: Array[CatData] = []
	for cat: CatData in game_state.cats:
		if cat != null and cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			result.append(cat)
	return result
