extends RefCounted

func build(
	victory: bool,
	node_type: String,
	active_genes_gained: Array[String],
	level_reached: int,
	battle_failed_by_death: bool
) -> Dictionary:
	return {
		"victory": victory,
		"battle_node_type": node_type,
		"battle_wins": 1 if victory else 0,
		"active_genes_gained": active_genes_gained.duplicate(),
		"level_reached": level_reached,
		"cat_retired": battle_failed_by_death,
		"failure_reason": "battle_death" if battle_failed_by_death else "",
	}
