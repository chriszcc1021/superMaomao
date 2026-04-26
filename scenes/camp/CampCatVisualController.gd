extends Node

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")
const CatSpriteScene := preload("res://scenes/common/CatSprite.tscn")

signal cat_drop_requested(cat: CatData, world_pos: Vector2)

var _cats_root: Node2D = null
var _game_state: Node = null
var _building_layout: Dictionary = {}
var _cat_visual_positions: Dictionary = {}
var _cat_building_anchors: Dictionary = {}
var _cat_anchor_buildings: Dictionary = {}

func setup(cats_root: Node2D, game_state: Node, building_layout: Dictionary) -> void:
	_cats_root = cats_root
	_game_state = game_state
	_building_layout = building_layout

func refresh() -> void:
	if _cats_root == null or _game_state == null:
		return
	_capture_cat_visual_state()
	for child: Node in _cats_root.get_children():
		child.queue_free()

	var active_cat_ids: Dictionary = {}
	for cat: CatData in _game_state.cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
			continue
		active_cat_ids[cat.id] = true
		var cat_sprite: Node2D = CatSpriteScene.instantiate()
		cat_sprite.global_position = _get_cached_cat_position(cat.id)
		cat_sprite.call("setup", cat)
		if cat.status != GameConstants.LIFECYCLE_STATUS_DEAD:
			var assigned: String = str(cat.assigned_building)
			if not assigned.is_empty() and _building_layout.has(assigned):
				var anchor := _get_cached_cat_anchor(cat.id, assigned)
				cat_sprite.call("set_building_anchor", assigned, anchor)
			else:
				_clear_cached_cat_anchor(cat.id)
		if cat_sprite.has_signal("drop_requested"):
			cat_sprite.connect("drop_requested", _on_cat_drop_requested)
		_cats_root.add_child(cat_sprite)
	_prune_cat_visual_cache(active_cat_ids)

func _capture_cat_visual_state() -> void:
	for child: Node in _cats_root.get_children():
		var cat_sprite := child as Node2D
		if cat_sprite == null:
			continue
		var child_cat := child.get("cat_data") as CatData
		if child_cat == null or child_cat.id.is_empty():
			continue
		_cat_visual_positions[child_cat.id] = cat_sprite.global_position
		if child.has_method("has_building_anchor") and bool(child.call("has_building_anchor")):
			_cat_building_anchors[child_cat.id] = child.call("get_building_anchor")
			_cat_anchor_buildings[child_cat.id] = str(child_cat.assigned_building)
		else:
			_clear_cached_cat_anchor(child_cat.id)

func _get_cached_cat_position(cat_id: String) -> Vector2:
	if not cat_id.is_empty() and _cat_visual_positions.has(cat_id):
		return _cat_visual_positions[cat_id]
	return _random_cat_spawn_position()

func _get_cached_cat_anchor(cat_id: String, building_id: String) -> Vector2:
	if _cat_anchor_buildings.get(cat_id, "") == building_id and _cat_building_anchors.has(cat_id):
		return _cat_building_anchors[cat_id]
	var anchor: Vector2 = _building_layout[building_id]
	anchor += Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0))
	_cat_building_anchors[cat_id] = anchor
	_cat_anchor_buildings[cat_id] = building_id
	return anchor

func _clear_cached_cat_anchor(cat_id: String) -> void:
	_cat_building_anchors.erase(cat_id)
	_cat_anchor_buildings.erase(cat_id)

func _prune_cat_visual_cache(active_cat_ids: Dictionary) -> void:
	for cat_id in _cat_visual_positions.keys():
		if not active_cat_ids.has(cat_id):
			_cat_visual_positions.erase(cat_id)
	for cat_id in _cat_building_anchors.keys():
		if not active_cat_ids.has(cat_id):
			_cat_building_anchors.erase(cat_id)
	for cat_id in _cat_anchor_buildings.keys():
		if not active_cat_ids.has(cat_id):
			_cat_anchor_buildings.erase(cat_id)

func _random_cat_spawn_position() -> Vector2:
	var rect: Rect2 = GameConstants.CAMP_CAT_SPAWN_RECT
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)

func _on_cat_drop_requested(cat: CatData, world_pos: Vector2) -> void:
	cat_drop_requested.emit(cat, world_pos)
