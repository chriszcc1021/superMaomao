extends Control

const CardData := preload("res://resources/CardData.gd")
const GameConstants := preload("res://data/constants.gd")
const ArtIcon := preload("res://scenes/common/ArtIcon.gd")
const UISkin := preload("res://scenes/common/UISkin.gd")

signal card_chosen(card: CardData)

@onready var _title: Label = $Panel/VBox/Title
@onready var _desc: Label = $Panel/VBox/Desc
@onready var _panel: PanelContainer = $Panel
@onready var _option_a: Button = $Panel/VBox/OptionA
@onready var _option_b: Button = $Panel/VBox/OptionB
@onready var _option_c: Button = $Panel/VBox/OptionC

var _choices: Array[CardData] = []
var _option_icons: Array[ArtIcon] = []

func _ready() -> void:
	visible = false
	_apply_skin()
	_configure_text_layout()
	_build_option_icons()
	_option_a.pressed.connect(_on_option_pressed.bind(0))
	_option_b.pressed.connect(_on_option_pressed.bind(1))
	_option_c.pressed.connect(_on_option_pressed.bind(2))

func show_choices(cards: Array[CardData], title: String, desc: String) -> void:
	_choices = cards
	_title.text = title
	_desc.text = desc
	_set_button_text(_option_a, 0)
	_set_button_text(_option_b, 1)
	_set_button_text(_option_c, 2)
	visible = true

func hide_panel() -> void:
	visible = false
	_choices.clear()

func _set_button_text(button: Button, idx: int) -> void:
	if idx >= _choices.size():
		button.disabled = true
		button.text = "-"
		return
	var card: CardData = _choices[idx]
	button.disabled = false
	var rarity_text: String = str(GameConstants.RARITY_DISPLAY_ZH.get(card.rarity, card.rarity))
	button.text = "      %s【%s】\n      %s" % [card.card_name, rarity_text, card.description]
	UISkin.apply_card_button(button, card.rarity)
	if idx < _option_icons.size():
		_option_icons[idx].setup(card.id if not card.id.is_empty() else card.card_type, card.rarity)

func _on_option_pressed(idx: int) -> void:
	if idx >= _choices.size():
		return
	card_chosen.emit(_choices[idx])

func _configure_text_layout() -> void:
	for label: Label in [_title, _desc]:
		@warning_ignore("int_as_enum_without_cast")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Button in [_option_a, _option_b, _option_c]:
		button.clip_text = true
		@warning_ignore("int_as_enum_without_cast")
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _build_option_icons() -> void:
	_option_icons.clear()
	for button: Button in [_option_a, _option_b, _option_c]:
		var icon := ArtIcon.new()
		icon.size = Vector2(50.0, 50.0)
		icon.position = Vector2(14.0, 34.0)
		button.add_child(icon)
		_option_icons.append(icon)

func _apply_skin() -> void:
	UISkin.apply_panel(_panel, true)
	UISkin.apply_label(_title, Color(1.0, 0.86, 0.42, 1.0))
	UISkin.apply_label(_desc, Color(0.94, 0.9, 0.8, 1.0))
	for button: Button in [_option_a, _option_b, _option_c]:
		UISkin.apply_card_button(button, "grey")
