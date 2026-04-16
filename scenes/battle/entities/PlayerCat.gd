class_name PlayerCat
extends CharacterBody2D

const CatData := preload("res://resources/CatData.gd")
const FloatingText := preload("res://scenes/common/FloatingText.gd")

signal hp_changed(current_hp: float, max_hp: float)
signal died

@onready var _weapon_system: Node = $WeaponSystem

var cat_data: CatData = null
var _battle_paused: bool = false

var base_max_hp: float = 120.0
var base_attack: float = 50.0
var base_move_speed: float = 70.0
var base_range: float = 5.0
var base_crit_rate: float = 0.05
var base_crit_multiplier: float = 1.5

var max_hp: float = 120.0
var current_hp: float = 120.0
var attack: float = 50.0
var move_speed: float = 70.0
var attack_range: float = 5.0
var crit_rate: float = 0.05
var crit_multiplier: float = 1.5

var _buff_bonus := {
	"max_hp": 0.0,
	"attack": 0.0,
	"move_speed": 0.0,
	"range": 0.0,
	"crit_rate": 0.0,
	"pickup_radius": 0.0
}

# 拾取相关
const BASE_PICKUP_MAGNET_RADIUS := 80.0
const BASE_COLLECT_RADIUS := 20.0
var pickup_magnet_radius: float = BASE_PICKUP_MAGNET_RADIUS
var collect_radius: float = BASE_COLLECT_RADIUS

var _enemies_root: Node2D = null

func _ready() -> void:
	queue_redraw()
	if _weapon_system.has_method("set_owner_cat"):
		_weapon_system.call("set_owner_cat", self)

func setup(data: CatData, enemies_root: Node2D) -> void:
	cat_data = data
	_enemies_root = enemies_root
	cat_data.calculate_stats()
	base_max_hp = cat_data.base_hp
	base_attack = cat_data.base_attack
	base_move_speed = cat_data.base_move_speed
	base_range = cat_data.base_range
	base_crit_rate = cat_data.base_crit_rate
	base_crit_multiplier = cat_data.base_crit_multiplier
	_recalculate_runtime_stats()
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if _battle_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var move := Vector2(
		float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))),
		float(int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	)
	if move.length_squared() > 0.0:
		move = move.normalized()
	velocity = move * move_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()
	# 浮动受伤数字（红色）
	if get_parent() != null:
		FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-6.0, 6.0), -20.0), "-%d" % int(amount), Color(0.95, 0.2, 0.2, 1.0))
	if current_hp <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)

func get_attack_direction() -> Vector2:
	var move_input := Vector2(
		float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))),
		float(int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	)
	if move_input.length_squared() > 0.0:
		var mouse_dir := (get_global_mouse_position() - global_position)
		if mouse_dir.length_squared() > 1.0:
			return mouse_dir.normalized()
	return _direction_to_nearest_enemy()

func apply_buff(effect_key: String, value: float) -> void:
	if not _buff_bonus.has(effect_key):
		return
	_buff_bonus[effect_key] = float(_buff_bonus[effect_key]) + value
	var hp_ratio := 0.0
	if max_hp > 0.0:
		hp_ratio = current_hp / max_hp
	_recalculate_runtime_stats()
	current_hp = max_hp * hp_ratio
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused
	set_physics_process(not paused)
	if _weapon_system.has_method("set_battle_paused"):
		_weapon_system.call("set_battle_paused", paused)

func get_weapon_system() -> Node:
	return _weapon_system

func _recalculate_runtime_stats() -> void:
	max_hp = base_max_hp * (1.0 + float(_buff_bonus["max_hp"]))
	attack = base_attack * (1.0 + float(_buff_bonus["attack"]))
	move_speed = base_move_speed * (1.0 + float(_buff_bonus["move_speed"]))
	attack_range = base_range * (1.0 + float(_buff_bonus["range"]))
	crit_rate = base_crit_rate + float(_buff_bonus["crit_rate"])
	crit_multiplier = base_crit_multiplier
	pickup_magnet_radius = BASE_PICKUP_MAGNET_RADIUS + float(_buff_bonus["pickup_radius"])

func _direction_to_nearest_enemy() -> Vector2:
	if _enemies_root == null:
		return Vector2.RIGHT
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for child: Node in _enemies_root.get_children():
		if not (child is Node2D):
			continue
		var dist := global_position.distance_squared_to((child as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = child
	if nearest == null:
		return Vector2.RIGHT
	return (nearest.global_position - global_position).normalized()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.98, 0.73, 0.31, 1.0))
	draw_circle(Vector2(-4.0, -3.0), 2.0, Color.BLACK)
	draw_circle(Vector2(4.0, -3.0), 2.0, Color.BLACK)
	draw_rect(Rect2(Vector2(-18, -24), Vector2(36, 4)), Color(0.15, 0.15, 0.15), true)
	var hp_ratio: float = clamp(current_hp / max(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-18, -24), Vector2(36 * hp_ratio, 4)), Color(0.2, 0.9, 0.25), true)
