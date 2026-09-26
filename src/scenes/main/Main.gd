class_name Main
extends Node2D

# Ana sahne yöneticisi
# Tüm alt sahneleri yükler ve oyun akışını kontrol eder.

@onready var workbench: Node2D = $Workbench

func _ready() -> void:
	# EventBus sinyallerine bağlan
	EventBus.build_complete.connect(_on_build_complete)

func _on_build_complete() -> void:
	# Yapım tamamlandı, BIOS boot ekranına geç
	print("Tüm parçalar yerleştirildi! BIOS boot başlatılıyor...")
