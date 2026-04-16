class_name WeaponSystem
extends Node

const GameConstants := preload("res://data/constants.gd")
const CardData := preload("res://resources/CardData.gd")
const ProjectileScene := preload("res://scenes/battle/entities/Projectile.tscn")

var _owner_cat: Node2D = null
var _projectile_root: Node2D = null
var _battle_paused: bool = false

var _basic_attack_timer: float = 0.0
var _weapon_attack_timer: float = 0.0

var _weapon_cards: Array[CardData] = []

func set_owner_cat(cat: Node2D) -> void:
	_owner_cat = cat

func set_projectile_root(root: Node2D) -> void:
	_projectile_root = root

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused

func _process(delta: float) -> void:
	if _battle_paused or _owner_cat == null or _projectile_root == null:
		return
	_basic_attack_timer -= delta
	_weapon_attack_timer -= delta
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
	var attack_value: float = float(_owner_cat.get("attack"))
	var range_tiles: float = GameConstants.BATTLE_BASIC_CLAW_RANGE_TILES
	var attack_range: float = max(float(_owner_cat.get("attack_range")), range_tiles)
	var projectile := ProjectileScene.instantiate()
	projectile.global_position = _owner_cat.global_position
	projectile.setup(
		_owner_cat.call("get_attack_direction"),
		attack_value * GameConstants.BATTLE_BASIC_CLAW_DAMAGE_MULT,
		attack_range * GameConstants.BATTLE_TILE_SIZE,
		Color(1.0, 0.95, 0.75, 1.0)
	)
	projectile.hit_enemy.connect(_on_projectile_hit_enemy)
	_projectile_root.add_child(projectile)

func _fire_weapon_cards() -> void:
	if _owner_cat == null:
		return
	var idx := 0
	for card: CardData in _weapon_cards:
		var stack_scale := 1.0 + GameConstants.BATTLE_WEAPON_STACK_BONUS * float(max(card.stack_count - 1, 0))
		var projectile := ProjectileScene.instantiate()
		projectile.global_position = _owner_cat.global_position
		var dir: Vector2 = _owner_cat.call("get_attack_direction")
		var angle_offset := deg_to_rad(float(idx - _weapon_cards.size() / 2.0) * GameConstants.BATTLE_WEAPON_SPREAD_DEGREES)
		dir = dir.rotated(angle_offset)
		projectile.setup(
			dir,
			float(_owner_cat.get("attack")) * GameConstants.BATTLE_WEAPON_DAMAGE_MULT * stack_scale,
			float(_owner_cat.get("attack_range")) * GameConstants.BATTLE_TILE_SIZE,
			_color_by_rarity(card.rarity)
		)
		projectile.hit_enemy.connect(_on_projectile_hit_enemy)
		_projectile_root.add_child(projectile)
		idx += 1

func _on_projectile_hit_enemy(projectile: Node, enemy: Node) -> void:
	if enemy != null and enemy.has_method("take_damage"):
		enemy.call("take_damage", float(projectile.damage))

func _color_by_rarity(rarity: String) -> Color:
	match rarity:
		"blue":
			return Color(0.45, 0.7, 1.0, 1.0)
		"purple":
			return Color(0.8, 0.5, 1.0, 1.0)
		_:
			return Color(1.0, 0.86, 0.45, 1.0)
