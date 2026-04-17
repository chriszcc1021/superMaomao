extends PanelContainer

const BreedingSystem := preload("res://scenes/camp/BreedingSystem.gd")

@onready var _father_option: OptionButton = $VBox/FatherRow/FatherOption
@onready var _mother_option: OptionButton = $VBox/MotherRow/MotherOption
@onready var _breed_option: OptionButton = $VBox/BreedRow/BreedOption
@onready var _profession_option: OptionButton = $VBox/ProfessionRow/ProfessionOption
@onready var _father_genes_label: RichTextLabel = $VBox/GeneRow/FatherGenes
@onready var _mother_genes_label: RichTextLabel = $VBox/GeneRow/MotherGenes
@onready var _prediction_label: RichTextLabel = $VBox/PredictionLabel
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _confirm_button: Button = $VBox/Buttons/ConfirmButton
@onready var _close_button: Button = $VBox/Buttons/CloseButton

var _game_state: Node = null
var _breeding_system := BreedingSystem.new()
var _available_cats: Array[CatData] = []

func _ready() -> void:
	visible = false
	_bind_static_options()
	_father_option.item_selected.connect(_on_selection_changed)
	_mother_option.item_selected.connect(_on_selection_changed)
	_breed_option.item_selected.connect(_on_selection_changed)
	_profession_option.item_selected.connect(_on_selection_changed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_close_button.pressed.connect(func() -> void: visible = false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_parent_options()

func bind_game_state(state_node: Node) -> void:
	_game_state = state_node
	_refresh_parent_options()

func _bind_static_options() -> void:
	_breed_option.clear()
	for breed_id: String in GameConstants.BREED_MODIFIERS.keys():
		_breed_option.add_item(_breed_zh(breed_id))
		_breed_option.set_item_metadata(_breed_option.item_count - 1, breed_id)
	_profession_option.clear()
	for profession_id: String in GameConstants.PROFESSION_BASE.keys():
		_profession_option.add_item(_profession_zh(profession_id))
		_profession_option.set_item_metadata(_profession_option.item_count - 1, profession_id)

func _refresh_parent_options() -> void:
	_father_option.clear()
	_mother_option.clear()
	_available_cats = _collect_breedable_cats()
	for i in _available_cats.size():
		var cat: CatData = _available_cats[i]
		var label := "%s，%s/%s" % [cat.cat_name, _profession_zh(cat.profession), _breed_zh(cat.breed)]
		_father_option.add_item(label, i)
		_mother_option.add_item(label, i)
	_confirm_button.disabled = _available_cats.size() < 2
	if _available_cats.size() < 2:
		_status_label.text = "至少需要两只可繁育成年猫。"
		_father_genes_label.text = "父本基因：\n无"
		_mother_genes_label.text = "母本基因：\n无"
		_prediction_label.text = "请选择父本与母本。"
		return
	_prediction_from_selection()

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

func _on_selection_changed(_index: int) -> void:
	_prediction_from_selection()

func _prediction_from_selection() -> void:
	var father := _selected_parent(_father_option)
	var mother := _selected_parent(_mother_option)
	if father == null or mother == null:
		_prediction_label.text = "请选择父本与母本。"
		return
	_father_genes_label.text = _format_gene_block("父本", father)
	_mother_genes_label.text = _format_gene_block("母本", mother)
	if father == mother:
		_prediction_label.text = "父本与母本不能是同一只猫。"
		return
	var predicted := _breeding_system.predict_range(father, mother, _selected_child_breed(), _selected_child_profession(), 100)
	_prediction_label.text = "生命：%.1f - %.1f\n攻击：%.1f - %.1f\n攻速：%.2f - %.2f\n移速：%.1f - %.1f\n射程：%.1f - %.1f\n暴击：%.1f%% - %.1f%%" % [
		predicted.hp_min, predicted.hp_max,
		predicted.atk_min, predicted.atk_max,
		predicted.aspd_min, predicted.aspd_max,
		predicted.move_min, predicted.move_max,
		predicted.range_min, predicted.range_max,
		predicted.crit_min * 100.0, predicted.crit_max * 100.0
	]

func _on_confirm_pressed() -> void:
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
	var chance := GameConstants.BREED_SUCCESS_WITH_NURSERY if _game_state.has_building("nursery") else GameConstants.BREED_SUCCESS_WITHOUT_NURSERY
	# love_spreader：父本或母本有此基因，繁育成功率+15%
	if _cat_has_gene(father, "love_spreader") or _cat_has_gene(mother, "love_spreader"):
		chance = min(1.0, chance + 0.15)
	if randf() > chance:
		_status_label.text = "今日繁育失败。"
		return
	var child := _breeding_system.breed(father, mother, _selected_child_breed(), _selected_child_profession())
	if child == null:
		_status_label.text = "繁育失败：子代参数缺失。"
		return
	father.breed_count += 1
	mother.breed_count += 1
	_game_state.add_cat(child)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.breeding_success.emit(child)
	_status_label.text = "繁育成功：%s" % child.cat_name
	_refresh_parent_options()

func _format_gene_block(title: String, cat: CatData) -> String:
	return "%s基因\n头:%s 耳:%s 眼色:%s 眼型:%s\n主毛:%s 辅毛:%s 花纹:%s 尾:%s\n槽位:[%s] [%s] [%s]" % [
		title,
		cat.gene_head, cat.gene_ear, cat.gene_eye_color, cat.gene_eye_shape,
		cat.gene_fur_main, cat.gene_fur_accent, cat.gene_pattern, cat.gene_tail,
		_slot_text(cat.gene_slot_1), _slot_text(cat.gene_slot_2), _slot_text(cat.gene_slot_3)
	]

func _slot_text(value: String) -> String:
	return "空槽" if value.is_empty() else value

func _selected_child_breed() -> String:
	return "" if _breed_option.selected < 0 else str(_breed_option.get_item_metadata(_breed_option.selected))

func _selected_child_profession() -> String:
	return "" if _profession_option.selected < 0 else str(_profession_option.get_item_metadata(_profession_option.selected))

func _selected_parent(option: OptionButton) -> CatData:
	if _available_cats.is_empty():
		return null
	var idx := clampi(option.selected, 0, _available_cats.size() - 1)
	return _available_cats[idx]

func _profession_zh(profession_id: String) -> String:
	return str(GameConstants.PROFESSION_DISPLAY_ZH.get(profession_id, profession_id))

func _breed_zh(breed_id: String) -> String:
	return str(GameConstants.BREED_DISPLAY_ZH.get(breed_id, breed_id))

func _cat_has_gene(cat: CatData, gene_id: String) -> bool:
	return gene_id in [str(cat.gene_slot_1), str(cat.gene_slot_2), str(cat.gene_slot_3)]
