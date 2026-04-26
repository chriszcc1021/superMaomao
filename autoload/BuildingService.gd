extends RefCounted

const GameConstants := preload("res://data/constants.gd")

func build_building(game_state: Node, building_id: String) -> bool:
	if game_state.has_building(building_id):
		return false
	var cost: int = int(GameConstants.BUILDING_COSTS.get(building_id, 0))
	if cost > 0 and not game_state.spend_coins(cost):
		return false
	game_state.set_building_state(building_id, true)
	return true

func upgrade_building(game_state: Node, building_id: String) -> bool:
	match building_id:
		"cat_house":
			return _upgrade_cat_house(game_state)
		"granary":
			return _upgrade_granary(game_state)
		"fortune_cat":
			return _upgrade_fortune_cat(game_state)
		"nursery":
			return _upgrade_nursery(game_state)
	return false

func _upgrade_cat_house(game_state: Node) -> bool:
	if game_state.cat_house_slots >= GameConstants.MAX_CAT_HOUSE_SLOTS:
		return false
	var cost: int = int(GameConstants.BUILDING_COSTS.get("cat_house_expand", 60))
	if not game_state.spend_coins(cost):
		return false
	game_state.cat_house_slots += 1
	return true

func _upgrade_granary(game_state: Node) -> bool:
	var current_level: int = game_state.get_building_level("granary")
	if current_level >= GameConstants.GRANARY_MAX_LEVEL:
		return false
	var cost_idx: int = current_level - 1
	if cost_idx < 0 or cost_idx >= GameConstants.GRANARY_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.GRANARY_UPGRADE_COSTS[cost_idx])
	if not game_state.spend_coins(cost):
		return false
	game_state.buildings_built["granary"] = current_level + 1
	game_state.cat_food_cap = int(GameConstants.GRANARY_FOOD_CAP_BY_LEVEL.get(current_level + 1, game_state.cat_food_cap))
	game_state.cat_food_changed.emit(game_state.cat_food)
	return true

func _upgrade_fortune_cat(game_state: Node) -> bool:
	var current_level: int = game_state.get_building_level("fortune_cat")
	if current_level >= GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.size():
		return false
	var cost_idx: int = current_level - 1
	if cost_idx < 0 or cost_idx >= GameConstants.FORTUNE_CAT_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.FORTUNE_CAT_UPGRADE_COSTS[cost_idx])
	if not game_state.spend_coins(cost):
		return false
	game_state.buildings_built["fortune_cat"] = current_level + 1
	return true

func _upgrade_nursery(game_state: Node) -> bool:
	if game_state.max_breeding_slots >= GameConstants.BREEDING_SLOT_MAX:
		return false
	var cost_idx: int = game_state.max_breeding_slots - 1
	if cost_idx < 0 or cost_idx >= GameConstants.BREEDING_SLOT_UPGRADE_COSTS.size():
		return false
	var cost: int = int(GameConstants.BREEDING_SLOT_UPGRADE_COSTS[cost_idx])
	if not game_state.spend_coins(cost):
		return false
	game_state.max_breeding_slots += 1
	game_state.sync_breeding_slots()
	return true
