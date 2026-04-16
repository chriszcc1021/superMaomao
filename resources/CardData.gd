class_name CardData
extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export var card_type: String = "weapon"
@export var rarity: String = "grey"
@export_multiline var description: String = ""
@export var stack_count: int = 1
@export var max_stacks: int = 3
@export var evolved: bool = false
@export var evolution_path: String = ""
@export var values: Array[float] = []

func can_stack() -> bool:
	return stack_count < max_stacks

func add_stack() -> void:
	if can_stack():
		stack_count += 1
