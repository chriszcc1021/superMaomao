extends RefCounted

const WeaponCards := preload("res://data/cards/weapon_cards.gd")
const BuffCards := preload("res://data/cards/buff_cards.gd")
const CardData := preload("res://resources/CardData.gd")
const GameConstants := preload("res://data/constants.gd")

var _cards: Array[CardData] = []
var _card_by_id: Dictionary = {}
var _card_meta_by_id: Dictionary = {}

func load_shop_cards(game_state: Node, player_cat: Node) -> void:
	if game_state == null:
		return
	for card_def: Dictionary in game_state.expedition_shop_cards:
		var card := _build_card(card_def)
		_cards.append(card)
		_card_by_id[card.id] = card
		if card.card_type == "weapon":
			player_cat.get_weapon_system().apply_weapon_card(card)
		else:
			_apply_buff_card(card, player_cat)

func apply_card(card: CardData, player_cat: Node) -> void:
	var existing: CardData = _card_by_id.get(card.id, null)
	if existing == null:
		_cards.append(card)
		_card_by_id[card.id] = card
		existing = card
	elif card.card_type != "weapon" and existing.can_stack():
		existing.add_stack()

	if card.card_type == "weapon":
		player_cat.get_weapon_system().apply_weapon_card(existing)
		return

	_apply_buff_card(card, player_cat)

func apply_resonance_boost() -> void:
	for card: CardData in _cards:
		if str(card.card_type) == "buff":
			for i: int in card.values.size():
				card.values[i] = float(card.values[i]) * 1.05

func roll_cards(force_weapon_only: bool) -> Array[CardData]:
	var weapon_defs: Array[Dictionary] = WeaponCards.get_pool()
	var buff_defs: Array[Dictionary] = BuffCards.get_pool()
	var available: Array[Dictionary] = []

	for def: Dictionary in weapon_defs:
		if _can_offer_weapon(def):
			available.append(def)
	if not force_weapon_only:
		for def: Dictionary in buff_defs:
			available.append(def)
	if available.is_empty():
		return []

	available.shuffle()
	var result: Array[CardData] = []
	for def: Dictionary in available:
		var card := _build_card(def)
		result.append(card)
		if result.size() >= GameConstants.BATTLE_CARD_CHOICE_COUNT:
			break
	return result

func get_cards() -> Array[CardData]:
	return _cards

func _apply_buff_card(card: CardData, player_cat: Node) -> void:
	var meta: Dictionary = _card_meta_by_id.get(card.id, {})
	var effect_key: String = str(meta.get("effect_key", ""))
	var per_stack: float = float(meta.get("per_stack", 0.0))
	if not effect_key.is_empty() and per_stack > 0.0:
		player_cat.apply_buff(effect_key, per_stack)

func _can_offer_weapon(def: Dictionary) -> bool:
	var id: String = str(def.get("id", ""))
	if _card_by_id.has(id):
		var existing: CardData = _card_by_id[id]
		return existing.can_stack()
	var weapon_count := 0
	for card: CardData in _cards:
		if card.card_type == "weapon":
			weapon_count += 1
	return weapon_count < GameConstants.BATTLE_WEAPON_SLOT_CAP

func _build_card(def: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = str(def.get("id", ""))
	card.card_name = str(def.get("name", "card"))
	card.card_type = str(def.get("card_type", "weapon"))
	card.rarity = str(def.get("rarity", "grey"))
	card.description = str(def.get("description", ""))
	card.max_stacks = int(def.get("max_stacks", 3))
	_card_meta_by_id[card.id] = def
	return card
