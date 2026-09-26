class_name Motherboard
extends Node2D

# Anakart yöneticisi
# Slotları ve parça yerleştirme mantığını yönetir.

# Slot referansları - sahnede oluşturulacak
var slots: Array[Node] = []

func _ready() -> void:
	# Tüm alt slot düğümlerini topla
	for child in get_children():
		if child is Area2D:
			slots.append(child)
	
	# EventBus bağlantıları
	EventBus.part_installed.connect(_on_part_installed)

func _on_part_installed(slot_id: String, part_data: Resource) -> void:
	print("%s slotuna parça yerleştirildi: %s" % [slot_id, part_data])
