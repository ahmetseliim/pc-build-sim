class_name ComponentData
extends Resource

# Temel Bileşen Verisi (ComponentData)
# Tüm parçaların ortak özelliklerini tutar.

@export var part_name: String = ""
@export var part_type: String = ""  # cpu, gpu, ram, m2, sata, fan, paste, psu, atx24, eps8, pcie8, satapwr, satadata
@export var socket: String = ""
@export var price: float = 0.0
@export var texture: Texture2D
@export var icon: Texture2D
@export var description: String = ""
@export var is_cable: bool = false
@export var bg_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var icon_text: String = ""
@export var is_new: bool = false ## Tamir dükkânında yedek olarak verilen yeni parça ("YENİ" etiketi)

@export_group("Katalog")
## Katalog parçası kimliği (data/parts/<tür>/<id>.tres), örn. "ram_ddr4_8_kartal". Boşsa katalogda olmayan genel parça (eski tür adıyla üretilenler, kablolar).
@export var id: String = ""
@export var brand: String = "" ## Kurgu marka: Kartal, Pusula, Zirve, Volta, Nimbus, Demirci
@export var model: String = "" ## Marka içindeki model adı
@export_range(0, 3) var tier: int = 0 ## 1 ekonomik, 2 dengeli, 3 üst; 0 katalogda değil
@export var buy_price: int = 0 ## Dükkânın tedarikçiden alış fiyatı (₺)
@export var sell_price: int = 0 ## Müşteriye satış fiyatı (₺); kâr = satış - alış
@export var ram_type: String = "" ## RAM için DDR3 / DDR4 / DDR5
@export var capacity_gb: int = 0 ## RAM ve SSD kapasitesi (1 TB = 1000)
@export var watt: int = 0 ## Güç kaynağı gücü (ekran kartı ve işlemci için GPUData.power_draw / CPUData.tdp)
@export var form_factor: String = "" ## Güç kaynağı için ATX vb.
@export var min_shelf_level: int = 1 ## Hangi raf seviyesinde satılabilir (1-3)
@export var art: String = "" ## Görsel anahtarı (P6'da parça görselini seçer), örn. "ram_t2"
## Çıkma parça tedarikçiden arızalı geldi (tezgâh teklifinde %20 ihtimal). Takılınca BIOS'ta yakalanır; PartItem.is_broken olur.
## Yalnız çalışma anında doldurulur, katalog dosyalarında false kalır.
@export var is_faulty: bool = false

@export_group("Görünüm")
@export var part_size: Vector2 = Vector2(100, 100) ## Envanterdeki boyut (px)
@export var bg_color_end: Color = Color(0, 0, 0, 0) ## Doluysa 135° gradyan bitiş rengi
@export var border_width: int = 0
@export var border_color: Color = Color.TRANSPARENT
@export var text_color: Color = Color.WHITE
@export var font_size: int = 11
@export var corner_radius: float = 6.0
@export var is_circle: bool = false
@export var layout: String = "column" ## column, row veya vertical

@export_group("Kablo")
@export var cable_color: Color = Color.WHITE
@export var cable_width: float = 6.0
@export var cable_from: String = "" ## Kablonun çıktığı port: psu_atx, psu_eps, psu_pcie, psu_sata, mb_sata, fan
@export var cable_entry: Vector2 = Vector2.RIGHT ## Kablonun fişten çıktığı yön
