class_name Enemy
extends CharacterBody2D

const GameConstants := preload("res://data/constants.gd")
const FloatingText := preload("res://scenes/common/FloatingText.gd")

signal died(enemy_type: String, fish_drop: int, world_position: Vector2)

@export var enemy_type: String = "small_monkey"
@export var display_name: String = "小猴兵"
@export var max_hp: float = 30.0
@export var damage: float = 8.0
@export var move_speed: float = 95.0
@export var fish_drop: int = 1
@export var tint_color: Color = Color(0.85, 0.4, 0.25, 1.0)

var current_hp: float = 30.0
var show_hp_bar: bool = false
var is_elite: bool = false
var is_boss: bool = false
var _target: Node2D = null
var _attack_cd: float = 0.0
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0

func _ready() -> void:
	current_hp = max_hp
	queue_redraw()

func setup(definition: Dictionary, player_target: Node2D) -> void:
	enemy_type = str(definition.get("id", enemy_type))
	display_name = str(definition.get("display_name", display_name))
	max_hp = float(definition.get("hp", max_hp))
	damage = float(definition.get("damage", damage))
	move_speed = float(definition.get("move_speed", move_speed))
	fish_drop = int(definition.get("fish_drop", fish_drop))
	is_elite = str(enemy_type).begins_with("elite")
	is_boss = str(enemy_type).begins_with("boss")
	show_hp_bar = is_elite or is_boss or bool(definition.get("show_hp_bar", false))
	_target = player_target
	current_hp = max_hp
	tint_color = _resolve_color(enemy_type)
	queue_redraw()

func apply_slow(duration: float, amount: float) -> void:
	_slow_timer = duration
	_slow_multiplier = 1.0 - amount

func set_battle_paused(paused: bool) -> void:
	set_physics_process(not paused)

func _physics_process(delta: float) -> void:
	_attack_cd = max(_attack_cd - delta, 0.0)
	# 减速计时
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
			queue_redraw()
	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * move_speed * _slow_multiplier
	move_and_slide()
	if global_position.distance_to(_target.global_position) <= GameConstants.BATTLE_ENEMY_MELEE_RANGE and _attack_cd <= 0.0:
		_attack_cd = GameConstants.BATTLE_ENEMY_MELEE_INTERVAL
		if _target.has_method("take_damage"):
			_target.call("take_damage", damage)

func take_damage(amount: float) -> void:
	current_hp -= amount
	queue_redraw()
	if get_parent() != null:
		FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-8.0, 8.0), -16.0), "-%d" % int(amount), Color(1.0, 0.85, 0.2, 1.0))
	if current_hp <= 0.0:
		died.emit(enemy_type, fish_drop, global_position)
		queue_free()

func _draw() -> void:
	var col := tint_color
	# 减速时变蓝
	if _slow_timer > 0.0:
		col = tint_color.lerp(Color(0.4, 0.7, 1.0, 1.0), 0.5)
	draw_circle(Vector2.ZERO, 12.0, col)
	draw_circle(Vector2(-4.0, -2.0), 2.0, Color.BLACK)
	draw_circle(Vector2(4.0, -2.0), 2.0, Color.BLACK)
	# 只有精英怪和 Boss 才显示血条
	if show_hp_bar:
		var hp_ratio: float = clamp(current_hp / max(max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-14, -20), Vector2(28, 4)), Color(0.15, 0.15, 0.15), true)
		draw_rect(Rect2(Vector2(-14, -20), Vector2(28 * hp_ratio, 4)), Color(0.25, 0.85, 0.25), true)

func _resolve_color(id: String) -> Color:
	match id:
		"small_monkey":
			return Color(0.86, 0.55, 0.35, 1.0)
		"stone_monkey":
			return Color(0.65, 0.65, 0.73, 1.0)
		"tank_gorilla":
			return Color(0.45, 0.45, 0.5, 1.0)
		"elite_monkey":
			return Color(0.78, 0.38, 0.9, 1.0)
		"boss_gorilla_king":
			return Color(0.85, 0.2, 0.2, 1.0)
		_:
			return Color(0.8, 0.45, 0.3, 1.0)
