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
## Teklifte listelenebilecek en yüksek raf seviyesi. Raf seviyeleri (P5) gelene kadar hepsi açık.
const SHELF_LEVEL: int = 3
const TIER_NAMES: Dictionary = {1: "EKONOMİK", 2: "DENGELİ", 3: "ÜST"}
const USED_NAME: String = "ÇIKMA"

## Tepki: sonuç anahtarı -> müşterinin sözü
const REACTION_LINES: Dictionary = {
	"happy": "Tam aradığım gibi! Fiyatı da gayet makul, teşekkürler.",
	"over_budget": "Bütçemi biraz aştı ama tamam, kabul. Hadi bakalım.",
	"cheap_meh": "Hımm, daha iyisi yok muydu? Neyse, bu da idare eder...",
	"used_happy": "Çıkma mı? Çok iyi, tam bana göre! Cebim de rahat.",
	"used_ok": "Çıkma parça ha... Olur, bakarız.",
	"used_angry": "Çıkma mı?! Ben buna para vermem, hiç hoşuma gitmedi!",
	"leave": "Bu fiyata mı? Bütçemin çok üstünde! Başka dükkâna bakarım.",
}

# Müşterinin bütçesini söyleyen söz (şikâyetin sonuna eklenir); tona göre
const BUDGET_LINES: Dictionary = {
	"dar": "Param kısıtlı, %d lirayı geçmesin lütfen.",
	"orta": "Bütçem %d lira civarı, ona göre bir şey bulalım.",
	"genis": "Fiyat önemli değil, kaliteli olsun; yine de %d lirayı aşmasın.",
}

# Müşterinin bütçesi (₺, 10'a yuvarlanır); senaryoda teklif yoksa 0
static func budget_for(scenario: ScenarioData, budget_type: String) -> int:
	if scenario == null or scenario.base_budget <= 0:
		return 0
	var mult: float = BUDGET_MULTIPLIERS.get(budget_type, 1.0)
	return int(round(scenario.base_budget * mult / 10.0)) * 10

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
static func options(scenario: ScenarioData, board: BoardData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if scenario == null or scenario.offer_part_type == "":
		return result
	var type: String = scenario.offer_part_type
	var picked_tiers: Dictionary = {}
	var used_part: ComponentData = null
	for part: ComponentData in InventoryManager.catalog_parts(type, SHELF_LEVEL):
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
		result.append(_option(picked_tiers[tier], scenario.price))
	if used_part != null:
		result.append(_option(used_part, scenario.price))
	return result

# Karta uyum: RAM kartın türüne (H81'de DDR3), M.2 / SATA / ekran kartı ilgili yuvası olan karta, güç kaynağı güç kaynağı yuvası (ATX 24-pin bağlantısı) olan karta uyar
static func _fits_board(part: ComponentData, type: String, board: BoardData) -> bool:
	if board == null:
		return true
	if type == "ram":
		return part.ram_type == board.ram_type
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
