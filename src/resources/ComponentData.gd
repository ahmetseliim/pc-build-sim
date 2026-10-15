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
@export var cable_from: String = "" ## Kablonun çıktığı port: psu_atx, psu_eps, psu_pcie, psu_sata, mb_sata
@export var cable_entry: Vector2 = Vector2.RIGHT ## Kablonun fişten çıktığı yön
