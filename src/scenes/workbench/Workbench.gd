class_name Workbench
extends Control

# Montaj masası sahnesi
# Anakart ve tüm slotları yönetir.

@onready var motherboard: Motherboard = $Motherboard

func _ready() -> void:
	print("Montaj masası hazır.")
