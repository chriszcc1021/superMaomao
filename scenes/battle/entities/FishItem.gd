class_name FishItem
extends Node2D

# 小鱼干掉落物，落地后等待玩家拾取
# 进入磁吸范围后自动向玩家移动，进入拾取范围后收集

signal collected(amount: int)

const MAGNET_SPEED := 180.0   # 磁吸移动速度（px/s）
const COLLECT_RADIUS := 20.0  # 实际拾取距离（px）
const BOB_AMPLITUDE := 3.0    # 上下浮动幅度（视觉）
const BOB_SPEED := 3.0        # 浮动频率

var amount: int = 1
var _player: Node2D = null
var _elapsed: float = 0.0
var _collected: bool = false

static func spawn(parent: Node, world_pos: Vector2, fish_amount: int, player: Node2D) -> void:
	var item := FishItem.new()
	item.global_position = world_pos
	item.amount = fish_amount
	item._player = player
	parent.add_child(item)

func _process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta

	if _player == null or not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	var magnet_radius: float = BASE_PICKUP_MAGNET_RADIUS

	# 读取玩家当前磁吸范围（支持卡牌增强）
	if _player.get("pickup_magnet_radius") != null:
		magnet_radius = float(_player.get("pickup_magnet_radius"))

	# 进入实际拾取距离 → 收集
	if dist <= COLLECT_RADIUS:
		_do_collect()
		return

	# 进入磁吸范围 → 向玩家移动
	if dist <= magnet_radius:
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta

	queue_redraw()

const BASE_PICKUP_MAGNET_RADIUS := 80.0

func _do_collect() -> void:
	if _collected:
		return
	_collected = true
	collected.emit(amount)
	queue_free()

func _draw() -> void:
	# 上下浮动效果
	var bob_offset := sin(_elapsed * BOB_SPEED) * BOB_AMPLITUDE
	# 小鱼干：黄色小菱形
	var points := PackedVector2Array([
		Vector2(0.0, -6.0 + bob_offset),
		Vector2(5.0, bob_offset),
		Vector2(0.0, 6.0 + bob_offset),
		Vector2(-5.0, bob_offset)
	])
	draw_colored_polygon(points, Color(1.0, 0.88, 0.2, 1.0))
	# 高光点
	draw_circle(Vector2(-1.5, -2.0 + bob_offset), 1.2, Color(1.0, 1.0, 0.8, 0.8))
