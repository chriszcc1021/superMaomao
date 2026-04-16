extends Node2D

@export var area_size: Vector2 = Vector2(1400.0, 1000.0)
@export var cell_size: float = 64.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var half := area_size * 0.5
	draw_rect(Rect2(-half, area_size), Color(0.18, 0.22, 0.16, 1.0), true)
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(0.22, 0.28, 0.2, 1.0), 1.0)
		x += cell_size
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(0.22, 0.28, 0.2, 1.0), 1.0)
		y += cell_size
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-130, -half.y + 28), "俯视战场", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.9, 0.95, 0.9, 1.0))
