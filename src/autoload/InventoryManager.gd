extends Node

# Envanter Yöneticisi (InventoryManager)
# Kullanıcının sahip olduğu bilgisayar parçalarını yönetir.

var available_parts: Array[Resource] = []

func _ready() -> void:
	var cpu = preload("res://src/resources/CPUData.gd").new()
	cpu.part_name = "Intel Core i5"
	cpu.part_type = "cpu"
	cpu.bg_color = Color("#9ca3af")
	cpu.icon_text = "⏹️"
	add_part(cpu)
	
	var ram = preload("res://src/resources/ComponentData.gd").new()
	ram.part_name = "Corsair 16GB"
	ram.part_type = "ram"
	ram.bg_color = Color("#0ea5e9")
	ram.icon_text = "📊"
	add_part(ram)
	
	var gpu = preload("res://src/resources/GPUData.gd").new()
	gpu.part_name = "RTX 4060"
	gpu.part_type = "gpu"
	gpu.bg_color = Color("#9333ea")
	gpu.icon_text = "🎮"
	add_part(gpu)
	
	var m2 = preload("res://src/resources/ComponentData.gd").new()
	m2.part_name = "Samsung 1TB"
	m2.part_type = "m2"
	m2.bg_color = Color("#f59e0b")
	m2.icon_text = "💾"
	add_part(m2)
	
	var cmos = preload("res://src/resources/ComponentData.gd").new()
	cmos.part_name = "CR2032 Pil"
	cmos.part_type = "cmos"
	cmos.bg_color = Color("#f8fafc")
	cmos.icon_text = "🪙"
	add_part(cmos)
	
	var power = preload("res://src/resources/ComponentData.gd").new()
	power.part_name = "24-PIN Güç"
	power.part_type = "power"
	power.bg_color = Color("#334155")
	power.icon_text = "🔌"
	add_part(power)

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
