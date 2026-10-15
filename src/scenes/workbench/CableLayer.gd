class_name CableLayer
extends Control

# Kablo katmanı
# Takılmış kabloları ve sürüklenmekte olan kabloyu, kaynağından (PSU portu veya
# anakart SATA portu) fişe kadar kıvrımlı bir eğri olarak çizer.

# Takılı kablolar: {from, from_dir, to, to_dir, color, width, target, flash}
var cables: Array[Dictionary] = []

var _drag_part: PartItem = null
var _drag_from: Vector2 = Vector2.ZERO
var _drag_dir: Vector2 = Vector2.UP

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

# Envanterden bir kablo tutulduğunda: kaynaktan imlece kablo uzat
func begin_drag(part: PartItem, from: Vector2, from_dir: Vector2) -> void:
	_drag_part = part
	_drag_from = from
	_drag_dir = from_dir
	set_process(true)

func end_drag() -> void:
	_drag_part = null
	set_process(false)
	queue_redraw()

# Kablo konnektöre takıldığında kalıcı olarak ekle
func add_cable(part: PartItem, from: Vector2, from_dir: Vector2, target: Rect2) -> void:
	var cable: Dictionary = {
		"from": from, "from_dir": from_dir,
		"to": PartArt.entry_point(target, part.data.cable_entry), "to_dir": part.data.cable_entry,
		"color": part.data.cable_color, "width": part.data.cable_width,
		"target": target, "flash": 1.0,
	}
	cables.append(cable)
	# Takılma anında kısa bir parlama
	var set_flash: Callable = func(v: float) -> void:
		cable["flash"] = v
		queue_redraw()
	create_tween().tween_method(set_flash, 1.0, 0.0, 0.6)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for cable: Dictionary in cables:
		_draw_cable(cable["from"], cable["from_dir"], cable["to"], cable["to_dir"], cable["color"], cable["width"])
		_draw_origin_plug(cable["from"], cable["from_dir"], cable["color"], cable["width"])
		var flash: float = cable["flash"]
		if flash > 0.0:
			UIStyle.draw_rect_glow(self, cable["target"], 12.0, Color(cable["color"], flash))

	if _drag_part and is_instance_valid(_drag_part):
		var data: ComponentData = _drag_part.data
		var r: Rect2 = _drag_part.get_global_rect()
		r.position -= global_position
		_draw_cable(_drag_from, _drag_dir, PartArt.entry_point(r, data.cable_entry), data.cable_entry, data.cable_color, data.cable_width)
		_draw_origin_plug(_drag_from, _drag_dir, data.cable_color, data.cable_width)

func _draw_cable(from: Vector2, from_dir: Vector2, to: Vector2, to_dir: Vector2, color: Color, width: float) -> void:
	var dist: float = from.distance_to(to)
	var k: float = clampf(dist * 0.45, 25.0, 180.0)
	var p1: Vector2 = from + from_dir * k
	var p2: Vector2 = to + to_dir * k
	var segments: int = clampi(int(dist / 8.0), 12, 80)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments + 1):
		pts.append(from.bezier_interpolate(p1, p2, to, float(i) / float(segments)))

	# Gölge, dış hat ve gövde
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		shadow.append(p + Vector2(2, 5))
	draw_polyline(shadow, Color(0, 0, 0, 0.3), width + 2.0, true)
	draw_polyline(pts, color.darkened(0.5), width + 2.0, true)
	draw_polyline(pts, color, width, true)

	# Örgülü kılıf dokusu ve parlaklık çizgisi
	var highlight: PackedVector2Array = PackedVector2Array()
	for i: int in range(pts.size()):
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var tangent: Vector2 = (b - a).normalized()
		var normal: Vector2 = tangent.orthogonal()
		highlight.append(pts[i] - normal * width * 0.22)
		if width >= 6.0 and i > 0 and i < pts.size() - 1:
			draw_line(pts[i] - normal * width * 0.45, pts[i] + normal * width * 0.45 + tangent * 2.0, Color(0, 0, 0, 0.18), 1.0, true)
	draw_polyline(highlight, Color(color.lightened(0.5), 0.55), maxf(1.0, width * 0.25), true)

# Kaynak porttaki küçük fiş
func _draw_origin_plug(from: Vector2, dir: Vector2, color: Color, width: float) -> void:
	var size: Vector2 = Vector2(width + 8.0, 14.0) if dir.y != 0.0 else Vector2(14.0, width + 8.0)
	var center: Vector2 = from + dir * 4.0
	UIStyle.box(Color("#111827"), 2, 1, color.darkened(0.2)).draw(get_canvas_item(), Rect2(center - size / 2.0, size))
