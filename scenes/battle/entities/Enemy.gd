class_name Enemy
extends CharacterBody2D

const FloatingText    := preload("res://scenes/common/FloatingText.gd")
const GameConstants   := preload("res://data/constants.gd")

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
	# 使用场景里配置的 layer/mask，保证投射物 Area2D 可以正确检测到敌人。
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

func take_damage(amount: float, is_crit: bool = false) -> void:
	current_hp -= amount
	queue_redraw()
	if get_parent() != null:
		var _ft := FloatingText.new()
		if is_crit:
			_ft._text = "!!-%d" % int(amount)
			_ft._color = Color(1.0, 0.45, 0.0, 1.0)   # 橙色 = 暴击
		else:
			_ft._text = "-%d" % int(amount)
			_ft._color = Color(1.0, 0.85, 0.2, 1.0)   # 黄色 = 普通
		_ft.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -16.0)
		get_parent().add_child(_ft)
	if current_hp <= 0.0:
		died.emit(enemy_type, fish_drop, global_position)
		queue_free()

func apply_knockback(impulse: Vector2) -> void:
	# 击退：给敌人一个短暂的位移冲量
	if has_method("move_and_slide"):
		velocity += impulse

func _draw() -> void:
	var col := tint_color
	if _slow_timer > 0.0:
		col = tint_color.lerp(Color(0.4, 0.7, 1.0, 1.0), 0.5)
	var outline := Color(0.12, 0.09, 0.08, 1.0)
	var scale_mult := _visual_scale()
	_draw_shadow(scale_mult)
	if _is_gorilla():
		_draw_gorilla_body(scale_mult, col, outline)
	else:
		_draw_monkey_tail(scale_mult, outline)
	_draw_enemy_head(scale_mult, col, outline)
	if enemy_type == "stone_monkey":
		_draw_stone_plates(scale_mult)
	elif enemy_type == "tank_gorilla":
		_draw_gorilla_armor(scale_mult, Color(0.3, 0.31, 0.34, 1.0))
	elif is_elite:
		_draw_enemy_badge(Vector2(0.0, -16.0) * scale_mult, scale_mult, Color(0.86, 0.45, 1.0, 1.0))
	elif is_boss:
		_draw_gorilla_armor(scale_mult, Color(0.46, 0.08, 0.08, 1.0))
		_draw_crown(Vector2(0.0, -19.0) * scale_mult, scale_mult)
	if show_hp_bar:
		var hp_ratio: float = clamp(current_hp / max(max_hp, 1.0), 0.0, 1.0)
		var bar_width := 32.0 * scale_mult
		var bar_y := -26.0 * scale_mult
		draw_rect(Rect2(Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width, 4.0)), Color(0.15, 0.15, 0.15), true)
		draw_rect(Rect2(Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width * hp_ratio, 4.0)), Color(0.25, 0.85, 0.25), true)

func _visual_scale() -> float:
	match enemy_type:
		"stone_monkey":
			return 1.1
		"elite_monkey":
			return 1.28
		"tank_gorilla":
			return 1.55
		"boss_gorilla_king":
			return 2.05
		_:
			return 0.95

func _is_gorilla() -> bool:
	return enemy_type == "tank_gorilla" or enemy_type == "boss_gorilla_king"

func _draw_shadow(scale_mult: float) -> void:
	draw_circle(Vector2(0.0, 11.0 * scale_mult), 12.0 * scale_mult, Color(0.0, 0.0, 0.0, 0.18))
	draw_line(
		Vector2(-12.0, 11.0) * scale_mult,
		Vector2(12.0, 11.0) * scale_mult,
		Color(0.0, 0.0, 0.0, 0.14),
		5.0 * scale_mult
	)

func _draw_monkey_tail(scale_mult: float, outline: Color) -> void:
	draw_arc(Vector2(-11.0, 5.0) * scale_mult, 10.0 * scale_mult, 0.4 * PI, 1.55 * PI, 22, outline, 3.0 * scale_mult)
	draw_arc(Vector2(-11.0, 5.0) * scale_mult, 7.0 * scale_mult, 0.45 * PI, 1.5 * PI, 18, tint_color.lightened(0.1), 1.5 * scale_mult)

func _draw_gorilla_body(scale_mult: float, col: Color, outline: Color) -> void:
	draw_circle(Vector2(-13.0, 10.0) * scale_mult, 9.0 * scale_mult, outline)
	draw_circle(Vector2(13.0, 10.0) * scale_mult, 9.0 * scale_mult, outline)
	draw_circle(Vector2(0.0, 13.0) * scale_mult, 14.0 * scale_mult, outline)
	draw_circle(Vector2(-13.0, 9.0) * scale_mult, 7.0 * scale_mult, col.darkened(0.14))
	draw_circle(Vector2(13.0, 9.0) * scale_mult, 7.0 * scale_mult, col.darkened(0.14))
	draw_circle(Vector2(0.0, 12.0) * scale_mult, 11.0 * scale_mult, col.darkened(0.08))

func _draw_enemy_head(scale_mult: float, col: Color, outline: Color) -> void:
	var head_radius := 12.0 if _is_gorilla() else 11.2
	draw_circle(Vector2.ZERO, (head_radius + 2.0) * scale_mult, outline)
	draw_circle(Vector2.ZERO, head_radius * scale_mult, col)
	draw_circle(Vector2(-8.0, -4.0) * scale_mult, 5.0 * scale_mult, outline)
	draw_circle(Vector2(8.0, -4.0) * scale_mult, 5.0 * scale_mult, outline)
	draw_circle(Vector2(-8.0, -4.0) * scale_mult, 3.2 * scale_mult, col.lightened(0.16))
	draw_circle(Vector2(8.0, -4.0) * scale_mult, 3.2 * scale_mult, col.lightened(0.16))
	draw_circle(Vector2(-4.0, -2.5) * scale_mult, 1.7 * scale_mult, Color.BLACK)
	draw_circle(Vector2(4.0, -2.5) * scale_mult, 1.7 * scale_mult, Color.BLACK)
	if _is_gorilla():
		draw_circle(Vector2(0.0, 4.0) * scale_mult, 5.8 * scale_mult, col.lightened(0.18))
		draw_circle(Vector2(-2.5, 3.0) * scale_mult, 1.0 * scale_mult, Color(0.12, 0.08, 0.06, 1.0))
		draw_circle(Vector2(2.5, 3.0) * scale_mult, 1.0 * scale_mult, Color(0.12, 0.08, 0.06, 1.0))
		draw_arc(Vector2(0.0, 4.5) * scale_mult, 5.0 * scale_mult, 0.2, PI - 0.2, 10, outline, 1.4 * scale_mult)
	else:
		draw_circle(Vector2(0.0, 2.5) * scale_mult, 1.6 * scale_mult, Color(0.12, 0.08, 0.06, 1.0))
		draw_arc(Vector2(0.0, 3.0) * scale_mult, 5.0 * scale_mult, 0.25, PI - 0.25, 10, outline, 1.3 * scale_mult)

func _draw_stone_plates(scale_mult: float) -> void:
	var plate_color := Color(0.78, 0.8, 0.82, 1.0)
	_draw_enemy_badge(Vector2(0.0, -14.0) * scale_mult, scale_mult, plate_color)
	_draw_enemy_badge(Vector2(-6.5, 4.0) * scale_mult, scale_mult * 0.55, plate_color.darkened(0.08))
	_draw_enemy_badge(Vector2(6.5, 4.0) * scale_mult, scale_mult * 0.55, plate_color.darkened(0.12))

func _draw_gorilla_armor(scale_mult: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(-10.0, -18.0) * scale_mult, Vector2(20.0, 7.0) * scale_mult), color, true)
	draw_line(Vector2(-10.0, -11.0) * scale_mult, Vector2(10.0, -11.0) * scale_mult, color.lightened(0.25), 1.3 * scale_mult)

func _draw_enemy_badge(center: Vector2, scale_mult: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -5.0) * scale_mult,
		center + Vector2(5.0, 0.0) * scale_mult,
		center + Vector2(0.0, 5.0) * scale_mult,
		center + Vector2(-5.0, 0.0) * scale_mult,
	])
	draw_colored_polygon(points, color)

func _draw_crown(center: Vector2, scale_mult: float) -> void:
	var crown := PackedVector2Array([
		center + Vector2(-10.0, 5.0) * scale_mult,
		center + Vector2(-7.0, -5.0) * scale_mult,
		center + Vector2(-2.0, 3.0) * scale_mult,
		center + Vector2(0.0, -7.0) * scale_mult,
		center + Vector2(2.0, 3.0) * scale_mult,
		center + Vector2(7.0, -5.0) * scale_mult,
		center + Vector2(10.0, 5.0) * scale_mult,
	])
	draw_colored_polygon(crown, Color(1.0, 0.76, 0.18, 1.0))

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
