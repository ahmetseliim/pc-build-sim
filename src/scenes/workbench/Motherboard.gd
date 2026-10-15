class_name Motherboard
extends Control

# Anakart yöneticisi
# Anakartı çizer, senaryoya göre hazır parçaları yerleştirir, bırakılan parçaları
# ve kabloları ilgili yuvaya takar, bozuk kabloların sökülmesini yönetir ve
# montaj sırası kurallarını uygular.

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
@onready var fan_slot: MotherboardSlot = $Slots/Fan_Slot
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
	EventBus.part_unplug_requested.connect(_on_part_unplug_requested)
	EventBus.part_extract_requested.connect(_on_part_extract_requested)
	EventBus.part_locked_touched.connect(_on_part_locked_touched)
	for slot: MotherboardSlot in slots:
		if slot.accepted_type == "ram":
			slot.latch_toggled.connect(_on_latch_toggled)
	EventBus.fan_mounted.connect(_check_complete)
	EventBus.fan_unmounted.connect(_on_fan_unmounted)

	_preinstall_scenario_parts()

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

# --- Senaryo: hazır gelen bilgisayar -----------------------------------------

func _preinstall_scenario_parts() -> void:
	var scenario: ScenarioData = GameManager.current_scenario
	if scenario == null or scenario.preinstalled_parts.is_empty():
		return
	var types: Array[String] = scenario.preinstalled_parts
	var cables: Array[ComponentData] = []

	# Önce parçalar
	for type: String in types:
		if type == "paste":
			continue
		var data: ComponentData = InventoryManager.create_part(type)
		if data.is_cable:
			cables.append(data)
			continue
		var slot: MotherboardSlot = _free_slot_for(type)
		if slot == null:
			continue
		var part: PartItem = _new_part(data)
		if type == "cpu":
			slot.install(part, false)
			GameManager.set_cpu_state("locked_full")
			if "paste" in types:
				cpu_socket.apply_paste_instant(scenario.old_paste)
		else:
			slot.install(part, false)
			_after_install(part, true)

	# Arızalı parça: bu türden takılı olanlardan biri rastgele seçilir (görünüşte sağlam)
	if scenario.faulty_part != "":
		var candidates: Array[PartItem] = _placed_parts_of(scenario.faulty_part)
		if not candidates.is_empty():
			var faulty: PartItem = candidates.pick_random()
			faulty.is_broken = true
			faulty.refresh_interaction()
			GameManager.broken_parts.append(scenario.faulty_part)
			GameManager.faulty_slot_label = (faulty.get_parent() as MotherboardSlot).slot_label
	for type: String in scenario.removable_parts:
		for part: PartItem in _placed_parts_of(type):
			part.is_removable = true
			part.refresh_interaction()
		for slot: MotherboardSlot in slots:
			if slot.accepted_type == type:
				slot.latches_interactive = true

	# Sonra kablolar (PSU ve cihazlar takılı olmalı)
	for data: ComponentData in cables:
		var slot: MotherboardSlot = _free_slot_for(data.part_type)
		var origin: Dictionary = get_cable_origin(data.cable_from)
		if slot == null or origin.is_empty():
			continue
		var part: PartItem = _new_part(data)
		part.is_broken = data.part_type in GameManager.scenario_broken
		slot.install(part, false)
		if part.is_broken:
			GameManager.broken_parts.append(data.part_type)
		cable_layer.add_cable(part, origin["point"], origin["dir"], Rect2(slot.position, slot.size), part.is_broken, false)

	_check_complete()

func _new_part(data: ComponentData) -> PartItem:
	var part: PartItem = PartItem.new()
	part.setup(data)
	return part

# Bu türden yuvalara takılı parçalar
func _placed_parts_of(type: String) -> Array[PartItem]:
	var result: Array[PartItem] = []
	for slot: MotherboardSlot in slots:
		if slot.accepted_type != type or not slot.is_occupied:
			continue
		for child: Node in slot.get_children():
			if child is PartItem:
				result.append(child)
	return result

func _free_slot_for(type: String) -> MotherboardSlot:
	for slot: MotherboardSlot in slots:
		if slot.accepted_type == type and not slot.is_occupied:
			return slot
	return null

# --- Sürükle bırak -----------------------------------------------------------

func _on_part_drag_started(part_node: Control) -> void:
	var part: PartItem = part_node as PartItem
	var type: String = part.data.part_type
	# Takılabilecek yuvaları vurgula
	for slot: MotherboardSlot in slots:
		slot.hint = slot.is_visible_in_tree() and not slot.is_occupied and slot.accepted_type == type
	if type == "paste":
		cpu_socket.hint = GameManager.cpu_state == "locked_full"
	elif type == "cloth":
		cpu_socket.hint = GameManager.cpu_state == "paste_old"
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
		elif GameManager.paste_old:
			_reject(part, "Önce fanı söküp eski macunu alkollü bezle temizlemelisin!")
		elif GameManager.cpu_state != "locked_full":
			_reject(part, "Önce işlemciyi takıp kilitlemelisin!")
		else:
			cpu_socket.start_paste(part)
		return

	# Alkollü bez: işlemcideki kurumuş macunu temizleme mini oyunu
	if type == "cloth":
		if slot != cpu_socket:
			_reject(part)
		elif not GameManager.paste_old:
			_reject(part, "Temizlenecek eski macun yok.")
		elif GameManager.fan_mounted:
			_reject(part, "Önce fanı sök (vidalarına basılı tut)!")
		else:
			cpu_socket.start_cleaning(part)
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

	var scenario: ScenarioData = GameManager.current_scenario
	part.is_removable = scenario != null and type in scenario.removable_parts
	slot.install(part)
	# Arızalı parça geri takıldıysa yine arızalı sayılır
	if part.is_broken:
		GameManager.broken_parts.append(type)
		GameManager.faulty_slot_label = slot.slot_label
	_after_install(part, false)
	_check_complete()

# Takılı parça (RAM) yuvasından tutulup çekildi: mandallar açılır, parça eline gelir
func _on_part_extract_requested(part_node: Control) -> void:
	var part: PartItem = part_node as PartItem
	var slot: MotherboardSlot = part.get_parent() as MotherboardSlot
	if slot == null:
		return
	slot.uninstall()
	if part.is_broken:
		GameManager.broken_parts.erase(part.data.part_type)
	# Elde taşınma hissi
	part.pivot_offset = part.size / 2.0
	create_tween().tween_property(part, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_check_complete()

# Mandallar kapalıyken parça tutulmaya çalışıldı: mandalları göster
func _on_part_locked_touched(part_node: Control) -> void:
	var slot: MotherboardSlot = part_node.get_parent() as MotherboardSlot
	if slot:
		slot.flash_latches()
	EventBus.warning_requested.emit("Önce RAM yuvasının iki ucundaki mandalları aç (mandallara tıkla)!")

# Mandal açıldı/kapandı: ikisi de açıksa RAM yuvasından "klik" diye kalkar, biri kapanırsa geri oturur
func _on_latch_toggled(slot: MotherboardSlot) -> void:
	var parts: Array[PartItem] = []
	for child: Node in slot.get_children():
		if child is PartItem:
			parts.append(child)
	if parts.is_empty() or not parts[0].is_removable:
		return
	var part: PartItem = parts[0]
	part.pivot_offset = part.size / 2.0
	if slot.latches_open() and not part.is_loose:
		part.is_loose = true
		var pop: Tween = create_tween().set_parallel(true)
		pop.tween_property(part, "position:y", -8.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(part, "scale", Vector2(1.05, 1.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not slot.latches_open() and part.is_loose:
		part.is_loose = false
		var seat: Tween = create_tween().set_parallel(true)
		seat.tween_property(part, "position:y", 0.0, 0.12)
		seat.tween_property(part, "scale", Vector2.ONE, 0.12)
	part.refresh_interaction()

# Parça takıldıktan sonraki ek işler (fan vidaları, cihaz konnektörleri)
func _after_install(part: PartItem, prelocked: bool) -> void:
	match part.data.part_type:
		"fan":
			if not prelocked:
				GameManager.set_cpu_state("screwing_fan")
			var screws: ScrewMechanic = ScrewMechanicScene.instantiate()
			part.add_child(screws)
			screws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			screws.start(prelocked)
		"gpu":
			_reveal(gpu_power, not prelocked)
		"sata":
			_reveal(sata_power, not prelocked)
			_reveal(sata_data, not prelocked)

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
		if slot.accepted_type == part.data.part_type and slot.is_visible_in_tree() \
				and slot.get_global_rect().grow(CABLE_SNAP).has_point(global_point):
			target = slot
			break
	if target == null:
		_reject(part)
		return
	if target.is_occupied:
		if part.data.part_type in GameManager.broken_parts:
			_reject(part, "Önce bozuk kabloyu sök (fişine tıkla)!")
		else:
			_reject(part)
		return

	target.install(part)
	cable_layer.add_cable(part, origin["point"], origin["dir"], Rect2(target.position, target.size))
	_check_complete()

# Bozuk kablonun fişine tıklandı: kabloyu sök ve at
func _on_part_unplug_requested(part_node: Control) -> void:
	var part: PartItem = part_node as PartItem
	var slot: MotherboardSlot = part.get_parent() as MotherboardSlot
	if slot == null:
		return
	# Animasyon sürerken tekrar tıklanmasın
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.mouse_default_cursor_shape = Control.CURSOR_ARROW
	slot.uninstall()
	GameManager.broken_parts.erase(part.data.part_type)
	_check_complete()
	await _animate_cable_removal(part, slot)
	EventBus.info_requested.emit("Bozuk kablo söküldü ve atıldı. Envanterden yenisini tak.")
	part.queue_free()

# Kablo söküm animasyonu: fiş kilidinden kurtulana kadar sallanır, "pop" diye çıkar,
# ardından kablo güç kaynağına doğru toplanarak kaybolur.
func _animate_cable_removal(part: PartItem, slot: MotherboardSlot) -> void:
	var origin: Dictionary = get_cable_origin(part.data.cable_from)
	var dir: Vector2 = part.data.cable_entry
	cable_layer.follow_part(part)
	_lift_to_drag_layer(part)
	var start: Vector2 = part.global_position

	var pull: Tween = create_tween()
	for i: int in range(3):
		pull.tween_property(part, "global_position", start + dir * 3.0, 0.05)
		pull.tween_property(part, "global_position", start - dir * 1.0, 0.05)
	pull.tween_callback(cable_layer.pop_at.bind(slot.position + slot.size / 2.0, part.data.cable_color))
	pull.tween_property(part, "global_position", start + dir * 34.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pull.tween_interval(0.15)
	await pull.finished

	if not origin.is_empty():
		var target: Vector2 = cable_layer.global_position + origin["point"] - part.size / 2.0
		var reel: Tween = create_tween().set_parallel(true)
		reel.tween_property(part, "global_position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		reel.tween_property(part, "scale", Vector2(0.4, 0.4), 0.45).set_ease(Tween.EASE_IN)
		reel.tween_property(part, "modulate:a", 0.0, 0.15).set_delay(0.3)
		await reel.finished
	cable_layer.remove_cable(part)

func _lift_to_drag_layer(part: PartItem) -> void:
	var layer: Node = get_tree().get_first_node_in_group("drag_layer")
	if layer:
		part.reparent(layer)
	part.pivot_offset = part.size / 2.0

# Fanın dört vidası söküldü: fanı yuvadan çıkarıp envantere geri koy
func _on_fan_unmounted() -> void:
	for child: Node in fan_slot.get_children():
		if child is PartItem:
			var fan: PartItem = child as PartItem
			fan_slot.uninstall()
			var screws: Node = fan.get_node_or_null("ScrewMechanic")
			if screws:
				screws.queue_free()
			fan.unplace()
			EventBus.part_return_requested.emit(fan)
			break
	EventBus.info_requested.emit("Fan söküldü. Şimdi eski macunu temizle.")
	_check_complete()

# Tüm yuvalar dolu, fan vidalı, macun yeni ve bozuk kablo yoksa bilgisayar hazırdır
func _check_complete() -> void:
	var done: bool = GameManager.fan_mounted and not GameManager.paste_old and GameManager.broken_parts.is_empty()
	for slot: MotherboardSlot in slots:
		if not slot.is_occupied:
			done = false
	GameManager.mark_complete(done)

func _reveal(slot: MotherboardSlot, animate: bool) -> void:
	slot.visible = true
	if animate:
		slot.modulate.a = 0.0
		create_tween().tween_property(slot, "modulate:a", 1.0, 0.3)

func _reject(part: PartItem, message: String = "") -> void:
	if message != "":
		EventBus.warning_requested.emit(message)
	EventBus.part_return_requested.emit(part)

# --- Çizim -------------------------------------------------------------------

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
