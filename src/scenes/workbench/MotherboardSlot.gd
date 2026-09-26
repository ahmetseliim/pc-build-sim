class_name MotherboardSlot
extends Area2D

# Anakart üzerindeki tekrar kullanılabilir slot bileşeni
# CPU, RAM, GPU, M.2 gibi farklı parça tipleri için kullanılır.

@export var slot_id: String = "" ## Slot tanımlayıcısı (orn: "cpu_socket", "ram_1")
@export var accepted_type: String = "" ## Kabul edilen parça tipi (orn: "cpu", "ram")
@export var accepted_socket: String = "" ## Kabul edilen soket tipi (orn: "AM5", "LGA1700")
@export var slot_label: String = "" ## Slot etiketi (görselde gözükecek)
@export var requires_state: String = "" ## Bu slot için gereken GameManager cpu_state

var is_occupied: bool = false
var installed_part: ComponentData = null

# Slot doluyken görsel güncelleme sinyali
signal slot_filled(slot: MotherboardSlot)
signal slot_emptied(slot: MotherboardSlot)

func _ready() -> void:
	# Fare/touch algılama için giriş olaylarını etkinleştir
	input_pickable = true
	monitoring = true
	monitorable = true

# Parça yerleştirmeyi dener
func try_install(part: ComponentData) -> bool:
	if is_occupied:
		print("Slot zaten dolu: %s" % slot_id)
		return false
	
	# Tip kontrolu
	if part.part_type != accepted_type:
		print("Yanlış parça tipi! Beklenen: %s, Gelen: %s" % [accepted_type, part.part_type])
		return false
	
	# Soket kontrolu (eğer tanımlıysa)
	if accepted_socket != "" and part.socket != accepted_socket:
		print("Uyumsuz soket! Beklenen: %s, Gelen: %s" % [accepted_socket, part.socket])
		return false
	
	# State kontrolu (CPU için mandal açık mı?)
	if requires_state != "" and GameManager.cpu_state != requires_state:
		print("Gerekli durum sağlanmadı: %s" % requires_state)
		return false
	
	# Yerleştir
	installed_part = part
	is_occupied = true
	slot_filled.emit(self)
	EventBus.part_installed.emit(slot_id, part)
	print("✅ %s parçası %s slotuna yerleştirildi." % [part.part_name, slot_id])
	return true

# Parçayı çıkar
func remove_part() -> ComponentData:
	if not is_occupied:
		return null
	
	var removed: ComponentData = installed_part
	installed_part = null
	is_occupied = false
	slot_emptied.emit(self)
	EventBus.part_removed.emit(slot_id)
	return removed

# Vurgulama (parça üzerinde sürüklenirken)
func highlight(enable: bool) -> void:
	if enable:
		modulate = Color(0.5, 1.0, 0.5, 1.0) # Yeşil vurgu
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0) # Normal
