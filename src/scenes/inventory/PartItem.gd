class_name PartItem
extends Control

# Sürüklenebilir donanım parçası veya kablo fişi.
# Görünümünü PartArt ile çizer; envanterden tutulup imleçle birlikte taşınır,
# bırakıldığında EventBus.part_dropped ile anakarta haber verir.

const SPIN_SPEED: float = TAU / 0.25 ## Bilgisayar açılınca fanların dönüş hızı (HTML: 0.25 sn'de bir tur)
const SPINNING_TYPES: Array[String] = ["fan", "gpu", "psu"]

var data: ComponentData = null
var is_placed: bool = false
var is_dragging: bool = false
var is_spinning: bool = false
var icon_angle: float = 0.0

var _grab_offset: Vector2 = Vector2.ZERO
var _pointer: Vector2 = Vector2.ZERO # İmlecin son konumu (tuval koordinatı)

func setup(part_data: ComponentData) -> void:
	data = part_data
	custom_minimum_size = data.part_size
	size = data.part_size
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = data.part_name
	set_process_input(false)
	set_process(false)
	if data.part_type in SPINNING_TYPES:
		EventBus.bios_boot_started.connect(_on_boot_started)

func _gui_input(event: InputEvent) -> void:
	if is_placed or is_dragging:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		accept_event()
		# Tutulan noktayı koru (HTML'deki shiftX / shiftY)
		_grab_offset = mb.position
		_pointer = global_position + mb.position
		is_dragging = true
		tooltip_text = ""
		set_process_input(true)
		_begin_drag.call_deferred()

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		_follow_mouse()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_pointer = mb.position
			get_viewport().set_input_as_handled()
			_finish_drag.call_deferred()

func _begin_drag() -> void:
	# Parçayı en üstteki sürükleme katmanına taşı
	var layer: Node = get_tree().get_first_node_in_group("drag_layer")
	if layer:
		reparent(layer)
	_follow_mouse()
	EventBus.part_drag_started.emit(self)

func _finish_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	set_process_input(false)
	_follow_mouse()
	EventBus.part_dropped.emit(self, _pointer)

func _follow_mouse() -> void:
	global_position = _pointer - _grab_offset

# Parçayı envanterin sonuna geri koyar (HTML'deki returnToInventory)
func return_to(container: Container) -> void:
	is_dragging = false
	visible = true
	tooltip_text = data.part_name
	custom_minimum_size = data.part_size
	reparent(container, false)

# Parçayı yuvaya oturtur; boyut envanterdekiyle aynıdır (1:1)
func place_into(slot: Control, rect: Rect2) -> void:
	is_placed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	custom_minimum_size = Vector2.ZERO
	reparent(slot, false)
	slot.move_child(self, 0) # Yuvanın kaplamaları parçanın üstünde kalsın
	position = rect.position
	size = rect.size
	queue_redraw()
	# Yerine oturma hissi için küçük bir esneme
	pivot_offset = size / 2.0
	scale = Vector2(1.08, 1.08)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_boot_started() -> void:
	is_spinning = true
	set_process(true)

func _process(delta: float) -> void:
	if is_spinning:
		icon_angle = fmod(icon_angle + SPIN_SPEED * delta, TAU)
		queue_redraw()

func _draw() -> void:
	if data:
		PartArt.draw(self, data, Rect2(Vector2.ZERO, size), is_placed, icon_angle)
