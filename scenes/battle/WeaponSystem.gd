class_name WeaponSystem
extends Node

const ProjectileScene := preload("res://scenes/battle/entities/Projectile.tscn")
const GameConstants   := preload("res://data/constants.gd")
const CardData        := preload("res://resources/CardData.gd")
const Projectile      := preload("res://scenes/battle/entities/Projectile.gd")

var _owner_cat: Node2D = null
var _projectile_root: Node2D = null
var _battle_paused: bool = false

var _basic_attack_timer: float = 0.0
var _weapon_attack_timer: float = 0.0
var _weapon_cards: Array[CardData] = []

# ── 品种 ──────────────────────────────────────────
var _breed: String = "tabby"

# ── 基因 flags ────────────────────────────────────
var _has_curious_lockon: bool = false
var _has_cold_paw: bool = false
var _has_chain_hit: bool = false
var _has_hunter_instinct: bool = false
var _frenzy_bonus: float = 0.0
var _dyn_aspd_bonus: float = 0.0
var _dyn_attack_bonus: float = 0.0
var _enemies_root: Node2D = null

func set_owner_cat(cat: Node2D) -> void:
	_owner_cat = cat

func set_projectile_root(root: Node2D) -> void:
	_projectile_root = root

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused

func setup_breed(breed: String) -> void:
	_breed = breed

func setup_gene_flags(genes: Array[String], enemies_root: Node2D) -> void:
	_has_curious_lockon  = "curious_lockon"   in genes
	_has_cold_paw        = "cold_paw"         in genes
	_has_chain_hit       = "chain_hit"        in genes
	_has_hunter_instinct = "hunter_instinct"  in genes
	_enemies_root = enemies_root

func set_frenzy_bonus(bonus: float) -> void:
	_frenzy_bonus = bonus

func set_dynamic_bonuses(aspd_bonus: float, attack_bonus: float) -> void:
	_dyn_aspd_bonus = aspd_bonus
	_dyn_attack_bonus = attack_bonus

func _get_aspd_multiplier() -> float:
	return max(1.0 + _frenzy_bonus + _dyn_aspd_bonus, 0.1)

func _process(delta: float) -> void:
	if _battle_paused or _owner_cat == null or _projectile_root == null:
		return
	var aspd := _get_aspd_multiplier()
	_basic_attack_timer -= delta * aspd
	_weapon_attack_timer -= delta * aspd
	if _basic_attack_timer <= 0.0:
		_basic_attack_timer = GameConstants.BATTLE_BASIC_CLAW_INTERVAL
		_fire_basic_claw()
	if _weapon_cards.size() > 0 and _weapon_attack_timer <= 0.0:
		_weapon_attack_timer = GameConstants.BATTLE_WEAPON_ATTACK_INTERVAL
		_fire_weapon_cards()

func apply_weapon_card(card: CardData) -> void:
	for existing: CardData in _weapon_cards:
		if existing.id == card.id:
			if existing.can_stack():
				existing.add_stack()
			return
	if _weapon_cards.size() >= GameConstants.BATTLE_WEAPON_SLOT_CAP:
		return
	_weapon_cards.append(card)

func get_weapon_cards() -> Array[CardData]:
	return _weapon_cards

# ── 暴击工具函数 ─────────────────────────────────
func _get_crit_rate() -> float:
	if _owner_cat == null:
		return 0.0
	return float(_owner_cat.get("crit_rate"))

func _get_crit_multiplier() -> float:
	if _owner_cat == null:
		return 1.5
	return float(_owner_cat.get("crit_multiplier"))

func _apply_crit_to_projectile(projectile: Projectile) -> void:
	projectile.crit_rate = _get_crit_rate()
	projectile.crit_multiplier = _get_crit_multiplier()

# ── 基础爪击（品种差异化）────────────────────────
func _fire_basic_claw() -> void:
	if _owner_cat == null:
		return
	var attack_value: float = float(_owner_cat.get("attack")) * (1.0 + _dyn_attack_bonus)
	var range_tiles: float = GameConstants.BATTLE_BASIC_CLAW_RANGE_TILES
	var attack_range: float = max(float(_owner_cat.get("attack_range")), range_tiles)
	var base_dmg: float = attack_value * GameConstants.BATTLE_BASIC_CLAW_DAMAGE_MULT
	var range_px: float = attack_range * GameConstants.BATTLE_TILE_SIZE
	var dir: Vector2 = _owner_cat.call("get_attack_direction")

	match _breed:
		"ragdoll":
			# 穿透直线弹，伤害×0.9
			var p: Projectile = _make_projectile(dir, base_dmg * 0.9, range_px, Color(0.85, 0.75, 1.0))
			p.is_piercing = true
			_apply_gene_flags_to_projectile(p)
			_projectile_root.add_child(p)

		"siamese":
			# 同时射2枚轻弹，各0.5×伤害，轻微分叉±6°
			for offset_deg: float in [-6.0, 6.0]:
				var d := dir.rotated(deg_to_rad(offset_deg))
				var p: Projectile = _make_projectile(d, base_dmg * 0.5, range_px * 0.9, Color(0.7, 1.0, 0.9))
				p.speed = 520.0
				_apply_gene_flags_to_projectile(p)
				_projectile_root.add_child(p)

		"orange":
			# 标准弹+命中溅射25%伤害，溅射半径50px
			var p: Projectile = _make_projectile(dir, base_dmg, range_px, Color(1.0, 0.6, 0.2))
			p.splash_damage = base_dmg * 0.25
			p.splash_radius = 50.0
			_apply_gene_flags_to_projectile(p)
			_projectile_root.add_child(p)

		"black":
			# 暴击率额外+15%，暴击时spawn一枚追踪副弹
			var p: Projectile = _make_projectile(dir, base_dmg, range_px, Color(0.4, 0.3, 0.6))
			p.crit_rate = _get_crit_rate() + 0.15   # 额外+15%暴击率
			p.crit_multiplier = _get_crit_multiplier()
			_apply_gene_flags_to_projectile(p)
			# 连接暴击副弹信号（复用 hit_enemy，在外部判断）
			p.hit_enemy.connect(_on_black_crit_sub_proj.bind(p))
			_projectile_root.add_child(p)
			return  # 已手动设置crit，跳过下方的_apply_crit

		"british":
			# 大弹体积+击退+命中减速20%，速度慢，伤害×1.1
			var p: Projectile = _make_projectile(dir, base_dmg * 1.1, range_px * 0.7, Color(0.75, 0.85, 1.0))
			p.speed = 260.0
			p.knockback_force = 120.0
			p.applies_slow_on_hit = true
			p.slow_duration = 1.5
			p.slow_amount = 0.2
			_apply_gene_flags_to_projectile(p)
			_projectile_root.add_child(p)

		_:
			# tabby（默认）：标准直线弹
			var p: Projectile = _make_projectile(dir, base_dmg, range_px, Color(1.0, 0.95, 0.75))
			_apply_gene_flags_to_projectile(p)
			_projectile_root.add_child(p)

func _on_black_crit_sub_proj(_proj: Projectile, _hit_enemy: Node) -> void:
	# black品种：每次命中有暴击率概率生成追踪副弹（50%伤害）
	if randf() > _proj.crit_rate or _projectile_root == null:
		return
	var target := _get_nearest_enemy()
	if target == null:
		return
	var sub_dir := (target.global_position - _proj.global_position).normalized()
	var sub: Projectile = _make_projectile(sub_dir, _proj.damage * 0.5, 300.0, Color(0.7, 0.3, 1.0))
	sub.is_homing = true
	sub.homing_target = target
	sub.is_chain_projectile = true
	_projectile_root.add_child(sub)

func _fire_weapon_cards() -> void:
	if _owner_cat == null:
		return
	var dyn_attack := float(_owner_cat.get("attack")) * (1.0 + _dyn_attack_bonus)
	var idx := 0
	for card: CardData in _weapon_cards:
		var stack_scale := 1.0 + GameConstants.BATTLE_WEAPON_STACK_BONUS * float(max(card.stack_count - 1, 0))
		var dir: Vector2 = _owner_cat.call("get_attack_direction")
		var angle_offset := deg_to_rad(float(idx - _weapon_cards.size() / 2.0) * GameConstants.BATTLE_WEAPON_SPREAD_DEGREES)
		dir = dir.rotated(angle_offset)
		var projectile: Projectile = _make_projectile(
			dir,
			dyn_attack * GameConstants.BATTLE_WEAPON_DAMAGE_MULT * stack_scale,
			float(_owner_cat.get("attack_range")) * GameConstants.BATTLE_TILE_SIZE,
			_color_by_rarity(card.rarity)
		)
		_apply_gene_flags_to_projectile(projectile)
		_projectile_root.add_child(projectile)
		idx += 1

func _make_projectile(dir: Vector2, dmg: float, range_px: float, color: Color) -> Projectile:
	var p: Projectile = ProjectileScene.instantiate()
	p.global_position = _owner_cat.global_position
	p.setup(dir, dmg, range_px, color)
	_apply_crit_to_projectile(p)
	return p

func _apply_gene_flags_to_projectile(projectile: Projectile) -> void:
	if _has_curious_lockon:
		projectile.is_homing = true
		projectile.homing_target = _get_nearest_enemy()
	if _has_cold_paw:
		projectile.applies_slow = true
		projectile.slow_duration = 2.0
		projectile.slow_amount = 0.4
	if _has_hunter_instinct:
		projectile.hunter_bonus = 0.25
	if _has_chain_hit:
		projectile.hit_enemy.connect(_on_chain_hit_trigger.bind(projectile))

func _on_chain_hit_trigger(proj: Projectile, hit_enemy_node: Node) -> void:
	if randf() > 0.25 or _enemies_root == null or _projectile_root == null:
		return
	var best_target: Node2D = null
	var best_dist: float = 150.0
	for child: Node in _enemies_root.get_children():
		if child == hit_enemy_node or not (child is Node2D):
			continue
		var dist := (child as Node2D).global_position.distance_to(proj.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = child
	if best_target == null:
		return
	var chain: Projectile = _make_projectile(
		(best_target.global_position - proj.global_position).normalized(),
		proj.damage * 0.6, 200.0,
		proj.projectile_color.lightened(0.2)
	)
	chain.is_chain_projectile = true
	chain.applies_slow = proj.applies_slow
	chain.hunter_bonus = proj.hunter_bonus
	chain.global_position = proj.global_position
	_projectile_root.add_child(chain)

func _get_nearest_enemy() -> Node2D:
	if _enemies_root == null or _owner_cat == null:
		return null
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for child: Node in _enemies_root.get_children():
		if not (child is Node2D):
			continue
		var dist := _owner_cat.global_position.distance_squared_to((child as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = child
	return nearest

func _color_by_rarity(rarity: String) -> Color:
	match rarity:
		"blue":   return Color(0.45, 0.7, 1.0, 1.0)
		"purple": return Color(0.8, 0.5, 1.0, 1.0)
		_:        return Color(1.0, 0.86, 0.45, 1.0)

