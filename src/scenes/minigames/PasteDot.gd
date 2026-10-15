class_name PasteDot
extends Control

# İşlemci üzerine sürülmüş termal macunun son hali (HTML'deki .thermal-paste-dot)
# Macun tamamlandığında ortadan büyüyerek açılır.

const FINAL_RATIO: float = 0.85
const BASE_COLOR: Color = Color("#cbd5e1")
const LIGHT_RING: Color = Color(248.0 / 255.0, 250.0 / 255.0, 252.0 / 255.0, 0.4)
const DARK_RING: Color = Color(148.0 / 255.0, 163.0 / 255.0, 184.0 / 255.0, 0.3)
const INSET_SHADOW: Color = Color(100.0 / 255.0, 116.0 / 255.0, 139.0 / 255.0, 0.6)

var ratio: float = 0.0:
	set(value):
		ratio = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func apply() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "ratio", FINAL_RATIO, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if ratio <= 0.001:
		return
	var s: Vector2 = size * ratio
	var rect: Rect2 = Rect2((size - s) / 2.0, s)
	var radius: float = minf(8.0, minf(s.x, s.y) / 2.0)
	UIStyle.box(BASE_COLOR, radius, 0, Color.TRANSPARENT, Color(0, 0, 0, 0.3), 2, Vector2(0, 2)).draw(get_canvas_item(), rect)
	# Macunun yayılma izleri (köşelerden halkalar)
	_draw_rings(rect, rect.position, 17.0, 18.0, LIGHT_RING)
	_draw_rings(rect, rect.end, 22.0, 23.0, DARK_RING)
	# İçe doğru gölge ve kenar koyuluğu
	for i: int in range(6):
		var inset: float = float(i) * 1.6
		var r: Rect2 = rect.grow(-inset)
		if r.size.x <= 4.0:
			break
		var alpha: float = INSET_SHADOW.a * 0.4 * (1.0 - float(i) / 6.0)
		UIStyle.box(Color.TRANSPARENT, maxf(radius - inset, 1.0), 2, Color(INSET_SHADOW, alpha)).draw(get_canvas_item(), r)

# Verilen merkezden tekrar eden halkalar çizer, yalnızca dikdörtgen içinde kalanları
func _draw_rings(rect: Rect2, center: Vector2, first_radius: float, period: float, color: Color) -> void:
	var inner: Rect2 = rect.grow(-1.0)
	var max_radius: float = rect.size.length()
	var radius: float = first_radius
	while radius < max_radius:
		var run: PackedVector2Array = PackedVector2Array()
		for i: int in range(97):
			var a: float = TAU * float(i) / 96.0
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			if inner.has_point(p):
				run.append(p)
			else:
				if run.size() >= 2:
					draw_polyline(run, color, 2.0, true)
				run = PackedVector2Array()
		if run.size() >= 2:
			draw_polyline(run, color, 2.0, true)
		radius += period
