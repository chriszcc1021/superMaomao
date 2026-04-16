extends Node

const CatData := preload("res://resources/CatData.gd")
const CardData := preload("res://resources/CardData.gd")

signal building_built(building_id: String)
signal stray_cat_arrived(cat: CatData)
signal breeding_success(offspring: CatData)

signal expedition_started(cat: CatData)
signal expedition_ended(success: bool, coins_earned: int)

signal battle_started
signal battle_ended(victory: bool)
signal player_leveled_up(level: int)
signal card_selected(card: CardData)
