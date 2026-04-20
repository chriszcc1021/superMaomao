class_name FloatingText
extends Node2D

# 浮动伤害数字，自动向上飘动后销毁
# 使用方法：FloatingText.spawn(parent_node, world_position, text, color)

const FLOAT_DURATION := 0.8  # 秒
const FLOAT_RISE := 40.0     # 像素（向上飘移距离）
const FONT_SIZE := 14

# Fix: 用场景文件实例化，避免 class_name 自引用在热重载时报错
const _Scene := preload("res://scenes/common/FloatingText.tscn")

static func spawn(parent: Node, world_pos: Vector2, display_text: String, color: Color = Color.WHITE) -> void:
	var ft: Node2D = _Scene.instantiate()
	ft.global_position = world_pos
	ft._text = display_text
	ft._color = color
	parent.add_child(ft)

var _text: String = ""
var _color: Color = Color.WHITE
var _elapsed: float = 0.0
var _label: Label = null

func _ready() -> void:
	_label = Label.new()
	_label.text = _text
	_label.add_theme_color_override("font_color", _color)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.position = Vector2(-20.0, -30.0)
	add_child(_label)
	z_index = 10

func _process(delta: float) -> void:
	_elapsed += delta
	var progress := _elapsed / FLOAT_DURATION
	# 向上飘
	_label.position.y = -30.0 - FLOAT_RISE * progress
	# 淡出
	modulate.a = 1.0 - progress
	if _elapsed >= FLOAT_DURATION:
		queue_free()
