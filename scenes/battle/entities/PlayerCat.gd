class_name PlayerCat
extends CharacterBody2D

const FloatingText  := preload("res://scenes/common/FloatingText.gd")
const CatData       := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")

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
var _xp_progress: int = 0
var _xp_to_next: int = 1

var _buff_bonus := {
	"max_hp": 0.0, "attack": 0.0, "move_speed": 0.0,
	"range": 0.0, "crit_rate": 0.0, "pickup_radius": 0.0
}

const BASE_PICKUP_MAGNET_RADIUS := 80.0
const BASE_COLLECT_RADIUS := 20.0
var pickup_magnet_radius: float = BASE_PICKUP_MAGNET_RADIUS
var collect_radius: float = BASE_COLLECT_RADIUS

var _enemies_root: Node2D = null

# ── 基因系统状态 ──────────────────────────────────
var active_genes: Array[String] = []

# 动态属性加成（随HP变化实时计算）
var _dyn_move_bonus: float = 0.0
var _dyn_aspd_bonus: float = 0.0
var _dyn_attack_bonus: float = 0.0

# battle_frenzy：击杀攻速叠层
var _frenzy_stacks: int = 0

# self_heal：计时器
var _self_heal_timer: float = 0.0

# tenacity_revive：每场一次复生
var _revive_available: bool = false
var _revive_iframes: float = 0.0

# invulnerable_frame：受击无敌帧
var _iframes_timer: float = 0.0

# sleepyhead：周期性睡眠
var _sleep_cycle_timer: float = 0.0
var _sleeping: bool = false
var _sleep_timer: float = 0.0

func _ready() -> void:
	queue_redraw()
	if _weapon_system.has_method("set_owner_cat"):
		_weapon_system.call("set_owner_cat", self)

func setup(data: CatData, enemies_root: Node2D) -> void:
	cat_data = data
	_enemies_root = enemies_root
	visible = true
	z_index = 10
	# 玩家猫在 layer=1，mask=0：不与任何物体物理碰撞，敌人无法推动
	collision_layer = 1
	collision_mask = 0
	cat_data.calculate_stats()
	# Model B：使用 CatData.base_hp（基因+职业计算值），不再用 BATTLE_PLAYER_HP_BY_BREED
	base_max_hp = cat_data.base_hp if cat_data.base_hp > 0.0 else 50.0
	base_attack = cat_data.base_attack
	base_move_speed = cat_data.base_move_speed
	base_range = cat_data.base_range
	base_crit_rate = cat_data.base_crit_rate
	base_crit_multiplier = cat_data.base_crit_multiplier
	_recalculate_runtime_stats()
	# 继承血量：cat_data.current_hp >= 0 时从上场战斗继承，否则满血开始
	if cat_data.current_hp >= 0.0:
		current_hp = clampf(cat_data.current_hp, 1.0, max_hp)
	else:
		current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()

func setup_genes(genes: Array[String]) -> void:
	active_genes = genes.duplicate()
	for gene_id: String in genes:
		match gene_id:
			"bulky_body":
				apply_buff("max_hp", 0.20)
			"cat_step":
				apply_buff("move_speed", 0.15)
			"berserk_factor":
				apply_buff("crit_rate", 0.10)
				apply_buff("max_hp", -0.15)
			"lone_pride":
				# 单人战场恒常+20%全属性
				apply_buff("max_hp", 0.20)
				apply_buff("attack", 0.20)
				apply_buff("move_speed", 0.20)
				apply_buff("range", 0.20)
				apply_buff("crit_rate", 0.20)
	# 触发型基因初始化
	_revive_available = "tenacity_revive" in active_genes
	_self_heal_timer = 5.0 if "self_heal" in active_genes else 0.0
	_sleep_cycle_timer = 30.0 if "sleepyhead" in active_genes else 0.0
	# HP满血（apply_buff可能改变max_hp）
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()
	# 向 WeaponSystem 传递弹道基因 flags
	if _weapon_system != null and _weapon_system.has_method("setup_gene_flags"):
		_weapon_system.call("setup_gene_flags", active_genes, _enemies_root)

func _process(delta: float) -> void:
	if _battle_paused:
		return
	# 受击无敌帧冷却
	if _iframes_timer > 0.0:
		_iframes_timer -= delta
	if _revive_iframes > 0.0:
		_revive_iframes -= delta
	# self_heal：每5秒回3%HP
	if _self_heal_timer > 0.0:
		_self_heal_timer -= delta
		if _self_heal_timer <= 0.0:
			_self_heal_timer = 5.0
			var heal_amount := maxf(1.0, ceilf(max_hp * 0.03))
			current_hp = min(_snap_hp_points(current_hp + heal_amount), max_hp)
			hp_changed.emit(current_hp, max_hp)
			queue_redraw()
	# sleepyhead：每30秒强制睡1秒（无敌+停止攻击）
	if _sleeping:
		_sleep_timer -= delta
		if _sleep_timer <= 0.0:
			_sleeping = false
			_sleep_cycle_timer = 30.0
			if _weapon_system != null:
				_weapon_system.call("set_battle_paused", false)
	elif _sleep_cycle_timer > 0.0:
		_sleep_cycle_timer -= delta
		if _sleep_cycle_timer <= 0.0:
			_sleeping = true
			_sleep_timer = 1.0
			_revive_iframes = 1.0  # 睡觉无敌
			if _weapon_system != null:
				_weapon_system.call("set_battle_paused", true)

func _physics_process(_delta: float) -> void:
	if _battle_paused or _sleeping:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var move := Vector2(
		float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))),
		float(int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	)
	if move.length_squared() > 0.0:
		move = move.normalized()
	var effective_speed := move_speed * (1.0 + _dyn_move_bonus)
	velocity = move * effective_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	# 无敌帧/睡觉无敌/复生无敌
	if _iframes_timer > 0.0 or _sleeping or _revive_iframes > 0.0:
		return
	current_hp = maxf(current_hp - GameConstants.BATTLE_PLAYER_HIT_DAMAGE, 0.0)
	_iframes_timer = GameConstants.BATTLE_PLAYER_HIT_IFRAME_SEC
	# invulnerable_frame：额外延长受击无敌时间
	if "invulnerable_frame" in active_genes:
		_iframes_timer += 0.5
	# tenacity_revive：首次濒死复生
	if current_hp <= 0.0 and _revive_available:
		_revive_available = false
		current_hp = maxf(1.0, ceilf(max_hp * 0.20))
		_revive_iframes = 2.0
		if get_parent() != null:
			var _ft_r := FloatingText.new()
			_ft_r._text = "坚韧复生！"
			_ft_r._color = Color(1.0, 0.92, 0.2)
			_ft_r.global_position = global_position + Vector2(0, -30)
			get_parent().add_child(_ft_r)
	# 更新动态加成（desperado / survival_rush / coward）
	_recalculate_dynamic_gene_effects()
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()
	if get_parent() != null:
		var _ft := FloatingText.new()
		_ft._text = "-%d" % int(GameConstants.BATTLE_PLAYER_HIT_DAMAGE)
		_ft._color = Color(0.95, 0.2, 0.2)
		_ft.global_position = global_position + Vector2(randf_range(-6.0, 6.0), -20.0)
		get_parent().add_child(_ft)
	if current_hp <= 0.0:
		died.emit()

func register_kill() -> void:
	# battle_frenzy：每击杀+5%攻速，最多10层
	if "battle_frenzy" in active_genes and _frenzy_stacks < 10:
		_frenzy_stacks += 1
		if _weapon_system != null and _weapon_system.has_method("set_frenzy_bonus"):
			_weapon_system.call("set_frenzy_bonus", _frenzy_stacks * 0.05)

func heal(amount: float) -> void:
	current_hp = min(_snap_hp_points(current_hp + maxf(1.0, ceilf(amount))), max_hp)
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()

func set_xp_progress(current_xp: int, xp_to_next: int) -> void:
	_xp_progress = maxi(current_xp, 0)
	_xp_to_next = maxi(xp_to_next, 1)
	queue_redraw()

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
	var hp_ratio: float = current_hp / maxf(max_hp, 1.0) if max_hp > 0.0 else 1.0
	_recalculate_runtime_stats()
	current_hp = clampf(_snap_hp_points(max_hp * hp_ratio), 0.0, max_hp)
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
	max_hp = _snap_hp_points(base_max_hp * (1.0 + float(_buff_bonus["max_hp"])))
	attack = base_attack * (1.0 + float(_buff_bonus["attack"]))
	move_speed = base_move_speed * (1.0 + float(_buff_bonus["move_speed"]))
	attack_range = base_range * (1.0 + float(_buff_bonus["range"]))
	crit_rate = base_crit_rate + float(_buff_bonus["crit_rate"])
	crit_multiplier = base_crit_multiplier
	pickup_magnet_radius = BASE_PICKUP_MAGNET_RADIUS + float(_buff_bonus["pickup_radius"])

func _recalculate_dynamic_gene_effects() -> void:
	var hp_ratio: float = current_hp / maxf(max_hp, 1.0)
	_dyn_move_bonus = 0.0
	_dyn_aspd_bonus = 0.0
	_dyn_attack_bonus = 0.0
	# survival_rush：HP<30% 移速+攻速均+30%
	if "survival_rush" in active_genes and hp_ratio < 0.30:
		_dyn_move_bonus += 0.30
		_dyn_aspd_bonus += 0.30
	# coward：HP>70% 移速+25%
	if "coward" in active_genes and hp_ratio > 0.70:
		_dyn_move_bonus += 0.25
	# desperado：每损失10%HP攻击+3%（最多+24%）
	if "desperado" in active_genes:
		var hp_lost: float = 1.0 - hp_ratio
		var stacks: int = mini(int(hp_lost / 0.10), 8)
		_dyn_attack_bonus += stacks * 0.03
	# 通知 WeaponSystem 更新动态攻速/攻击加成
	if _weapon_system != null and _weapon_system.has_method("set_dynamic_bonuses"):
		_weapon_system.call("set_dynamic_bonuses", _dyn_aspd_bonus, _dyn_attack_bonus)

func _direction_to_nearest_enemy() -> Vector2:
	if _enemies_root == null:
		return Vector2.RIGHT
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for child: Node in _enemies_root.get_children():
		if not (child is Node2D):
			continue
		var dist: float = global_position.distance_squared_to((child as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = child
	if nearest == null:
		return Vector2.RIGHT
	return (nearest.global_position - global_position).normalized()

func _draw() -> void:
	var cat_color := _battle_cat_color()
	if _sleeping:
		cat_color = Color(0.6, 0.6, 0.9, 1.0)  # 睡觉变蓝紫
	elif _revive_iframes > 0.0 or _iframes_timer > 0.0:
		cat_color = Color(1.0, 1.0, 0.5, 1.0)  # 无敌闪黄
	var outline := Color(0.16, 0.11, 0.09, 1.0)
	draw_circle(Vector2(0.0, 8.0), 15.0, Color(0.0, 0.0, 0.0, 0.16))
	draw_circle(Vector2.ZERO, 17.0, outline)
	draw_circle(Vector2.ZERO, 14.5, cat_color)
	var left_ear := PackedVector2Array([Vector2(-13.0, -9.0), Vector2(-8.0, -24.0), Vector2(-2.0, -12.0)])
	var right_ear := PackedVector2Array([Vector2(13.0, -9.0), Vector2(8.0, -24.0), Vector2(2.0, -12.0)])
	draw_colored_polygon(left_ear, outline)
	draw_colored_polygon(right_ear, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-10.0, -9.0), Vector2(-7.8, -18.0), Vector2(-3.5, -11.0)]), cat_color.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(10.0, -9.0), Vector2(7.8, -18.0), Vector2(3.5, -11.0)]), cat_color.lightened(0.18))
	draw_circle(Vector2(-5.0, -3.5), 2.4, Color.BLACK)
	draw_circle(Vector2(5.0, -3.5), 2.4, Color.BLACK)
	draw_circle(Vector2(-4.2, -4.3), 0.8, Color.WHITE)
	draw_circle(Vector2(5.8, -4.3), 0.8, Color.WHITE)
	draw_circle(Vector2(0.0, 2.0), 1.8, Color(0.18, 0.1, 0.1, 1.0))
	draw_arc(Vector2(-3.0, 3.0), 4.0, 0.1, 1.35, 8, outline, 1.2)
	draw_arc(Vector2(3.0, 3.0), 4.0, 1.8, 3.05, 8, outline, 1.2)
	draw_line(Vector2(-10.0, 2.0), Vector2(-21.0, -1.0), outline, 1.2)
	draw_line(Vector2(10.0, 2.0), Vector2(21.0, -1.0), outline, 1.2)
	draw_line(Vector2(-10.0, 6.0), Vector2(-21.0, 7.0), outline, 1.2)
	draw_line(Vector2(10.0, 6.0), Vector2(21.0, 7.0), outline, 1.2)
	draw_rect(Rect2(Vector2(-18, -24), Vector2(36, 4)), Color(0.15, 0.15, 0.15), true)
	var hp_ratio: float = clamp(current_hp / max(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-18, -24), Vector2(36 * hp_ratio, 4)), Color(0.2, 0.9, 0.25), true)
	draw_rect(Rect2(Vector2(-18, -18), Vector2(36, 3)), Color(0.12, 0.12, 0.18), true)
	var xp_ratio: float = clamp(float(_xp_progress) / maxf(float(_xp_to_next), 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-18, -18), Vector2(36 * xp_ratio, 3)), Color(0.3, 0.65, 1.0), true)

func _battle_cat_color() -> Color:
	if cat_data == null:
		return Color(0.98, 0.73, 0.31, 1.0)
	match cat_data.breed:
		"ragdoll":
			return Color(0.9, 0.84, 0.72, 1.0)
		"siamese":
			return Color(0.76, 0.64, 0.48, 1.0)
		"orange":
			return Color(0.98, 0.62, 0.2, 1.0)
		"black":
			return Color(0.16, 0.16, 0.18, 1.0)
		"british":
			return Color(0.62, 0.68, 0.72, 1.0)
	return Color(0.98, 0.73, 0.31, 1.0)

func _initial_hp_for_breed(breed_id: String) -> float:
	return float(GameConstants.BATTLE_PLAYER_HP_BY_BREED.get(breed_id, 4.0))

func _snap_hp_points(value: float) -> float:
	return maxf(1.0, roundf(value))
