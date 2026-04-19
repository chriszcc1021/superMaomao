extends PanelContainer

# BreedingSystem 已有 class_name，全局可用，无需 preload

@onready var _slots_container: HBoxContainer = $VBox/SlotsContainer
@onready var _form_panel: PanelContainer = $VBox/FormPanel
@onready var _father_option: OptionButton = $VBox/FormPanel/FormVBox/FatherRow/FatherOption
@onready var _mother_option: OptionButton = $VBox/FormPanel/FormVBox/MotherRow/MotherOption
@onready var _breed_option: OptionButton = $VBox/FormPanel/FormVBox/BreedRow/BreedOption
@onready var _profession_option: OptionButton = $VBox/FormPanel/FormVBox/ProfessionRow/ProfessionOption
@onready var _prediction_label: RichTextLabel = $VBox/FormPanel/FormVBox/PredictionLabel
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _confirm_button: Button = $VBox/Buttons/ConfirmButton
@onready var _upgrade_button: Button = $VBox/Buttons/UpgradeButton
@onready var _close_button: Button = $VBox/Buttons/CloseButton

var _game_state: Node = null
var _breeding_system := BreedingSystem.new()
var _available_cats: Array[CatData] = []
var _active_slot_idx: int = -1  # 当前正在配置哪个坑位

func _ready() -> void:
	visible = false
	_bind_static_options()
	_father_option.item_selected.connect(_on_selection_changed)
	_mother_option.item_selected.connect(_on_selection_changed)
	_breed_option.item_selected.connect(_on_selection_changed)
	_profession_option.item_selected.connect(_on_selection_changed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_close_button.pressed.connect(func() -> void: visible = false)
	_form_panel.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()

func bind_game_state(state_node: Node) -> void:
	_game_state = state_node
	refresh()

# ─── 公共刷新入口 ──────────────────────────────────────────────────────────────

func refresh() -> void:
	if _game_state == null:
		return
	_refresh_slot_cards()
	_refresh_upgrade_button()
	_available_cats = _collect_breedable_cats()

# ─── 坑位卡片 ─────────────────────────────────────────────────────────────────

func _refresh_slot_cards() -> void:
	for child in _slots_container.get_children():
		child.queue_free()

	for i in _game_state.max_breeding_slots:
		var slot: Dictionary = _game_state.get_breeding_slot(i)
		_slots_container.add_child(_make_slot_card(i, slot))

func _make_slot_card(idx: int, slot: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 100)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var title := Label.new()
	title.text = "坑位 %d" % (idx + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if slot.get("active", false):
		var father := _game_state.find_cat(str(slot.get("father_id", "")))
		var mother := _game_state.find_cat(str(slot.get("mother_id", "")))
		var father_name := father.cat_name if father != null else "未知"
		var mother_name := mother.cat_name if mother != null else "未知"

		var info := Label.new()
		info.text = "♂ %s\n♀ %s" % [father_name, mother_name]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(info)

		var days_label := Label.new()
		days_label.text = "剩余 %d 天" % int(slot.get("days_remaining", 0))
		days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(days_label)
	else:
		var empty_label := Label.new()
		empty_label.text = "空坑"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_label)

		var btn := Button.new()
		btn.text = "开始繁育"
		btn.pressed.connect(func() -> void: _open_form_for_slot(idx))
		vbox.add_child(btn)

	return card

# ─── 繁育表单 ─────────────────────────────────────────────────────────────────

func _open_form_for_slot(slot_idx: int) -> void:
	_active_slot_idx = slot_idx
	_form_panel.visible = true
	_available_cats = _collect_breedable_cats()
	_refresh_parent_options()
	_status_label.text = "坑位 %d：选择父本与母本" % (slot_idx + 1)

func _bind_static_options() -> void:
	_breed_option.clear()
	for breed_id: String in GameConstants.BREED_MODIFIERS.keys():
		_breed_option.add_item(GameConstants.breed_zh(breed_id))
		_breed_option.set_item_metadata(_breed_option.item_count - 1, breed_id)
	_profession_option.clear()
	for profession_id: String in GameConstants.PROFESSION_BASE.keys():
		_profession_option.add_item(GameConstants.profession_zh(profession_id))
		_profession_option.set_item_metadata(_profession_option.item_count - 1, profession_id)

func _refresh_parent_options() -> void:
	_father_option.clear()
	_mother_option.clear()
	for i in _available_cats.size():
		var cat: CatData = _available_cats[i]
		var label := "%s [%s/%s]" % [cat.cat_name, GameConstants.profession_zh(cat.profession), GameConstants.breed_zh(cat.breed)]
		_father_option.add_item(label, i)
		_mother_option.add_item(label, i)
	_confirm_button.disabled = _available_cats.size() < 2
	if _available_cats.size() < 2:
		_prediction_label.text = "需要至少两只成年猫才能繁育。"
		return
	_update_prediction()

func _on_selection_changed(_index: int) -> void:
	_update_prediction()

func _update_prediction() -> void:
	var father := _selected_parent(_father_option)
	var mother := _selected_parent(_mother_option)
	if father == null or mother == null:
		_prediction_label.text = "请选择父本与母本。"
		return
	if father == mother:
		_prediction_label.text = "父本与母本不能是同一只猫。"
		return
	var predicted := _breeding_system.predict_range(father, mother, _selected_child_breed(), _selected_child_profession(), 100)
	_prediction_label.text = "预测子代属性范围：\n生命：%.0f - %.0f　攻击：%.0f - %.0f\n攻速：%.2f - %.2f　射程：%.1f - %.1f\n暴击：%.0f%% - %.0f%%" % [
		predicted.hp_min, predicted.hp_max,
		predicted.atk_min, predicted.atk_max,
		predicted.aspd_min, predicted.aspd_max,
		predicted.range_min, predicted.range_max,
		predicted.crit_min * 100.0, predicted.crit_max * 100.0
	]

func _on_confirm_pressed() -> void:
	if _active_slot_idx < 0:
		return
	var father := _selected_parent(_father_option)
	var mother := _selected_parent(_mother_option)
	if father == null or mother == null:
		_status_label.text = "请选择父本与母本。"
		return
	if father == mother:
		_status_label.text = "父本与母本不能相同。"
		return
	if not _game_state.has_free_cat_house_slot():
		_status_label.text = "猫窝已满，无法繁育。"
		return

	var ok: bool = _game_state.start_breeding_in_slot(_active_slot_idx, father.id, mother.id, _selected_child_breed(), _selected_child_profession())
	if ok:
		_status_label.text = "繁育启动！%d 天后诞生。" % GameConstants.BREEDING_SLOT_CD_DAYS
		_form_panel.visible = false
		_active_slot_idx = -1
		refresh()
	else:
		_status_label.text = "本次配对失败（概率未触发），请再试。"

# ─── 产房升级 ─────────────────────────────────────────────────────────────────

func _refresh_upgrade_button() -> void:
	if _game_state == null:
		return
	var slots := _game_state.max_breeding_slots
	var max_s := GameConstants.BREEDING_SLOT_MAX
	if slots >= max_s:
		_upgrade_button.text = "坑位已满"
		_upgrade_button.disabled = true
		return
	var cost_idx := slots - 1
	var cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[cost_idx])
	_upgrade_button.text = "升级产房 +1坑（%d金）" % cost
	_upgrade_button.disabled = _game_state.coins < cost

func _on_upgrade_pressed() -> void:
	if _game_state == null:
		return
	var ok: bool = _game_state.upgrade_building("nursery")
	if ok:
		_status_label.text = "产房升级！现有 %d 个坑位。" % _game_state.max_breeding_slots
		refresh()
	else:
		_status_label.text = "金币不足或已达上限。"

# ─── 辅助 ─────────────────────────────────────────────────────────────────────

func _collect_breedable_cats() -> Array[CatData]:
	var result: Array[CatData] = []
	if _game_state == null:
		return result
	for cat: CatData in _game_state.cats:
		if cat == null or cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS or not cat.can_breed():
			continue
		result.append(cat)
	return result

func _selected_parent(option: OptionButton) -> CatData:
	if _available_cats.is_empty() or option.selected < 0:
		return null
	var idx := clampi(option.selected, 0, _available_cats.size() - 1)
	return _available_cats[idx]

func _selected_child_breed() -> String:
	return "" if _breed_option.selected < 0 else str(_breed_option.get_item_metadata(_breed_option.selected))

func _selected_child_profession() -> String:
	return "" if _profession_option.selected < 0 else str(_profession_option.get_item_metadata(_profession_option.selected))
