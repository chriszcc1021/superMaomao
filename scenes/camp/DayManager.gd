class_name DayManager
extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CatFactory := preload("res://data/cat_factory.gd")

func advance_day(game_state: Node, event_bus: Node) -> void:
	if game_state == null:
		return
	game_state.advance_camp_day()
	_consume_cat_food(game_state)
	_age_all_cats(game_state)
	_check_lifecycle(game_state)
	_produce_resources(game_state)
	_roll_stray_cat(game_state, event_bus)

func _consume_cat_food(game_state: Node) -> void:
	var total_cost: int = 0
	for cat: CatData in game_state.get_living_cats():
		if cat.age_days < GameConstants.KITTEN_DAYS:
			total_cost += GameConstants.FOOD_CONSUMPTION_KITTEN
		elif cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
			total_cost += GameConstants.FOOD_CONSUMPTION_ELDER
		else:
			total_cost += GameConstants.FOOD_CONSUMPTION_ADULT
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
	var workers: int = _count_available_workers(game_state)
	if game_state.has_building("food_farm"):
		var food_workers: int = min(workers, 3)
		var food_gain: int = int(GameConstants.FOOD_FARM_OUTPUT_BY_WORKERS.get(food_workers, 3))
		game_state.add_cat_food(food_gain)
	else:
		# 没有猫粮田时提供基础产出，避免前期断粮
		game_state.add_cat_food(3)
	if game_state.has_building("gold_mine"):
		var gold_workers: int = min(max(workers - 3, 0), 2)
		var gold_gain: int = int(GameConstants.GOLD_MINE_OUTPUT_BY_WORKERS.get(gold_workers, 2))
		game_state.add_coins(gold_gain)

func _count_available_workers(game_state: Node) -> int:
	var count := 0
	for cat: CatData in game_state.get_living_cats():
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		count += 1
	return count

func _roll_stray_cat(game_state: Node, event_bus: Node) -> void:
	if game_state.stray_cat_queue.size() >= GameConstants.MAX_STRAY_QUEUE_SIZE:
		return
	var chance := GameConstants.STRAY_CAT_DAILY_CHANCE
	if game_state.has_building("heart_cat_house"):
		chance = min(1.0, chance + GameConstants.HEART_CAT_HOUSE_STRAY_CHANCE_BONUS)
	if randf() > chance:
		return
	var stray_cat := CatFactory.create_random_stray_cat("stray", "流浪猫")
	if not game_state.enqueue_stray_cat(stray_cat):
		return
	if event_bus != null:
		event_bus.stray_cat_arrived.emit(stray_cat)
