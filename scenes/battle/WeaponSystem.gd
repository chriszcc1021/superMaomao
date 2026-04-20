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

# ── 基因 flags ────────────────────────────────────
var _has_curious_lockon: bool = false   # 追踪弹道
var _has_cold_paw: bool = false         # 减速
var _has_chain_hit: bool = false        # 连锁打击
var _has_hunter_instinct: bool = false  # 精英+25%伤害
var _frenzy_bonus: float = 0.0          # battle_frenzy 攻速加成
var _dyn_aspd_bonus: float = 0.0        # survival_rush 动态攻速
var _dyn_attack_bonus: float = 0.0      # desperado 动态攻击
var _enemies_root: Node2D = null

func set_owner_cat(cat: Node2D) -> void:
	_owner_cat = cat

func set_projectile_root(root: Node2D) -> void:
	_projectile_root = root

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused

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

func _fire_basic_claw() -> void:
	if _owner_cat == null:
		return
	var attack_value: float = float(_owner_cat.get("attack")) * (1.0 + _dyn_attack_bonus)
	var range_tiles: float = GameConstants.BATTLE_BASIC_CLAW_RANGE_TILES
	var attack_range: float = max(float(_owner_cat.get("attack_range")), range_tiles)
	var projectile: Projectile = ProjectileScene.instantiate()
	projectile.global_position = _owner_cat.global_position
	projectile.setup(
		_owner_cat.call("get_attack_direction"),
		attack_value * GameConstants.BATTLE_BASIC_CLAW_DAMAGE_MULT,
		attack_range * GameConstants.BATTLE_TILE_SIZE,
		Color(1.0, 0.95, 0.75, 1.0)
	)
	_apply_gene_flags_to_projectile(projectile)
	_projectile_root.add_child(projectile)

func _fire_weapon_cards() -> void:
	if _owner_cat == null:
		return
	var dyn_attack := float(_owner_cat.get("attack")) * (1.0 + _dyn_attack_bonus)
	var idx := 0
	for card: CardData in _weapon_cards:
		var stack_scale := 1.0 + GameConstants.BATTLE_WEAPON_STACK_BONUS * float(max(card.stack_count - 1, 0))
		var projectile: Projectile = ProjectileScene.instantiate()
		projectile.global_position = _owner_cat.global_position
		var dir: Vector2 = _owner_cat.call("get_attack_direction")
		var angle_offset := deg_to_rad(float(idx - _weapon_cards.size() / 2.0) * GameConstants.BATTLE_WEAPON_SPREAD_DEGREES)
		dir = dir.rotated(angle_offset)
		projectile.setup(
			dir,
			dyn_attack * GameConstants.BATTLE_WEAPON_DAMAGE_MULT * stack_scale,
			float(_owner_cat.get("attack_range")) * GameConstants.BATTLE_TILE_SIZE,
			_color_by_rarity(card.rarity)
		)
		_apply_gene_flags_to_projectile(projectile)
		_projectile_root.add_child(projectile)
		idx += 1

func _apply_gene_flags_to_projectile(projectile: Projectile) -> void:
	# curious_lockon：追踪最近敌人
	if _has_curious_lockon:
		projectile.is_homing = true
		projectile.homing_target = _get_nearest_enemy()
	# cold_paw：减速
	if _has_cold_paw:
		projectile.applies_slow = true
		projectile.slow_duration = 2.0
		projectile.slow_amount = 0.4
	# hunter_instinct：精英+25%
	if _has_hunter_instinct:
		projectile.hunter_bonus = 0.25
	# chain_hit：连接 hit 信号以触发弹射
	if _has_chain_hit:
		projectile.hit_enemy.connect(_on_chain_hit_trigger.bind(projectile))

func _on_chain_hit_trigger(proj: Projectile, hit_enemy_node: Node) -> void:
	if randf() > 0.25 or _enemies_root == null or _projectile_root == null:
		return
	# 寻找弹射目标（150px内另一敌人）
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
	# 派生链式弹（伤害60%，不再次弹射）
	var chain: Projectile = ProjectileScene.instantiate()
	var dir := (best_target.global_position - proj.global_position).normalized()
	chain.is_chain_projectile = true
	chain.applies_slow = proj.applies_slow
	chain.hunter_bonus = proj.hunter_bonus
	chain.global_position = proj.global_position
	chain.setup(dir, proj.damage * 0.6, 200.0, proj.projectile_color.lightened(0.2))
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
