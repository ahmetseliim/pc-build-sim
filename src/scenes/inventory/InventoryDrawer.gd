class_name InventoryDrawer
extends PanelContainer

# Envanter paneli (HTML sürümündeki .inventory-container)
# Parçaları listeler; anakarta oturmayan parçalar sona geri döner.

@onready var title_label: Label = $VBox/Title
@onready var items: HFlowContainer = $VBox/Items

func _ready() -> void:
	var panel: StyleBoxFlat = UIStyle.box(Color("#2b170e"), 12, 2, Color("#3d2314"), Color(0, 0, 0, 0.4), 10, Vector2(0, 8))
	panel.content_margin_left = 25
	panel.content_margin_right = 25
	panel.content_margin_top = 15
	panel.content_margin_bottom = 20
	add_theme_stylebox_override("panel", panel)

	title_label.add_theme_font_override("font", UIStyle.ui_font(true))
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color("#e2b083"))

	EventBus.part_return_requested.connect(_on_part_return_requested)

	for part: Resource in InventoryManager.available_parts:
		var item: PartItem = PartItem.new()
		item.setup(part as ComponentData)
		items.add_child(item)

func _on_part_return_requested(part: Control) -> void:
	(part as PartItem).return_to(items)
