# 《喵喵远征》Codex 开发规则

## 项目概述
Godot 4 + GDScript 的「营地建设养成 × 肉鸽远征 × 幸存者战斗 × 基因繁育」游戏。
- 设计文档：`游戏设计文档-v3.5.md`
- 架构文档：`ARCHITECTURE.md`

## 核心原则
- **严格按 ARCHITECTURE.md 的目录结构和脚本职责来**，不自行发明
- **每次只实现一个功能**，实现完跑通再进行下一个
- **数据与逻辑分离**：数据定义在 `res://data/`，逻辑在对应场景脚本
- **跨节点通信只用信号（Signal）**，禁止节点间直接引用兄弟节点
- **遇到设计文档没写的内容，停下来说明，不自行决定**

## 引擎规范
- 引擎：Godot 4.x
- 语言：GDScript（不使用 C#）
- 目标平台：PC（Windows/Mac）

## 命名规范
- 脚本文件：`snake_case.gd`
- 场景文件：`PascalCase.tscn`
- 节点名：`PascalCase`
- 常量：`ALL_CAPS`
- 变量/函数：`snake_case`
- 信号：`snake_case` 过去时（如 `cat_died`，`level_up`）

## Autoload 规则
- `GameState`：唯一全局状态持有者
- `SceneManager`：所有场景切换必须经过此单例
- `EventBus`：跨场景信号总线
- 禁止在 Autoload 以外持有跨场景引用

## GDScript 代码风格
```gdscript
class_name CatData
extends Resource

const MAX_GENE_SLOTS = 3

@export var cat_name: String = ""
var _current_hp: float = 0.0

signal hp_changed(new_hp: float)
signal cat_died

func _ready() -> void:
    pass

func deal_damage(amount: float) -> void:
    _current_hp = max(0.0, _current_hp - amount)
    hp_changed.emit(_current_hp)
    if _current_hp <= 0.0:
        cat_died.emit()
```

## 禁止事项
- ❌ 不用 `find_node()`，用 `@onready var` 或 `$NodePath`
- ❌ 不在 `_process()` 里做一次性逻辑
- ❌ 不硬编码路径字符串
- ❌ 单个脚本不超过 300 行，超了拆分
- ❌ 不跳过数据逻辑直接写 UI

## 开发顺序（Phase 顺序严格执行）

### Phase 1：数据层 + GameState
- [ ] `CatData.gd`（Resource）
- [ ] `CardData.gd`（Resource）
- [ ] `GeneData.gd`（Resource）
- [ ] `GameState.gd`（Autoload）
- [ ] `EventBus.gd`（Autoload）
- [ ] `SceneManager.gd`（Autoload）
- [ ] `constants.gd`（所有数值常量）

### Phase 2：营地场景骨架
- [ ] `CampScene.tscn`（等距视角，Y-Sort）
- [ ] 建筑色块占位
- [ ] 猫咪自动走动 AI
- [ ] 日期推进 + 猫粮消耗
- [ ] 流浪猫队列逻辑

### Phase 3：繁育系统
- [ ] `breed()` 遗传函数（45%父/45%母/10%突变）
- [ ] 繁育 UI（父母选择 + 属性预测）

### Phase 4：战斗系统
- [ ] `BattleScene.tscn`（Top-Down 俯视角）
- [ ] `PlayerCat.gd`（WASD移动 + 鼠标朝向）
- [ ] 基础爪击（通用，攻击力×0.8，间隔1.0s，射程3格，不占背包格）
- [ ] `WeaponSystem.gd`（管理武器卡自动触发）
- [ ] `SpawnManager.gd`（敌人生成，含开场密度：0s→4只小猴兵，5s→3只，10s→2投石猴+3小猴兵）
- [ ] 升级经验系统（小鱼干，Lv1→2只需5个，保证约10秒首升）
- [ ] 选卡界面（首升强制三选一武器卡，之后正常混合）

### Phase 5：远征系统
- [ ] `ExpeditionMapUI.tscn`（分叉路线，6层）
- [ ] 节点类型分配（概率配置见设计文档§4.4）
- [ ] 远征结算（写入基因槽）

### Phase 6：打通循环
- [ ] 场景切换完整流程
- [ ] 技能基因写回猫咪数据
- [ ] 整体测试

## 关键战斗数值（Phase 4 参考）
- 小鱼干掉落：小猴兵1，投石猴2，坦克猩猩5，精英15-25，Boss50
- 升级经验：Lv1→2需5个；Lv2→3需15；Lv3→4需25；之后每级+10递增
- 首次升级（Lv1→2）：选卡池只出武器卡
- 武器卡背包上限：4格（基础爪击不占格）
