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
	"cemetery": preload("res://scenes/camp/buildings/Cemetery.tscn"),
	"fortune_cat": preload("res://scenes/camp/buildings/BuildingPlaceholder.tscn")
}

const BUILDING_LAYOUT := {
	"cat_house": Vector2(220, 180),
	"granary": Vector2(430, 180),
	"food_farm": Vector2(640, 180),
	"gold_mine": Vector2(850, 180),
	"nursery": Vector2(220, 360),
	"hospital": Vector2(430, 360),
	"heart_cat_house": Vector2(640, 360),
	"cemetery": Vector2(850, 360),
	"fortune_cat": Vector2(535, 520)
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
		# 添加点击区域，用于建筑交互和猫分配
		var click_area := Area2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(60.0, 60.0)
		col.shape = shape
		click_area.add_child(col)
		click_area.input_pickable = true
		click_area.input_event.connect(_on_building_clicked.bind(building_id))
		instance.add_child(click_area)
		_buildings_root.add_child(instance)

func _on_building_clicked(viewport: Node, event: InputEvent, _shape_idx: int, building_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if not GameState.has_building(building_id):
		return
	_show_building_sidebar(building_id)

func _refresh_cat_nodes() -> void:
	for child: Node in _cats_root.get_children():
		child.queue_free()
	for cat: CatData in GameState.get_living_cats():
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = _random_cat_spawn_position()
		cat_sprite.call("setup", cat)
		var assigned: String = str(cat.assigned_building)
		if not assigned.is_empty() and BUILDING_LAYOUT.has(assigned):
			var anchor: Vector2 = BUILDING_LAYOUT[assigned]
			anchor += Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0))
			cat_sprite.call("set_building_anchor", assigned, anchor)
		# 连接拖拽信号
		if cat_sprite.has_signal("drop_requested"):
			cat_sprite.connect("drop_requested", _on_cat_drop_requested)
		_cats_root.add_child(cat_sprite)

func _random_cat_spawn_position() -> Vector2:
	var rect: Rect2 = GameConstants.CAMP_CAT_SPAWN_RECT
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)

func _show_building_sidebar(building_id: String) -> void:
	var lines: PackedStringArray = []
	match building_id:
		"cat_house":
			lines.append("🏠 猫窝")
			lines.append("已住：%d / %d" % [GameState.get_living_cats().size(), GameState.cat_house_slots])
			lines.append("扩建费用：%d金" % GameConstants.BUILDING_COSTS.get("cat_house_expand", 60))
		"granary":
			lines.append("🌾 粮仓")
			lines.append("猫粮：%d / %d" % [GameState.cat_food, GameState.cat_food_cap])
		"food_farm":
			var workers := _get_assigned_cats_text("food_farm")
			lines.append("🌱 猫粮田")
			lines.append("工作猫：%s" % workers)
			lines.append("每日产粮：按工作猫数量")
		"gold_mine":
			var workers := _get_assigned_cats_text("gold_mine")
			lines.append("⛏️ 金矿")
			lines.append("工作猫：%s" % workers)
		"fortune_cat":
			var workers := _get_assigned_cats_text("fortune_cat")
			var level := GameState.get_building_level("fortune_cat")
			var per := int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(level, 15))
			var max_w := int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level, 1))
			lines.append("🪙 招财猫神龛 Lv%d" % level)
			lines.append("工作猫（%d/%d）：%s" % [_count_assigned_cats("fortune_cat"), max_w, workers])
			lines.append("每日产金：%d金/只猫" % per)
		"nursery":
			lines.append("🍼 产房")
			lines.append("繁育成功率：%d%%" % int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100))
		"hospital":
			lines.append("🏥 医院 → 查看详情")
		"heart_cat_house":
			lines.append("❤️ 爱心猫窝")
			lines.append("流浪猫来访概率提升 +20%%")
		"cemetery":
			lines.append("🪦 墓地 → 查看详情")
	# 分配猫到建筑按钮（招财猫、猫粮田、金矿）
	if building_id in ["fortune_cat", "food_farm", "gold_mine"]:
		lines.append("")
		lines.append("── 分配猫咪 ──")
		for cat: CatData in GameState.get_living_cats():
			if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
				continue
			var mark := "✅" if str(cat.assigned_building) == building_id else "  "
			lines.append("%s %s (%s)" % [mark, cat.cat_name, _profession_zh(cat.profession)])
	_set_sidebar_text("\n".join(lines))

func _get_assigned_cats_text(building_id: String) -> String:
	var names: PackedStringArray = []
	for cat: CatData in GameState.get_living_cats():
		if str(cat.assigned_building) == building_id:
			names.append(cat.cat_name)
	return ", ".join(names) if not names.is_empty() else "无"

func _count_assigned_cats(building_id: String) -> int:
	var count := 0
	for cat: CatData in GameState.get_living_cats():
		if str(cat.assigned_building) == building_id:
			count += 1
	return count

func _set_sidebar_text(text: String) -> void:
	# 直接用 cat_list_text 作为侧边栏展示（临时复用）
	if _cat_list_text != null:
		if _cat_list_text != null:
		_cat_list_text.text = text

func _on_cat_drop_requested(cat: CatData, world_pos: Vector2) -> void:
	# 找最近的建筑（60px阈值）
	var nearest_id := ""
	var nearest_dist := 70.0
	for building_id: String in BUILDING_LAYOUT.keys():
		if not GameState.has_building(building_id):
			continue
		var dist := world_pos.distance_to(BUILDING_LAYOUT[building_id])
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = building_id

	if nearest_id.is_empty():
		# 没有建筑附近 → 自由漫游
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	if cat.assigned_building == nearest_id:
		# 放在已分配建筑 → 取消分配
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	var cap := _get_building_worker_cap(nearest_id)
	var current := _count_assigned_cats(nearest_id)
	if current >= cap:
		# 已满员 → 回旧建筑（如旧建筑仍有空位），否则漫游
		var old_id := str(cat.assigned_building)
		if not old_id.is_empty() and old_id != nearest_id:
			var old_cap := _get_building_worker_cap(old_id)
			# 算旧建筑中不含自己的数量
			var old_count := _count_assigned_cats(old_id) - 1
			if old_count < old_cap:
				_refresh_cat_nodes()
				return  # 猫还在旧建筑，不变
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	# 从旧建筑解绑，分配到新建筑
	cat.assigned_building = nearest_id
	_refresh_cat_nodes()

func _get_building_worker_cap(building_id: String) -> int:
	if building_id == "fortune_cat":
		var level := GameState.get_building_level("fortune_cat")
		return int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level, 1))
	var base_cap = GameConstants.BUILDING_WORKER_CAP.get(building_id, null)
	if base_cap != null:
		return int(base_cap)
	return 999  # 无上限（猫窝、粮仓、墓地等）
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
