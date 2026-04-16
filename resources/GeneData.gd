class_name GeneData
extends Resource

@export var id: String = ""
@export var gene_name: String = ""
@export_enum("active_skill", "combat_passive", "camp_passive") var gene_type: String = "active_skill"
@export_multiline var description: String = ""
@export var effect_params: Dictionary = {}
