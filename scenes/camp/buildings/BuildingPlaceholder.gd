class_name BuildingPlaceholder
extends Node2D

@export var building_id: String = ""
@export var display_name: String = "建筑"
@export var block_size: Vector2 = Vector2(140.0, 72.0)
@export var fill_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var icon_color: Color = Color(0.1, 0.1, 0.1, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-block_size * 0.5, block_size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, Color(0.05, 0.05, 0.05, 1.0), false, 2.0)
	_draw_icon()
	_draw_name()

func _draw_icon() -> void:
	var center := Vector2(0.0, -10.0)
	match building_id:
		"cat_house":
			draw_polygon(PackedVector2Array([center + Vector2(-16, 6), center + Vector2(0, -10), center + Vector2(16, 6)]), PackedColorArray([icon_color]))
			draw_rect(Rect2(center + Vector2(-12, 6), Vector2(24, 14)), icon_color, false, 2.0)
		"nursery":
			draw_circle(center, 10.0, icon_color)
			draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), icon_color, 2.0)
		"hospital":
			draw_rect(Rect2(center + Vector2(-12, -4), Vector2(24, 8)), icon_color, true)
			draw_rect(Rect2(center + Vector2(-4, -12), Vector2(8, 24)), icon_color, true)
		"food_farm":
			draw_line(center + Vector2(0, 12), center + Vector2(0, -10), icon_color, 2.0)
			draw_circle(center + Vector2(-6, -2), 4.0, icon_color)
			draw_circle(center + Vector2(6, -6), 4.0, icon_color)
		"gold_mine":
			draw_rect(Rect2(center + Vector2(-12, -8), Vector2(24, 16)), icon_color, false, 2.0)
			draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), icon_color, 2.0)
		"granary":
			draw_rect(Rect2(center + Vector2(-10, -10), Vector2(20, 20)), icon_color, false, 2.0)
			draw_line(center + Vector2(-10, -10), center + Vector2(0, -16), icon_color, 2.0)
			draw_line(center + Vector2(10, -10), center + Vector2(0, -16), icon_color, 2.0)
		"heart_cat_house":
			draw_circle(center + Vector2(-4, -2), 6.0, icon_color)
			draw_circle(center + Vector2(4, -2), 6.0, icon_color)
			draw_polygon(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(10, 0), center + Vector2(0, 14)]), PackedColorArray([icon_color]))
		"cemetery":
			draw_rect(Rect2(center + Vector2(-8, -8), Vector2(16, 18)), icon_color, false, 2.0)
			draw_arc(center + Vector2(0, -8), 8.0, PI, TAU, 12, icon_color, 2.0)
		_:
			draw_circle(center, 8.0, icon_color)

func _draw_name() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := display_name
	var size := 14
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(-text_width * 0.5, 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.0, 0.0, 0.0, 1.0))
