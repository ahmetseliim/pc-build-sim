class_name MotherboardSlot
extends Control

@export var slot_id: String = "" 
@export var accepted_type: String = "" 
@export var accepted_socket: String = "" 
@export var slot_label: String = "" 
@export var requires_state: String = "" 

var is_occupied: bool = false
var installed_part: ComponentData = null
var is_highlighted: bool = false

signal slot_filled(slot: MotherboardSlot)
signal slot_emptied(slot: MotherboardSlot)

func _ready() -> void:
	if slot_label != "":
		$SlotLabel.text = slot_label

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	
	if is_occupied:
		# Draw the installed part's background
		draw_rect(rect, installed_part.bg_color)
		
		# Draw border
		var border_color = Color(1.0, 1.0, 1.0, 0.2)
		draw_rect(rect, border_color, false, 2.0)
		
		# Icon text is drawn by a Label node created dynamically or we just draw string
		var font = ThemeDB.fallback_font
		var text_size = font.get_string_size(installed_part.icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
		var text_pos = (size - text_size) / 2.0 + Vector2(0, font.get_ascent(32))
		draw_string(font, text_pos, installed_part.icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
		
	else:
		# Draw empty slot (dashed look simulation)
		var bg_color = Color(15.0/255.0, 23.0/255.0, 42.0/255.0, 0.6)
		if is_highlighted:
			bg_color = Color(0.1, 0.4, 0.2, 0.8) # Green highlight
			
		draw_rect(rect, bg_color)
		
		# Draw solid border (dashed is complex in raw _draw, solid is fine for now)
		var border_color = Color("#ef4444") if accepted_type == "cpu" else Color("#475569")
		if is_highlighted:
			border_color = Color("#4ade80")
			
		draw_rect(rect, border_color, false, 2.0)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if is_occupied:
		return false
	
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "component":
		var part = data["data"] as ComponentData
		if part.part_type == accepted_type:
			highlight(true)
			return true
			
	highlight(false)
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	highlight(false)
	if typeof(data) == TYPE_DICTIONARY and data.has("data"):
		var part = data["data"] as ComponentData
		try_install(part)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		highlight(false)

func try_install(part: ComponentData) -> bool:
	if is_occupied:
		return false
	
	if accepted_socket != "" and part.socket != accepted_socket:
		return false
	
	if requires_state != "" and GameManager.cpu_state != requires_state:
		return false
	
	installed_part = part
	is_occupied = true
	$SlotLabel.visible = false
	queue_redraw()
	
	slot_filled.emit(self)
	EventBus.part_installed.emit(slot_id, part)
	return true

func remove_part() -> ComponentData:
	if not is_occupied:
		return null
	
	var removed = installed_part
	installed_part = null
	is_occupied = false
	$SlotLabel.visible = true
	queue_redraw()
	
	slot_emptied.emit(self)
	EventBus.part_removed.emit(slot_id)
	return removed

func highlight(enable: bool) -> void:
	is_highlighted = enable
	queue_redraw()
