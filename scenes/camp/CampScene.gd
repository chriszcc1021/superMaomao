extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData       := preload("res://resources/CatData.gd")

const CatSpriteScene := preload("res://scenes/common/CatSprite.tscn")
const DayManagerScript := preload("res://scenes/camp/DayManager.gd")
const StarterCatPreviewScript := preload("res://scenes/camp/ui/StarterCatPreview.gd")

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
	GameConstants.LIFECYCLE_STATUS_IDLE: "待命",
	GameConstants.LIFECYCLE_STATUS_EXPEDITION: "远征中",
	GameConstants.LIFECYCLE_STATUS_RETIRED: "退休",
	GameConstants.LIFECYCLE_STATUS_ELDER: "老年",
	GameConstants.LIFECYCLE_STATUS_DEAD: "死亡",
	GameConstants.LIFECYCLE_STATUS_BURIED: "已入葬",
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
var _starter_previews: Array[Control] = []
var _starter_info_labels: Array[Label] = []
var _starter_overlay_paused_time: bool = false

# 升级按钮容器（动态创建）
var _action_btn_container: VBoxContainer = null
# 当前选中的建筑ID（用于升级后刷新）
var _selected_building_id: String = ""

func _ready() -> void:
	randomize()
	_game_state = get_node_or_null("/root/GameState")
	_event_bus = get_node_or_null("/root/EventBus")
	_time_manager = get_node_or_null("/root/TimeManager")
	if _game_state != null and _game_state.has_method("ensure_intro_state"):
		_game_state.ensure_intro_state()
	_init_action_btn_container()
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
	var paused_tag: String = " ⏸" if bool(_time_manager.time_paused) else ""
	_day_label.text = "第%d天 %s%s" % [int(_time_manager.total_days) + 1, time_label, paused_tag]

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
	if _event_bus != null and not _event_bus.breeding_success.is_connected(_on_breeding_success):
		_event_bus.breeding_success.connect(_on_breeding_success)
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
		_show_building_preview(building_id)
		return
	_show_building_sidebar(building_id)

func _show_building_preview(building_id: String) -> void:
	var cost := _get_effective_building_cost(int(GameConstants.BUILDING_COSTS.get(building_id, 0)))
	var lines: PackedStringArray = []
	match building_id:
		"food_farm":
			lines.append("🌱 猫粮田【未解锁】")
			lines.append("效果：每天根据分配猫数量产出猫粮")
			lines.append("解锁费用：%d金" % cost)
		"gold_mine":
			lines.append("⛏️ 金矿【未解锁】")
			lines.append("效果：每天根据分配猫数量产出金币")
			lines.append("解锁费用：%d金" % cost)
		"nursery":
			lines.append("🍼 产房【未解锁】")
			lines.append("效果：繁育成功率从%d%%提升至%d%%" % [
				int(GameConstants.BREED_SUCCESS_WITHOUT_NURSERY * 100),
				int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100)])
			lines.append("解锁费用：%d金" % cost)
		"hospital":
			lines.append("🏥 医院【未解锁】")
			lines.append("效果：每天治愈在此工作的病猫")
			lines.append("解锁费用：%d金" % cost)
		"heart_cat_house":
			lines.append("❤️ 爱心猫窝【未解锁】")
			lines.append("效果：流浪猫来访概率 +20%")
			lines.append("解锁费用：%d金" % cost)
		"cemetery":
			lines.append("🪦 墓地【未解锁】")
			lines.append("效果：记录死亡猫咪")
			lines.append("解锁费用：%d金" % cost)
		"fortune_cat":
			lines.append("🪙 招财猫神龛【未解锁】")
			lines.append("效果：分配猫每天产出金币")
			lines.append("解锁费用：%d金" % cost)
		_:
			lines.append("%s【未解锁】" % _building_display_name(building_id))
			lines.append("解锁费用：%d金" % cost)
	if cost > 0:
		lines.append("")
		lines.append("💡 目前金币：%d" % _game_state.coins)
	_set_sidebar_text("\n".join(lines))

func _refresh_cat_nodes() -> void:
	for child: Node in _cats_root.get_children():
		child.queue_free()
	# 活猫 + 死猫（死猫在入葬前占坑位，需要显示）
	var all_cats: Array = _game_state.cats
	for cat in all_cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
			continue  # 已入葬，不再显示
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = _random_cat_spawn_position()
		cat_sprite.call("setup", cat)
		# 活猫才设建筑锚点
		if cat.status != GameConstants.LIFECYCLE_STATUS_DEAD:
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
	_selected_building_id = building_id
	var lines: PackedStringArray = []
	match building_id:
		"cat_house":
			var slots: int = _game_state.cat_house_slots
			lines.append("🏠 猫窝 (上限 %d)" % slots)
			lines.append("已住：%d / %d" % [_game_state.get_living_cats().size(), slots])
			if slots < GameConstants.MAX_CAT_HOUSE_SLOTS:
				var expand_cost: int = _get_effective_building_cost(int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60)))
				lines.append("扩建费用：%d金（当前 %d金）" % [expand_cost, _game_state.coins])
		"granary":
			var g_level: int = _game_state.get_building_level("granary")
			lines.append("🌾 粮仓 Lv%d" % g_level)
			lines.append("猫粮：%d / %d" % [_game_state.cat_food, _game_state.cat_food_cap])
			if g_level < GameConstants.GRANARY_MAX_LEVEL:
				var next_cap: int = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(g_level + 1, _game_state.cat_food_cap))
				var upgrade_cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[g_level - 1])
				lines.append("升级后粮仓上限：%d" % next_cap)
				lines.append("升级费用：%d金（当前 %d金）" % [upgrade_cost, _game_state.coins])
			else:
				lines.append("✅ 已达最高等级")
		"food_farm":
			var farm_workers: String = _get_assigned_cats_text("food_farm")
			var worker_cnt: int = _count_assigned_cats("food_farm")
			var output: int = int(GameConstants.FOOD_FARM_OUTPUT_BY_WORKERS.get(worker_cnt, 0))
			lines.append("🌱 猫粮田")
			lines.append("工作猫：%s" % farm_workers)
			lines.append("今日预计产粮：%d" % output)
		"gold_mine":
			var mine_workers: String = _get_assigned_cats_text("gold_mine")
			var mine_cnt: int = _count_assigned_cats("gold_mine")
			var mine_output: int = int(GameConstants.GOLD_MINE_OUTPUT_BY_WORKERS.get(mine_cnt, 0))
			lines.append("⛏️ 金矿")
			lines.append("工作猫：%s" % mine_workers)
			lines.append("今日预计产金：%d" % mine_output)
		"fortune_cat":
			var fortune_level: int = int(_game_state.get_building_level("fortune_cat"))
			var per_worker: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(fortune_level, 15))
			var max_workers: int = int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(fortune_level, 1))
			var fortune_workers: String = _get_assigned_cats_text("fortune_cat")
			lines.append("🪙 招财猫神龛 Lv%d" % fortune_level)
			lines.append("每日产金：%d金/只" % per_worker)
			lines.append("工作猫：%d / %d（%s）" % [_count_assigned_cats("fortune_cat"), max_workers, fortune_workers])
			if fortune_level < GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
				var fc_cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[fortune_level - 1])
				var next_max: int = int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(fortune_level + 1, max_workers))
				var next_out: int = int(GameConstants.FORTUNE_CAT_OUTPUT_PER_WORKER.get(fortune_level + 1, per_worker))
				lines.append("升Lv%d：工作上限→%d，产金→%d金/只" % [fortune_level + 1, next_max, next_out])
				lines.append("升级费用：%d金（当前 %d金）" % [fc_cost, _game_state.coins])
			else:
				lines.append("✅ 已达最高等级")
		"nursery":
			var n_slots: int = _game_state.max_breeding_slots
			lines.append("🍼 产房")
			lines.append("繁育成功率：%d%%" % int(GameConstants.BREED_SUCCESS_WITH_NURSERY * 100.0))
			lines.append("当前坑位：%d / %d" % [n_slots, GameConstants.BREEDING_SLOT_MAX])
			lines.append("繁育周期：%d 天" % GameConstants.BREEDING_SLOT_CD_DAYS)
			if n_slots < GameConstants.BREEDING_SLOT_MAX:
				var upgrade_cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[n_slots - 1])
				lines.append("升级费用：%d金（当前 %d金）" % [upgrade_cost, _game_state.coins])
		"hospital":
			lines.append("🏥 医院")
			lines.append("每天治愈在此工作的病猫")
			lines.append("病态/濒危猫咪无法工作，需送医治疗。")
			# 列出所有病猫
			var sick_cats: Array = []
			for cat in _game_state.get_living_cats():
				if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
					sick_cats.append(cat)
			if sick_cats.is_empty():
				lines.append("✅ 当前无病猫")
			else:
				lines.append("病猫列表：")
				for cat in sick_cats:
					var h_zh := "病态" if cat.health == GameConstants.HEALTH_STATE_SICK else "濒危"
					lines.append("  %s（%s）" % [cat.cat_name, h_zh])
		"heart_cat_house":
			lines.append("❤️ 爱心猫窝")
			lines.append("流浪猫来访概率提升 +20%")
		"cemetery":
			lines.append("🪦 墓地")
			# 列出未入葬的死猫
			var dead_cats: Array = []
			for cat in _game_state.cats:
				if cat != null and cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
					dead_cats.append(cat)
			if dead_cats.is_empty():
				lines.append("暂无需要入葬的猫咪。")
			else:
				lines.append("以下猫咪已离世，等待入葬（占用猫窝坑位）：")
				for cat in dead_cats:
					lines.append("  💀 %s（%s）" % [cat.cat_name, GameConstants.breed_zh(cat.breed)])
	# 分配猫咪区域（产出建筑）
	if building_id in ["fortune_cat", "food_farm", "gold_mine", "hospital", "nursery", "heart_cat_house"]:
		lines.append("")
		lines.append("── 分配猫咪（拖拽猫咪到建筑） ──")
		for cat: CatData in _game_state.get_living_cats():
			if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
				continue
			var mark: String = "✅" if str(cat.assigned_building) == building_id else "  "
			lines.append("%s %s（%s）" % [mark, cat.cat_name, GameConstants.profession_zh(cat.profession)])
	_set_sidebar_text("\n".join(lines))
	# ── 升级按钮 ──
	_add_upgrade_buttons(building_id)

func _add_upgrade_buttons(building_id: String) -> void:
	match building_id:
		"cat_house":
			var slots: int = _game_state.cat_house_slots
			if slots < GameConstants.MAX_CAT_HOUSE_SLOTS:
				var cost: int = _get_effective_building_cost(int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60)))
				var can_afford: bool = _game_state.coins >= cost
				_add_action_button(
					"🏠 扩建猫窝 -%d金（%d→%d格）" % [cost, slots, slots + 1],
					_on_upgrade_building.bind("cat_house"),
					can_afford
				)
		"granary":
			var lv: int = _game_state.get_building_level("granary")
			if lv < GameConstants.GRANARY_MAX_LEVEL:
				var cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[lv - 1])
				var next_cap: int = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(lv + 1, 0))
				var can_afford: bool = _game_state.coins >= cost
				_add_action_button(
					"🌾 升级粮仓 Lv%d→%d -%d金（上限→%d）" % [lv, lv + 1, cost, next_cap],
					_on_upgrade_building.bind("granary"),
					can_afford
				)
		"fortune_cat":
			var lv: int = _game_state.get_building_level("fortune_cat")
			if lv < GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
				var cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[lv - 1])
				var can_afford: bool = _game_state.coins >= cost
				_add_action_button(
					"🪙 升级神龛 Lv%d→%d -%d金" % [lv, lv + 1, cost],
					_on_upgrade_building.bind("fortune_cat"),
					can_afford
				)
		"nursery":
			var n_slots: int = _game_state.max_breeding_slots
			if n_slots < GameConstants.BREEDING_SLOT_MAX:
				var upgrade_cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[n_slots - 1])
				var can_afford: bool = _game_state.coins >= upgrade_cost
				_add_action_button(
					"🍼 扩建产房坑位 %d→%d（-%d金）" % [n_slots, n_slots + 1, upgrade_cost],
					_on_upgrade_building.bind("nursery"),
					can_afford
				)
		"hospital":
			# 快速将所有病猫分配进医院
			var sick_cats: Array = []
			for cat in _game_state.get_living_cats():
				if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
					sick_cats.append(cat)
			if not sick_cats.is_empty():
				_add_action_button(
					"🏥 将所有病猫送入医院（%d只）" % sick_cats.size(),
					_on_send_all_sick_to_hospital,
					true
				)
		"cemetery":
			# 一键将所有死猫入葬
			var dead_cats: Array = []
			for cat in _game_state.cats:
				if cat != null and cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
					dead_cats.append(cat)
			if not dead_cats.is_empty():
				_add_action_button(
					"🪦 入葬所有离世猫咪（%d只）" % dead_cats.size(),
					_on_bury_all_dead_cats,
					true
				)

func _on_send_all_sick_to_hospital() -> void:
	for cat in _game_state.get_living_cats():
		if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
			cat.assigned_building = "hospital"
	_refresh_all()
	_show_building_sidebar("hospital")

func _on_bury_all_dead_cats() -> void:
	var biographies: PackedStringArray = []
	for cat in _game_state.cats.duplicate():
		if cat != null and cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			var bio: String = _game_state.bury_cat(cat.id)
			if not bio.is_empty():
				biographies.append(bio)
	if not biographies.is_empty():
		_set_sidebar_text("\n\n".join(biographies))
	_refresh_all()

func _on_upgrade_building(building_id: String) -> void:
	if _game_state == null:
		return
	var success: bool = _game_state.upgrade_building(building_id)
	if success:
		_refresh_all()
		# 刷新当前 sidebar 显示
		_show_building_sidebar(building_id)

func _get_assigned_cats_text(building_id: String) -> String:
	var names: PackedStringArray = []
	for cat: CatData in _game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			names.append(cat.cat_name)
	return ", ".join(names) if not names.is_empty() else "无"

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

func _init_action_btn_container() -> void:
	# 在 CatListUI/VBox 下创建按钮容器（紧贴文字区域下方）
	var vbox: Node = get_node_or_null("UI/CatListUI/VBox")
	if vbox == null:
		return
	_action_btn_container = VBoxContainer.new()
	_action_btn_container.name = "ActionButtons"
	_action_btn_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_action_btn_container)

func _clear_action_buttons() -> void:
	if _action_btn_container == null:
		return
	for child in _action_btn_container.get_children():
		child.queue_free()

func _add_action_button(label: String, callback: Callable, enabled: bool = true) -> void:
	if _action_btn_container == null:
		return
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	_action_btn_container.add_child(btn)

func _set_sidebar_text(text: String) -> void:
	_clear_action_buttons()
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

	# ── 死亡猫：只能拖进墓地 ──────────────────────────────────────────────────
	if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
		if nearest_id == "cemetery" and _game_state.has_building("cemetery"):
			var bio: String = _game_state.bury_cat(cat.id)
			if not bio.is_empty():
				_set_sidebar_text(bio)
		_refresh_all()
		return

	# ── 病态猫：只能拖进医院 ──────────────────────────────────────────────────
	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		if nearest_id == "hospital" and _game_state.has_building("hospital"):
			cat.assigned_building = "hospital"
			_set_sidebar_text("🏥 %s 已送入医院治疗。" % cat.cat_name)
		else:
			_set_sidebar_text("⚠️ 病猫只能送入医院治疗！")
		_refresh_cat_nodes()
		return

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
		_stray_label.text = "猫窝已满，请先扩建猫窝。"
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
	_coins_label.text = "金币: %d" % _game_state.coins
	_food_label.text = "猫粮: %d/%d" % [_game_state.cat_food, _game_state.cat_food_cap]
	_refresh_time_label()

func _refresh_cat_list() -> void:
	var lines: PackedStringArray = []
	for cat in _game_state.cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
			continue
		var health_tag := ""
		if cat.status != GameConstants.LIFECYCLE_STATUS_DEAD:
			match cat.health:
				GameConstants.HEALTH_STATE_SICK:     health_tag = " 🤒"
				GameConstants.HEALTH_STATE_CRITICAL: health_tag = " 🆘"
		var dead_tag := " 💀（拖入墓地入葬）" if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD else ""
		lines.append(
			"%s | %s | %s | %s | %d天 | %s%s%s"
			% [
				cat.cat_name,
				GameConstants.sex_display(cat.sex),
				GameConstants.profession_zh(cat.profession),
				GameConstants.breed_zh(cat.breed),
				cat.age_days,
				_status_zh(cat.status),
				health_tag,
				dead_tag,
			]
		)
	if lines.is_empty():
		_cat_list_text.text = "选择你的第一只猫开始游戏。"
		return
	_cat_list_text.text = "\n".join(lines)

func _refresh_stray_ui() -> void:
	_stray_panel.visible = not _game_state.stray_cat_queue.is_empty()
	if _game_state.stray_cat_queue.is_empty():
		return
	var head: CatData = _game_state.stray_cat_queue[0]
	_stray_label.text = "流浪猫来访：%s %s %s/%s\n队列：%d/%d" % [
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
	_set_sidebar_text("一只流浪猫到访营地！")

func _on_breeding_success(child: CatData) -> void:
	_set_sidebar_text("🐱 新生！%s 在产房诞生了。" % child.cat_name)
	if _breeding_ui.has_method("refresh"):
		_breeding_ui.call("refresh")

func _status_zh(status_id: String) -> String:
	return str(STATUS_DISPLAY.get(status_id, status_id))

func _building_display_name(building_id: String) -> String:
	match building_id:
		"cat_house":
			return "猫窝"
		"granary":
			return "粮仓"
		"food_farm":
			return "猫粮田"
		"gold_mine":
			return "金矿"
		"nursery":
			return "产房"
		"hospital":
			return "医院"
		"heart_cat_house":
			return "爱心猫窝"
		"cemetery":
			return "墓地"
		"fortune_cat":
			return "招财猫"
	return building_id

func _build_starter_overlay() -> void:
	if _starter_overlay != null:
		return

	# ── 全屏半透明遮罩 ──
	var overlay := ColorRect.new()
	overlay.name = "StarterOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.06, 0.10, 0.90)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 中央主面板 ──
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980.0, 500.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -490.0
	panel.offset_top = -250.0
	panel.offset_right = 490.0
	panel.offset_bottom = 250.0
	overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)

	# ── 标题 ──
	var title := Label.new()
	title.text = "✦ 选择你的第一只猫 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	# ── 副标题 ──
	var hint := Label.new()
	hint.text = "从三只候选猫中选一只。选完后，一只异性流浪猫将很快到访营地。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	root.add_child(hint)
	_starter_hint_label = hint

	# ── 三张卡片横排 ──
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 20)
	root.add_child(choices)

	for index in GameConstants.STARTER_CHOICE_COUNT:
		var card := _build_starter_card(index)
		choices.add_child(card)

	_ui_layer.add_child(overlay)
	_starter_overlay = overlay

func _build_starter_card(index: int) -> PanelContainer:
	# ── 卡片外框 ──
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280.0, 390.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	# ── 猫咪外观预览（占据约一半高度） ──
	var preview: Control = StarterCatPreviewScript.new()
	preview.custom_minimum_size = Vector2(280.0, 170.0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(preview)
	_starter_previews.append(preview)

	# ── 猫咪信息标签 ──
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("int_as_enum_without_cast")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 13)
	inner.add_child(info)
	_starter_info_labels.append(info)

	# ── 选择按钮 ──
	var btn := Button.new()
	btn.text = "选择此猫"
	btn.custom_minimum_size = Vector2(0.0, 40.0)
	btn.pressed.connect(_on_starter_choice_pressed.bind(index))
	inner.add_child(btn)
	_starter_choice_buttons.append(btn)

	return card

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
		var btn := _starter_choice_buttons[index]
		var has_cat: bool = index < candidates.size()
		btn.disabled = not has_cat
		# 更新预览和信息标签
		if index < _starter_previews.size():
			var preview: Control = _starter_previews[index]
			if preview.has_method("setup"):
				preview.call("setup", candidates[index] if has_cat else null)
		if index < _starter_info_labels.size():
			var lbl: Label = _starter_info_labels[index]
			lbl.text = _starter_card_info_text(candidates[index]) if has_cat else ""

func _starter_card_info_text(cat: CatData) -> String:
	var gene_names: PackedStringArray = []
	for gene_id: String in cat.get_special_genes():
		var gene_info: Dictionary = GameConstants.GENE_DISPLAY_ZH.get(gene_id, {})
		var gene_name: String = str(gene_info.get("name", gene_id))
		gene_names.append(gene_name)
	var trait_text := "、".join(gene_names) if not gene_names.is_empty() else "无"
	return (
		"%s\n" % cat.cat_name
		+ "%s  %s  %s\n" % [GameConstants.sex_display(cat.sex), GameConstants.profession_zh(cat.profession), GameConstants.breed_zh(cat.breed)]
		+ "HP %.0f  攻击 %.0f\n" % [cat.base_hp, cat.base_attack]
		+ "射程 %.1f  攻速 %.2f/s\n" % [cat.base_range, cat.base_attack_speed]
		+ "特性：%s" % trait_text
	)

func _on_starter_choice_pressed(index: int) -> void:
	var chosen: CatData = _game_state.choose_starter_cat(index)
	if chosen == null:
		return
	_refresh_all()
	_refresh_starter_overlay()
	_set_sidebar_text(
		"已选择：%s\n%s流浪猫即将到访。" % [
			chosen.cat_name,
			GameConstants.sex_display(_game_state.intro_stray_target_sex),
		]
	)
