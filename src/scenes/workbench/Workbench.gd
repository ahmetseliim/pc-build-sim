class_name Workbench
extends Node2D

# Montaj masası sahnesi
# Anakart ve tüm slotları yönetir.

@onready var motherboard: Node2D = $Motherboard

func _ready() -> void:
	print("Montaj masası hazır.")
