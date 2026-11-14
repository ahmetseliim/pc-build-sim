class_name PartOffer
extends RefCounted

# Parça Teklifi (PartOffer)
# Tezgâhta parça gereken işlerde müşterinin bütçesi, teklif kartındaki seçenekler ve
# müşterinin seçime tepkisi burada hesaplanır (saf mantık; sahne ve kayıt yok).
# Durum (seçilen parça, ödenen alış fiyatı) CareerManager.offer içinde tutulur.
#
# Bütçe: senaryonun `base_budget` değeri (işçilik + parça toplamı) müşterinin bütçe tipiyle çarpılır.
# Tepki (toplam = işçilik + parça satış fiyatı):
#   - Dar:   toplam bütçeyi aşarsa müşteri gider. Çıkma parçaya sevinir.
#   - Orta:  bütçeyi %15'e kadar aşarsa söylenir ama kabul eder (bahşiş yok); fazlasında gider.
#   - Geniş: en ucuz (kademe 1) parçada "daha iyisi yok muydu" der (bahşiş yarıya düşer); çıkma parçaya kızar (bahşiş yok).
#   - Bütçeye ve tipe uygun seçimde mutlu yüz ve bahşişe +%5.

const BUDGET_MULTIPLIERS: Dictionary = {"dar": 0.8, "orta": 1.0, "genis": 1.6}
const BUDGET_NAMES: Dictionary = {"dar": "Dar bütçeli", "orta": "Orta bütçeli", "genis": "Geniş bütçeli"}
const TOLERANCE: float = 0.15 ## Orta ve geniş müşteri bütçeyi bu orana kadar aşmayı kabul eder
const HAPPY_TIP_BONUS: float = 0.05 ## Mutlu seçimde bahşiş oranına eklenir
const USED_BRAND: String = "Demirci" ## Çıkma (ikinci el) parçaların markası
const FAULTY_CHANCE: float = 0.2 ## Çıkma parçanın arızalı gelme ihtimali
## Kariyer dışı (Test menüsü) işlerde kullanılan raf seviyesi: hepsi açık. Kariyerde `CareerManager.shelf_level()` dükkân seviyesinden gelir.
const MAX_SHELF_LEVEL: int = 3
const TIER_NAMES: Dictionary = {1: "EKONOMİK", 2: "DENGELİ", 3: "ÜST"}
const USED_NAME: String = "ÇIKMA"

## Bütçeli montaj (P7, offer_part_type "build"): müşteri bütün parçaları oyuncuya seçtirir. Parça türleri ve her birinden kaç adet takıldığı.
const BUILD_PARTS: Array[String] = ["cpu", "ram", "m2", "gpu", "psu"]
const BUILD_COUNTS: Dictionary = {"ram": 2}
const BUILD_PART_NAMES: Dictionary = {"cpu": "İşlemci", "ram": "RAM (2 adet)", "m2": "SSD (M.2)", "gpu": "Ekran kartı", "psu": "Güç kaynağı"}
const OFFICE_BUDGET_FACTOR: float = 0.8 ## Ofis amaçlı montajda bütçe oyuncununkinin bu kadarıdır (taban bütçe oyun içindir)

## Tepki: sonuç anahtarı -> müşterinin sözü
const REACTION_LINES: Dictionary = {
	"happy": "Tam aradığım gibi! Fiyatı da gayet makul, teşekkürler.",
	"over_budget": "Bütçemi biraz aştı ama tamam, kabul. Hadi bakalım.",
	"cheap_meh": "Hımm, daha iyisi yok muydu? Neyse, bu da idare eder...",
	"used_happy": "Çıkma mı? Çok iyi, tam bana göre! Cebim de rahat.",
	"used_ok": "Çıkma parça ha... Olur, bakarız.",
	"used_angry": "Çıkma mı?! Ben buna para vermem, hiç hoşuma gitmedi!",
	"leave": "Bu fiyata mı? Bütçemin çok üstünde! Başka dükkâna bakarım.",
	"build_weak_gpu": "Bu ekran kartıyla oyun mu oynanır?! Ben oyun için istemiştim...",
	"build_overkill": "Ofis işi için bu kadar güçlü kart mı? Parayı boşa harcamışız.",
}

# Müşterinin bütçesini söyleyen söz (şikâyetin sonuna eklenir); tona göre
const BUDGET_LINES: Dictionary = {
	"dar": "Param kısıtlı, %d lirayı geçmesin lütfen.",
	"orta": "Bütçem %d lira civarı, ona göre bir şey bulalım.",
	"genis": "Fiyat önemli değil, kaliteli olsun; yine de %d lirayı aşmasın.",
}

# Müşterinin bütçesi (₺, 10'a yuvarlanır); senaryoda teklif yoksa 0
static func budget_for(scenario: ScenarioData, budget_type: String, purpose: String = "") -> int:
	if scenario == null or scenario.base_budget <= 0:
		return 0
	var mult: float = BUDGET_MULTIPLIERS.get(budget_type, 1.0)
	if is_build(scenario) and purpose == "ofis":
		mult *= OFFICE_BUDGET_FACTOR
	return int(round(scenario.base_budget * mult / 10.0)) * 10

# Bütçeli montaj mı (müşteri bütün parçaları seçtirir)?
static func is_build(scenario: ScenarioData) -> bool:
	return scenario != null and scenario.offer_part_type == "build"

static func budget_line(budget_type: String, budget: int) -> String:
	return BUDGET_LINES.get(budget_type, BUDGET_LINES["orta"]) % budget

static func is_used(part: ComponentData) -> bool:
	return part.brand == USED_BRAND

# En çok ödemeyi kabul ettiği tutar: dar bütçeli müşteri bütçeyi hiç aşmaz, diğerleri %15 aşar
static func spend_limit(budget_type: String, budget: int) -> int:
	return budget if budget_type == "dar" else int(floor(budget * (1.0 + TOLERANCE)))

# Teklif kartındaki seçenekler: işin parça türünden, gelen kartın kabul ettiği (uyumlu) katalog parçaları.
# Kademe 1-2-3'ten birer yeni parça (kademede birden çok varsa katalog sırasındaki ilki: ucuz, sonra id) + varsa çıkma.
# Uyumsuz parça listelenmez. `board` null olursa kart kısıtı uygulanmaz.
# `shelf_level`: listelenebilecek en yüksek kademe (dükkân seviyesine bağlı). O kademede karta uyan parça yoksa
# kart boş kalmasın diye bir üst kademeye çıkılır.
static func options(scenario: ScenarioData, board: BoardData, shelf_level: int = MAX_SHELF_LEVEL) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if scenario == null or scenario.offer_part_type == "" or is_build(scenario):
		return result
	for level: int in range(clampi(shelf_level, 1, MAX_SHELF_LEVEL), MAX_SHELF_LEVEL + 1):
		result = _options_for(scenario.offer_part_type, scenario.price, board, level)
		if not result.is_empty():
			break
	if scenario.power_check and scenario.offer_part_type == "gpu":
		_add_power_bundle(result, scenario, shelf_level)
	return result

# Ekran kartı yükseltmede güç hesabı: kartı taşımayan güç kaynağı varsa seçeneğe yeterli en ucuz yeni güç kaynağı da eklenir
# (alış, satış ve toplam ona göre artar; kart "extras" ile PSU'yu taşır, "note" teklif kartında uyarı olarak gösterilir)
static func _add_power_bundle(options_list: Array[Dictionary], scenario: ScenarioData, shelf_level: int) -> void:
	var psu_watt: int = installed_psu_watt(scenario)
	for option: Dictionary in options_list:
		var gpu_watt: int = PowerCalc.gpu_watt_of(option["part"])
		option["gpu_watt"] = gpu_watt
		if PowerCalc.enough(psu_watt, gpu_watt):
			continue
		var psu: ComponentData = cheapest_psu(PowerCalc.needed_psu_watt(gpu_watt), shelf_level)
		if psu == null:
			continue
		option["extras"] = [{"type": "psu", "id": psu.id, "label": part_label_of(psu), "buy": psu.buy_price, "sell": psu.sell_price, "count": 1}]
		option["buy"] = int(option["buy"]) + psu.buy_price
		option["sell"] = int(option["sell"]) + psu.sell_price
		option["total"] = int(option["total"]) + psu.sell_price
		option["profit"] = int(option["sell"]) - int(option["buy"])
		option["note"] = "Güç kaynağın %d W, yetmez. %s de gerekir (+%d ₺)" % [psu_watt, part_label_of(psu), psu.sell_price]

# Bilgisayarda takılı gelen güç kaynağının kapasitesi (W): hazır takılı listede katalog güç kaynağı varsa o, yoksa genel
static func installed_psu_watt(scenario: ScenarioData) -> int:
	for key: String in scenario.preinstalled_parts:
		if InventoryManager.catalog_part_type(key) == "psu":
			return InventoryManager.create_part(key).watt
	return PowerCalc.GENERIC_PSU_WATT

# En az `watt` kapasiteli en ucuz (yeni) katalog güç kaynağı; rafta yoksa bütün katalogdan; hiç yoksa null
static func cheapest_psu(watt: int, shelf_level: int) -> ComponentData:
	for level: int in [clampi(shelf_level, 1, MAX_SHELF_LEVEL), MAX_SHELF_LEVEL]:
		var best: ComponentData = null
		for part: ComponentData in InventoryManager.catalog_parts("psu", level):
			if not is_used(part) and part.watt >= watt and (best == null or part.buy_price < best.buy_price):
				best = part
		if best != null:
			return best
	return null

static func part_label_of(part: ComponentData) -> String:
	return PartArt.part_label(part)

# Bütçeli montajın parça listesi: tür -> seçenekler (kademe 1-2-3, çıkma parça yok). Alış/satış/toplam adetle çarpılıdır (RAM 2 adet).
static func build_options(board: BoardData, shelf_level: int = MAX_SHELF_LEVEL) -> Dictionary:
	var result: Dictionary = {}
	for type: String in BUILD_PARTS:
		var list: Array[Dictionary] = []
		for level: int in range(clampi(shelf_level, 1, MAX_SHELF_LEVEL), MAX_SHELF_LEVEL + 1):
			list.clear()
			for option: Dictionary in _options_for(type, 0, board, level):
				if not bool(option["used"]):
					list.append(option)
			if not list.is_empty():
				break
		var count: int = int(BUILD_COUNTS.get(type, 1))
		for option: Dictionary in list:
			option["count"] = count
			option["buy"] = int(option["buy"]) * count
			option["sell"] = int(option["sell"]) * count
			option["total"] = int(option["sell"])
			option["profit"] = int(option["sell"]) - int(option["buy"])
		result[type] = list
	return result

# Seçilen parçaların özeti. `selection`: tür -> seçenek. Dönüş: buy, sell, labor, total, power_ok, need_watt (güç kaynağı yetmezse gereken W)
static func build_summary(scenario: ScenarioData, selection: Dictionary) -> Dictionary:
	var buy: int = 0
	var sell: int = 0
	for type: String in selection:
		buy += int((selection[type] as Dictionary)["buy"])
		sell += int((selection[type] as Dictionary)["sell"])
	var power_ok: bool = true
	var need_watt: int = 0
	if selection.has("gpu") and selection.has("psu"):
		var gpu_watt: int = PowerCalc.gpu_watt_of(((selection["gpu"] as Dictionary)["part"]) as ComponentData)
		var psu_watt: int = PowerCalc.psu_watt_of(((selection["psu"] as Dictionary)["part"]) as ComponentData)
		power_ok = PowerCalc.enough(psu_watt, gpu_watt)
		need_watt = 0 if power_ok else PowerCalc.needed_psu_watt(gpu_watt)
	var labor: int = scenario.price if scenario != null else 0
	return {"buy": buy, "sell": sell, "labor": labor, "total": labor + sell, "power_ok": power_ok, "need_watt": need_watt}

# Bütçeli montajda müşterinin tepkisi: önce bütçe (judge), sonra amaç. Oyun için zayıf kart ya da ofis için gereğinden güçlü kart bahşişi keser.
static func judge_build(summary: Dictionary, gpu_tier: int, budget: int, budget_type: String, purpose: String) -> Dictionary:
	var verdict: Dictionary = judge({"total": int(summary["total"]), "used": false, "tier": 2}, budget, budget_type)
	if verdict["leaves"]:
		return verdict
	var outcome: String = ""
	if purpose == "oyun" and gpu_tier < 2:
		outcome = "build_weak_gpu"
		verdict["mood"] = "sad"
	elif purpose == "ofis" and gpu_tier >= 3:
		outcome = "build_overkill"
		verdict["mood"] = "normal"
	if outcome != "":
		verdict["outcome"] = outcome
		verdict["tip_bonus"] = 0.0
		verdict["tip_mult"] = 0.0
		verdict["line"] = REACTION_LINES[outcome]
	return verdict

static func _options_for(type: String, labor: int, board: BoardData, shelf_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var picked_tiers: Dictionary = {}
	var used_part: ComponentData = null
	for part: ComponentData in InventoryManager.catalog_parts(type, shelf_level):
		if not _fits_board(part, type, board):
			continue
		if is_used(part):
			if used_part == null:
				used_part = part
		elif not picked_tiers.has(part.tier):
			picked_tiers[part.tier] = part
	var tiers: Array = picked_tiers.keys()
	tiers.sort()
	for tier: int in tiers:
		result.append(_option(picked_tiers[tier], labor))
	if used_part != null:
		result.append(_option(used_part, labor))
	return result

# Karta uyum: RAM kartın türüne (H81'de DDR3), M.2 / SATA / ekran kartı ilgili yuvası olan karta, güç kaynağı güç kaynağı yuvası (ATX 24-pin bağlantısı) olan karta uyar
static func _fits_board(part: ComponentData, type: String, board: BoardData) -> bool:
	if board == null:
		return true
	if type == "ram":
		return part.ram_type == board.ram_type
	if type == "cpu":
		return part.socket == board.socket
	if type in ["m2", "sata", "gpu", "psu"]:
		return GameManager.slot_types_of(board).has(type)
	return true

static func _option(part: ComponentData, labor: int) -> Dictionary:
	var used: bool = is_used(part)
	return {
		"id": part.id, "part": part, "tier": part.tier, "used": used,
		"tag": USED_NAME if used else TIER_NAMES.get(part.tier, ""),
		"label": PartArt.part_label(part), "model": part.model, "brand": part.brand,
		"spec": spec_text(part),
		"buy": part.buy_price, "sell": part.sell_price, "labor": labor,
		"total": labor + part.sell_price, "profit": part.sell_price - part.buy_price,
	}

# Kartta parçanın kısa özelliği: "8 GB DDR4", "500 GB NVMe"
static func spec_text(part: ComponentData) -> String:
	match part.part_type:
		"ram":
			return "%s %s" % [PartArt.capacity_text(part.capacity_gb), part.ram_type]
		"m2":
			return "%s NVMe" % PartArt.capacity_text(part.capacity_gb)
		"sata":
			return "%s SATA" % PartArt.capacity_text(part.capacity_gb)
		"psu":
			return "%d W" % part.watt
		"gpu":
			var vram: int = (part as GPUData).vram_gb if part is GPUData else 0
			return "%d GB" % vram if vram > 0 else part.model
	return part.model

# Seçimin sonucu. Dönüş: outcome (REACTION_LINES anahtarı), mood ("happy"/"normal"/"sad"), leaves (müşteri gider),
# tip_bonus (bahşiş oranına eklenir), tip_mult (bahşişin çarpanı), line (müşterinin sözü)
static func judge(option: Dictionary, budget: int, budget_type: String) -> Dictionary:
	var total: int = int(option["total"])
	var used: bool = bool(option["used"])
	var outcome: String
	if total > spend_limit(budget_type, budget):
		outcome = "leave"
	elif used:
		outcome = "used_happy" if budget_type == "dar" else ("used_angry" if budget_type == "genis" else "used_ok")
	elif total > budget:
		outcome = "over_budget"
	elif budget_type == "genis" and int(option["tier"]) <= 1:
		outcome = "cheap_meh"
	else:
		outcome = "happy"
	var mood: String = "normal"
	var tip_bonus: float = 0.0
	var tip_mult: float = 1.0
	match outcome:
		"happy", "used_happy":
			mood = "happy"
			tip_bonus = HAPPY_TIP_BONUS
		"over_budget":
			tip_mult = 0.0
		"cheap_meh":
			tip_mult = 0.5
		"used_angry":
			mood = "sad"
			tip_mult = 0.0
		"leave":
			mood = "sad"
	return {
		"outcome": outcome, "mood": mood, "leaves": outcome == "leave",
		"tip_bonus": tip_bonus, "tip_mult": tip_mult, "line": REACTION_LINES[outcome],
	}
