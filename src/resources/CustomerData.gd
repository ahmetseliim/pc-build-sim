class_name CustomerData
extends Resource

# Müşteri Karakteri (CustomerData)
# Tezgâha gelen bir müşterinin adı, görünüşü ve konuşma tarzı.
# Görseller "Müşteri Karakterleri" tasarım dosyasından alınan SVG'lerdir (assets/characters/).

@export var display_name: String = ""
@export var role: String = "" ## Karakter tipi (örn. "Antika Meraklısı")
@export var texture: Texture2D
@export var texture_happy: Texture2D ## Memnun yüz (boşsa normal görsel kullanılır)
@export var texture_sad: Texture2D ## Kırgın yüz (boşsa normal görsel kullanılır)
@export var texture_talk: Texture2D ## Konuşurken ağzı açık normal yüz (boşsa ağız oynamaz)
@export var accent: Color = Color("#E1A83A") ## Konuşma balonundaki isim etiketinin rengi
@export var greeting: String = "" ## Tezgâha gelince şikâyetten önce söylediği söz
@export var thanks_line: String = "" ## Memnun kalınca söylediği kendine özgü söz
## Bütçe tipi: "dar" (×0,8), "orta" (×1,0), "genis" (×1,6). Parça teklifinde müşterinin bütçesini ve tepkisini belirler (PartOffer)
@export_enum("dar", "orta", "genis") var budget_type: String = "orta"
## Bu müşteri hangi dükkân seviyesinden itibaren gelir (1: baştan)
@export var min_shop_level: int = 1
