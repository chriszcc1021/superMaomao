class_name BuildingPlaceholder
extends Node2D

@export var building_id: String = ""
@export var display_name: String = "建筑"
@export var block_size: Vector2 = Vector2(140.0, 72.0)
@export var fill_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var icon_color: Color = Color(0.1, 0.1, 0.1, 1.0)

const OUTLINE := Color(0.18, 0.14, 0.12, 1.0)
const TEXT := Color(0.16, 0.12, 0.1, 1.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var palette := _palette()
	_draw_shadow()
	_draw_ground(palette.ground)
	_draw_building(palette)
	_draw_name()

func _draw_shadow() -> void:
	var shadow := PackedVector2Array([
		Vector2(-58.0, 26.0),
		Vector2(-22.0, 43.0),
		Vector2(38.0, 43.0),
		Vector2(66.0, 28.0),
		Vector2(18.0, 12.0),
		Vector2(-38.0, 14.0),
	])
	draw_colored_polygon(shadow, Color(0.05, 0.04, 0.03, 0.18))

func _draw_ground(color: Color) -> void:
	var ground := _oval(Vector2(0.0, 24.0), block_size.x * 0.86, block_size.y * 0.62, 22)
	draw_colored_polygon(ground, color)
	_draw_poly_outline(ground, Color(0.14, 0.18, 0.11, 0.38), 1.8)
	draw_arc(Vector2(0.0, 24.0), 44.0, 0.08, PI - 0.08, 20, Color(1.0, 1.0, 1.0, 0.12), 1.2)

func _draw_building(palette: Dictionary) -> void:
	match building_id:
		"cat_house":
			_draw_house(palette.wall, palette.roof, Vector2(0.0, -8.0), true)
		"granary":
			_draw_granary(palette.wall, palette.roof)
		"food_farm":
			_draw_farm(palette.wall, palette.roof)
		"gold_mine":
			_draw_mine(palette.wall, palette.roof)
		"nursery":
			_draw_nursery(palette.wall, palette.roof)
		"hospital":
			_draw_hospital(palette.wall, palette.roof)
		"heart_cat_house":
			_draw_house(palette.wall, palette.roof, Vector2(0.0, -8.0), false)
			_draw_heart(Vector2(0.0, -34.0), 7.0, Color(0.95, 0.24, 0.38, 1.0))
		"cemetery":
			_draw_cemetery(palette.wall, palette.roof)
		"fortune_cat":
			_draw_fortune_shrine(palette.wall, palette.roof)
		_:
			_draw_house(palette.wall, palette.roof, Vector2(0.0, -8.0), true)

func _draw_house(wall: Color, roof: Color, center: Vector2, has_paw: bool) -> void:
	var body := Rect2(center + Vector2(-28.0, -8.0), Vector2(56.0, 34.0))
	draw_rect(body, wall, true)
	draw_rect(body, OUTLINE, false, 2.0)
	var roof_poly := PackedVector2Array([
		center + Vector2(-36.0, -8.0),
		center + Vector2(0.0, -34.0),
		center + Vector2(36.0, -8.0),
	])
	draw_colored_polygon(roof_poly, roof)
	_draw_poly_outline(roof_poly, OUTLINE, 2.0)
	draw_rect(Rect2(center + Vector2(-7.0, 8.0), Vector2(14.0, 18.0)), Color(0.2, 0.15, 0.12, 1.0), true)
	draw_circle(center + Vector2(9.0, 17.0), 1.6, Color(0.95, 0.76, 0.28, 1.0))
	if has_paw:
		_draw_paw(center + Vector2(0.0, -2.0), Color(0.3, 0.2, 0.16, 1.0))

func _draw_granary(wall: Color, roof: Color) -> void:
	draw_rect(Rect2(Vector2(-26.0, -24.0), Vector2(52.0, 52.0)), wall, true)
	draw_rect(Rect2(Vector2(-26.0, -24.0), Vector2(52.0, 52.0)), OUTLINE, false, 2.0)
	for x in [-14.0, 0.0, 14.0]:
		draw_line(Vector2(x, -21.0), Vector2(x, 25.0), wall.lerp(OUTLINE, 0.28), 1.5)
	var roof_poly := PackedVector2Array([Vector2(-34.0, -24.0), Vector2(0.0, -44.0), Vector2(34.0, -24.0)])
	draw_colored_polygon(roof_poly, roof)
	_draw_poly_outline(roof_poly, OUTLINE, 2.0)
	draw_rect(Rect2(Vector2(-12.0, 5.0), Vector2(24.0, 23.0)), Color(0.42, 0.28, 0.16, 1.0), true)

func _draw_farm(wall: Color, roof: Color) -> void:
	for i in 4:
		var x := -42.0 + float(i) * 24.0
		draw_line(Vector2(x, 6.0), Vector2(x + 18.0, 28.0), Color(0.28, 0.42, 0.18, 1.0), 5.0)
		draw_line(Vector2(x + 8.0, 0.0), Vector2(x + 26.0, 22.0), Color(0.58, 0.74, 0.26, 1.0), 3.0)
	_draw_house(wall, roof, Vector2(0.0, -18.0), false)
	draw_rect(Rect2(Vector2(-7.0, -6.0), Vector2(14.0, 22.0)), Color(0.34, 0.22, 0.14, 1.0), true)

func _draw_mine(wall: Color, roof: Color) -> void:
	var cave := PackedVector2Array([Vector2(-40.0, 20.0), Vector2(-22.0, -24.0), Vector2(20.0, -32.0), Vector2(45.0, 18.0)])
	draw_colored_polygon(cave, wall)
	_draw_poly_outline(cave, OUTLINE, 2.0)
	draw_arc(Vector2(2.0, 16.0), 24.0, PI, TAU, 24, Color(0.12, 0.1, 0.09, 1.0), 16.0)
	for p in [Vector2(-24.0, 8.0), Vector2(28.0, 5.0), Vector2(9.0, -17.0)]:
		_draw_gem(p, roof)

func _draw_nursery(wall: Color, roof: Color) -> void:
	_draw_house(wall, roof, Vector2(0.0, -10.0), false)
	draw_arc(Vector2(0.0, 2.0), 17.0, 0.18, PI - 0.18, 24, Color(0.95, 0.72, 0.56, 1.0), 4.0)
	draw_circle(Vector2(-13.0, 7.0), 3.5, OUTLINE)
	draw_circle(Vector2(13.0, 7.0), 3.5, OUTLINE)

func _draw_hospital(wall: Color, roof: Color) -> void:
	_draw_house(wall, roof, Vector2(0.0, -8.0), false)
	draw_rect(Rect2(Vector2(-5.0, -21.0), Vector2(10.0, 30.0)), Color(0.88, 0.08, 0.08, 1.0), true)
	draw_rect(Rect2(Vector2(-17.0, -11.0), Vector2(34.0, 10.0)), Color(0.88, 0.08, 0.08, 1.0), true)

func _draw_cemetery(wall: Color, roof: Color) -> void:
	draw_rect(Rect2(Vector2(-26.0, -18.0), Vector2(52.0, 36.0)), wall, true)
	draw_rect(Rect2(Vector2(-26.0, -18.0), Vector2(52.0, 36.0)), OUTLINE, false, 2.0)
	var stone := Rect2(Vector2(-13.0, -30.0), Vector2(26.0, 48.0))
	draw_rect(stone, roof, true)
	draw_arc(Vector2(0.0, -30.0), 13.0, PI, TAU, 20, roof, 13.0)
	draw_line(Vector2(0.0, -22.0), Vector2(0.0, -5.0), OUTLINE, 2.0)
	draw_line(Vector2(-7.0, -15.0), Vector2(7.0, -15.0), OUTLINE, 2.0)

func _draw_fortune_shrine(wall: Color, roof: Color) -> void:
	draw_rect(Rect2(Vector2(-28.0, -10.0), Vector2(56.0, 28.0)), wall, true)
	draw_rect(Rect2(Vector2(-28.0, -10.0), Vector2(56.0, 28.0)), OUTLINE, false, 2.0)
	var roof_poly := PackedVector2Array([Vector2(-38.0, -10.0), Vector2(0.0, -34.0), Vector2(38.0, -10.0)])
	draw_colored_polygon(roof_poly, roof)
	_draw_poly_outline(roof_poly, OUTLINE, 2.0)
	draw_circle(Vector2(0.0, -5.0), 14.0, Color(1.0, 0.82, 0.46, 1.0))
	draw_circle(Vector2(-5.0, -8.0), 1.8, OUTLINE)
	draw_circle(Vector2(5.0, -8.0), 1.8, OUTLINE)
	draw_arc(Vector2(0.0, -4.0), 7.0, 0.2, PI - 0.2, 12, OUTLINE, 1.6)
	draw_circle(Vector2(15.0, -15.0), 4.0, Color(0.92, 0.16, 0.18, 1.0))

func _draw_paw(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(0.0, 4.0), 4.5, color)
	for p in [Vector2(-6.0, -1.0), Vector2(-2.0, -5.0), Vector2(2.0, -5.0), Vector2(6.0, -1.0)]:
		draw_circle(center + p, 2.2, color)

func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	draw_circle(center + Vector2(-size * 0.45, -size * 0.25), size * 0.52, color)
	draw_circle(center + Vector2(size * 0.45, -size * 0.25), size * 0.52, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size, 0.0),
		center + Vector2(size, 0.0),
		center + Vector2(0.0, size * 1.15),
	]), color)

func _draw_gem(center: Vector2, color: Color) -> void:
	var gem := PackedVector2Array([
		center + Vector2(0.0, -6.0),
		center + Vector2(7.0, 0.0),
		center + Vector2(0.0, 7.0),
		center + Vector2(-7.0, 0.0),
	])
	draw_colored_polygon(gem, color)
	_draw_poly_outline(gem, OUTLINE, 1.2)

func _draw_poly_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], color, width)

func _draw_name() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text_width := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	draw_string(font, Vector2(-text_width * 0.5, 58.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, TEXT)

func _diamond(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -height * 0.5),
		center + Vector2(width * 0.5, 0.0),
		center + Vector2(0.0, height * 0.5),
		center + Vector2(-width * 0.5, 0.0),
	])

func _oval(center: Vector2, width: float, height: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		var wobble := 0.94 + 0.06 * sin(float(i) * 2.17)
		points.append(center + Vector2(cos(angle) * width * 0.5 * wobble, sin(angle) * height * 0.5 * wobble))
	return points

func _palette() -> Dictionary:
	match building_id:
		"cat_house":
			return {"ground": Color(0.72, 0.86, 0.58), "wall": Color(0.88, 0.67, 0.46), "roof": Color(0.64, 0.32, 0.23)}
		"granary":
			return {"ground": Color(0.77, 0.78, 0.52), "wall": Color(0.78, 0.61, 0.34), "roof": Color(0.45, 0.28, 0.16)}
		"food_farm":
			return {"ground": Color(0.62, 0.78, 0.42), "wall": Color(0.8, 0.58, 0.33), "roof": Color(0.52, 0.76, 0.3)}
		"gold_mine":
			return {"ground": Color(0.7, 0.66, 0.48), "wall": Color(0.42, 0.39, 0.37), "roof": Color(0.95, 0.74, 0.24)}
		"nursery":
			return {"ground": Color(0.78, 0.86, 0.62), "wall": Color(0.95, 0.72, 0.62), "roof": Color(0.85, 0.43, 0.48)}
		"hospital":
			return {"ground": Color(0.76, 0.84, 0.7), "wall": Color(0.92, 0.91, 0.82), "roof": Color(0.48, 0.72, 0.78)}
		"heart_cat_house":
			return {"ground": Color(0.78, 0.86, 0.58), "wall": Color(0.9, 0.62, 0.58), "roof": Color(0.78, 0.28, 0.36)}
		"cemetery":
			return {"ground": Color(0.6, 0.66, 0.58), "wall": Color(0.42, 0.46, 0.44), "roof": Color(0.65, 0.68, 0.64)}
		"fortune_cat":
			return {"ground": Color(0.78, 0.72, 0.52), "wall": Color(0.72, 0.34, 0.26), "roof": Color(0.94, 0.67, 0.18)}
	return {"ground": fill_color.lerp(Color.WHITE, 0.2), "wall": fill_color, "roof": icon_color}
