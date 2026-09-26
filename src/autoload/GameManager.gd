extends Node

# Oyun durumu yöneticisi (GameManager)
# Oyunun genel durumunu ve parça montajlarını takip eder.

var cpu_state: String = "locked_empty" # Durumlar: locked_empty, open, installed, locked_full, painting, paste_applied, screwing_fan, fan_mounted
var placed_parts: Dictionary = {}
var total_required_parts: int = 10
var fan_mounted: bool = false
var build_complete: bool = false

func _ready() -> void:
	# EventBus sinyallerine bağlanma
	EventBus.part_installed.connect(_on_part_installed)
	EventBus.part_removed.connect(_on_part_removed)
	EventBus.fan_mounted.connect(_on_fan_mounted)

# Parça yerleştirmeyi dener
func try_place_part(slot_id: String, part_type: String) -> bool:
	if placed_parts.has(slot_id):
		return false
	return true # Gerçek mantık buraya eklenebilir

# Yapının tamamlanıp tamamlanmadığını kontrol eder
func is_build_complete() -> bool:
	if placed_parts.size() >= total_required_parts and fan_mounted:
		if not build_complete:
			build_complete = true
			EventBus.build_complete.emit()
		return true
	return false

# Yapıyı sıfırlar
func reset_build() -> void:
	cpu_state = "locked_empty"
	placed_parts.clear()
	fan_mounted = false
	build_complete = false

func _on_part_installed(slot_id: String, part_data: Resource) -> void:
	placed_parts[slot_id] = part_data
	is_build_complete()

func _on_part_removed(slot_id: String) -> void:
	placed_parts.erase(slot_id)

func _on_fan_mounted() -> void:
	fan_mounted = true
	is_build_complete()
