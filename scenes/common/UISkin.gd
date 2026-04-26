class_name UISkin
extends RefCounted

const INK := Color(0.18, 0.12, 0.08, 1.0)
const PANEL_BG := Color(0.96, 0.89, 0.74, 0.94)
const PANEL_DARK := Color(0.22, 0.18, 0.14, 0.88)
const BUTTON_BG := Color(0.88, 0.68, 0.42, 1.0)

static func panel(bg: Color = PANEL_BG, border: Color = INK, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12.0)
	return style

static func dark_panel() -> StyleBoxFlat:
	return panel(PANEL_DARK, Color(0.08, 0.06, 0.05, 1.0), 8)

static func button(base: Color = BUTTON_BG, border: Color = INK, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8.0)
	return style

static func apply_panel(control: Control, dark: bool = false) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("panel", dark_panel() if dark else panel())

static func apply_button(button_node: BaseButton, base: Color = BUTTON_BG) -> void:
	if button_node == null:
		return
	button_node.add_theme_stylebox_override("normal", button(base))
	button_node.add_theme_stylebox_override("hover", button(base.lightened(0.08)))
	button_node.add_theme_stylebox_override("pressed", button(base.darkened(0.12)))
	button_node.add_theme_stylebox_override("disabled", button(Color(0.45, 0.42, 0.36, 0.7), Color(0.24, 0.22, 0.2, 0.8)))
	button_node.add_theme_color_override("font_color", INK)
	button_node.add_theme_color_override("font_hover_color", INK.darkened(0.1))
	button_node.add_theme_color_override("font_pressed_color", Color.WHITE)
	button_node.add_theme_color_override("font_disabled_color", Color(0.7, 0.67, 0.6, 1.0))

static func apply_card_button(button_node: Button, rarity: String) -> void:
	var color := rarity_color(rarity)
	apply_button(button_node, color.lerp(Color.WHITE, 0.18))
	button_node.add_theme_stylebox_override("normal", button(Color(0.22, 0.18, 0.15, 0.94), color, 8))
	button_node.add_theme_stylebox_override("hover", button(Color(0.3, 0.24, 0.2, 0.98), color.lightened(0.2), 8))
	button_node.add_theme_stylebox_override("pressed", button(Color(0.16, 0.13, 0.11, 1.0), color.darkened(0.12), 8))
	button_node.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82, 1.0))
	button_node.add_theme_color_override("font_hover_color", Color.WHITE)

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"blue":
			return Color(0.3, 0.58, 0.95, 1.0)
		"purple":
			return Color(0.72, 0.38, 0.95, 1.0)
		"green":
			return Color(0.35, 0.76, 0.4, 1.0)
	return Color(0.72, 0.72, 0.66, 1.0)

static func apply_label(label: Label, color: Color = INK) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)

static func apply_rich_text(text: RichTextLabel, dark: bool = false) -> void:
	if text == null:
		return
	text.add_theme_stylebox_override("normal", panel(Color(0.98, 0.93, 0.82, 0.35), Color(0.35, 0.25, 0.18, 0.35), 6))
	text.add_theme_color_override("default_color", Color(0.94, 0.9, 0.8, 1.0) if dark else INK)
