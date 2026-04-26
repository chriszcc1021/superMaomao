extends Node2D

@export var area_size: Vector2 = Vector2(1040.0, 620.0)
@export var tile_width: float = 96.0
@export var tile_height: float = 48.0

const GRASS_A := Color(0.53, 0.72, 0.42, 1.0)
const GRASS_B := Color(0.47, 0.66, 0.36, 1.0)
const PATH := Color(0.67, 0.55, 0.36, 1.0)
const STONE := Color(0.56, 0.57, 0.51, 1.0)
const OUTLINE := Color(0.18, 0.22, 0.14, 0.28)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_isometric_tiles()
	_draw_paths()
	_draw_decorations()

func _draw_isometric_tiles() -> void:
	for y in range(-2, 9):
		for x in range(-2, 13):
			var center := Vector2(120.0, 70.0) + Vector2(
				(float(x - y) * tile_width * 0.5),
				(float(x + y) * tile_height * 0.5)
			)
			if center.x < -80.0 or center.x > area_size.x + 80.0:
				continue
			if center.y < -40.0 or center.y > area_size.y + 70.0:
				continue
			var color := GRASS_A if (x + y) % 2 == 0 else GRASS_B
			_draw_diamond(center, tile_width, tile_height, color)

func _draw_paths() -> void:
	_draw_iso_path([Vector2(170, 260), Vector2(350, 260), Vector2(535, 350), Vector2(720, 260), Vector2(910, 260)], 34.0)
	_draw_iso_path([Vector2(535, 350), Vector2(535, 520)], 32.0)
	_draw_stepping_stones([Vector2(220, 360), Vector2(360, 360), Vector2(500, 360), Vector2(640, 360), Vector2(780, 360)])

func _draw_iso_path(points: Array[Vector2], width: float) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		draw_line(a, b, Color(0.33, 0.24, 0.13, 0.16), width + 8.0)
		draw_line(a, b, PATH, width)
		draw_line(a, b, Color(0.88, 0.76, 0.52, 0.2), 3.0)

func _draw_stepping_stones(points: Array[Vector2]) -> void:
	for i in points.size():
		var p := points[i] + Vector2(_rand(i, 0, -10.0, 10.0), _rand(i, 1, -8.0, 8.0))
		var stone := PackedVector2Array([
			p + Vector2(-18.0, 0.0),
			p + Vector2(-4.0, -9.0),
			p + Vector2(18.0, -3.0),
			p + Vector2(12.0, 10.0),
			p + Vector2(-10.0, 9.0),
		])
		draw_colored_polygon(stone, STONE)
		_draw_poly_outline(stone, Color(0.24, 0.24, 0.22, 0.35), 1.0)

func _draw_decorations() -> void:
	for i in 24:
		var p := Vector2(_rand(i, 2, 95.0, 960.0), _rand(i, 3, 85.0, 580.0))
		if _is_near_building_band(p):
			continue
		match i % 4:
			0:
				_draw_grass_tuft(p)
			1:
				_draw_crate(p)
			2:
				_draw_fence(p)
			_:
				_draw_signpost(p)

func _draw_grass_tuft(center: Vector2) -> void:
	for i in 5:
		var angle := -PI * 0.8 + float(i) * PI * 0.2
		var len := 10.0 + float(i % 2) * 4.0
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * len, Color(0.28, 0.5, 0.18, 0.78), 2.0)

func _draw_crate(center: Vector2) -> void:
	var rect := Rect2(center + Vector2(-10.0, -8.0), Vector2(20.0, 16.0))
	draw_rect(rect, Color(0.52, 0.32, 0.18, 0.82), true)
	draw_rect(rect, Color(0.2, 0.12, 0.08, 0.55), false, 1.2)
	draw_line(rect.position, rect.end, Color(0.2, 0.12, 0.08, 0.45), 1.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(0.2, 0.12, 0.08, 0.45), 1.0)

func _draw_fence(center: Vector2) -> void:
	for i in 3:
		var x := center.x + (float(i) - 1.0) * 12.0
		draw_line(Vector2(x, center.y - 10.0), Vector2(x, center.y + 10.0), Color(0.44, 0.29, 0.16, 0.9), 3.0)
	draw_line(center + Vector2(-20.0, -2.0), center + Vector2(20.0, -2.0), Color(0.44, 0.29, 0.16, 0.9), 3.0)

func _draw_signpost(center: Vector2) -> void:
	draw_line(center + Vector2(0.0, -8.0), center + Vector2(0.0, 12.0), Color(0.38, 0.24, 0.13, 0.9), 3.0)
	var board := Rect2(center + Vector2(-13.0, -15.0), Vector2(26.0, 10.0))
	draw_rect(board, Color(0.7, 0.48, 0.24, 0.9), true)
	draw_rect(board, Color(0.2, 0.12, 0.06, 0.55), false, 1.0)

func _is_near_building_band(p: Vector2) -> bool:
	if p.y > 135.0 and p.y < 225.0:
		return true
	if p.y > 315.0 and p.y < 405.0:
		return true
	if p.distance_to(Vector2(535.0, 520.0)) < 110.0:
		return true
	return false

func _draw_diamond(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -height * 0.5),
		center + Vector2(width * 0.5, 0.0),
		center + Vector2(0.0, height * 0.5),
		center + Vector2(-width * 0.5, 0.0),
	])
	draw_colored_polygon(points, color)
	_draw_poly_outline(points, OUTLINE, 1.0)

func _draw_poly_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], color, width)

func _rand(index: int, salt: int, from: float, to: float) -> float:
	var n := sin(float(index * 97 + salt * 193) * 12.9898) * 43758.5453
	return lerpf(from, to, fposmod(n, 1.0))
