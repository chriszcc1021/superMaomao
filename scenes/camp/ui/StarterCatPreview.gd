class_name StarterCatPreview
extends Control
## 首选猫卡片中的猫咪外观预览（Control版，无需SubViewport）

var cat_data: CatData = null

func setup(data: CatData) -> void:
	cat_data = data
	queue_redraw()

func _draw() -> void:
	if cat_data == null:
		return
	var center := size / 2.0
	var r := minf(size.x, size.y) * 0.30
	var cat_color := _get_cat_color()

	# ── 身体 ──
	draw_circle(center, r, cat_color)
	# ── 耳朵 ──
	var ear_r := r * 0.38
	var ear_offset := Vector2(r * 0.65, r * 0.78)
	draw_circle(center + Vector2(-ear_offset.x, -ear_offset.y), ear_r, cat_color)
	draw_circle(center + Vector2( ear_offset.x, -ear_offset.y), ear_r, cat_color)
	# 耳朵内侧
	var inner_ear := _lighter(cat_color, 0.25)
	draw_circle(center + Vector2(-ear_offset.x, -ear_offset.y), ear_r * 0.55, inner_ear)
	draw_circle(center + Vector2( ear_offset.x, -ear_offset.y), ear_r * 0.55, inner_ear)

	# ── 花纹叠加 ──
	_draw_pattern(center, r, cat_color)

	# ── 眼睛 ──
	var eye_color := _get_eye_color()
	var ex := r * 0.40
	var ey := r * 0.18
	draw_circle(center + Vector2(-ex, -ey), r * 0.22, eye_color)
	draw_circle(center + Vector2( ex, -ey), r * 0.22, eye_color)
	# 瞳孔
	var pupil_r := r * 0.10
	draw_circle(center + Vector2(-ex, -ey), pupil_r, Color.BLACK)
	draw_circle(center + Vector2( ex, -ey), pupil_r, Color.BLACK)
	# 眼睛高光
	draw_circle(center + Vector2(-ex + r * 0.06, -ey - r * 0.08), pupil_r * 0.55, Color(1, 1, 1, 0.85))
	draw_circle(center + Vector2( ex + r * 0.06, -ey - r * 0.08), pupil_r * 0.55, Color(1, 1, 1, 0.85))

	# ── 鼻子 ──
	draw_circle(center + Vector2(0, r * 0.22), r * 0.11, Color(0.98, 0.58, 0.60))
	# 嘴（两条斜线）
	var mouth_base := center + Vector2(0, r * 0.28)
	draw_line(mouth_base, mouth_base + Vector2(-r * 0.20, r * 0.15), Color(0.3, 0.15, 0.15, 0.7), 1.5)
	draw_line(mouth_base, mouth_base + Vector2( r * 0.20, r * 0.15), Color(0.3, 0.15, 0.15, 0.7), 1.5)

	# ── 轮廓描边 ──
	draw_arc(center, r, 0.0, TAU, 48, Color(0, 0, 0, 0.18), 1.5)

func _draw_pattern(center: Vector2, r: float, base_color: Color) -> void:
	if cat_data == null:
		return
	var stripe := base_color.darkened(0.30)
	match cat_data.gene_pattern:
		"tabby":
			for i in range(3):
				var y := center.y - r * 0.25 + i * (r * 0.32)
				draw_line(Vector2(center.x - r * 0.65, y), Vector2(center.x + r * 0.65, y), stripe, 2.0)
		"spotted":
			var spots := [Vector2(-0.35, 0.15), Vector2(0.30, 0.25), Vector2(0.05, -0.10), Vector2(-0.20, 0.35)]
			for sp in spots:
				draw_circle(center + (sp as Vector2) * r * 1.3, r * 0.18, stripe)
		"tortoise":
			var patches := [Vector2(-0.28, -0.10), Vector2(0.30, -0.15), Vector2(0.00, 0.30)]
			for p in patches:
				draw_circle(center + (p as Vector2) * r * 1.2, r * 0.28, Color(0.85, 0.42, 0.12, 0.50))
		"colorpoint":
			# 脸部颜色深
			draw_circle(center + Vector2(0, r * 0.45), r * 0.32, base_color.darkened(0.40))

func _lighter(c: Color, amount: float) -> Color:
	return Color(clampf(c.r + amount, 0.0, 1.0),
				 clampf(c.g + amount, 0.0, 1.0),
				 clampf(c.b + amount, 0.0, 1.0), c.a)

func _get_cat_color() -> Color:
	if cat_data == null:
		return Color(0.80, 0.70, 0.60)
	match cat_data.gene_fur_main:
		"orange": return Color(0.97, 0.65, 0.25)
		"black":  return Color(0.22, 0.22, 0.25)
		"white":  return Color(0.95, 0.95, 0.93)
		"gray":   return Color(0.62, 0.62, 0.66)
	return Color(0.82, 0.72, 0.58)

func _get_eye_color() -> Color:
	if cat_data == null:
		return Color(0.90, 0.75, 0.20)
	match cat_data.gene_eye_color:
		"blue":   return Color(0.35, 0.65, 0.95)
		"green":  return Color(0.28, 0.82, 0.42)
		"amber":  return Color(0.95, 0.70, 0.15)
	return Color(0.90, 0.75, 0.20)
