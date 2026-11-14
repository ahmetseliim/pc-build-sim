extends Node

# Kariyer Yöneticisi (CareerManager)
# Dükkânın parasını, itibarını (yıldız), gün düzenini ve kaydı yönetir.
# Her gün sırayla müşteriler (tamir işleri) gelir: müşteri kapıdan girip tezgâha
# yürür ve arızayı anlatır, sonra atölyeye geçilir. İş bitince ücret hatalara göre
# hesaplanır, müşteri tezgâhta yorumunu ve ödemesini yapıp çıkar; oyun otomatik kaydedilir.
#
# Para gün sonu mağazasında harcanır (Good Pizza, Great Pizza mantığı): raf yeni iş
# türü açar, alet işi kolaylaştırır, dekor bahşiş getirir. Kira yoktur; rafı olmayan
# işin müşterisi gider ve gün sonunda "kaçan kazanç" olarak görünür.

const SAVE_PATH: String = "user://kariyer.json"
const SAVE_VERSION: int = 5 ## 5: tezgâh parça teklifi (offer, day_part_sales, day_part_cost); 3 ve 4 numaralı kayıtlar .get varsayılanlarıyla açılır
const RESULT_SCENE: String = "res://src/scenes/ui/ResultScreen.tscn" ## Gün sonu özeti
const COUNTER_SCENE: String = "res://src/scenes/counter/Counter.tscn"
const CUSTOMERS_DIR: String = "res://data/customers/"
const UPGRADES_DIR: String = "res://data/upgrades/"

const MISTAKE_PENALTY: float = 0.10 ## Her hata ücretten %10 keser
const MIN_PAY_RATIO: float = 0.5 ## Ücretin en az yarısı ödenir
const MAX_STARS: int = 5
## Yıldıza göre bahşiş (iş ücretinin oranı); 3 yıldızın altı bahşiş bırakmaz
const TIP_RATES: Dictionary = {5: 0.15, 4: 0.08, 3: 0.03}
const TEA_TIP_BONUS: float = 0.10 ## Çay ocağı: memnun müşteriye ek bahşiş
const SCREWDRIVER_SPEED: float = 1.4 ## Cırcır tornavida: vida hızı çarpanı
const LOCKED_JOB_CHANCE: float = 0.5 ## Planlı günlerden sonra günde bir "rafı olmayan" müşterinin gelme ihtimali

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
var day_tips: int = 0 ## Bugün alınan bahşiş (day_earned'e dahil)
var day_missed: int = 0 ## Rafı olmadığı için bugün geri gönderilen müşteri
var day_lost: int = 0 ## Geri gönderilen müşterilerin işlerinin ücreti
var day_part_sales: int = 0 ## Bugün müşteriye satılan parçaların satış bedeli (day_earned'e dahil)
var day_part_cost: int = 0 ## Bugün tedarikçiye ödenen parça alış bedeli (kasadan alım anında düşer)
var day_missed_needs: Array[String] = [] ## Bugün eksik kalan alımların id'leri (mağazada vurgulanır)
var owned_upgrades: Array[String] = [] ## Satın alınan dükkân alımlarının id'leri

var _catalog: Array[UpgradeData] = []

# Aktif işin takibi
var mistakes: Dictionary = {} ## hata türü -> adet
var failed_boots: int = 0
var last_result: Dictionary = {}
## Aktif işte tezgâhta seçilen parça teklifi (boşsa teklif yapılmadı). Anahtarlar: part_id, label, tier, used, buy, sell, labor, total,
## outcome, mood, tip_bonus, tip_mult, faulty (tedarikçiden arızalı geldi), replaced (arıza yüzünden yeniden alındı),
## reorder_cost, board (bu işin anakartı: menüye çıkıp dönünce aynı kart gelsin), budget, budget_type. Kayda yazılır.
var offer: Dictionary = {}
## Tezgâh sahnesi açılınca ne olacak: "arrive" (sıradaki müşteri gelir) / "farewell" (biten işin müşterisi ödeyip gider)
var counter_mode: String = "arrive"

func _ready() -> void:
	EventBus.paste_failed.connect(func() -> void: record_mistake("paste_spill"))
	EventBus.mistake_made.connect(record_mistake)
	EventBus.boot_failed.connect(_on_boot_failed)
	_load_catalog()
	GameManager.job_hook = _apply_offer_to_job

# --- Kariyer akışı -----------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	money = 0
	day = 1
	jobs_done = 0
	star_total = 0
	owned_upgrades.clear()
	_clear_job()
	_begin_day()
	save_game()
	start_current_job()

func continue_game() -> void:
	if not load_game():
		new_game()
		return
	if job_index >= day_queue.size():
		# Günün son müşterisinden sonra çıkıldıysa özet atlanmasın
		show_day_summary()
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
	# Arıza yeniden belirlendiği için ilk BIOS yine teşhistir; ama yarım kalan işin hataları silinmez
	failed_boots = 0
	if not job_active:
		mistakes.clear()
		job_active = true
	save_game()
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
	# Hata cezası yalnız işçilik ücretine uygulanır; parça satış bedeli kesilmez
	var price: int = scenario.price
	var ratio: float = maxf(MIN_PAY_RATIO, 1.0 - MISTAKE_PENALTY * mistake_count)
	var pay: int = int(round(price * ratio))
	var stars: int = maxi(1, MAX_STARS - mistake_count)
	var tip: int = tip_for(price, stars, float(offer.get("tip_bonus", 0.0)), float(offer.get("tip_mult", 1.0)))
	var part_sell: int = int(offer.get("sell", 0))
	# Parçanın alış fiyatı seçim anında kasadan düşmüştü (yeniden alınan parça dahil)
	var part_cost: int = int(offer.get("buy", 0)) + int(offer.get("reorder_cost", 0))
	var paid: int = pay + part_sell + tip
	money += paid
	jobs_done += 1
	star_total += stars
	day_earned += paid
	day_part_sales += part_sell
	day_tips += tip
	day_star_total += stars
	day_jobs += 1
	var customer: CustomerData = current_customer()
	last_result = {
		"title": scenario.title, "customer": customer.display_name if customer else scenario.customer,
		"customer_index": job_index,
		"price": price, "pay": pay, "tip": tip, "stars": stars, "mistakes": mistakes.duplicate(),
		"part_label": str(offer.get("label", "")), "part_sell": part_sell, "part_cost": part_cost,
		"paid": paid, "offer_outcome": str(offer.get("outcome", "")),
		"day_done": job_index + 1 >= day_queue.size(),
	}
	job_index += 1
	_clear_job()
	save_game()
	EventBus.career_updated.emit()
	counter_mode = "farewell"
	get_tree().change_scene_to_file(COUNTER_SCENE)

# Yıldıza göre bahşiş; çay ocağı memnun müşterinin bahşişini artırır
# `bonus`: müşterinin parça seçimine sevinince eklenen oran, `mult`: tepkiye göre bahşiş çarpanı (PartOffer.judge)
func tip_for(price: int, stars: int, bonus: float = 0.0, mult: float = 1.0) -> int:
	var rate: float = TIP_RATES.get(stars, 0.0)
	if stars >= 3:
		rate += bonus
		if effect_active("cay_ocagi"):
			rate += TEA_TIP_BONUS
	return int(round(price * rate * mult))

# Sıradaki işin gerektirdiği alım eksik mi (rafta parça yok)
func current_job_missing() -> UpgradeData:
	var scenario: ScenarioData = current_scenario()
	if scenario == null or scenario.required_upgrade == "" or has_upgrade(scenario.required_upgrade):
		return null
	return get_upgrade(scenario.required_upgrade)

# Rafta parça yok: müşteri geri gönderilir, işin ücreti "kaçan kazanç" olur.
# Tezgâh sahnesi müşteriyi kapıya yürütür; sıradakiler ilerler. Gün bittiyse true döner.
# `lost`: kaçan kazanç (bütçe yüzünden giden müşteride teklifin toplamı); verilmezse işin işçilik ücreti
func turn_away_current(lost: int = -1) -> bool:
	var scenario: ScenarioData = current_scenario()
	if scenario == null:
		return true
	day_missed += 1
	day_lost += scenario.price if lost < 0 else lost
	if scenario.required_upgrade != "" and not day_missed_needs.has(scenario.required_upgrade):
		day_missed_needs.append(scenario.required_upgrade)
	job_index += 1
	_clear_job()
	save_game()
	EventBus.career_updated.emit()
	return job_index >= day_queue.size()

# --- Tezgâhta parça teklifi --------------------------------------------------

# Bu işte (kariyerde) tezgâhta parça seçilmesi gerekiyor mu? Seçim yapıldıysa ya da senaryoda teklif yoksa false.
func needs_offer() -> bool:
	var scenario: ScenarioData = current_scenario()
	return is_career and scenario != null and scenario.offer_part_type != "" and scenario.base_budget > 0 \
		and offer.is_empty() and not offer_options().is_empty()

func offer_budget_type() -> String:
	var customer: CustomerData = current_customer()
	return customer.budget_type if customer else "orta"

# Sıradaki müşterinin söylediği bütçe (₺); senaryoda teklif yoksa 0
func offer_budget() -> int:
	return PartOffer.budget_for(current_scenario(), offer_budget_type())

# Teklif kartındaki seçenekler (gelen anakarta uyan parçalar)
func offer_options() -> Array[Dictionary]:
	return PartOffer.options(current_scenario(), GameManager.current_board)

# Seçeneğin kasadan alınamama nedeni (alınabiliyorsa boş)
func offer_block_reason(option: Dictionary) -> String:
	if money < int(option["buy"]):
		return "Kasada %d ₺ eksik" % (int(option["buy"]) - money)
	return ""

# Oyuncu teklif kartından bir parça seçti. Dönüş: judge() sonucu + "ok" (kabul edildi), "part_id", "total".
# Müşteri bütçesini çok aşarsa gider: para ve durum değişmez, Counter turn_away_current(total) çağırır.
# Kabul edilirse alış fiyatı kasadan hemen düşer, parça işin envanterine yeni parça olarak konur, durum kaydedilir.
# `roll`: çıkma parçanın arızalı gelme zarı (0-1, FAULTY_CHANCE'ten küçükse arızalı); verilmezse rastgele.
func choose_part(part_id: String, roll: float = -1.0) -> Dictionary:
	var chosen: Dictionary = {}
	for option: Dictionary in offer_options():
		if option["id"] == part_id:
			chosen = option
	if chosen.is_empty() or not offer.is_empty():
		return {"ok": false, "reason": "geçersiz seçim"}
	var budget: int = offer_budget()
	var budget_type: String = offer_budget_type()
	var verdict: Dictionary = PartOffer.judge(chosen, budget, budget_type)
	verdict["part_id"] = part_id
	verdict["total"] = int(chosen["total"])
	verdict["ok"] = not verdict["leaves"]
	if verdict["leaves"]:
		return verdict
	var reason: String = offer_block_reason(chosen)
	if reason != "":
		verdict["ok"] = false
		verdict["reason"] = reason
		return verdict
	var faulty: bool = bool(chosen["used"]) and (roll if roll >= 0.0 else randf()) < PartOffer.FAULTY_CHANCE
	money -= int(chosen["buy"])
	day_part_cost += int(chosen["buy"])
	offer = {
		"part_id": part_id, "label": chosen["label"], "tier": int(chosen["tier"]), "used": bool(chosen["used"]),
		"buy": int(chosen["buy"]), "sell": int(chosen["sell"]), "labor": int(chosen["labor"]), "total": int(chosen["total"]),
		"outcome": verdict["outcome"], "mood": verdict["mood"],
		"tip_bonus": verdict["tip_bonus"], "tip_mult": verdict["tip_mult"],
		"faulty": faulty, "replaced": false, "reorder_cost": 0,
		"board": GameManager.current_board.resource_path if GameManager.current_board else "",
		"budget": budget, "budget_type": budget_type,
	}
	_apply_offer_to_job()
	save_game()
	EventBus.career_updated.emit()
	return verdict

# Seçilen parçayı işe uygular: envanterdeki aynı türdeki genel parçanın yerine katalog parçası konur,
# iş aynı anakartla açılır (menüye çıkıp dönünce kart değişmesin), çıkma parça arızalıysa işaretlenir.
# GameManager._prepare her iş hazırlanışında çağırır (job_hook).
func _apply_offer_to_job() -> void:
	if not is_career or offer.is_empty():
		return
	var scenario: ScenarioData = GameManager.current_scenario
	if scenario == null or scenario != current_scenario() or scenario.offer_part_type == "":
		return
	var board_path: String = str(offer.get("board", ""))
	if board_path != "" and ResourceLoader.exists(board_path):
		GameManager.current_board = load(board_path)
	var part_id: String = str(offer.get("part_id", ""))
	var index: int = GameManager.scenario_inventory.find(scenario.offer_part_type)
	if index >= 0:
		GameManager.scenario_inventory[index] = part_id
	elif not GameManager.scenario_inventory.has(part_id):
		GameManager.scenario_inventory.append(part_id)
	GameManager.scenario_faulty_id = part_id if bool(offer.get("faulty", false)) and not bool(offer.get("replaced", false)) else ""

# Tedarikçiden arızalı gelen çıkma parça BIOS'ta yakalanıp sökülünce çağrılır: sağlam bir eşi
# kasadan yeniden alınır (alış fiyatı bir kez daha düşer) ve envantere yeni parça olarak konur. Bir kez.
func replace_faulty_part(part: ComponentData) -> void:
	if offer.is_empty() or bool(offer.get("replaced", false)) or part.id != str(offer.get("part_id", "")):
		return
	offer["replaced"] = true
	var cost: int = int(offer.get("buy", 0))
	offer["reorder_cost"] = cost
	money -= cost
	day_part_cost += cost
	var spare: ComponentData = InventoryManager.create_part(part.id)
	spare.is_new = true
	InventoryManager.add_part(spare)
	GameManager.scenario_faulty_id = ""
	save_game()
	EventBus.career_updated.emit()
	EventBus.info_requested.emit("Çıkma parça arızalıymış. Yenisi %d ₺'ye alındı, envantere konuldu." % cost)

# Kayıttan okunan teklif sözlüğünü tiplendirir (JSON sayıları ondalık gelir)
func _read_offer(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return result
	var d: Dictionary = raw
	result = {
		"part_id": str(d.get("part_id", "")), "label": str(d.get("label", "")),
		"tier": int(d.get("tier", 0)), "used": bool(d.get("used", false)),
		"buy": int(d.get("buy", 0)), "sell": int(d.get("sell", 0)), "labor": int(d.get("labor", 0)), "total": int(d.get("total", 0)),
		"outcome": str(d.get("outcome", "")), "mood": str(d.get("mood", "normal")),
		"tip_bonus": float(d.get("tip_bonus", 0.0)), "tip_mult": float(d.get("tip_mult", 1.0)),
		"faulty": bool(d.get("faulty", false)), "replaced": bool(d.get("replaced", false)),
		"reorder_cost": int(d.get("reorder_cost", 0)),
		"board": str(d.get("board", "")), "budget": int(d.get("budget", 0)), "budget_type": str(d.get("budget_type", "orta")),
	}
	return result

# --- Dükkân mağazası ---------------------------------------------------------

func _load_catalog() -> void:
	_catalog.clear()
	for file: String in DirAccess.get_files_at(UPGRADES_DIR):
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var upgrade: UpgradeData = load(UPGRADES_DIR + file) as UpgradeData
		if upgrade and upgrade.id != "":
			_catalog.append(upgrade)
	_catalog.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		return a.order < b.order if a.order != b.order else a.price < b.price)

func catalog(category: String = "") -> Array[UpgradeData]:
	if category == "":
		return _catalog.duplicate()
	return _catalog.filter(func(u: UpgradeData) -> bool: return u.category == category)

func get_upgrade(id: String) -> UpgradeData:
	for upgrade: UpgradeData in _catalog:
		if upgrade.id == id:
			return upgrade
	return null

func has_upgrade(id: String) -> bool:
	return owned_upgrades.has(id)

# Alımın etkisi yalnız kariyerde geçerli (Test listesindeki işler hep aynı zorlukta)
func effect_active(id: String) -> bool:
	return is_career and has_upgrade(id)

func screw_speed_multiplier() -> float:
	return SCREWDRIVER_SPEED if effect_active("circir_tornavida") else 1.0

# Satın alınamıyorsa nedeni, alınabiliyorsa boş metin
func purchase_block_reason(upgrade: UpgradeData) -> String:
	if has_upgrade(upgrade.id):
		return "Alındı"
	if jobs_done < upgrade.required_jobs:
		return "%d iş gerekli" % upgrade.required_jobs
	if upgrade.required_stars > 0.0 and average_stars() < upgrade.required_stars:
		return "★ %.1f itibar gerekli" % upgrade.required_stars
	if money < upgrade.price:
		return "Kasada %d ₺ eksik" % (upgrade.price - money)
	return ""

func buy_upgrade(upgrade: UpgradeData) -> bool:
	if upgrade == null or purchase_block_reason(upgrade) != "":
		return false
	money -= upgrade.price
	owned_upgrades.append(upgrade.id)
	save_game() # Alım anında kaydedilir: para düşüp alım kaybolmasın
	EventBus.career_updated.emit()
	return true

# --- Hatalar -----------------------------------------------------------------

func record_mistake(kind: String) -> void:
	if not job_active:
		return
	mistakes[kind] = mistakes.get(kind, 0) + 1
	if is_career:
		save_game() # Menüye çıkıp dönmek hatayı silmesin
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

func _clear_job() -> void:
	mistakes.clear()
	failed_boots = 0
	job_active = false
	offer.clear()

func _begin_day() -> void:
	job_index = 0
	day_earned = 0
	day_star_total = 0
	day_jobs = 0
	day_tips = 0
	day_missed = 0
	day_lost = 0
	day_part_sales = 0
	day_part_cost = 0
	offer.clear()
	day_missed_needs.clear()
	day_queue.clear()
	if day <= PLANNED_DAYS.size():
		for path: String in PLANNED_DAYS[day - 1]:
			day_queue.append(path)
		_assign_customers()
		return
	var count: int = 3 if day < 5 else 4
	# Yalnız yapılabilen işler gelir; rafı alınmamış işten günde en fazla bir müşteri
	var open_pool: Array[String] = []
	var locked_pool: Array[String] = []
	for path: String in CAREER_POOL:
		if _job_open(path):
			open_pool.append(path)
		else:
			locked_pool.append(path)
	var last: String = ""
	for i: int in range(count):
		var options: Array = open_pool.filter(func(p: String) -> bool: return p != last)
		if options.is_empty():
			options = open_pool
		last = options.pick_random()
		day_queue.append(last)
	if not locked_pool.is_empty() and randf() < LOCKED_JOB_CHANCE:
		day_queue[randi_range(1, count - 1)] = locked_pool.pick_random()
	_assign_customers()

func _job_open(path: String) -> bool:
	var scenario: ScenarioData = load(path) as ScenarioData
	return scenario != null and (scenario.required_upgrade == "" or has_upgrade(scenario.required_upgrade))

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
		"version": SAVE_VERSION,
		"job_active": job_active, "mistakes": mistakes,
		"money": money, "day": day, "job_index": job_index, "day_queue": day_queue,
		"day_customers": day_customers,
		"jobs_done": jobs_done, "star_total": star_total,
		"day_earned": day_earned, "day_star_total": day_star_total, "day_jobs": day_jobs,
		"day_tips": day_tips, "day_missed": day_missed, "day_lost": day_lost, "day_missed_needs": day_missed_needs,
		"day_part_sales": day_part_sales, "day_part_cost": day_part_cost, "offer": offer,
		"owned_upgrades": owned_upgrades,
	}
	# Önce geçici dosyaya yazılır: yarım kalan yazım eski kaydı bozmasın
	var temp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Kayıt açılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_warning("Kayıt yazılamadı: %s" % error_string(write_error))
		return
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH))
	if rename_error != OK:
		push_warning("Kayıt tamamlanamadı: %s" % error_string(rename_error))

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
	var queue_ok: bool = true
	for path: Variant in data.get("day_queue", []):
		if ResourceLoader.exists(str(path)):
			day_queue.append(str(path))
		else:
			queue_ok = false
	# Silinmiş bir iş varsa gün yeniden kurulur (aşağıda _begin_day)
	if not queue_ok:
		day_queue.clear()
	job_active = queue_ok and bool(data.get("job_active", false))
	mistakes.clear()
	var saved_mistakes: Variant = data.get("mistakes", {})
	if saved_mistakes is Dictionary:
		for kind: Variant in saved_mistakes:
			mistakes[str(kind)] = int(saved_mistakes[kind])
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
	day_tips = int(data.get("day_tips", 0))
	day_missed = int(data.get("day_missed", 0))
	day_lost = int(data.get("day_lost", 0))
	day_part_sales = int(data.get("day_part_sales", 0))
	day_part_cost = int(data.get("day_part_cost", 0))
	day_missed_needs.clear()
	for id: Variant in data.get("day_missed_needs", []):
		day_missed_needs.append(str(id))
	owned_upgrades.clear()
	for id: Variant in data.get("owned_upgrades", []):
		# Silinmiş bir alım kayıtta kalsa da zarar vermez, ama listeye alınmaz
		if get_upgrade(str(id)) != null and not owned_upgrades.has(str(id)):
			owned_upgrades.append(str(id))
	# Tezgâhta seçilmiş parça: iş aynı kalmışsa korunur (menüye çıkıp dönmek seçimi silmez)
	offer = _read_offer(data.get("offer", {}))
	if not offer.is_empty() and not _offer_still_valid():
		money += int(offer.get("buy", 0)) + int(offer.get("reorder_cost", 0)) # Geçersiz teklif: ödenen alış bedeli iade
		offer.clear()
	if day_queue.is_empty():
		_begin_day()
	return true

# Kayıttaki teklif, sıradaki işe ait ve katalogda hâlâ var mı?
func _offer_still_valid() -> bool:
	var scenario: ScenarioData = current_scenario()
	return scenario != null and scenario.offer_part_type != "" and InventoryManager.has_catalog_part(str(offer.get("part_id", "")))

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
