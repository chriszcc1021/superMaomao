extends PanelContainer

const UISkin := preload("res://scenes/common/UISkin.gd")

@onready var _coins_label: Label = $HBox/CoinsLabel
@onready var _food_label: Label = $HBox/CatFoodLabel
@onready var _day_label: Label = $HBox/DayLabel
@onready var _next_day_button: Button = $HBox/NextDayButton

func _ready() -> void:
	UISkin.apply_panel(self)
	for label: Label in [_coins_label, _food_label, _day_label]:
		UISkin.apply_label(label)
	UISkin.apply_button(_next_day_button, Color(0.64, 0.78, 0.42, 1.0))
