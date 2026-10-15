extends Node

# Oyun durumu yöneticisi (GameManager)
# Aktif senaryoyu, CPU soketinin durumunu, takılı parçaları ve arızaları takip eder.

const MENU_SCENE: String = "res://src/scenes/menu/MainMenu.tscn"
const GAME_SCENE: String = "res://src/scenes/main/Main.tscn"
const DEFAULT_SCENARIO: String = "res://data/scenarios/full_build.tres"
const CABLE_TYPES: Array[String] = ["atx24", "eps8", "pcie8", "satapwr", "satadata"]
## Menüde listelenen senaryolar
const SCENARIOS: Array[String] = [
	"res://data/scenarios/repair_broken_cable.tres",
	"res://data/scenarios/thermal_paste_renewal.tres",
	"res://data/scenarios/faulty_ram.tres",
	"res://data/scenarios/full_build.tres",
]

# Bozuk kabloya göre müşteri şikâyeti (senaryoda şikâyet boşsa kullanılır)
const COMPLAINTS: Dictionary = {
	"atx24": "Bilgisayar hiç açılmıyor. Düğmeye basıyorum, ne fan dönüyor ne ışık yanıyor.",
	"eps8": "Fanlar dönüyor ama ekrana hiçbir şey gelmiyor. İşlemci mi gitti acaba?",
	"pcie8": "Oyun açınca ekran gidiyor, ekran kartını hiç algılamıyor.",
	"satapwr": "Fotoğraflarımın olduğu ikinci disk birden görünmez oldu.",
	"satadata": "Fotoğraflarımın olduğu ikinci disk birden görünmez oldu.",
}

var current_scenario: ScenarioData = null
var scenario_broken: Array[String] = [] ## Bu oturumda bozuk gelen kablolar (rastgele seçim çözülmüş)
var scenario_inventory: Array[String] = [] ## Bu oturumda envantere konan parçalar

var cpu_state: String = "locked_empty" # Durumlar: locked_empty, open, installed, locked_full, painting, paste_applied, screwing_fan, fan_mounted
var installed: Dictionary = {} ## parça türü -> takılı adet
var broken_parts: Array[String] = [] ## Şu an takılı olan bozuk kablo/parça türleri
var faulty_slot_label: String = "" ## Arızalı parçanın takılı olduğu yuva (BIOS mesajı için)
var fan_mounted: bool = false
var paste_old: bool = false ## İşlemcideki macun kurumuş (temizlenip yenilenmeli)
var build_complete: bool = false

func _ready() -> void:
	# EventBus sinyallerine bağlanma
	EventBus.part_installed.connect(_on_part_installed)
	EventBus.part_removed.connect(_on_part_removed)
	EventBus.fan_mounted.connect(_on_fan_mounted)
	EventBus.fan_unmounted.connect(_on_fan_unmounted)
	# Oyun sahnesi doğrudan çalıştırılırsa varsayılan senaryo
	_prepare(load(DEFAULT_SCENARIO))

# Senaryoyu hazırlar ve oyun sahnesine geçer
func start_scenario(scenario: ScenarioData) -> void:
	_prepare(scenario)
	InventoryManager.setup(scenario_inventory)
	get_tree().change_scene_to_file(GAME_SCENE)

func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _prepare(scenario: ScenarioData) -> void:
	reset_build()
	current_scenario = scenario
	scenario_broken = scenario.broken_cables.duplicate()
	if scenario.random_broken_cable:
		var cables: Array[String] = []
		for type: String in scenario.preinstalled_parts:
			if type in CABLE_TYPES:
				cables.append(type)
		if not cables.is_empty():
			scenario_broken.append(cables.pick_random())
	scenario_inventory = scenario.inventory_parts.duplicate()
	if scenario.spare_for_broken:
		scenario_inventory.append_array(scenario_broken)

# Müşterinin şikâyeti
func get_complaint() -> String:
	if current_scenario == null:
		return ""
	if current_scenario.complaint != "":
		return current_scenario.complaint
	for type: String in scenario_broken:
		if COMPLAINTS.has(type):
			return COMPLAINTS[type]
	return "Bilgisayarımda bir sorun var, bakabilir misin?"

# CPU soketinin durumunu değiştirir ve herkese duyurur
func set_cpu_state(state: String) -> void:
	cpu_state = state
	EventBus.cpu_state_changed.emit(state)

# Parça türü takılı ve sağlam mı?
func is_working(type: String) -> bool:
	return installed.get(type, 0) > 0 and not (type in broken_parts)

# Yapıyı sıfırlar
func reset_build() -> void:
	cpu_state = "locked_empty"
	installed.clear()
	broken_parts.clear()
	faulty_slot_label = ""
	fan_mounted = false
	paste_old = false
	build_complete = false

func mark_complete(done: bool) -> void:
	if done and not build_complete:
		build_complete = true
		EventBus.build_complete.emit()
	elif not done:
		build_complete = false

func _on_part_installed(_slot_id: String, part_data: Resource) -> void:
	var type: String = (part_data as ComponentData).part_type
	installed[type] = installed.get(type, 0) + 1

func _on_part_removed(_slot_id: String, part_data: Resource) -> void:
	var type: String = (part_data as ComponentData).part_type
	installed[type] = maxi(0, installed.get(type, 0) - 1)

func _on_fan_mounted() -> void:
	fan_mounted = true
	set_cpu_state("fan_mounted")

func _on_fan_unmounted() -> void:
	fan_mounted = false
	set_cpu_state("paste_old" if paste_old else "paste_applied")
