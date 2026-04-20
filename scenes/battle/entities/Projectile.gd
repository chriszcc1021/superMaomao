class_name Projectile
extends Area2D

signal hit_enemy(projectile: Projectile, enemy: Node)

@export var speed: float = 420.0
@export var max_distance: float = 220.0
@export var damage: float = 10.0
@export var projectile_color: Color = Color(1.0, 0.9, 0.5, 1.0)

# ── 暴击 ──────────────────────────────────────────
var crit_rate: float = 0.0
var crit_multiplier: float = 1.5

# ── 基因效果 flags ──────────────────────────────
var is_homing: bool = false          # curious_lockon：追踪
var homing_target: Node2D = null
var applies_slow: bool = false       # cold_paw：减速
var slow_duration: float = 2.0
var slow_amount: float = 0.4         # 40% 减速
var hunter_bonus: float = 0.0        # hunter_instinct：精英+25%伤害
var is_chain_projectile: bool = false # 防止连锁递归

# ── 品种差异化 flags ────────────────────────────
var is_piercing: bool = false        # ragdoll：穿透所有敌人
var splash_damage: float = 0.0       # orange：命中溅射伤害
var splash_radius: float = 0.0       # orange：溅射半径
var knockback_force: float = 0.0     # british：击退力度
var applies_slow_on_hit: bool = false # british：命中减速

var _direction: Vector2 = Vector2.RIGHT
var _origin: Vector2 = Vector2.ZERO
var _travelled: float = 0.0
var _hit_bodies: Array[Node] = []    # 穿透用：记录已击中的对象

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
	var radius := 6.0 if (knockback_force > 0.0) else 4.0  # british：大弹
	draw_circle(Vector2.ZERO, radius, projectile_color)
	draw_line(Vector2.ZERO, Vector2(-8, 0), projectile_color.darkened(0.4), 2.0)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("take_damage"):
		if not is_piercing:
			queue_free()
		return
	# 穿透：每个目标只打一次
	if is_piercing:
		if body in _hit_bodies:
			return
		_hit_bodies.append(body)

	# 暴击判定
	var is_crit := randf() < crit_rate
	var actual_damage := damage
	if is_crit:
		actual_damage *= crit_multiplier

	# hunter_instinct：对精英/Boss额外伤害
	if hunter_bonus > 0.0:
		var is_priority: bool = bool(body.get("is_elite")) or bool(body.get("is_boss"))
		if is_priority:
			actual_damage *= (1.0 + hunter_bonus)

	body.call("take_damage", actual_damage, is_crit)

	# cold_paw / british减速
	if (applies_slow or applies_slow_on_hit) and body.has_method("apply_slow"):
		body.call("apply_slow", slow_duration, slow_amount)

	# british：击退
	if knockback_force > 0.0 and body is Node2D:
		var push_dir := (_direction).normalized()
		if body.has_method("apply_knockback"):
			body.call("apply_knockback", push_dir * knockback_force)

	# orange：溅射
	if splash_damage > 0.0 and splash_radius > 0.0:
		_do_splash(body)

	hit_enemy.emit(self, body)

	if not is_piercing:
		queue_free()

func _do_splash(origin_body: Node) -> void:
	# 找 _projectile_root 的兄弟层（parent 的 parent），在 splash_radius 内寻找敌人
	var proj_root := get_parent()
	if proj_root == null:
		return
	var scene_root := proj_root.get_parent()
	if scene_root == null:
		return
	# 找 enemies_root（名字约定为 Enemies）
	var enemies_root: Node = scene_root.get_node_or_null("Enemies")
	if enemies_root == null:
		return
	for child: Node in enemies_root.get_children():
		if child == origin_body or not (child is Node2D):
			continue
		var dist := (child as Node2D).global_position.distance_to(global_position)
		if dist <= splash_radius and child.has_method("take_damage"):
			child.call("take_damage", splash_damage, false)
