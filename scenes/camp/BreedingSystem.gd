class_name BreedingSystem
extends RefCounted

const CatData       := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")

func breed(father: CatData, mother: CatData, child_breed: String, child_profession: String) -> CatData:
	if father == null or mother == null:
		return null
	if child_breed.is_empty() or child_profession.is_empty():
		return null

	var offspring := CatData.new()
	offspring.id = "cat_%s_%d" % [str(Time.get_unix_time_from_system()), int(randi() % 100000)]
	offspring.cat_name = "幼崽-%03d" % int(randi() % 1000)
	offspring.breed = child_breed
	offspring.profession = child_profession

	offspring.gene_head = _inherit_appearance_gene("head", father.gene_head, mother.gene_head)
	offspring.gene_ear = _inherit_appearance_gene("ear", father.gene_ear, mother.gene_ear)
	offspring.gene_eye_color = _inherit_appearance_gene("eye_color", father.gene_eye_color, mother.gene_eye_color)
	offspring.gene_eye_shape = _inherit_appearance_gene("eye_shape", father.gene_eye_shape, mother.gene_eye_shape)
	offspring.gene_fur_main = _inherit_appearance_gene("fur_main", father.gene_fur_main, mother.gene_fur_main)
	offspring.gene_fur_accent = _inherit_appearance_gene("fur_accent", father.gene_fur_accent, mother.gene_fur_accent)
	offspring.gene_pattern = _inherit_appearance_gene("pattern", father.gene_pattern, mother.gene_pattern)
	offspring.gene_tail = _inherit_appearance_gene("tail", father.gene_tail, mother.gene_tail)

	# breeding_expert：父母任一有此基因，特殊基因继承率+10%
	var expert_bonus: float = 0.0
	if father.has_gene("breeding_expert") or mother.has_gene("breeding_expert"):
		expert_bonus = 0.10
	offspring.gene_slot_1 = _inherit_special_gene(father.gene_slot_1, mother.gene_slot_1, expert_bonus)
	offspring.gene_slot_2 = _inherit_special_gene(father.gene_slot_2, mother.gene_slot_2, expert_bonus)
	offspring.gene_slot_3 = _inherit_special_gene(father.gene_slot_3, mother.gene_slot_3, expert_bonus)
	offspring.calculate_stats()
	return offspring

func predict_range(father: CatData, mother: CatData, child_breed: String, child_profession: String, sample_count: int = 100) -> Dictionary:
	var result := {
		"hp_min": INF, "hp_max": -INF,
		"atk_min": INF, "atk_max": -INF,
		"aspd_min": INF, "aspd_max": -INF,
		"move_min": INF, "move_max": -INF,
		"range_min": INF, "range_max": -INF,
		"crit_min": INF, "crit_max": -INF
	}
	if father == null or mother == null:
		return result
	if child_breed.is_empty() or child_profession.is_empty():
		return result

	for _i in sample_count:
		var child := breed(father, mother, child_breed, child_profession)
		if child == null:
			continue
		result.hp_min = min(result.hp_min, child.base_hp)
		result.hp_max = max(result.hp_max, child.base_hp)
		result.atk_min = min(result.atk_min, child.base_attack)
		result.atk_max = max(result.atk_max, child.base_attack)
		result.aspd_min = min(result.aspd_min, child.base_attack_speed)
		result.aspd_max = max(result.aspd_max, child.base_attack_speed)
		result.move_min = min(result.move_min, child.base_move_speed)
		result.move_max = max(result.move_max, child.base_move_speed)
		result.range_min = min(result.range_min, child.base_range)
		result.range_max = max(result.range_max, child.base_range)
		result.crit_min = min(result.crit_min, child.base_crit_rate)
		result.crit_max = max(result.crit_max, child.base_crit_rate)
	return result

func _inherit_appearance_gene(slot_key: String, father_value: String, mother_value: String) -> String:
	var roll := randf()
	if roll < GameConstants.BREEDING_GENE_INHERIT_PARENT:
		return father_value
	if roll < GameConstants.BREEDING_GENE_INHERIT_PARENT + GameConstants.BREEDING_GENE_INHERIT_OTHER_PARENT:
		return mother_value
	var options: Array = GameConstants.APPEARANCE_GENE_OPTIONS.get(slot_key, [])
	if options.is_empty():
		return father_value
	return str(options[randi() % options.size()])

func _inherit_special_gene(father_gene: String, mother_gene: String, expert_bonus: float = 0.0) -> String:
	var inherit_chance := GameConstants.BREEDING_GENE_INHERIT_PARENT + GameConstants.BREEDING_GENE_INHERIT_OTHER_PARENT + expert_bonus
	var roll := randf()
	if roll < GameConstants.BREEDING_GENE_INHERIT_PARENT:
		return father_gene
	if roll < inherit_chance:
		return mother_gene
	if GameConstants.ALL_SPECIAL_GENE_POOL.is_empty():
		return ""
	return str(GameConstants.ALL_SPECIAL_GENE_POOL[randi() % GameConstants.ALL_SPECIAL_GENE_POOL.size()])

