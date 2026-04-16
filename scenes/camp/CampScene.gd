extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CatSpriteScene := preload("res://scenes/common/CatSprite.tscn")
const DayManager := preload("res://scenes/camp/DayManager.gd")

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

const STATUS_DISPLAY_ZH := {
	GameConstants.LIFECYCLE_STATUS_IDLE: "待命",
	GameConstants.LIFECYCLE_STATUS_EXPEDITION: "远征中",
	GameConstants.LIFECYCLE_STATUS_RETIRED: "退休",
	GameConstants.LIFECYCLE_STATUS_ELDER: "老年",
	GameConstants.LIFECYCLE_STATUS_DEAD: "死亡"
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
var _day_manager := DayManager.new()

func _ready() -> void:
	randomize()
	GameState = get_node_or_null("/root/GameState")
	EventBus = get_node_or_null("/root/EventBus")
	_spawn_buildings()
	_bind_signals()
	_refresh_all()

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
		var instance: Node2D = (BUILDING_SCENES[building_id] as PackedScene).instantiate()
		instance.position = BUILDING_LAYOUT.get(building_id, Vector2.ZERO)
		if not GameState.has_building(building_id):
			instance.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_buildings_root.add_child(instance)

func _refresh_cat_nodes() -> void:
	for child: Node in _cats_root.get_children():
		child.queue_free()
	for cat: CatData in GameState.get_living_cats():
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = _random_cat_spawn_position()
		cat_sprite.call("setup", cat)
		_cats_root.add_child(cat_sprite)

func _random_cat_spawn_position() -> Vector2:
	var rect: Rect2 = GameConstants.CAMP_CAT_SPAWN_RECT
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)

func _on_next_day_pressed() -> void:
	_day_manager.advance_day(GameState, EventBus)
	_refresh_all()

func _on_accept_stray_pressed() -> void:
	if GameState.stray_cat_queue.is_empty():
		return
	if not GameState.has_free_cat_house_slot():
		_stray_label.text = "猫窝已满，请先扩建猫窝。"
		return
	var cat: CatData = GameState.dequeue_stray_cat()
	GameState.add_cat(cat)
	_refresh_all()

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

func _refresh_all() -> void:
	_refresh_hud()
	_refresh_cat_list()
	_refresh_cat_nodes()
	_refresh_stray_ui()

func _refresh_hud() -> void:
	_coins_label.text = "金币: %d" % GameState.coins
	_food_label.text = "猫粮: %d/%d" % [GameState.cat_food, GameState.cat_food_cap]
	_day_label.text = "天数: %d" % GameState.camp_day

func _refresh_cat_list() -> void:
	var lines: PackedStringArray = []
	for cat: CatData in GameState.cats:
		lines.append(
			"%s | %s | %s | 年龄%d天 | %s"
			% [cat.cat_name, _profession_zh(cat.profession), _breed_zh(cat.breed), cat.age_days, _status_zh(cat.status)]
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
	_stray_label.text = "流浪猫来访：%s，%s / %s\n队列：%d/%d" % [
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
	return str(STATUS_DISPLAY_ZH.get(status_id, status_id))
