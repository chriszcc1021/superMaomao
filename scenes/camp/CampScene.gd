extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CatSpriteScene := preload("res://scenes/common/CatSprite.tscn")

const BUILDING_SCENES := {
	"cat_house": preload("res://scenes/camp/buildings/CatHouse.tscn"),
	"nursery": preload("res://scenes/camp/buildings/Nursery.tscn"),
	"hospital": preload("res://scenes/camp/buildings/Hospital.tscn"),
	"food_farm": preload("res://scenes/camp/buildings/FoodFarm.tscn"),
	"gold_mine": preload("res://scenes/camp/buildings/GoldMine.tscn"),
	"granary": preload("res://scenes/camp/buildings/Granary.tscn"),
	"heart_cat_house": preload("res://scenes/camp/buildings/HeartCatHouse.tscn"),
	"cemetery": preload("res://scenes/camp/buildings/Cemetery.tscn")
}

const BUILDING_LAYOUT := {
	"cat_house": Vector2(220, 180),
	"granary": Vector2(430, 180),
	"food_farm": Vector2(640, 180),
	"gold_mine": Vector2(850, 180),
	"nursery": Vector2(220, 360),
	"hospital": Vector2(430, 360),
	"heart_cat_house": Vector2(640, 360),
	"cemetery": Vector2(850, 360)
}

@onready var _buildings_root: Node2D = $IsometricWorld/Buildings
@onready var _cats_root: Node2D = $IsometricWorld/Cats
@onready var _coins_label: Label = $UI/CampHUD/HBox/CoinsLabel
@onready var _food_label: Label = $UI/CampHUD/HBox/CatFoodLabel
@onready var _day_label: Label = $UI/CampHUD/HBox/DayLabel
@onready var _next_day_button: Button = $UI/CampHUD/HBox/NextDayButton
@onready var _cat_list_text: RichTextLabel = $UI/CatListUI/VBox/CatListText
@onready var _stray_panel: PanelContainer = $UI/StrayNotification
@onready var _stray_label: Label = $UI/StrayNotification/VBox/StrayLabel
@onready var _accept_stray_button: Button = $UI/StrayNotification/VBox/Buttons/AcceptButton
@onready var _reject_stray_button: Button = $UI/StrayNotification/VBox/Buttons/RejectButton
@onready var _defer_stray_button: Button = $UI/StrayNotification/VBox/Buttons/DeferButton
@onready var _open_breed_button: Button = $UI/SidePanel/VBox/OpenBreedingButton
@onready var _open_expedition_button: Button = $UI/SidePanel/VBox/OpenExpeditionButton
@onready var _breeding_ui: Control = $UI/BreedingUI

var GameState: Node = null
var EventBus: Node = null

func _ready() -> void:
	randomize()
	GameState = get_node_or_null("/root/GameState")
	EventBus = get_node_or_null("/root/EventBus")
	_spawn_buildings()
	_refresh_cat_nodes()
	_bind_signals()
	_refresh_hud()
	_refresh_cat_list()
	_refresh_stray_ui()

func _bind_signals() -> void:
	if not _next_day_button.pressed.is_connected(_on_next_day_pressed):
		_next_day_button.pressed.connect(_on_next_day_pressed)
	if not _accept_stray_button.pressed.is_connected(_on_accept_stray_pressed):
		_accept_stray_button.pressed.connect(_on_accept_stray_pressed)
	if not _reject_stray_button.pressed.is_connected(_on_reject_stray_pressed):
		_reject_stray_button.pressed.connect(_on_reject_stray_pressed)
	if not _defer_stray_button.pressed.is_connected(_on_defer_stray_pressed):
		_defer_stray_button.pressed.connect(_on_defer_stray_pressed)
	if not _open_breed_button.pressed.is_connected(_on_open_breeding_pressed):
		_open_breed_button.pressed.connect(_on_open_breeding_pressed)
	if not _open_expedition_button.pressed.is_connected(_on_open_expedition_pressed):
		_open_expedition_button.pressed.connect(_on_open_expedition_pressed)
	if not GameState.coins_changed.is_connected(_on_game_coins_changed):
		GameState.coins_changed.connect(_on_game_coins_changed)
	if not GameState.cat_food_changed.is_connected(_on_game_cat_food_changed):
		GameState.cat_food_changed.connect(_on_game_cat_food_changed)
	if not GameState.cat_added.is_connected(_on_game_cat_added):
		GameState.cat_added.connect(_on_game_cat_added)
	if _breeding_ui.has_method("bind_game_state"):
		_breeding_ui.call("bind_game_state", GameState)

func _spawn_buildings() -> void:
	for child: Node in _buildings_root.get_children():
		child.queue_free()
	for building_id: String in BUILDING_SCENES.keys():
		var scene: PackedScene = BUILDING_SCENES[building_id]
		var instance: Node2D = scene.instantiate()
		instance.position = BUILDING_LAYOUT.get(building_id, Vector2.ZERO)
		if not GameState.has_building(building_id):
			instance.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_buildings_root.add_child(instance)

func _refresh_cat_nodes() -> void:
	for child: Node in _cats_root.get_children():
		child.queue_free()
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = Vector2(
			randf_range(160.0, 920.0),
			randf_range(130.0, 520.0)
		)
		cat_sprite.call("setup", cat)
		_cats_root.add_child(cat_sprite)

func _on_next_day_pressed() -> void:
	advance_day()

func advance_day() -> void:
	GameState.camp_day += 1
	_consume_cat_food()
	_age_all_cats()
	_check_lifecycle()
	_produce_resources()
	_roll_stray_cat()
	GameState.day_advanced.emit(GameState.camp_day)
	_refresh_hud()
	_refresh_cat_list()
	_refresh_cat_nodes()
	_refresh_stray_ui()

func _consume_cat_food() -> void:
	var total_cost: int = 0
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			total_cost += GameConstants.FOOD_CONSUMPTION_KITTEN
		elif cat.status == GameConstants.LIFECYCLE_STATUS_ELDER:
			total_cost += GameConstants.FOOD_CONSUMPTION_ELDER
		else:
			total_cost += GameConstants.FOOD_CONSUMPTION_ADULT
	if total_cost <= 0:
		return
	if GameState.consume_cat_food(total_cost):
		return
	GameState.cat_food = 0
	GameState.cat_food_changed.emit(GameState.cat_food)
	_apply_food_shortage()

func _apply_food_shortage() -> void:
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		match cat.health:
			GameConstants.HEALTH_STATE_HEALTHY:
				cat.health = GameConstants.HEALTH_STATE_SICK
			GameConstants.HEALTH_STATE_SICK:
				cat.health = GameConstants.HEALTH_STATE_CRITICAL
			GameConstants.HEALTH_STATE_CRITICAL:
				cat.status = GameConstants.LIFECYCLE_STATUS_DEAD
				GameState.cat_died.emit(cat)

func _age_all_cats() -> void:
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		cat.age_days += 1

func _check_lifecycle() -> void:
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		if cat.age_days >= GameConstants.ADULT_MAX_DAYS or cat.breed_count >= GameConstants.MAX_BREED_COUNT:
			cat.status = GameConstants.LIFECYCLE_STATUS_ELDER
		if cat.status == GameConstants.LIFECYCLE_STATUS_ELDER and cat.age_days >= GameConstants.ADULT_MAX_DAYS + GameConstants.ELDER_DAYS:
			cat.status = GameConstants.LIFECYCLE_STATUS_DEAD
			GameState.cat_died.emit(cat)

func _produce_resources() -> void:
	var workers: int = _count_available_workers()
	if GameState.has_building("food_farm"):
		var food_workers: int = min(workers, 3)
		var food_gain: int = int(GameConstants.FOOD_FARM_OUTPUT_BY_WORKERS.get(food_workers, 3))
		GameState.add_cat_food(food_gain)
	if GameState.has_building("gold_mine"):
		var gold_workers: int = min(max(workers - 3, 0), 2)
		var gold_gain: int = int(GameConstants.GOLD_MINE_OUTPUT_BY_WORKERS.get(gold_workers, 2))
		GameState.add_coins(gold_gain)

func _count_available_workers() -> int:
	var count := 0
	for cat: CatData in GameState.cats:
		if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		count += 1
	return count

func _roll_stray_cat() -> void:
	if randf() > GameConstants.STRAY_CAT_DAILY_CHANCE:
		return
	if GameState.stray_cat_queue.size() >= GameConstants.MAX_STRAY_QUEUE_SIZE:
		return
	var stray_cat := _create_random_stray_cat()
	GameState.enqueue_stray_cat(stray_cat)
	EventBus.stray_cat_arrived.emit(stray_cat)

func _create_random_stray_cat() -> CatData:
	var cat := CatData.new()
	cat.id = "stray_%s" % [str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)]
	cat.cat_name = "流浪猫-%03d" % int(randi() % 1000)
	cat.breed = _random_key(GameConstants.BREED_MODIFIERS)
	cat.profession = _random_key(GameConstants.PROFESSION_BASE)
	cat.gene_head = _random_option("head")
	cat.gene_ear = _random_option("ear")
	cat.gene_eye_color = _random_option("eye_color")
	cat.gene_eye_shape = _random_option("eye_shape")
	cat.gene_fur_main = _random_option("fur_main")
	cat.gene_fur_accent = _random_option("fur_accent")
	cat.gene_pattern = _random_option("pattern")
	cat.gene_tail = _random_option("tail")
	cat.calculate_stats()
	return cat

func _random_key(dict: Dictionary) -> String:
	var keys: Array = dict.keys()
	if keys.is_empty():
		return ""
	return str(keys[randi() % keys.size()])

func _random_option(slot_key: String) -> String:
	var options: Array = GameConstants.APPEARANCE_GENE_OPTIONS.get(slot_key, [])
	if options.is_empty():
		return ""
	return str(options[randi() % options.size()])

func _on_accept_stray_pressed() -> void:
	if GameState.stray_cat_queue.is_empty():
		return
	if not GameState.has_free_cat_house_slot():
		_stray_label.text = "猫窝已满，请先扩建猫窝。"
		return
	var cat: CatData = GameState.dequeue_stray_cat()
	GameState.add_cat(cat)
	_refresh_cat_nodes()
	_refresh_cat_list()
	_refresh_stray_ui()

func _on_reject_stray_pressed() -> void:
	if GameState.stray_cat_queue.is_empty():
		return
	GameState.dequeue_stray_cat()
	_refresh_stray_ui()

func _on_defer_stray_pressed() -> void:
	_refresh_stray_ui()

func _on_open_breeding_pressed() -> void:
	_breeding_ui.visible = not _breeding_ui.visible

func _on_open_expedition_pressed() -> void:
	var scene_manager := get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.go_to_expedition_map()

func _refresh_hud() -> void:
	_coins_label.text = "金币: %d" % GameState.coins
	_food_label.text = "猫粮: %d/%d" % [GameState.cat_food, GameState.cat_food_cap]
	_day_label.text = "天数: %d" % GameState.camp_day

func _refresh_cat_list() -> void:
	var lines: PackedStringArray = []
	for cat: CatData in GameState.cats:
		lines.append(
			"%s | %s | %s | 年龄%d天 | %s" % [
				cat.cat_name,
				_profession_zh(cat.profession),
				_breed_zh(cat.breed),
				cat.age_days,
				_status_zh(cat.status)
			]
		)
	if lines.is_empty():
		_cat_list_text.text = "营地里暂无猫咪。"
		return
	_cat_list_text.text = "\n".join(lines)

func _refresh_stray_ui() -> void:
	_stray_panel.visible = not GameState.stray_cat_queue.is_empty()
	if GameState.stray_cat_queue.is_empty():
		return
	var head: CatData = GameState.stray_cat_queue[0]
	_stray_label.text = "流浪猫来访：%s（%s / %s）\n队列：%d/%d" % [
		head.cat_name,
		_profession_zh(head.profession),
		_breed_zh(head.breed),
		GameState.stray_cat_queue.size(),
		GameConstants.MAX_STRAY_QUEUE_SIZE
	]

func _on_game_coins_changed(_new_val: int) -> void:
	_refresh_hud()

func _on_game_cat_food_changed(_new_val: int) -> void:
	_refresh_hud()

func _on_game_cat_added(_cat: CatData) -> void:
	_refresh_cat_list()
	_refresh_cat_nodes()

func _profession_zh(profession_id: String) -> String:
	return str(GameConstants.PROFESSION_DISPLAY_ZH.get(profession_id, profession_id))

func _breed_zh(breed_id: String) -> String:
	return str(GameConstants.BREED_DISPLAY_ZH.get(breed_id, breed_id))

func _status_zh(status_id: String) -> String:
	match status_id:
		GameConstants.LIFECYCLE_STATUS_IDLE:
			return "待命"
		GameConstants.LIFECYCLE_STATUS_EXPEDITION:
			return "远征中"
		GameConstants.LIFECYCLE_STATUS_RETIRED:
			return "退休"
		GameConstants.LIFECYCLE_STATUS_ELDER:
			return "老年"
		GameConstants.LIFECYCLE_STATUS_DEAD:
			return "死亡"
		_:
			return status_id
