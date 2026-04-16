class_name SpawnManager
extends Node

const GameConstants := preload("res://data/constants.gd")
const EnemyData := preload("res://data/enemies/enemy_data.gd")
const EnemyScene := preload("res://scenes/battle/entities/Enemy.tscn")

signal enemy_defeated(enemy_type: String, fish_drop: int, position: Vector2)
signal boss_spawned(enemy: Node)
signal elite_spawned(enemy: Node)

var _battle_node_type: String = "battle_normal"
var _enemies_root: Node2D = null
var _player_cat: Node2D = null
var _elapsed: float = 0.0
var _battle_paused: bool = false

var _opening_wave_index: int = 0
var _regular_spawn_cd: float = 3.5
var _elite_spawned: bool = false
var _boss_spawned_once: bool = false

var _enemy_defs: Dictionary = {}

func _ready() -> void:
	_enemy_defs = EnemyData.get_enemy_definitions()

func configure(node_type: String, enemies_root: Node2D, player_cat: Node2D) -> void:
	_battle_node_type = node_type
	_enemies_root = enemies_root
	_player_cat = player_cat
	_elapsed = 0.0
	_opening_wave_index = 0
	_regular_spawn_cd = 3.5
	_elite_spawned = false
	_boss_spawned_once = false

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused

func _process(delta: float) -> void:
	if _battle_paused or _enemies_root == null or _player_cat == null:
		return
	_elapsed += delta
	_process_opening_waves()
	match _battle_node_type:
		"battle_elite":
			_process_elite_mode(delta)
		"battle_boss":
			_process_boss_mode()
		_:
			_process_normal_mode(delta)

func _process_opening_waves() -> void:
	while _opening_wave_index < GameConstants.BATTLE_OPENING_WAVES.size():
		var wave: Dictionary = GameConstants.BATTLE_OPENING_WAVES[_opening_wave_index]
		if _elapsed < float(wave.get("time", 0.0)):
			break
		_spawn_enemy_group("small_monkey", int(wave.get("small_monkey", 0)))
		_spawn_enemy_group("stone_monkey", int(wave.get("stone_monkey", 0)))
		_opening_wave_index += 1

func _process_normal_mode(delta: float) -> void:
	_regular_spawn_cd -= delta
	if _regular_spawn_cd > 0.0:
		return
	_regular_spawn_cd = randf_range(2.8, 4.2)
	var roll := randf()
	if roll < 0.55:
		_spawn_enemy_group("small_monkey", randi_range(2, 4))
	elif roll < 0.75:
		_spawn_enemy_group("stone_monkey", randi_range(1, 3))
	elif roll < 0.9:
		_spawn_enemy_group("monkey_swarm", 5)
	else:
		_spawn_enemy_group("tank_gorilla", 1)

func _process_elite_mode(delta: float) -> void:
	if not _elite_spawned:
		_elite_spawned = true
		var elite := _spawn_enemy("elite_monkey")
		if elite != null:
			elite_spawned.emit(elite)
	_regular_spawn_cd -= delta
	if _regular_spawn_cd > 0.0:
		return
	_regular_spawn_cd = randf_range(3.0, 4.8)
	_spawn_enemy_group("small_monkey", randi_range(1, 3))
	_spawn_enemy_group("stone_monkey", randi_range(0, 2))

func _process_boss_mode() -> void:
	if _boss_spawned_once:
		return
	_boss_spawned_once = true
	var boss := _spawn_enemy("boss_gorilla_king")
	if boss != null:
		boss_spawned.emit(boss)

func _spawn_enemy_group(enemy_id: String, count: int) -> void:
	for _i in count:
		_spawn_enemy(enemy_id)

func _spawn_enemy(enemy_id: String) -> Node:
	if _enemies_root == null or _player_cat == null:
		return null
	var raw: Dictionary = _enemy_defs.get(enemy_id, {})
	if raw.is_empty():
		return null
	var def: Dictionary = raw.duplicate(true)
	def["id"] = enemy_id
	var enemy := EnemyScene.instantiate()
	enemy.global_position = _random_spawn_pos()
	enemy.setup(def, _player_cat)
	enemy.died.connect(_on_enemy_died)
	_enemies_root.add_child(enemy)
	return enemy

func _on_enemy_died(enemy_type: String, fish_drop: int, world_position: Vector2) -> void:
	enemy_defeated.emit(enemy_type, fish_drop, world_position)

func _random_spawn_pos() -> Vector2:
	var center := _player_cat.global_position
	var radius := randf_range(260.0, 380.0)
	var angle := randf_range(0.0, TAU)
	return center + Vector2.RIGHT.rotated(angle) * radius
