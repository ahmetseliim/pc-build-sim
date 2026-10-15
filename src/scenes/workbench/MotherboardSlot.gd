class_name MotherboardSlot
extends Control

# Anakart yuvası (HTML sürümündeki .slot öğesi)
# Boş yuvayı kesikli/düz kenarlıkla ve etiketiyle çizer, parçayı içine oturtur.

@export var slot_id: String = ""
@export var accepted_type: String = ""
@export var slot_label: String = ""

@export_group("Görünüm")
@export var border_color: Color = Color("#475569"):
	set(value):
		border_color = value
		queue_redraw()
@export var border_width: int = 2
@export var dashed: bool = true
@export var corner_radius: float = 6.0
@export var is_circle: bool = false
@export var fill_color: Color = Color(15.0 / 255.0, 23.0 / 255.0, 42.0 / 255.0, 0.6)
@export var label_size: int = 11
@export var label_color: Color = Color("#94a3b8")
@export var vertical_label: bool = false
@export var label_spacing: int = 0

const HINT_COLOR: Color = Color(0.29, 0.87, 0.5)

var is_occupied: bool = false
var installed_part: ComponentData = null

## Sürüklenen parça buraya takılabiliyorsa yuva yeşil yanıp söner
var hint: bool = false:
	set(value):
		hint = value
		_hint_time = 0.0
		set_process(value)
		queue_redraw()

var _hint_time: float = 0.0

# RAM yuvası kilit mandalları (0: üst, 1: alt). Gerçekte RAM sökmek için iki uçtaki
# mandallar dışa doğru bastırılır, RAM yuvasından hafifçe yukarı fırlar.
var latch_state: Array[bool] = [false, false] ## Mandal açık mı?
var latch_amount: Array[float] = [0.0, 0.0] ## Çizim için açıklık (0-1, animasyonlu)
## Mandallara tıklanabilir mi (senaryoda bu parça sökülebiliyorsa)
var latches_interactive: bool = false:
	set(value):
		latches_interactive = value
		for button: Control in _latch_buttons:
			button.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
## Oyuncuya mandalları göstermek için kısa yanıp sönme
var latch_flash: float = 0.0:
	set(value):
		latch_flash = value
		queue_redraw()

var _latch_buttons: Array[Control] = []

signal slot_filled(slot: MotherboardSlot)
signal latch_toggled(slot: MotherboardSlot)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if accepted_type == "ram":
		_create_latch_buttons()

func _process(delta: float) -> void:
	_hint_time += delta
	queue_redraw()

# Mandalların tıklama alanları (parçanın üstünde kalır)
func _create_latch_buttons() -> void:
	for i: int in range(2):
		var button: Control = Control.new()
		button.size = Vector2(24, 16)
		button.position = Vector2(size.x / 2.0 - 12.0, -13.0 if i == 0 else size.y - 3.0)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Mandalı aç / kapat"
		button.gui_input.connect(_on_latch_input.bind(i))
		add_child(button)
		_latch_buttons.append(button)

func _on_latch_input(event: InputEvent, index: int) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_latch_buttons[index].accept_event()
		set_latch(index, not latch_state[index])
		latch_toggled.emit(self)

func set_latch(index: int, open: bool, animate: bool = true) -> void:
	latch_state[index] = open
	var target: float = 1.0 if open else 0.0
	if animate:
		create_tween().tween_method(_set_latch_amount.bind(index), latch_amount[index], target, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_latch_amount(target, index)

func _set_latch_amount(value: float, index: int) -> void:
	latch_amount[index] = value
	queue_redraw()

func latches_open() -> bool:
	return latch_state[0] and latch_state[1]

# Mandalları birkaç kez sarı yakıp söndürür
func flash_latches() -> void:
	latch_flash = 1.0
	create_tween().tween_property(self, "latch_flash", 0.0, 1.2)

# Parçanın oturacağı alan: yuvanın tamamı (envanterdeki boyutla 1:1)
func content_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func install(part: PartItem, animate: bool = true) -> void:
	is_occupied = true
	installed_part = part.data
	part.place_into(self, content_rect(), animate)
	queue_redraw()
	# Açık mandallar parça oturunca "klik" diye kapanır
	for i: int in range(2):
		if latch_state[i]:
			set_latch(i, false, animate)
	InventoryManager.remove_part(part.data)
	slot_filled.emit(self)
	EventBus.part_installed.emit(slot_id, part.data)

# Takılı parçayı yuvadan ayırır (parça düğümünü çağıran yönetir)
func uninstall() -> void:
	if not is_occupied:
		return
	var removed: ComponentData = installed_part
	is_occupied = false
	installed_part = null
	queue_redraw()
	EventBus.part_removed.emit(slot_id, removed)

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var radius: float = size.x / 2.0 if is_circle else corner_radius
	var canvas: RID = get_canvas_item()
	var pulse: float = 0.5 + 0.5 * sin(_hint_time * 6.0)
	if hint:
		UIStyle.draw_rect_glow(self, rect, 10.0, Color(HINT_COLOR, 0.35 + 0.35 * pulse))
	UIStyle.box(fill_color, radius).draw(canvas, rect)
	if hint:
		UIStyle.box(Color(HINT_COLOR, 0.12 + 0.1 * pulse), radius).draw(canvas, rect)

	if dashed:
		var inset: float = float(border_width) / 2.0
		var pts: PackedVector2Array
		if is_circle:
			pts = UIStyle.circle_points(rect.get_center(), size.x / 2.0 - inset)
		else:
			pts = UIStyle.rounded_points(rect.grow(-inset), maxf(radius - inset, 0.5))
		UIStyle.draw_dashed_loop(self, pts, HINT_COLOR if hint else border_color, float(border_width), border_width * 3.0, border_width * 2.5)
	else:
		UIStyle.box(Color.TRANSPARENT, radius, border_width, HINT_COLOR if hint else border_color).draw(canvas, rect)

	if accepted_type == "ram":
		_draw_latches()

	if not is_occupied and slot_label != "":
		_draw_label()

# RAM yuvasının iki ucundaki kilit mandalları; açılınca dışa doğru yatar
func _draw_latches() -> void:
	var blink: float = latch_flash * (0.5 + 0.5 * sin(latch_flash * 30.0))
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var amount: float = latch_amount[i]
		var hinge: Vector2 = Vector2(size.x / 2.0, 0.0 if side < 0.0 else size.y)
		draw_set_transform(hinge, side * amount * 0.7)
		var rect: Rect2 = Rect2(Vector2(-8, -8 if side < 0.0 else 1), Vector2(16, 7))
		if blink > 0.01:
			UIStyle.draw_rect_glow(self, rect, 8.0, Color(Color("#fbbf24"), blink))
		var color: Color = Color("#cbd5e1").lerp(Color("#fbbf24"), maxf(amount, blink))
		UIStyle.box(color, 2, 1, Color("#475569")).draw(get_canvas_item(), rect)
		# Tırnak çizgisi
		draw_line(rect.position + Vector2(4, rect.size.y / 2.0), rect.end - Vector2(4, rect.size.y / 2.0), Color("#475569"), 1.0)
		draw_set_transform(Vector2.ZERO)

func _draw_label() -> void:
	var font: Font = UIStyle.ui_font(true, label_spacing)
	var ascent: float = font.get_ascent(label_size)
	if vertical_label:
		var w: float = font.get_string_size(slot_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_set_transform(Vector2(size.x / 2.0, (size.y - w) / 2.0), PI / 2.0)
		draw_string(font, Vector2(0, (ascent - font.get_descent(label_size)) / 2.0), slot_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)
		draw_set_transform(Vector2.ZERO)
	else:
		var width: float = maxf(size.x - 4.0, 1.0)
		var text_h: float = font.get_multiline_string_size(slot_label, HORIZONTAL_ALIGNMENT_CENTER, width, label_size).y
		draw_multiline_string(font, Vector2(2, (size.y - text_h) / 2.0 + ascent), slot_label, HORIZONTAL_ALIGNMENT_CENTER, width, label_size, -1, label_color)
