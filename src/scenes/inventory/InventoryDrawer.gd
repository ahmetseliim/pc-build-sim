class_name InventoryDrawer
extends Control

# Envanter çekmecesi
# Ekranın altından yukarı doğru açılır.
# Parçaları sürükleyip anakart slotlarına bırakmayı sağlar.

@export var drawer_open_y: float = 600.0 ## Açık konumu (Y)
@export var drawer_closed_y: float = 1700.0 ## Kapalı konumu (Y)
@export var animation_duration: float = 0.4 ## Açılıp kapanma süresi

var is_open: bool = false

@onready var item_grid: GridContainer = $Panel/ScrollContainer/ItemGrid
@onready var drawer_handle: Button = $DrawerHandle

func _ready() -> void:
	position.y = drawer_closed_y
	drawer_handle.pressed.connect(_toggle_drawer)
	EventBus.inventory_updated.connect(_refresh_items)
	_refresh_items()

func _toggle_drawer() -> void:
	is_open = !is_open
	var target_y: float = drawer_open_y if is_open else drawer_closed_y
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, animation_duration)

func _refresh_items() -> void:
	# Envanter güncellendiğinde öğeleri yeniden yükle
	for child in item_grid.get_children():
		child.queue_free()
	
	# InventoryManager'dan parçaları al ve slotlara yerleştir
	for part: Resource in InventoryManager.available_parts:
		var slot_scene: PackedScene = preload("res://src/scenes/inventory/InventorySlot.tscn")
		var slot: Control = slot_scene.instantiate()
		item_grid.add_child(slot)
		slot.setup(part as ComponentData)

func open_drawer() -> void:
	if not is_open:
		_toggle_drawer()

func close_drawer() -> void:
	if is_open:
		_toggle_drawer()
