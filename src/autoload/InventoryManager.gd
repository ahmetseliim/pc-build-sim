extends Node

# Envanter Yöneticisi (InventoryManager)
# Kullanıcının sahip olduğu bilgisayar parçalarını ve kabloları yönetir.

var available_parts: Array[Resource] = []

func _ready() -> void:
	# Parçalar (envanterdeki boyut = anakarttaki yuva boyutu)
	add_part(_create(CPUData.new(), "cpu", "İşlemci", Vector2(115, 115)))
	add_part(_create(ComponentData.new(), "paste", "Termal Macun", Vector2(60, 40)))
	add_part(_create(ComponentData.new(), "fan", "CPU Fanı", Vector2(115, 115)))
	add_part(_create(ComponentData.new(), "ram", "RAM 1", Vector2(42, 130)))
	add_part(_create(ComponentData.new(), "ram", "RAM 2", Vector2(42, 130)))
	add_part(_create(ComponentData.new(), "m2", "M.2 SSD", Vector2(140, 38)))
	add_part(_create(ComponentData.new(), "sata", "SATA SSD", Vector2(140, 95)))

	# Kablolar (fiş boyutu = konnektör boyutu)
	add_part(_cable("atx24", "24-PIN", Vector2(28, 84), "#f59e0b", 9.0, "psu_atx", Vector2.DOWN))
	add_part(_cable("eps8", "CPU 8-PIN", Vector2(48, 24), "#22d3ee", 6.0, "psu_eps", Vector2.RIGHT))
	add_part(_cable("pcie8", "PCIe 8-PIN", Vector2(48, 24), "#a855f7", 6.0, "psu_pcie", Vector2.RIGHT))
	add_part(_cable("satapwr", "SATA GÜÇ", Vector2(20, 44), "#34d399", 4.5, "psu_sata", Vector2.RIGHT))
	add_part(_cable("satadata", "SATA VERİ", Vector2(20, 30), "#ef4444", 3.5, "mb_sata", Vector2.RIGHT))

	add_part(_create(GPUData.new(), "gpu", "Ekran Kartı", Vector2(480, 52)))
	add_part(_create(ComponentData.new(), "psu", "Güç Kaynağı", Vector2(200, 110)))

func _create(part: ComponentData, type: String, display_name: String, part_size: Vector2) -> ComponentData:
	part.part_type = type
	part.part_name = display_name
	part.part_size = part_size
	return part

func _cable(type: String, display_name: String, part_size: Vector2, color: String, width: float, from: String, entry: Vector2) -> ComponentData:
	var cable: ComponentData = _create(ComponentData.new(), type, display_name, part_size)
	cable.is_cable = true
	cable.cable_color = Color(color)
	cable.cable_width = width
	cable.cable_from = from
	cable.cable_entry = entry
	return cable

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
