class_name InventorySlot
extends ColorRect

# Envanter slotu
# Sürüklenebilir parça temsili.

var item_data: ComponentData = null

@onready var icon_label: Label = $VBox/IconLabel
@onready var name_label: Label = $VBox/NameLabel

func setup(data: ComponentData) -> void:
	item_data = data
	color = data.bg_color
	
	icon_label.text = data.icon_text
	name_label.text = data.part_name
	
	tooltip_text = data.part_name

# Sürükleme başlatıldığında çağrılır
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item_data:
		return null
	
	# Sürükleme önizlemesi oluştur
	var preview = ColorRect.new()
	preview.color = item_data.bg_color
	preview.custom_minimum_size = Vector2(80, 80)
	
	var v_box = VBoxContainer.new()
	v_box.set_anchors_preset(PRESET_FULL_RECT)
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(v_box)
	
	var lbl_icon = Label.new()
	lbl_icon.text = item_data.icon_text
	lbl_icon.add_theme_font_size_override("font_size", 20)
	lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box.add_child(lbl_icon)
	
	var lbl_name = Label.new()
	lbl_name.text = item_data.part_name
	lbl_name.add_theme_font_size_override("font_size", 10)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box.add_child(lbl_name)
	
	preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(preview)
	
	return {"type": "component", "data": item_data, "source": self}
