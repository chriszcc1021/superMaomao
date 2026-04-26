extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData       := preload("res://resources/CatData.gd")
const FloatingTextScript := preload("res://scenes/common/FloatingText.gd")

const DayManagerScript := preload("res://scenes/camp/DayManager.gd")
const CampDaySummaryScript := preload("res://scenes/camp/CampDaySummary.gd")
const CampBuildingPresenterScript := preload("res://scenes/camp/CampBuildingPresenter.gd")
const CampCatListPresenterScript := preload("res://scenes/camp/CampCatListPresenter.gd")
const CampCatVisualControllerScript := preload("res://scenes/camp/CampCatVisualController.gd")
const CampAssignmentControllerScript := preload("res://scenes/camp/CampAssignmentController.gd")
const StarterOverlayControllerScript := preload("res://scenes/camp/ui/StarterOverlayController.gd")

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
	"cat_house": Vector2(220, 210),
	"granary": Vector2(395, 150),
	"food_farm": Vector2(250, 470),
	"gold_mine": Vector2(760, 150),
	"nursery": Vector2(660, 455),
	"hospital": Vector2(825, 340),
	"heart_cat_house": Vector2(465, 270),
	"cemetery": Vector2(860, 505),
	"fortune_cat": Vector2(560, 335),
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
@onready var _open_expedition_button: Button = $UI/SidePanel/VBox/OpenExpeditionButton
@onready var _breeding_ui: Control = $UI/BreedingUI
@onready var _ui_layer: CanvasLayer = $UI

var _time_manager: Node = null
var _is_night: bool = false
var _game_state: Node = null
var _event_bus: Node = null
var _day_manager: RefCounted = DayManagerScript.new()
var _day_summary = CampDaySummaryScript.new()
var _building_presenter = CampBuildingPresenterScript.new()
var _cat_list_presenter = CampCatListPresenterScript.new()
var _assignment_controller = CampAssignmentControllerScript.new()
var _cat_visual_controller = null
var _speed_btn: Button = null  # 动态创建的速度切换按钮

var _starter_overlay: Control = null
var _starter_overlay_controller = null
var _starter_choice_buttons: Array[Button] = []
var _expedition_summary_dialog: AcceptDialog = null

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
	_setup_cat_visual_controller()
	_spawn_buildings()
	_bind_signals()
	_bind_time_signals()
	_build_starter_overlay()
	_build_expedition_summary_dialog()
	_refresh_starter_overlay()
	_refresh_all()
	if _next_day_button != null:
		_next_day_button.visible = true
	_create_speed_button()
	_show_pending_expedition_summary()

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
	if _time_manager.has_signal("resource_generated") and not _time_manager.resource_generated.is_connected(_on_resource_generated):
		_time_manager.resource_generated.connect(_on_resource_generated)

func _on_night_started() -> void:
	_is_night = true
	_refresh_cat_nodes()
	_refresh_hud()

func _on_day_started() -> void:
	_is_night = false
	_refresh_cat_nodes()
	_refresh_hud()

func _on_day_boundary_crossed() -> void:
	# advance_day 已在 TimeManager 里执行完毕，直接刷新 UI
	_refresh_all()
	# 简短自动通知，不覆盖玩家正在查看的 sidebar
	_show_toast("📅 第%d天开始" % _game_state.camp_day)

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
	_day_label.text = "第%d天 %s%s" % [_game_state.camp_day, time_label, paused_tag]

func _bind_signals() -> void:
	if not _next_day_button.pressed.is_connected(_on_next_day_pressed):
		_next_day_button.pressed.connect(_on_next_day_pressed)
	if not _accept_stray_button.pressed.is_connected(_on_accept_stray_pressed):
		_accept_stray_button.pressed.connect(_on_accept_stray_pressed)
	if not _reject_stray_button.pressed.is_connected(_on_reject_stray_pressed):
		_reject_stray_button.pressed.connect(_on_reject_stray_pressed)
	if not _defer_stray_button.pressed.is_connected(_on_defer_stray_pressed):
		_defer_stray_button.pressed.connect(_on_defer_stray_pressed)
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
			instance.set("display_name", _building_presenter.display_name(building_id))
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
	if building_id == "nursery":
		_open_nursery_breeding()
		return
	_show_building_sidebar(building_id)

func _show_building_preview(building_id: String) -> void:
	_render_building_panel(_building_presenter.preview(building_id, _game_state))

func _refresh_cat_nodes() -> void:
	_cat_visual_controller.refresh()

func _setup_cat_visual_controller() -> void:
	_cat_visual_controller = CampCatVisualControllerScript.new()
	_cat_visual_controller.cat_drop_requested.connect(_on_cat_drop_requested)
	add_child(_cat_visual_controller)
	_cat_visual_controller.setup(_cats_root, _game_state, BUILDING_LAYOUT)

func _show_building_sidebar(building_id: String) -> void:
	_selected_building_id = building_id
	_render_building_panel(_building_presenter.sidebar(building_id, _game_state))

func _render_building_panel(panel: Dictionary) -> void:
	_set_sidebar_text(str(panel.get("text", "")))
	for action: Dictionary in panel.get("actions", []):
		_add_building_action_button(action)

func _add_building_action_button(action: Dictionary) -> void:
	var label: String = str(action.get("label", ""))
	var enabled: bool = bool(action.get("enabled", true))
	var action_name: String = str(action.get("action", ""))
	if action_name == CampBuildingPresenterScript.ACTION_BUILD:
		_add_action_button(label, _on_build_building.bind(str(action.get("building_id", ""))), enabled)
	elif action_name == CampBuildingPresenterScript.ACTION_UPGRADE:
		_add_action_button(label, _on_upgrade_building.bind(str(action.get("building_id", ""))), enabled)
	elif action_name == CampBuildingPresenterScript.ACTION_OPEN_NURSERY:
		_add_action_button(label, _open_nursery_breeding, enabled)
	elif action_name == CampBuildingPresenterScript.ACTION_SEND_SICK_TO_HOSPITAL:
		_add_action_button(label, _on_send_all_sick_to_hospital, enabled)
	elif action_name == CampBuildingPresenterScript.ACTION_BURY_DEAD_CATS:
		_add_action_button(label, _on_bury_all_dead_cats, enabled)

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

func _on_build_building(building_id: String) -> void:
	if _game_state == null:
		return
	var ok: bool = _game_state.build_building(building_id)
	if ok:
		_spawn_buildings()  # 刷新建筑外观（半透明→正常）
		_refresh_all()
		_show_building_sidebar(building_id)
	else:
		_set_sidebar_text("❌ 建造失败（金币不足或已建造）")

func _on_upgrade_building(building_id: String) -> void:
	if _game_state == null:
		return
	var success: bool = _game_state.upgrade_building(building_id)
	if success:
		_refresh_all()
		# 刷新当前 sidebar 显示
		_show_building_sidebar(building_id)

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

func _open_nursery_breeding() -> void:
	_show_building_sidebar("nursery")
	if _breeding_ui == null:
		return
	if _breeding_ui.has_method("open_for_building"):
		_breeding_ui.call("open_for_building")
		return
	_breeding_ui.visible = true
	if _breeding_ui.has_method("refresh"):
		_breeding_ui.call("refresh")

func _on_cat_drop_requested(cat: CatData, world_pos: Vector2) -> void:
	var result: Dictionary = _assignment_controller.handle_cat_drop(cat, world_pos, _game_state, BUILDING_LAYOUT)
	if result.has("sidebar_text"):
		_set_sidebar_text(str(result["sidebar_text"]))
	if bool(result.get("open_nursery", false)):
		_open_nursery_breeding()
	if bool(result.get("refresh_all", false)):
		_refresh_all()
	elif bool(result.get("refresh_cat_nodes", false)):
		_refresh_cat_nodes()

func _on_next_day_pressed() -> void:
	var summary := _run_day_advance()
	_refresh_all()
	_set_sidebar_text(summary)

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

func _on_open_expedition_pressed() -> void:
	if _game_state == null:
		return
	if bool(_game_state.expedition_active):
		var active_scene_manager: Node = get_node_or_null("/root/SceneManager")
		if active_scene_manager != null:
			active_scene_manager.go_to_expedition_map()
			return
		get_tree().change_scene_to_file("res://scenes/expedition/ExpeditionMapUI.tscn")
		return
	if bool(_game_state.starter_selection_pending):
		_set_sidebar_text("请先选择第一只猫，再开始远征。")
		return
	if _get_expedition_candidates().is_empty():
		_set_sidebar_text("暂无可出征猫咪。出征需要成年、健康且未远征过的猫。")
		return
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.go_to_expedition_map()
		return
	get_tree().change_scene_to_file("res://scenes/expedition/ExpeditionMapUI.tscn")

func _refresh_all() -> void:
	_refresh_hud()
	_refresh_cat_list()
	_refresh_cat_nodes()
	_refresh_stray_ui()
	_refresh_starter_overlay()
	_refresh_expedition_button()

func _refresh_hud() -> void:
	_coins_label.text = "金币: %d" % _game_state.coins
	_food_label.text = "猫粮: %d/%d" % [_game_state.cat_food, _game_state.cat_food_cap]
	_refresh_time_label()
	# 速度按钮防丢失：如果引用失效则重建
	if not is_instance_valid(_speed_btn):
		_speed_btn = null
		_create_speed_button()
	elif _time_manager != null:
		_speed_btn.text = _format_speed_text(_time_manager.time_speed)

func _refresh_cat_list() -> void:
	_cat_list_presenter.refresh(_cat_list_text, _game_state)

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

func _refresh_expedition_button() -> void:
	if _open_expedition_button == null:
		return
	if _game_state == null:
		_open_expedition_button.disabled = true
		return
	_open_expedition_button.disabled = (not bool(_game_state.expedition_active)) and (bool(_game_state.starter_selection_pending) or _get_expedition_candidates().is_empty())

func _get_expedition_candidates() -> Array[CatData]:
	if _game_state == null:
		return []
	if _game_state.has_method("get_expedition_candidates"):
		return _game_state.get_expedition_candidates()
	var candidates: Array[CatData] = []
	for cat: CatData in _game_state.get_living_cats():
		if cat != null and cat.status != GameConstants.LIFECYCLE_STATUS_RETIRED and cat.health == GameConstants.HEALTH_STATE_HEALTHY:
			candidates.append(cat)
	return candidates

func _build_expedition_summary_dialog() -> void:
	if _ui_layer == null or _expedition_summary_dialog != null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "远征结算"
	dialog.dialog_text = ""
	dialog.exclusive = true
	dialog.unresizable = true
	_ui_layer.add_child(dialog)
	_expedition_summary_dialog = dialog

func _show_pending_expedition_summary() -> void:
	if _game_state == null:
		return
	var summary := str(_game_state.consume_pending_expedition_summary())
	if summary.is_empty():
		return
	_set_sidebar_text(summary)
	if _expedition_summary_dialog != null:
		_expedition_summary_dialog.dialog_text = summary
		_expedition_summary_dialog.popup_centered(Vector2i(460, 220))

func _build_starter_overlay() -> void:
	if _starter_overlay_controller != null:
		return
	_starter_overlay_controller = StarterOverlayControllerScript.new()
	_starter_overlay_controller.starter_choice_pressed.connect(_on_starter_choice_pressed)
	add_child(_starter_overlay_controller)
	_starter_overlay_controller.setup(_ui_layer, _game_state, _time_manager)
	_sync_starter_overlay_refs()

func _refresh_starter_overlay() -> void:
	if _starter_overlay_controller == null:
		return
	_starter_overlay_controller.refresh()
	_sync_starter_overlay_refs()

func _sync_starter_overlay_refs() -> void:
	if _starter_overlay_controller == null:
		return
	_starter_overlay = _starter_overlay_controller.get_overlay()
	_starter_choice_buttons = _starter_overlay_controller.choice_buttons

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

# ── 日结算（手动推进）：快照 → advance_day → 对比 → 返回事件日志 ──────────────
func _run_day_advance() -> String:
	return _day_summary.run(_game_state, _event_bus, _day_manager)

# ── 速度切换按钮（动态创建，加在 NextDayButton 旁边）────────────────────────
func _create_speed_button() -> void:
	if _time_manager == null:
		return
	var hbox: HBoxContainer = get_node_or_null("UI/CampHUD/HBox")
	if hbox == null:
		return
	var btn := Button.new()
	btn.text = "1×"
	btn.custom_minimum_size = Vector2(48, 0)
	btn.tooltip_text = "切换时间速率 (1×/2×/5×/10×)"
	btn.pressed.connect(func() -> void:
		var new_speed: float = _time_manager.cycle_speed()
		btn.text = _format_speed_text(new_speed)
	)
	hbox.add_child(btn)
	_speed_btn = btn

func _format_speed_text(speed: float) -> String:
	var speed_text := str(snappedf(speed, 0.1))
	if speed_text.ends_with(".0"):
		speed_text = speed_text.left(speed_text.length() - 2)
	return "%s×" % speed_text

# ── 轻量提示（status_label 短暂显示，不覆盖 sidebar）────────────────────────
func _show_toast(text: String) -> void:
	# 用 stray_label 同一套时间后消失的逻辑实在麻烦，
	# 暂时只在 day_label 区域旁打印一个 1 秒闪过的 Label
	# 简单实现：直接更新 _cat_list_text 的最后一行（如果当前没在看 sidebar）
	# TODO: 如果后续要做 Toast 系统可单独提取
	pass  # auto day advance 只静默刷新 HUD，不抢占 sidebar

func _on_resource_generated(building_id: String, resource_type: String, amount: int) -> void:
	if amount <= 0 or not BUILDING_LAYOUT.has(building_id):
		return
	for i in amount:
		_spawn_resource_float(building_id, resource_type, i)

func _spawn_resource_float(building_id: String, resource_type: String, index: int) -> void:
	var text := "+1"
	var color := Color.WHITE
	match resource_type:
		"food":
			text = "猫粮 +1"
			color = Color(0.72, 0.95, 0.52)
		"coins":
			text = "金币 +1"
			color = Color(1.0, 0.88, 0.32)
		_:
			text = "+1"

	var ft := FloatingTextScript.new()
	ft._text = text
	ft._color = color
	var base_pos: Vector2 = BUILDING_LAYOUT[building_id]
	ft.position = base_pos + Vector2(
		randf_range(-16.0, 16.0),
		randf_range(-42.0, -18.0) - float(index) * 6.0
	)
	_buildings_root.add_child(ft)
