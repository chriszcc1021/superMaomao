extends RefCounted

const GameConstants := preload("res://data/constants.gd")

func run(game_state: Node, event_bus: Node, day_manager) -> String:
	if game_state == null:
		return ""

	var snap_coins: int = game_state.coins
	var snap_food: int = game_state.cat_food
	var snap_queue: int = game_state.stray_cat_queue.size()
	var snap_cat_ids: Dictionary = {}
	var snap_health: Dictionary = {}
	var snap_status: Dictionary = {}
	for cat in game_state.cats:
		if cat == null:
			continue
		snap_cat_ids[cat.id] = true
		snap_health[cat.id] = cat.health
		snap_status[cat.id] = cat.status

	day_manager.advance_day(game_state, event_bus)

	var events: Array[String] = []
	var food_delta: int = game_state.cat_food - snap_food
	var coins_delta: int = game_state.coins - snap_coins

	if food_delta > 0:
		events.append("🌾 猫粮 +%d → %d/%d" % [food_delta, game_state.cat_food, game_state.cat_food_cap])
	elif game_state.cat_food == 0 and snap_food > 0:
		events.append("⚠️ 猫粮耗尽！猫咪开始生病")
	else:
		events.append("🍽️ 猫粮 %d → %d/%d" % [snap_food, game_state.cat_food, game_state.cat_food_cap])

	if coins_delta > 0:
		events.append("💰 金币 +%d → %d" % [coins_delta, game_state.coins])

	for cat in game_state.cats:
		if cat == null:
			continue
		if not snap_cat_ids.has(cat.id):
			events.append("🐣 %s 出生了！" % cat.cat_name)
			continue
		var old_h: String = str(snap_health.get(cat.id, GameConstants.HEALTH_STATE_HEALTHY))
		var old_s: String = str(snap_status.get(cat.id, GameConstants.LIFECYCLE_STATUS_IDLE))
		if old_h == GameConstants.HEALTH_STATE_HEALTHY and cat.health == GameConstants.HEALTH_STATE_SICK:
			events.append("🤒 %s 生病了！" % cat.cat_name)
		elif old_h == GameConstants.HEALTH_STATE_SICK and cat.health == GameConstants.HEALTH_STATE_CRITICAL:
			events.append("🆘 %s 病危！需要送医" % cat.cat_name)
		if old_s != GameConstants.LIFECYCLE_STATUS_ELDER and cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
			events.append("👴 %s 步入老年期" % cat.cat_name)
		if old_s != GameConstants.LIFECYCLE_STATUS_DEAD and cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			events.append("💀 %s 离世了" % cat.cat_name)

	if game_state.stray_cat_queue.size() > snap_queue:
		events.append("🐱 有流浪猫到访！")

	var day: int = game_state.camp_day
	var header := "─── 第%d天 结算 ───" % day
	var body := "\n".join(events) if not events.is_empty() else "一切平静。"
	return "%s\n%s" % [header, body]
