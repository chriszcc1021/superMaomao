extends Node2D

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CardData := preload("res://resources/CardData.gd")
const WeaponCards := preload("res://data/cards/weapon_cards.gd")
const BuffCards := preload("res://data/cards/buff_cards.gd")

@onready var _player_cat: Node2D = $World/PlayerCat
@onready var _enemies_root: Node2D = $World/Enemies
@onready var _projectiles_root: Node2D = $World/Projectiles
@onready var _spawn_manager: Node = $SpawnManager
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: Control = $UI/BattleHUD
@onready var _card_select: Control = $UI/CardSelectUI

var _node_type: String = "battle_normal"
var _selected_cat: CatData = null
var _battle_over: bool = false
var _battle_paused: bool = false
var _battle_time_left: float = GameConstants.BATTLE_NORMAL_DURATION

var _level: int = 1
var _fish: int = 0
var _xp_to_next: int = int(GameConstants.LEVEL_UP_XP[0])
var _cards: Array[CardData] = []
var _card_by_id: Dictionary = {}
var _card_meta_by_id: Dictionary = {}
var _active_genes_gained: Array[String] = []
var _active_gene_level_grants: Dictionary = {}

var _elite_target: Node = null
var _boss_target: Node = null

func _ready() -> void:
	randomize()
	_node_type = _get_scene_manager().last_battle_node_type if _get_scene_manager() != null else "battle_normal"
	_selected_cat = _resolve_selected_cat()
	_setup_player()
	_setup_spawn()
	_setup_card_select()
	_set_timer_by_node_type()
	_refresh_hud()
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.battle_started.emit()

func _process(delta: float) -> void:
	if _battle_over or _battle_paused:
		return
	# 摄像机跟随玩家
	_camera.global_position = _player_cat.global_position
	if _battle_time_left > 0.0:
		_battle_time_left = max(_battle_time_left - delta, 0.0)
		if _battle_time_left <= 0.0:
			_finish_battle(true)
			return
	if _node_type == "battle_elite" and _elite_target != null and not is_instance_valid(_elite_target):
		_finish_battle(true)
		return
	if _node_type == "battle_boss" and _boss_target != null and not is_instance_valid(_boss_target):
		_finish_battle(true)
		return
	_refresh_hud()

func _setup_player() -> void:
	_player_cat.setup(_selected_cat, _enemies_root)
	_player_cat.hp_changed.connect(_on_player_hp_changed)
	_player_cat.died.connect(_on_player_died)
	var weapon_system: Node = _player_cat.get_weapon_system()
	weapon_system.set_projectile_root(_projectiles_root)
	_camera.position = _player_cat.global_position

func _setup_spawn() -> void:
	_spawn_manager.configure(_node_type, _enemies_root, _player_cat)
	_spawn_manager.enemy_defeated.connect(_on_enemy_defeated)
	_spawn_manager.elite_spawned.connect(_on_elite_spawned)
	_spawn_manager.boss_spawned.connect(_on_boss_spawned)

func _setup_card_select() -> void:
	_card_select.card_chosen.connect(_on_card_chosen)

func _set_timer_by_node_type() -> void:
	match _node_type:
		"battle_elite":
			_battle_time_left = randf_range(GameConstants.BATTLE_ELITE_DURATION_MIN, GameConstants.BATTLE_ELITE_DURATION_MAX)
		"battle_boss":
			_battle_time_left = -1.0
		_:
			_battle_time_left = GameConstants.BATTLE_NORMAL_DURATION
	_xp_to_next = _xp_required_for_level(_level)

func _resolve_selected_cat() -> CatData:
	var game_state := _get_game_state()
	if game_state == null:
		return CatData.new()
	for cat: CatData in game_state.cats:
		if cat.id == game_state.expedition_cat_id:
			return cat
	if not game_state.cats.is_empty():
		return game_state.cats[0]
	return CatData.new()

func _on_enemy_defeated(_enemy_type: String, fish_drop: int, _pos: Vector2) -> void:
	_gain_fish(fish_drop)

func _on_elite_spawned(enemy: Node) -> void:
	_elite_target = enemy

func _on_boss_spawned(enemy: Node) -> void:
	_boss_target = enemy

func _gain_fish(amount: int) -> void:
	_fish += amount
	while _fish >= _xp_to_next:
		_fish -= _xp_to_next
		_level += 1
		_xp_to_next = _xp_required_for_level(_level)
		_on_level_up()
	_refresh_hud()

func _on_level_up() -> void:
	_grant_active_gene_by_level()
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.player_leveled_up.emit(_level)
	var first_level_up := _level == 2 and GameConstants.FIRST_LEVEL_WEAPON_ONLY
	var choices := _roll_cards(first_level_up)
	if choices.is_empty():
		return
	_pause_battle_for_card_select(choices, first_level_up)

func _pause_battle_for_card_select(choices: Array[CardData], first_level_up: bool) -> void:
	_battle_paused = true
	_player_cat.set_battle_paused(true)
	_spawn_manager.set_battle_paused(true)
	var title := "首次升级" if first_level_up else "升级选卡"
	var desc := "Lv1→2 仅出现武器卡。" if first_level_up else "请选择一张卡牌。"
	_card_select.show_choices(choices, title, desc)

func _on_card_chosen(card: CardData) -> void:
	_apply_card(card)
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.card_selected.emit(card)
	_card_select.hide_panel()
	_battle_paused = false
	_player_cat.set_battle_paused(false)
	_spawn_manager.set_battle_paused(false)
	_refresh_hud()

func _apply_card(card: CardData) -> void:
	var existing: CardData = _card_by_id.get(card.id, null)
	if existing == null:
		_cards.append(card)
		_card_by_id[card.id] = card
		existing = card
	elif (existing as CardData).can_stack():
		(existing as CardData).add_stack()

	if card.card_type == "weapon":
		_player_cat.get_weapon_system().apply_weapon_card(existing)
		return

	var meta: Dictionary = _card_meta_by_id.get(card.id, {})
	var effect_key: String = str(meta.get("effect_key", ""))
	var per_stack: float = float(meta.get("per_stack", 0.0))
	if not effect_key.is_empty() and per_stack > 0.0:
		_player_cat.apply_buff(effect_key, per_stack)

func _roll_cards(force_weapon_only: bool) -> Array[CardData]:
	var weapon_defs: Array[Dictionary] = WeaponCards.get_pool()
	var buff_defs: Array[Dictionary] = BuffCards.get_pool()
	var available: Array[Dictionary] = []

	for def: Dictionary in weapon_defs:
		if _can_offer_weapon(def):
			available.append(def)
	if not force_weapon_only:
		for def: Dictionary in buff_defs:
			available.append(def)
	if available.is_empty():
		return []

	available.shuffle()
	var result: Array[CardData] = []
	for def: Dictionary in available:
		var card := _build_card(def)
		result.append(card)
		if result.size() >= GameConstants.BATTLE_CARD_CHOICE_COUNT:
			break
	return result

func _can_offer_weapon(def: Dictionary) -> bool:
	var id: String = str(def.get("id", ""))
	if _card_by_id.has(id):
		var existing: CardData = _card_by_id[id]
		return existing.can_stack()
	var weapon_count := 0
	for card: CardData in _cards:
		if card.card_type == "weapon":
			weapon_count += 1
	return weapon_count < GameConstants.BATTLE_WEAPON_SLOT_CAP

func _build_card(def: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = str(def.get("id", ""))
	card.card_name = str(def.get("name", "card"))
	card.card_type = str(def.get("card_type", "weapon"))
	card.rarity = str(def.get("rarity", "grey"))
	card.description = str(def.get("description", ""))
	card.max_stacks = int(def.get("max_stacks", 3))
	_card_meta_by_id[card.id] = def
	return card

func _grant_active_gene_by_level() -> void:
	if not [_level == 5, _level == 10, _level == 15].has(true):
		return
	if _active_gene_level_grants.has(_level):
		return
	_active_gene_level_grants[_level] = true
	if GameConstants.ACTIVE_SKILL_GENE_POOL.is_empty():
		return
	var gene_id := str(GameConstants.ACTIVE_SKILL_GENE_POOL[randi() % GameConstants.ACTIVE_SKILL_GENE_POOL.size()])
	_active_genes_gained.append(gene_id)

func _xp_required_for_level(level: int) -> int:
	var idx := level - 1
	if idx < GameConstants.LEVEL_UP_XP.size():
		return int(GameConstants.LEVEL_UP_XP[idx])
	var overflow := idx - GameConstants.LEVEL_UP_XP.size() + 1
	return int(GameConstants.LEVEL_UP_XP[-1]) + overflow * int(GameConstants.LEVEL_UP_XP_INCREMENT_AFTER_TABLE)

func _on_player_hp_changed(_cur: float, _max: float) -> void:
	_refresh_hud()

func _on_player_died() -> void:
	_finish_battle(false)

func _refresh_hud() -> void:
	var timer_text := "时间: --"
	if _battle_time_left >= 0.0:
		timer_text = "时间: %d秒" % int(ceil(_battle_time_left))
	var cards_text := "已选卡牌:\n"
	if _cards.is_empty():
		cards_text += "无"
	else:
		for card: CardData in _cards:
			cards_text += "- %s x%d\n" % [card.card_name, card.stack_count]
	_hud.update_stats(
		_player_cat.current_hp,
		_player_cat.max_hp,
		_level,
		_fish,
		_xp_to_next,
		timer_text,
		cards_text
	)

func _finish_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	_battle_paused = true
	_player_cat.set_battle_paused(true)
	_spawn_manager.set_battle_paused(true)
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.battle_ended.emit(victory)
	var result := {
		"victory": victory,
		"battle_node_type": _node_type,
		"battle_wins": 1 if victory else 0,
		"active_genes_gained": _active_genes_gained.duplicate(),
		"level_reached": _level
	}
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.return_from_battle(result)
		return
	push_error("SceneManager is missing. Battle result cannot be returned safely.")

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")
