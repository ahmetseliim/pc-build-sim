class_name Motherboard
extends Control

# Anakart yöneticisi
# Anakartı çizer, bırakılan parçaları ve kabloları ilgili yuvaya yerleştirir
# ve montaj sırası kurallarını uygular.

const BOARD_SIZE: Vector2 = Vector2(960, 540)
const BORDER: float = 3.0
const GRID_STEP: float = 20.0
const GRID_COLOR: Color = Color(30.0 / 255.0, 62.0 / 255.0, 98.0 / 255.0, 0.2)
const TRACE_COLOR: Color = Color(0.3, 0.6, 1.0, 0.1)
const TITLE: String = "ANAKART • Z790 • DDR5 EXPERT"
const TITLE_POS: Vector2 = Vector2(38, 28)
const SATA_PORT_RECT: Rect2 = Rect2(300, 478, 34, 16) ## SATA veri kablosunun çıktığı anakart portu
const MOUNT_HOLES: Array[Vector2] = [Vector2(20, 20), Vector2(940, 20), Vector2(20, 520), Vector2(940, 520), Vector2(460, 215)]
const CABLE_SNAP: float = 14.0 ## Küçük konnektörler için bırakma toleransı (px)
const ScrewMechanicScene: PackedScene = preload("res://src/scenes/minigames/ScrewMechanic.tscn")

var slots: Array[MotherboardSlot] = []

@onready var cpu_socket: CpuSocket = $Slots/CPU_Socket
@onready var gpu_slot: MotherboardSlot = $Slots/GPU_Slot
@onready var sata_slot: MotherboardSlot = $Slots/SATA_Slot
@onready var psu_slot: MotherboardSlot = $Slots/PSU_Slot
@onready var gpu_power: MotherboardSlot = $Slots/GPU_Power
@onready var sata_power: MotherboardSlot = $Slots/SATA_Power
@onready var sata_data: MotherboardSlot = $Slots/SATA_Data
@onready var cable_layer: CableLayer = $CableLayer

func _ready() -> void:
	custom_minimum_size = BOARD_SIZE
	for child: Node in $Slots.get_children():
		if child is MotherboardSlot:
			slots.append(child)

	# Cihaz üzerindeki konnektörler cihaz takılınca belirir
	gpu_power.visible = false
	sata_power.visible = false
	sata_data.visible = false

	# EventBus bağlantıları
	EventBus.part_drag_started.connect(_on_part_drag_started)
	EventBus.part_dropped.connect(_on_part_dropped)

# Verilen global noktadaki görünür yuvayı döndürür
func get_slot_at(global_point: Vector2) -> MotherboardSlot:
	for i: int in range(slots.size() - 1, -1, -1):
		if slots[i].is_visible_in_tree() and slots[i].get_global_rect().has_point(global_point):
			return slots[i]
	return null

# Kablonun çıktığı port: {point, dir} (anakart koordinatı). Port yoksa boş sözlük.
func get_cable_origin(port_id: String) -> Dictionary:
	if port_id == "mb_sata":
		return {"point": Vector2(SATA_PORT_RECT.position.x, SATA_PORT_RECT.get_center().y), "dir": Vector2.LEFT}
	if PartArt.PSU_PORTS.has(port_id) and psu_slot.is_occupied:
		var port: Dictionary = PartArt.PSU_PORTS[port_id]
		return {"point": psu_slot.position + port["pos"], "dir": port["dir"]}
	return {}

func _on_part_drag_started(part_node: Control) -> void:
	var part: PartItem = part_node as PartItem
	var type: String = part.data.part_type
	# Takılabilecek yuvaları vurgula
	for slot: MotherboardSlot in slots:
		slot.hint = slot.is_visible_in_tree() and not slot.is_occupied and slot.accepted_type == type
	if type == "paste":
		cpu_socket.hint = GameManager.cpu_state == "locked_full"
	# Kablo tutulduysa kaynağından itibaren çiz
	if part.data.is_cable:
		var origin: Dictionary = get_cable_origin(part.data.cable_from)
		if not origin.is_empty():
			cable_layer.begin_drag(part, origin["point"], origin["dir"])

func _on_part_dropped(part_node: Control, global_point: Vector2) -> void:
	for slot: MotherboardSlot in slots:
		slot.hint = false
	cable_layer.end_drag()

	var part: PartItem = part_node as PartItem
	if part.data.is_cable:
		_drop_cable(part, global_point)
		return

	var slot: MotherboardSlot = get_slot_at(global_point)
	var type: String = part.data.part_type

	# Termal macun bir yuvaya takılmaz, soketin üstünde mini oyunu başlatır
	if type == "paste":
		if slot != cpu_socket:
			_reject(part)
		elif GameManager.cpu_state != "locked_full":
			_reject(part, "Önce işlemciyi takıp kilitlemelisin!")
		else:
			cpu_socket.start_paste(part)
		return

	if slot == null or slot.accepted_type != type or slot.is_occupied:
		_reject(part)
		return

	match type:
		"cpu":
			if GameManager.cpu_state != "open":
				_reject(part, "Önce soket mandalına tıklayarak kilidi açmalısın!")
				return
			GameManager.set_cpu_state("installed")
		"fan":
			if GameManager.cpu_state != "paste_applied":
				_reject(part, "İşlemciye termal macun sürmeden fanı takamazsın!")
				return

	slot.install(part)

	match type:
		"fan":
			GameManager.set_cpu_state("screwing_fan")
			var screws: ScrewMechanic = ScrewMechanicScene.instantiate()
			part.add_child(screws)
			screws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			screws.start()
		"gpu":
			_reveal(gpu_power)
		"sata":
			_reveal(sata_power)
			_reveal(sata_data)

func _drop_cable(part: PartItem, global_point: Vector2) -> void:
	# Anakart dışına bırakıldıysa sessizce envantere dön
	if not get_global_rect().has_point(global_point):
		_reject(part)
		return
	var origin: Dictionary = get_cable_origin(part.data.cable_from)
	if origin.is_empty():
		_reject(part, "Önce güç kaynağını takmalısın!")
		return
	match part.data.part_type:
		"pcie8":
			if not gpu_slot.is_occupied:
				_reject(part, "Önce ekran kartını takmalısın!")
				return
		"satapwr", "satadata":
			if not sata_slot.is_occupied:
				_reject(part, "Önce SATA SSD'yi takmalısın!")
				return

	var target: MotherboardSlot = null
	for slot: MotherboardSlot in slots:
		if slot.accepted_type == part.data.part_type and slot.is_visible_in_tree() and not slot.is_occupied \
				and slot.get_global_rect().grow(CABLE_SNAP).has_point(global_point):
			target = slot
			break
	if target == null:
		_reject(part)
		return

	target.install(part)
	cable_layer.add_cable(part, origin["point"], origin["dir"], Rect2(target.position, target.size))

func _reveal(slot: MotherboardSlot) -> void:
	slot.visible = true
	slot.modulate.a = 0.0
	create_tween().tween_property(slot, "modulate:a", 1.0, 0.3)

func _reject(part: PartItem, message: String = "") -> void:
	if message != "":
		EventBus.warning_requested.emit(message)
	EventBus.part_return_requested.emit(part)

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var canvas: RID = get_canvas_item()

	# 1. Arka plan, yuvarlak köşeler ve gölge
	UIStyle.box(Color("#0b192c"), 12, 0, Color.TRANSPARENT, Color(0, 0, 0, 0.5), 15, Vector2(0, 10)).draw(canvas, rect)

	# 2. Izgara çizgileri (20 px)
	var inner: Rect2 = rect.grow(-BORDER)
	var x: float = inner.position.x + 0.5
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = inner.position.y + 0.5
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP

	# 3. Süslemeler: devre yolları, vida delikleri, SATA portu
	_draw_traces()
	for hole: Vector2 in MOUNT_HOLES:
		draw_circle(hole, 8.0, Color(0.83, 0.69, 0.3, 0.25))
		draw_circle(hole, 5.0, Color("#05101f"))
	_draw_sata_port()

	# 4. Kenarlık
	UIStyle.box(Color.TRANSPARENT, 12, int(BORDER), Color("#1e3e62")).draw(canvas, rect)

	# 5. Başlık
	var font: Font = UIStyle.ui_font(true, 2)
	draw_string(font, TITLE_POS + Vector2(0, font.get_ascent(14)), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#00ffcc"))

func _draw_traces() -> void:
	# İşlemciden RAM'e
	for i: int in range(5):
		var ty: float = 92.0 + i * 9.0
		draw_line(Vector2(153, ty), Vector2(318, ty), TRACE_COLOR, 1.5)
	# İşlemciden M.2'ye ve M.2'den PCIe'ye
	for i: int in range(5):
		var tx: float = 60.0 + i * 16.0
		draw_line(Vector2(tx, 187), Vector2(tx, 227), TRACE_COLOR, 1.5)
		draw_line(Vector2(tx, 265), Vector2(tx, 337), TRACE_COLOR, 1.5)

func _draw_sata_port() -> void:
	var r: Rect2 = SATA_PORT_RECT
	UIStyle.box(Color("#111827"), 2, 1, Color(0.94, 0.27, 0.27, 0.8)).draw(get_canvas_item(), r)
	draw_rect(Rect2(r.position + Vector2(4, 5), Vector2(r.size.x - 10, 4)), Color("#374151"))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 8, 5), Vector2(3, 7)), Color("#374151"))
	_center_text(r.get_center() + Vector2(0, -16), "SATA", 7, Color("#94a3b8"))

func _center_text(center: Vector2, text: String, fs: int, color: Color) -> void:
	var font: Font = UIStyle.ui_font(true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-w / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
