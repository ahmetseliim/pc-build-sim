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
const HALO: Color = Color(0.88, 0.93, 1.0, 0.62) ## Koyu zeminde siluet için açık kenar konturu
const NEON: Array[Color] = [Color("#22d3ee"), Color("#6366f1"), Color("#c026d3"), Color("#f472b6")] ## Kademe 3 RGB şerit renkleri
## Marka renkleri (marka şeridi ve etiket bandı)
const BRAND_COLORS: Dictionary = {
	"Kartal": Color("#ef4444"), "Pusula": Color("#3b82f6"), "Zirve": Color("#a855f7"),
	"Volta": Color("#f59e0b"), "Nimbus": Color("#22d3ee"), "Demirci": Color("#f97316"),
}

# Kule fan görselleri (üretilmiş): gövde sabit, pervane ayrı katman. Merkezler 460 px'lik özgün görselde ölçüldü.
const FAN_BODY: Texture2D = preload("res://assets/sprites/components/fan_govde.png")
const FAN_BLADES: Texture2D = preload("res://assets/sprites/components/fan_pervane.png")
const FAN_SRC: float = 460.0 ## Özgün görsel kenarı (ölçüm birimi)
const FAN_BODY_CENTER: Vector2 = Vector2(229.5, 230.0) ## Gövdedeki ızgara/göbek merkezi (özgün px)
const FAN_BLADE_HUB: Vector2 = Vector2(127.83, 128.56) ## Pervane göbeğinin merkezi (256 px'lik dosyada px)
const FAN_BLADE_SCALE: float = 0.84 ## Pervane, gövde ızgarasının içinde kalsın diye küçültülür

static func draw(ci: CanvasItem, d: ComponentData, r: Rect2, placed: bool, angle: float) -> void:
	if d.is_cable:
		_draw_plug(ci, d, r, placed)
		return
	match d.part_type:
		"cpu":
			_draw_cpu(ci, d, r)
		"paste":
			_draw_paste(ci, d, r)
		"cloth":
			_draw_cloth(ci, r)
		"fan":
			_draw_fan(ci, d, r, angle)
		"ram":
			_draw_ram(ci, d, r)
		"m2":
			_draw_m2(ci, d, r)
		"sata":
			_draw_sata(ci, d, r)
		"gpu":
			_draw_gpu(ci, d, r, angle)
		"psu":
			_draw_psu(ci, d, r, angle)
		_:
			_shadowed_box(ci, r, d.bg_color, d.corner_radius)
			_text(ci, r.get_center(), d.part_name, d.font_size, d.text_color)
	# Yedek parça etiketi (RAM kendi çiziminde gösterir)
	if d.is_new and d.part_type != "ram":
		var badge: Rect2 = Rect2(r.position + Vector2(r.size.x / 2.0 - 15.0, r.size.y - 12.0), Vector2(30, 10))
		_box(ci, badge, Color("#16a34a"), 2)
		_text(ci, badge.get_center(), "YENİ", 7, Color.WHITE)

# Kapasite yazısı: 1000 GB ve üstü TB (1000 -> "1 TB", 500 -> "500 GB")
static func capacity_text(gb: int) -> String:
	return "%d TB" % (gb / 1000) if gb >= 1000 and gb % 1000 == 0 else "%d GB" % gb

# Katalog parçasının kısa etiketi: "Kartal 8 GB DDR4", "Pusula 480 GB", "Volta 650 W", "Zirve Nova 8"
static func part_label(d: ComponentData) -> String:
	if d.brand == "":
		return d.part_name
	match d.part_type:
		"ram":
			return "%s %s %s" % [d.brand, capacity_text(d.capacity_gb), d.ram_type]
		"m2", "sata":
			return "%s %s" % [d.brand, capacity_text(d.capacity_gb)]
		"psu":
			return "%s %d W" % [d.brand, d.watt]
	return "%s %s" % [d.brand, d.model]

# Kablonun fişten çıktığı kenarın orta noktası
static func entry_point(r: Rect2, dir: Vector2) -> Vector2:
	return r.get_center() + Vector2(dir.x * r.size.x / 2.0, dir.y * r.size.y / 2.0)

# --- Ortak çizim araçları (yumuşak 2D stil) ---------------------------------

# Katalog dışı (kademe 0) genel parçalar "dengeli" görünür
static func _tier(d: ComponentData) -> int:
	return d.tier if d.tier > 0 else 2

static func _brand_color(brand: String) -> Color:
	return BRAND_COLORS.get(brand, Color("#2dd4bf"))

# Koyu zeminde siluet kaybolmasın: parçanın kenarında açık, ince bir kontur
static func _outline(ci: CanvasItem, r: Rect2, radius: float) -> void:
	_box(ci, r, Color.TRANSPARENT, radius, 1, HALO)

# Üstten ışık: üst yüzeyde açık yumuşak vurgu, altta hafif iç gölge, köşede parlama çizgisi
static func _sheen(ci: CanvasItem, r: Rect2, radius: float, strength: float = 1.0, low_shade: bool = true) -> void:
	var w: float = r.size.x - 4.0
	var top1: Rect2 = Rect2(r.position + Vector2(2, 2), Vector2(w, maxf(r.size.y * 0.42, 4.0)))
	var top2: Rect2 = Rect2(r.position + Vector2(2, 2), Vector2(w, maxf(r.size.y * 0.20, 3.0)))
	ci.draw_colored_polygon(UIStyle.rounded_points(top1, maxf(radius - 1.0, 1.0)), Color(1, 1, 1, 0.07 * strength))
	ci.draw_colored_polygon(UIStyle.rounded_points(top2, maxf(radius - 1.0, 1.0)), Color(1, 1, 1, 0.09 * strength))
	var low: Rect2 = Rect2(r.position + Vector2(2, r.size.y * 0.72), Vector2(w, r.size.y * 0.28 - 2.0))
	if low_shade:
		ci.draw_colored_polygon(UIStyle.rounded_points(low, maxf(radius - 1.0, 1.0)), Color(0, 0, 0, 0.13 * strength))
	var gx: float = r.position.x + minf(radius, r.size.x * 0.3) + 1.0
	ci.draw_line(Vector2(gx, r.position.y + 1.5), Vector2(gx + minf(r.size.x * 0.3, 40.0), r.position.y + 1.5), Color(1, 1, 1, 0.55 * strength), 1.0, true)

# Birden çok renk duraklı düz şerit (yatay: soldan sağa, dikey: yukarıdan aşağı)
static func _grad_bar(ci: CanvasItem, rect: Rect2, cols: Array[Color], horizontal: bool = true) -> void:
	var n: int = cols.size() - 1
	for i: int in range(n):
		var a: float = float(i) / float(n)
		var b: float = float(i + 1) / float(n)
		var p0: Vector2
		var p1: Vector2
		var q0: Vector2
		var q1: Vector2
		if horizontal:
			var x0: float = rect.position.x + rect.size.x * a
			var x1: float = rect.position.x + rect.size.x * b
			p0 = Vector2(x0, rect.position.y)
			p1 = Vector2(x1, rect.position.y)
			q1 = Vector2(x1, rect.end.y)
			q0 = Vector2(x0, rect.end.y)
		else:
			var y0: float = rect.position.y + rect.size.y * a
			var y1: float = rect.position.y + rect.size.y * b
			p0 = Vector2(rect.position.x, y0)
			p1 = Vector2(rect.end.x, y0)
			q1 = Vector2(rect.end.x, y1)
			q0 = Vector2(rect.position.x, y1)
		ci.draw_polygon(PackedVector2Array([p0, p1, q1, q0]), PackedColorArray([cols[i], cols[i] if not horizontal else cols[i + 1], cols[i + 1], cols[i + 1] if not horizontal else cols[i]]))

# Kademe şeridi: 1 sade mat, 2 metalik, 3 parlak neon (RGB çizgisi)
static func _tier_strip(ci: CanvasItem, rect: Rect2, tier: int, horizontal: bool = true) -> void:
	match tier:
		1:
			ci.draw_rect(rect, Color("#8a94a6"))
			ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0) if horizontal else Vector2(1.0, rect.size.y)), Color(1, 1, 1, 0.25))
		2:
			var cols: Array[Color] = [Color("#f8fafc"), Color("#94a3b8"), Color("#e2e8f0"), Color("#64748b")]
			_grad_bar(ci, rect, cols, not horizontal)
			ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0) if horizontal else Vector2(1.0, rect.size.y)), Color(1, 1, 1, 0.8))
		_:
			UIStyle.draw_rect_glow(ci, rect, 5.0, Color(0.55, 0.45, 1.0, 0.75), 6)
			_grad_bar(ci, rect, NEON, horizontal)
			var mid: Vector2 = rect.get_center()
			if horizontal:
				ci.draw_line(Vector2(rect.position.x + 1, mid.y), Vector2(rect.end.x - 1, mid.y), Color(1, 1, 1, 0.55), 1.0)
			else:
				ci.draw_line(Vector2(mid.x, rect.position.y + 1), Vector2(mid.x, rect.end.y - 1), Color(1, 1, 1, 0.55), 1.0)

# Açık renkli etiket alanı (üstte marka renginde ince şerit)
static func _label_plate(ci: CanvasItem, rect: Rect2, brand: String, horizontal_band: bool = true) -> void:
	_box(ci, rect, Color("#f1f5f9"), 3, 1, Color("#94a3b8"))
	var bc: Color = _brand_color(brand)
	if horizontal_band:
		ci.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2.0, 3)), bc)
	else:
		ci.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(4, rect.size.y - 2.0)), bc)

# --- Parçalar ---------------------------------------------------------------

static func _draw_cpu(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#94a3b8"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#dbe4ee"), Color("#64748b"))
	_box(ci, r, Color.TRANSPARENT, 6, 2, Color("#475569"))
	# Alt tabaka: kenarlarda koyu çerçeve ve altın pin sırası ipucu
	var sub: Rect2 = r.grow(-6)
	_box(ci, sub, Color.TRANSPARENT, 4, 1, Color(0, 0, 0, 0.25))
	# Isı dağıtıcı kapak (IHS)
	var ihs: Rect2 = r.grow(-15)
	var ihs_a: Color = Color("#f8fafc") if t >= 2 else Color("#e5eaf0")
	UIStyle.draw_diagonal_gradient(ci, ihs, 8, ihs_a, Color("#94a3b8") if t >= 2 else Color("#a6b0bf"))
	_box(ci, ihs, Color.TRANSPARENT, 8, 1, Color(1, 1, 1, 0.7))
	_sheen(ci, ihs, 8, 0.8, false)
	if t == 2:
		# Fırçalanmış metal: ince yatay çizgiler
		var ly: float = ihs.position.y + 9.0
		while ly < ihs.end.y - 6.0:
			ci.draw_line(Vector2(ihs.position.x + 8, ly), Vector2(ihs.end.x - 8, ly), Color(1, 1, 1, 0.22), 1.0)
			ly += 4.0
	elif t >= 3:
		# Neon çerçeve: IHS çevresinde RGB halka
		var pts: PackedVector2Array = UIStyle.rounded_points(ihs.grow(1.5), 9.0)
		var cols: PackedColorArray = PackedColorArray()
		for i: int in range(pts.size()):
			var k: float = float(i) / float(pts.size())
			cols.append(NEON[0].lerp(NEON[2], 0.5 + 0.5 * sin(k * TAU * 2.0)))
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		cols.append(cols[0])
		ci.draw_polyline_colors(closed, cols, 2.0, true)
	# Marka şeridi
	var bc: Color = _brand_color(d.brand) if d.brand != "" else Color("#38bdf8")
	ci.draw_rect(Rect2(ihs.position + Vector2(12, 8), Vector2(ihs.size.x - 24.0, 3)), bc)
	# Yön işareti (altın üçgen)
	var p: Vector2 = r.position
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(5, r.size.y - 5), p + Vector2(17, r.size.y - 5), p + Vector2(5, r.size.y - 17)]), Color("#fbbf24"))
	_outline(ci, r, 6)
	if d is CPUData and d.brand != "":
		var cpu: CPUData = d as CPUData
		_fit_text(ci, ihs.get_center() + Vector2(0, -3), cpu.brand.to_upper(), 13, Color("#1e293b"), ihs.size.x - 8.0)
		_fit_text(ci, ihs.get_center() + Vector2(0, 13), "%s · %.1f GHz" % [cpu.model, cpu.clock_speed], 8, Color("#334155"), ihs.size.x - 8.0)
	else:
		_text(ci, ihs.get_center() + Vector2(0, -3), "Z-CORE", 13, Color("#1e293b"))
		_text(ci, ihs.get_center() + Vector2(0, 13), "i7 · 5.4 GHz", 8, Color("#334155"))

static func _draw_paste(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#334155"), 6, 1, Color("#64748b"))
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#4b5b73"), Color("#1e293b"))
	_sheen(ci, r, 6)
	var o: Vector2 = r.position
	var y: float = 14.0
	# Şırınga: uç, gövde, macun, piston
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(5, y), o + Vector2(12, y - 4), o + Vector2(12, y + 4)]), Color("#cbd5e1"))
	_box(ci, Rect2(o + Vector2(12, y - 6), Vector2(30, 12)), Color("#f1f5f9"), 3, 1, Color("#94a3b8"))
	# Macun rengi kademeyle değişir: standart gri, gümüşlü açık, üst kademe mavi-gümüş
	var paste_c: Color = [Color("#94a3b8"), Color("#cbd5e1"), Color("#7dd3fc")][clampi(t, 1, 3) - 1]
	_box(ci, Rect2(o + Vector2(14, y - 4), Vector2(18, 8)), paste_c, 2)
	ci.draw_rect(Rect2(o + Vector2(42, y - 1.5), Vector2(8, 3)), Color("#cbd5e1"))
	_box(ci, Rect2(o + Vector2(50, y - 6), Vector2(4, 12)), Color("#e2e8f0"), 1)
	# Marka şeridi
	if d.brand != "":
		ci.draw_rect(Rect2(o + Vector2(3, r.size.y - 18), Vector2(r.size.x - 6.0, 2)), _brand_color(d.brand))
	_tier_strip(ci, Rect2(o + Vector2(5, 24), Vector2(r.size.x - 10.0, 2)), t)
	_outline(ci, r, 6)
	if d.brand != "":
		_fit_text(ci, Vector2(r.get_center().x, r.end.y - 8), "%s %s" % [d.brand, d.model], 8, Color.WHITE, r.size.x - 6.0)
	else:
		_text(ci, Vector2(r.get_center().x, r.end.y - 8), "Macun", 8, Color.WHITE)

static func _draw_cloth(ci: CanvasItem, r: Rect2) -> void:
	_shadowed_box(ci, r, Color("#334155"), 6, 1, Color("#64748b"))
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#4b5b73"), Color("#1e293b"))
	_sheen(ci, r, 6)
	var o: Vector2 = r.position
	# Katlanmış bez
	var cloth: Rect2 = Rect2(o + Vector2(6, 6), Vector2(28, 18))
	_box(ci, cloth, Color("#e0f2fe"), 3, 1, Color("#7dd3fc"))
	ci.draw_line(o + Vector2(8, 12), o + Vector2(32, 12), Color("#7dd3fc"), 1.0, true)
	ci.draw_line(o + Vector2(8, 18), o + Vector2(32, 18), Color("#7dd3fc"), 1.0, true)
	# Alkol şişesi
	_box(ci, Rect2(o + Vector2(40, 9), Vector2(12, 16)), Color("#38bdf8"), 2, 1, Color("#e0f2fe"))
	ci.draw_rect(Rect2(o + Vector2(43, 5), Vector2(6, 4)), Color("#f8fafc"))
	ci.draw_rect(Rect2(o + Vector2(42, 14), Vector2(8, 5)), Color("#f8fafc"))
	_outline(ci, r, 6)
	_text(ci, Vector2(r.get_center().x, r.end.y - 8), "Alkollü Bez", 8, Color.WHITE)

# Kule fan: üretilmiş gövde (sabit) + ayrı pervane katmanı (icon_angle ile döner).
# Pervane merkezi (göbek) ve gövdenin ızgara merkezi 460 px'lik görselde ölçüldü; döndürme tam göbek etrafında yapılır.
static func _draw_fan(ci: CanvasItem, d: ComponentData, r: Rect2, angle: float) -> void:
	var t: int = _tier(d)
	# Kademe 1 "kutu fan": mat, gri tonlu; kademe 2 görselin kendisi; kademe 3 ışıklı (halka FanGlow katmanında)
	var body_mod: Color = Color(0.70, 0.72, 0.75) if t == 1 else Color.WHITE
	var blade_mod: Color = Color(0.58, 0.62, 0.66) if t == 1 else Color.WHITE
	_shadowed_box(ci, r, Color("#15181d"), 7)
	ci.draw_texture_rect(FAN_BODY, r, false, body_mod)
	var c: Vector2 = r.position + Vector2(r.size.x * FAN_BODY_CENTER.x, r.size.y * FAN_BODY_CENTER.y) / FAN_SRC
	var k: float = FAN_BLADE_SCALE * r.size.x / float(FAN_BODY.get_width())
	# Pervanenin gövdeye düşen yumuşak gölgesi, sonra pervane
	ci.draw_set_transform(c + Vector2(1.5, 2.0), angle, Vector2(k, k))
	ci.draw_texture(FAN_BLADES, -FAN_BLADE_HUB, Color(0, 0, 0, 0.35))
	ci.draw_set_transform(c, angle, Vector2(k, k))
	ci.draw_texture(FAN_BLADES, -FAN_BLADE_HUB, blade_mod)
	ci.draw_set_transform(Vector2.ZERO)
	_outline(ci, r, 7)
	# Marka, sol alt köşede koyu bir etiket üzerinde (pervane dairesinin dışında; ortadaki YENİ rozetiyle çakışmaz)
	if d.brand != "":
		var pill: Rect2 = Rect2(r.position + Vector2(3, r.size.y - 14), Vector2(40, 11))
		_box(ci, pill, Color(0.04, 0.06, 0.1, 0.82), 3)
		ci.draw_rect(Rect2(pill.position + Vector2(1.5, 2), Vector2(2, 7)), _brand_color(d.brand))
		_fit_text(ci, pill.get_center() + Vector2(2, 0), d.brand, 8, Color.WHITE, 32.0)

# Fan parçasına bağlı ek katmanlar (PartItem.setup çağırır): doku süzgeci ve kademe 3 ışıma katmanı
static func attach_overlays(item: Control, d: ComponentData) -> void:
	if d == null or d.is_cable or d.part_type != "fan":
		return
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _tier(d) < 3 or item.get_node_or_null("FanGlow") != null:
		return
	var glow: Control = Control.new()
	glow.name = "FanGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.draw.connect(_draw_fan_glow.bind(glow))
	item.add_child(glow)

# Kademe 3: pervane çevresinde eklemeli (additive) cyan-mor halka ve hafif ışıma
static func _draw_fan_glow(g: Control) -> void:
	var s: Vector2 = g.size
	if s.x < 8.0:
		return
	var c: Vector2 = Vector2(s.x * FAN_BODY_CENTER.x, s.y * FAN_BODY_CENTER.y) / FAN_SRC
	var ring: float = s.x * 0.435
	g.draw_circle(c, ring, Color(0.35, 0.3, 0.9, 0.10))
	g.draw_circle(c, ring * 0.45, Color(0.2, 0.7, 0.9, 0.08))
	# Tek çoklu çizgi olarak çizilir (parçalar arası binme olmaz; eklemeli karışımda boncuklanmasın)
	var n: int = 96
	var pts: PackedVector2Array = PackedVector2Array()
	var hues: Array[Color] = []
	for i: int in range(n + 1):
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2.from_angle(a) * ring)
		hues.append(NEON[0].lerp(NEON[2], 0.5 + 0.5 * sin(a * 2.0)))
	var widths: Array[float] = [8.0, 5.0, 3.0, 1.4]
	var alphas: Array[float] = [0.10, 0.16, 0.35, 0.85]
	for j: int in range(widths.size()):
		var cols: PackedColorArray = PackedColorArray()
		for hc: Color in hues:
			cols.append(Color(hc, alphas[j]))
		g.draw_polyline_colors(pts, cols, widths[j], true)

static func _draw_ram(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	var t: int = _tier(d)
	var o: Vector2 = r.position
	var w: float = r.size.x
	var h: float = r.size.y
	# Gövde: kademe 1 çıplak yeşil kart, 2 siyah soğutucu, 3 koyu soğutucu + neon
	var body: Color = [Color("#1f8a4c"), Color("#2b3547"), Color("#171d2e")][t - 1]
	_shadowed_box(ci, r, body, 4)
	UIStyle.draw_diagonal_gradient(ci, r, 4, body.lightened(0.14), body.darkened(0.25))
	# Üst şerit (kademeye göre)
	_tier_strip(ci, Rect2(o + Vector2(3, 3), Vector2(w - 6, 7 if t > 1 else 4)), t)
	if t == 1:
		# Çıplak kart: dört bellek çipi
		for cx: int in range(2):
			for cy: int in range(2):
				var chip: Rect2 = Rect2(o + Vector2(6 + cx * 16, 14 + cy * 16), Vector2(14, 13))
				_box(ci, chip, Color("#0f172a"), 2, 1, Color(1, 1, 1, 0.18))
	else:
		# Soğutucu üzerindeki çapraz şerit: kademe 2 mavi, kademe 3 cyan-mor
		var band: PackedVector2Array = PackedVector2Array([o + Vector2(3, 30), o + Vector2(w - 3, 18), o + Vector2(w - 3, 32), o + Vector2(3, 44)])
		if t == 2:
			ci.draw_colored_polygon(band, Color("#38bdf8"))
			ci.draw_line(o + Vector2(3, 30), o + Vector2(w - 3, 18), Color(1, 1, 1, 0.6), 1.0, true)
		else:
			ci.draw_polygon(band, PackedColorArray([NEON[0], NEON[2], NEON[2], NEON[0]]))
			ci.draw_line(o + Vector2(3, 30), o + Vector2(w - 3, 18), Color(1, 1, 1, 0.7), 1.0, true)
	# Altın kontaklar ve çentik
	var contacts: Rect2 = Rect2(o + Vector2(4, h - 12), Vector2(w - 8, 9))
	ci.draw_rect(contacts, GOLD)
	var x: float = contacts.position.x + 2.0
	while x < contacts.end.x:
		ci.draw_line(Vector2(x, contacts.position.y), Vector2(x, contacts.end.y), Color(0, 0, 0, 0.3), 1.0)
		x += 3.0
	ci.draw_rect(Rect2(o + Vector2(w * 0.4, h - 12), Vector2(3, 9)), Color("#1e293b"))
	_sheen(ci, r, 4)
	_outline(ci, r, 4)
	# Açık etiket alanı: koyu yazı, güçlü kontrast
	var plate: Rect2 = Rect2(o + Vector2(5, 46), Vector2(w - 10, 55))
	_label_plate(ci, plate, d.brand)
	if d.brand != "":
		# Katalog parçası: iki satır (marka, kapasite + tür); 42 px genişliğe sığması için dikey yazılır
		var avail: float = plate.size.y - 6.0
		var mid: Vector2 = plate.get_center() + Vector2(0, 2)
		_vfit(ci, mid + Vector2(5.5, 0), d.brand, 9, Color("#0f172a"), avail)
		_vfit(ci, mid + Vector2(-6.5, 0), "%s %s" % [capacity_text(d.capacity_gb), d.ram_type], 8, Color("#334155"), avail)
	else:
		var board: BoardData = GameManager.current_board
		var ram_label: String = "%s · %dGB" % [board.ram_type, board.ram_size_gb] if board else "DDR5 · 16GB"
		_vtext(ci, plate.get_center() + Vector2(0, 2), ram_label, 8, Color("#0f172a"))
	if d.is_new:
		var badge: Rect2 = Rect2(o + Vector2(4, h - 27), Vector2(w - 8, 12))
		_box(ci, badge, Color("#16a34a"), 2, 1, Color("#bbf7d0"))
		_text(ci, badge.get_center(), "YENİ", 7, Color.WHITE)

static func _draw_m2(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#166534"), 3)
	UIStyle.draw_diagonal_gradient(ci, r, 3, Color("#22964f"), Color("#0f4d28"))
	var o: Vector2 = r.position
	var h: float = r.size.y
	# Altın bağlantı ucu
	ci.draw_rect(Rect2(o + Vector2(0, 4), Vector2(8, h - 8)), GOLD)
	var y: float = o.y + 6.0
	while y < o.y + h - 5.0:
		ci.draw_line(Vector2(o.x, y), Vector2(o.x + 8, y), Color(0, 0, 0, 0.3), 1.0)
		y += 3.0
	# Vida yuvası
	ci.draw_circle(Vector2(r.end.x - 1.0, r.get_center().y), 6.0, Color(0, 0, 0, 0.5))
	# Denetleyici çip
	_box(ci, Rect2(o + Vector2(16, 9), Vector2(20, 20)), Color("#0f172a"), 2, 1, Color(1, 1, 1, 0.2))
	var nand1: Rect2 = Rect2(o + Vector2(44, 7), Vector2(38, 24))
	var nand2: Rect2 = Rect2(o + Vector2(88, 7), Vector2(38, 24))
	var txt: Color = Color("#e2e8f0")
	if t == 1:
		# Çıplak kart: iki NAND çipi, ince marka şeridi
		_box(ci, nand1, Color("#0f172a"), 2, 1, Color(1, 1, 1, 0.2))
		_box(ci, nand2, Color("#0f172a"), 2, 1, Color(1, 1, 1, 0.2))
		if d.brand != "":
			ci.draw_rect(Rect2(o + Vector2(44, 32), Vector2(82, 2)), _brand_color(d.brand))
	else:
		# Soğutucu plaka: kademe 2 metalik (koyu yazı), kademe 3 koyu + neon (açık yazı)
		var plate: Rect2 = Rect2(o + Vector2(41, 4), Vector2(88, h - 8.0))
		if t == 2:
			UIStyle.draw_diagonal_gradient(ci, plate, 3, Color("#f1f5f9"), Color("#94a3b8"))
			_box(ci, plate, Color.TRANSPARENT, 3, 1, Color("#475569"))
			txt = Color("#0f172a")
		else:
			UIStyle.draw_diagonal_gradient(ci, plate, 3, Color("#2a3550"), Color("#0b1220"))
			_box(ci, plate, Color.TRANSPARENT, 3, 1, Color("#818cf8"))
			_tier_strip(ci, Rect2(plate.position + Vector2(3, 2), Vector2(plate.size.x - 6.0, 2)), 3)
		if d.brand != "":
			ci.draw_rect(Rect2(plate.position + Vector2(3, plate.size.y - 5.0), Vector2(plate.size.x - 6.0, 2)), _brand_color(d.brand))
		ci.draw_line(Vector2(o.x + 85, o.y + 9), Vector2(o.x + 85, o.y + 29), Color(txt, 0.35), 1.0)
	_sheen(ci, r, 3, 0.7)
	_outline(ci, r, 3)
	if d.brand != "":
		_fit_text(ci, nand1.get_center(), d.brand, 8, txt if t > 1 else Color("#cbd5e1"), nand1.size.x - 4.0)
		_fit_text(ci, nand2.get_center(), capacity_text(d.capacity_gb), 8, txt if t > 1 else Color("#cbd5e1"), nand2.size.x - 4.0)
	else:
		_text(ci, nand1.get_center(), "NVMe", 8, txt if t > 1 else Color("#cbd5e1"))
		_text(ci, nand2.get_center(), "1TB", 8, txt if t > 1 else Color("#cbd5e1"))

static func _draw_sata(ci: CanvasItem, d: ComponentData, r: Rect2) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#475569"), 6)
	# Kasa: kademe 1 mat koyu gri, 2 fırçalı alüminyum, 3 koyu + neon
	var ca: Color = [Color("#5b6678"), Color("#e2e8f0"), Color("#27324d")][t - 1]
	var cb: Color = [Color("#252d3b"), Color("#7b889c"), Color("#0b1220")][t - 1]
	UIStyle.draw_diagonal_gradient(ci, r, 6, ca, cb)
	var o: Vector2 = r.position
	var w: float = r.size.x
	if t == 2:
		var ly: float = o.y + 5.0
		while ly < r.end.y - 3.0:
			ci.draw_line(Vector2(o.x + 3, ly), Vector2(r.end.x - 3, ly), Color(1, 1, 1, 0.14), 1.0)
			ly += 4.0
	_sheen(ci, r, 6)
	_box(ci, r, Color.TRANSPARENT, 6, 1, Color("#64748b"))
	_outline(ci, r, 6)
	# Üstte marka şeridi, altta kademe şeridi
	if d.brand != "":
		ci.draw_rect(Rect2(o + Vector2(12, 6), Vector2(w - 42.0, 4)), _brand_color(d.brand))
	_tier_strip(ci, Rect2(o + Vector2(12, r.size.y - 11.0), Vector2(w - 42.0, 4)), t)
	# Açık etiket
	var sticker: Rect2 = Rect2(o + Vector2(12, 14), Vector2(w - 42, r.size.y - 28))
	_box(ci, sticker, Color("#f8fafc"), 4, 1, Color("#94a3b8"))
	ci.draw_rect(Rect2(sticker.position + Vector2(1, 1), Vector2(5, sticker.size.y - 2.0)), _brand_color(d.brand) if d.brand != "" else Color("#14b8a6"))
	var sc: Vector2 = sticker.get_center() + Vector2(3, 0)
	_text(ci, sc + Vector2(0, -8), "SATA SSD", 12, Color("#0f172a"))
	if d.brand != "":
		_fit_text(ci, sc + Vector2(0, 10), part_label(d), 9, Color("#0f766e"), sticker.size.x - 16.0)
	else:
		_text(ci, sc + Vector2(0, 10), "1TB · 550 MB/s", 8, Color("#0f766e"))
	# Sağ kenardaki güç ve veri konnektörleri (anakarttaki hedeflerle hizalı)
	for conn: Rect2 in [Rect2(o + Vector2(w - 10, 5), Vector2(8, 44)), Rect2(o + Vector2(w - 10, 57), Vector2(8, 30))]:
		_box(ci, conn, Color("#111827"), 2, 1, Color(1, 1, 1, 0.25))
		var py: float = conn.position.y + 3.0
		while py < conn.end.y - 2.0:
			ci.draw_line(Vector2(conn.position.x + 2, py), Vector2(conn.end.x - 2, py), GOLD, 1.0)
			py += 3.0
	# Vida delikleri
	var screw: Color = Color("#475569") if t == 2 else Color("#94a3b8")
	for p: Vector2 in [Vector2(7, 7), Vector2(w - 18, 7), Vector2(7, r.size.y - 7), Vector2(w - 18, r.size.y - 7)]:
		ci.draw_circle(o + p, 2.5, screw)
		ci.draw_circle(o + p + Vector2(0.5, 0.5), 1.0, Color(0, 0, 0, 0.5))

static func _draw_gpu(ci: CanvasItem, d: ComponentData, r: Rect2, angle: float) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#1f2937"), 6)
	var ca: Color = [Color("#454e5e"), Color("#3a4358"), Color("#2a2f4a")][t - 1]
	UIStyle.draw_diagonal_gradient(ci, r, 6, ca, Color("#0f141d"))
	_sheen(ci, r, 6)
	_box(ci, r, Color.TRANSPARENT, 6, 1, Color("#4b5563"))
	# Kademe şeritleri: 1 mat gri, 2 metalik, 3 üst ve alt neon
	_tier_strip(ci, Rect2(r.position + Vector2(10, 3), Vector2(r.size.x - 20.0, 3)), t)
	if t >= 3:
		_tier_strip(ci, Rect2(r.position + Vector2(10, r.size.y - 6.0), Vector2(r.size.x - 20.0, 3)), 3)
	elif t == 2:
		_tier_strip(ci, Rect2(r.position + Vector2(10, r.size.y - 6.0), Vector2(r.size.x - 20.0, 3)), 2)
	var cy: float = r.get_center().y
	# Marka etiketi: koyu plaka, açık yazı, solda marka rengi
	var plate: Rect2 = Rect2(r.position + Vector2(9, 10), Vector2(108, r.size.y - 20.0))
	_box(ci, plate, Color(0.03, 0.05, 0.09, 0.62), 4, 1, Color(1, 1, 1, 0.22))
	ci.draw_rect(Rect2(plate.position + Vector2(1, 1), Vector2(3, plate.size.y - 2.0)), _brand_color(d.brand) if d.brand != "" else Color("#a855f7"))
	if d is GPUData and d.brand != "":
		var gpu: GPUData = d as GPUData
		_fit_text(ci, Vector2(r.position.x + 64, cy - 6), "%s %s" % [gpu.brand, gpu.model], 11, Color("#f5f3ff"), 98.0)
		_fit_text(ci, Vector2(r.position.x + 64, cy + 9), "%d GB" % gpu.vram_gb, 9, Color("#ddd6fe"), 98.0)
	else:
		_text(ci, Vector2(r.position.x + 64, cy), "RTX 4070", 12, Color("#f5f3ff"))
	var rad: float = r.size.y / 2.0 - 4.0
	var blade_c: Color = [Color(0.6, 0.64, 0.72, 0.9), Color(0.5, 0.62, 0.95, 0.9), Color(0.66, 0.33, 0.97, 0.9)][t - 1]
	var ring_c: Color = [Color("#6b7280"), Color("#94a3b8"), Color("#c084fc")][t - 1]
	for i: int in range(3):
		var c: Vector2 = Vector2(r.position.x + 180 + i * 110, cy + 1)
		ci.draw_circle(c, rad + 1.5, Color("#0b1220"))
		_blades(ci, c, rad * 0.3, rad * 0.92, 7, angle + i * 0.4, blade_c)
		ci.draw_circle(c, rad * 0.3, Color("#1f2937"))
		ci.draw_circle(c, rad * 0.12, ring_c)
		ci.draw_arc(c, rad, 0.0, TAU, 36, ring_c, 1.5, true)
		ci.draw_arc(c, rad - 1.5, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.3), 1.0, true)
	# Sağ uçta havalandırma yuvaları
	for k: int in range(5):
		var vx: float = r.position.x + 440.0 + k * 7.0
		ci.draw_line(Vector2(vx + 4, r.position.y + 10), Vector2(vx, r.end.y - 10), Color(0, 0, 0, 0.55), 2.0, true)
	_outline(ci, r, 6)

static func _draw_psu(ci: CanvasItem, d: ComponentData, r: Rect2, angle: float) -> void:
	var t: int = _tier(d)
	_shadowed_box(ci, r, Color("#374151"), 6)
	UIStyle.draw_diagonal_gradient(ci, r, 6, Color("#5b6678"), Color("#141a24"))
	_sheen(ci, r, 6)
	_box(ci, r, Color.TRANSPARENT, 6, 2, Color("#6b7280"))
	_outline(ci, r, 6)
	var o: Vector2 = r.position
	# Fan ızgarası
	var c: Vector2 = o + Vector2(58, 55)
	var rad: float = 42.0
	ci.draw_circle(c, rad + 2.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, rad, Color("#0b1220"))
	_blades(ci, c, rad * 0.25, rad * 0.9, 7, angle, [Color(0.5, 0.54, 0.62, 0.7), Color(0.6, 0.66, 0.78, 0.7), Color(0.4, 0.78, 0.95, 0.75)][t - 1])
	for k: float in [0.35, 0.6, 0.85, 1.0]:
		ci.draw_arc(c, rad * k, 0.0, TAU, 40, Color("#9ca3af"), 1.5, true)
	for i: int in range(4):
		var dir: Vector2 = Vector2.from_angle(PI / 4.0 * i)
		ci.draw_line(c - dir * rad, c + dir * rad, Color("#9ca3af"), 1.5, true)
	ci.draw_circle(c, rad * 0.18, Color("#1f2937"))
	ci.draw_arc(c, rad - 1.0, PI * 1.1, PI * 1.6, 14, Color(1, 1, 1, 0.35), 1.5, true)
	if t >= 3:
		ci.draw_arc(c, rad + 1.0, 0.0, TAU, 48, NEON[0], 1.5, true)
	# Kademe şeridi (güç yazısının üstünde)
	_tier_strip(ci, Rect2(o + Vector2(118, 22), Vector2(64, 5)), t)
	# Etiketler
	var badge: Rect2 = Rect2(o + Vector2(118, 60), Vector2(64, 16))
	if d.brand != "":
		_fit_text(ci, o + Vector2(150, 44), "%dW" % d.watt, 20, Color.WHITE, 64.0)
		_box(ci, badge, Color("#fbbf24"), 3, 1, Color("#fef3c7"))
		_fit_text(ci, badge.get_center(), d.brand, 9, Color("#111827"), badge.size.x - 6.0)
	else:
		_text(ci, o + Vector2(150, 44), "750W", 20, Color.WHITE)
		_box(ci, badge, Color("#fbbf24"), 3, 1, Color("#fef3c7"))
		_text(ci, badge.get_center(), "80+ GOLD", 9, Color("#111827"))
	# Açma/kapama düğmesi
	_box(ci, Rect2(o + Vector2(168, 86), Vector2(18, 12)), Color("#111827"), 2, 1, Color(1, 1, 1, 0.3))
	ci.draw_rect(Rect2(o + Vector2(171, 88), Vector2(6, 8)), Color("#ef4444"))
	# Kablo portları
	for key: String in PSU_PORTS:
		var port: Dictionary = PSU_PORTS[key]
		var pos: Vector2 = port["pos"]
		var size: Vector2 = port["size"]
		var port_dir: Vector2 = port["dir"]
		var rect: Rect2 = Rect2(o + pos - Vector2(size.x / 2.0, 0), size) if port_dir.y != 0.0 else Rect2(o + pos - Vector2(0, size.y / 2.0), size)
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

# Yazıyı en fazla max_w piksele sığacak şekilde küçülterek (en az 6 punto) ortalar
static func _fit_text(ci: CanvasItem, center: Vector2, text: String, fs: int, color: Color, max_w: float) -> void:
	_text(ci, center, text, _fit_size(text, fs, max_w), color)

static func _vfit(ci: CanvasItem, center: Vector2, text: String, fs: int, color: Color, max_len: float) -> void:
	_vtext(ci, center, text, _fit_size(text, fs, max_len), color)

static func _fit_size(text: String, fs: int, max_w: float) -> int:
	var font: Font = UIStyle.ui_font(true)
	while fs > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs

# 90° döndürülmüş yazı (yukarıdan aşağı okunur)
static func _vtext(ci: CanvasItem, center: Vector2, text: String, fs: int, color: Color) -> void:
	var font: Font = UIStyle.ui_font(true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_set_transform(center, PI / 2.0)
	ci.draw_string(font, Vector2(-w / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	ci.draw_set_transform(Vector2.ZERO)
