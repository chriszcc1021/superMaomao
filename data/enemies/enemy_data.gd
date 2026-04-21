class_name EnemyData
extends RefCounted

static func get_enemy_definitions() -> Dictionary:
	var result := {}
	for file_name in ["base_enemies", "elite_enemies", "bosses"]:
		var path: String = "res://data/enemies/%s.json" % file_name
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("EnemyData: cannot open %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			result.merge(parsed)
		else:
			push_error("EnemyData: invalid JSON in %s" % path)
	return result
