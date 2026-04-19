extends Node

# BreedingSystem 已有 class_name，全局可用，无需 preload

const DEFAULT_BUILDINGS_BUILT := {
	"cat_house": true,
	"granary": true,
	"nursery": false,
	"hospital": false,
	"food_farm": false,
	"gold_mine": false,
	"heart_cat_house": false,
	"cemetery": false,
}

signal coins_changed(new_val: int)
signal cat_food_changed(new_val: int)
signal day_advanced(day: int)
signal cat_added(cat: CatData)
signal cat_died(cat: CatData)

var coins: int = GameConstants.STARTING_COINS
var cat_food: int = GameConstants.STARTING_CAT_FOOD
var cat_food_cap: int = GameConstants.STARTING_CAT_FOOD_CAP
var camp_day: int = GameConstants.STARTING_CAMP_DAY

var cats: Array[CatData] = []
var stray_cat_queue: Array[CatData] = []

var starter_selection_pending: bool = true
var starter_candidates: Array[CatData] = []
var intro_stray_pending: bool = false
var intro_stray_arrived: bool = false
var intro_stray_timer_sec: float = 0.0
var intro_stray_target_sex: String = ""

var expedition_active: bool = false
var expedition_cat_id: String = ""
var expedition_layer: int = 0
var expedition_battle_wins: int = 0
var expedition_buffs: Array = []
var expedition_active_genes: Array[String] = []
var expedition_shop_cards: Array = []
var buildings_built: Dictionary = DEFAULT_BUILDINGS_BUILT.duplicate(true)
var cat_house_slots: int = GameConstants.STARTING_CAT_HOUSE_SLOTS

# ─── 产房坑位 ─────────────────────────────────────────────────────────────────
# 每个坑位结构: { "active": bool, "father_id": String, "mother_id": String, "days_remaining": int }
var max_breeding_slots: int = GameConstants.BREEDING_SLOT_INITIAL
var breeding_slots: Array[Dictionary] = []

func _ready() -> void:
	randomize()
	_init_breeding_slots()
	ensure_intro_state()

func _process(delta: float) -> void:
	if starter_selection_pending or not intro_stray_pending or intro_stray_arrived:
		return
	if cats.is_empty():
		return
	intro_stray_timer_sec = maxf(0.0, intro_stray_timer_sec - delta)
	if intro_stray_timer_sec > 0.0:
		return
	var stray := CatFactory.create_intro_stray_cat(intro_stray_target_sex)
	if not enqueue_stray_cat(stray):
		return
	intro_stray_pending = false
	intro_stray_arrived = true
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.stray_cat_arrived.emit(stray)

func ensure_intro_state() -> void:
	if not cats.is_empty():
		starter_selection_pending = false
		starter_candidates.clear()
		return
	if not starter_selection_pending:
		return
	if starter_candidates.is_empty():
		starter_candidates = CatFactory.create_starter_choices()

func choose_starter_cat(index: int) -> CatData:
	ensure_intro_state()
	if not starter_selection_pending:
		return null
	if index < 0 or index >= starter_candidates.size():
		return null
	var chosen: CatData = starter_candidates[index]
	starter_candidates.clear()
	starter_selection_pending = false
	add_cat(chosen)
	_schedule_intro_stray(chosen.sex)
	return chosen

func reset_state() -> void:
	coins = GameConstants.STARTING_COINS
	cat_food = GameConstants.STARTING_CAT_FOOD
	cat_food_cap = GameConstants.STARTING_CAT_FOOD_CAP
	camp_day = GameConstants.STARTING_CAMP_DAY
	cats.clear()
	stray_cat_queue.clear()
	starter_selection_pending = true
	starter_candidates.clear()
	intro_stray_pending = false
	intro_stray_arrived = false
	intro_stray_timer_sec = 0.0
	intro_stray_target_sex = ""
	expedition_active = false
	expedition_cat_id = ""
	expedition_layer = 0
	expedition_battle_wins = 0
	expedition_buffs.clear()
	expedition_active_genes.clear()
	expedition_shop_cards.clear()
	buildings_built = DEFAULT_BUILDINGS_BUILT.duplicate(true)
	cat_house_slots = GameConstants.STARTING_CAT_HOUSE_SLOTS
	max_breeding_slots = GameConstants.BREEDING_SLOT_INITIAL
	breeding_slots.clear()
	_init_breeding_slots()
	ensure_intro_state()
	coins_changed.emit(coins)
	cat_food_changed.emit(cat_food)
	day_advanced.emit(camp_day)

func add_coins(value: int) -> void:
	if value <= 0:
		return
	coins += value
	coins_changed.emit(coins)

func spend_coins(value: int) -> bool:
	if value <= 0:
		return true
	if coins < value:
		return false
	coins -= value
	coins_changed.emit(coins)
	return true

func add_cat_food(value: int) -> void:
	if value <= 0:
		return
	cat_food = min(cat_food_cap, cat_food + value)
	cat_food_changed.emit(cat_food)

func set_cat_food(value: int) -> void:
	cat_food = clampi(value, 0, cat_food_cap)
	cat_food_changed.emit(cat_food)

func consume_cat_food(value: int) -> bool:
	if value <= 0:
		return true
	if cat_food < value:
		return false
	cat_food -= value
	cat_food_changed.emit(cat_food)
	return true

func add_cat(cat: CatData) -> bool:
	if cat == null:
		return false
	if not has_free_cat_house_slot():
		return false
	cats.append(cat)
	cat_added.emit(cat)
	return true

func get_occupied_cat_house_slots() -> int:
	var occupied := 0
	for cat: CatData in get_living_cats():
		if cat == null:
			continue
		occupied += 1
	return occupied

func get_living_cats() -> Array[CatData]:
	var living: Array[CatData] = []
	for cat: CatData in cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		living.append(cat)
	return living

func has_free_cat_house_slot() -> bool:
	return get_occupied_cat_house_slots() < cat_house_slots

func advance_camp_day() -> void:
	camp_day += 1
	day_advanced.emit(camp_day)

func mark_cat_dead(cat_id: String) -> void:
	for cat: CatData in cats:
		if cat == null:
			continue
		if cat.id == cat_id:
			if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
				return
			cat.status = GameConstants.LIFECYCLE_STATUS_DEAD
			cat_died.emit(cat)
			return

func enqueue_stray_cat(cat: CatData) -> bool:
	if stray_cat_queue.size() >= GameConstants.MAX_STRAY_QUEUE_SIZE:
		return false
	stray_cat_queue.append(cat)
	return true

func dequeue_stray_cat() -> CatData:
	if stray_cat_queue.is_empty():
		return null
	return stray_cat_queue.pop_front()

func set_building_state(building_id: String, built: bool) -> void:
	buildings_built[building_id] = built

func has_building(building_id: String) -> bool:
	return bool(buildings_built.get(building_id, false))

func get_building_level(building_id: String) -> int:
	var val = buildings_built.get(building_id, false)
	if val is int:
		return val
	if val == true:
		return 1
	return 0

func start_expedition(cat: CatData) -> bool:
	if cat == null or expedition_active:
		return false
	expedition_active = true
	expedition_cat_id = cat.id
	expedition_layer = 1
	expedition_battle_wins = 0
	expedition_buffs.clear()
	expedition_active_genes.clear()
	expedition_shop_cards.clear()
	cat.status = GameConstants.LIFECYCLE_STATUS_EXPEDITION
	return true

func record_expedition_battle_result(result: Dictionary) -> void:
	expedition_battle_wins += int(result.get("battle_wins", 0))
	for gene_id: String in result.get("active_genes_gained", []):
		add_expedition_active_gene(gene_id)

func add_expedition_buff(buff_id: String) -> void:
	if buff_id.is_empty():
		return
	expedition_buffs.append(buff_id)

func add_expedition_active_gene(gene_id: String) -> void:
	if gene_id.is_empty():
		return
	expedition_active_genes.append(gene_id)

func advance_expedition_layer() -> int:
	expedition_layer += 1
	return expedition_layer

func clear_expedition_state() -> void:
	expedition_active = false
	expedition_cat_id = ""
	expedition_layer = 0
	expedition_battle_wins = 0
	expedition_buffs.clear()
	expedition_active_genes.clear()
	expedition_shop_cards.clear()

func _schedule_intro_stray(selected_sex: String) -> void:
	intro_stray_pending = true
	intro_stray_arrived = false
	intro_stray_timer_sec = GameConstants.STARTER_STRAY_DELAY_SEC
	intro_stray_target_sex = _opposite_sex(selected_sex)

func _opposite_sex(value: String) -> String:
	if value == GameConstants.SEX_MALE:
		return GameConstants.SEX_FEMALE
	return GameConstants.SEX_MALE

# ─── 建筑升级 ─────────────────────────────────────────────────────────────────

## 返回升级是否成功
func upgrade_building(building_id: String) -> bool:
	match building_id:
		"cat_house":
			return _upgrade_cat_house()
		"granary":
			return _upgrade_granary()
		"fortune_cat":
			return _upgrade_fortune_cat()
		"nursery":
			return _upgrade_nursery()
	return false

func _upgrade_cat_house() -> bool:
	if cat_house_slots >= GameConstants.MAX_CAT_HOUSE_SLOTS:
		return false
	var cost: int = int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60))
	if coins < cost:
		return false
	coins -= cost
	cat_house_slots += 1
	coins_changed.emit(coins)
	return true

func _upgrade_granary() -> bool:
	var current_level: int = get_building_level("granary")
	if current_level >= GameConstants.GRANARY_MAX_LEVEL:
		return false
	var cost_idx: int = current_level - 1  # 0-based
	if cost_idx < 0 or cost_idx >= GameConstants.GRANARY_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[cost_idx])
	if coins < cost:
		return false
	coins -= cost
	buildings_built["granary"] = current_level + 1
	cat_food_cap = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(current_level + 1, cat_food_cap))
	coins_changed.emit(coins)
	cat_food_changed.emit(cat_food)
	return true

func _upgrade_fortune_cat() -> bool:
	var current_level: int = get_building_level("fortune_cat")
	if current_level >= GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
		return false
	var cost_idx: int = current_level - 1  # 0-based index into upgrade costs
	if cost_idx < 0 or cost_idx >= GameConstants.FORTUNE_CAT_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[cost_idx])
	if coins < cost:
		return false
	coins -= cost
	buildings_built["fortune_cat"] = current_level + 1
	coins_changed.emit(coins)
	return true

func _upgrade_nursery() -> bool:
	if max_breeding_slots >= GameConstants.BREEDING_SLOT_MAX:
		return false
	var cost_idx: int = max_breeding_slots - 1  # 0-based: 0=解锁第2坑, 1=解锁第3坑
	if cost_idx < 0 or cost_idx >= GameConstants.BREEDING_SLOT_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[cost_idx])
	if coins < cost:
		return false
	coins -= cost
	max_breeding_slots += 1
	_init_breeding_slots()
	coins_changed.emit(coins)
	return true

# ─── 产房坑位 API ─────────────────────────────────────────────────────────────

func _init_breeding_slots() -> void:
	while breeding_slots.size() < max_breeding_slots:
		breeding_slots.append({"active": false, "father_id": "", "mother_id": "", "days_remaining": 0})

func get_breeding_slot(index: int) -> Dictionary:
	if index < 0 or index >= breeding_slots.size():
		return {}
	return breeding_slots[index]

## 启动一个坑位的繁育。成功返回 true，失败返回 false。
func start_breeding_in_slot(slot_idx: int, father_id: String, mother_id: String, child_breed: String, child_profession: String) -> bool:
	if slot_idx < 0 or slot_idx >= breeding_slots.size():
		return false
	var slot: Dictionary = breeding_slots[slot_idx]
	if slot.get("active", false):
		return false
	if not has_free_cat_house_slot():
		return false
	# 验证父母
	if father_id == mother_id:
		return false
	var father := find_cat(father_id)
	var mother := find_cat(mother_id)
	if father == null or mother == null:
		return false
	if father.sex != GameConstants.SEX_MALE or mother.sex != GameConstants.SEX_FEMALE:
		return false
	# 成功率检定
	var chance := GameConstants.BREED_SUCCESS_WITH_NURSERY if has_building("nursery") else GameConstants.BREED_SUCCESS_WITHOUT_NURSERY
	if father.has_gene("love_spreader") or mother.has_gene("love_spreader"):
		chance = minf(1.0, chance + 0.15)
	if randf() > chance:
		return false  # 本次繁育失败，坑位不占用
	slot["active"] = true
	slot["father_id"] = father_id
	slot["mother_id"] = mother_id
	slot["child_breed"] = child_breed
	slot["child_profession"] = child_profession
	slot["days_remaining"] = GameConstants.BREEDING_SLOT_CD_DAYS
	father.breed_count += 1
	mother.breed_count += 1
	return true

## DayManager 每天调用，推进所有坑位倒计时，返回本天出生的猫列表
func tick_breeding_slots() -> Array[CatData]:
	var born: Array[CatData] = []
	for i in breeding_slots.size():
		var slot: Dictionary = breeding_slots[i]
		if not slot.get("active", false):
			continue
		slot["days_remaining"] = int(slot["days_remaining"]) - 1
		if slot["days_remaining"] > 0:
			continue
		# 出生
		var father := find_cat(str(slot.get("father_id", "")))
		var mother := find_cat(str(slot.get("mother_id", "")))
		if father != null and mother != null:
			var breeding_sys := BreedingSystem.new()
			var child_breed := str(slot.get("child_breed", father.breed))
			var child_profession := str(slot.get("child_profession", father.profession))
			var child := breeding_sys.breed(father, mother, child_breed, child_profession)
			if child != null and add_cat(child):
				born.append(child)
		# 清空坑位
		slot["active"] = false
		slot["father_id"] = ""
		slot["mother_id"] = ""
		slot["days_remaining"] = 0
	return born

func find_cat(cat_id: String) -> CatData:
	if cat_id.is_empty():
		return null
	for cat: CatData in cats:
		if cat != null and cat.id == cat_id:
			return cat
	return null
