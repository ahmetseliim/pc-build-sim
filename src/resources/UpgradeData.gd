class_name UpgradeData
extends Resource

# Dükkân Alımı (UpgradeData)
# Gün sonu mağazasında satılan kalıcı bir alım. Üç tür vardır:
# "raf"   — o parçanın tedarikçisini açar; rafı olmayan işin müşterisi gider
# "alet"  — işi kolaylaştırır ya da hızlandırır
# "dekor" — dükkânın görünümü, bahşiş ve müşteri
# Etkiler kodda id ile sorgulanır (CareerManager.effect_active).

@export var id: String = "" ## Kayıtta ve kodda kullanılan kalıcı ad (değiştirilmemeli)
@export var title: String = ""
@export_enum("raf", "alet", "dekor") var category: String = "alet"
@export var price: int = 0 ## ₺
@export_multiline var effect: String = "" ## Mağazada gösterilen tek cümlelik etki
@export var required_jobs: int = 0 ## Satın almak için gereken toplam iş
@export var required_stars: float = 0.0 ## Satın almak için gereken dükkân itibarı
@export var order: int = 0 ## Mağazadaki sıra (küçük önce)
