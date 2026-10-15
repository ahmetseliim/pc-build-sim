extends Node

# Oyun durumu yöneticisi (GameManager)
# Oyunun genel durumunu ve parça montajlarını takip eder.

var cpu_state: String = "locked_empty" # Durumlar: locked_empty, open, installed, locked_full, painting, paste_applied, screwing_fan, fan_mounted
var placed_count: int = 0
var total_required_parts: int = 13 # 8 parça + 5 kablo
var fan_mounted: bool = false
var build_complete: bool = false

func _ready() -> void:
	# EventBus sinyallerine bağlanma
	EventBus.part_installed.connect(_on_part_installed)
	EventBus.fan_mounted.connect(_on_fan_mounted)

# CPU soketinin durumunu değiştirir ve herkese duyurur
func set_cpu_state(state: String) -> void:
	cpu_state = state
	EventBus.cpu_state_changed.emit(state)

# Yapıyı sıfırlar
func reset_build() -> void:
	cpu_state = "locked_empty"
	placed_count = 0
	fan_mounted = false
	build_complete = false

func _on_part_installed(_slot_id: String, part_data: Resource) -> void:
	# Fan, vidaları sıkılınca sayılır
	if (part_data as ComponentData).part_type == "fan":
		return
	_increment_placed()

func _on_fan_mounted() -> void:
	fan_mounted = true
	set_cpu_state("fan_mounted")
	_increment_placed()

func _increment_placed() -> void:
	placed_count += 1
	if placed_count >= total_required_parts and not build_complete:
		build_complete = true
		EventBus.build_complete.emit()
