extends Node

const CatFactory := preload("res://data/cat_factory.gd")

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

func _ready() -> void:
	randomize()
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
