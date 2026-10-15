class_name SlotOverlay
extends Control

# CPU soketi üzerindeki durum kaplaması (HTML sürümündeki .slot-overlay)
# Yarı saydam arka plan ve ortalanmış durum yazıları çizer.

# Macun tüpü simgesi (HTML'deki SVG yolu, 24x24 görünüm kutusu)
const TUBE_ICON: Array[Vector2] = [
	Vector2(15, 11), Vector2(15, 4), Vector2(14, 3), Vector2(10, 3), Vector2(9, 4), Vector2(9, 11),
	Vector2(6, 15), Vector2(6, 18), Vector2(7, 19), Vector2(17, 19), Vector2(18, 18), Vector2(18, 15),
]
const ICON_SIZE: float = 14.0

var bg_color: Color = Color(0, 0, 0, 0.6):
	set(value):
		bg_color = value
		queue_redraw()

# Her satır: {"text": String, "size": int, "color": Color, "icon": bool}
var lines: Array = []

var _tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_content(color: Color, new_lines: Array, animate: bool = true) -> void:
	lines = new_lines
	queue_redraw()
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_property(self, "bg_color", color, 0.3)
	else:
		bg_color = color

func _draw() -> void:
	UIStyle.box(bg_color, 4).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var font: Font = UIStyle.ui_font(true)
	var heights: Array[float] = []
	var total: float = 0.0
	for line: Dictionary in lines:
		var fs: int = line.get("size", 11)
		var h: float = font.get_multiline_string_size(line["text"], HORIZONTAL_ALIGNMENT_CENTER, size.x, fs).y
		heights.append(h)
		total += h
	var y: float = (size.y - total) / 2.0
	for i: int in range(lines.size()):
		var line: Dictionary = lines[i]
		var fs: int = line.get("size", 11)
		var color: Color = line.get("color", Color.WHITE)
		var text: String = line["text"]
		var baseline: float = y + font.get_ascent(fs)
		if line.get("icon", false):
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x: float = (size.x - w - 4.0 - ICON_SIZE) / 2.0
			draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			_draw_tube_icon(Vector2(x + w + 4.0, y + (heights[i] - ICON_SIZE) / 2.0), color)
		else:
			draw_multiline_string(font, Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, -1, color)
		y += heights[i]

func _draw_tube_icon(origin: Vector2, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in TUBE_ICON:
		pts.append(origin + p * (ICON_SIZE / 24.0))
	draw_colored_polygon(pts, color)
