extends Node2D

const CatSpriteScene := preload("res://scenes/common/CatSprite.tscn")
const DayManagerScript := preload("res://scenes/camp/DayManager.gd")

const BUILDING_SCENES := {
	"cat_house": preload("res://scenes/camp/buildings/CatHouse.tscn"),
	"nursery": preload("res://scenes/camp/buildings/Nursery.tscn"),
	"hospital": preload("res://scenes/camp/buildings/Hospital.tscn"),
	"food_farm": preload("res://scenes/camp/buildings/FoodFarm.tscn"),
	"gold_mine": preload("res://scenes/camp/buildings/GoldMine.tscn"),
	"granary": preload("res://scenes/camp/buildings/Granary.tscn"),
	"heart_cat_house": preload("res://scenes/camp/buildings/HeartCatHouse.tscn"),
	"cemetery": preload("res://scenes/camp/buildings/Cemetery.tscn"),
	"fortune_cat": preload("res://scenes/camp/buildings/BuildingPlaceholder.tscn"),
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
	"fortune_cat": Vector2(535, 520),
}

const STATUS_DISPLAY := {
	GameConstants.LIFECYCLE_STATUS_IDLE: "Idle",
	GameConstants.LIFECYCLE_STATUS_EXPEDITION: "Expedition",
	GameConstants.LIFECYCLE_STATUS_RETIRED: "Retired",
	GameConstants.LIFECYCLE_STATUS_ELDER: "Elder",
	GameConstants.LIFECYCLE_STATUS_DEAD: "Dead",
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
@onready var _ui_layer: CanvasLayer = $UI

var _time_manager: Node = null
var _is_night: bool = false
var _game_state: Node = null
var _event_bus: Node = null
var _day_manager: RefCounted = DayManagerScript.new()

var _starter_overlay: Control = null
var _starter_hint_label: Label = null
var _starter_choice_buttons: Array[Button] = []
var _starter_overlay_paused_time: bool = false

func _ready() -> void:
	randomize()
	_game_state = get_node_or_null("/root/GameState")
	_event_bus = get_node_or_null("/root/EventBus")
	_time_manager = get_node_or_null("/root/TimeManager")
	if _game_state != null and _game_state.has_method("ensure_intro_state"):
		_game_state.ensure_intro_state()
	_spawn_buildings()
	_bind_signals()
	_bind_time_signals()
	_build_starter_overlay()
	_refresh_starter_overlay()
	_refresh_all()
	if _next_day_button != null:
		_next_day_button.visible = false

func _process(_delta: float) -> void:
	_refresh_time_label()
	# starter overlay 只在首次显示时刷新，不需要每帧调用

func _bind_time_signals() -> void:
	if _time_manager == null:
		return
	if not _time_manager.night_started.is_connected(_on_night_started):
		_time_manager.night_started.connect(_on_night_started)
	if not _time_manager.day_started.is_connected(_on_day_started):
		_time_manager.day_started.connect(_on_day_started)
	if not _time_manager.day_boundary_crossed.is_connected(_on_day_boundary_crossed):
		_time_manager.day_boundary_crossed.connect(_on_day_boundary_crossed)

func _on_night_started() -> void:
	_is_night = true
	_refresh_cat_nodes()
	_refresh_hud()

func _on_day_started() -> void:
	_is_night = false
	_refresh_cat_nodes()
	_refresh_hud()

func _on_day_boundary_crossed() -> void:
	_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	if _starter_overlay != null and _starter_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel") and _time_manager != null:
		if bool(_time_manager.time_paused):
			_time_manager.resume()
		else:
			_time_manager.pause()
		_refresh_hud()

func _refresh_time_label() -> void:
	if _time_manager == null or _day_label == null:
		return
	var time_label: String = str(_time_manager.get_time_label())
	var paused_tag: String = " [Paused]" if bool(_time_manager.time_paused) else ""
	_day_label.text = "Day %d %s%s" % [int(_time_manager.total_days) + 1, time_label, paused_tag]

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
	if _game_state != null and not _game_state.coins_changed.is_connected(_on_game_coins_changed):
		_game_state.coins_changed.connect(_on_game_coins_changed)
	if _game_state != null and not _game_state.cat_food_changed.is_connected(_on_game_cat_food_changed):
		_game_state.cat_food_changed.connect(_on_game_cat_food_changed)
	if _game_state != null and not _game_state.cat_added.is_connected(_on_game_cat_added):
		_game_state.cat_added.connect(_on_game_cat_added)
	if _event_bus != null and not _event_bus.stray_cat_arrived.is_connected(_on_stray_cat_arrived):
		_event_bus.stray_cat_arrived.connect(_on_stray_cat_arrived)
	if _breeding_ui.has_method("bind_game_state"):
		_breeding_ui.call("bind_game_state", _game_state)

func _spawn_buildings() -> void:
	for child: Node in _buildings_root.get_children():
		child.queue_free()
	for building_id: String in BUILDING_SCENES.keys():
		var packed_scene: PackedScene = BUILDING_SCENES[building_id]
		var instance: Node2D = packed_scene.instantiate()
		instance.position = BUILDING_LAYOUT.get(building_id, Vector2.ZERO)
		if not _game_state.has_building(building_id):
			instance.modulate = Color(1.0, 1.0, 1.0, 0.35)
		if instance.has_method("set"):
			instance.set("building_id", building_id)
			instance.set("display_name", _building_display_name(building_id))
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

func _on_building_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, building_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _game_state.has_building(building_id):
		return
	_show_building_sidebar(building_id)

func _refresh_cat_nodes() -> void:
	for child: Node in _cats_root.get_children():
		child.queue_free()
	for cat: CatData in _game_state.get_living_cats():
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = _random_cat_spawn_position()
		cat_sprite.call("setup", cat)
		var assigned: String = str(cat.assigned_building)
		if not assigned.is_empty() and BUILDING_LAYOUT.has(assigned):
			var anchor: Vector2 = BUILDING_LAYOUT[assigned]
			anchor += Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0))
			cat_sprite.call("set_building_anchor", assigned, anchor)
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
			lines.append("Cat House")
			lines.append("Occupancy: %d / %d" % [_game_state.get_living_cats().size(), _game_state.cat_house_slots])
			var expand_cost: int = _get_effective_building_cost(int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60)))
			lines.append("Expand cost: %d coins" % expand_cost)
		"granary":
			lines.append("Granary")
			lines.append("Food: %d / %d" % [_game_state.cat_food, _game_state.cat_food_cap])
		"food_farm":
			var farm_workers: String = _get_assigned_cats_text("food_farm")
			lines.append("Food Farm")
			lines.append("Workers: %s" % farm_workers)
		"gold_mine":
			var mine_workers: String = _get_assigned_cats_text("gold_mine")
			lines.append("Gold Mine")
			lines.append("Workers: %s" % mine_workers)
		"fortune_cat":
			var fortune_workers: String = _get_assigned_cats_text("fortune_cat")
			var fortune_level: int = int(_game_state.get_building_level("fortune_cat"))
			var per_worker: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(fortune_level, 15))
			var max_workers: int = int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(fortune_level, 1))
			lines.append("Fortune Cat Lv%d" % fortune_level)
			lines.append("Workers: %d / %d" % [_count_assigned_cats("fortune_cat"), max_workers])
			lines.append("Assigned: %s" % fortune_workers)
			lines.append("Daily output: %d coins each" % per_worker)
		"nursery":
			lines.append("Nursery")
			lines.append("Breeding success: %d%%" % int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100.0))
		"hospital":
			lines.append("Hospital")
		"heart_cat_house":
			lines.append("Heart Cat House")
			lines.append("Stray cat chance bonus: +20%%")
		"cemetery":
			lines.append("Cemetery")
	if building_id in ["fortune_cat", "food_farm", "gold_mine"]:
		lines.append("")
		lines.append("Assignments")
		for cat: CatData in _game_state.get_living_cats():
			if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
				continue
			var mark: String = "[x]" if str(cat.assigned_building) == building_id else "[ ]"
			lines.append("%s %s (%s)" % [mark, cat.cat_name, GameConstants.profession_zh(cat.profession)])
	_set_sidebar_text("\n".join(lines))

func _get_assigned_cats_text(building_id: String) -> String:
	var names: PackedStringArray = []
	for cat: CatData in _game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			names.append(cat.cat_name)
	return ", ".join(names) if not names.is_empty() else "None"

func _count_assigned_cats(building_id: String) -> int:
	var count: int = 0
	for cat: CatData in _game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			count += 1
	return count

func _get_effective_building_cost(base_cost: int) -> int:
	for cat: CatData in _game_state.get_living_cats():
		if cat.has_gene("builder_discount"):
			return int(base_cost * 0.80)
	return base_cost

func _set_sidebar_text(text: String) -> void:
	if _cat_list_text != null:
		_cat_list_text.text = text

func _on_cat_drop_requested(cat: CatData, world_pos: Vector2) -> void:
	var nearest_id: String = ""
	var nearest_dist: float = 70.0
	for building_id: String in BUILDING_LAYOUT.keys():
		if not _game_state.has_building(building_id):
			continue
		var dist: float = world_pos.distance_to(BUILDING_LAYOUT[building_id])
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = building_id

	if nearest_id.is_empty():
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	if cat.assigned_building == nearest_id:
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	var cap: int = _get_building_worker_cap(nearest_id)
	var current: int = _count_assigned_cats(nearest_id)
	if current >= cap:
		var old_id: String = str(cat.assigned_building)
		if not old_id.is_empty() and old_id != nearest_id:
			var old_cap: int = _get_building_worker_cap(old_id)
			var old_count: int = _count_assigned_cats(old_id) - 1
			if old_count < old_cap:
				_refresh_cat_nodes()
				return
		cat.assigned_building = ""
		_refresh_cat_nodes()
		return

	cat.assigned_building = nearest_id
	_refresh_cat_nodes()

func _get_building_worker_cap(building_id: String) -> int:
	if building_id == "fortune_cat":
		var level: int = int(_game_state.get_building_level("fortune_cat"))
		return int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level, 1))
	var base_cap: Variant = GameConstants.BUILDING_WORKER_CAP.get(building_id, null)
	if base_cap != null:
		return int(base_cap)
	return 999

func _on_next_day_pressed() -> void:
	_day_manager.advance_day(_game_state, _event_bus)
	_refresh_all()

func _on_accept_stray_pressed() -> void:
	if _game_state.stray_cat_queue.is_empty():
		return
	if not _game_state.has_free_cat_house_slot():
		_stray_label.text = "Cat house is full."
		return
	var cat: CatData = _game_state.dequeue_stray_cat()
	_game_state.add_cat(cat)
	_refresh_all()

func _on_reject_stray_pressed() -> void:
	if _game_state.stray_cat_queue.is_empty():
		return
	_game_state.dequeue_stray_cat()
	_refresh_stray_ui()

func _on_defer_stray_pressed() -> void:
	_refresh_stray_ui()

func _on_open_breeding_pressed() -> void:
	_breeding_ui.visible = not _breeding_ui.visible

func _on_open_expedition_pressed() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.go_to_expedition_map()

func _refresh_all() -> void:
	_refresh_hud()
	_refresh_cat_list()
	_refresh_cat_nodes()
	_refresh_stray_ui()
	_refresh_starter_overlay()

func _refresh_hud() -> void:
	_coins_label.text = "Coins: %d" % _game_state.coins
	_food_label.text = "Food: %d/%d" % [_game_state.cat_food, _game_state.cat_food_cap]
	_refresh_time_label()

func _refresh_cat_list() -> void:
	var lines: PackedStringArray = []
	for cat: CatData in _game_state.cats:
		lines.append(
			"%s | %s | %s | %s | Age %d | %s"
			% [
				cat.cat_name,
				GameConstants.sex_display(cat.sex),
				GameConstants.profession_zh(cat.profession),
				GameConstants.breed_zh(cat.breed),
				cat.age_days,
				_status_zh(cat.status),
			]
		)
	if lines.is_empty():
		_cat_list_text.text = "Choose your first cat to begin."
		return
	_cat_list_text.text = "\n".join(lines)

func _refresh_stray_ui() -> void:
	_stray_panel.visible = not _game_state.stray_cat_queue.is_empty()
	if _game_state.stray_cat_queue.is_empty():
		return
	var head: CatData = _game_state.stray_cat_queue[0]
	_stray_label.text = "Stray cat: %s, %s, %s / %s\nQueue: %d/%d" % [
		head.cat_name,
		GameConstants.sex_display(head.sex),
		GameConstants.profession_zh(head.profession),
		GameConstants.breed_zh(head.breed),
		_game_state.stray_cat_queue.size(),
		GameConstants.MAX_STRAY_QUEUE_SIZE,
	]

func _on_game_coins_changed(_new_val: int) -> void:
	_refresh_hud()

func _on_game_cat_food_changed(_new_val: int) -> void:
	_refresh_hud()

func _on_game_cat_added(_cat: CatData) -> void:
	_refresh_cat_list()
	_refresh_cat_nodes()

func _on_stray_cat_arrived(_cat: CatData) -> void:
	_refresh_stray_ui()
	_set_sidebar_text("A new stray cat has arrived at camp.")

func _status_zh(status_id: String) -> String:
	return str(STATUS_DISPLAY.get(status_id, status_id))

func _building_display_name(building_id: String) -> String:
	match building_id:
		"cat_house":
			return "Cat House"
		"granary":
			return "Granary"
		"food_farm":
			return "Food Farm"
		"gold_mine":
			return "Gold Mine"
		"nursery":
			return "Nursery"
		"hospital":
			return "Hospital"
		"heart_cat_house":
			return "Heart House"
		"cemetery":
			return "Cemetery"
		"fortune_cat":
			return "Fortune Cat"
	return building_id

func _build_starter_overlay() -> void:
	if _starter_overlay != null:
		return

	var overlay := ColorRect.new()
	overlay.name = "StarterOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.07, 0.10, 0.86)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040.0, 420.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -520.0
	panel.offset_top = -210.0
	panel.offset_right = 520.0
	panel.offset_bottom = 210.0
	overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Choose Your First Cat"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Pick 1 of 3 starter cats. A second opposite-sex stray cat will visit camp shortly after."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	_starter_hint_label = hint

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 18)
	root.add_child(choices)

	for index in GameConstants.STARTER_CHOICE_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300.0, 250.0)
		button.clip_text = false
		button.pressed.connect(_on_starter_choice_pressed.bind(index))
		choices.add_child(button)
		_starter_choice_buttons.append(button)

	_ui_layer.add_child(overlay)
	_starter_overlay = overlay

func _refresh_starter_overlay() -> void:
	if _starter_overlay == null or _game_state == null:
		return
	var needs_choice: bool = bool(_game_state.starter_selection_pending)
	_starter_overlay.visible = needs_choice
	if not needs_choice:
		if _starter_overlay_paused_time and _time_manager != null and bool(_time_manager.time_paused):
			_time_manager.resume()
		_starter_overlay_paused_time = false
		return

	if _time_manager != null and not bool(_time_manager.time_paused):
		_time_manager.pause()
		_starter_overlay_paused_time = true

	var candidates: Array = _game_state.starter_candidates
	for index in _starter_choice_buttons.size():
		var button := _starter_choice_buttons[index]
		if index >= candidates.size():
			button.disabled = true
			button.text = "Unavailable"
			continue
		var cat: CatData = candidates[index]
		button.disabled = false
		button.text = _starter_button_text(cat)

func _starter_button_text(cat: CatData) -> String:
	var traits: PackedStringArray = []
	for gene_id: String in cat.get_special_genes():
		traits.append(gene_id)
	var trait_text := ", ".join(traits) if not traits.is_empty() else "None"
	return "%s\n%s %s / %s\nHP %.0f  ATK %.0f\nSpeed %.1f  Range %.1f\nTrait: %s" % [
		cat.cat_name,
		GameConstants.sex_display(cat.sex),
		GameConstants.profession_zh(cat.profession),
		GameConstants.breed_zh(cat.breed),
		cat.base_hp,
		cat.base_attack,
		cat.base_attack_speed,
		cat.base_range,
		trait_text,
	]

func _on_starter_choice_pressed(index: int) -> void:
	var chosen: CatData = _game_state.choose_starter_cat(index)
	if chosen == null:
		return
	_refresh_all()
	_refresh_starter_overlay()
	_set_sidebar_text(
		"Starter chosen: %s\nA %s stray cat will visit soon." % [
			chosen.cat_name,
			GameConstants.sex_display(_game_state.intro_stray_target_sex),
		]
	)
