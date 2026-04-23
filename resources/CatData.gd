class_name CatData
extends Resource

const GameConstants := preload("res://data/constants.gd")

@export var id: String = ""
@export var cat_name: String = ""
@export var sex: String = GameConstants.SEX_FEMALE
@export var breed: String = "tabby"
@export var profession: String = "sniper"

@export var status: String = "idle"
@export var health: String = "healthy"
@export var age_days: int = 0
@export var has_expeditioned: bool = false
@export var breed_count: int = 0
@export var assigned_building: String = ""

# 永久等级系统（全游戏唯一经验池）
@export var level: int = 1
@export var xp: int = 0  # 当前等级内已积累 XP（满则升级归零）

# 继承血量（Model B）：-1 = 战斗开始时取满血；远征中跨战斗继承
@export var current_hp: float = -1.0

@export var gene_head: String = "round"
@export var gene_ear: String = "upright"
@export var gene_eye_color: String = "blue"
@export var gene_eye_shape: String = "round"
@export var gene_fur_main: String = "orange"
@export var gene_fur_accent: String = "none"
@export var gene_pattern: String = "none"
@export var gene_tail: String = "long"

@export var gene_slot_1: String = ""
@export var gene_slot_2: String = ""
@export var gene_slot_3: String = ""

var base_hp: float = 0.0
var base_attack: float = 0.0
var base_attack_speed: float = 0.0
var base_move_speed: float = 0.0
var base_range: float = 0.0
var base_crit_rate: float = 0.0
var base_crit_multiplier: float = 0.0
var base_defense: float = 0.0
var gold_multiplier: float = 1.0

func _init() -> void:
	calculate_stats()

func calculate_stats() -> void:
	var hp_from_appearance: float = _float_value(GameConstants.HEAD_HP, gene_head, 200.0)
	var attack_from_appearance: float = _float_value(GameConstants.FUR_MAIN_ATTACK, gene_fur_main, 12.0)
	var attack_speed_from_appearance: float = _float_value(GameConstants.TAIL_ATTACK_SPEED, gene_tail, 0.8)
	var range_from_appearance: float = _float_value(GameConstants.EAR_RANGE, gene_ear, 3.0)
	var crit_rate_from_appearance: float = _float_value(GameConstants.EYE_COLOR_CRIT, gene_eye_color, 0.05)
	var crit_mult_from_appearance: float = _float_value(GameConstants.EYE_SHAPE_CRIT_MULT, gene_eye_shape, 1.5)
	gold_multiplier = _float_value(GameConstants.FUR_ACCENT_GOLD_MULT, gene_fur_accent, 1.0)

	var breed_mod: Dictionary = GameConstants.BREED_MODIFIERS.get(breed, GameConstants.BREED_MODIFIERS["tabby"])
	hp_from_appearance *= float(breed_mod.get("hp_mult", 1.0))
	attack_from_appearance *= float(breed_mod.get("attack_mult", 1.0))
	attack_speed_from_appearance *= float(breed_mod.get("attack_speed_mult", 1.0))
	var move_speed_mult: float = float(breed_mod.get("move_speed_mult", 1.0))
	var breed_crit_rate_add: float = float(breed_mod.get("crit_rate_add", 0.0))

	var profession_base: Dictionary = GameConstants.PROFESSION_BASE.get(profession, GameConstants.PROFESSION_BASE["sniper"])
	base_hp = hp_from_appearance + float(profession_base.get("hp", 0.0))
	base_attack = attack_from_appearance + float(profession_base.get("attack", 0.0))
	base_attack_speed = attack_speed_from_appearance + float(profession_base.get("attack_speed", 0.0))
	base_move_speed = float(profession_base.get("speed", 0.0)) * move_speed_mult
	base_range = range_from_appearance + float(profession_base.get("range", 0.0))
	base_defense = float(profession_base.get("defense", 0.0))
	base_crit_rate = crit_rate_from_appearance + breed_crit_rate_add
	base_crit_multiplier = crit_mult_from_appearance

func get_special_genes() -> Array[String]:
	var result: Array[String] = []
	if not gene_slot_1.is_empty():
		result.append(gene_slot_1)
	if not gene_slot_2.is_empty():
		result.append(gene_slot_2)
	if not gene_slot_3.is_empty():
		result.append(gene_slot_3)
	return result

func set_special_gene(slot_idx: int, gene_id: String) -> void:
	match slot_idx:
		0:
			gene_slot_1 = gene_id
		1:
			gene_slot_2 = gene_id
		2:
			gene_slot_3 = gene_id

func can_breed() -> bool:
	return breed_count < GameConstants.MAX_BREED_COUNT \
		and status != GameConstants.LIFECYCLE_STATUS_DEAD \
		and status != GameConstants.LIFECYCLE_STATUS_RETIRED

## 检查猫是否拥有指定基因（三槽任一匹配）
func has_gene(gene_id: String) -> bool:
	return gene_id in [gene_slot_1, gene_slot_2, gene_slot_3]

func _float_value(dict: Dictionary, key: String, fallback: float) -> float:
	return float(dict.get(key, fallback))
