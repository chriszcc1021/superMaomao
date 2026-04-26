extends Node2D

@export var area_size: Vector2 = Vector2(1400.0, 1000.0)
@export var cell_size: float = 96.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var half := area_size * 0.5
	_draw_ground(half)
	_draw_soft_grid(half)
	_draw_ruins(half)
	_draw_boundary(half)

func _draw_ground(half: Vector2) -> void:
	draw_rect(Rect2(-half, area_size), Color(0.24, 0.34, 0.22, 1.0), true)
	for i in 90:
		var p := Vector2(
			_rand_from_index(i, 0, -half.x, half.x),
			_rand_from_index(i, 1, -half.y, half.y)
		)
		var radius := _rand_from_index(i, 2, 6.0, 18.0)
		var color := Color(0.18, 0.29, 0.18, 0.22)
		if i % 5 == 0:
			color = Color(0.34, 0.43, 0.22, 0.18)
		draw_circle(p, radius, color)

func _draw_soft_grid(half: Vector2) -> void:
	var line_color := Color(0.17, 0.25, 0.18, 0.22)
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), line_color, 1.0)
		x += cell_size
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), line_color, 1.0)
		y += cell_size

func _draw_ruins(half: Vector2) -> void:
	for i in 18:
		var center := Vector2(
			_rand_from_index(i, 3, -half.x + 80.0, half.x - 80.0),
			_rand_from_index(i, 4, -half.y + 80.0, half.y - 80.0)
		)
		if center.length() < 150.0:
			center += center.normalized() * 150.0 if center.length() > 0.0 else Vector2(180.0, 120.0)
		if i % 3 == 0:
			_draw_stone(center, _rand_from_index(i, 5, 14.0, 30.0))
		elif i % 3 == 1:
			_draw_grass_tuft(center)
		else:
			_draw_broken_tile(center)

func _draw_stone(center: Vector2, size: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-size * 0.7, -size * 0.2),
		center + Vector2(-size * 0.2, -size * 0.65),
		center + Vector2(size * 0.65, -size * 0.35),
		center + Vector2(size * 0.55, size * 0.45),
		center + Vector2(-size * 0.35, size * 0.62),
	])
	draw_colored_polygon(points, Color(0.38, 0.41, 0.36, 0.72))
	for j in points.size():
		draw_line(points[j], points[(j + 1) % points.size()], Color(0.18, 0.2, 0.18, 0.45), 1.5)

func _draw_grass_tuft(center: Vector2) -> void:
	for j in 5:
		var angle := -PI * 0.75 + float(j) * PI * 0.18
		var tip := center + Vector2(cos(angle), sin(angle)) * (16.0 + float(j % 2) * 5.0)
		draw_line(center, tip, Color(0.42, 0.58, 0.22, 0.8), 2.0)

func _draw_broken_tile(center: Vector2) -> void:
	var color := Color(0.47, 0.43, 0.34, 0.44)
	draw_rect(Rect2(center + Vector2(-18.0, -9.0), Vector2(36.0, 18.0)), color, true)
	draw_line(center + Vector2(-18.0, -9.0), center + Vector2(18.0, 9.0), Color(0.2, 0.18, 0.14, 0.3), 1.2)

func _draw_boundary(half: Vector2) -> void:
	var rect := Rect2(-half, area_size)
	draw_rect(rect, Color(0.09, 0.12, 0.08, 0.0), false, 8.0)
	draw_rect(rect.grow(-18.0), Color(0.46, 0.58, 0.28, 0.12), false, 3.0)

func _rand_from_index(index: int, salt: int, from: float, to: float) -> float:
	var n := sin(float(index * 91 + salt * 137) * 12.9898) * 43758.5453
	var t := fposmod(n, 1.0)
	return lerpf(from, to, t)
