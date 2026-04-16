class_name Projectile
extends Area2D

signal hit_enemy(projectile: Projectile, enemy: Node)

@export var speed: float = 420.0
@export var max_distance: float = 220.0
@export var damage: float = 10.0
@export var projectile_color: Color = Color(1.0, 0.9, 0.5, 1.0)

# ── 基因效果 flags ──────────────────────────────
var is_homing: bool = false          # curious_lockon：追踪
var homing_target: Node2D = null
var applies_slow: bool = false       # cold_paw：减速
var slow_duration: float = 2.0
var slow_amount: float = 0.4         # 40% 减速
var hunter_bonus: float = 0.0        # hunter_instinct：精英+25%伤害
var is_chain_projectile: bool = false # 防止连锁递归

var _direction: Vector2 = Vector2.RIGHT
var _origin: Vector2 = Vector2.ZERO
var _travelled: float = 0.0

func _ready() -> void:
	_origin = global_position
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(direction: Vector2, amount: float, range_px: float, color: Color) -> void:
	_direction = direction.normalized()
	damage = amount
	max_distance = range_px
	projectile_color = color
	queue_redraw()

func _process(delta: float) -> void:
	# curious_lockon：导弹式追踪
	if is_homing and homing_target != null and is_instance_valid(homing_target):
		var target_dir := (homing_target.global_position - global_position).normalized()
		_direction = _direction.lerp(target_dir, 8.0 * delta).normalized()
	var move := _direction * speed * delta
	global_position += move
	_travelled += move.length()
	if _travelled >= max_distance:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, projectile_color)
	draw_line(Vector2.ZERO, Vector2(-8, 0), projectile_color.darkened(0.4), 2.0)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("take_damage"):
		queue_free()
		return
	# hunter_instinct：对精英/Boss额外伤害
	var actual_damage := damage
	if hunter_bonus > 0.0:
		var is_priority: bool = bool(body.get("is_elite")) or bool(body.get("is_boss"))
		if is_priority:
			actual_damage *= (1.0 + hunter_bonus)
	body.call("take_damage", actual_damage)
	# cold_paw：减速
	if applies_slow and body.has_method("apply_slow"):
		body.call("apply_slow", slow_duration, slow_amount)
	hit_enemy.emit(self, body)
	queue_free()
