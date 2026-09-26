extends Node

# Envanter Yöneticisi (InventoryManager)
# Kullanıcının sahip olduğu bilgisayar parçalarını yönetir.

var available_parts: Array[Resource] = []

# Parça ekler
func add_part(part: Resource) -> void:
	available_parts.append(part)
	EventBus.inventory_updated.emit()

# Parça çıkarır
func remove_part(part: Resource) -> void:
	if available_parts.has(part):
		available_parts.erase(part)
		EventBus.inventory_updated.emit()

# Belirli bir türdeki parçaları döndürür
func get_parts_by_type(type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for part in available_parts:
		if part is ComponentData and part.part_type == type:
			result.append(part)
	return result
