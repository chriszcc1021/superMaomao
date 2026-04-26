extends SceneTree

const VIEWPORTS := [
	Vector2i(1280, 720),
]

const SCENE_PATHS := [
	"res://scenes/camp/CampScene.tscn",
	"res://scenes/battle/BattleScene.tscn",
	"res://scenes/expedition/ExpeditionMapUI.tscn",
	"res://scenes/expedition/ShopScene.tscn",
	"res://scenes/expedition/QuestionEventUI.tscn",
	"res://scenes/camp/ui/BreedingUI.tscn",
	"res://scenes/battle/ui/BattleHUD.tscn",
	"res://scenes/battle/ui/CardSelectUI.tscn",
]

var _errors: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_project_settings()
	for viewport_size: Vector2i in VIEWPORTS:
		root.size = viewport_size
		for scene_path: String in SCENE_PATHS:
			await _validate_scene(scene_path, viewport_size)
	if _errors.is_empty():
		print("[UILayoutValidator] OK")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
		print("[UILayoutValidator] " + error)
	quit(1)

func _validate_scene(scene_path: String, viewport_size: Vector2i) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_errors.append("Cannot load scene: %s" % scene_path)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_validate_control_bounds(scene, scene_path, viewport_size)
	scene.queue_free()
	await process_frame

func _validate_project_settings() -> void:
	var stretch_mode := str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	if stretch_mode != "canvas_items":
		_errors.append("Project stretch mode should be canvas_items, got %s" % stretch_mode)

func _validate_control_bounds(node: Node, scene_path: String, viewport_size: Vector2i) -> void:
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0:
			var rect := control.get_global_rect()
			var max_size := Vector2(viewport_size)
			if rect.position.x < -2.0 or rect.position.y < -2.0:
				_errors.append("%s: %s extends above/left of viewport" % [scene_path, control.get_path()])
			if rect.end.x > max_size.x + 2.0 or rect.end.y > max_size.y + 2.0:
				_errors.append("%s: %s extends outside viewport %s" % [scene_path, control.get_path(), str(viewport_size)])
	for child: Node in node.get_children():
		_validate_control_bounds(child, scene_path, viewport_size)
