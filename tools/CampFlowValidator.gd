extends SceneTree

const CatData := preload("res://resources/CatData.gd")
const GameConstants := preload("res://data/constants.gd")
const CampAssignmentController := preload("res://scenes/camp/CampAssignmentController.gd")

var _errors: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_fail("GameState autoload is missing")
	else:
		_prepare_state(game_state)
		_validate_building_flow(game_state)
		_validate_assignment_flow(game_state)
		_validate_breeding_flow(game_state)

	if _errors.is_empty():
		print("[CampFlowValidator] OK")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
		print("[CampFlowValidator] " + error)
	quit(1)

func _prepare_state(game_state: Node) -> void:
	if game_state.has_method("reset_game"):
		game_state.reset_game()
	game_state.coins = 10000
	game_state.cat_food = 10000
	game_state.cat_food_cap = 10000
	game_state.cats.clear()
	game_state.cat_house_slots = 8
	game_state.buildings_built = {
		"cat_house": true,
		"food_farm": true,
		"gold_mine": true,
	}
	game_state.max_breeding_slots = GameConstants.BREEDING_SLOT_INITIAL
	game_state.breeding_slots.clear()
	game_state.sync_breeding_slots()

func _validate_building_flow(game_state: Node) -> void:
	_require(game_state.build_building("nursery"), "nursery should be buildable")
	_require(game_state.has_building("nursery"), "nursery should be marked built")
	var old_slots: int = int(game_state.max_breeding_slots)
	_require(game_state.upgrade_building("nursery"), "nursery should be upgradeable")
	_require(game_state.max_breeding_slots == old_slots + 1, "nursery upgrade should add one breeding slot")

func _validate_assignment_flow(game_state: Node) -> void:
	var cat := _make_cat("validator_worker", GameConstants.SEX_MALE)
	_require(game_state.add_cat(cat), "worker cat should be added")
	var controller := CampAssignmentController.new()
	var layout := {"gold_mine": Vector2(100.0, 100.0)}
	var result: Dictionary = controller.handle_cat_drop(cat, Vector2(100.0, 100.0), game_state, layout)
	_require(bool(result.get("refresh_cat_nodes", false)), "assignment should request cat node refresh")
	_require(cat.assigned_building == "gold_mine", "cat should be assigned to nearest built building")

func _validate_breeding_flow(game_state: Node) -> void:
	var father := _make_cat("validator_father", GameConstants.SEX_MALE)
	var mother := _make_cat("validator_mother", GameConstants.SEX_FEMALE)
	_require(game_state.add_cat(father), "father cat should be added")
	_require(game_state.add_cat(mother), "mother cat should be added")

	var started := false
	for _attempt in range(20):
		if game_state.start_breeding_in_slot(0, father.id, mother.id, father.breed, father.profession):
			started = true
			break
	_require(started, "breeding should start in slot 0")
	_require(game_state.is_cat_breeding(father), "father should be marked breeding")
	_require(game_state.is_cat_breeding(mother), "mother should be marked breeding")

	var born: Array[CatData] = []
	for _day in range(GameConstants.BREEDING_SLOT_CD_DAYS):
		born = game_state.tick_breeding_slots()
	_require(not born.is_empty(), "breeding should produce offspring after cooldown")
	_require(not bool(game_state.get_breeding_slot(0).get("active", false)), "breeding slot should clear after birth")

func _make_cat(id: String, sex: String) -> CatData:
	var cat := CatData.new()
	cat.id = id
	cat.cat_name = id
	cat.sex = sex
	cat.age_days = GameConstants.KITTEN_DAYS
	cat.status = GameConstants.LIFECYCLE_STATUS_IDLE
	cat.health = GameConstants.HEALTH_STATE_HEALTHY
	cat.breed = "tabby"
	cat.profession = "sniper"
	cat.calculate_stats()
	return cat

func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_errors.append(message)
