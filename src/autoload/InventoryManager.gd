extends Node

# Envanter Yöneticisi (InventoryManager)
# Parça kataloğunu tutar ve aktif senaryonun envanterini hazırlar.

const PARTS_DIR: String = "res://data/parts/" ## Parça kataloğu: data/parts/<tür>/<id>.tres

## Envanter boyutu = yuva boyutu (1:1). Katalog parçaları da bu ölçüye zorlanır.
const PART_SIZES: Dictionary = {
	"cpu": Vector2(115, 115),
	"paste": Vector2(60, 40),
	"cloth": Vector2(60, 40),
	"fan": Vector2(115, 115),
	"ram": Vector2(42, 130),
	"m2": Vector2(140, 38),
	"sata": Vector2(140, 95),
	"gpu": Vector2(480, 52),
	"psu": Vector2(200, 110),
}

var available_parts: Array[Resource] = []

var _ram_count: int = 0
var _catalog: Dictionary = {} ## id -> ComponentData (paylaşılan örnek; create_part kopyasını verir)

func _ready() -> void:
	_load_parts_catalog()
	setup(GameManager.scenario_inventory)

# data/parts altındaki bütün katalog parçalarını yükler (tür klasörü başına)
func _load_parts_catalog() -> void:
	_catalog.clear()
	for dir: String in DirAccess.get_directories_at(PARTS_DIR):
		for file: String in DirAccess.get_files_at(PARTS_DIR + dir):
			file = file.trim_suffix(".remap")
			if not file.ends_with(".tres"):
				continue
			var part: ComponentData = load(PARTS_DIR + dir + "/" + file) as ComponentData
			if part == null or part.id == "":
				push_warning("Geçersiz katalog parçası: %s/%s" % [dir, file])
			elif _catalog.has(part.id):
				push_warning("Katalogda yinelenen id: %s" % part.id)
			else:
				_catalog[part.id] = part

## Katalogdaki parça kimliği mi?
func has_catalog_part(id: String) -> bool:
	return _catalog.has(id)

## Katalogdaki parçalar (isteğe bağlı tür ve en düşük kademe/raf seviyesi süzgeci); kademe, sonra alış fiyatına göre sıralı
func catalog_parts(type: String = "", max_shelf_level: int = 0) -> Array[ComponentData]:
	var result: Array[ComponentData] = []
	for part: ComponentData in _catalog.values():
		if type != "" and part.part_type != type:
			continue
		if max_shelf_level > 0 and part.min_shelf_level > max_shelf_level:
			continue
		result.append(part)
	result.sort_custom(func(a: ComponentData, b: ComponentData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		return a.buy_price < b.buy_price if a.buy_price != b.buy_price else a.id < b.id)
	return result

# Envanteri verilen parça türleriyle yeniden kurar
func setup(types: Array[String]) -> void:
	available_parts.clear()
	_ram_count = 0
	# Tamir dükkânında envanterdekiler yeni yedek parçalardır
	var scenario: ScenarioData = GameManager.current_scenario
	var spares: bool = scenario != null and scenario.shop_stage == 1 and scenario.inventory_is_new
	var faulty_pending: String = GameManager.scenario_faulty_id
	for type: String in types:
		var part: ComponentData = create_part(type)
		part.is_new = spares
		# Tezgâhta seçilen çıkma parça arızalı geldiyse (bir kez): takılınca BIOS'ta yakalanır
		if faulty_pending != "" and type == faulty_pending:
			part.is_faulty = true
			part.is_new = true
			faulty_pending = ""
		available_parts.append(part)
	EventBus.inventory_updated.emit()

# Yeni bir parça verisi üretir (envanter boyutu = yuva boyutu, 1:1).
# `key` bir katalog kimliği ("ram_ddr4_8_kartal") ya da eski tür adı ("ram", "m2", "gpu", kablo adları) olabilir.
# Eski tür adları değişmemiş genel parçayı verir (marka/fiyat yok): bugünkü senaryolar aynen çalışır.
func create_part(key: String) -> ComponentData:
	if _catalog.has(key):
		return _from_catalog(key)
	var type: String = key
	match type:
		"cpu":
			return _create(CPUData.new(), "cpu", "İşlemci", PART_SIZES["cpu"])
		"paste":
			return _create(ComponentData.new(), "paste", "Termal Macun", PART_SIZES["paste"])
		"cloth":
			return _create(ComponentData.new(), "cloth", "Alkollü Bez", PART_SIZES["cloth"])
		"fan":
			return _create(ComponentData.new(), "fan", "CPU Fanı", PART_SIZES["fan"])
		"ram":
			_ram_count += 1
			return _create(ComponentData.new(), "ram", "RAM %d" % _ram_count, PART_SIZES["ram"])
		"m2":
			return _create(ComponentData.new(), "m2", "M.2 SSD", PART_SIZES["m2"])
		"sata":
			return _create(ComponentData.new(), "sata", "SATA SSD", PART_SIZES["sata"])
		"gpu":
			return _create(GPUData.new(), "gpu", "Ekran Kartı", PART_SIZES["gpu"])
		"psu":
			return _create(ComponentData.new(), "psu", "Güç Kaynağı", PART_SIZES["psu"])
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
		"cpufan":
			# Fanın kendi kablosu: fandan çıkar, anakarttaki CPU_FAN girişine takılır
			return _cable("cpufan", "FAN", Vector2(28, 18), "#38bdf8", 3.0, "fan", Vector2.LEFT)
	push_error("Bilinmeyen parça türü: %s" % type)
	return _create(ComponentData.new(), type, type, Vector2(60, 40))

# Katalog parçasının kopyasını verir (paylaşılan örnek değişmesin: is_new gibi alanlar parçaya özgü)
func _from_catalog(id: String) -> ComponentData:
	var part: ComponentData = (_catalog[id] as ComponentData).duplicate() as ComponentData
	if PART_SIZES.has(part.part_type):
		part.part_size = PART_SIZES[part.part_type]
	return part

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
