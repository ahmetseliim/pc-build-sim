class_name ScenarioData
extends Resource

# Senaryo Verisi (ScenarioData)
# Dükkâna gelen bir işi tanımlar: bilgisayarda hazır takılı gelen parçalar,
# envanterde verilen parçalar ve arızalar.

@export var title: String = ""
@export var shop_stage: int = 1 ## 1: Tamir dükkânı, 2: Montaj dükkânı
@export var price: int = 0 ## İşin ücreti (₺); hatalar bundan keser
@export var customer: String = ""
@export_multiline var complaint: String = "" ## Boşsa arızaya göre otomatik şikâyet yazılır
## Müşterinin söyleyebileceği şikâyetler (genelde 3). Doluysa iş her hazırlanışında biri rastgele seçilir (complaint yok sayılır);
## tezgâh ve iş emri aynı metni gösterir (GameManager.get_complaint)
@export var complaints: Array[String] = []
@export_multiline var menu_description: String = ""
@export_multiline var hint: String = "" ## İş emri kartında gösterilen ipucu
## Bu işi kabul etmek için gereken dükkân alımı (data/upgrades/*.tres id'si, örn. "raf_ssd"). Boşsa her zaman yapılabilir.
@export var required_upgrade: String = ""
## Tezgâhta parça teklifi açılacak parça türü ("ram", "m2"...). Boşsa teklif yok: müşteri doğrudan atölyeye alınır.
@export var offer_part_type: String = ""
## Teklif toplam fiyatı (işçilik + parça) için taban bütçe (₺); müşterinin bütçesi bunun bütçe tipi çarpanıyla çarpımıdır
@export var base_budget: int = 0

@export_group("Bilgisayarın durumu")
## Bu işte gelebilecek anakartlar (data/boards/*.tres); her seferinde biri rastgele seçilir. Boşsa modern kart.
@export var board_paths: Array[String] = []
## Hazır takılı gelen parçalar ve kablolar. "paste": işlemciye macun sürülmüş demektir.
@export var preinstalled_parts: Array[String] = []
## Envanterde verilen parçalar
@export var inventory_parts: Array[String] = []
## Tamir dükkânında envanterdekiler yeni yedek parça mı ("YENİ" etiketi). Çıkmış bir kablo gibi eski parçalarda false.
@export var inventory_is_new: bool = true

@export_group("Arızalar")
@export var broken_cables: Array[String] = [] ## Bozuk gelen kablolar
@export var random_broken_cable: bool = false ## Takılı kablolardan biri rastgele bozuk gelsin
@export var spare_for_broken: bool = true ## Bozuk kablonun yedeği envantere konsun
@export var old_paste: bool = false ## İşlemcideki macun kurumuş gelsin (fan sökülüp yenilenmeli)
## Bu türden takılı parçalardan biri rastgele arızalı gelir (örn. "ram"); görünüşte sağlamdır, BIOS'tan teşhis edilir
@export var faulty_part: String = ""
## Tıklanarak sökülebilen parça türleri (sağlam olan envantere döner, arızalı atılır)
@export var removable_parts: Array[String] = []

@export_group("Gevşek parça")
## Hazır bilgisayarda yerinden çıkmış gelen parça/kablo türleri (preinstalled_parts içinde geçmeli; örn. "ram", "atx24"):
## takılı gelmez, envantere konur, BIOS "bulunamadı" der. Kartta olmayan tür seçilmez.
@export var loose_parts: Array[String] = []
## loose_parts içinden kaç tanesi (rastgele) yerinden çıksın; 0: hepsi
@export var loose_count: int = 0

@export_group("Akış")
@export var early_boot: bool = false ## "Bilgisayarı Başlat" baştan görünsün (arıza teşhisi için)
