extends Node

# ─────────────────────────────────────────────
# TimeManager  —  全局时间控制器
# ─────────────────────────────────────────────
# 1天 = 480 现实秒（8分钟）
# 白天 = 75%（360s）  夜晚 = 25%（120s）
# 远征中 = 0.3x 速度，最多流逝 2 天后冻结
# 暂停 = 时间停止 + 自动存档
# ─────────────────────────────────────────────

const DAY_DURATION_SEC := 480.0      # 1游戏天 = 8 现实分钟
const NIGHT_FRACTION   := 0.25       # 夜晚占比（后25%为夜晚）
const DAY_FRACTION     := 0.75       # 白天占比

const EXPEDITION_TIME_RATIO := 0.3   # 远征中时间流速
const EXPEDITION_DAY_CAP    := 2     # 远征期间最多流逝 2 天

const SAVE_PATH := "user://save.json"

signal day_started          # 每天白天开始
signal night_started        # 每天夜晚开始
signal day_boundary_crossed # 每过一天（用于资源结算）

# 当前游戏时间在今天的进度 [0.0, 1.0)
var time_of_day: float = 0.0
# 累计总天数
var total_days: int = 0
# 是否白天
var is_daytime: bool = true
# 是否暂停
var time_paused: bool = false
# 远征中累计流逝天数
var expedition_days_elapsed: float = 0.0
# 是否处于远征中（由 BattleScene/ExpeditionScene 设置）
var in_expedition: bool = false

func _ready() -> void:
	_try_load_save()

func _process(delta: float) -> void:
	if time_paused:
		return

	# 计算本帧时间增量
	var effective_delta := delta
	if in_expedition:
		effective_delta = delta * EXPEDITION_TIME_RATIO
		expedition_days_elapsed += effective_delta / DAY_DURATION_SEC
		if expedition_days_elapsed >= EXPEDITION_DAY_CAP:
			# 已达上限，冻结时间直到回营
			return

	# 推进当天时间
	var prev_time := time_of_day
	time_of_day += effective_delta / DAY_DURATION_SEC

	# 检查日夜边界
	_check_day_night_boundary(prev_time, time_of_day)

	# 检查天数翻转
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		total_days += 1
		day_boundary_crossed.emit()
		_trigger_day_production()

func _check_day_night_boundary(prev: float, curr: float) -> void:
	# 夜晚开始（穿越 0.75 边界）
	if prev < DAY_FRACTION and curr >= DAY_FRACTION:
		if is_daytime:
			is_daytime = false
			night_started.emit()
	# 白天开始（穿越 0.0 边界，即天数翻转后）
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
	else:
		return "⭐ 深夜"

func _trigger_day_production() -> void:
	# 触发 DayManager 资源结算
	var game_state := _get_game_state()
	if game_state == null:
		return
	var dm := preload("res://scenes/camp/DayManager.gd").new()
	var event_bus := get_node_or_null("/root/EventBus")
	dm.advance_day(game_state, event_bus)

## ─── 存读档 ───────────────────────────────

func _save_game() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var data := {
		"save_version": 1,
		"time_of_day": time_of_day,
		"total_days": total_days,
		"coins": game_state.coins,
		"cat_food": game_state.cat_food,
		"cat_food_cap": game_state.cat_food_cap,
		"camp_day": game_state.camp_day,
		"cat_house_slots": game_state.cat_house_slots,
		"buildings_built": game_state.buildings_built,
		"cats": _serialize_cats(game_state),
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
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if not (result is Dictionary):
		return
	var data: Dictionary = result
	# save_version 兼容处理（未来字段迁移用）
	var _sv := int(data.get("save_version", 0))
	time_of_day = float(data.get("time_of_day", 0.0))
	total_days = int(data.get("total_days", 0))
	is_daytime = time_of_day < DAY_FRACTION
	var game_state := _get_game_state()
	if game_state == null:
		return
	game_state.coins = int(data.get("coins", game_state.coins))
	game_state.cat_food = int(data.get("cat_food", game_state.cat_food))
	game_state.cat_food_cap = int(data.get("cat_food_cap", game_state.cat_food_cap))
	game_state.camp_day = int(data.get("camp_day", game_state.camp_day))
	game_state.cat_house_slots = int(data.get("cat_house_slots", game_state.cat_house_slots))
	if data.has("buildings_built"):
		game_state.buildings_built = data["buildings_built"]
	if data.has("cats"):
		_deserialize_cats(game_state, data["cats"])
	game_state.expedition_active = bool(data.get("expedition_active", false))
	game_state.expedition_cat_id = str(data.get("expedition_cat_id", ""))
	game_state.expedition_layer = int(data.get("expedition_layer", 0))
	game_state.expedition_battle_wins = int(data.get("expedition_battle_wins", 0))
	if data.has("expedition_buffs"):
		game_state.expedition_buffs = data["expedition_buffs"]
	if data.has("expedition_active_genes"):
		game_state.expedition_active_genes = data["expedition_active_genes"]
	if data.has("expedition_shop_cards"):
		game_state.expedition_shop_cards = data["expedition_shop_cards"]

func _serialize_cats(game_state: Node) -> Array:
	var arr := []
	for cat in game_state.cats:
		arr.append({
			"id": cat.id, "cat_name": cat.cat_name,
			"breed": cat.breed, "profession": cat.profession,
			"status": cat.status, "health": cat.health,
			"age_days": cat.age_days, "has_expeditioned": cat.has_expeditioned,
			"breed_count": cat.breed_count, "assigned_building": cat.assigned_building,
			"level": cat.level, "xp": cat.xp,
			"gene_head": cat.gene_head, "gene_ear": cat.gene_ear,
			"gene_eye_color": cat.gene_eye_color, "gene_eye_shape": cat.gene_eye_shape,
			"gene_fur_main": cat.gene_fur_main, "gene_fur_accent": cat.gene_fur_accent,
			"gene_pattern": cat.gene_pattern, "gene_tail": cat.gene_tail,
			"gene_slot_1": cat.gene_slot_1, "gene_slot_2": cat.gene_slot_2,
			"gene_slot_3": cat.gene_slot_3,
		})
	return arr

func _deserialize_cats(game_state: Node, cats_data: Array) -> void:
	game_state.cats.clear()
	for d: Dictionary in cats_data:
		var cat := CatData.new()
		cat.id = str(d.get("id", ""))
		cat.cat_name = str(d.get("cat_name", ""))
		cat.breed = str(d.get("breed", "tabby"))
		cat.profession = str(d.get("profession", "sniper"))
		cat.status = str(d.get("status", "idle"))
		cat.health = str(d.get("health", "healthy"))
		cat.age_days = int(d.get("age_days", 0))
		cat.has_expeditioned = bool(d.get("has_expeditioned", false))
		cat.breed_count = int(d.get("breed_count", 0))
		cat.assigned_building = str(d.get("assigned_building", ""))
		cat.level = int(d.get("level", 1))
		cat.xp = int(d.get("xp", 0))
		cat.gene_head = str(d.get("gene_head", "round"))
		cat.gene_ear = str(d.get("gene_ear", "upright"))
		cat.gene_eye_color = str(d.get("gene_eye_color", "blue"))
		cat.gene_eye_shape = str(d.get("gene_eye_shape", "round"))
		cat.gene_fur_main = str(d.get("gene_fur_main", "orange"))
		cat.gene_fur_accent = str(d.get("gene_fur_accent", "none"))
		cat.gene_pattern = str(d.get("gene_pattern", "none"))
		cat.gene_tail = str(d.get("gene_tail", "long"))
		cat.gene_slot_1 = str(d.get("gene_slot_1", ""))
		cat.gene_slot_2 = str(d.get("gene_slot_2", ""))
		cat.gene_slot_3 = str(d.get("gene_slot_3", ""))
		cat.calculate_stats()
		game_state.cats.append(cat)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")
