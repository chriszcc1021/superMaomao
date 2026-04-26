extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

func roll_choices(cat: CatData, active_genes_gained: Array[String]) -> Array[String]:
	var cat_has_active := has_active_gene(cat, active_genes_gained)
	var pool: Array[String] = []
	for gene_id: String in GameConstants.ALL_SPECIAL_GENE_POOL:
		var is_active := GameConstants.ACTIVE_SKILL_GENE_POOL.has(gene_id)
		if is_active and cat_has_active:
			continue
		var rarity: String = str(GameConstants.GENE_RARITY.get(gene_id, "grey"))
		var weight: int = int(GameConstants.GENE_RARITY_WEIGHT.get(rarity, 3))
		for _w in weight:
			pool.append(gene_id)
	pool.shuffle()

	var seen: Dictionary = {}
	var result: Array[String] = []
	for gene_id: String in pool:
		if not seen.has(gene_id):
			seen[gene_id] = true
			result.append(gene_id)
			if result.size() >= 3:
				break
	return result

func has_active_gene(cat: CatData, active_genes_gained: Array[String]) -> bool:
	if cat == null:
		return false
	for slot_gene: String in [cat.gene_slot_1, cat.gene_slot_2, cat.gene_slot_3]:
		if GameConstants.ACTIVE_SKILL_GENE_POOL.has(slot_gene):
			return true
	for gene_id: String in active_genes_gained:
		if GameConstants.ACTIVE_SKILL_GENE_POOL.has(gene_id):
			return true
	return false

func write_to_empty_slot(cat: CatData, active_genes_gained: Array[String], gene_id: String) -> bool:
	if cat == null:
		return false
	if str(cat.gene_slot_1).is_empty():
		cat.gene_slot_1 = gene_id
	elif str(cat.gene_slot_2).is_empty():
		cat.gene_slot_2 = gene_id
	elif str(cat.gene_slot_3).is_empty():
		cat.gene_slot_3 = gene_id
	else:
		return false
	active_genes_gained.append(gene_id)
	return true

func get_slot_gene(cat: CatData, slot_idx: int) -> String:
	if cat == null:
		return ""
	match slot_idx:
		0: return str(cat.gene_slot_1)
		1: return str(cat.gene_slot_2)
		2: return str(cat.gene_slot_3)
	return ""

func replace_slot(cat: CatData, active_genes_gained: Array[String], slot_idx: int, new_gene_id: String) -> void:
	if cat != null:
		match slot_idx:
			0: cat.gene_slot_1 = new_gene_id
			1: cat.gene_slot_2 = new_gene_id
			2: cat.gene_slot_3 = new_gene_id
	active_genes_gained.append(new_gene_id)
