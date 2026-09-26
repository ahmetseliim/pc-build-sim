class_name ScrewMechanic
extends Node2D

# Vida sıkma mini oyunu
# CPU fanını 4 vida ile sabitleme.
# Oyuncu her vidaya basılı tutarak sıkar.

signal all_screws_done()

@export var screw_speed: float = 1.5 ## Vida sıkma hızı (saniye başına ilerleme)
@export var required_screws: int = 4 ## Gereken vida sayısı

var screws_locked: int = 0
var screw_nodes: Array[Node] = []

# Vida pozisyonları (fanın köşeleri)
var screw_positions: Array[Vector2] = [
	Vector2(8, 8),      # Sol üst
	Vector2(107, 8),    # Sağ üst
	Vector2(8, 107),    # Sol alt
	Vector2(107, 107),  # Sağ alt
]

func _ready() -> void:
	pass

func start() -> void:
	screws_locked = 0
	_create_screws()

func _create_screws() -> void:
	for i: int in range(required_screws):
		var screw: ScrewNode = ScrewNode.new()
		screw.position = screw_positions[i]
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

# İç sınıf: Tek bir vida düğümü
class ScrewNode extends Node2D:
	signal screw_completed(screw_id: String)
	
	var screw_id: String = ""
	var screw_speed: float = 1.5
	var progress: float = 0.0
	var is_locked: bool = false
	var is_pressing: bool = false
	var screw_radius: float = 12.0
	
	func _ready() -> void:
		pass
	
	func _input(event: InputEvent) -> void:
		if is_locked:
			return
		
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			var pos: Vector2 = get_local_mouse_position()
			if pos.length() <= screw_radius:
				is_pressing = event.pressed
			else:
				is_pressing = false
	
	func _process(delta: float) -> void:
		if is_locked or not is_pressing:
			return
		
		progress += screw_speed * delta
		if progress >= 1.0:
			progress = 1.0
			is_locked = true
			is_pressing = false
			screw_completed.emit(screw_id)
		
		queue_redraw()
	
	func _draw() -> void:
		# Vida arka planı
		var bg_color: Color = Color(0.2, 0.25, 0.3) if not is_locked else Color(0.08, 0.08, 0.12)
		draw_circle(Vector2.ZERO, screw_radius, bg_color)
		
		# İlerleme göstergesi (conic gradient simülasyonu)
		if progress > 0 and not is_locked:
			var end_angle: float = progress * TAU
			var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
			for angle_step: int in range(int(end_angle * 10) + 1):
				var a: float = float(angle_step) / 10.0
				points.append(Vector2(cos(a - PI/2), sin(a - PI/2)) * screw_radius)
			if points.size() > 2:
				draw_colored_polygon(points, Color(0.06, 0.73, 0.51, 0.8))
		
		# Vida başı (+) veya (✔)
		if is_locked:
			draw_string(ThemeDB.fallback_font, Vector2(-5, 5), "✔", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.06, 0.73, 0.51))
		else:
			draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.2, 0.25, 0.35), 2.0)
			draw_line(Vector2(0, -5), Vector2(0, 5), Color(0.2, 0.25, 0.35), 2.0)
		
		# Basılı tutulurken parlama efekti
		if is_pressing and not is_locked:
			draw_circle(Vector2.ZERO, screw_radius + 3, Color(0.06, 0.73, 0.51, 0.3))
