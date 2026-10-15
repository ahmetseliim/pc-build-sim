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

signal slot_filled(slot: MotherboardSlot)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _process(delta: float) -> void:
	_hint_time += delta
	queue_redraw()

# Parçanın oturacağı alan: yuvanın tamamı (envanterdeki boyutla 1:1)
func content_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func install(part: PartItem) -> void:
	is_occupied = true
	installed_part = part.data
	part.place_into(self, content_rect())
	queue_redraw()
	InventoryManager.remove_part(part.data)
	slot_filled.emit(self)
	EventBus.part_installed.emit(slot_id, part.data)

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

	if not is_occupied and slot_label != "":
		_draw_label()

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
