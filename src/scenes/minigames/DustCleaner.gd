class_name DustCleaner
extends Control

# Toz temizleme mini oyunu (Aşırı ısınma işi)
# Macun boyama ızgarasının tersi: fanın ızgarası baştan kirlidir, oyuncu basılı tutup sürükleyerek tozu temizler.
# Dükkândaki hava kompresörü (alet) kullanılabilirken hava huzmesi geniştir; yoksa (Test menüsü) dar bir fırçayla temizlenir.
# Kirli hücrelerin %92'si temizlenince biter (GameManager.dusty = false).

signal progress_changed(percent: int)
signal cleaned()

const CELL: float = 5.0 ## Izgara hücre boyutu (px)
const CLEAN_TARGET: float = 92.0 ## Bitmek için temizlenmesi gereken oran (%)
const BRUSH_RADIUS: float = 12.0 ## Fırça yarıçapı (Test menüsü)
const AIR_RADIUS: float = 22.0 ## Hava kompresörünün huzme yarıçapı
const DUST_COLOR: Color = Color("#8a8072")

var cols: int = 0
var rows: int = 0
var dirty: Array = [] ## [sütun][satır] -> true: hâlâ tozlu
var dirty_total: int = 0
var dirty_left: int = 0
var radius: float = BRUSH_RADIUS
var is_active: bool = true
var _painting: bool = false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	radius = AIR_RADIUS if CareerManager.effect_active("alet_kompresor") else BRUSH_RADIUS
	if UIStyle.ui_scale(get_viewport()) > 1.0:
		radius *= 1.5 # Telefonda parmak büyük
	tooltip_text = "Basılı tutup sürükleyerek tozu temizle"
	rebuild()

# Izgarayı boyuta göre kurar; fanın ortasındaki dairesel bölge tozludur (köşeler boş kalır)
func rebuild() -> void:
	cols = maxi(1, int(size.x / CELL))
	rows = maxi(1, int(size.y / CELL))
	dirty.clear()
	dirty_total = 0
	var center: Vector2 = Vector2(cols, rows) / 2.0
	var limit: float = minf(cols, rows) / 2.0
	for c: int in range(cols):
		var column: Array = []
		for r: int in range(rows):
			var is_dirty: bool = Vector2(c + 0.5, r + 0.5).distance_to(center) <= limit
			column.append(is_dirty)
			if is_dirty:
				dirty_total += 1
		dirty.append(column)
	dirty_left = dirty_total
	is_active = true
	queue_redraw()

func percent_cleaned() -> float:
	return 100.0 * (1.0 - float(dirty_left) / float(maxi(dirty_total, 1)))

# Verilen noktadaki hücrelerdeki tozu siler (fare hareketi ve testler bunu çağırır)
func scrub(pos: Vector2) -> void:
	if not is_active:
		return
	var min_col: int = maxi(0, int(floor((pos.x - radius) / CELL)))
	var max_col: int = mini(cols - 1, int(floor((pos.x + radius) / CELL)))
	var min_row: int = maxi(0, int(floor((pos.y - radius) / CELL)))
	var max_row: int = mini(rows - 1, int(floor((pos.y + radius) / CELL)))
	for c: int in range(min_col, max_col + 1):
		for r: int in range(min_row, max_row + 1):
			if dirty[c][r] and pos.distance_to(Vector2(c + 0.5, r + 0.5) * CELL) <= radius:
				dirty[c][r] = false
				dirty_left -= 1
	progress_changed.emit(int(percent_cleaned()))
	queue_redraw()
	if percent_cleaned() >= CLEAN_TARGET:
		is_active = false
		_painting = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameManager.dusty = false
		cleaned.emit()
		EventBus.dust_cleaned.emit()

func _gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_painting = mb.pressed
		if mb.pressed:
			scrub(mb.position)
	elif event is InputEventMouseMotion and _painting:
		scrub((event as InputEventMouseMotion).position)

func _draw() -> void:
	if not is_active and dirty_left < dirty_total:
		return # Temizlendi: kalan birkaç tozu çizme
	for c: int in range(cols):
		for r: int in range(rows):
			if dirty[c][r]:
				# Her hücrenin tozu biraz farklı koyulukta ve yarı saydam (hafif tüylü görünüm)
				var shade: float = float((c * 7 + r * 13) % 5) * 0.05
				draw_rect(Rect2(Vector2(c, r) * CELL, Vector2.ONE * CELL), Color(DUST_COLOR.darkened(shade), 0.82))
	# Üstte aletin adı
	var font: Font = UIStyle.ui_font(true)
	var label: String = "HAVA KOMPRESÖRÜ" if CareerManager.effect_active("alet_kompresor") else "FIRÇA"
	if is_active:
		draw_string(font, Vector2(4, size.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 9, Color("#f8fafc"))
