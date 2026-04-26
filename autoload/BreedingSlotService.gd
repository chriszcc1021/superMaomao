extends RefCounted

const CatData := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")
const BreedingSystem := preload("res://scenes/camp/BreedingSystem.gd")

func init_slots(game_state: Node) -> void:
	while game_state.breeding_slots.size() < game_state.max_breeding_slots:
		game_state.breeding_slots.append({"active": false, "father_id": "", "mother_id": "", "days_remaining": 0})

func sync_slots(game_state: Node) -> void:
	if game_state.breeding_slots.size() > game_state.max_breeding_slots:
		game_state.breeding_slots.resize(game_state.max_breeding_slots)
	init_slots(game_state)

func is_cat_breeding(game_state: Node, cat: CatData) -> bool:
	if cat == null or cat.id.is_empty():
		return false
	for slot in game_state.breeding_slots:
		if not bool(slot.get("active", false)):
			continue
		if str(slot.get("father_id", "")) == cat.id:
			return true
		if str(slot.get("mother_id", "")) == cat.id:
			return true
	return false

func can_cat_breed(game_state: Node, cat: CatData) -> bool:
	if cat == null:
		return false
	if cat.age_days < GameConstants.KITTEN_DAYS:
		return false
	if not cat.can_breed():
		return false
	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		return false
	if cat.status == GameConstants.LIFECYCLE_STATUS_EXPEDITION:
		return false
	if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
		return false
	if is_cat_breeding(game_state, cat):
		return false
	return true

func get_breedable_cats(game_state: Node) -> Array[CatData]:
	var result: Array[CatData] = []
	for cat: CatData in game_state.cats:
		if can_cat_breed(game_state, cat):
			result.append(cat)
	return result

func start_in_slot(
	game_state: Node,
	slot_idx: int,
	father_id: String,
	mother_id: String,
	child_breed: String,
	child_profession: String
) -> bool:
	if slot_idx < 0 or slot_idx >= game_state.breeding_slots.size():
		return false
	if not game_state.has_building("nursery"):
		return false
	var slot: Dictionary = game_state.breeding_slots[slot_idx]
	if slot.get("active", false):
		return false
	if not game_state.has_free_cat_house_slot():
		return false
	if father_id == mother_id:
		return false
	var father: CatData = game_state.find_cat(father_id)
	var mother: CatData = game_state.find_cat(mother_id)
	if father == null or mother == null:
		return false
	if not can_cat_breed(game_state, father) or not can_cat_breed(game_state, mother):
		return false
	if father.sex != GameConstants.SEX_MALE or mother.sex != GameConstants.SEX_FEMALE:
		return false

	var chance := GameConstants.BREED_SUCCESS_WITH_NURSERY
	if father.has_gene("love_spreader") or mother.has_gene("love_spreader"):
		chance = minf(1.0, chance + 0.15)
	if randf() > chance:
		return false

	slot["active"] = true
	slot["father_id"] = father_id
	slot["mother_id"] = mother_id
	slot["child_breed"] = child_breed
	slot["child_profession"] = child_profession
	slot["days_remaining"] = GameConstants.BREEDING_SLOT_CD_DAYS
	father.breed_count += 1
	mother.breed_count += 1
	father.assigned_building = "nursery"
	mother.assigned_building = "nursery"
	return true

func tick_slots(game_state: Node) -> Array[CatData]:
	var born: Array[CatData] = []
	for i in game_state.breeding_slots.size():
		var slot: Dictionary = game_state.breeding_slots[i]
		if not slot.get("active", false):
			continue
		slot["days_remaining"] = int(slot["days_remaining"]) - 1
		if slot["days_remaining"] > 0:
			continue
		var father: CatData = game_state.find_cat(str(slot.get("father_id", "")))
		var mother: CatData = game_state.find_cat(str(slot.get("mother_id", "")))
		if father != null and mother != null:
			var breeding_sys := BreedingSystem.new()
			var child_breed := str(slot.get("child_breed", father.breed))
			var child_profession := str(slot.get("child_profession", father.profession))
			var child := breeding_sys.breed(father, mother, child_breed, child_profession)
			if child != null and game_state.add_cat(child):
				born.append(child)
		_clear_slot(slot)
	return born

func _clear_slot(slot: Dictionary) -> void:
	slot["active"] = false
	slot["father_id"] = ""
	slot["mother_id"] = ""
	slot["days_remaining"] = 0
