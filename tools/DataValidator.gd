extends SceneTree

const WeaponCards := preload("res://data/cards/weapon_cards.gd")
const BuffCards := preload("res://data/cards/buff_cards.gd")
const EnemyData := preload("res://data/enemies/enemy_data.gd")
const QuestionEvents := preload("res://data/question_events.gd")
const GameConstants := preload("res://data/constants.gd")

const ENEMY_FILES := [
	"res://data/enemies/base_enemies.json",
	"res://data/enemies/elite_enemies.json",
	"res://data/enemies/bosses.json",
]

const QUESTION_EFFECT_TYPES := {
	"immediate_coins": true,
	"immediate_hp_pct": true,
	"buff_attack": true,
	"buff_crit_rate": true,
	"buff_crit_mult": true,
	"buff_move_speed": true,
	"buff_aspd": true,
	"buff_max_hp": true,
	"next_battle_dmg_taken": true,
	"buff_regen_per_battle": true,
	"buff_immunity_next_debuff": true,
	"stray_cat": true,
	"stray_cat_injured": true,
	"unknown_buff": true,
	"unknown_good_or_bad": true,
	"gain_card_rarity": true,
	"exchange_card": true,
	"discard_worst_card": true,
	"lose_random_buff": true,
	"gamble_all_coins": true,
	"gamble_small": true,
	"gain_active_gene": true,
}

var _errors: PackedStringArray = []

func _init() -> void:
	_validate_cards()
	_validate_enemy_json()
	_validate_question_events()
	_validate_constants()
	if _errors.is_empty():
		print("[DataValidator] OK")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
		print("[DataValidator] " + error)
	quit(1)

func _validate_cards() -> void:
	var seen: Dictionary = {}
	_validate_card_pool("weapon", WeaponCards.get_pool(), seen)
	_validate_card_pool("buff", BuffCards.get_pool(), seen)

func _validate_card_pool(expected_type: String, pool: Array[Dictionary], seen: Dictionary) -> void:
	for def: Dictionary in pool:
		var id: String = str(def.get("id", ""))
		_require(not id.is_empty(), "%s card has empty id" % expected_type)
		_require(not seen.has(id), "Duplicate card id: %s" % id)
		seen[id] = true
		_require(str(def.get("card_type", "")) == expected_type, "Card %s has wrong card_type" % id)
		_require(not str(def.get("name", "")).is_empty(), "Card %s missing name" % id)
		_require(GameConstants.SHOP_CARD_PRICE.has(str(def.get("rarity", ""))), "Card %s has unknown rarity" % id)
		if expected_type == "buff":
			_require(not str(def.get("effect_key", "")).is_empty(), "Buff card %s missing effect_key" % id)
			_require(float(def.get("per_stack", 0.0)) > 0.0, "Buff card %s has non-positive per_stack" % id)

func _validate_enemy_json() -> void:
	var seen: Dictionary = {}
	for path: String in ENEMY_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		_require(file != null, "Cannot open enemy data file: %s" % path)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		_require(parsed is Dictionary, "Enemy data file is not a dictionary: %s" % path)
		if not (parsed is Dictionary):
			continue
		for enemy_id: String in (parsed as Dictionary).keys():
			_require(not seen.has(enemy_id), "Duplicate enemy id: %s" % enemy_id)
			seen[enemy_id] = true
			var enemy: Dictionary = parsed[enemy_id]
			_validate_enemy(enemy_id, enemy)
	var merged: Dictionary = EnemyData.get_enemy_definitions()
	_require(merged.size() == seen.size(), "Merged enemy data count mismatch")

func _validate_enemy(enemy_id: String, enemy: Dictionary) -> void:
	_require(not str(enemy.get("display_name", "")).is_empty(), "Enemy %s missing display_name" % enemy_id)
	_require(float(enemy.get("hp", 0.0)) > 0.0, "Enemy %s has non-positive hp" % enemy_id)
	_require(float(enemy.get("damage", 0.0)) >= 0.0, "Enemy %s has negative damage" % enemy_id)
	_require(float(enemy.get("move_speed", 0.0)) > 0.0, "Enemy %s has non-positive move_speed" % enemy_id)
	_require(int(enemy.get("fish_drop", -1)) >= 0, "Enemy %s has negative fish_drop" % enemy_id)

func _validate_question_events() -> void:
	var seen: Dictionary = {}
	for event: Dictionary in QuestionEvents.get_all_events():
		var id: String = str(event.get("id", ""))
		_require(not id.is_empty(), "Question event has empty id")
		_require(not seen.has(id), "Duplicate question event id: %s" % id)
		seen[id] = true
		_require(not str(event.get("title", "")).is_empty(), "Question event %s missing title" % id)
		var choices: Array = event.get("choices", [])
		_require(choices.size() >= 2 and choices.size() <= 3, "Question event %s should have 2-3 choices" % id)
		for choice in choices:
			_validate_question_choice(id, choice)

func _validate_question_choice(event_id: String, choice) -> void:
	_require(choice is Dictionary, "Question event %s has non-dictionary choice" % event_id)
	if not (choice is Dictionary):
		return
	_require(not str(choice.get("label", "")).is_empty(), "Question event %s has choice without label" % event_id)
	var effects: Array = choice.get("effects", [])
	_require(not effects.is_empty(), "Question event %s choice has no effects" % event_id)
	for effect in effects:
		_require(effect is Dictionary, "Question event %s has non-dictionary effect" % event_id)
		if not (effect is Dictionary):
			continue
		var effect_type: String = str(effect.get("type", ""))
		_require(QUESTION_EFFECT_TYPES.has(effect_type), "Question event %s has unknown effect type: %s" % [event_id, effect_type])

func _validate_constants() -> void:
	_require(GameConstants.EXPEDITION_TOTAL_LAYERS == 6, "EXPEDITION_TOTAL_LAYERS should match design doc")
	_require(GameConstants.EXPEDITION_BOSS_LAYER == 6, "EXPEDITION_BOSS_LAYER should match design doc")
	_require(GameConstants.BATTLE_NORMAL_DURATION == 90.0, "BATTLE_NORMAL_DURATION should match design doc")
	_require(GameConstants.BATTLE_FISH_XP_BASE == 5, "BATTLE_FISH_XP_BASE should match design doc")
	_require(GameConstants.BATTLE_FISH_XP_INCREMENT == 10, "BATTLE_FISH_XP_INCREMENT should match design doc")
	_require(GameConstants.GENE_CHOICE_LEVELS == [5, 10, 15], "GENE_CHOICE_LEVELS should be Lv5/10/15")

func _require(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
