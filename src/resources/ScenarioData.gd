class_name ScenarioData
extends Resource

# Senaryo Verisi (ScenarioData)
# Dükkâna gelen bir işi tanımlar: bilgisayarda hazır takılı gelen parçalar,
# envanterde verilen parçalar ve arızalar.

@export var title: String = ""
@export var shop_stage: int = 1 ## 1: Tamir dükkânı, 2: Montaj dükkânı
@export var customer: String = ""
@export_multiline var complaint: String = "" ## Boşsa arızaya göre otomatik şikâyet yazılır
@export_multiline var menu_description: String = ""
@export_multiline var hint: String = "" ## İş emri kartında gösterilen ipucu

@export_group("Bilgisayarın durumu")
## Hazır takılı gelen parçalar ve kablolar. "paste": işlemciye macun sürülmüş demektir.
@export var preinstalled_parts: Array[String] = []
## Envanterde verilen parçalar
@export var inventory_parts: Array[String] = []

@export_group("Arızalar")
@export var broken_cables: Array[String] = [] ## Bozuk gelen kablolar
@export var random_broken_cable: bool = false ## Takılı kablolardan biri rastgele bozuk gelsin
@export var spare_for_broken: bool = true ## Bozuk kablonun yedeği envantere konsun
@export var old_paste: bool = false ## İşlemcideki macun kurumuş gelsin (fan sökülüp yenilenmeli)
## Bu türden takılı parçalardan biri rastgele arızalı gelir (örn. "ram"); görünüşte sağlamdır, BIOS'tan teşhis edilir
@export var faulty_part: String = ""
## Tıklanarak sökülebilen parça türleri (sağlam olan envantere döner, arızalı atılır)
@export var removable_parts: Array[String] = []

@export_group("Akış")
@export var early_boot: bool = false ## "Bilgisayarı Başlat" baştan görünsün (arıza teşhisi için)
