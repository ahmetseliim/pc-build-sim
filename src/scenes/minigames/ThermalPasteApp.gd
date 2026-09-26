class_name ThermalPasteApp
extends Node2D

# Termal macun mini oyunu
# Oyuncu CPU üzerine macun sürer.
# _draw() ile canvas boyama kullanılır.

signal paste_complete(coverage: float)
signal paste_spilled()

@export var min_coverage_percent: float = 85.0 ## Minimum kapsama yüzdesi
@export var brush_radius: float = 10.0 ## Fırça boyutu
@export var cpu_size: Vector2 = Vector2(115, 115) ## CPU alanı

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
	_reset_grid()

func start() -> void:
	is_active = true
	is_painting = false
	has_spilled = false
	coverage = 0.0
	paste_points.clear()
	_reset_grid()
	queue_redraw()

func stop() -> void:
	is_active = false
	is_painting = false

func _reset_grid() -> void:
	coverage_grid.clear()
	for c: int in range(grid_cols):
		var row: Array = []
		for r: int in range(grid_rows):
			row.append(false)
		coverage_grid.append(row)

func _input(event: InputEvent) -> void:
	if not is_active or has_spilled:
		return
	
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			is_painting = true
			_paint(get_local_mouse_position())
		else:
			is_painting = false
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_painting:
		var pos: Vector2 = get_local_mouse_position()
		# Taşma kontrolü
		if pos.x < -2 or pos.x > cpu_size.x + 2 or pos.y < -2 or pos.y > cpu_size.y + 2:
			_trigger_spill()
			return
		_paint(pos)

func _paint(pos: Vector2) -> void:
	paste_points.append(pos)
	
	# Kapsama ızgarasını güncelle
	var cell_size: float = 5.0
	var min_col: int = maxi(0, int((pos.x - brush_radius) / cell_size))
	var max_col: int = mini(grid_cols - 1, int((pos.x + brush_radius) / cell_size))
	var min_row: int = maxi(0, int((pos.y - brush_radius) / cell_size))
	var max_row: int = mini(grid_rows - 1, int((pos.y + brush_radius) / cell_size))
	
	for c: int in range(min_col, max_col + 1):
		for r: int in range(min_row, max_row + 1):
			var cell_x: float = c * cell_size + cell_size / 2.0
			var cell_y: float = r * cell_size + cell_size / 2.0
			var dist: float = pos.distance_to(Vector2(cell_x, cell_y))
			if dist <= brush_radius:
				coverage_grid[c][r] = true
	
	# Kapsama yüzdesini hesapla
	var covered: int = 0
	for c: int in range(grid_cols):
		for r: int in range(grid_rows):
			if coverage_grid[c][r]:
				covered += 1
	
	coverage = float(covered) / float(grid_cols * grid_rows) * 100.0
	
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
	# CPU arka planı (yarı saydam)
	draw_rect(Rect2(Vector2.ZERO, cpu_size), Color(0.2, 0.2, 0.25, 0.3))
	
	# Macun noktaları
	var paste_color: Color = Color(0.58, 0.64, 0.69, 0.9) # #94a3b8
	for point: Vector2 in paste_points:
		draw_circle(point, brush_radius, paste_color)
	
	# Taşma durumunda kırmızı çerçeve
	if has_spilled:
		draw_rect(Rect2(Vector2.ZERO, cpu_size), Color(1, 0, 0, 0.5), false, 3.0)
