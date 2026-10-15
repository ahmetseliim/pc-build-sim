class_name PartArt
extends RefCounted

# Parça çizimleri
# Her donanım parçasını (CPU, fan, RAM, GPU, PSU, kablo fişleri...) emoji yerine
# sade vektör çizimlerle çizer. Envanterde ve anakartta aynı boyutta (1:1) kullanılır.

# Güç kaynağı üzerindeki kablo portları (PSU'ya göre yerel konum, kablonun çıkış yönü, port boyutu)
const PSU_PORTS: Dictionary = {
	"psu_atx": {"pos": Vector2(178, 0), "dir": Vector2(0, -1), "size": Vector2(22, 8)},
	"psu_eps": {"pos": Vector2(138, 0), "dir": Vector2(0, -1), "size": Vector2(14, 8)},
	"psu_pcie": {"pos": Vector2(38, 0), "dir": Vector2(0, -1), "size": Vector2(14, 8)},
	"psu_sata": {"pos": Vector2(0, 75), "dir": Vector2(-1, 0), "size": Vector2(8, 12)},
}

const GOLD: Color = Color("#d4a017")
const SHADOW: Color = Color(0, 0, 0, 0.35)

static func draw(ci: CanvasItem, d: ComponentData, r: Rect2, placed: bool, angle: float) -> void:
	if d.is_cable:
		_draw_plug(ci, d, r, placed)
		return
	match d.part_type:
		"cpu":
			_draw_cpu(ci, r)
		"paste":
			_draw_paste(ci, r)
		"fan":
			_draw_fan(ci, r, angle)
		"ram":
			_draw_ram(ci, d, r)
		"m2":
			_draw_m2(ci, r)
		"sata":
			_draw_sata(ci, r)
		"gpu":
			_draw_gpu(ci, r, angle)
		"psu":
			_draw_psu(ci, r, angle)
		_:
			_shadowed_box(ci, r, d.bg_color, d.corner_radius)
			_text(ci, r.get_center(), d.part_name, d.font_size, d.text_color)

# Kablonun fişten çıktığı kenarın orta noktası
static func entry_point(r: Rect2, dir: Vector2) -> Vector2:
	return r.get_center() + Vector2(dir.x * r.size.x / 2.0, dir.y * r.size.y / 2.0)

# --- Parçalar ---------------------------------------------------------------

static func _draw_cpu(ci: CanvasItem, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#94a3b8"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#cbd5e1"), Color("#64748b"))
	_box(ci, r, Color.TRANSPARENT, 6, 2, Color("#475569"))
	# Isı dağıtıcı kapak (IHS)
	var ihs: Rect2 = r.grow(-15)
	UIStyle.draw_diagonal_gradient(ci, ihs, 8, Color("#f1f5f9"), Color("#94a3b8"))
	_box(ci, ihs, Color.TRANSPARENT, 8, 1, Color(1, 1, 1, 0.55))
	# Yön işareti (altın üçgen)
	var p: Vector2 = r.position
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(5, r.size.y - 5), p + Vector2(17, r.size.y - 5), p + Vector2(5, r.size.y - 17)]), Color("#fbbf24"))
	_text(ci, ihs.get_center() + Vector2(0, -7), "Z-CORE", 13, Color("#334155"))
	_text(ci, ihs.get_center() + Vector2(0, 9), "i7 · 5.4 GHz", 8, Color("#475569"))

static func _draw_paste(ci: CanvasItem, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#334155"), 6, 1, Color("#64748b"))
	var o: Vector2 = r.position
	var y: float = 14.0
	# Şırınga: uç, gövde, macun, piston
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(5, y), o + Vector2(12, y - 4), o + Vector2(12, y + 4)]), Color("#94a3b8"))
	_box(ci, Rect2(o + Vector2(12, y - 6), Vector2(30, 12)), Color("#e2e8f0"), 3)
	_box(ci, Rect2(o + Vector2(14, y - 4), Vector2(18, 8)), Color("#94a3b8"), 2)
	ci.draw_rect(Rect2(o + Vector2(42, y - 1.5), Vector2(8, 3)), Color("#cbd5e1"))
	_box(ci, Rect2(o + Vector2(50, y - 6), Vector2(4, 12)), Color("#cbd5e1"), 1)
	_text(ci, Vector2(r.get_center().x, r.end.y - 8), "Macun", 8, Color.WHITE)

static func _draw_fan(ci: CanvasItem, r: Rect2, angle: float) -> void:
	_shadowed_box(ci, r, Color("#1e293b"), 8, 2, Color("#334155"))
	var c: Vector2 = r.get_center()
	var rad: float = minf(r.size.x, r.size.y) / 2.0 - 6.0
	ci.draw_circle(c, rad, Color("#0b1220"))
	ci.draw_arc(c, rad, 0.0, TAU, 48, Color("#0284c7"), 2.0, true)
	_blades(ci, c, rad * 0.3, rad * 0.92, 7, angle, Color(0.22, 0.74, 0.97, 0.9))
	ci.draw_circle(c, rad * 0.3, Color("#0f172a"))
	ci.draw_arc(c, rad * 0.3, 0.0, TAU, 24, Color("#0284c7"), 1.5, true)
	ci.draw_circle(c, rad * 0.12, Color("#0ea5e9"))

static func _draw_ram(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#1e293b"), 4, 1, Color("#334155"))
	var o: Vector2 = r.position
	var w: float = r.size.x
	var h: float = r.size.y
	# RGB şerit
	var bar: Rect2 = Rect2(o + Vector2(3, 3), Vector2(w - 6, 7))
	ci.draw_polygon(PackedVector2Array([bar.position, Vector2(bar.end.x, bar.position.y), bar.end, Vector2(bar.position.x, bar.end.y)]),
		PackedColorArray([Color("#22d3ee"), Color("#a855f7"), Color("#a855f7"), Color("#22d3ee")]))
	# Soğutucu üzerindeki çapraz desen
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(3, 30), o + Vector2(w - 3, 18), o + Vector2(w - 3, 32), o + Vector2(3, 44)]), Color(0.05, 0.65, 0.91, 0.55))
	# Altın kontaklar ve çentik
	var contacts: Rect2 = Rect2(o + Vector2(4, h - 12), Vector2(w - 8, 9))
	ci.draw_rect(contacts, GOLD)
	var x: float = contacts.position.x + 2.0
	while x < contacts.end.x:
		ci.draw_line(Vector2(x, contacts.position.y), Vector2(x, contacts.end.y), Color(0, 0, 0, 0.3), 1.0)
		x += 3.0
	ci.draw_rect(Rect2(o + Vector2(w * 0.4, h - 12), Vector2(3, 9)), Color("#1e293b"))
	_vtext(ci, o + Vector2(w / 2.0, h * 0.62), "DDR5 · " + d.part_name, 8, Color("#e2e8f0"))

static func _draw_m2(ci: CanvasItem, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#166534"), 3)
	var o: Vector2 = r.position
	var h: float = r.size.y
	# Altın bağlantı ucu
	ci.draw_rect(Rect2(o + Vector2(0, 4), Vector2(8, h - 8)), GOLD)
	var y: float = o.y + 6.0
	while y < o.y + h - 5.0:
		ci.draw_line(Vector2(o.x, y), Vector2(o.x + 8, y), Color(0, 0, 0, 0.3), 1.0)
		y += 3.0
	# Vida yuvası
	ci.draw_circle(Vector2(r.end.x, r.get_center().y), 6.0, Color(0, 0, 0, 0.45))
	# Çipler
	_box(ci, Rect2(o + Vector2(16, 9), Vector2(20, 20)), Color("#111827"), 2)
	var nand1: Rect2 = Rect2(o + Vector2(44, 7), Vector2(38, 24))
	var nand2: Rect2 = Rect2(o + Vector2(88, 7), Vector2(38, 24))
	_box(ci, nand1, Color("#111827"), 2)
	_box(ci, nand2, Color("#111827"), 2)
	_text(ci, nand1.get_center(), "NVMe", 8, Color("#cbd5e1"))
	_text(ci, nand2.get_center(), "1TB", 8, Color("#cbd5e1"))

static func _draw_sata(ci: CanvasItem, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#475569"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#64748b"), Color("#1e293b"))
	_box(ci, r, Color.TRANSPARENT, 6, 1, Color("#64748b"))
	var o: Vector2 = r.position
	var w: float = r.size.x
	# Etiket
	var sticker: Rect2 = Rect2(o + Vector2(12, 14), Vector2(w - 42, r.size.y - 28))
	_box(ci, sticker, Color("#0f766e"), 4, 1, Color("#2dd4bf"))
	_text(ci, sticker.get_center() + Vector2(0, -8), "SATA SSD", 12, Color.WHITE)
	_text(ci, sticker.get_center() + Vector2(0, 10), "1TB · 550 MB/s", 8, Color("#99f6e4"))
	# Sağ kenardaki güç ve veri konnektörleri (anakarttaki hedeflerle hizalı)
	for conn: Rect2 in [Rect2(o + Vector2(w - 10, 5), Vector2(8, 44)), Rect2(o + Vector2(w - 10, 57), Vector2(8, 30))]:
		_box(ci, conn, Color("#111827"), 2)
		var py: float = conn.position.y + 3.0
		while py < conn.end.y - 2.0:
			ci.draw_line(Vector2(conn.position.x + 2, py), Vector2(conn.end.x - 2, py), GOLD, 1.0)
			py += 3.0
	# Vida delikleri
	for p: Vector2 in [Vector2(7, 7), Vector2(w - 18, 7), Vector2(7, r.size.y - 7), Vector2(w - 18, r.size.y - 7)]:
		ci.draw_circle(o + p, 2.5, Color("#94a3b8"))

static func _draw_gpu(ci: CanvasItem, r: Rect2, angle: float) -> void:
	_shadowed_box(ci, r, Color("#1f2937"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#374151"), Color("#111827"))
	_box(ci, r, Color.TRANSPARENT, 6, 1, Color("#4b5563"))
	ci.draw_rect(Rect2(r.position + Vector2(6, 2), Vector2(r.size.x - 12, 2)), Color("#a855f7"))
	var cy: float = r.get_center().y
	_text(ci, Vector2(r.position.x + 62, cy), "RTX 4070", 12, Color("#e9d5ff"))
	var rad: float = r.size.y / 2.0 - 4.0
	for i: int in range(3):
		var c: Vector2 = Vector2(r.position.x + 180 + i * 110, cy + 1)
		ci.draw_circle(c, rad, Color("#0b1220"))
		_blades(ci, c, rad * 0.3, rad * 0.92, 7, angle + i * 0.4, Color(0.66, 0.33, 0.97, 0.85))
		ci.draw_circle(c, rad * 0.3, Color("#1f2937"))
		ci.draw_arc(c, rad, 0.0, TAU, 36, Color("#6b21a8"), 1.5, true)

static func _draw_psu(ci: CanvasItem, r: Rect2, angle: float) -> void:
	_shadowed_box(ci, r, Color("#374151"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#4b5563"), Color("#111827"))
	_box(ci, r, Color.TRANSPARENT, 6, 2, Color("#6b7280"))
	var o: Vector2 = r.position
	# Fan ızgarası
	var c: Vector2 = o + Vector2(58, 55)
	var rad: float = 42.0
	ci.draw_circle(c, rad, Color("#0b1220"))
	_blades(ci, c, rad * 0.25, rad * 0.9, 7, angle, Color(0.42, 0.46, 0.53, 0.55))
	for k: float in [0.35, 0.6, 0.85, 1.0]:
		ci.draw_arc(c, rad * k, 0.0, TAU, 40, Color("#6b7280"), 1.5, true)
	for i: int in range(4):
		var dir: Vector2 = Vector2.from_angle(PI / 4.0 * i)
		ci.draw_line(c - dir * rad, c + dir * rad, Color("#6b7280"), 1.5, true)
	ci.draw_circle(c, rad * 0.18, Color("#1f2937"))
	# Etiketler
	_text(ci, o + Vector2(150, 44), "750W", 20, Color.WHITE)
	var badge: Rect2 = Rect2(o + Vector2(118, 60), Vector2(64, 16))
	_box(ci, badge, Color("#fbbf24"), 3)
	_text(ci, badge.get_center(), "80+ GOLD", 9, Color("#111827"))
	# Açma/kapama düğmesi
	_box(ci, Rect2(o + Vector2(168, 86), Vector2(18, 12)), Color("#111827"), 2)
	ci.draw_rect(Rect2(o + Vector2(171, 88), Vector2(6, 8)), Color("#ef4444"))
	# Kablo portları
	for key: String in PSU_PORTS:
		var port: Dictionary = PSU_PORTS[key]
		var pos: Vector2 = port["pos"]
		var size: Vector2 = port["size"]
		var d: Vector2 = port["dir"]
		var rect: Rect2 = Rect2(o + pos - Vector2(size.x / 2.0, 0), size) if d.y != 0.0 else Rect2(o + pos - Vector2(0, size.y / 2.0), size)
		_box(ci, rect, Color("#0b0f17"), 2, 1, Color("#9ca3af"))

# Kablo fişi (konnektör gövdesi, pinler, renkli bant)
static func _draw_plug(ci: CanvasItem, d: ComponentData, r: Rect2, placed: bool) -> void:
	var accent: Color = d.cable_color
	if not placed:
		# Envanterde fişten çıkan kısa kablo ucu
		var start: Vector2 = entry_point(r, d.cable_entry)
		ci.draw_line(start, start + d.cable_entry * 12.0, accent.darkened(0.5), d.cable_width + 2.0, true)
		ci.draw_line(start, start + d.cable_entry * 12.0, accent, d.cable_width, true)
	_shadowed_box(ci, r, Color("#111827"), 3, 1, accent.darkened(0.2))
	# Kablo tarafındaki renkli bant
	var band: Rect2
	if d.cable_entry.x > 0.0:
		band = Rect2(Vector2(r.end.x - 4, r.position.y + 1), Vector2(3, r.size.y - 2))
	elif d.cable_entry.x < 0.0:
		band = Rect2(r.position + Vector2(1, 1), Vector2(3, r.size.y - 2))
	elif d.cable_entry.y > 0.0:
		band = Rect2(Vector2(r.position.x + 1, r.end.y - 4), Vector2(r.size.x - 2, 3))
	else:
		band = Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3))
	ci.draw_rect(band, accent)
	# Pin delikleri
	var inner: Rect2 = r.grow(-5)
	var pin: float = 4.0
	var gap: float = 2.5
	var cols: int = maxi(1, int((inner.size.x + gap) / (pin + gap)))
	var rows: int = maxi(1, int((inner.size.y + gap) / (pin + gap)))
	var grid: Vector2 = Vector2(cols * pin + (cols - 1) * gap, rows * pin + (rows - 1) * gap)
	var start_pos: Vector2 = inner.position + (inner.size - grid) / 2.0
	for cx: int in range(cols):
		for cy: int in range(rows):
			ci.draw_rect(Rect2(start_pos + Vector2(cx, cy) * (pin + gap), Vector2(pin, pin)), Color("#374151"))
	# İsim (yalnızca envanterde)
	if not placed:
		var font: Font = UIStyle.ui_font(true)
		var fs: int = 7
		var tw: float = font.get_string_size(d.part_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var vertical: bool = r.size.y > r.size.x * 1.4
		var pill_size: Vector2 = Vector2(fs + 5, tw + 6) if vertical else Vector2(tw + 6, fs + 5)
		_box(ci, Rect2(r.get_center() - pill_size / 2.0, pill_size), Color(0, 0, 0, 0.7), 3)
		if vertical:
			_vtext(ci, r.get_center(), d.part_name, fs, Color.WHITE)
		else:
			_text(ci, r.get_center(), d.part_name, fs, Color.WHITE)

# --- Yardımcılar ------------------------------------------------------------

static func _blades(ci: CanvasItem, c: Vector2, r_in: float, r_out: float, count: int, angle: float, color: Color) -> void:
	var r_mid: float = (r_in + r_out) / 2.0
	for i: int in range(count):
		var a: float = angle + TAU * float(i) / float(count)
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2.from_angle(a - 0.18) * r_in,
			c + Vector2.from_angle(a + 0.12) * r_mid,
			c + Vector2.from_angle(a + 0.42) * r_out,
			c + Vector2.from_angle(a + 0.78) * r_out,
			c + Vector2.from_angle(a + 0.55) * r_mid,
			c + Vector2.from_angle(a + 0.28) * r_in,
		]), color)

static func _box(ci: CanvasItem, r: Rect2, bg: Color, radius: float, border_w: int = 0, border_c: Color = Color.TRANSPARENT) -> void:
	UIStyle.box(bg, radius, border_w, border_c).draw(ci.get_canvas_item(), r)

static func _shadowed_box(ci: CanvasItem, r: Rect2, bg: Color, radius: float, border_w: int = 0, border_c: Color = Color.TRANSPARENT) -> void:
	UIStyle.box(bg, radius, border_w, border_c, SHADOW, 5, Vector2(0, 4)).draw(ci.get_canvas_item(), r)

static func _text(ci: CanvasItem, center: Vector2, text: String, fs: int, color: Color) -> void:
	var font: Font = UIStyle.ui_font(true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, center + Vector2(-w / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

# 90° döndürülmüş yazı (yukarıdan aşağı okunur)
static func _vtext(ci: CanvasItem, center: Vector2, text: String, fs: int, color: Color) -> void:
	var font: Font = UIStyle.ui_font(true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(center, PI / 2.0)
	ci.draw_string(font, Vector2(-w / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	ci.draw_set_transform(Vector2.ZERO)
