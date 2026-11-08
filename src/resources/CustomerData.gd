class_name CustomerData
extends Resource

# Müşteri Karakteri (CustomerData)
# Tezgâha gelen bir müşterinin adı, görünüşü ve konuşma tarzı.
# Görseller "Müşteri Karakterleri" tasarım dosyasından alınan SVG'lerdir (assets/characters/).

@export var display_name: String = ""
@export var role: String = "" ## Karakter tipi (örn. "Antika Meraklısı")
@export var texture: Texture2D
@export var accent: Color = Color("#E1A83A") ## Konuşma balonundaki isim etiketinin rengi
@export var greeting: String = "" ## Tezgâha gelince şikâyetten önce söylediği söz
@export var thanks_line: String = "" ## Memnun kalınca söylediği kendine özgü söz
