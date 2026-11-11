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
