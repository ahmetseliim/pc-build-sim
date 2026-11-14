extends Node

# Oyun durumu yöneticisi (GameManager)
# Aktif senaryoyu, CPU soketinin durumunu, takılı parçaları ve arızaları takip eder.

const MENU_SCENE: String = "res://src/scenes/menu/MainMenu.tscn"
const GAME_SCENE: String = "res://src/scenes/main/Main.tscn"
const DEFAULT_SCENARIO: String = "res://data/scenarios/full_build.tres"
const DEFAULT_BOARD: String = "res://data/boards/modern_z790.tres"
const CABLE_TYPES: Array[String] = ["atx24", "eps8", "pcie8", "satapwr", "satadata", "cpufan"]
## Menüde listelenen senaryolar
const SCENARIOS: Array[String] = [
	"res://data/scenarios/repair_broken_cable.tres",
	"res://data/scenarios/thermal_paste_renewal.tres",
	"res://data/scenarios/faulty_ram.tres",
	"res://data/scenarios/dead_ssd.tres",
	"res://data/scenarios/cpu_fan_error.tres",
	"res://data/scenarios/full_build.tres",
	"res://data/scenarios/ram_upgrade.tres",
	"res://data/scenarios/loose_part.tres",
	"res://data/scenarios/second_disk.tres",
	"res://data/scenarios/nvme_upgrade.tres",
	"res://data/scenarios/psu_swap.tres",
	"res://data/scenarios/gpu_swap.tres",
	"res://data/scenarios/revive_old_pc.tres",
]

# Bozuk kabloya göre müşteri şikâyetleri (senaryoda şikâyet yoksa kullanılır; biri rastgele seçilir)
const COMPLAINTS: Dictionary = {
	"atx24": [
		"Bilgisayar hiç açılmıyor. Düğmeye basıyorum, ne fan dönüyor ne ışık yanıyor.",
		"Dün akşam kapattım, bugün düğmeye bastım, hiçbir tepki yok. Prize bağlı, ışık bile yanmıyor.",
		"Bilgisayar sapasağlam duruyordu ama şimdi tamamen ölü gibi. Ne ses var ne ışık.",
	],
	"eps8": [
		"Fanlar dönüyor ama ekrana hiçbir şey gelmiyor. İşlemci mi gitti acaba?",
		"Düğmeye basınca fanlar dönüp duruyor, ekran ise simsiyah kalıyor.",
		"Açılıyor gibi oluyor ama ekrana bir görüntü gelmiyor, klavye ışığı da yanmıyor.",
	],
	"pcie8": [
		"Oyun açınca ekran gidiyor, ekran kartını hiç algılamıyor.",
		"Ekran kartının fanları dönmüyor, oyunlarda görüntü bir anda karardı.",
		"Ekran kartım artık yokmuş gibi davranıyor, bilgisayar onu hiç görmüyor.",
	],
	"satapwr": [
		"Fotoğraflarımın olduğu ikinci disk birden görünmez oldu.",
		"İkinci diskim Bilgisayarım'da yok, dün gece hâlâ oradaydı.",
		"Arşiv diskimi bilgisayar artık hiç görmüyor, içinde yıllarca fotoğrafım var.",
	],
	"satadata": [
		"Fotoğraflarımın olduğu ikinci disk birden görünmez oldu.",
		"İkinci diskim Bilgisayarım'da yok, dün gece hâlâ oradaydı.",
		"Arşiv diskimi bilgisayar artık hiç görmüyor, içinde yıllarca fotoğrafım var.",
	],
	"cpufan": [
		"Açılışta 'CPU Fan Error' diye bir uyarı çıkıyor, bilgisayar da çok ısınıp kapanıyor.",
		"Her açılışta F1'e basmamı isteyen bir fan uyarısı çıkıyor, makine de çok ısınıyor.",
		"İşlemci fanı hatası veriyor, bilgisayar biraz çalışınca ısınıp kendini kapatıyor.",
	],
}

var current_scenario: ScenarioData = null
var current_board: BoardData = null ## Bu işte gelen bilgisayarın anakartı
var board_slot_types: Array[String] = [] ## Yüklü anakartta bulunan yuva türleri
var scenario_broken: Array[String] = [] ## Bu oturumda bozuk gelen kablolar (rastgele seçim çözülmüş)
var scenario_inventory: Array[String] = [] ## Bu oturumda envantere konan parçalar
## Bu işte yerinden çıkmış gelen parça/kablo türleri (ScenarioData.loose_parts'tan seçilir): takılı gelmez, envanterdedir
var scenario_loose: Array[String] = []
var _complaint_roll: int = 0 ## Şikâyet listesinden hangisinin seçileceği (iş hazırlanırken bir kez atılır: tezgâh ve iş emri aynı metni gösterir)
## Tezgâh teklifinde seçilen çıkma parça tedarikçiden arızalı geldiyse onun katalog kimliği (InventoryManager.setup bu parçayı arızalı işaretler)
var scenario_faulty_id: String = ""
## İş hazırlanınca çağrılır (CareerManager: tezgâhta seçilen teklif parçasını ve kartı işe uygular). GameManager kariyeri tanımaz.
var job_hook: Callable = Callable()

var cpu_state: String = "locked_empty" # Durumlar: locked_empty, open, installed, locked_full, painting, paste_applied, screwing_fan, fan_mounted
var installed: Dictionary = {} ## parça türü -> takılı adet
var broken_parts: Array[String] = [] ## Şu an takılı olan bozuk kablo/parça türleri
var faulty_slot_label: String = "" ## Arızalı parçanın takılı olduğu yuva (BIOS mesajı için)
var fan_mounted: bool = false
var paste_old: bool = false ## İşlemcideki macun kurumuş (temizlenip yenilenmeli)
var m2_secured: bool = true ## M.2 SSD vidasıyla sabitlendi mi (vidalı senaryolarda)
var build_complete: bool = false
var random_cable_pick: String = "" ## Tezgâhta seçilen rastgele bozuk kablo
var _job_prepared: bool = false

func _ready() -> void:
	UIStyle.setup_window(get_window())
	get_tree().quit_on_go_back = false
	# EventBus sinyallerine bağlanma
	EventBus.part_installed.connect(_on_part_installed)
	EventBus.part_removed.connect(_on_part_removed)
	EventBus.fan_mounted.connect(_on_fan_mounted)
	EventBus.fan_unmounted.connect(_on_fan_unmounted)
	# Oyun sahnesi doğrudan çalıştırılırsa varsayılan senaryo
	_prepare(load(DEFAULT_SCENARIO))

# Senaryoyu hazırlar ve oyun sahnesine geçer
func start_scenario(scenario: ScenarioData) -> void:
	if not (_job_prepared and current_scenario == scenario):
		_prepare(scenario)
	_job_prepared = false
	InventoryManager.setup(scenario_inventory)
	get_tree().change_scene_to_file(GAME_SCENE)

func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# Android geri tuşu: menüde oyundan çıkar, başka ekranda menüye döner
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var scene: Node = get_tree().current_scene
	if scene and scene.scene_file_path == MENU_SCENE:
		get_tree().quit()
	else:
		go_to_menu()

# Müşteri tezgâha gelince işi önceden belirler: anlattığı şikâyet ile atölyedeki arıza aynı olur
func prepare_job(scenario: ScenarioData) -> void:
	_prepare(scenario)
	_job_prepared = true
	board_slot_types = slot_types_of(current_board)
	if not scenario.random_broken_cable:
		return
	var candidates: Array[String] = []
	for type: String in scenario.preinstalled_parts:
		if type in CABLE_TYPES and type in board_slot_types and not type in candidates:
			candidates.append(type)
	if not candidates.is_empty():
		random_cable_pick = candidates.pick_random()
		scenario_broken.append(random_cable_pick)

# Anakart sahnesindeki yuva türleri
func slot_types_of(board: BoardData) -> Array[String]:
	var types: Array[String] = []
	var scene: PackedScene = load(board.scene_path)
	var root: Node = scene.instantiate()
	for child: Node in root.get_node("Slots").get_children():
		if child is MotherboardSlot and not (child as MotherboardSlot).accepted_type in types:
			types.append((child as MotherboardSlot).accepted_type)
	root.free()
	return types

func _prepare(scenario: ScenarioData) -> void:
	reset_build()
	random_cable_pick = ""
	current_scenario = scenario
	# Bu işte gelen bilgisayarın anakartı (uygun olanlardan rastgele)
	var board_path: String = DEFAULT_BOARD if scenario.board_paths.is_empty() else scenario.board_paths.pick_random()
	current_board = load(board_path)
	# Rastgele bozuk kablo anakart yüklenince seçilir (kartta olmayan kablo seçilmesin diye)
	scenario_broken = scenario.broken_cables.duplicate()
	scenario_inventory = scenario.inventory_parts.duplicate()
	if scenario.spare_for_broken:
		scenario_inventory.append_array(scenario_broken)
	scenario_faulty_id = ""
	_complaint_roll = randi()
	_pick_loose_parts(scenario)
	if job_hook.is_valid():
		job_hook.call()

# Yerinden çıkmış gelecek parçaları seçer: seçilenler envantere konur, atölyede takılı gelmez (Motherboard._preinstall_scenario_parts).
# Yalnız hazır takılı listesinde geçen ve bu kartta yuvası olan türler adaydır.
func _pick_loose_parts(scenario: ScenarioData) -> void:
	scenario_loose.clear()
	if scenario.loose_parts.is_empty():
		return
	var slot_types: Array[String] = slot_types_of(current_board)
	var pool: Array[String] = []
	for type: String in scenario.loose_parts:
		if type in scenario.preinstalled_parts and type in slot_types and not type in pool:
			pool.append(type)
	pool.shuffle()
	var count: int = pool.size() if scenario.loose_count <= 0 else mini(scenario.loose_count, pool.size())
	for i: int in range(count):
		scenario_loose.append(pool[i])
		scenario_inventory.append(pool[i])

# Müşterinin şikâyeti: senaryonun şikâyet listesinden (iş hazırlanırken atılan zarla) biri, yoksa tek şikâyet metni, yoksa bozuk kabloya göre
func get_complaint() -> String:
	if current_scenario == null:
		return ""
	if not current_scenario.complaints.is_empty():
		return current_scenario.complaints[_complaint_roll % current_scenario.complaints.size()]
	if current_scenario.complaint != "":
		return current_scenario.complaint
	for type: String in scenario_broken:
		# M.2'siz eski kartta SATA disk sistem diskidir
		if type in ["satapwr", "satadata"] and not board_has("m2"):
			return "Bilgisayar açılıyor ama Windows gelmiyor, ekranda disk bulunamadı yazıyor."
		if COMPLAINTS.has(type):
			var lines: Array = COMPLAINTS[type]
			return lines[_complaint_roll % lines.size()]
	return "Bilgisayarımda bir sorun var, bakabilir misin?"

# NVMe yükseltmede eski SATA disk sökülebilir parçadır: yuvası boş kalsa da bilgisayar tamam sayılır, BIOS da SATA aramaz
func sata_is_optional() -> bool:
	return current_scenario != null and "sata" in current_scenario.removable_parts and current_scenario.faulty_part != "sata"

# Yüklü anakartta bu türden yuva var mı?
func board_has(type: String) -> bool:
	return type in board_slot_types

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
	m2_secured = true
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
