extends Control

@onready var _hp_label: Label = $Panel/VBox/HpLabel
@onready var _xp_label: Label = $Panel/VBox/XpLabel
@onready var _level_label: Label = $Panel/VBox/LevelLabel
@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _cards_label: RichTextLabel = $Panel/VBox/CardsLabel

func update_stats(hp: float, hp_max: float, level: int, xp: int, xp_next: int, timer_text: String, cards_text: String) -> void:
	_hp_label.text = "生命: %.0f / %.0f" % [hp, hp_max]
	_level_label.text = "等级: %d" % level
	_xp_label.text = "小鱼干: %d / %d" % [xp, xp_next]
	_timer_label.text = timer_text
	_cards_label.text = cards_text
