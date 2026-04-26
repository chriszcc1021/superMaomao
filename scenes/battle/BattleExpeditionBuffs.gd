extends RefCounted

func apply(game_state: Node, player_cat: Node, grant_bonus_card: Callable, dmg_taken_modifier: float) -> float:
	if game_state == null:
		return dmg_taken_modifier
	var next_dmg_taken_modifier := dmg_taken_modifier
	var consume_list: Array = []
	for buff in game_state.expedition_buffs:
		var parsed: Dictionary = _parse_buff(buff)
		var effect_key: String = str(parsed.get("effect_key", ""))
		var value: float = float(parsed.get("value", 0.0))
		if effect_key.is_empty():
			continue
		match effect_key:
			"attack":
				player_cat.apply_buff("attack", value)
			"crit_rate":
				player_cat.apply_buff("crit_rate", value)
			"crit_mult":
				player_cat.apply_buff("crit_rate", value * 0.5)
			"move_speed":
				player_cat.apply_buff("move_speed", value)
			"aspd":
				if player_cat.has_method("get_weapon_system"):
					player_cat.get_weapon_system().call("set_dynamic_bonuses", value, 0.0)
			"max_hp":
				player_cat.apply_buff("max_hp", value)
			"dmg_taken_next":
				next_dmg_taken_modifier = 1.0 + value
				consume_list.append(buff)
			"immediate_hp_restore_pct":
				player_cat.heal(player_cat.max_hp * value)
				consume_list.append(buff)
			"immediate_hp_cost_pct":
				var dmg: float = float(player_cat.max_hp) * value
				var safe_dmg: float = minf(dmg, float(player_cat.current_hp) - 1.0)
				if safe_dmg > 0.0:
					player_cat.take_damage(safe_dmg)
				consume_list.append(buff)
			"regen_per_battle":
				player_cat.heal(player_cat.max_hp * value)
			"grant_card_on_battle_start":
				grant_bonus_card.call()
				consume_list.append(buff)

	for used in consume_list:
		game_state.expedition_buffs.erase(used)
	return next_dmg_taken_modifier

func _parse_buff(buff) -> Dictionary:
	if buff is Dictionary:
		return {
			"effect_key": str(buff.get("effect_key", "")),
			"value": float(buff.get("value", 0.0)),
		}
	if buff is String:
		var parts := str(buff).split(":")
		if parts.size() == 2:
			return {
				"effect_key": parts[0],
				"value": float(parts[1]),
			}
	return {}
