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
	_update_processing()
	queue_redraw()

# Kablo konnektöre takıldığında kalıcı olarak ekle
func add_cable(part: PartItem, from: Vector2, from_dir: Vector2, target: Rect2, broken: bool = false, animate: bool = true) -> void:
	var cable: Dictionary = {
		"part": part,
		"from": from, "from_dir": from_dir,
		"to": PartArt.entry_point(target, part.data.cable_entry), "to_dir": part.data.cable_entry,
		"color": part.data.cable_color, "width": part.data.cable_width,
		"target": target, "flash": 0.0, "broken": broken,
	}
	cables.append(cable)
	_update_processing()
	queue_redraw()
	if animate:
		# Takılma anında kısa bir parlama
		var set_flash: Callable = func(v: float) -> void:
			cable["flash"] = v
			queue_redraw()
		create_tween().tween_method(set_flash, 1.0, 0.0, 0.6)

# Söküm animasyonu: kablonun ucu artık sabit konnektörü değil, hareket eden fişi takip eder
func follow_part(part: PartItem) -> void:
	for cable: Dictionary in cables:
		if cable["part"] == part:
			cable["follow"] = true
	_update_processing()

# Fişin konnektörden çıktığı anda kıvılcımlı "pop" efekti
var pops: Array[Dictionary] = [] ## {center, color, life}

func pop_at(center: Vector2, color: Color) -> void:
	var pop: Dictionary = {"center": center, "color": color, "life": 1.0}
	pops.append(pop)
	_update_processing()
	var set_life: Callable = func(v: float) -> void:
		pop["life"] = v
	var finish: Callable = func() -> void:
		pops.erase(pop)
		_update_processing()
	var tween: Tween = create_tween()
	tween.tween_method(set_life, 1.0, 0.0, 0.35)
	tween.tween_callback(finish)

# Kabloyu (fişiyle birlikte) kaldırır
func remove_cable(part: PartItem) -> void:
	for i: int in range(cables.size() - 1, -1, -1):
		if cables[i]["part"] == part:
			cables.remove_at(i)
	_update_processing()
	queue_redraw()

# Sürükleme veya bozuk kablo kıvılcımı varken her kare yeniden çiz
func _update_processing() -> void:
	var needs: bool = _drag_part != null or not pops.is_empty()
	for cable: Dictionary in cables:
		if cable["broken"] or cable.get("follow", false):
			needs = true
	set_process(needs)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for cable: Dictionary in cables:
		if cable.get("follow", false) and is_instance_valid(cable["part"]):
			var part: PartItem = cable["part"]
			var r: Rect2 = part.get_global_rect()
			r.position -= global_position
			cable["to"] = PartArt.entry_point(r, part.data.cable_entry)
		var pts: PackedVector2Array = _draw_cable(cable["from"], cable["from_dir"], cable["to"], cable["to_dir"], cable["color"], cable["width"])
		if cable["broken"]:
			_draw_damage(pts, cable["width"])
		_draw_origin_plug(cable["from"], cable["from_dir"], cable["color"], cable["width"])
		var flash: float = cable["flash"]
		if flash > 0.0:
			UIStyle.draw_rect_glow(self, cable["target"], 12.0, Color(cable["color"], flash))

	for pop: Dictionary in pops:
		var life: float = pop["life"]
		var c: Vector2 = pop["center"]
		var col: Color = pop["color"]
		draw_circle(c, 4.0 + 10.0 * (1.0 - life), Color(col, 0.35 * life))
		for k: int in range(8):
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0 + 0.3)
			var inner: float = 6.0 + 14.0 * (1.0 - life)
			draw_line(c + dir * inner, c + dir * (inner + 6.0 * life), Color(1.0, 0.9, 0.5, life), 1.5, true)

	if _drag_part and is_instance_valid(_drag_part):
		var data: ComponentData = _drag_part.data
		var r: Rect2 = _drag_part.get_global_rect()
		r.position -= global_position
		_draw_cable(_drag_from, _drag_dir, PartArt.entry_point(r, data.cable_entry), data.cable_entry, data.cable_color, data.cable_width)
		_draw_origin_plug(_drag_from, _drag_dir, data.cable_color, data.cable_width)

func _draw_cable(from: Vector2, from_dir: Vector2, to: Vector2, to_dir: Vector2, color: Color, width: float) -> PackedVector2Array:
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
	return pts

# Bozuk kablo: ortasında yırtık kılıf, açıkta bakır teller ve ara ara kıvılcım
func _draw_damage(pts: PackedVector2Array, width: float) -> void:
	if pts.size() < 4:
		return
	var i: int = int(pts.size() * 0.55)
	var p: Vector2 = pts[i]
	var tangent: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[i - 1]).normalized()
	var normal: Vector2 = tangent.orthogonal()
	var half: float = width * 0.5 + 1.5
	# Yanık / yırtık bölge
	draw_line(p - tangent * 6.0, p + tangent * 6.0, Color("#1c1917"), width + 3.0, true)
	draw_line(p - tangent * 3.0, p + tangent * 3.0, Color("#0c0a09"), width + 1.0, true)
	# Açıkta kalan bakır teller
	for k: int in range(3):
		var offset: float = (float(k) - 1.0) * half * 0.6
		var a: Vector2 = p - tangent * 5.0 + normal * offset
		var b: Vector2 = p + tangent * 5.0 + normal * (offset + (1.5 if k % 2 == 0 else -1.5))
		draw_line(a, b, Color("#f59e0b"), 1.2, true)
	# Kıvılcım (yaklaşık 1,6 saniyede bir, kısa süreli)
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, 1.6)
	if t < 0.22:
		var strength: float = 1.0 - t / 0.22
		for k: int in range(6):
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 6.0 + float(Time.get_ticks_msec() / 90) * 0.7)
			draw_line(p + dir * 3.0, p + dir * (6.0 + 8.0 * strength), Color(1.0, 0.85, 0.3, strength), 1.5, true)
		draw_circle(p, 3.0 * strength + 1.0, Color(1.0, 0.95, 0.6, strength))

# Kaynak porttaki küçük fiş
func _draw_origin_plug(from: Vector2, dir: Vector2, color: Color, width: float) -> void:
	var size: Vector2 = Vector2(width + 8.0, 14.0) if dir.y != 0.0 else Vector2(14.0, width + 8.0)
	var center: Vector2 = from + dir * 4.0
	UIStyle.box(Color("#111827"), 2, 1, color.darkened(0.2)).draw(get_canvas_item(), Rect2(center - size / 2.0, size))
