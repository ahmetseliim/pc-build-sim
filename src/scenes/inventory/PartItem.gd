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
var is_broken: bool = false ## Arızalı kablo/parça: takılıyken tıklanınca sökülür ve atılır
var is_removable: bool = false ## Takılıyken (mandalları açılınca) tutulup sökülebilir
var is_loose: bool = false ## Mandalları açıldı, yuvasından kalktı; tutulup çekilebilir
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
		EventBus.boot_failed.connect(_on_boot_failed)

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if is_placed:
		if not (mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
			return
		accept_event()
		if is_removable and not data.is_cable:
			if not is_loose:
				# Mandallar kapalı: parça yerinde kilitli
				EventBus.part_locked_touched.emit(self)
				return
			# Yuvasından kalkmış parçayı tutup çek
			EventBus.part_extract_requested.emit(self)
			is_placed = false
			is_loose = false
			_start_drag(mb.position)
		elif is_broken:
			# Bozuk kablo: tıklayınca sök
			EventBus.part_unplug_requested.emit(self)
		return
	if is_dragging:
		return
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		accept_event()
		_start_drag(mb.position)

func _start_drag(local_point: Vector2) -> void:
	# Tutulan noktayı koru (HTML'deki shiftX / shiftY)
	_grab_offset = local_point
	_pointer = global_position + local_point
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
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = data.part_name
	custom_minimum_size = data.part_size
	reparent(container, false)

# Takılı parçanın tıklanabilirliğini (söküm) günceller
func refresh_interaction() -> void:
	if not is_placed:
		return
	if is_removable and not data.is_cable:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG if is_loose else Control.CURSOR_ARROW
		tooltip_text = "Tutup envantere sürükle" if is_loose else "Sökmek için önce mandalları aç"
	elif is_broken:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Sökmek için tıkla"
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = ""

# Yuvadan sökülen parçayı tekrar sürüklenebilir hale getirir
func unplace() -> void:
	is_placed = false
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = data.part_name
	queue_redraw()

# Parçayı yuvaya oturtur; boyut envanterdekiyle aynıdır (1:1)
func place_into(slot: Control, rect: Rect2, animate: bool = true) -> void:
	is_placed = true
	is_loose = false
	refresh_interaction()
	custom_minimum_size = Vector2.ZERO
	if get_parent():
		reparent(slot, false)
	else:
		slot.add_child(self)
	slot.move_child(self, 0) # Yuvanın kaplamaları parçanın üstünde kalsın
	position = rect.position
	size = rect.size
	queue_redraw()
	if not animate:
		return
	# Yerine oturma hissi için küçük bir esneme
	pivot_offset = size / 2.0
	scale = Vector2(1.08, 1.08)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_boot_started() -> void:
	is_spinning = true
	set_process(true)

func _on_boot_failed() -> void:
	is_spinning = false
	set_process(false)

func _process(delta: float) -> void:
	if is_spinning:
		icon_angle = fmod(icon_angle + SPIN_SPEED * delta, TAU)
		queue_redraw()

func _draw() -> void:
	if data:
		PartArt.draw(self, data, Rect2(Vector2.ZERO, size), is_placed, icon_angle)
