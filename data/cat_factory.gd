class_name CatFactory
extends RefCounted

const CatData       := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")

static func create_random_stray_cat(
	id_prefix: String = "stray",
	name_prefix: String = "流浪猫",
	forced_sex: String = "",
	forced_age_days: int = 0
) -> CatData:
	var cat := CatData.new()
	cat.id = "%s_%s_%d" % [id_prefix, str(Time.get_unix_time_from_system()), int(randi() % 10000)]
	cat.cat_name = "%s%03d" % [name_prefix, int(randi() % 1000)]
	cat.sex = forced_sex if not forced_sex.is_empty() else _random_sex()
	cat.age_days = forced_age_days
	cat.breed = _random_key(GameConstants.BREED_MODIFIERS)
	cat.profession = _random_key(GameConstants.PROFESSION_BASE)
	_apply_random_appearance(cat)
	cat.calculate_stats()
	return cat

static func create_starter_choices() -> Array[CatData]:
	var starter_specs := [
		{
			"id_prefix": "starter",
			"name": "麻糬",
			"sex": GameConstants.SEX_FEMALE,
			"breed": "ragdoll",
			"profession": "support",
			"age_days": 5,
			"gene": "mini_nurse",
		},
		{
			"id_prefix": "starter",
			"name": "灰烬",
			"sex": GameConstants.SEX_MALE,
			"breed": "siamese",
			"profession": "sniper",
			"age_days": 5,
			"gene": "cat_step",
		},
		{
			"id_prefix": "starter",
			"name": "余烬",
			"sex": GameConstants.SEX_MALE,
			"breed": "orange",
			"profession": "aoe",
			"age_days": 5,
			"gene": "hard_worker",
		},
	]
	var result: Array[CatData] = []
	for spec: Dictionary in starter_specs:
		result.append(_create_cat_from_spec(spec))
	return result

static func create_intro_stray_cat(target_sex: String) -> CatData:
	var cat := create_random_stray_cat("intro_stray", "流浪猫", target_sex, 5)
	cat.gene_slot_1 = "love_spreader"
	cat.calculate_stats()
	return cat

static func _create_cat_from_spec(spec: Dictionary) -> CatData:
	var cat := CatData.new()
	cat.id = "%s_%s_%d" % [str(spec.get("id_prefix", "cat")), str(Time.get_unix_time_from_system()), int(randi() % 10000)]
	cat.cat_name = str(spec.get("name", "Cat"))
	cat.sex = str(spec.get("sex", GameConstants.SEX_FEMALE))
	cat.breed = str(spec.get("breed", "tabby"))
	cat.profession = str(spec.get("profession", "sniper"))
	cat.age_days = int(spec.get("age_days", 0))
	_apply_random_appearance(cat)
	var gene_id := str(spec.get("gene", ""))
	if not gene_id.is_empty():
		cat.gene_slot_1 = gene_id
	cat.calculate_stats()
	return cat

static func _apply_random_appearance(cat: CatData) -> void:
	cat.gene_head = _random_option("head")
	cat.gene_ear = _random_option("ear")
	cat.gene_eye_color = _random_option("eye_color")
	cat.gene_eye_shape = _random_option("eye_shape")
	cat.gene_fur_main = _random_option("fur_main")
	cat.gene_fur_accent = _random_option("fur_accent")
	cat.gene_pattern = _random_option("pattern")
	cat.gene_tail = _random_option("tail")

static func _random_key(dict: Dictionary) -> String:
	var keys: Array = dict.keys()
	if keys.is_empty():
		return ""
	return str(keys[randi() % keys.size()])

static func _random_option(slot_key: String) -> String:
	var options: Array = GameConstants.APPEARANCE_GENE_OPTIONS.get(slot_key, [])
	if options.is_empty():
		return ""
	return str(options[randi() % options.size()])

static func _random_sex() -> String:
	return GameConstants.SEX_MALE if randf() < 0.5 else GameConstants.SEX_FEMALE
