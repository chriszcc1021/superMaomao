class_name CatSprite
extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

@export var auto_wander: bool = true
@export var wander_rect: Rect2 = Rect2(Vector2(120.0, 110.0), Vector2(900.0, 500.0))

var cat_data: CatData
var _target_position: Vector2 = Vector2.ZERO
var _move_speed: float = 65.0

func _ready() -> void:
	set_process(auto_wander)
	if auto_wander:
		_pick_new_target()
	queue_redraw()

func setup(data: CatData) -> void:
	cat_data = data
	_move_speed = max(GameConstants.CAT_WANDER_MIN_MOVE_SPEED, cat_data.base_move_speed)
	if cat_data.base_move_speed <= 0.0:
		cat_data.calculate_stats()
		_move_speed = max(GameConstants.CAT_WANDER_MIN_MOVE_SPEED, cat_data.base_move_speed)
	queue_redraw()

func _process(delta: float) -> void:
	if not auto_wander:
		return
	if global_position.distance_to(_target_position) < GameConstants.CAT_WANDER_TARGET_REACHED_DISTANCE:
		_pick_new_target()
		return
	global_position = global_position.move_toward(_target_position, _move_speed * delta)

func _draw() -> void:
	var cat_color := Color(0.95, 0.73, 0.28, 1.0)
	if cat_data != null:
		match cat_data.profession:
			"sniper":
				cat_color = Color(0.96, 0.66, 0.28, 1.0)
			"aoe":
				cat_color = Color(0.9, 0.5, 0.3, 1.0)
			"control":
				cat_color = Color(0.42, 0.68, 0.95, 1.0)
			"support":
				cat_color = Color(0.53, 0.87, 0.62, 1.0)
	draw_circle(Vector2.ZERO, 14.0, cat_color)
	draw_circle(Vector2(-4.0, -2.0), 2.0, Color.BLACK)
	draw_circle(Vector2(4.0, -2.0), 2.0, Color.BLACK)

func _pick_new_target() -> void:
	var x := randf_range(wander_rect.position.x, wander_rect.end.x)
	var y := randf_range(wander_rect.position.y, wander_rect.end.y)
	_target_position = Vector2(x, y)
