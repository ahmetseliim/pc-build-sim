class_name InventorySlot
extends TextureRect

# Envanter slotu
# Sürüklenebilir parça temsili.

var item_data: ComponentData = null

func setup(data: ComponentData) -> void:
	item_data = data
	if data.texture:
		texture = data.texture
	tooltip_text = data.part_name

# Sürükleme başlatıldığında çağrılır
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item_data:
		return null
	
	# Sürükleme önizlemesi oluştur
	var preview: TextureRect = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(80, 80)
	preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(preview)
	
	return {"type": "component", "data": item_data, "source": self}
