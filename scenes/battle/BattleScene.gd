extends Node2D

const FishItem      := preload("res://scenes/battle/entities/FishItem.gd")
const CatData       := preload("res://resources/CatData.gd")
const CardData      := preload("res://resources/CardData.gd")
const GameConstants := preload("res://data/constants.gd")
const BattleCardControllerScript := preload("res://scenes/battle/BattleCardController.gd")
const BattleExpeditionBuffsScript := preload("res://scenes/battle/BattleExpeditionBuffs.gd")
const BattleResultBuilderScript := preload("res://scenes/battle/BattleResultBuilder.gd")
const BattleGeneSelectorScript := preload("res://scenes/battle/BattleGeneSelector.gd")
const BattleGenePopupControllerScript := preload("res://scenes/battle/BattleGenePopupController.gd")

@onready var _player_cat: Node2D = $World/PlayerCat
@onready var _enemies_root: Node2D = $World/Enemies
@onready var _projectiles_root: Node2D = $World/Projectiles
@onready var _spawn_manager: Node = $SpawnManager
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: Control = $UI/BattleHUD
@onready var _card_select: Control = $UI/CardSelectUI

var _node_type: String = "battle_normal"
var _selected_cat: CatData = null
var _selected_cat_source: CatData = null
var _battle_over: bool = false
var _battle_paused: bool = false
var _battle_failed_by_death: bool = false
var _battle_time_left: float = GameConstants.BATTLE_NORMAL_DURATION

# 等级系统：直接映射猫的永久等级
var _level: int = 1
var _fish: int = 0        # 当前等级内已积累 XP
var _xp_to_next: int = 0
var _card_controller = BattleCardControllerScript.new()
var _expedition_buffs = BattleExpeditionBuffsScript.new()
var _result_builder = BattleResultBuilderScript.new()
var _gene_selector = BattleGeneSelectorScript.new()
var _gene_popup_controller = BattleGenePopupControllerScript.new()
var _active_genes_gained: Array[String] = []  # 本场战斗中写入基因槽的基因

var _elite_target: Node = null
var _boss_target: Node = null
var _dmg_taken_modifier: float = 1.0  # 奇遇 buff：下一场受到伤害倍率

# 基因选择弹窗
var _gene_popup: Control = null
var _pending_card_choices: Array[CardData] = []
var _pending_first_level_up: bool = false

func _ready() -> void:
	randomize()
	_node_type = _get_scene_manager().last_battle_node_type if _get_scene_manager() != null else "battle_normal"
	_selected_cat_source = _resolve_selected_cat()
	_selected_cat = _create_battle_cat_copy(_selected_cat_source)
	_setup_player()
	_setup_spawn()
	_setup_card_select()
	_set_timer_by_node_type()
	_load_shop_cards()
	_refresh_hud()
	# 进入战斗 → 远征时间模式
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.set_expedition_mode(true)
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.battle_started.emit()

func _load_shop_cards() -> void:
	_card_controller.load_shop_cards(_get_game_state(), _player_cat)

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
	# 读取猫的基因槽，激活技能
	_setup_cat_genes()
	# 应用远征途中获得的 buff（奇遇事件等）
	_apply_expedition_buffs()

func _setup_cat_genes() -> void:
	if _selected_cat == null:
		return
	var genes: Array[String] = []
	for slot_gene: String in [_selected_cat.gene_slot_1, _selected_cat.gene_slot_2, _selected_cat.gene_slot_3]:
		if not slot_gene.is_empty():
			genes.append(slot_gene)
	if not genes.is_empty():
		_player_cat.setup_genes(genes)
	# 品种差异化基础爪击
	var weapon_system: Node = _player_cat.get_weapon_system()
	if weapon_system != null and weapon_system.has_method("setup_breed"):
		weapon_system.call("setup_breed", str(_selected_cat.breed))

func _cat_has_gene(gene_id: String) -> bool:
	if _selected_cat == null:
		return false
	return gene_id in [_selected_cat.gene_slot_1, _selected_cat.gene_slot_2, _selected_cat.gene_slot_3]

## 应用远征 buff（奇遇事件写入 expedition_buffs 的效果）
func _apply_expedition_buffs() -> void:
	_dmg_taken_modifier = _expedition_buffs.apply(
		_get_game_state(),
		_player_cat,
		_grant_bonus_card,
		_dmg_taken_modifier
	)

## 赠送一张稀有卡（继承遗志/仔细研究等）
func _grant_bonus_card() -> void:
	var cards := _roll_cards(false)
	if cards.is_empty():
		return
	# 取稀有度最高的
	cards.sort_custom(func(a, b): return a.rarity > b.rarity)
	_apply_card(cards[0])

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
	# 从猫的持久等级恢复；小鱼干是局内经验，每场战斗从0开始（设计文档§3.1：战斗结束后消失）
	_level = max(1, int(_selected_cat.level)) if _selected_cat != null else 1
	_fish = 0
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

func _create_battle_cat_copy(source: CatData) -> CatData:
	if source == null:
		return CatData.new()
	var copy := CatData.new()
	copy.id = source.id
	copy.cat_name = source.cat_name
	copy.sex = source.sex
	copy.breed = source.breed
	copy.profession = source.profession
	copy.status = GameConstants.LIFECYCLE_STATUS_IDLE
	copy.health = source.health
	copy.age_days = source.age_days
	copy.has_expeditioned = source.has_expeditioned
	copy.breed_count = source.breed_count
	copy.assigned_building = source.assigned_building
	copy.level = source.level
	copy.xp = source.xp
	copy.gene_head = source.gene_head
	copy.gene_ear = source.gene_ear
	copy.gene_eye_color = source.gene_eye_color
	copy.gene_eye_shape = source.gene_eye_shape
	copy.gene_fur_main = source.gene_fur_main
	copy.gene_fur_accent = source.gene_fur_accent
	copy.gene_pattern = source.gene_pattern
	copy.gene_tail = source.gene_tail
	copy.gene_slot_1 = source.gene_slot_1
	copy.gene_slot_2 = source.gene_slot_2
	copy.gene_slot_3 = source.gene_slot_3
	copy.calculate_stats()
	return copy

func _on_enemy_defeated(enemy_type: String, fish_drop: int, pos: Vector2) -> void:
	# 生成小鱼干掉落物
	if fish_drop > 0:
		var item := FishItem.new()
		item.global_position = pos
		item.amount = fish_drop
		item._player = _player_cat
		item.collected.connect(_on_fish_collected)
		_projectiles_root.add_child(item)
	# battle_frenzy：击杀触发攻速叠层
	if _player_cat != null and _player_cat.has_method("register_kill"):
		_player_cat.register_kill()
	# cleanup_blast：击杀产生爆炸
	if _cat_has_gene("cleanup_blast") and _player_cat != null:
		_spawn_cleanup_blast(pos)

func _spawn_cleanup_blast(center: Vector2) -> void:
	var blast_radius := 80.0
	var blast_damage := float(_player_cat.get("attack")) * 0.5
	for enemy: Node in _enemies_root.get_children():
		if enemy is Node2D:
			var dist := center.distance_to((enemy as Node2D).global_position)
			if dist <= blast_radius and enemy.has_method("take_damage"):
				enemy.call("take_damage", blast_damage)
	# 简单爆炸视觉：临时颜色圆圈（Node2D + _draw）
	var flash := Node2D.new()
	flash.global_position = center
	_enemies_root.get_parent().add_child(flash)
	flash.set_script(null)
	# 用 create_tween 延迟删除
	var tw := flash.create_tween()
	tw.tween_callback(flash.queue_free).set_delay(0.15)

func _on_fish_collected(amount: int) -> void:
	_gain_fish(amount)

func _on_elite_spawned(enemy: Node) -> void:
	_elite_target = enemy

func _on_boss_spawned(enemy: Node) -> void:
	_boss_target = enemy

func _gain_fish(amount: int) -> void:
	_fish += amount
	# 检查是否升级（支持连续多级）
	while _level < GameConstants.CAT_LEVEL_CAP and _fish >= _xp_to_next:
		_fish -= _xp_to_next
		_level += 1
		_xp_to_next = _xp_required_for_level(_level)
		_on_level_up()
		# 升级后如果弹窗出现，中断循环（等玩家操作完再继续）
		if _battle_paused:
			break
	_refresh_hud()

func _on_level_up() -> void:
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.player_leveled_up.emit(_level)
	var first_level_up := _level == 2 and GameConstants.FIRST_LEVEL_WEAPON_ONLY
	var choices := _roll_cards(first_level_up)

	if GameConstants.GENE_CHOICE_LEVELS.has(_level):
		_pending_card_choices = choices
		_pending_first_level_up = first_level_up
		_show_gene_choice_popup()
	elif not choices.is_empty():
		_pause_battle_for_card_select(choices, first_level_up)

func _pause_battle_for_card_select(choices: Array[CardData], first_level_up: bool) -> void:
	_battle_paused = true
	_player_cat.set_battle_paused(true)
	_spawn_manager.set_battle_paused(true)
	# 冻结场上所有已有敌人
	_set_enemies_paused(true)
	var title := "首次升级" if first_level_up else "升级选卡"
	var desc := "Lv1→2 仅出现武器卡。" if first_level_up else "请选择一张卡牌。"
	_card_select.show_choices(choices, title, desc)

func _set_enemies_paused(paused: bool) -> void:
	for child: Node in _enemies_root.get_children():
		if child.has_method("set_battle_paused"):
			child.set_battle_paused(paused)

func _on_card_chosen(card: CardData) -> void:
	_apply_card(card)
	# resonance_stack：每选一张卡，所有已持有buff卡效果+5%
	if _cat_has_gene("resonance_stack"):
		_apply_resonance_boost()
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.card_selected.emit(card)
	_card_select.hide_panel()
	_battle_paused = false
	_player_cat.set_battle_paused(false)
	_spawn_manager.set_battle_paused(false)
	# 恢复场上所有敌人
	_set_enemies_paused(false)
	_refresh_hud()

func _apply_resonance_boost() -> void:
	_card_controller.apply_resonance_boost()

func _apply_card(card: CardData) -> void:
	_card_controller.apply_card(card, _player_cat)

func _roll_cards(force_weapon_only: bool) -> Array[CardData]:
	return _card_controller.roll_cards(force_weapon_only)

## ──── 基因三选一弹窗 ────

func _roll_gene_choices() -> Array[String]:
	return _gene_selector.roll_choices(_selected_cat, _active_genes_gained)

func _cat_has_active_gene() -> bool:
	return _gene_selector.has_active_gene(_selected_cat, _active_genes_gained)

func _show_gene_choice_popup() -> void:
	_battle_paused = true
	_player_cat.set_battle_paused(true)
	_spawn_manager.set_battle_paused(true)
	_set_enemies_paused(true)

	var gene_choices := _roll_gene_choices()
	var cat_name: String = _selected_cat.cat_name if _selected_cat != null else "你的猫"
	_gene_popup = _gene_popup_controller.show_choice($UI, cat_name, _level, gene_choices, _on_gene_chosen)

func _on_gene_chosen(gene_id: String) -> void:
	if _gene_selector.write_to_empty_slot(_selected_cat, _active_genes_gained, gene_id):
		_close_gene_popup_and_continue()
		return
	_show_gene_replace_view(gene_id)

func _show_gene_replace_view(new_gene_id: String) -> void:
	var slot_genes: Array[String] = []
	for slot_idx in 3:
		slot_genes.append(_get_slot_gene(slot_idx))
	_gene_popup_controller.show_replace(
		_gene_popup,
		new_gene_id,
		slot_genes,
		_on_gene_replace_chosen,
		_on_gene_abandoned
	)

func _get_slot_gene(slot_idx: int) -> String:
	return _gene_selector.get_slot_gene(_selected_cat, slot_idx)

func _on_gene_replace_chosen(slot_idx: int, new_gene_id: String) -> void:
	_gene_selector.replace_slot(_selected_cat, _active_genes_gained, slot_idx, new_gene_id)
	_close_gene_popup_and_continue()

func _on_gene_abandoned() -> void:
	_close_gene_popup_and_continue()

func _close_gene_popup_and_continue() -> void:
	if _gene_popup != null:
		_gene_popup.queue_free()
		_gene_popup = null
	if not _pending_card_choices.is_empty():
		var card_choices: Array[CardData] = _pending_card_choices.duplicate()
		var first_level_up := _pending_first_level_up
		_pending_card_choices.clear()
		_pending_first_level_up = false
		_pause_battle_for_card_select(card_choices, first_level_up)
	else:
		_battle_paused = false
		_player_cat.set_battle_paused(false)
		_spawn_manager.set_battle_paused(false)
		_set_enemies_paused(false)

func _xp_required_for_level(level: int) -> int:
	# 设计文档§5.4：Lv1→2需5条，之后每级+10（5, 15, 25, 35...）
	return GameConstants.BATTLE_FISH_XP_BASE + (level - 1) * GameConstants.BATTLE_FISH_XP_INCREMENT

func _on_player_hp_changed(_cur: float, _max: float) -> void:
	_refresh_hud()

func _on_player_died() -> void:
	_battle_failed_by_death = true
	_finish_battle(false)

func _refresh_hud() -> void:
	var timer_text := "时间: --"
	if _battle_time_left >= 0.0:
		timer_text = "时间: %d秒" % int(ceil(_battle_time_left))
	var cards_text := "已选卡牌:\n"
	var cards: Array[CardData] = _card_controller.get_cards()
	if cards.is_empty():
		cards_text += "无"
	else:
		for card: CardData in cards:
			cards_text += "- %s x%d\n" % [card.card_name, card.stack_count]
	if _player_cat != null and _player_cat.has_method("set_xp_progress"):
		_player_cat.call("set_xp_progress", _fish, _xp_to_next)
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

	# 将本场战斗的等级和继承血量写回猫的持久数据；小鱼干不写回（局内消耗品）
	if _selected_cat_source != null:
		_selected_cat_source.level = _level
		# Model B：写回当前血量，供下一场战斗继承
		if _player_cat != null and is_instance_valid(_player_cat):
			_selected_cat_source.current_hp = _player_cat.current_hp
		# _selected_cat_source.xp = _fish  ← 移除：小鱼干战斗后消失（设计文档§3.1）

	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.battle_ended.emit(victory)
	var result: Dictionary = _result_builder.build(
		victory,
		_node_type,
		_active_genes_gained,
		_level,
		_battle_failed_by_death
	)
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.return_from_battle(result)
		# 回营地 → 恢复正常时间模式
		var tm := get_node_or_null("/root/TimeManager")
		if tm != null:
			tm.set_expedition_mode(false)
		return
	push_error("SceneManager is missing. Battle result cannot be returned safely.")

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")
