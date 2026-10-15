class_name ThermalPasteApp
extends Control

# Termal macun mini oyunu
# Oyuncu CPU üzerine basılı tutup sürükleyerek macun sürer.
# İşlemci alanının dışına taşarsa macun "taşar" ve temizlenmesi gerekir.

signal paste_complete(coverage: float)
signal paste_spilled()
signal coverage_changed(percent: int)

@export var min_coverage_percent: float = 85.0 ## Minimum kapsama yüzdesi
@export var brush_radius: float = 10.0 ## Fırça boyutu
@export var cell_size: float = 5.0 ## Kapsama ızgarası hücre boyutu

const PASTE_COLOR: Color = Color("#94a3b8")
const PASTE_SHADOW: Color = Color(100.0 / 255.0, 116.0 / 255.0, 139.0 / 255.0, 0.45)
const SPILL_MARGIN: float = 2.0

var paste_points: Array[Vector2] = []
var is_active: bool = false
var is_painting: bool = false
var has_spilled: bool = false
var coverage: float = 0.0

# Kapsama hesabı için ızgara
var grid_cols: int = 23
var grid_rows: int = 23
var coverage_grid: Array = []

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	grid_cols = int(size.x / cell_size)
	grid_rows = int(size.y / cell_size)
	_reset_grid()

func start() -> void:
	visible = true
	is_active = true
	is_painting = false
	has_spilled = false
	coverage = 0.0
	paste_points.clear()
	_reset_grid()
	coverage_changed.emit(0)
	queue_redraw()

func stop() -> void:
	is_active = false
	is_painting = false

func _reset_grid() -> void:
	coverage_grid.clear()
	for c: int in range(grid_cols):
		var row: Array = []
		row.resize(grid_rows)
		row.fill(false)
		coverage_grid.append(row)

func _gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed:
			if has_spilled:
				return
			is_painting = true
			_paint(mb.position)
		else:
			is_painting = false
	elif event is InputEventMouseMotion and is_painting and not has_spilled:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		# Taşma kontrolü (2 px tolerans)
		if pos.x < -SPILL_MARGIN or pos.x > size.x + SPILL_MARGIN or pos.y < -SPILL_MARGIN or pos.y > size.y + SPILL_MARGIN:
			_trigger_spill()
			return
		_paint(pos)

func _paint(pos: Vector2) -> void:
	paste_points.append(pos)

	# Kapsama ızgarasını güncelle
	var min_col: int = maxi(0, int(floor((pos.x - brush_radius) / cell_size)))
	var max_col: int = mini(grid_cols - 1, int(floor((pos.x + brush_radius) / cell_size)))
	var min_row: int = maxi(0, int(floor((pos.y - brush_radius) / cell_size)))
	var max_row: int = mini(grid_rows - 1, int(floor((pos.y + brush_radius) / cell_size)))

	for c: int in range(min_col, max_col + 1):
		for r: int in range(min_row, max_row + 1):
			var cell_center: Vector2 = Vector2(c * cell_size + cell_size / 2.0, r * cell_size + cell_size / 2.0)
			if pos.distance_to(cell_center) <= brush_radius:
				coverage_grid[c][r] = true

	# Kapsama yüzdesini hesapla
	var covered: int = 0
	for c: int in range(grid_cols):
		for r: int in range(grid_rows):
			if coverage_grid[c][r]:
				covered += 1

	coverage = float(covered) / float(grid_cols * grid_rows) * 100.0
	coverage_changed.emit(int(coverage))
	queue_redraw()

	if coverage >= min_coverage_percent:
		_complete()

func _trigger_spill() -> void:
	has_spilled = true
	is_painting = false
	paste_spilled.emit()
	EventBus.paste_failed.emit()

func _complete() -> void:
	is_active = false
	is_painting = false
	paste_complete.emit(coverage)
	EventBus.paste_applied.emit()

func _draw() -> void:
	# Her fırça darbesi hafif gölgeli bir daire (HTML canvas shadowBlur karşılığı)
	for point: Vector2 in paste_points:
		draw_circle(point, brush_radius + 2.0, PASTE_SHADOW)
		draw_circle(point, brush_radius, PASTE_COLOR)
