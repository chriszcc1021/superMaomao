class_name Projectile
extends Area2D

signal hit_enemy(projectile: Projectile, enemy: Node)

@export var speed: float = 420.0
@export var max_distance: float = 220.0
@export var damage: float = 10.0
@export var projectile_color: Color = Color(1.0, 0.9, 0.5, 1.0)

var _direction: Vector2 = Vector2.RIGHT
var _origin: Vector2 = Vector2.ZERO
var _travelled: float = 0.0

func _ready() -> void:
	_origin = global_position
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(direction: Vector2, amount: float, range_px: float, color: Color) -> void:
	_direction = direction.normalized()
	damage = amount
	max_distance = range_px
	projectile_color = color
	queue_redraw()

func _process(delta: float) -> void:
	var move := _direction * speed * delta
	global_position += move
	_travelled += move.length()
	if _travelled >= max_distance:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, projectile_color)
	draw_line(Vector2.ZERO, Vector2(-8, 0), projectile_color.darkened(0.4), 2.0)

func _on_body_entered(body: Node) -> void:
	if body != null and body.has_method("take_damage"):
		hit_enemy.emit(self, body)
	queue_free()
