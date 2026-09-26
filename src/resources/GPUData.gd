class_name GPUData
extends ComponentData

# Ekran Kartı Verisi (GPUData)

@export var vram_gb: int = 0
@export var gpu_clock: float = 0.0 # MHz cinsinden
@export var power_draw: int = 0 # Watt cinsinden
@export var length_mm: int = 0
@export var pcie_gen: int = 4

func _init() -> void:
	part_type = "gpu"
