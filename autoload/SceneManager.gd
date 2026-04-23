extends Node

const CAMP_SCENE_PATH := "res://scenes/camp/CampScene.tscn"
const EXPEDITION_MAP_SCENE_PATH := "res://scenes/expedition/ExpeditionMapUI.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle/BattleScene.tscn"
const SHOP_SCENE_PATH := "res://scenes/expedition/ShopScene.tscn"
const EXPEDITION_RESULT_SCENE_PATH := "res://scenes/expedition/ExpeditionResultScene.tscn"

var last_battle_node_type: String = ""
var last_battle_result: Dictionary = {}
var returned_from_shop: bool = false
var expedition_result_data: Dictionary = {}  # 供 ExpeditionResultScene 读取

func go_to_camp() -> void:
	get_tree().call_deferred("change_scene_to_file", CAMP_SCENE_PATH)

func go_to_expedition_map() -> void:
	get_tree().call_deferred("change_scene_to_file", EXPEDITION_MAP_SCENE_PATH)

func go_to_shop() -> void:
	get_tree().call_deferred("change_scene_to_file", SHOP_SCENE_PATH)

func go_to_battle(node_type: String) -> void:
	last_battle_node_type = node_type
	get_tree().call_deferred("change_scene_to_file", BATTLE_SCENE_PATH)

func return_from_battle(result: Dictionary) -> void:
	last_battle_result = result.duplicate(true)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.expedition_active:
		go_to_expedition_map()
		return
	go_to_camp()

func return_from_shop() -> void:
	returned_from_shop = true
	go_to_expedition_map()

func go_to_expedition_result(data: Dictionary) -> void:
	expedition_result_data = data.duplicate(true)
	get_tree().call_deferred("change_scene_to_file", EXPEDITION_RESULT_SCENE_PATH)
