class_name ScrewMechanic
extends Control

# Vida sıkma mini oyunu
# CPU fanını 4 vida ile sabitleme.
# Oyuncu her vidaya basılı tutarak sıkar; bırakınca ilerleme korunur.

signal all_screws_done()

@export var screw_speed: float = 75.0 ## Saniyede ilerleme yüzdesi (HTML: 20 ms'de %1,5)
@export var required_screws: int = 4 ## Gereken vida sayısı

const SCREW_SIZE: float = 24.0
const SCREW_MARGIN: float = 8.0

var screws_locked: int = 0
var screw_nodes: Array[Node] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# Vidaları fanın köşelerine yerleştirir (boyut ayarlandıktan sonra çağrılmalı)
func start() -> void:
	screws_locked = 0
	var far: Vector2 = size - Vector2.ONE * (SCREW_SIZE + SCREW_MARGIN)
	var positions: Array[Vector2] = [
		Vector2(SCREW_MARGIN, SCREW_MARGIN), # Sol üst
		Vector2(far.x, SCREW_MARGIN),        # Sağ üst
		Vector2(SCREW_MARGIN, far.y),        # Sol alt
		far,                                 # Sağ alt
	]
	for i: int in range(mini(required_screws, positions.size())):
		var screw: ScrewNode = ScrewNode.new()
		screw.position = positions[i]
		screw.size = Vector2.ONE * SCREW_SIZE
		screw.screw_id = "screw_%d" % i
		screw.screw_speed = screw_speed
		screw.screw_completed.connect(_on_screw_completed)
		add_child(screw)
		screw_nodes.append(screw)

func _on_screw_completed(screw_id: String) -> void:
	screws_locked += 1
	EventBus.screw_locked.emit(screw_id)

	if screws_locked >= required_screws:
		all_screws_done.emit()
		EventBus.all_screws_locked.emit()
		EventBus.fan_mounted.emit()

# İç sınıf: Tek bir vida
class ScrewNode extends Control:
	signal screw_completed(screw_id: String)

	const COLOR_IDLE: Color = Color("#94a3b8")
	const COLOR_GREEN: Color = Color("#10b981")
	const COLOR_DARK: Color = Color("#334155")
	const COLOR_DARKER: Color = Color("#0f172a")

	var screw_id: String = ""
	var screw_speed: float = 75.0
	var progress: float = 0.0 # 0 - 100
	var is_locked: bool = false
	var is_pressing: bool = false
	var flash: float = 0.0:
		set(value):
			flash = value
			queue_redraw()

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if is_locked:
			return
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			is_pressing = mb.pressed
			accept_event()
			queue_redraw()

	func _process(delta: float) -> void:
		if is_locked or not is_pressing:
			return
		progress = minf(100.0, progress + screw_speed * delta)
		if progress >= 100.0:
			_lock()
		queue_redraw()

	func _lock() -> void:
		is_locked = true
		is_pressing = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		flash = 1.0
		create_tween().tween_property(self, "flash", 0.0, 0.6).set_ease(Tween.EASE_OUT)
		screw_completed.emit(screw_id)

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var r: float = size.x / 2.0
		# Gölge (box-shadow: 0 3px 5px)
		UIStyle.draw_soft_circle(self, c + Vector2(0, 3), r - 1.0, 3.0, Color(0, 0, 0, 0.5))
		# Sıkılırken yeşil parlama
		if is_pressing and not is_locked:
			UIStyle.draw_soft_circle(self, c, r, 10.0, Color(COLOR_GREEN, 0.7))
		# Kilitlenme anındaki parlama
		if flash > 0.0:
			UIStyle.draw_soft_circle(self, c, r, 20.0 * flash, Color(COLOR_GREEN, flash))

		var body: Color = COLOR_DARK.lerp(COLOR_GREEN, flash) if is_locked else COLOR_IDLE
		var border: Color = COLOR_DARKER.lerp(COLOR_GREEN, flash) if is_locked else COLOR_DARK
		draw_circle(c, r - 1.0, body)

		# İlerleme göstergesi (conic-gradient)
		if not is_locked and progress > 0.0:
			var end_angle: float = progress / 100.0 * TAU
			var steps: int = maxi(2, int(progress / 100.0 * 40.0))
			var pts: PackedVector2Array = PackedVector2Array([c])
			for i: int in range(steps + 1):
				var a: float = -PI / 2.0 + end_angle * float(i) / float(steps)
				pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
			draw_colored_polygon(pts, COLOR_GREEN)

		# Kilitliyken içe gömülü gölge
		if is_locked:
			for i: int in range(3):
				draw_arc(c, r - 2.5 - float(i), PI * 1.05, PI * 1.95, 16, Color(0, 0, 0, 0.45 - 0.13 * float(i)), 1.5, true)

		draw_arc(c, r - 1.0, 0.0, TAU, 40, border, 2.0, true)

		# Vida başı: kilitliyse yeşil tik, değilse dönen "+"
		if is_locked:
			draw_polyline(PackedVector2Array([c + Vector2(-4.5, 0), c + Vector2(-1.5, 3.5), c + Vector2(4.5, -3.5)]), COLOR_GREEN, 2.5, true)
		else:
			var font: Font = UIStyle.ui_font(true)
			var w: float = font.get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_set_transform(c, deg_to_rad(progress * 7.2))
			draw_string(font, Vector2(-w / 2.0, (font.get_ascent(14) - font.get_descent(14)) / 2.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_DARK)
			draw_set_transform(Vector2.ZERO)
