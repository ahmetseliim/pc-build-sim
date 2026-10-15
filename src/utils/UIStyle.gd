class_name UIStyle
extends RefCounted

# Ortak görsel stil yardımcıları.
# HTML/CSS sürümündeki görünümü (yazı tipleri, yuvarlak köşeler, kesikli
# kenarlıklar, gradyanlar, gölgeler) Godot'un çizim API'si ile yeniden üretir.

const UI_FONT_NAMES: Array = ["Segoe UI", "Tahoma", "Geneva", "Verdana", "Roboto", "Noto Sans", "sans-serif"]
const MONO_FONT_NAMES: Array = ["Courier New", "Courier", "Liberation Mono", "monospace"]

static var _fonts: Dictionary = {}

# Arayüz yazı tipi (HTML'deki 'Segoe UI' yığını). spacing: harf aralığı (px)
static func ui_font(bold: bool = true, spacing: int = 0) -> Font:
	var key: String = "ui_%d_%d" % [int(bold), spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base: SystemFont = SystemFont.new()
	base.font_names = PackedStringArray(UI_FONT_NAMES)
	base.font_weight = 700 if bold else 400
	var result: Font = base
	if spacing != 0:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = spacing
		result = variation
	_fonts[key] = result
	return result

# BIOS ekranı için eş aralıklı yazı tipi
static func mono_font() -> Font:
	if _fonts.has("mono"):
		return _fonts["mono"]
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(MONO_FONT_NAMES)
	_fonts["mono"] = font
	return font

# CSS kutusu karşılığı StyleBoxFlat (arka plan, köşe, kenarlık, gölge)
static func box(bg: Color, radius: float, border_width: int = 0, border_color: Color = Color.TRANSPARENT,
		shadow_color: Color = Color.TRANSPARENT, shadow_size: int = 0, shadow_offset: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 10
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.shadow_color = shadow_color
	sb.shadow_size = shadow_size
	sb.shadow_offset = shadow_offset
	sb.anti_aliasing = true
	return sb

# Yuvarlak köşeli dikdörtgenin çevre noktaları (saat yönünde)
static func rounded_points(rect: Rect2, radius: float, segments: int = 8) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	radius = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	if radius < 0.5:
		pts.append(rect.position)
		pts.append(Vector2(rect.end.x, rect.position.y))
		pts.append(rect.end)
		pts.append(Vector2(rect.position.x, rect.end.y))
		return pts
	var centers: Array[Vector2] = [
		rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
	]
	var start_angles: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]
	for i: int in range(4):
		for s: int in range(segments + 1):
			var a: float = start_angles[i] + (PI / 2.0) * float(s) / float(segments)
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * radius)
	return pts

# Çember noktaları
static func circle_points(center: Vector2, radius: float, segments: int = 48) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments):
		var a: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

# CSS 'linear-gradient(135deg, c1, c2)' karşılığı, yuvarlak köşeli dolgu
static func draw_diagonal_gradient(ci: CanvasItem, rect: Rect2, radius: float, c1: Color, c2: Color) -> void:
	var pts: PackedVector2Array = rounded_points(rect, radius)
	var colors: PackedColorArray = PackedColorArray()
	var center: Vector2 = rect.get_center()
	var dir: Vector2 = Vector2(1, 1).normalized()
	var length: float = (rect.size.x + rect.size.y) * 0.70710678
	for p: Vector2 in pts:
		var t: float = clampf(0.5 + (p - center).dot(dir) / length, 0.0, 1.0)
		colors.append(c1.lerp(c2, t))
	ci.draw_polygon(pts, colors)

# Kapalı bir çokgen boyunca kesikli çizgi (CSS 'border: dashed')
static func draw_dashed_loop(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var on: bool = true
	var remaining: float = dash
	var current: PackedVector2Array = PackedVector2Array([pts[0]])
	for i: int in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var seg: float = a.distance_to(b)
		var pos: float = 0.0
		while seg - pos > 0.0001:
			var step: float = minf(remaining, seg - pos)
			pos += step
			remaining -= step
			var p: Vector2 = a.lerp(b, pos / seg)
			if on:
				current.append(p)
			if remaining <= 0.0001:
				if on and current.size() >= 2:
					ci.draw_polyline(current, color, width, true)
				on = not on
				remaining = dash if on else gap
				current = PackedVector2Array([p])
	if on and current.size() >= 2:
		ci.draw_polyline(current, color, width, true)

# Yumuşak kenarlı daire (gölge / parlama efekti için)
static func draw_soft_circle(ci: CanvasItem, center: Vector2, radius: float, spread: float, color: Color, steps: int = 6) -> void:
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		ci.draw_circle(center, radius + spread * (1.0 - t), Color(color, color.a / float(steps)))

# Dikdörtgen etrafında dışa doğru solan parlama (CSS 'box-shadow: 0 0 Npx')
static func draw_rect_glow(ci: CanvasItem, rect: Rect2, spread: float, color: Color, steps: int = 8) -> void:
	for i: int in range(steps):
		var t: float = float(i + 1) / float(steps)
		ci.draw_rect(rect.grow(spread * t), Color(color, color.a * (1.0 - t) * 0.5), false, spread / float(steps) + 1.0)
