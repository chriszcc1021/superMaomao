class_name EnemyData
extends RefCounted

static func get_enemy_definitions() -> Dictionary:
	return {
		"small_monkey": {
			"display_name": "小猴兵",
			"hp": 30.0,
			"damage": 8.0,
			"move_speed": 95.0,
			"fish_drop": 1
		},
		"stone_monkey": {
			"display_name": "投石猴",
			"hp": 25.0,
			"damage": 12.0,
			"move_speed": 85.0,
			"fish_drop": 2
		},
		"tank_gorilla": {
			"display_name": "坦克猩猩",
			"hp": 120.0,
			"damage": 15.0,
			"move_speed": 50.0,
			"fish_drop": 5
		},
		"elite_monkey": {
			"display_name": "精英猴",
			"hp": 300.0,
			"damage": 20.0,
			"move_speed": 70.0,
			"fish_drop": 20
		},
		"boss_gorilla_king": {
			"display_name": "猩猩大王",
			"hp": 2000.0,
			"damage": 30.0,
			"move_speed": 60.0,
			"fish_drop": 50
		}
	}
