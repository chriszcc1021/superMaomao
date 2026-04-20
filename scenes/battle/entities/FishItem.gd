class_name FishItem
extends Node2D

# 小鱼干掉落物，落地后等待玩家拾取
# 使用方法：
#   var item := FishItem.new()
#   item.global_position = world_pos
#   item.amount = fish_amount
#   item._player = player
#   parent.add_child(item)

signal collected(amount: int)

const MAGNET_SPEED := 180.0
const COLLECT_RADIUS := 20.0
const BOB_AMPLITUDE := 3.0
const BOB_SPEED := 3.0
const BASE_PICKUP_MAGNET_RADIUS := 80.0

var amount: int = 1
var _player: Node2D = null
var _elapsed: float = 0.0
var _collected: bool = false

func _process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta
	if _player == null or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	var magnet_radius: float = BASE_PICKUP_MAGNET_RADIUS
	if _player.get("pickup_magnet_radius") != null:
		magnet_radius = float(_player.get("pickup_magnet_radius"))
	if dist <= COLLECT_RADIUS:
		_do_collect()
		return
	if dist <= magnet_radius:
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta
	queue_redraw()

func _do_collect() -> void:
	if _collected:
		return
	_collected = true
	collected.emit(amount)
	queue_free()

func _draw() -> void:
	var bob_offset := sin(_elapsed * BOB_SPEED) * BOB_AMPLITUDE
	var points := PackedVector2Array([
		Vector2(0.0, -6.0 + bob_offset),
		Vector2(5.0, bob_offset),
		Vector2(0.0, 6.0 + bob_offset),
		Vector2(-5.0, bob_offset)
	])
	draw_colored_polygon(points, Color(1.0, 0.88, 0.2, 1.0))
	draw_circle(Vector2(-1.5, -2.0 + bob_offset), 1.2, Color(1.0, 1.0, 0.8, 0.8))
