extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

const NEAREST_BUILDING_RADIUS := 70.0

func handle_cat_drop(cat: CatData, world_pos: Vector2, game_state: Node, building_layout: Dictionary) -> Dictionary:
	var nearest_id: String = _find_nearest_built_building(world_pos, game_state, building_layout)

	if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
		var result := {"refresh_all": true}
		if nearest_id == "cemetery" and game_state.has_building("cemetery"):
			var bio: String = game_state.bury_cat(cat.id)
			if not bio.is_empty():
				result["sidebar_text"] = bio
		return result

	if cat.status == GameConstants.LIFECYCLE_STATUS_RETIRED:
		cat.assigned_building = ""
		return {
			"sidebar_text": "退休的猫不能再工作、繁育或出征。",
			"refresh_cat_nodes": true,
		}

	if cat.health != GameConstants.HEALTH_STATE_HEALTHY:
		if nearest_id == "hospital" and game_state.has_building("hospital"):
			cat.assigned_building = "hospital"
			return {
				"sidebar_text": "🏥 %s 已送入医院治疗。" % cat.cat_name,
				"refresh_cat_nodes": true,
			}
		return {
			"sidebar_text": "⚠️ 病猫只能送入医院治疗！",
			"refresh_cat_nodes": true,
		}

	if game_state.has_method("is_cat_breeding") and game_state.is_cat_breeding(cat):
		if nearest_id != "nursery":
			return {
				"sidebar_text": "繁育中的猫必须留在产房。",
				"refresh_cat_nodes": true,
			}
		return {
			"open_nursery": true,
			"refresh_cat_nodes": true,
		}

	if nearest_id.is_empty():
		cat.assigned_building = ""
		return {"refresh_cat_nodes": true}

	if cat.assigned_building == nearest_id:
		cat.assigned_building = ""
		return {"refresh_cat_nodes": true}

	var cap: int = _get_building_worker_cap(nearest_id, game_state)
	var current: int = _count_assigned_cats(nearest_id, game_state)
	if current >= cap:
		var old_id: String = str(cat.assigned_building)
		if not old_id.is_empty() and old_id != nearest_id:
			var old_cap: int = _get_building_worker_cap(old_id, game_state)
			var old_count: int = _count_assigned_cats(old_id, game_state) - 1
			if old_count < old_cap:
				cat.assigned_building = nearest_id
				return {"refresh_cat_nodes": true}
		cat.assigned_building = ""
		return {"refresh_cat_nodes": true}

	cat.assigned_building = nearest_id
	var result := {"refresh_cat_nodes": true}
	if nearest_id == "nursery":
		result["open_nursery"] = true
	return result

func _find_nearest_built_building(world_pos: Vector2, game_state: Node, building_layout: Dictionary) -> String:
	var nearest_id: String = ""
	var nearest_dist: float = NEAREST_BUILDING_RADIUS
	for building_id: String in building_layout.keys():
		if not game_state.has_building(building_id):
			continue
		var dist: float = world_pos.distance_to(building_layout[building_id])
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = building_id
	return nearest_id

func _get_building_worker_cap(building_id: String, game_state: Node) -> int:
	if building_id == "fortune_cat":
		var level: int = int(game_state.get_building_level("fortune_cat"))
		return int(GameConstants.FORTUNE_CAT_MAX_WORKERS_BY_LEVEL.get(level, 1))
	var base_cap: Variant = GameConstants.BUILDING_WORKER_CAP.get(building_id, null)
	if base_cap != null:
		return int(base_cap)
	return 999

func _count_assigned_cats(building_id: String, game_state: Node) -> int:
	var count: int = 0
	for cat: CatData in game_state.get_living_cats():
		if str(cat.assigned_building) == building_id:
			count += 1
	return count
