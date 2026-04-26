extends Node

# Preloader autoload 确保这些 class_name �?GameState 解析前已注册
# 但为安全起见保留显式引用（Godot 4.2 autoload 有时仍需要）
const CatData        := preload("res://resources/CatData.gd")
const GameConstants  := preload("res://data/constants.gd")
const CatFactory     := preload("res://data/cat_factory.gd")
const BuildingService := preload("res://autoload/BuildingService.gd")
const BreedingSlotService := preload("res://autoload/BreedingSlotService.gd")

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
var pending_expedition_summary: String = ""
var buildings_built: Dictionary = DEFAULT_BUILDINGS_BUILT.duplicate(true)
var cat_house_slots: int = GameConstants.STARTING_CAT_HOUSE_SLOTS
var _building_service = BuildingService.new()
var _breeding_slot_service = BreedingSlotService.new()

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
	pending_expedition_summary = ""
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
	for cat: CatData in cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_RETIRED:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
			continue  # 已入葬，不占坑位
		occupied += 1
	return occupied

func get_living_cats() -> Array[CatData]:
	var living: Array[CatData] = []
	for cat: CatData in cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_RETIRED:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
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

func is_cat_breeding(cat: CatData) -> bool:
	return _breeding_slot_service.is_cat_breeding(self, cat)

func can_cat_breed(cat: CatData) -> bool:
	return _breeding_slot_service.can_cat_breed(self, cat)

func get_breedable_cats() -> Array[CatData]:
	return _breeding_slot_service.get_breedable_cats(self)

func get_expedition_block_reason(cat: CatData) -> String:
	if cat == null:
		return "没有选择出征猫。"
	if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
		return "死亡的猫不能出征。"
	if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
		return "这只猫已经不可用了。"
	if cat.status == GameConstants.LIFECYCLE_STATUS_RETIRED:
		return "退休的猫不能再出征。"
	if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
		return "这只猫已经在远征中。"
	if cat.has_expeditioned:
		return "这只猫已经远征过了，一生限一次。"
	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		return "只有健康状态的猫可以出征。"
	if is_cat_breeding(cat):
		return "繁育中的猫不能出征。"
	return ""

func can_cat_join_expedition(cat: CatData) -> bool:
	return get_expedition_block_reason(cat).is_empty()

func get_expedition_candidates() -> Array[CatData]:
	var result: Array[CatData] = []
	for cat: CatData in get_living_cats():
		if can_cat_join_expedition(cat):
			result.append(cat)
	return result

func start_expedition(cat: CatData) -> bool:
	if cat == null or expedition_active:
		return false
	if not can_cat_join_expedition(cat):
		return false
	expedition_active = true
	expedition_cat_id = cat.id
	expedition_layer = 1
	expedition_battle_wins = 0
	expedition_buffs.clear()
	expedition_active_genes.clear()
	expedition_shop_cards.clear()
	cat.status = GameConstants.LIFECYCLE_STATUS_EXPEDITION
	# Model B：远征开始时重置继承血量（满血出发）
	cat.current_hp = -1.0
	return true

func record_expedition_battle_result(result: Dictionary) -> void:
	expedition_battle_wins += int(result.get("battle_wins", 0))
	for gene_id: String in result.get("active_genes_gained", []):
		add_expedition_active_gene(gene_id)

func add_expedition_buff(buff_id: String) -> void:
	if buff_id.is_empty():
		return
	expedition_buffs.append(buff_id)

## 新版：以字典格式存储 buff，供 BattleScene 应用
func add_expedition_buff_dict(buff: Dictionary) -> void:
	if buff.is_empty():
		return
	expedition_buffs.append(buff)

func consume_expedition_buff(buff) -> void:
	expedition_buffs.erase(buff)

func pop_random_expedition_buff() -> Dictionary:
	if expedition_buffs.is_empty():
		return {}
	var remove_idx := randi() % expedition_buffs.size()
	var removed = expedition_buffs[remove_idx]
	expedition_buffs.remove_at(remove_idx)
	if removed is Dictionary:
		return removed
	return {"label": str(removed)}

func add_expedition_active_gene(gene_id: String) -> void:
	if gene_id.is_empty():
		return
	expedition_active_genes.append(gene_id)

func add_expedition_shop_card(card_def: Dictionary) -> void:
	if card_def.is_empty():
		return
	expedition_shop_cards.append(card_def)

func advance_expedition_layer() -> int:
	expedition_layer += 1
	return expedition_layer

func set_pending_expedition_summary(summary: String) -> void:
	pending_expedition_summary = summary

func consume_pending_expedition_summary() -> String:
	var summary := pending_expedition_summary
	pending_expedition_summary = ""
	return summary

func restore_expedition_state(data: Dictionary) -> void:
	expedition_active = bool(data.get("expedition_active", false))
	expedition_cat_id = str(data.get("expedition_cat_id", ""))
	expedition_layer = int(data.get("expedition_layer", 0))
	expedition_battle_wins = int(data.get("expedition_battle_wins", 0))
	if data.has("expedition_buffs"):
		expedition_buffs = data["expedition_buffs"]
	if data.has("expedition_active_genes"):
		var genes: Array[String] = []
		for gene_id in data["expedition_active_genes"]:
			genes.append(str(gene_id))
		expedition_active_genes = genes
	if data.has("expedition_shop_cards"):
		expedition_shop_cards = data["expedition_shop_cards"]

func clear_expedition_state() -> void:
	expedition_active = false
	expedition_cat_id = ""
	expedition_layer = 0
	expedition_battle_wins = 0
	expedition_buffs.clear()
	expedition_active_genes.clear()
	expedition_shop_cards.clear()

func retire_cat(cat_id: String) -> void:
	var cat := find_cat(cat_id)
	if cat == null:
		return
	cat.status = GameConstants.LIFECYCLE_STATUS_RETIRED
	cat.health = GameConstants.HEALTH_STATE_HEALTHY
	cat.assigned_building = ""

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
## 建造一个新建筑。成功返�?true，失败返�?false�?
func build_building(building_id: String) -> bool:
	return _building_service.build_building(self, building_id)

func upgrade_building(building_id: String) -> bool:
	return _building_service.upgrade_building(self, building_id)

# ─── 产房坑位 API ─────────────────────────────────────────────────────────────

func _init_breeding_slots() -> void:
	_breeding_slot_service.init_slots(self)

func sync_breeding_slots() -> void:
	_breeding_slot_service.sync_slots(self)

func get_breeding_slot(index: int) -> Dictionary:
	if index < 0 or index >= breeding_slots.size():
		return {}
	return breeding_slots[index]

## 启动一个坑位的繁育。成功返�?true，失败返�?false�?
func start_breeding_in_slot(slot_idx: int, father_id: String, mother_id: String, child_breed: String, child_profession: String) -> bool:
	return _breeding_slot_service.start_in_slot(self, slot_idx, father_id, mother_id, child_breed, child_profession)

func tick_breeding_slots() -> Array[CatData]:
	return _breeding_slot_service.tick_slots(self)

func find_cat(cat_id: String) -> CatData:
	if cat_id.is_empty():
		return null
	for cat: CatData in cats:
		if cat != null and cat.id == cat_id:
			return cat
	return null

## 入葬猫咪到墓地，生成生平，释放坑�?
func bury_cat(cat_id: String) -> String:
	var cat := find_cat(cat_id)
	if cat == null or cat.status != GameConstants.LIFECYCLE_STATUS_DEAD:
		return ""
	cat.status = GameConstants.LIFECYCLE_STATUS_BURIED
	return _generate_biography(cat)

func _generate_biography(cat: CatData) -> String:
	var lines: PackedStringArray = []
	lines.append("🪦 %s 生平" % cat.cat_name)
	lines.append("品种：%s　职业：%s　性别：%s" % [
		GameConstants.breed_zh(cat.breed),
		GameConstants.profession_zh(cat.profession),
		GameConstants.sex_display(cat.sex)
	])
	lines.append("享年 %d 天　繁育 %d 次" % [cat.age_days, cat.breed_count])
	if cat.has_expeditioned:
		lines.append("曾参与远征，为营地立下功勋。")
	else:
		lines.append("未曾出征，守护营地度过一生。")
	var genes := cat.get_special_genes()
	if not genes.is_empty():
		var names: PackedStringArray = []
		for g: String in genes:
			names.append(str(GameConstants.GENE_DISPLAY_ZH.get(g, {}).get("name", g)))
		lines.append("天赋：%s" % "、".join(names))
	lines.append("愿你在天堂有吃不完的鱼罐头。")
	return "\n".join(lines)
