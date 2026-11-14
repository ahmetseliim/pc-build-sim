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
## İş emri kartında (kariyer, dükkân seviyesi 2 ve üstü) gösterilen belirsiz başlık: yalnız belirtiyi söyler, teşhisi BIOS'tan yapılır.
## Boşsa ya da seviye 1'de `title` gösterilir (GameManager.order_title)
@export var symptom_title: String = ""
## Bu iş kariyerde hangi dükkân seviyesinden itibaren havuza girer (CareerManager.level_pool; 1: her zaman). Test menüsünde her zaman açıktır.
@export var min_shop_level: int = 1
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

@export_group("Yeni mekanikler (P7)")
## Fanda ve ızgarada toz birikmiş gelir: bilgisayar çalışmaz (BIOS: CPU ısınır, throttle); DustCleaner ile temizlenir
@export var dusty: bool = false
## Saat sıfırlanıyor: CMOS pil yuvası eklenir (preinstalled_parts/inventory_parts'ta "cmos"), pil bittiğinde BIOS tarihi sıfırlar,
## yeni pil takılınca BIOS'ta tarih ayarlanana kadar iş bitmez
@export var clock_reset: bool = false
## Güç hesabı: BIOS, takılı ekran kartının ve sistemin çektiği gücü güç kaynağının kapasitesiyle karşılaştırır (PowerCalc);
## yetmiyorsa uyarı verip durur. Tezgâh teklifinde büyük kartla birlikte yeterli güç kaynağı da önerilir.
@export var power_check: bool = false
## Gizli arıza: bu türlerden biri (iş hazırlanırken rastgele) arızalı gelir ama BIOS adını söylemez, yalnız bip kodu verir.
## POST kartı (alet) varsa kod çözülür ve arızalı parça yazılır.
@export var hidden_faults: Array[String] = []
## Çift arıza: `faulty_part` çözülünce bu türlerden biri (rastgele) bozulur ve BIOS ikinci arızayı gösterir
@export var latent_faults: Array[String] = []
## `complaints` ile aynı sırada, her şikâyetin etiketi (örn. "oyun" / "ofis"); bütçeli montajda müşterinin amacını belirler
@export var complaint_tags: Array[String] = []
