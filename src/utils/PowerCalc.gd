class_name PowerCalc
extends RefCounted

# Güç Hesabı (PowerCalc)
# Ekran kartı değişiminde güç kaynağının yetip yetmediğini hesaplar (saf mantık; sahne ve kayıt yok).
# Sistemin (işlemci, kart, disk, fan) ekran kartı dışındaki çekişi sabit kabul edilir; güç kaynağı kapasitesinin
# yalnız %85'i sürekli yük için güvenlidir. BIOS uyarısı ve tezgâhtaki "PSU de gerekir" önerisi aynı hesabı kullanır.

const SYSTEM_BASE_WATT: int = 200 ## Ekran kartı hariç sistemin çektiği güç
const LOAD_LIMIT: float = 0.85 ## Güç kaynağı kapasitesinin güvenle kullanılabilir oranı
const GENERIC_PSU_WATT: int = 750 ## Katalogda olmayan (genel) güç kaynağı: eski sabit BIOS değeri

# Toplam çekiş (W)
static func total_load(gpu_watt: int) -> int:
	return SYSTEM_BASE_WATT + gpu_watt

# Güç kaynağının güvenle verebildiği güç (W)
static func psu_limit(psu_watt: int) -> int:
	return int(floor(psu_watt * LOAD_LIMIT))

static func enough(psu_watt: int, gpu_watt: int) -> bool:
	return total_load(gpu_watt) <= psu_limit(psu_watt)

# Bu kartı taşıyacak en küçük güç kaynağı kapasitesi (W)
static func needed_psu_watt(gpu_watt: int) -> int:
	return int(ceil(total_load(gpu_watt) / LOAD_LIMIT))

# Parçanın watt değeri: katalog güç kaynağı kendi değerini, genel (watt 0) güç kaynağı GENERIC_PSU_WATT verir
static func psu_watt_of(part: ComponentData) -> int:
	return part.watt if part != null and part.watt > 0 else GENERIC_PSU_WATT

static func gpu_watt_of(part: ComponentData) -> int:
	return (part as GPUData).power_draw if part is GPUData else 0
