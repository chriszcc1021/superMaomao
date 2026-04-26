extends Node2D

@export var area_size: Vector2 = Vector2(1040.0, 620.0)

const GRASS := Color(0.43, 0.58, 0.38, 1.0)
const GRASS_LIGHT := Color(0.56, 0.68, 0.44, 1.0)
const GRASS_DARK := Color(0.28, 0.42, 0.28, 1.0)
const DIRT := Color(0.58, 0.34, 0.31, 1.0)
const DIRT_LIGHT := Color(0.72, 0.48, 0.39, 1.0)
const WATER := Color(0.37, 0.61, 0.58, 1.0)
const STONE := Color(0.55, 0.56, 0.5, 1.0)
const OUTLINE := Color(0.16, 0.22, 0.14, 0.28)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_natural_ground()
	_draw_water_edge()
	_draw_paths()
	_draw_clearings()
	_draw_farm_plots()
	_draw_decorations()

func _draw_natural_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, area_size), GRASS, true)
	_draw_blob(Vector2(160.0, 110.0), 150.0, GRASS_DARK, 1, 15, Vector2(1.35, 0.65), 0.16)
	_draw_blob(Vector2(880.0, 120.0), 140.0, GRASS_DARK, 2, 14, Vector2(1.25, 0.72), 0.12)
	_draw_blob(Vector2(780.0, 470.0), 180.0, GRASS_DARK, 3, 16, Vector2(1.45, 0.75), 0.14)
	_draw_blob(Vector2(500.0, 485.0), 170.0, GRASS_LIGHT, 4, 15, Vector2(1.55, 0.55), 0.12)
	for i in 36:
		var p := Vector2(_rand(i, 10, 45.0, 960.0), _rand(i, 11, 70.0, 575.0))
		if _is_open_camp_space(p):
			continue
		_draw_grass_patch(p, 0.72 + _rand(i, 12, 0.0, 0.45))

func _draw_water_edge() -> void:
	_draw_blob(Vector2(88.0, 485.0), 132.0, WATER, 20, 18, Vector2(1.2, 0.85), 0.12)
	_draw_blob(Vector2(132.0, 405.0), 82.0, WATER.lightened(0.08), 21, 14, Vector2(1.05, 0.6), 0.08)
	for i in 5:
		var p := Vector2(70.0 + float(i) * 34.0, 360.0 + _rand(i, 22, -16.0, 46.0))
		draw_circle(p, 6.0, Color(0.7, 0.88, 0.84, 0.5))

func _draw_paths() -> void:
	_draw_soft_path([Vector2(85, 288), Vector2(255, 250), Vector2(425, 286), Vector2(560, 335), Vector2(735, 282), Vector2(945, 260)], 68.0)
	_draw_soft_path([Vector2(560, 335), Vector2(472, 418), Vector2(395, 505)], 54.0)
	_draw_soft_path([Vector2(560, 335), Vector2(690, 420), Vector2(850, 505)], 50.0)
	_draw_soft_path([Vector2(560, 335), Vector2(545, 245), Vector2(480, 150)], 48.0)

func _draw_soft_path(points: Array[Vector2], width: float) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		draw_line(a, b, Color(0.24, 0.16, 0.12, 0.12), width + 14.0)
		draw_line(a, b, DIRT, width)
		draw_line(a + Vector2(0.0, -3.0), b + Vector2(0.0, -3.0), DIRT_LIGHT, 4.0)
	for i in points.size():
		_draw_blob(points[i], width * 0.48, DIRT, 50 + i, 12, Vector2(1.3, 0.7), 0.0)

func _draw_clearings() -> void:
	_draw_blob(Vector2(560.0, 335.0), 92.0, DIRT, 70, 18, Vector2(1.05, 0.72), 0.18)
	_draw_blob(Vector2(220.0, 210.0), 64.0, DIRT.lightened(0.04), 71, 14, Vector2(1.15, 0.62), 0.12)
	_draw_blob(Vector2(810.0, 345.0), 70.0, DIRT.lightened(0.03), 72, 14, Vector2(1.1, 0.65), 0.12)
	for i in 11:
		var angle := TAU * float(i) / 11.0
		var p := Vector2(560.0, 335.0) + Vector2(cos(angle) * 76.0, sin(angle) * 48.0)
		_draw_stone(p, i)

func _draw_farm_plots() -> void:
	for y in 2:
		for x in 3:
			var center := Vector2(214.0 + float(x) * 46.0, 444.0 + float(y) * 34.0)
			var plot := PackedVector2Array([
				center + Vector2(-20.0, -12.0),
				center + Vector2(20.0, -14.0),
				center + Vector2(22.0, 12.0),
				center + Vector2(-18.0, 14.0),
			])
			draw_colored_polygon(plot, Color(0.29, 0.22, 0.17, 1.0))
			_draw_poly_outline(plot, Color(0.18, 0.12, 0.08, 0.45), 1.0)
			draw_line(center + Vector2(-13.0, 0.0), center + Vector2(13.0, -2.0), Color(0.46, 0.68, 0.24, 0.9), 3.0)

func _draw_decorations() -> void:
	for i in 30:
		var p := Vector2(_rand(i, 30, 70.0, 970.0), _rand(i, 31, 75.0, 575.0))
		if _is_open_camp_space(p):
			continue
		match i % 5:
			0:
				_draw_grass_patch(p, 1.0)
			1:
				_draw_flower_patch(p)
			2:
				_draw_crate(p)
			3:
				_draw_fence(p)
			_:
				_draw_signpost(p)

func _draw_grass_patch(center: Vector2, scale_mult: float) -> void:
	for i in 6:
		var angle := -PI * 0.9 + float(i) * PI * 0.18
		var length := (12.0 + float(i % 2) * 5.0) * scale_mult
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * length, Color(0.19, 0.38, 0.17, 0.84), 2.2 * scale_mult)

func _draw_flower_patch(center: Vector2) -> void:
	_draw_grass_patch(center, 0.8)
	for i in 3:
		var p := center + Vector2(_rand(i, int(center.x), -8.0, 8.0), _rand(i, int(center.y), -7.0, 5.0))
		draw_circle(p, 2.0, Color(0.95, 0.78, 0.36, 0.9))

func _draw_stone(center: Vector2, index: int) -> void:
	var p := center + Vector2(_rand(index, 80, -5.0, 5.0), _rand(index, 81, -4.0, 4.0))
	var stone := PackedVector2Array([
		p + Vector2(-13.0, 0.0),
		p + Vector2(-3.0, -7.0),
		p + Vector2(12.0, -4.0),
		p + Vector2(9.0, 7.0),
		p + Vector2(-9.0, 8.0),
	])
	draw_colored_polygon(stone, STONE)
	_draw_poly_outline(stone, Color(0.24, 0.24, 0.22, 0.35), 1.0)

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

func _is_open_camp_space(p: Vector2) -> bool:
	if p.distance_to(Vector2(560.0, 335.0)) < 145.0:
		return true
	if p.y > 170.0 and p.y < 380.0 and p.x > 120.0 and p.x < 940.0:
		return true
	if p.x < 330.0 and p.y > 400.0:
		return true
	return false

func _draw_blob(center: Vector2, radius: float, color: Color, seed: int, count: int, stretch: Vector2, outline_alpha: float) -> void:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		var wobble := 0.82 + _rand(i, seed, 0.0, 0.28)
		points.append(center + Vector2(cos(angle) * radius * stretch.x * wobble, sin(angle) * radius * stretch.y * wobble))
	draw_colored_polygon(points, color)
	if outline_alpha > 0.0:
		_draw_poly_outline(points, Color(0.14, 0.18, 0.1, outline_alpha), 1.2)

func _draw_poly_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], color, width)

func _rand(index: int, salt: int, from: float, to: float) -> float:
	var n := sin(float(index * 97 + salt * 193) * 12.9898) * 43758.5453
	return lerpf(from, to, fposmod(n, 1.0))
