extends Control

const UISkin := preload("res://scenes/common/UISkin.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _hp_label: Label = $Panel/VBox/HpLabel
@onready var _xp_label: Label = $Panel/VBox/XpLabel
@onready var _level_label: Label = $Panel/VBox/LevelLabel
@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _cards_label: RichTextLabel = $Panel/VBox/CardsLabel

var _hp_bar: ColorRect = null
var _hp_bar_bg: ColorRect = null
var _xp_bar: ColorRect = null
var _xp_bar_bg: ColorRect = null

const STAT_BAR_WIDTH := 220.0
const HP_BAR_HEIGHT := 12.0
const XP_BAR_HEIGHT := 8.0
const CARDS_LABEL_MIN_SIZE := Vector2(310.0, 96.0)

func _ready() -> void:
	_apply_skin()
	_build_stat_bars()
	_cards_label.custom_minimum_size = CARDS_LABEL_MIN_SIZE
	_cards_label.fit_content = false
	_cards_label.scroll_active = true
	@warning_ignore("int_as_enum_without_cast")
	_cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_skin() -> void:
	UISkin.apply_panel(_panel, true)
	for label: Label in [_hp_label, _xp_label, _level_label, _timer_label]:
		UISkin.apply_label(label, Color(0.98, 0.92, 0.78, 1.0))
	UISkin.apply_rich_text(_cards_label, true)

func _build_stat_bars() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	if vbox == null:
		return
	_hp_bar_bg = _create_bar_bg(HP_BAR_HEIGHT)
	_hp_bar = _create_bar(Color(0.2, 0.9, 0.25, 1.0), HP_BAR_HEIGHT)
	_hp_bar_bg.add_child(_hp_bar)
	vbox.add_child(_hp_bar_bg)
	vbox.move_child(_hp_bar_bg, vbox.get_children().find(_hp_label) + 1)

	_xp_bar_bg = _create_bar_bg(XP_BAR_HEIGHT)
	_xp_bar = _create_bar(Color(0.35, 0.6, 1.0, 1.0), XP_BAR_HEIGHT)
	_xp_bar_bg.add_child(_xp_bar)
	vbox.add_child(_xp_bar_bg)
	vbox.move_child(_xp_bar_bg, vbox.get_children().find(_xp_label) + 1)

func _create_bar_bg(height: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.12, 0.92)
	bg.custom_minimum_size = Vector2(STAT_BAR_WIDTH, height)
	return bg

func _create_bar(color: Color, height: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.size = Vector2(STAT_BAR_WIDTH, height)
	bar.position = Vector2.ZERO
	return bar

func update_stats(hp: float, hp_max: float, level: int, xp: int, xp_next: int, timer_text: String, cards_text: String) -> void:
	_hp_label.text = "生命: %.0f / %.0f" % [hp, hp_max]
	_level_label.text = "等级: %d" % level
	_xp_label.text = "小鱼干: %d / %d" % [xp, xp_next]
	_timer_label.text = timer_text
	_cards_label.text = cards_text
	_update_hp_bar(hp, hp_max)
	_update_xp_bar(xp, xp_next)

func _update_hp_bar(hp: float, hp_max: float) -> void:
	if _hp_bar == null or _hp_bar_bg == null:
		return
	var ratio: float = clamp(hp / max(hp_max, 1.0), 0.0, 1.0)
	_hp_bar.size = Vector2(STAT_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	if ratio <= 0.3:
		_hp_bar.color = Color(0.9, 0.15, 0.15, 1.0)
	elif ratio <= 0.6:
		_hp_bar.color = Color(0.9, 0.65, 0.1, 1.0)
	else:
		_hp_bar.color = Color(0.2, 0.9, 0.25, 1.0)

func _update_xp_bar(xp: int, xp_next: int) -> void:
	if _xp_bar == null or _xp_bar_bg == null:
		return
	var ratio: float = clamp(float(xp) / max(float(xp_next), 1.0), 0.0, 1.0)
	_xp_bar.size = Vector2(STAT_BAR_WIDTH * ratio, XP_BAR_HEIGHT)
