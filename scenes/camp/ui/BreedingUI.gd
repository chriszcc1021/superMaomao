extends PanelContainer

const BreedingSystem := preload("res://scenes/camp/BreedingSystem.gd")
const CatData := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")

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
var _available_cats: Array = []
var _male_count: int = 0
var _active_slot_idx: int = -1

func _ready() -> void:
	visible = false
	_bind_static_options()
	_father_option.item_selected.connect(_on_selection_changed)
	_mother_option.item_selected.connect(_on_selection_changed)
	_breed_option.item_selected.connect(_on_selection_changed)
	_profession_option.item_selected.connect(_on_selection_changed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_close_button.pressed.connect(_close_ui)
	_form_panel.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()

func bind_game_state(state_node: Node) -> void:
	_game_state = state_node
	refresh()

func open_for_building() -> void:
	visible = true
	refresh()
	var slot_idx := _first_available_slot_idx()
	if slot_idx >= 0:
		_open_form_for_slot(slot_idx)
	else:
		_form_panel.visible = false
		_status_label.text = "No breeding slot is currently free."

func refresh() -> void:
	if _game_state == null:
		return
	_refresh_slot_cards()
	_refresh_upgrade_button()
	_available_cats = _collect_breedable_cats()

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
	title.text = "Slot %d" % (idx + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if slot.get("active", false):
		var father: CatData = _game_state.find_cat(str(slot.get("father_id", "")))
		var mother: CatData = _game_state.find_cat(str(slot.get("mother_id", "")))
		var father_name := str(father.cat_name) if father != null else "Unknown"
		var mother_name := str(mother.cat_name) if mother != null else "Unknown"

		var info := Label.new()
		info.text = "M %s\nF %s" % [father_name, mother_name]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(info)

		var days_label := Label.new()
		days_label.text = "%d day(s) left" % int(slot.get("days_remaining", 0))
		days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(days_label)
	else:
		var empty_label := Label.new()
		empty_label.text = "Empty slot"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_label)

		var btn := Button.new()
		btn.text = "Start breeding"
		btn.pressed.connect(func() -> void: _open_form_for_slot(idx))
		vbox.add_child(btn)

	return card

func _open_form_for_slot(slot_idx: int) -> void:
	_active_slot_idx = slot_idx
	_form_panel.visible = true
	_available_cats = _collect_breedable_cats()
	_refresh_parent_options()
	_status_label.text = "Choose a father and mother for slot %d." % (slot_idx + 1)

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
	var males: Array = []
	var females: Array = []
	for cat in _available_cats:
		if cat.sex == GameConstants.SEX_MALE:
			males.append(cat)
		else:
			females.append(cat)
	for cat in males:
		var label := "%s [%s/%s]" % [cat.cat_name, GameConstants.profession_zh(cat.profession), GameConstants.breed_zh(cat.breed)]
		_father_option.add_item(label, males.find(cat))
	for cat in females:
		var label := "%s [%s/%s]" % [cat.cat_name, GameConstants.profession_zh(cat.profession), GameConstants.breed_zh(cat.breed)]
		_mother_option.add_item(label, females.find(cat))
	_available_cats = males + females
	_male_count = males.size()
	_confirm_button.disabled = males.is_empty() or females.is_empty()
	if males.is_empty() or females.is_empty():
		_prediction_label.text = "Need at least one male cat and one female cat."
		return
	_update_prediction()

func _on_selection_changed(_index: int) -> void:
	_update_prediction()

func _update_prediction() -> void:
	var father = _selected_parent(_father_option)
	var mother = _selected_parent(_mother_option)
	if father == null or mother == null:
		_prediction_label.text = "Select both parents first."
		return
	if father == mother:
		_prediction_label.text = "The two parents must be different cats."
		return
	var predicted = _breeding_system.predict_range(father, mother, _selected_child_breed(), _selected_child_profession(), 100)
	_prediction_label.text = "Predicted child range:\nHP %.0f - %.0f  ATK %.0f - %.0f\nASPD %.2f - %.2f  RNG %.1f - %.1f\nCRIT %.0f%% - %.0f%%" % [
		predicted.hp_min, predicted.hp_max,
		predicted.atk_min, predicted.atk_max,
		predicted.aspd_min, predicted.aspd_max,
		predicted.range_min, predicted.range_max,
		predicted.crit_min * 100.0, predicted.crit_max * 100.0
	]

func _on_confirm_pressed() -> void:
	if _active_slot_idx < 0:
		return
	var father = _selected_parent(_father_option)
	var mother = _selected_parent(_mother_option)
	if father == null or mother == null:
		_status_label.text = "Select both parents first."
		return
	if father == mother:
		_status_label.text = "The two parents must be different cats."
		return
	if not _game_state.has_free_cat_house_slot():
		_status_label.text = "The cat house is full."
		return

	var ok: bool = _game_state.start_breeding_in_slot(_active_slot_idx, father.id, mother.id, _selected_child_breed(), _selected_child_profession())
	if ok:
		_status_label.text = "Breeding started. The kitten arrives in %d day(s)." % GameConstants.BREEDING_SLOT_CD_DAYS
		_form_panel.visible = false
		_active_slot_idx = -1
		refresh()
	else:
		_status_label.text = "Breeding could not be started."

func _refresh_upgrade_button() -> void:
	if _game_state == null:
		return
	var slots: int = _game_state.max_breeding_slots
	var max_slots: int = GameConstants.BREEDING_SLOT_MAX
	if slots >= max_slots:
		_upgrade_button.text = "Slots maxed"
		_upgrade_button.disabled = true
		return
	var cost_idx: int = slots - 1
	var cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[cost_idx])
	_upgrade_button.text = "Upgrade nursery +1 slot (%d coins)" % cost
	_upgrade_button.disabled = _game_state.coins < cost

func _on_upgrade_pressed() -> void:
	if _game_state == null:
		return
	var ok: bool = _game_state.upgrade_building("nursery")
	if ok:
		_status_label.text = "Nursery upgraded. Total slots: %d." % _game_state.max_breeding_slots
		refresh()
	else:
		_status_label.text = "Cannot upgrade the nursery right now."

func _collect_breedable_cats() -> Array:
	if _game_state == null:
		return []
	if _game_state.has_method("get_breedable_cats"):
		return _game_state.get_breedable_cats()
	var result: Array = []
	for cat in _game_state.cats:
		if cat == null:
			continue
		if cat.age_days < GameConstants.KITTEN_DAYS:
			continue
		if not cat.can_breed():
			continue
		result.append(cat)
	return result

func _selected_parent(option: OptionButton) -> Object:
	if option.selected < 0:
		return null
	var is_father := option == _father_option
	if is_father:
		var idx: int = clampi(option.selected, 0, _male_count - 1)
		return _available_cats[idx] if idx < _available_cats.size() else null
	var female_count: int = maxi(_available_cats.size() - _male_count, 0)
	var female_index: int = clampi(option.selected, 0, maxi(female_count - 1, 0))
	var idx: int = _male_count + female_index
	return _available_cats[idx] if idx < _available_cats.size() else null

func _selected_child_breed() -> String:
	return "" if _breed_option.selected < 0 else str(_breed_option.get_item_metadata(_breed_option.selected))

func _selected_child_profession() -> String:
	return "" if _profession_option.selected < 0 else str(_profession_option.get_item_metadata(_profession_option.selected))

func _first_available_slot_idx() -> int:
	if _game_state == null:
		return -1
	for i in _game_state.max_breeding_slots:
		var slot: Dictionary = _game_state.get_breeding_slot(i)
		if not bool(slot.get("active", false)):
			return i
	return -1

func _close_ui() -> void:
	_form_panel.visible = false
	_active_slot_idx = -1
	visible = false
