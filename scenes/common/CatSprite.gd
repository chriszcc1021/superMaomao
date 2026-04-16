class_name CatSprite
extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

@export var auto_wander: bool = true
@export var wander_rect: Rect2 = Rect2(Vector2(120.0, 110.0), Vector2(900.0, 500.0))

signal drop_requested(cat_data: CatData, world_pos: Vector2)

var cat_data: CatData = null
var _target_position: Vector2 = Vector2.ZERO
var _move_speed: float = 65.0
var _elapsed: float = 0.0
var _anim_state: String = "wander"
var _building_anchor: Vector2 = Vector2(-9999, -9999)
var _at_anchor: bool = false
var _food_drop_timer: float = 0.0
var _food_particles: Array = []

# 拖拽状态
var _dragging: bool = false

func _ready() -> void:
	set_process(true)
	_pick_new_target()
	queue_redraw()

func setup(data: CatData) -> void:
	cat_data = data
	_move_speed = max(GameConstants.CAT_WANDER_MIN_MOVE_SPEED, cat_data.base_move_speed)
	if cat_data.base_move_speed <= 0.0:
		cat_data.calculate_stats()
		_move_speed = max(GameConstants.CAT_WANDER_MIN_MOVE_SPEED, cat_data.base_move_speed)
	_update_anim_state()
	queue_redraw()

func set_building_anchor(building_id: String, world_pos: Vector2) -> void:
	_building_anchor = world_pos
	_target_position = world_pos
	_at_anchor = false
	_update_anim_state()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var local_pos := to_local(get_global_mouse_position())
		if local_pos.length() <= 18.0 and not _dragging:
			_dragging = true
			_building_anchor = Vector2(-9999, -9999)
			_at_anchor = false
			get_viewport().set_input_as_handled()
	else:
		if _dragging:
			_dragging = false
			drop_requested.emit(cat_data, get_global_mouse_position())

func _update_anim_state() -> void:
	if cat_data == null:
		_anim_state = "wander"
		return
	if cat_data.health == GameConstants.HEALTH_STATE_SICK or cat_data.health == GameConstants.HEALTH_STATE_CRITICAL:
		_anim_state = "sick"
		return
	if cat_data.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
		_anim_state = "expedition"
		return
	match str(cat_data.assigned_building):
		"cat_house":   _anim_state = "sleep"
		"nursery":     _anim_state = "love"
		"food_farm":   _anim_state = "pray"
		"fortune_cat": _anim_state = "beckon"
		"gold_mine":   _anim_state = "mine"
		"hospital":    _anim_state = "heal"
		_:             _anim_state = "wander"

func _process(delta: float) -> void:
	_elapsed += delta
	_update_anim_state()

	if _anim_state == "expedition":
		visible = false
		return
	visible = true

	if _dragging:
		global_position = get_global_mouse_position()
		queue_redraw()
		return

	if _building_anchor.x > -999.0:
		if not _at_anchor:
			if global_position.distance_to(_building_anchor) < 12.0:
				_at_anchor = true
			else:
				global_position = global_position.move_toward(_building_anchor, _move_speed * delta)
	else:
		if global_position.distance_to(_target_position) < GameConstants.CAT_WANDER_TARGET_REACHED_DISTANCE:
			_pick_new_target()
		else:
			global_position = global_position.move_toward(_target_position, _move_speed * delta)

	if _anim_state == "pray":
		_food_drop_timer -= delta
		if _food_drop_timer <= 0.0:
			_food_drop_timer = randf_range(1.8, 3.5)
			_food_particles.append({"pos": Vector2(randf_range(-40.0, 40.0), -120.0), "vy": 0.0, "alpha": 1.0})
		for i in _food_particles.size():
			_food_particles[i]["vy"] = float(_food_particles[i]["vy"]) + 200.0 * delta
			_food_particles[i]["pos"] += Vector2(0.0, float(_food_particles[i]["vy"]) * delta)
			_food_particles[i]["alpha"] = maxf(0.0, float(_food_particles[i]["alpha"]) - delta * 0.6)
		_food_particles = _food_particles.filter(func(p): return float(p["alpha"]) > 0.0)
	else:
		_food_particles.clear()

	queue_redraw()

func _draw() -> void:
	if _anim_state == "expedition":
		return

	var cat_color := _get_cat_color()
	var scale_mult := 1.3 if _dragging else 1.0
	var shake := Vector2.ZERO
	if _dragging:
		shake = Vector2(sin(_elapsed * 18.0) * 5.0, cos(_elapsed * 14.0) * 2.0)
	elif _anim_state == "sick":
		shake = Vector2(sin(_elapsed * 20.0) * 2.5, 0.0)

	var r := 14.0 * scale_mult
	draw_circle(shake, r, cat_color)
	_draw_eyes(shake, scale_mult)
	draw_circle(shake + Vector2(-10.0, -12.0) * scale_mult, 4.5 * scale_mult, cat_color)
	draw_circle(shake + Vector2(10.0, -12.0) * scale_mult, 4.5 * scale_mult, cat_color)

	if _dragging:
		draw_arc(shake, r + 3.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.5), 2.0)
		return

	match _anim_state:
		"sleep":  _draw_zzz(shake)
		"love":   _draw_hearts(shake)
		"pray":   _draw_praying(shake); _draw_food_drops()
		"beckon": _draw_beckoning(shake)
		"mine":   _draw_mining(shake)
		"heal":   _draw_healing(shake)
		"sick":   _draw_skull(shake)

func _draw_eyes(base: Vector2, scale_mult: float = 1.0) -> void:
	if _anim_state == "sleep":
		draw_line(base + Vector2(-5.5, -2.0) * scale_mult, base + Vector2(-2.5, -2.0) * scale_mult, Color.BLACK, 1.5)
		draw_line(base + Vector2(2.5, -2.0) * scale_mult, base + Vector2(5.5, -2.0) * scale_mult, Color.BLACK, 1.5)
	else:
		draw_circle(base + Vector2(-4.0, -2.0) * scale_mult, 2.0 * scale_mult, Color.BLACK)
		draw_circle(base + Vector2(4.0, -2.0) * scale_mult, 2.0 * scale_mult, Color.BLACK)

func _draw_zzz(base: Vector2) -> void:
	for i in 3:
		var t := fmod(_elapsed * 0.8 + i * 0.4, 2.4) / 2.4
		var alpha := sin(t * PI)
		draw_circle(base + Vector2(float(i) * 6.0 - 3.0 + 12.0, -20.0 - t * 25.0), 3.5, Color(0.8, 0.8, 0.95, alpha))

func _draw_hearts(base: Vector2) -> void:
	for i in 3:
		var t := fmod(_elapsed * 0.9 + i * 0.5, 2.0) / 2.0
		var alpha := sin(t * PI)
		var y_off := -20.0 - t * 30.0
		var x_off := (float(i) - 1.0) * 12.0
		var sz := 4.5
		var c := Color(0.95, 0.3, 0.55, alpha)
		draw_circle(base + Vector2(x_off - sz * 0.5, y_off - sz * 0.4), sz * 0.55, c)
		draw_circle(base + Vector2(x_off + sz * 0.5, y_off - sz * 0.4), sz * 0.55, c)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(x_off - sz, y_off),
			base + Vector2(x_off + sz, y_off),
			base + Vector2(x_off, y_off + sz * 1.2)
		]), c)

func _draw_praying(base: Vector2) -> void:
	var rock := sin(_elapsed * 3.0) * 5.0
	draw_line(base + Vector2(-6.0 + rock, 10.0), base + Vector2(rock, 20.0), Color(0.9, 0.6, 0.3), 3.0)
	draw_line(base + Vector2(6.0 + rock, 10.0), base + Vector2(rock, 20.0), Color(0.9, 0.6, 0.3), 3.0)

func _draw_food_drops() -> void:
	for p in _food_particles:
		var pos: Vector2 = p["pos"]
		var alpha: float = p["alpha"]
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x, pos.y - 6.0), Vector2(pos.x + 5.0, pos.y),
			Vector2(pos.x, pos.y + 6.0), Vector2(pos.x - 5.0, pos.y)
		]), Color(1.0, 0.88, 0.2, alpha))

func _draw_beckoning(base: Vector2) -> void:
	var arm_angle := sin(_elapsed * 3.5) * 0.6
	var arm_end := base + Vector2(18.0 + sin(arm_angle) * 8.0, -5.0 + cos(arm_angle) * 8.0)
	draw_line(base + Vector2(12.0, 2.0), arm_end, _get_cat_color(), 4.0)
	for i in 2:
		var t := fmod(_elapsed * 1.0 + float(i) * 0.7, 1.8) / 1.8
		draw_circle(base + Vector2(22.0, -20.0 - t * 20.0), 3.5, Color(1.0, 0.85, 0.1, sin(t * PI)))

func _draw_mining(base: Vector2) -> void:
	var angle := sin(_elapsed * 4.0) * 0.8
	var hammer_tip := base + Vector2(cos(angle) * 20.0, -sin(angle) * 18.0)
	draw_line(base + Vector2(8.0, 4.0), hammer_tip, Color(0.55, 0.55, 0.6), 3.0)
	draw_circle(hammer_tip, 5.0, Color(0.5, 0.5, 0.55))

func _draw_healing(base: Vector2) -> void:
	draw_line(base + Vector2(-8.0, -2.0), base + Vector2(-8.0, -22.0), Color(0.8, 0.8, 0.8), 2.0)
	draw_rect(Rect2(base + Vector2(-12.0, -20.0), Vector2(8.0, 5.0)), Color(0.9, 0.15, 0.15), true)
	draw_rect(Rect2(base + Vector2(-9.5, -23.0), Vector2(3.0, 10.0)), Color(0.9, 0.15, 0.15), true)

func _draw_skull(base: Vector2) -> void:
	draw_circle(base + Vector2(0.0, -24.0), 6.0, Color(0.85, 0.85, 0.85, 0.9))
	draw_circle(base + Vector2(-2.5, -25.0), 1.5, Color(0.2, 0.2, 0.2, 0.9))
	draw_circle(base + Vector2(2.5, -25.0), 1.5, Color(0.2, 0.2, 0.2, 0.9))

func _get_cat_color() -> Color:
	if cat_data == null:
		return Color(0.95, 0.73, 0.28, 1.0)
	match cat_data.profession:
		"sniper":  return Color(0.96, 0.66, 0.28, 1.0)
		"aoe":     return Color(0.9, 0.5, 0.3, 1.0)
		"control": return Color(0.42, 0.68, 0.95, 1.0)
		"support": return Color(0.53, 0.87, 0.62, 1.0)
	return Color(0.95, 0.73, 0.28, 1.0)

func _pick_new_target() -> void:
	var wait := randf_range(2.5, 5.0)
	await get_tree().create_timer(wait).timeout
	if is_inside_tree() and _building_anchor.x <= -999.0 and not _dragging:
		var x := randf_range(wander_rect.position.x, wander_rect.end.x)
		var y := randf_range(wander_rect.position.y, wander_rect.end.y)
		_target_position = Vector2(x, y)
