class_name ComponentData
extends Resource

# Temel Bileşen Verisi (ComponentData)
# Tüm parçaların ortak özelliklerini tutar.

@export var part_name: String = ""
@export var part_type: String = ""  # cpu, gpu, ram, m2, fan, paste, cmos, power, cpufan, pwr
@export var socket: String = ""
@export var price: float = 0.0
@export var texture: Texture2D
@export var icon: Texture2D
@export var description: String = ""
@export var is_cable: bool = false
@export var bg_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var icon_text: String = ""
