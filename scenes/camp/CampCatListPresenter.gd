extends RefCounted

const GameConstants := preload("res://data/constants.gd")
const CatData := preload("res://resources/CatData.gd")

const STATUS_DISPLAY := {
	GameConstants.LIFECYCLE_STATUS_IDLE: "待命",
	GameConstants.LIFECYCLE_STATUS_EXPEDITION: "远征中",
	GameConstants.LIFECYCLE_STATUS_RETIRED: "退休",
	GameConstants.LIFECYCLE_STATUS_ELDER: "老年",
	GameConstants.LIFECYCLE_STATUS_DEAD: "死亡",
	GameConstants.LIFECYCLE_STATUS_BURIED: "已入葬",
}

func refresh(label: RichTextLabel, game_state: Node) -> void:
	if label == null or game_state == null:
		return
	var lines: PackedStringArray = []
	for cat: CatData in game_state.cats:
		if cat == null:
			continue
		if cat.status == GameConstants.LIFECYCLE_STATUS_BURIED:
			continue
		var health_tag := _health_tag(cat)
		var dead_tag := " 💀（拖入墓地入葬）" if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD else ""
		lines.append(
			"%s | %s | %s | %s | %d天 | %s%s%s"
			% [
				cat.cat_name,
				GameConstants.sex_display(cat.sex),
				GameConstants.profession_zh(cat.profession),
				GameConstants.breed_zh(cat.breed),
				cat.age_days,
				_cat_runtime_status_text(cat, game_state),
				health_tag,
				dead_tag,
			]
		)
	if lines.is_empty():
		label.text = "选择你的第一只猫开始游戏。"
		return
	label.text = "\n".join(lines)

func _health_tag(cat: CatData) -> String:
	if cat.status == GameConstants.LIFECYCLE_STATUS_DEAD:
		return ""
	match cat.health:
		GameConstants.HEALTH_STATE_SICK:
			return " 🤒"
		GameConstants.HEALTH_STATE_CRITICAL:
			return " 🆘"
	return ""

func _cat_runtime_status_text(cat: CatData, game_state: Node) -> String:
	var status_text := _status_zh(cat.status)
	if game_state.has_method("is_cat_breeding") and game_state.is_cat_breeding(cat):
		status_text += " / 繁育中"
	return status_text

func _status_zh(status_id: String) -> String:
	return str(STATUS_DISPLAY.get(status_id, status_id))
