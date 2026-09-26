class_name HUD
extends CanvasLayer

# Oyun içi arayüz katmanı
# Skor, durum bilgisi ve başlat butonu içerir.

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton

func _ready() -> void:
	start_button.visible = false
	start_button.pressed.connect(_on_start_pressed)
	EventBus.build_complete.connect(_on_build_complete)
	EventBus.part_installed.connect(_on_part_installed)
	_update_status()

func _update_status() -> void:
	var placed: int = GameManager.placed_parts.size()
	var total: int = GameManager.total_required_parts
	status_label.text = "Parçalar: %d / %d" % [placed, total]

func _on_part_installed(_slot_id: String, _part_data: Resource) -> void:
	_update_status()

func _on_build_complete() -> void:
	status_label.text = "✅ TÜM PARÇALAR YERLEŞTİRİLDİ!"
	start_button.visible = true
	# Buton animasyonu
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.75)
	tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.75)

func _on_start_pressed() -> void:
	print("⚡ Bilgisayar başlatılıyor...")
	# BIOS boot ekranına geçiş sinyali gönder
	EventBus.bios_boot_started.emit()
