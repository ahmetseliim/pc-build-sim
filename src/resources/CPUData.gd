class_name CPUData
extends ComponentData

# İşlemci Verisi (CPUData)

@export var cores: int = 0
@export var clock_speed: float = 0.0 # GHz cinsinden
@export var tdp: int = 0 # Watt cinsinden
@export var has_igpu: bool = false

func _init() -> void:
	part_type = "cpu"
