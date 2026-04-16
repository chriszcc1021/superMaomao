class_name WeaponCards
extends RefCounted

static func get_pool() -> Array[Dictionary]:
	return [
		{
			"id": "weapon_claw_combo",
			"name": "猫爪连击",
			"rarity": "grey",
			"description": "近距离快速三连爪",
			"card_type": "weapon"
		},
		{
			"id": "weapon_furball_throw",
			"name": "毛球投掷",
			"rarity": "grey",
			"description": "向前方抛出毛球",
			"card_type": "weapon"
		},
		{
			"id": "weapon_frost_claw",
			"name": "冰霜爪",
			"rarity": "grey",
			"description": "发射减速冰爪",
			"card_type": "weapon"
		},
		{
			"id": "weapon_homing_claw",
			"name": "追踪爪影",
			"rarity": "grey",
			"description": "自动锁定最近敌人",
			"card_type": "weapon"
		},
		{
			"id": "weapon_meow_wave",
			"name": "喵呜震波",
			"rarity": "grey",
			"description": "扇形冲击波攻击",
			"card_type": "weapon"
		},
		{
			"id": "weapon_swift_combo",
			"name": "迅影连爪",
			"rarity": "blue",
			"description": "高攻速多段攻击",
			"card_type": "weapon"
		},
		{
			"id": "weapon_pierce_claw",
			"name": "穿刺利爪",
			"rarity": "blue",
			"description": "直线贯穿攻击",
			"card_type": "weapon"
		},
		{
			"id": "weapon_electric_fur",
			"name": "电磁猫毛",
			"rarity": "blue",
			"description": "闪电链弹射伤害",
			"card_type": "weapon"
		},
		{
			"id": "weapon_ghost_mark",
			"name": "幽灵爪印",
			"rarity": "purple",
			"description": "穿透型高频低伤",
			"card_type": "weapon"
		},
		{
			"id": "weapon_time_stop",
			"name": "时停喵叫",
			"rarity": "purple",
			"description": "短暂冻结全场",
			"card_type": "weapon"
		},
		{
			"id": "weapon_nuclear_meow",
			"name": "喵喵核爆",
			"rarity": "purple",
			"description": "大范围爆炸伤害",
			"card_type": "weapon"
		}
	]
