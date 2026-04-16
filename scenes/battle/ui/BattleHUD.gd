extends Control

@onready var _hp_label: Label = $Panel/VBox/HpLabel
@onready var _xp_label: Label = $Panel/VBox/XpLabel
@onready var _level_label: Label = $Panel/VBox/LevelLabel
@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _cards_label: RichTextLabel = $Panel/VBox/CardsLabel

# 动态创建的可视血条
var _hp_bar: ColorRect = null
var _hp_bar_bg: ColorRect = null

const HP_BAR_WIDTH := 200.0
const HP_BAR_HEIGHT := 12.0

func _ready() -> void:
	_build_hp_bar()

func _build_hp_bar() -> void:
	# 在 HpLabel 后插入血条背景 + 前景
	var vbox: VBoxContainer = $Panel/VBox
	if vbox == null:
		return
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 1.0)
	_hp_bar_bg.custom_minimum_size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.2, 0.9, 0.25, 1.0)
	_hp_bar.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar.position = Vector2.ZERO
	_hp_bar_bg.add_child(_hp_bar)

	# 插到 HpLabel 后面（index 1）
	vbox.add_child(_hp_bar_bg)
	vbox.move_child(_hp_bar_bg, 1)

func update_stats(hp: float, hp_max: float, level: int, xp: int, xp_next: int, timer_text: String, cards_text: String) -> void:
	_hp_label.text = "生命: %.0f / %.0f" % [hp, hp_max]
	_level_label.text = "等级: %d" % level
	_xp_label.text = "小鱼干: %d / %d" % [xp, xp_next]
	_timer_label.text = timer_text
	_cards_label.text = cards_text
	_update_hp_bar(hp, hp_max)

func _update_hp_bar(hp: float, hp_max: float) -> void:
	if _hp_bar == null or _hp_bar_bg == null:
		return
	var ratio: float = clamp(hp / max(hp_max, 1.0), 0.0, 1.0)
	_hp_bar.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	# 血量低于30%变红
	if ratio <= 0.3:
		_hp_bar.color = Color(0.9, 0.15, 0.15, 1.0)
	elif ratio <= 0.6:
		_hp_bar.color = Color(0.9, 0.65, 0.1, 1.0)
	else:
		_hp_bar.color = Color(0.2, 0.9, 0.25, 1.0)
