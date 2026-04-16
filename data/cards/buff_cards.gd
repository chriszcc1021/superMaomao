class_name BuffCards
extends RefCounted

static func get_pool() -> Array[Dictionary]:
	return [
		{
			"id": "buff_crit_eye",
			"name": "暴击眼",
			"rarity": "grey",
			"card_type": "buff",
			"max_stacks": 3,
			"effect_key": "crit_rate",
			"per_stack": 0.08
		},
		{
			"id": "buff_tough_fur",
			"name": "厚实皮毛",
			"rarity": "grey",
			"card_type": "buff",
			"max_stacks": 3,
			"effect_key": "max_hp",
			"per_stack": 0.10
		},
		{
			"id": "buff_swift_tail",
			"name": "迅捷尾巴",
			"rarity": "grey",
			"card_type": "buff",
			"max_stacks": 3,
			"effect_key": "move_speed",
			"per_stack": 0.08
		},
		{
			"id": "buff_sharp_claw",
			"name": "锋利爪尖",
			"rarity": "grey",
			"card_type": "buff",
			"max_stacks": 3,
			"effect_key": "attack",
			"per_stack": 0.08
		},
		{
			"id": "buff_wide_ear",
			"name": "广域耳朵",
			"rarity": "grey",
			"card_type": "buff",
			"max_stacks": 3,
			"effect_key": "range",
			"per_stack": 0.10
		}
	]
