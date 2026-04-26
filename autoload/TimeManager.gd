extends Node

const CatData       := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")

const DAY_DURATION_SEC := 480.0
const NIGHT_FRACTION := 0.25
const DAY_FRACTION := 0.75

const EXPEDITION_TIME_RATIO := 0.3
const EXPEDITION_DAY_CAP := 2
const SAVE_PATH := "user://save.json"

signal day_started
signal night_started
signal day_boundary_crossed
signal resource_generated(building_id: String, resource_type: String, amount: int)

var time_of_day: float = 0.0
var total_days: int = 0
var is_daytime: bool = true
var time_paused: bool = false
var expedition_days_elapsed: float = 0.0
var in_expedition: bool = false
var resource_progress: Dictionary = {
	"food_farm": 0.0,
	"gold_mine": 0.0,
	"fortune_cat": 0.0,
}

# 时间速率：1× / 2× / 5× / 10×
var time_speed: float = 1.0
const SPEED_OPTIONS: Array[float] = [1.0, 2.0, 5.0, 10.0]

## 循环切换速率，返回新速率
func cycle_speed() -> float:
	var idx := SPEED_OPTIONS.find(time_speed)
	if idx < 0:
		idx = 0
	time_speed = SPEED_OPTIONS[(idx + 1) % SPEED_OPTIONS.size()]
	return time_speed

var _day_manager: RefCounted = null

func _ready() -> void:
	_day_manager = preload("res://scenes/camp/DayManager.gd").new()
	_try_load_save()

func _process(delta: float) -> void:
	if time_paused:
		return

	var effective_delta := delta
	if in_expedition:
		effective_delta = delta * EXPEDITION_TIME_RATIO
		expedition_days_elapsed += effective_delta / DAY_DURATION_SEC
		if expedition_days_elapsed >= EXPEDITION_DAY_CAP:
			return

	var prev_time := time_of_day
	var day_delta := effective_delta * time_speed / DAY_DURATION_SEC
	_tick_continuous_resources(day_delta)
	time_of_day += day_delta
	_check_day_night_boundary(prev_time, time_of_day)

	if time_of_day >= 1.0:
		time_of_day -= 1.0
		total_days += 1
		# 先执行日结算，再通知 UI（避免 UI 刷新到旧数据）
		_trigger_day_production()
		day_boundary_crossed.emit()

func _check_day_night_boundary(prev: float, curr: float) -> void:
	if prev < DAY_FRACTION and curr >= DAY_FRACTION:
		if is_daytime:
			is_daytime = false
			night_started.emit()
	if prev > DAY_FRACTION and curr < DAY_FRACTION:
		if not is_daytime:
			is_daytime = true
			day_started.emit()

func set_expedition_mode(active: bool) -> void:
	in_expedition = active
	if not active:
		expedition_days_elapsed = 0.0

func pause() -> void:
	if time_paused:
		return
	time_paused = true
	_save_game()

func resume() -> void:
	time_paused = false

func get_time_label() -> String:
	var fraction := time_of_day
	if fraction < 0.125:
		return "🌄 清晨"
	elif fraction < 0.375:
		return "☀️ 上午"
	elif fraction < 0.625:
		return "🌅 下午"
	elif fraction < DAY_FRACTION:
		return "🌆 傍晚"
	elif fraction < 0.875:
		return "🌙 夜晚"
	return "⭐ 深夜"

func _tick_continuous_resources(day_delta: float) -> void:
	if day_delta <= 0.0:
		return
	var game_state := _get_game_state()
	if game_state == null or _day_manager == null:
		return
	if not _day_manager.has_method("get_continuous_resource_rates"):
		return

	var rates: Dictionary = _day_manager.get_continuous_resource_rates(game_state)
	for building_id in ["food_farm", "gold_mine", "fortune_cat"]:
		var rate_per_day := float(rates.get(building_id, 0))
		if rate_per_day <= 0.0:
			continue
		if building_id == "food_farm" and game_state.cat_food >= game_state.cat_food_cap:
			resource_progress[building_id] = minf(float(resource_progress.get(building_id, 0.0)), 0.999)
			continue

		resource_progress[building_id] = float(resource_progress.get(building_id, 0.0)) + rate_per_day * day_delta
		var produced_units := int(floor(float(resource_progress.get(building_id, 0.0))))
		if produced_units <= 0:
			continue
		resource_progress[building_id] = float(resource_progress.get(building_id, 0.0)) - produced_units
		_apply_continuous_resource_gain(game_state, building_id, produced_units)

func _apply_continuous_resource_gain(game_state: Node, building_id: String, amount: int) -> void:
	if amount <= 0 or game_state == null:
		return
	match building_id:
		"food_farm":
			var before_food: int = game_state.cat_food
			game_state.add_cat_food(amount)
			var actual_food: int = game_state.cat_food - before_food
			if actual_food > 0:
				resource_generated.emit(building_id, "food", actual_food)
		"gold_mine", "fortune_cat":
			game_state.add_coins(amount)
			resource_generated.emit(building_id, "coins", amount)

func _trigger_day_production() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var event_bus := get_node_or_null("/root/EventBus")
	_day_manager.advance_day(game_state, event_bus)

func _save_game() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var data := {
		"save_version": 3,
		"time_of_day": time_of_day,
		"total_days": total_days,
		"resource_progress": resource_progress,
		"coins": game_state.coins,
		"cat_food": game_state.cat_food,
		"cat_food_cap": game_state.cat_food_cap,
		"camp_day": game_state.camp_day,
		"cat_house_slots": game_state.cat_house_slots,
		"max_breeding_slots": game_state.max_breeding_slots,
		"buildings_built": game_state.buildings_built,
		"breeding_slots": _serialize_breeding_slots(game_state.breeding_slots),
		"cats": _serialize_cats(game_state.cats),
		"starter_selection_pending": bool(game_state.starter_selection_pending),
		"starter_candidates": _serialize_cats(game_state.starter_candidates),
		"intro_stray_pending": bool(game_state.intro_stray_pending),
		"intro_stray_arrived": bool(game_state.intro_stray_arrived),
		"intro_stray_timer_sec": float(game_state.intro_stray_timer_sec),
		"intro_stray_target_sex": str(game_state.intro_stray_target_sex),
		"stray_cat_queue": _serialize_cats(game_state.stray_cat_queue),
		"expedition_active": game_state.expedition_active,
		"expedition_cat_id": game_state.expedition_cat_id,
		"expedition_layer": game_state.expedition_layer,
		"expedition_battle_wins": game_state.expedition_battle_wins,
		"expedition_buffs": game_state.expedition_buffs,
		"expedition_active_genes": game_state.expedition_active_genes,
		"expedition_shop_cards": game_state.expedition_shop_cards,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _try_load_save() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	if not FileAccess.file_exists(SAVE_PATH):
		game_state.ensure_intro_state()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		game_state.ensure_intro_state()
		return

	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if not (result is Dictionary):
		game_state.ensure_intro_state()
		return

	var data: Dictionary = result
	time_of_day = float(data.get("time_of_day", 0.0))
	total_days = int(data.get("total_days", 0))
	is_daytime = time_of_day < DAY_FRACTION
	if data.has("resource_progress") and data["resource_progress"] is Dictionary:
		for building_id in resource_progress.keys():
			resource_progress[building_id] = float(data["resource_progress"].get(building_id, resource_progress[building_id]))

	game_state.coins = int(data.get("coins", game_state.coins))
	game_state.cat_food = int(data.get("cat_food", game_state.cat_food))
	game_state.cat_food_cap = int(data.get("cat_food_cap", game_state.cat_food_cap))
	game_state.camp_day = int(data.get("camp_day", game_state.camp_day))
	game_state.cat_house_slots = int(data.get("cat_house_slots", game_state.cat_house_slots))
	game_state.max_breeding_slots = int(data.get("max_breeding_slots", game_state.max_breeding_slots))
	if data.has("buildings_built"):
		game_state.buildings_built = data["buildings_built"]
	if data.has("breeding_slots"):
		game_state.breeding_slots = _deserialize_breeding_slots(data["breeding_slots"])
	if game_state.has_method("sync_breeding_slots"):
		game_state.sync_breeding_slots()
	game_state.cats = _deserialize_cats(data.get("cats", []))
	game_state.starter_selection_pending = bool(data.get("starter_selection_pending", game_state.cats.is_empty()))
	game_state.starter_candidates = _deserialize_cats(data.get("starter_candidates", []))
	game_state.intro_stray_pending = bool(data.get("intro_stray_pending", false))
	game_state.intro_stray_arrived = bool(data.get("intro_stray_arrived", false))
	game_state.intro_stray_timer_sec = float(data.get("intro_stray_timer_sec", 0.0))
	game_state.intro_stray_target_sex = str(data.get("intro_stray_target_sex", ""))
	game_state.stray_cat_queue = _deserialize_cats(data.get("stray_cat_queue", []))
	if game_state.has_method("restore_expedition_state"):
		game_state.restore_expedition_state(data)
	game_state.ensure_intro_state()

func _serialize_cats(cats_data: Array) -> Array:
	var arr: Array = []
	for cat in cats_data:
		if cat == null:
			continue
		arr.append(_serialize_cat(cat))
	return arr

func _serialize_cat(cat: CatData) -> Dictionary:
	return {
		"id": cat.id,
		"cat_name": cat.cat_name,
		"sex": cat.sex,
		"breed": cat.breed,
		"profession": cat.profession,
		"status": cat.status,
		"health": cat.health,
		"age_days": cat.age_days,
		"has_expeditioned": cat.has_expeditioned,
		"breed_count": cat.breed_count,
		"assigned_building": cat.assigned_building,
		"level": cat.level,
		"xp": cat.xp,
		"current_hp": cat.current_hp,
		"gene_head": cat.gene_head,
		"gene_ear": cat.gene_ear,
		"gene_eye_color": cat.gene_eye_color,
		"gene_eye_shape": cat.gene_eye_shape,
		"gene_fur_main": cat.gene_fur_main,
		"gene_fur_accent": cat.gene_fur_accent,
		"gene_pattern": cat.gene_pattern,
		"gene_tail": cat.gene_tail,
		"gene_slot_1": cat.gene_slot_1,
		"gene_slot_2": cat.gene_slot_2,
		"gene_slot_3": cat.gene_slot_3,
	}

func _serialize_breeding_slots(slots: Array) -> Array:
	var result: Array = []
	for slot in slots:
		if not (slot is Dictionary):
			continue
		result.append({
			"active": bool(slot.get("active", false)),
			"father_id": str(slot.get("father_id", "")),
			"mother_id": str(slot.get("mother_id", "")),
			"child_breed": str(slot.get("child_breed", "")),
			"child_profession": str(slot.get("child_profession", "")),
			"days_remaining": int(slot.get("days_remaining", 0)),
		})
	return result

func _deserialize_cats(cats_data: Array) -> Array[CatData]:
	var result: Array[CatData] = []
	for entry in cats_data:
		if not (entry is Dictionary):
			continue
		result.append(_deserialize_cat(entry))
	return result

func _deserialize_breeding_slots(slots_data: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in slots_data:
		if not (entry is Dictionary):
			continue
		result.append({
			"active": bool(entry.get("active", false)),
			"father_id": str(entry.get("father_id", "")),
			"mother_id": str(entry.get("mother_id", "")),
			"child_breed": str(entry.get("child_breed", "")),
			"child_profession": str(entry.get("child_profession", "")),
			"days_remaining": int(entry.get("days_remaining", 0)),
		})
	return result

func _deserialize_cat(data: Dictionary) -> CatData:
	var cat := CatData.new()
	cat.id = str(data.get("id", ""))
	cat.cat_name = str(data.get("cat_name", ""))
	cat.sex = str(data.get("sex", GameConstants.SEX_FEMALE))
	cat.breed = str(data.get("breed", "tabby"))
	cat.profession = str(data.get("profession", "sniper"))
	cat.status = str(data.get("status", "idle"))
	cat.health = str(data.get("health", "healthy"))
	cat.age_days = int(data.get("age_days", 0))
	cat.has_expeditioned = bool(data.get("has_expeditioned", false))
	cat.breed_count = int(data.get("breed_count", 0))
	cat.assigned_building = str(data.get("assigned_building", ""))
	cat.level = int(data.get("level", 1))
	cat.xp = int(data.get("xp", 0))
	cat.current_hp = float(data.get("current_hp", -1.0))
	cat.gene_head = str(data.get("gene_head", "round"))
	cat.gene_ear = str(data.get("gene_ear", "upright"))
	cat.gene_eye_color = str(data.get("gene_eye_color", "blue"))
	cat.gene_eye_shape = str(data.get("gene_eye_shape", "round"))
	cat.gene_fur_main = str(data.get("gene_fur_main", "orange"))
	cat.gene_fur_accent = str(data.get("gene_fur_accent", "none"))
	cat.gene_pattern = str(data.get("gene_pattern", "none"))
	cat.gene_tail = str(data.get("gene_tail", "long"))
	cat.gene_slot_1 = str(data.get("gene_slot_1", ""))
	cat.gene_slot_2 = str(data.get("gene_slot_2", ""))
	cat.gene_slot_3 = str(data.get("gene_slot_3", ""))
	cat.calculate_stats()
	return cat

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")
