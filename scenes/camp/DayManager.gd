class_name DayManager
extends RefCounted

const CatData       := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")
const CatFactory    := preload("res://data/cat_factory.gd")


func advance_day(game_state: Node, event_bus: Node) -> void:
	if game_state == null:
		return
	game_state.advance_camp_day()
	_consume_cat_food(game_state)
	_age_all_cats(game_state)
	_check_lifecycle(game_state)
	_produce_resources(game_state)
	_roll_stray_cat(game_state, event_bus)
	_tick_breeding_slots(game_state, event_bus)

func _tick_breeding_slots(game_state: Node, event_bus: Node) -> void:
	var born: Array[CatData] = game_state.tick_breeding_slots()
	if born.is_empty() or event_bus == null:
		return
	for child: CatData in born:
		event_bus.breeding_success.emit(child)

func _consume_cat_food(game_state: Node) -> void:
	var total_cost: int = 0
	for cat: CatData in game_state.get_living_cats():
		var base_cost := 0
		if cat.age_days < GameConstants.KITTEN_DAYS:
			base_cost = GameConstants.FOOD_CONSUMPTION_KITTEN
		elif cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
			base_cost = GameConstants.FOOD_CONSUMPTION_ELDER
		else:
			base_cost = GameConstants.FOOD_CONSUMPTION_ADULT
		# big_belly：自身猫粮消耗-25%
		if cat.has_gene("big_belly"):
			base_cost = int(ceil(base_cost * 0.75))
		total_cost += base_cost
	if total_cost <= 0:
		return
	if game_state.consume_cat_food(total_cost):
		return
	game_state.set_cat_food(0)
	_apply_food_shortage(game_state)

func _apply_food_shortage(game_state: Node) -> void:
	for cat: CatData in game_state.get_living_cats():
		match cat.health:
			GameConstants.HEALTH_STATE_HEALTHY:
				cat.health = GameConstants.HEALTH_STATE_SICK
			GameConstants.HEALTH_STATE_SICK:
				cat.health = GameConstants.HEALTH_STATE_CRITICAL
			GameConstants.HEALTH_STATE_CRITICAL:
				game_state.mark_cat_dead(cat.id)

func _age_all_cats(game_state: Node) -> void:
	for cat: CatData in game_state.get_living_cats():
		cat.age_days += 1

func _check_lifecycle(game_state: Node) -> void:
	for cat: CatData in game_state.get_living_cats():
		if cat.age_days >= GameConstants.ADULT_MAX_DAYS or cat.breed_count >= GameConstants.MAX_BREED_COUNT:
			cat.status = GameConstants.LIFECYCLE_STATUS_ELDER
		if cat.status == GameConstants.LIFECYCLE_STATUS_ELDER and cat.age_days >= GameConstants.ADULT_MAX_DAYS + GameConstants.ELDER_DAYS:
			game_state.mark_cat_dead(cat.id)

func _produce_resources(game_state: Node) -> void:
	# community_planner：全局产出加成
	var community_bonus := _calc_community_planner_bonus(game_state)

	if game_state.has_building("food_farm"):
		# Bug fix: 使用实际分配到猫粮田的猫数，而非总可用猫数
		var food_workers: int = _count_workers_at_building(game_state, "food_farm")
		var food_gain: int = int(GameConstants.FOOD_FARM_OUTPUT_BY_WORKERS.get(food_workers, 3))
		# hard_worker 加成（猫粮田中有hard_worker猫）
		food_gain = _apply_worker_gene_bonus(game_state, "food_farm", food_gain)
		food_gain = int(food_gain * (1.0 + community_bonus))
		game_state.add_cat_food(food_gain)
	else:
		game_state.add_cat_food(3)

	if game_state.has_building("gold_mine"):
		# Bug fix: 使用实际分配到金矿的猫数，而非总可用猫数的剩余
		var gold_workers: int = _count_workers_at_building(game_state, "gold_mine")
		var gold_gain: int = int(GameConstants.GOLD_MINE_OUTPUT_BY_WORKERS.get(gold_workers, 2))
		# hard_worker + walnut_cracker 加成
		gold_gain = _apply_worker_gene_bonus(game_state, "gold_mine", gold_gain)
		gold_gain = int(gold_gain * (1.0 + community_bonus))
		game_state.add_coins(gold_gain)

	if game_state.has_building("fortune_cat"):
		var fortune_workers: int = _count_workers_at_building(game_state, "fortune_cat")
		if fortune_workers > 0:
			var level: int = int(game_state.get_building_level("fortune_cat"))
			var per_worker: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(level, 15))
			var fortune_gain := per_worker * fortune_workers
			fortune_gain = _apply_worker_gene_bonus(game_state, "fortune_cat", fortune_gain)
			fortune_gain = int(fortune_gain * (1.0 + community_bonus))
			game_state.add_coins(fortune_gain)

	# golden_paw：每天额外产金
	for cat: CatData in game_state.get_living_cats():
		if cat.has_gene("golden_paw"):
			game_state.add_coins(8)

	# 医院：mini_nurse 治疗效果
	_process_hospital_healing(game_state)

	# 建筑工作给猫加 XP
	_grant_building_xp(game_state)

func _apply_worker_gene_bonus(game_state: Node, building_id: String, base_amount: int) -> int:
	var mult := 1.0
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) != building_id:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.has_gene("hard_worker"):
			mult += 0.20
		if building_id == "gold_mine" and cat.has_gene("walnut_cracker"):
			mult += 0.30
	return int(base_amount * mult)

func _calc_community_planner_bonus(game_state: Node) -> float:
	var planner_present := false
	for cat: CatData in game_state.get_living_cats():
		if cat.has_gene("community_planner"):
			planner_present = true
			break
	if not planner_present:
		return 0.0
	# 统计所有在岗的猫（最多5只加成）
	var worker_count := 0
	for cat: CatData in game_state.get_living_cats():
		if not str(cat.assigned_building).is_empty() and cat.status != GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			worker_count += 1
	return min(worker_count, 5) * 0.02

func _process_hospital_healing(game_state: Node) -> void:
	if not game_state.has_building("hospital"):
		return
	var heal_rate := 1.0
	# mini_nurse 加成
	var hospital_workers_with_mini_nurse := 0
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) == "hospital" and cat.has_gene("mini_nurse"):
			hospital_workers_with_mini_nurse += 1
	if hospital_workers_with_mini_nurse > 0:
		heal_rate = 1.5
	# Bug fix: 只治疗分配到医院的病猫，而非所有病猫
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) != "hospital":
			continue
		if cat.health == GameConstants.HEALTH_STATE_SICK and heal_rate >= 1.5:
			cat.health = GameConstants.HEALTH_STATE_HEALTHY
		elif cat.health == GameConstants.HEALTH_STATE_CRITICAL:
			cat.health = GameConstants.HEALTH_STATE_SICK

func _grant_building_xp(game_state: Node) -> void:
	for cat: CatData in game_state.get_living_cats():
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		var building := str(cat.assigned_building)
		var xp_gain := 0
		if building.is_empty():
			xp_gain = GameConstants.CAT_WANDER_XP_PER_DAY
		elif GameConstants.BUILDING_WORK_XP_PER_DAY.has(building):
			var level := int(game_state.get_building_level(building)) if game_state.has_building(building) else 1
			var xp_table: Dictionary = GameConstants.BUILDING_WORK_XP_PER_DAY[building]
			xp_gain = int(xp_table.get(level, xp_table.get(1, 5)))
		if xp_gain > 0:
			_apply_cat_xp(cat, xp_gain)

func _apply_cat_xp(cat: CatData, amount: int) -> void:
	if cat.level >= GameConstants.CAT_LEVEL_CAP:
		return
	cat.xp += amount
	# 连续检查是否升级（建筑XP不触发技能选择，只升等级）
	while cat.level < GameConstants.CAT_LEVEL_CAP:
		var needed := GameConstants.CAT_XP_BASE + cat.level * GameConstants.CAT_XP_INCREMENT
		if cat.xp >= needed:
			cat.xp -= needed
			cat.level += 1
		else:
			break

func _count_workers_at_building(game_state: Node, building_id: String) -> int:
	var count := 0
	for cat: CatData in game_state.get_living_cats():
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		if str(cat.assigned_building) == building_id:
			count += 1
	return count

func _count_available_workers(game_state: Node) -> int:
	var count := 0
	for cat: CatData in game_state.get_living_cats():
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
			continue  # 病态/濒危猫不能工作
		count += 1
	return count

func _roll_stray_cat(game_state: Node, event_bus: Node) -> void:
	if game_state.stray_cat_queue.size() >= GameConstants.MAX_STRAY_QUEUE_SIZE:
		return
	var chance := GameConstants.STRAY_CAT_DAILY_CHANCE
	if game_state.has_building("heart_cat_house"):
		chance = min(1.0, chance + GameConstants.HEART_CAT_HOUSE_STRAY_CHANCE_BONUS)
	# lucky_cat：任一猫有此基因，流浪猫来访概率+15%
	for cat: CatData in game_state.get_living_cats():
		if cat.has_gene("lucky_cat"):
			chance = min(1.0, chance + 0.15)
			break
	if randf() > chance:
		return
	var stray_cat := CatFactory.create_random_stray_cat("stray", "流浪猫")
	if not game_state.enqueue_stray_cat(stray_cat):
		return
	if event_bus != null:
		event_bus.stray_cat_arrived.emit(stray_cat)

