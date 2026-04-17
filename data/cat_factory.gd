class_name CatFactory
extends RefCounted


static func create_random_stray_cat(id_prefix: String = "stray", name_prefix: String = "流浪猫") -> CatData:
	var cat := CatData.new()
	cat.id = "%s_%s_%d" % [id_prefix, str(Time.get_unix_time_from_system()), int(randi() % 10000)]
	cat.cat_name = "%s%03d" % [name_prefix, int(randi() % 1000)]
	cat.breed = _random_key(GameConstants.BREED_MODIFIERS)
	cat.profession = _random_key(GameConstants.PROFESSION_BASE)
	cat.gene_head = _random_option("head")
	cat.gene_ear = _random_option("ear")
	cat.gene_eye_color = _random_option("eye_color")
	cat.gene_eye_shape = _random_option("eye_shape")
	cat.gene_fur_main = _random_option("fur_main")
	cat.gene_fur_accent = _random_option("fur_accent")
	cat.gene_pattern = _random_option("pattern")
	cat.gene_tail = _random_option("tail")
	cat.calculate_stats()
	return cat

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
