extends Node

# Envanter Yöneticisi (InventoryManager)
# Parça kataloğunu tutar ve aktif senaryonun envanterini hazırlar.

var available_parts: Array[Resource] = []

var _ram_count: int = 0

func _ready() -> void:
	setup(GameManager.scenario_inventory)

# Envanteri verilen parça türleriyle yeniden kurar
func setup(types: Array[String]) -> void:
	available_parts.clear()
	_ram_count = 0
	# Tamir dükkânında envanterdekiler yeni yedek parçalardır
	var scenario: ScenarioData = GameManager.current_scenario
	var spares: bool = scenario != null and scenario.shop_stage == 1
	for type: String in types:
		var part: ComponentData = create_part(type)
		part.is_new = spares
		available_parts.append(part)
	EventBus.inventory_updated.emit()

# Katalogdan yeni bir parça verisi üretir (envanter boyutu = yuva boyutu, 1:1)
func create_part(type: String) -> ComponentData:
	match type:
		"cpu":
			return _create(CPUData.new(), "cpu", "İşlemci", Vector2(115, 115))
		"paste":
			return _create(ComponentData.new(), "paste", "Termal Macun", Vector2(60, 40))
		"cloth":
			return _create(ComponentData.new(), "cloth", "Alkollü Bez", Vector2(60, 40))
		"fan":
			return _create(ComponentData.new(), "fan", "CPU Fanı", Vector2(115, 115))
		"ram":
			_ram_count += 1
			return _create(ComponentData.new(), "ram", "RAM %d" % _ram_count, Vector2(42, 130))
		"m2":
			return _create(ComponentData.new(), "m2", "M.2 SSD", Vector2(140, 38))
		"sata":
			return _create(ComponentData.new(), "sata", "SATA SSD", Vector2(140, 95))
		"gpu":
			return _create(GPUData.new(), "gpu", "Ekran Kartı", Vector2(480, 52))
		"psu":
			return _create(ComponentData.new(), "psu", "Güç Kaynağı", Vector2(200, 110))
		# Kablolar (fiş boyutu = konnektör boyutu)
		"atx24":
			return _cable("atx24", "24-PIN", Vector2(28, 84), "#f59e0b", 9.0, "psu_atx", Vector2.DOWN)
		"eps8":
			return _cable("eps8", "CPU 8-PIN", Vector2(48, 24), "#22d3ee", 6.0, "psu_eps", Vector2.RIGHT)
		"pcie8":
			return _cable("pcie8", "PCIe 8-PIN", Vector2(48, 24), "#a855f7", 6.0, "psu_pcie", Vector2.RIGHT)
		"satapwr":
			return _cable("satapwr", "SATA GÜÇ", Vector2(20, 44), "#34d399", 4.5, "psu_sata", Vector2.RIGHT)
		"satadata":
			return _cable("satadata", "SATA VERİ", Vector2(20, 30), "#ef4444", 3.5, "mb_sata", Vector2.RIGHT)
	push_error("Bilinmeyen parça türü: %s" % type)
	return _create(ComponentData.new(), type, type, Vector2(60, 40))

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
