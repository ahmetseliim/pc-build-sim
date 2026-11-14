class_name LevelData
extends Resource

# Dükkân Seviyesi (LevelData)
# Dükkânın büyüme aşamalarından biri (Köşe tamircisi → Mahalle dükkânı → Montaj atölyesi → Teknoloji mağazası).
# Seviye atlama gün sonu mağazasından tek seferlik büyük bir alımla yapılır (CareerManager.buy_level).

@export var level: int = 1 ## 1-4
@export var title: String = "" ## Dükkânın adı
@export var price: int = 0 ## Bu seviyeye geçmenin bedeli (₺); seviye 1 için 0
@export var required_jobs: int = 0 ## Geçmek için gereken toplam iş
@export var required_stars: float = 0.0 ## Geçmek için gereken dükkân itibarı
## Günlük müşteri sayısı. Seviye 1'de bugünkü kural geçerlidir (1. gün 2, sonra 3, 5. günden itibaren 4); bu alan 3 olarak kalır.
@export var daily_customers: int = 3
## Tezgâh arka planı (seviyeye özel); dosya yoksa tezgâh sahnesi varsayılan shop_back.png'yi kullanır
@export var background: String = ""
## Bu seviyenin açtığı şeyler (mağazada kısa metin listesi)
@export var unlocks: Array[String] = []
