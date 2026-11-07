class_name BoardData
extends Resource

# Anakart Verisi (BoardData)
# Bir anakart modelinin bilgilerini ve görünümünü tutar. Yuvaların yerleşimi
# `scene_path` ile verilen sahnededir; kod (Motherboard.gd) tüm kartlarda ortaktır.

@export var display_name: String = "" ## İş emrinde görünen ad, örn. "Modern Oyuncu PC"
@export var title: String = "" ## Kartın üstüne basılı yazı
@export var era: String = "" ## Dönem, örn. "2013" ya da "Güncel"
@export var form_factor: String = "ATX" ## ATX, mATX, ITX
@export var socket: String = "" ## İşlemci soketi, örn. "LGA1700", "AM5"
@export var ram_type: String = "DDR5"
@export var ram_size_gb: int = 16 ## Tek RAM çubuğunun boyutu
@export var onboard_graphics: String = "" ## Ekran kartı yuvası yoksa kullanılan dahili grafik
@export_file("*.tscn") var scene_path: String = ""

@export_group("Görünüm")
@export var pcb_color: Color = Color("#0b192c")
@export var grid_color: Color = Color(30.0 / 255.0, 62.0 / 255.0, 98.0 / 255.0, 0.2)
@export var border_color: Color = Color("#1e3e62")
@export var title_color: Color = Color("#00ffcc")
@export var trace_color: Color = Color(0.3, 0.6, 1.0, 0.1)
