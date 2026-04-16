# 《喵喵远征》Godot 架构文档

> 本文档是 Cursor 开发时的架构参考，所有脚本职责、场景结构、信号流向均以此为准。
> 设计细节见：游戏设计文档-v3.4.md

---

## 一、项目目录结构

```
res://
├── autoload/
│   ├── GameState.gd        # 全局游戏状态
│   ├── SceneManager.gd     # 场景切换管理
│   └── EventBus.gd         # 全局信号总线
│
├── data/
│   ├── constants.gd        # 所有游戏常量（基因池、建筑成本、数值等）
│   ├── genes/
│   │   ├── appearance_genes.gd   # 外观基因定义
│   │   ├── active_skill_genes.gd # 主动技能基因池
│   │   ├── combat_passive_genes.gd # 战斗被动基因池
│   │   └── camp_passive_genes.gd   # 营地被动基因池
│   ├── cards/
│   │   ├── weapon_cards.gd  # 武器卡数据
│   │   └── buff_cards.gd    # Buff卡数据
│   └── enemies/
│       └── enemy_data.gd    # 敌人数据定义
│
├── resources/
│   ├── CatData.gd           # 猫咪 Resource 类定义
│   ├── CardData.gd          # 卡牌 Resource 类定义
│   └── GeneData.gd          # 基因 Resource 类定义
│
├── scenes/
│   ├── camp/
│   │   ├── CampScene.tscn       # 营地主场景（等距视角）
│   │   ├── CampScene.gd
│   │   ├── buildings/
│   │   │   ├── CatHouse.tscn
│   │   │   ├── Nursery.tscn
│   │   │   ├── Hospital.tscn
│   │   │   ├── FoodFarm.tscn
│   │   │   ├── GoldMine.tscn
│   │   │   ├── Granary.tscn
│   │   │   ├── HeartCatHouse.tscn
│   │   │   └── Cemetery.tscn
│   │   └── ui/
│   │       ├── CampHUD.tscn     # 营地顶部HUD
│   │       ├── BreedingUI.tscn  # 繁育界面
│   │       └── CatListUI.tscn   # 猫咪列表
│   │
│   ├── expedition/
│   │   ├── ExpeditionMapUI.tscn # 远征地图（分叉路线选择）
│   │   └── ExpeditionMapUI.gd
│   │
│   ├── battle/
│   │   ├── BattleScene.tscn     # 战斗场景（Top-Down视角）
│   │   ├── BattleScene.gd
│   │   ├── entities/
│   │   │   ├── PlayerCat.tscn   # 玩家控制的猫
│   │   │   ├── PlayerCat.gd
│   │   │   ├── Enemy.tscn       # 敌人基类
│   │   │   └── enemies/         # 各种敌人
│   │   └── ui/
│   │       ├── BattleHUD.tscn   # 战斗HUD（HP/经验/计时器）
│   │       └── CardSelectUI.tscn # 升级选卡界面
│   │
│   └── common/
│       ├── CatSprite.tscn       # 猫咪通用 Sprite 组件
│       └── FloatingText.tscn    # 伤害数字浮动文字
│
└── assets/
    ├── sprites/
    │   ├── cats/            # 猫咪分层 Sprite（body/head/ear/eye/tail/pattern）
    │   ├── buildings/       # 建筑等距 Sprite
    │   ├── enemies/         # 敌人 Sprite
    │   └── cards/           # 卡牌图标
    └── fonts/
```

---

## 二、Autoload 全局单例

### GameState.gd
**职责：** 持有所有持久化游戏数据，是唯一的数据权威。

```gdscript
# 营地数据
var coins: int = 100
var cat_food: int = 50
var cat_food_cap: int = 200
var camp_day: int = 1

# 猫咪数据
var cats: Array[CatData] = []          # 营地中所有猫
var stray_cat_queue: Array[CatData] = [] # 流浪猫等待队列（最多3只）

# 远征数据
var expedition_active: bool = false
var expedition_cat_id: String = ""
var expedition_layer: int = 0
var expedition_battle_wins: int = 0
var expedition_buffs: Array = []

# 建筑状态
var buildings_built: Dictionary = {}  # {"nursery": true, "hospital": false, ...}
var cat_house_slots: int = 5          # 当前猫窝格数

# 信号
signal coins_changed(new_val: int)
signal cat_food_changed(new_val: int)
signal day_advanced(day: int)
signal cat_added(cat: CatData)
signal cat_died(cat: CatData)
```

### SceneManager.gd
**职责：** 所有场景切换必须通过此单例，不允许直接调用 `get_tree().change_scene_to_file()`。

```gdscript
func go_to_camp() -> void
func go_to_expedition_map() -> void
func go_to_battle(node_type: String) -> void
func return_from_battle(result: Dictionary) -> void
```

### EventBus.gd
**职责：** 跨场景通信的信号总线。

```gdscript
# 营地事件
signal building_built(building_id: String)
signal stray_cat_arrived(cat: CatData)
signal breeding_success(offspring: CatData)

# 远征事件
signal expedition_started(cat: CatData)
signal expedition_ended(success: bool, coins_earned: int)

# 战斗事件
signal battle_started
signal battle_ended(victory: bool)
signal player_leveled_up(level: int)
signal card_selected(card: CardData)
```

---

## 三、核心 Resource 类

### CatData.gd（extends Resource）

```gdscript
class_name CatData
extends Resource

# 身份
@export var id: String = ""
@export var cat_name: String = ""
@export var breed: String = "tabby"        # tabby/ragdoll/siamese/orange/black/british
@export var profession: String = "sniper"  # sniper/aoe/control/support

# 生命状态
@export var status: String = "idle"   # idle/expedition/retired/elder/dead
@export var health: String = "healthy" # healthy/sick/critical
@export var age_days: int = 0
@export var has_expeditioned: bool = false
@export var breed_count: int = 0       # 已繁育次数（上限3次）

# 外观基因（8槽）
@export var gene_head: String = "round"
@export var gene_ear: String = "upright"
@export var gene_eye_color: String = "blue"
@export var gene_eye_shape: String = "round"
@export var gene_fur_main: String = "orange"
@export var gene_fur_accent: String = "none"
@export var gene_pattern: String = "none"
@export var gene_tail: String = "long"

# 特殊基因槽（3槽，共用）
@export var gene_slot_1: String = ""  # 空字符串=空槽
@export var gene_slot_2: String = ""
@export var gene_slot_3: String = ""

# 计算出的属性（由基因+品种+职业计算）
var base_hp: float = 0.0
var base_attack: float = 0.0
var base_attack_speed: float = 0.0
var base_move_speed: float = 0.0
var base_range: float = 0.0
var base_crit_rate: float = 0.0
var base_crit_multiplier: float = 0.0
var gold_multiplier: float = 1.0

func calculate_stats() -> void:
    # 1. 外观基因 → 基础值
    # 2. × 品种修正
    # 3. + 职业基底
    pass
```

### CardData.gd（extends Resource）

```gdscript
class_name CardData
extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export var card_type: String = "weapon"  # weapon / buff
@export var rarity: String = "grey"       # grey / blue / purple
@export var description: String = ""
@export var stack_count: int = 1          # 当前叠加层数
@export var max_stacks: int = 3
@export var evolved: bool = false
@export var evolution_path: String = ""   # "A" or "B"

# 效果数值（根据叠加层数变化）
@export var values: Array[float] = []
```

---

## 四、场景详细结构

### CampScene.tscn（营地，等距视角）

```
CampScene (Node2D)
├── IsometricWorld (Node2D) [Y-Sort enabled]
│   ├── Tilemap (TileMapLayer)  # 地面瓦片
│   ├── Buildings (Node2D)
│   │   ├── CatHouse
│   │   ├── Nursery
│   │   ├── Hospital
│   │   ├── FoodFarm
│   │   ├── GoldMine
│   │   ├── Granary
│   │   ├── HeartCatHouse
│   │   └── Cemetery
│   └── Cats (Node2D)           # 动态添加的猫咪节点
├── Camera2D                    # 等距视角相机，可拖动
└── UI (CanvasLayer)
    ├── CampHUD                 # 顶部金币/猫粮/天数
    ├── SidePanel               # 右侧猫咪列表/出征/繁育按钮
    └── StrayNotification       # 流浪猫来访通知弹窗
```

**CampScene.gd 职责：**
- 初始化营地建筑和猫咪节点
- 响应 GameState 变化更新显示
- 处理玩家拖拽猫咪到建筑的交互
- 推进游戏日期（"过一天"按钮）

### BattleScene.tscn（战斗，Top-Down）

```
BattleScene (Node2D)
├── World (Node2D)
│   ├── Tilemap (TileMapLayer)  # 战场地面
│   ├── PlayerCat (CharacterBody2D)
│   │   ├── Sprite2D            # 猫咪外观
│   │   ├── CollisionShape2D
│   │   ├── WeaponSystem (Node) # 管理所有武器卡的攻击逻辑
│   │   └── HitBox (Area2D)
│   └── Enemies (Node2D)        # 动态生成的敌人
├── Camera2D                    # 跟随玩家
├── SpawnManager (Node)         # 按时间触发敌人生成
└── UI (CanvasLayer)
    ├── BattleHUD               # HP条/经验条/计时器/卡牌栏
    └── CardSelectUI            # 升级时弹出的三选一卡牌界面
```

**BattleScene.gd 职责：**
- 初始化玩家猫（从 GameState 读取猫咪数据）
- 启动 SpawnManager 按时间生成敌人
- 监听升级事件，弹出选卡界面
- 战斗结束后将结果返回 SceneManager

### PlayerCat.gd 职责：
- `_process(delta)`：读取 WASD 输入，移动
- `get_attack_direction()`：返回鼠标方向（有输入）或最近敌人方向（无输入）
- 不直接处理攻击逻辑，通过 WeaponSystem 代理

### WeaponSystem.gd 职责：
- 持有当前所有武器卡
- 每帧按各武器 CD 自动触发攻击
- 调用 `get_attack_direction()` 决定攻击方向

---

## 五、核心系统流程

### 繁育流程（BreedingSystem.gd）

```gdscript
func breed(father: CatData, mother: CatData) -> CatData:
    var offspring = CatData.new()
    # 1. 外观基因：每槽 45%父 / 45%母 / 10%随机突变
    offspring.gene_head = inherit_gene("head", father, mother)
    # ... 其余7个外观基因
    # 2. 特殊基因槽：每槽 45%父 / 45%母 / 10%突变
    offspring.gene_slot_1 = inherit_special_gene(father, mother)
    offspring.gene_slot_2 = inherit_special_gene(father, mother)
    offspring.gene_slot_3 = inherit_special_gene(father, mother)
    # 3. 计算初始属性
    offspring.calculate_stats()
    return offspring
```

### 日期推进流程（DayManager.gd）

```gdscript
func advance_day() -> void:
    GameState.camp_day += 1
    _consume_cat_food()      # 扣猫粮
    _check_cat_food_crisis() # 断粮检查
    _age_all_cats()          # 所有猫年龄+1天
    _check_lifecycle()       # 检查成长/老年/死亡
    _produce_resources()     # 建筑产出
    _roll_stray_cat()        # 流浪猫来访概率检定
    EventBus.day_advanced.emit(GameState.camp_day)
```

---

## 六、视角技术要点

### 营地等距视角（Isometric）
- Camera2D 旋转设为 0，通过等距 Tilemap 和斜角 Sprite 实现视觉效果
- Node2D 根节点开启 Y-Sort：`ysort_enabled = true`
- 等距坐标转换：`iso_pos = Vector2((x - y) * TILE_W / 2, (x + y) * TILE_H / 2)`
- 猫咪和建筑都需要等距角度的 Sprite（斜45°画法）

### 战斗 Top-Down 视角
- 标准2D正交摄像机，无旋转
- Camera2D 跟随 PlayerCat 节点
- Sprite 使用正面朝上的俯视角画法

---

## 七、开发优先级（第一阶段 MVP）

**Phase 1：数据层 + 营地骨架**
- [ ] CatData / CardData / GeneData Resource
- [ ] GameState Autoload
- [ ] constants.gd（所有数值）
- [ ] 营地场景（色块占位，无美术）
- [ ] 猫咪自动走动 AI

**Phase 2：繁育系统**
- [ ] breed() 遗传函数
- [ ] 繁育 UI
- [ ] 日期推进 + 猫粮消耗

**Phase 3：战斗系统**
- [ ] PlayerCat 移动 + 鼠标方向攻击
- [ ] 武器卡系统（WeaponSystem）
- [ ] 敌人生成器（SpawnManager）
- [ ] 升级选卡流程

**Phase 4：远征系统**
- [ ] 远征地图 UI（分叉路线）
- [ ] 节点类型分配
- [ ] 远征结算

**Phase 5：打通循环**
- [ ] 场景切换流程完整跑通
- [ ] 技能基因写回猫咪数据
- [ ] 整体测试

---

*文档版本：v1.0 | 更新日期：2026-04-15*
