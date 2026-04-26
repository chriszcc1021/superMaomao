class_name ArtIcon
extends Control

@export var icon_id: String = "battle_normal"
@export var rarity: String = "grey"
@export var accent: Color = Color(0.9, 0.65, 0.2, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(52.0, 52.0)
	queue_redraw()

func setup(id: String, rarity_id: String = "grey") -> void:
	icon_id = id
	rarity = rarity_id
	accent = _accent_for(id, rarity_id)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var center := rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.44
	_draw_badge(center, radius)
	match icon_id:
		"battle_normal", "battle_elite", "battle_boss":
			_draw_battle(center, radius)
		"shop":
			_draw_shop(center, radius)
		"event_question":
			_draw_question(center, radius)
		"coin":
			_draw_coin(center, radius)
		"food":
			_draw_food(center, radius)
		"heart":
			_draw_heart(center, radius * 0.55, Color(0.94, 0.22, 0.36, 1.0))
		"weapon", "card_weapon":
			_draw_weapon(center, radius)
		"buff", "card_buff":
			_draw_buff(center, radius)
		_:
			if icon_id.begins_with("weapon_"):
				_draw_weapon(center, radius)
			elif icon_id.begins_with("buff_"):
				_draw_buff(center, radius)
			else:
				_draw_star(center, radius)

func _draw_badge(center: Vector2, radius: float) -> void:
	var outline := Color(0.16, 0.11, 0.09, 1.0)
	draw_circle(center + Vector2(0.0, radius * 0.14), radius * 1.02, Color(0.0, 0.0, 0.0, 0.18))
	draw_circle(center, radius, outline)
	draw_circle(center, radius * 0.86, accent.darkened(0.05))
	draw_arc(center, radius * 0.7, PI * 1.1, PI * 1.9, 24, Color(1.0, 1.0, 1.0, 0.24), radius * 0.1)

func _draw_battle(center: Vector2, radius: float) -> void:
	var blade := Color(0.92, 0.9, 0.78, 1.0)
	var hilt := Color(0.38, 0.22, 0.12, 1.0)
	draw_line(center + Vector2(-radius * 0.42, radius * 0.34), center + Vector2(radius * 0.36, -radius * 0.36), blade, radius * 0.18)
	draw_line(center + Vector2(radius * 0.18, -radius * 0.52), center + Vector2(radius * 0.5, -radius * 0.2), blade, radius * 0.12)
	draw_line(center + Vector2(-radius * 0.28, radius * 0.16), center + Vector2(-radius * 0.02, radius * 0.42), hilt, radius * 0.16)
	if icon_id == "battle_elite":
		_draw_star(center + Vector2(radius * 0.32, radius * 0.28), radius * 0.22)
	elif icon_id == "battle_boss":
		_draw_crown(center + Vector2(0.0, -radius * 0.45), radius * 0.6)

func _draw_shop(center: Vector2, radius: float) -> void:
	var cloth := Color(0.92, 0.24, 0.22, 1.0)
	var awning := Rect2(center + Vector2(-radius * 0.55, -radius * 0.36), Vector2(radius * 1.1, radius * 0.34))
	draw_rect(awning, cloth, true)
	for i in 3:
		var x := awning.position.x + float(i) * awning.size.x / 3.0
		draw_rect(Rect2(Vector2(x, awning.position.y), Vector2(awning.size.x / 6.0, awning.size.y)), Color(1.0, 0.86, 0.48, 1.0), true)
	draw_rect(Rect2(center + Vector2(-radius * 0.42, -radius * 0.04), Vector2(radius * 0.84, radius * 0.52)), Color(0.62, 0.38, 0.2, 1.0), true)
	draw_rect(Rect2(center + Vector2(-radius * 0.14, radius * 0.12), Vector2(radius * 0.28, radius * 0.36)), Color(0.25, 0.14, 0.09, 1.0), true)

func _draw_question(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, center + Vector2(-radius * 0.28, radius * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(radius * 1.55), Color(0.16, 0.11, 0.09, 1.0))

func _draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center, radius * 0.52, Color(1.0, 0.79, 0.2, 1.0))
	draw_arc(center, radius * 0.38, 0.0, TAU, 28, Color(0.62, 0.36, 0.08, 1.0), radius * 0.08)
	draw_line(center + Vector2(0.0, -radius * 0.28), center + Vector2(0.0, radius * 0.28), Color(0.62, 0.36, 0.08, 1.0), radius * 0.1)

func _draw_food(center: Vector2, radius: float) -> void:
	var fish := PackedVector2Array([
		center + Vector2(-radius * 0.5, 0.0),
		center + Vector2(-radius * 0.12, -radius * 0.32),
		center + Vector2(radius * 0.45, 0.0),
		center + Vector2(-radius * 0.12, radius * 0.32),
	])
	draw_colored_polygon(fish, Color(0.96, 0.82, 0.3, 1.0))
	draw_circle(center + Vector2(radius * 0.24, -radius * 0.06), radius * 0.05, Color(0.12, 0.08, 0.06, 1.0))
	draw_line(center + Vector2(-radius * 0.48, 0.0), center + Vector2(-radius * 0.72, -radius * 0.22), Color(0.96, 0.82, 0.3, 1.0), radius * 0.14)
	draw_line(center + Vector2(-radius * 0.48, 0.0), center + Vector2(-radius * 0.72, radius * 0.22), Color(0.96, 0.82, 0.3, 1.0), radius * 0.14)

func _draw_weapon(center: Vector2, radius: float) -> void:
	var claw := Color(0.95, 0.9, 0.78, 1.0)
	for i in 3:
		var x := (float(i) - 1.0) * radius * 0.2
		draw_line(center + Vector2(x, radius * 0.34), center + Vector2(x + radius * 0.12, -radius * 0.42), claw, radius * 0.16)
	draw_circle(center + Vector2(0.0, radius * 0.34), radius * 0.24, Color(0.36, 0.2, 0.14, 1.0))

func _draw_buff(center: Vector2, radius: float) -> void:
	var shield := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.56),
		center + Vector2(radius * 0.45, -radius * 0.28),
		center + Vector2(radius * 0.34, radius * 0.32),
		center + Vector2(0.0, radius * 0.56),
		center + Vector2(-radius * 0.34, radius * 0.32),
		center + Vector2(-radius * 0.45, -radius * 0.28),
	])
	draw_colored_polygon(shield, Color(0.82, 0.92, 0.98, 1.0))
	draw_line(center + Vector2(0.0, -radius * 0.34), center + Vector2(0.0, radius * 0.28), Color(0.2, 0.46, 0.62, 1.0), radius * 0.12)
	draw_line(center + Vector2(-radius * 0.22, -radius * 0.02), center + Vector2(radius * 0.22, -radius * 0.02), Color(0.2, 0.46, 0.62, 1.0), radius * 0.12)

func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	draw_circle(center + Vector2(-size * 0.45, -size * 0.25), size * 0.52, color)
	draw_circle(center + Vector2(size * 0.45, -size * 0.25), size * 0.52, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size, 0.0),
		center + Vector2(size, 0.0),
		center + Vector2(0.0, size * 1.15),
	]), color)

func _draw_star(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI * 0.5 + float(i) * PI / 5.0
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, Color(1.0, 0.86, 0.22, 1.0))

func _draw_crown(center: Vector2, width: float) -> void:
	var crown := PackedVector2Array([
		center + Vector2(-width * 0.5, width * 0.2),
		center + Vector2(-width * 0.35, -width * 0.25),
		center + Vector2(-width * 0.08, width * 0.06),
		center + Vector2(0.0, -width * 0.32),
		center + Vector2(width * 0.08, width * 0.06),
		center + Vector2(width * 0.35, -width * 0.25),
		center + Vector2(width * 0.5, width * 0.2),
	])
	draw_colored_polygon(crown, Color(1.0, 0.76, 0.18, 1.0))

func _accent_for(id: String, rarity_id: String) -> Color:
	match id:
		"battle_normal":
			return Color(0.62, 0.72, 0.44, 1.0)
		"battle_elite":
			return Color(0.72, 0.44, 0.86, 1.0)
		"battle_boss":
			return Color(0.86, 0.28, 0.24, 1.0)
		"shop":
			return Color(0.78, 0.55, 0.25, 1.0)
		"event_question":
			return Color(0.32, 0.65, 0.88, 1.0)
		"coin":
			return Color(0.96, 0.72, 0.18, 1.0)
		"food":
			return Color(0.42, 0.72, 0.34, 1.0)
		"heart":
			return Color(0.94, 0.48, 0.54, 1.0)
	match rarity_id:
		"blue":
			return Color(0.32, 0.58, 0.9, 1.0)
		"purple":
			return Color(0.64, 0.36, 0.88, 1.0)
	return Color(0.58, 0.62, 0.56, 1.0)
