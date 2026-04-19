extends Control

const WeaponCards := preload("res://data/cards/weapon_cards.gd")
const BuffCards := preload("res://data/cards/buff_cards.gd")

var _shop_cards: Array[Dictionary] = []
var _purchased: bool = false

func _ready() -> void:
	_roll_shop_cards()
	_build_ui()

func _roll_shop_cards() -> void:
	var pool: Array[Dictionary] = []
	for d: Dictionary in WeaponCards.get_pool():
		pool.append(d)
	for d: Dictionary in BuffCards.get_pool():
		pool.append(d)
	pool.shuffle()
	_shop_cards.clear()
	for d: Dictionary in pool:
		_shop_cards.append(d)
		if _shop_cards.size() >= 3:
			break

func _build_ui() -> void:
	var game_state := _get_game_state()

	# 背景遮罩
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 主面板
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560.0, 420.0)
	panel.position = Vector2(-280.0, -210.0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "🛒 旅行商人"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 金币余额
	var coins_label := Label.new()
	var cur_coins: int = int(game_state.coins) if game_state != null else 0
	coins_label.text = "当前金币：%d" % cur_coins
	coins_label.name = "CoinsLabel"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(coins_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 卡牌展示区
	var cards_hbox := HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(cards_hbox)

	for i in _shop_cards.size():
		var card_def: Dictionary = _shop_cards[i]
		var card_panel := _build_card_slot(card_def, i)
		cards_hbox.add_child(card_panel)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = "跳过，继续前进"
	skip_btn.pressed.connect(_on_skip_pressed)
	vbox.add_child(skip_btn)

func _build_card_slot(card_def: Dictionary, idx: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(160.0, 200.0)

	var vb := VBoxContainer.new()
	slot.add_child(vb)

	var rarity: String = str(card_def.get("rarity", "grey"))
	var price: int = int(GameConstants.SHOP_CARD_PRICE.get(rarity, 30))
	var rarity_zh: String = str(GameConstants.RARITY_DISPLAY_ZH.get(rarity, rarity))

	var name_label := Label.new()
	name_label.text = str(card_def.get("name", "卡牌"))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("int_as_enum_without_cast")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = "【%s】" % rarity_zh
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", _rarity_color(rarity))
	vb.add_child(rarity_label)

	var desc_label := Label.new()
	desc_label.text = str(card_def.get("description", ""))
	@warning_ignore("int_as_enum_without_cast")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(desc_label)

	# 填充空间
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var price_label := Label.new()
	price_label.text = "%d 金" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	vb.add_child(price_label)

	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.name = "BuyBtn%d" % idx
	var game_state := _get_game_state()
	var coins: int = int(game_state.coins) if game_state != null else 0
	buy_btn.disabled = _purchased or coins < price
	buy_btn.pressed.connect(_on_buy_pressed.bind(idx, price, card_def))
	vb.add_child(buy_btn)

	return slot

func _on_buy_pressed(idx: int, price: int, card_def: Dictionary) -> void:
	if _purchased:
		return
	var game_state := _get_game_state()
	if game_state == null:
		return
	if not game_state.spend_coins(price):  # spend_coins 正确扣钱并检查余额
		return
	game_state.expedition_shop_cards.append(card_def)
	_purchased = true
	_update_after_purchase()

func _update_after_purchase() -> void:
	# 禁用所有购买按钮
	_disable_all_buy_buttons(get_node_or_null("PanelContainer"))
	# 更新金币标签（用find_child查找）
	var coins_label := find_child("CoinsLabel", true, false)
	if coins_label is Label:
		var gs := _get_game_state()
		(coins_label as Label).text = "当前金币：%d ✅ 购买成功！" % (int(gs.coins) if gs != null else 0)

func _disable_all_buy_buttons(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is Button and child.name.begins_with("BuyBtn"):
			(child as Button).disabled = true
		_disable_all_buy_buttons(child)

func _on_skip_pressed() -> void:
	_finish_shop()

func _finish_shop() -> void:
	# 推进远征层数
	var game_state := _get_game_state()
	if game_state != null and game_state.expedition_active:
		game_state.advance_expedition_layer()
	var scene_manager := _get_scene_manager()
	if scene_manager != null:
		scene_manager.return_from_shop()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"green":  return Color(0.3, 0.9, 0.4)
		"blue":   return Color(0.35, 0.6, 1.0)
		"purple": return Color(0.75, 0.3, 1.0)
		_:        return Color(0.85, 0.85, 0.85)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")
