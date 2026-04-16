extends Control

const CardData := preload("res://resources/CardData.gd")
const GameConstants := preload("res://data/constants.gd")

signal card_chosen(card: CardData)

@onready var _title: Label = $Panel/VBox/Title
@onready var _desc: Label = $Panel/VBox/Desc
@onready var _option_a: Button = $Panel/VBox/OptionA
@onready var _option_b: Button = $Panel/VBox/OptionB
@onready var _option_c: Button = $Panel/VBox/OptionC

var _choices: Array[CardData] = []

func _ready() -> void:
	visible = false
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
		button.text = "—"
		return
	var card: CardData = _choices[idx]
	button.disabled = false
	var rarity_text: String = str(GameConstants.RARITY_DISPLAY_ZH.get(card.rarity, card.rarity))
	button.text = "%s【%s】\n%s" % [card.card_name, rarity_text, card.description]

func _on_option_pressed(idx: int) -> void:
	if idx >= _choices.size():
		return
	card_chosen.emit(_choices[idx])
