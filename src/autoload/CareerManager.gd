extends Node

# Kariyer Yöneticisi (CareerManager)
# Dükkânın parasını, itibarını (yıldız), gün düzenini ve kaydı yönetir.
# Her gün sırayla müşteriler (tamir işleri) gelir: müşteri kapıdan girip tezgâha
# yürür ve arızayı anlatır, sonra atölyeye geçilir. İş bitince ücret hatalara göre
# hesaplanır, müşteri tezgâhta yorumunu ve ödemesini yapıp çıkar; oyun otomatik kaydedilir.

const SAVE_PATH: String = "user://kariyer.json"
const RESULT_SCENE: String = "res://src/scenes/ui/ResultScreen.tscn" ## Gün sonu özeti
const COUNTER_SCENE: String = "res://src/scenes/counter/Counter.tscn"
const CUSTOMERS_DIR: String = "res://data/customers/"

const MISTAKE_PENALTY: float = 0.10 ## Her hata ücretten %10 keser
const MIN_PAY_RATIO: float = 0.5 ## Ücretin en az yarısı ödenir
const MAX_STARS: int = 5

# Hata türleri ve sonuç ekranındaki adları
const MISTAKE_NAMES: Dictionary = {
	"paste_spill": "Macun taştı",
	"healthy_removed": "Sağlam parça söküldü",
	"extra_boot": "Gereksiz BIOS denemesi",
	"sequence": "Sıra hatası",
}

const FAN: String = "res://data/scenarios/cpu_fan_error.tres"
const CABLE: String = "res://data/scenarios/repair_broken_cable.tres"
const RAM: String = "res://data/scenarios/faulty_ram.tres"
const PASTE: String = "res://data/scenarios/thermal_paste_renewal.tres"
const SSD: String = "res://data/scenarios/dead_ssd.tres"

## İlk günler planlıdır: her yeni iş türü ilk kez gelir, sonra tekrar edilir
const PLANNED_DAYS: Array = [
	[FAN, CABLE],
	[RAM, CABLE, FAN],
	[PASTE, SSD, RAM],
]
## Planlı günlerden sonra rastgele seçilen tamir işleri
const CAREER_POOL: Array[String] = [FAN, CABLE, RAM, PASTE, SSD]

var is_career: bool = false ## false: test listesinden açılan tek iş (para/kayıt etkilenmez)
var job_active: bool = false

# Kalıcı ilerleme
var money: int = 0
var day: int = 1
var job_index: int = 0 ## Günün kaçıncı müşterisi (0'dan)
var day_queue: Array[String] = []
var day_customers: Array[String] = [] ## day_queue'daki her işi getiren müşteri (data/customers/*.tres)
var jobs_done: int = 0
var star_total: int = 0
var day_earned: int = 0
var day_star_total: int = 0
var day_jobs: int = 0

# Aktif işin takibi
var mistakes: Dictionary = {} ## hata türü -> adet
var failed_boots: int = 0
var last_result: Dictionary = {}
## Tezgâh sahnesi açılınca ne olacak: "arrive" (sıradaki müşteri gelir) / "farewell" (biten işin müşterisi ödeyip gider)
var counter_mode: String = "arrive"

func _ready() -> void:
	EventBus.warning_requested.connect(func(_m: String) -> void: record_mistake("sequence"))
	EventBus.paste_failed.connect(func() -> void: record_mistake("paste_spill"))
	EventBus.mistake_made.connect(record_mistake)
	EventBus.boot_failed.connect(_on_boot_failed)

# --- Kariyer akışı -----------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	money = 0
	day = 1
	jobs_done = 0
	star_total = 0
	_begin_day()
	save_game()
	start_current_job()

func continue_game() -> void:
	if not load_game():
		new_game()
		return
	if job_index >= day_queue.size():
		start_next_day()
	else:
		start_current_job()

# Sıradaki müşteri tezgâha gelir (arızayı anlatınca atölyeye geçilir)
func start_current_job() -> void:
	is_career = true
	counter_mode = "arrive"
	get_tree().change_scene_to_file(COUNTER_SCENE)

# Tezgâhta arıza dinlendi: bilgisayar atölyeye alınır
func enter_workshop() -> void:
	is_career = true
	_reset_job()
	GameManager.start_scenario(load(day_queue[job_index]))

func show_day_summary() -> void:
	get_tree().change_scene_to_file(RESULT_SCENE)

func current_scenario() -> ScenarioData:
	return load(day_queue[job_index]) if job_index < day_queue.size() else null

func customer_at(index: int) -> CustomerData:
	if index < 0 or index >= day_customers.size():
		return null
	return load(day_customers[index])

func current_customer() -> CustomerData:
	return customer_at(job_index)

# Test listesinden tek bir iş (kariyeri etkilemez)
func start_test(scenario: ScenarioData) -> void:
	is_career = false
	_reset_job()
	GameManager.start_scenario(scenario)

func start_next_day() -> void:
	day += 1
	_begin_day()
	save_game()
	start_current_job()

# BIOS başarılı: ücreti hesapla, kaydet ve tezgâha dön (müşteri ödeyip gider)
func finish_job() -> void:
	job_active = false
	var scenario: ScenarioData = GameManager.current_scenario
	var mistake_count: int = total_mistakes()
	var price: int = scenario.price
	var ratio: float = maxf(MIN_PAY_RATIO, 1.0 - MISTAKE_PENALTY * mistake_count)
	var pay: int = int(round(price * ratio))
	var stars: int = maxi(1, MAX_STARS - mistake_count)
	money += pay
	jobs_done += 1
	star_total += stars
	day_earned += pay
	day_star_total += stars
	day_jobs += 1
	var customer: CustomerData = current_customer()
	last_result = {
		"title": scenario.title, "customer": customer.display_name if customer else scenario.customer,
		"customer_index": job_index,
		"price": price, "pay": pay, "stars": stars, "mistakes": mistakes.duplicate(),
		"day_done": job_index + 1 >= day_queue.size(),
	}
	job_index += 1
	save_game()
	EventBus.career_updated.emit()
	counter_mode = "farewell"
	get_tree().change_scene_to_file(COUNTER_SCENE)

# --- Hatalar -----------------------------------------------------------------

func record_mistake(kind: String) -> void:
	if not job_active:
		return
	mistakes[kind] = mistakes.get(kind, 0) + 1
	EventBus.career_updated.emit()

func total_mistakes() -> int:
	var n: int = 0
	for kind: String in mistakes:
		n += mistakes[kind]
	return n

# İlk başarısız BIOS denemesi teşhistir; sonrakiler (arıza giderilmeden) hata sayılır
func _on_boot_failed() -> void:
	failed_boots += 1
	if failed_boots > 1:
		record_mistake("extra_boot")

# --- Yardımcılar -------------------------------------------------------------

func average_stars() -> float:
	return float(star_total) / float(jobs_done) if jobs_done > 0 else 0.0

func customers_today() -> int:
	return day_queue.size()

func _reset_job() -> void:
	mistakes.clear()
	failed_boots = 0
	job_active = true

func _begin_day() -> void:
	job_index = 0
	day_earned = 0
	day_star_total = 0
	day_jobs = 0
	day_queue.clear()
	if day <= PLANNED_DAYS.size():
		for path: String in PLANNED_DAYS[day - 1]:
			day_queue.append(path)
		_assign_customers()
		return
	var count: int = 3 if day < 5 else 4
	var last: String = ""
	for i: int in range(count):
		var options: Array = CAREER_POOL.filter(func(p: String) -> bool: return p != last)
		last = options.pick_random()
		day_queue.append(last)
	_assign_customers()

# Günün her işine farklı bir müşteri karakteri atanır
func _assign_customers() -> void:
	day_customers.clear()
	var pool: Array[String] = []
	for file: String in DirAccess.get_files_at(CUSTOMERS_DIR):
		# Dışa aktarılmış oyunda dosyalar ".remap" uzantılı listelenir
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			pool.append(CUSTOMERS_DIR + file)
	pool.shuffle()
	for i: int in range(day_queue.size()):
		day_customers.append(pool[i % pool.size()])

# --- Kayıt -------------------------------------------------------------------

func save_game() -> void:
	var data: Dictionary = {
		"money": money, "day": day, "job_index": job_index, "day_queue": day_queue,
		"day_customers": day_customers,
		"jobs_done": jobs_done, "star_total": star_total,
		"day_earned": day_earned, "day_star_total": day_star_total, "day_jobs": day_jobs,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	money = int(data.get("money", 0))
	day = int(data.get("day", 1))
	job_index = int(data.get("job_index", 0))
	day_queue.clear()
	for path: Variant in data.get("day_queue", []):
		day_queue.append(str(path))
	day_customers.clear()
	for path: Variant in data.get("day_customers", []):
		if ResourceLoader.exists(str(path)):
			day_customers.append(str(path))
	if day_customers.size() != day_queue.size():
		_assign_customers()
	jobs_done = int(data.get("jobs_done", 0))
	star_total = int(data.get("star_total", 0))
	day_earned = int(data.get("day_earned", 0))
	day_star_total = int(data.get("day_star_total", 0))
	day_jobs = int(data.get("day_jobs", 0))
	if day_queue.is_empty():
		_begin_day()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
