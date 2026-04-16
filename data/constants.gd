class_name GameConstants
extends RefCounted

const STARTING_COINS := 100
const STARTING_CAT_FOOD := 50
const STARTING_CAT_FOOD_CAP := 200
const STARTING_CAMP_DAY := 1

const STARTING_CAT_HOUSE_SLOTS := 5
const MAX_CAT_HOUSE_SLOTS := 10
const MAX_STRAY_QUEUE_SIZE := 3
const MAX_BREED_COUNT := 3

const KITTEN_DAYS := 3
const ADULT_MAX_DAYS := 30
const ELDER_DAYS := 5

const STRAY_CAT_DAILY_CHANCE := 0.38
const HEART_CAT_HOUSE_STRAY_CHANCE_BONUS := 0.20
const BREED_SUCCESS_WITH_NURSERY := 0.65
const BREED_SUCCESS_WITHOUT_NURSERY := 0.15

const FOOD_CONSUMPTION_KITTEN := 1
const FOOD_CONSUMPTION_ADULT := 3
const FOOD_CONSUMPTION_ELDER := 3

const HOSPITAL_COST_SICK := 50
const HOSPITAL_COST_CRITICAL := 95
const SHOP_CAT_FOOD_AMOUNT := 10
const SHOP_CAT_FOOD_COST := 10

const FOOD_FARM_OUTPUT_BY_WORKERS := {
	0: 3,
	1: 8,
	2: 12,
	3: 15
}

const GOLD_MINE_OUTPUT_BY_WORKERS := {
	0: 2,
	1: 5,
	2: 7
}

# 招财猫神龛（按猫数产金）
const FORTUNE_CAT_OUTPUT_PER_WORKER := {1: 15, 2: 25, 3: 40}  # Lv1/2/3 每只猫/天
const FORTUNE_CAT_MAX_WORKERS_BY_LEVEL := {1: 1, 2: 2, 3: 3}
const FORTUNE_CAT_UPGRADE_COSTS := [100, 200, 400]  # 建造/升2/升3

# 商店卡牌价格（按稀有度）
const SHOP_CARD_PRICE := {"grey": 30, "green": 60, "blue": 120, "purple": 200}

# 建筑最大工作猫数（不在此表的建筑无限制）
const BUILDING_WORKER_CAP := {
	"food_farm": 3,
	"gold_mine": 2,
	"hospital": 1,
	"nursery": 2,
	"heart_cat_house": 1
	# fortune_cat 按等级变动，用 FORTUNE_CAT_MAX_WORKERS_BY_LEVEL
}

# 基因中文名称与描述
const GENE_DISPLAY_ZH := {
	"curious_lockon":   {"name": "好奇锁定",   "desc": "攻击自动追踪最近敌人"},
	"cold_paw":         {"name": "寒冰之爪",   "desc": "攻击附带减速效果"},
	"battle_frenzy":    {"name": "战斗狂热",   "desc": "每击杀一敌，攻速提升5%（最多叠10层）"},
	"bulky_body":       {"name": "壮硕体魄",   "desc": "最大生命值提升20%"},
	"cat_step":         {"name": "猫步轻功",   "desc": "移动速度提升15%"},
	"self_heal":        {"name": "自愈之力",   "desc": "每5秒回复最大HP的3%"},
	"chain_hit":        {"name": "连锁打击",   "desc": "攻击有25%概率弹射至附近另一敌人"},
	"cleanup_blast":    {"name": "清场爆炸",   "desc": "击杀敌人时产生小范围爆炸"},
	"survival_rush":    {"name": "求生冲刺",   "desc": "HP低于30%时移速和攻速提升30%"},
	"tenacity_revive":  {"name": "坚韧复生",   "desc": "濒死时触发一次无敌，HP回复至20%"},
	"resonance_stack":  {"name": "共鸣叠层",   "desc": "每次升级攻击力永久提升2%"},
	"desperado":        {"name": "亡命之徒",   "desc": "HP越低攻击力越高（最高+50%）"},
	"hunter_instinct":  {"name": "猎手本能",   "desc": "暴击率提升10%"},
	"invulnerable_frame":{"name": "无敌帧",    "desc": "受击后0.5秒内无敌"},
	"berserk_factor":   {"name": "狂暴因子",   "desc": "攻速提升20%，但防御降低10%"},
	"lone_pride":       {"name": "独行骄傲",   "desc": "场上敌人少于3只时，伤害提升40%"},
	"coward":           {"name": "胆小鬼",     "desc": "与敌人距离越远伤害越高（最高+35%）"},
	"sleepyhead":       {"name": "嗜睡猫",     "desc": "停止移动3秒后，下次攻击伤害翻倍"}
}

const BUILDING_COSTS := {
	"cat_house_expand": 60,
	"granary": 80,
	"food_farm": 40,
	"hospital": 60,
	"gold_mine": 40,
	"nursery": 80,
	"heart_cat_house": 50,
	"cemetery": 30,
	"fortune_cat": 100
}

const GRANARY_UPGRADE_COSTS := [80, 160, 320, 600]

const PROFESSION_BASE := {
	"sniper": {
		"attack": 70.0,
		"defense": 18.0,
		"speed": 72.0,
		"attack_speed": 0.8,
		"range": 6.0,
		"hp": 120.0
	},
	"aoe": {
		"attack": 40.0,
		"defense": 22.0,
		"speed": 60.0,
		"attack_speed": 1.2,
		"range": 4.0,
		"hp": 150.0
	},
	"control": {
		"attack": 25.0,
		"defense": 16.0,
		"speed": 68.0,
		"attack_speed": 1.0,
		"range": 5.0,
		"hp": 100.0
	},
	"support": {
		"attack": 20.0,
		"defense": 20.0,
		"speed": 65.0,
		"attack_speed": 1.0,
		"range": 4.0,
		"hp": 130.0
	}
}

const BREED_MODIFIERS := {
	"tabby": {
		"hp_mult": 1.0,
		"attack_mult": 1.0,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 1.0,
		"crit_rate_add": 0.0
	},
	"ragdoll": {
		"hp_mult": 1.2,
		"attack_mult": 0.9,
		"attack_speed_mult": 0.95,
		"move_speed_mult": 0.95,
		"crit_rate_add": 0.0
	},
	"siamese": {
		"hp_mult": 0.9,
		"attack_mult": 1.05,
		"attack_speed_mult": 1.1,
		"move_speed_mult": 1.15,
		"crit_rate_add": 0.02
	},
	"orange": {
		"hp_mult": 1.15,
		"attack_mult": 1.1,
		"attack_speed_mult": 0.9,
		"move_speed_mult": 0.95,
		"crit_rate_add": 0.0
	},
	"black": {
		"hp_mult": 0.85,
		"attack_mult": 1.05,
		"attack_speed_mult": 1.05,
		"move_speed_mult": 1.05,
		"crit_rate_add": 0.05
	},
	"british": {
		"hp_mult": 1.25,
		"attack_mult": 0.95,
		"attack_speed_mult": 0.95,
		"move_speed_mult": 0.9,
		"crit_rate_add": -0.02
	}
}

const PROFESSION_DISPLAY_ZH := {
	"sniper": "狙击猫",
	"aoe": "群攻猫",
	"control": "控制猫",
	"support": "辅助猫"
}

const BREED_DISPLAY_ZH := {
	"tabby": "虎斑",
	"ragdoll": "布偶",
	"siamese": "暹罗",
	"orange": "橘猫",
	"black": "黑猫",
	"british": "英短"
}

const RARITY_DISPLAY_ZH := {
	"grey": "灰",
	"green": "绿",
	"blue": "蓝",
	"purple": "紫"
}

const APPEARANCE_GENE_OPTIONS := {
	"head": ["round", "sharp", "wide"],
	"ear": ["upright", "fold", "big", "hairless"],
	"eye_color": ["blue", "green", "amber"],
	"eye_shape": ["round", "narrow"],
	"fur_main": ["orange", "black", "white", "gray"],
	"fur_accent": ["white", "tan", "none"],
	"pattern": ["none", "tabby", "tortoise", "spotted", "colorpoint"],
	"tail": ["long", "short", "curl", "bobtail"]
}

const HEAD_HP := {"round": 200.0, "sharp": 130.0, "wide": 300.0}
const EAR_RANGE := {"upright": 3.0, "fold": 2.0, "big": 4.0, "hairless": 2.5}
const EYE_COLOR_CRIT := {"blue": 0.05, "green": 0.10, "amber": 0.18}
const EYE_SHAPE_CRIT_MULT := {"round": 1.5, "narrow": 2.2}
const FUR_MAIN_ATTACK := {"orange": 12.0, "black": 16.0, "white": 9.0, "gray": 11.0}
const FUR_ACCENT_GOLD_MULT := {"white": 1.1, "tan": 1.2, "none": 1.0}
const TAIL_ATTACK_SPEED := {"long": 0.8, "short": 1.4, "curl": 1.1, "bobtail": 1.0}

const ACTIVE_SKILL_GENE_POOL := [
	"curious_lockon",
	"cold_paw",
	"battle_frenzy",
	"bulky_body",
	"cat_step",
	"self_heal",
	"chain_hit",
	"cleanup_blast",
	"survival_rush"
]

const COMBAT_PASSIVE_GENE_POOL := [
	"tenacity_revive",
	"resonance_stack",
	"desperado",
	"hunter_instinct",
	"invulnerable_frame",
	"berserk_factor",
	"lone_pride",
	"coward",
	"sleepyhead"
]

const CAMP_PASSIVE_GENE_POOL := [
	"hard_worker",
	"golden_paw",
	"mini_nurse",
	"love_spreader",
	"big_belly",
	"lucky_cat",
	"breeding_expert",
	"walnut_cracker",
	"builder_discount",
	"community_planner"
]

const ALL_SPECIAL_GENE_POOL := ACTIVE_SKILL_GENE_POOL + COMBAT_PASSIVE_GENE_POOL + CAMP_PASSIVE_GENE_POOL

# 基因稀有度（用于权重随机选择）
const GENE_RARITY := {
	# 战斗主动技能 → 蓝色（稀有）
	"curious_lockon": "blue", "cold_paw": "blue", "battle_frenzy": "blue",
	"bulky_body": "blue", "cat_step": "blue", "self_heal": "blue",
	"chain_hit": "blue", "cleanup_blast": "blue", "survival_rush": "blue",
	# 战斗被动 → 混合
	"tenacity_revive": "blue", "resonance_stack": "green", "desperado": "green",
	"hunter_instinct": "green", "invulnerable_frame": "blue", "berserk_factor": "green",
	"lone_pride": "green", "coward": "grey", "sleepyhead": "grey",
	# 后勤被动 → 灰/绿
	"hard_worker": "grey", "golden_paw": "green", "mini_nurse": "grey",
	"love_spreader": "grey", "big_belly": "grey", "lucky_cat": "green",
	"breeding_expert": "grey", "walnut_cracker": "grey",
	"builder_discount": "grey", "community_planner": "grey"
}

# 基因权重（按稀有度，用于重复入池）
# grey=3份, green=2份, blue=1份 → 自然概率分配
const GENE_RARITY_WEIGHT := {"grey": 3, "green": 2, "blue": 1}

# 猫永久等级系统
const CAT_LEVEL_CAP := 100
const GENE_LEVEL_INTERVAL := 10  # 每10级选一次技能基因
const CAT_XP_BASE := 150         # 每级所需 XP 基础值
const CAT_XP_INCREMENT := 2      # 每级额外增加的 XP

# 建筑工作每天贡献猫XP
const BUILDING_WORK_XP_PER_DAY := {
	"food_farm":       {1: 15, 2: 28, 3: 45},
	"gold_mine":       {1: 15, 2: 28, 3: 45},
	"fortune_cat":     {1: 18, 2: 32, 3: 50},
	"nursery":         {1: 8,  2: 16, 3: 28},
	"hospital":        {1: 8,  2: 16, 3: 28},
	"heart_cat_house": {1: 8,  2: 16, 3: 28}
}
const CAT_WANDER_XP_PER_DAY := 3  # 自由漫游每天获得的XP

const LIFECYCLE_STATUS_IDLE := "idle"
const LIFECYCLE_STATUS_EXPEDITION := "expedition"
const LIFECYCLE_STATUS_RETIRED := "retired"
const LIFECYCLE_STATUS_ELDER := "elder"
const LIFECYCLE_STATUS_DEAD := "dead"

const HEALTH_STATE_HEALTHY := "healthy"
const HEALTH_STATE_SICK := "sick"
const HEALTH_STATE_CRITICAL := "critical"

const BREEDING_GENE_INHERIT_PARENT := 0.45
const BREEDING_GENE_INHERIT_OTHER_PARENT := 0.45
const BREEDING_GENE_MUTATION := 0.10

const BATTLE_WEAPON_SLOT_CAP := 4
const BATTLE_CARD_CHOICE_COUNT := 3
const BATTLE_BASIC_CLAW_DAMAGE_MULT := 0.8
const BATTLE_BASIC_CLAW_INTERVAL := 1.0
const BATTLE_BASIC_CLAW_RANGE_TILES := 3.0
const BATTLE_TILE_SIZE := 64.0
const BATTLE_WEAPON_ATTACK_INTERVAL := 1.2
const BATTLE_WEAPON_DAMAGE_MULT := 0.55
const BATTLE_WEAPON_STACK_BONUS := 0.20
const BATTLE_WEAPON_SPREAD_DEGREES := 6.0
const BATTLE_ENEMY_MELEE_RANGE := 20.0
const BATTLE_ENEMY_MELEE_INTERVAL := 0.8
const BATTLE_SPAWN_CD_NORMAL_INITIAL := 3.5
const BATTLE_SPAWN_CD_NORMAL_MIN := 2.8
const BATTLE_SPAWN_CD_NORMAL_MAX := 4.2
const BATTLE_SPAWN_CD_ELITE_MIN := 3.0
const BATTLE_SPAWN_CD_ELITE_MAX := 4.8
const BATTLE_SPAWN_RADIUS_MIN := 260.0
const BATTLE_SPAWN_RADIUS_MAX := 380.0
const BATTLE_NORMAL_ROLL_SMALL_MONKEY := 0.55
const BATTLE_NORMAL_ROLL_STONE_MONKEY := 0.75
const BATTLE_NORMAL_ROLL_SWARM := 0.90
const BATTLE_NORMAL_SMALL_MONKEY_MIN := 2
const BATTLE_NORMAL_SMALL_MONKEY_MAX := 4
const BATTLE_NORMAL_STONE_MONKEY_MIN := 1
const BATTLE_NORMAL_STONE_MONKEY_MAX := 3
const BATTLE_NORMAL_SWARM_COUNT := 5
const BATTLE_ELITE_SMALL_MONKEY_MIN := 1
const BATTLE_ELITE_SMALL_MONKEY_MAX := 3
const BATTLE_ELITE_STONE_MONKEY_MIN := 0
const BATTLE_ELITE_STONE_MONKEY_MAX := 2

const BATTLE_NORMAL_DURATION := 90.0
const BATTLE_ELITE_DURATION_MIN := 120.0
const BATTLE_ELITE_DURATION_MAX := 180.0

const BATTLE_OPENING_WAVES := [
	{"time": 0.0, "small_monkey": 4},
	{"time": 5.0, "small_monkey": 3},
	{"time": 10.0, "small_monkey": 3, "stone_monkey": 2}
]

const LEVEL_UP_XP := [5, 15, 25, 35, 45]
const LEVEL_UP_XP_INCREMENT_AFTER_TABLE := 15
const FIRST_LEVEL_WEAPON_ONLY := true

const ENEMY_FISH_DROP := {
	"small_monkey": 1,
	"stone_monkey": 2,
	"monkey_swarm": 1,
	"tank_gorilla": 5,
	"poison_monkey": 2,
	"bomb_monkey": 2,
	"elite_monkey": 15,
	"boss_gorilla_king": 50
}

const EXPEDITION_TOTAL_LAYERS := 6
const EXPEDITION_BOSS_LAYER := 6
const EXPEDITION_BATTLE_REWARD_SUCCESS_MULT := 50
const EXPEDITION_BATTLE_REWARD_FAIL_MULT := 20
const EXPEDITION_NODE_COUNT_MIN := 2
const EXPEDITION_NODE_COUNT_MAX := 2
const EXPEDITION_QUESTION_COIN_MIN := 15
const EXPEDITION_QUESTION_COIN_MAX := 35
const EXPEDITION_MYSTERY_BUFF_VARIANTS := 3

const CAMP_CAT_SPAWN_RECT := Rect2(Vector2(160.0, 130.0), Vector2(760.0, 390.0))
const CAT_WANDER_MIN_MOVE_SPEED := 20.0
const CAT_WANDER_TARGET_REACHED_DISTANCE := 4.0

const EXPEDITION_NODE_PROBABILITIES := {
	1: {"battle_normal": 0.70, "battle_elite": 0.00, "event_question": 0.20, "shop": 0.10},
	2: {"battle_normal": 0.55, "battle_elite": 0.15, "event_question": 0.20, "shop": 0.10},
	3: {"battle_normal": 0.45, "battle_elite": 0.20, "event_question": 0.20, "shop": 0.15},
	4: {"battle_normal": 0.35, "battle_elite": 0.30, "event_question": 0.20, "shop": 0.15},
	5: {"battle_normal": 0.25, "battle_elite": 0.40, "event_question": 0.20, "shop": 0.15}
}

const QUESTION_EVENT_PROBABILITIES := {
	"coin_bonus": 0.30,
	"mystery_buff": 0.25,
	"stray_kitten": 0.20,
	"trouble": 0.15,
	"story": 0.10
}
