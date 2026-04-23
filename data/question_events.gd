## question_events.gd — 奇遇事件数据定义（9个，每个2-3选项）
## 效果类型说明：
##   immediate_coins   → 立即增减金币
##   immediate_hp_pct  → 立即扣百分比HP（不写入最大值）
##   buff_max_hp       → 远征buff：最大HP倍率修正
##   buff_attack       → 远征buff：攻击倍率修正
##   buff_crit_rate    → 远征buff：暴击率加值
##   buff_move_speed   → 远征buff：移速倍率修正
##   buff_aspd         → 远征buff：攻速倍率修正（通过dyn_aspd）
##   buff_crit_mult    → 远征buff：暴击伤害倍率
##   next_battle_dmg_taken → 远征buff：下一场战斗受到伤害倍率
##   stray_cat         → 流浪猫加入队列
##   stray_cat_injured → 流浪猫加入队列（受伤状态）
##   gain_card_rarity  → 抽一张卡（稀有度偏高）
##   exchange_card     → 弃最低稀有卡+抽更高稀有卡
##   skip_buffs        → 随机失去一个buff
##   unknown_buff      → 随机好buff（不告知具体内容）
##   unknown_bad       → 随机坏事（不告知）
##   nothing           → 什么都不发生

class_name QuestionEvents

## 每个选项格式：{label, desc, effects: [{type, value, label}]}
## unknown=true 时 desc 显示 "?"，效果在选择后才揭晓

static func get_all_events() -> Array[Dictionary]:
	return [
		## 01 废弃鱼铺
		{
			"id": "abandoned_fish_shop",
			"title": "废弃鱼铺",
			"icon": "🐟",
			"description": "残破的鱼铺前，弥漫着久违的咸香。橱窗里还挂着几串干鱼，不知放了多久。",
			"choices": [
				{
					"label": "🍖 大快朵颐",
					"desc": "恢复 25% HP，但本次远征攻击 -8%",
					"effects": [
						{"type": "immediate_hp_pct", "value": 0.25, "label": "HP +25%"},
						{"type": "buff_attack", "value": -0.08, "label": "攻击 -8%"},
					]
				},
				{
					"label": "💰 带走变卖",
					"desc": "获得 20-30 金币",
					"effects": [
						{"type": "immediate_coins", "value": -1, "label": "获得 ?? 金币"},  # -1 = random
					]
				},
				{
					"label": "👃 闻闻就走",
					"desc": "下一场战斗攻速 +15%",
					"effects": [
						{"type": "buff_aspd", "value": 0.15, "label": "攻速 +15%"},
					]
				},
			]
		},
		## 02 受伤的流浪猫
		{
			"id": "injured_stray",
			"title": "受伤的流浪猫",
			"icon": "🩹",
			"description": "一只橘猫蜷在墙角，左爪缠着脏布，用警惕又期待的眼神看着你。",
			"choices": [
				{
					"label": "💊 花钱医治",
					"desc": "消耗 40 金币，它加入营地队列（属性略好）",
					"cost": {"type": "coins", "value": 40},
					"effects": [
						{"type": "immediate_coins", "value": -40, "label": "金币 -40"},
						{"type": "stray_cat", "value": 1, "label": "流浪猫加入队列"},
					]
				},
				{
					"label": "🤲 带走再说",
					"desc": "它加入营地队列，但健康状态为「受伤」",
					"effects": [
						{"type": "stray_cat_injured", "value": 1, "label": "受伤流浪猫加入队列"},
					]
				},
				{
					"label": "💪 它能理解我",
					"desc": "获得 buff「共鸣」：本次远征暴击率 +8%",
					"effects": [
						{"type": "buff_crit_rate", "value": 0.08, "label": "暴击率 +8%"},
					]
				},
			]
		},
		## 03 神秘猫咪商人
		{
			"id": "mysterious_merchant",
			"title": "神秘猫咪商人",
			"icon": "🏪",
			"description": "一只戴斗笠的肥猫拦住去路，摆出装满奇怪瓶瓶罐罐的小摊，笑眯眯地。",
			"choices": [
				{
					"label": "🧪 买神秘药剂",
					"desc": "消耗 50 金币。随机：HP上限+15% / 攻击+15% / 暴击+10%（不知道会出什么）",
					"cost": {"type": "coins", "value": 50},
					"effects": [
						{"type": "immediate_coins", "value": -50, "label": "金币 -50"},
						{"type": "unknown_buff", "value": 1, "label": "获得随机增益"},
					]
				},
				{
					"label": "🃏 以卡换卡",
					"desc": "弃最低稀有度的手牌，换一张更高稀有度的卡",
					"effects": [
						{"type": "exchange_card", "value": 1, "label": "换一张更好的卡"},
					]
				},
				{
					"label": "😤 赶走他",
					"desc": "获得 buff「警觉」：下一场战斗受到伤害 -15%",
					"effects": [
						{"type": "next_battle_dmg_taken", "value": -0.15, "label": "受到伤害 -15%"},
					]
				},
			]
		},
		## 04 古老猫神祠
		{
			"id": "ancient_shrine",
			"title": "古老猫神祠",
			"icon": "⛩️",
			"description": "荒草中矗立着一座小猫神祠，香炉里的灰烬还带着余温，不知是谁留下的。",
			"choices": [
				{
					"label": "🙏 虔诚祈祷",
					"desc": "消耗 25% HP。获得随机稀有 buff（不告诉你是什么）",
					"effects": [
						{"type": "immediate_hp_pct", "value": -0.25, "label": "HP -25%"},
						{"type": "unknown_buff", "value": 2, "label": "获得随机强力增益"},
					]
				},
				{
					"label": "💰 供奉香火",
					"desc": "消耗 60 金币。HP 恢复至满，且上限永久 +10%",
					"cost": {"type": "coins", "value": 60},
					"effects": [
						{"type": "immediate_coins", "value": -60, "label": "金币 -60"},
						{"type": "immediate_hp_pct", "value": 1.0, "label": "HP 回满"},
						{"type": "buff_max_hp", "value": 0.10, "label": "HP上限 +10%"},
					]
				},
				{
					"label": "🤲 顺手拿走香炉",
					"desc": "获得 45 金币，但下一场战斗受到伤害 +20%",
					"effects": [
						{"type": "immediate_coins", "value": 45, "label": "金币 +45"},
						{"type": "next_battle_dmg_taken", "value": 0.20, "label": "受到伤害 +20%"},
					]
				},
			]
		},
		## 05 镜中的自己
		{
			"id": "mirror_self",
			"title": "镜中的自己",
			"icon": "🪞",
			"description": "废弃大楼里有面锈迹斑斑的镜子，里面的你看起来比你更凶猛，也更危险。",
			"choices": [
				{
					"label": "⚡ 吸取镜中力量",
					"desc": "HP减半。攻击/暴击/攻速全部 +12%，持续本次远征",
					"effects": [
						{"type": "immediate_hp_pct", "value": -0.50, "label": "HP -50%"},
						{"type": "buff_attack", "value": 0.12, "label": "攻击 +12%"},
						{"type": "buff_crit_rate", "value": 0.12, "label": "暴击率 +12%"},
						{"type": "buff_aspd", "value": 0.12, "label": "攻速 +12%"},
					]
				},
				{
					"label": "🔨 打碎镜子",
					"desc": "随机好事或坏事（50/50，不知道结果）",
					"effects": [
						{"type": "unknown_good_or_bad", "value": 1, "label": "随机结果"},
					]
				},
				{
					"label": "🚶 装作没看见",
					"desc": "获得 buff「见怪不怪」：免疫下一个负面效果",
					"effects": [
						{"type": "buff_immunity_next_debuff", "value": 1, "label": "免疫下一个负面效果"},
					]
				},
			]
		},
		## 07 老武士的遗物
		{
			"id": "old_warrior_relic",
			"title": "老武士的遗物",
			"icon": "⚔️",
			"description": "废墟角落有个锈盒，里面是一位没有留下名字的老猫武士的武器和一封信。",
			"choices": [
				{
					"label": "⚔️ 继承遗志",
					"desc": "获得一张随机武器卡（稀有度偏高），HP -15%",
					"effects": [
						{"type": "immediate_hp_pct", "value": -0.15, "label": "HP -15%"},
						{"type": "gain_card_rarity", "value": 1, "label": "获得稀有武器卡"},
					]
				},
				{
					"label": "📦 带回营地",
					"desc": "不获得战斗效果，回营地后获得 60 金币",
					"effects": [
						{"type": "immediate_coins", "value": 60, "label": "金币 +60"},
					]
				},
				{
					"label": "✉️ 读完信再走",
					"desc": "获得 buff「哀荣」：本次远征暴击伤害 +25%",
					"effects": [
						{"type": "buff_crit_mult", "value": 0.25, "label": "暴击伤害 +25%"},
					]
				},
			]
		},
		## 08 迷路的三只幼猫
		{
			"id": "lost_kittens",
			"title": "迷路的三只幼猫",
			"icon": "🐱",
			"description": "三只幼猫围住你，用期待的眼神看着你，它们显然不知道自己在哪。",
			"choices": [
				{
					"label": "🐱 全带回营地",
					"desc": "三只加入等待队列（队列满则尽量加）",
					"effects": [
						{"type": "stray_cat", "value": 3, "label": "三只流浪猫加入队列"},
					]
				},
				{
					"label": "🗺️ 给它们指路",
					"desc": "获得 buff「领路者」：移速 +20%，持续本次远征",
					"effects": [
						{"type": "buff_move_speed", "value": 0.20, "label": "移速 +20%"},
					]
				},
				{
					"label": "📮 委托路人",
					"desc": "弃一张手牌，获得 45 金币",
					"effects": [
						{"type": "discard_worst_card", "value": 1, "label": "弃一张最差手牌"},
						{"type": "immediate_coins", "value": 45, "label": "金币 +45"},
					]
				},
			]
		},
		## 09 神秘符文石
		{
			"id": "rune_stone",
			"title": "神秘符文石",
			"icon": "🪨",
			"description": "一块刻满爪印的石头，触摸时有热流从掌心传来，像是某种古老的记忆。",
			"choices": [
				{
					"label": "✋ 吸收能量",
					"desc": "消耗 20% HP，获得一个随机主动基因（永久写入基因槽）",
					"effects": [
						{"type": "immediate_hp_pct", "value": -0.20, "label": "HP -20%"},
						{"type": "gain_active_gene", "value": 1, "label": "获得随机主动基因"},
					]
				},
				{
					"label": "📖 仔细研究",
					"desc": "获得一张随机卡（稀有度偏高）",
					"effects": [
						{"type": "gain_card_rarity", "value": 1, "label": "获得稀有卡"},
					]
				},
				{
					"label": "🔨 砸碎它",
					"desc": "获得 50 金币，但随机失去一个现有 buff",
					"effects": [
						{"type": "immediate_coins", "value": 50, "label": "金币 +50"},
						{"type": "lose_random_buff", "value": 1, "label": "失去随机一个 buff"},
					]
				},
			]
		},
		## 10 猫咪赌场
		{
			"id": "cat_casino",
			"title": "猫咪赌场",
			"icon": "🎲",
			"description": "一群猫围着一张旧桌子喧嚣，有猫向你招手：「来一局？胆子大的才能赢！」",
			"choices": [
				{
					"label": "🎲 梭哈（全押）",
					"desc": "押上全部金币：50% 翻倍，50% 清零",
					"effects": [
						{"type": "gamble_all_coins", "value": 1, "label": "50% 翻倍 / 50% 归零"},
					]
				},
				{
					"label": "🎰 小赌怡情（押20金）",
					"desc": "60% 获得 40 金币，40% 失去 20 金币",
					"cost": {"type": "coins", "value": 20},
					"effects": [
						{"type": "gamble_small", "value": 1, "label": "60%+40金 / 40%-20金"},
					]
				},
				{
					"label": "🚪 义正言辞离开",
					"desc": "获得 buff「自律」：每场战斗开始时回 5% HP",
					"effects": [
						{"type": "buff_regen_per_battle", "value": 0.05, "label": "每场战斗开始回 5% HP"},
					]
				},
			]
		},
	]

static func get_random_event() -> Dictionary:
	var events := get_all_events()
	return events[randi() % events.size()]
