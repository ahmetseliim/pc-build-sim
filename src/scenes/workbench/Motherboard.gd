class_name Motherboard
extends Control

# Anakart yöneticisi (tüm anakart modellerinde ortak)
# Anakartı karta özel renk ve yazıyla çizer, senaryoya göre hazır parçaları yerleştirir,
# bırakılan parçaları ve kabloları ilgili yuvaya takar, söküm işlerini yönetir ve
# montaj sırası kurallarını uygular. Yuvaların yerleşimi her kartın kendi sahnesindedir
# (src/scenes/workbench/boards/); bir kartta olmayan yuvalar (M.2, ekran kartı, SATA) atlanır.

const BORDER: float = 3.0
const GRID_STEP: float = 20.0
const TITLE_POS: Vector2 = Vector2(38, 28)
const CABLE_SNAP: float = 14.0 ## Küçük konnektörler için bırakma toleransı (px)
const ScrewMechanicScene: PackedScene = preload("res://src/scenes/minigames/ScrewMechanic.tscn")

var slots: Array[MotherboardSlot] = []
var board: BoardData = null

@onready var cpu_socket: CpuSocket = $Slots/CPU_Socket
@onready var fan_slot: MotherboardSlot = $Slots/Fan_Slot
@onready var psu_slot: MotherboardSlot = $Slots/PSU_Slot
@onready var cable_layer: CableLayer = $CableLayer
# Her kartta bulunmayabilen yuvalar
@onready var gpu_slot: MotherboardSlot = get_node_or_null("Slots/GPU_Slot")
@onready var gpu_power: MotherboardSlot = get_node_or_null("Slots/GPU_Power")
@onready var sata_slot: MotherboardSlot = get_node_or_null("Slots/SATA_Slot")
@onready var sata_power: MotherboardSlot = get_node_or_null("Slots/SATA_Power")
@onready var sata_data: MotherboardSlot = get_node_or_null("Slots/SATA_Data")
@onready var sata_port: Control = get_node_or_null("SataPort") ## SATA veri kablosunun çıktığı anakart portu

func _ready() -> void:
	custom_minimum_size = size
	board = GameManager.current_board if GameManager.current_board else load(GameManager.DEFAULT_BOARD)
	for child: Node in $Slots.get_children():
		if child is MotherboardSlot:
			slots.append(child)
	GameManager.board_slot_types.clear()
	for slot: MotherboardSlot in slots:
		if not slot.accepted_type in GameManager.board_slot_types:
			GameManager.board_slot_types.append(slot.accepted_type)

	# Cihaz üzerindeki konnektörler cihaz takılınca belirir
	for connector: MotherboardSlot in [gpu_power, sata_power, sata_data]:
		if connector:
			connector.visible = false

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
	if port_id == "fan":
		# Fan kablosu fanın alt kenarından çıkar
		if not fan_slot.is_occupied:
			return {}
		return {"point": fan_slot.position + Vector2(30, fan_slot.size.y), "dir": Vector2.DOWN}
	if port_id == "mb_sata":
		if sata_port == null:
			return {}
		return {"point": Vector2(sata_port.position.x, sata_port.position.y + sata_port.size.y / 2.0), "dir": Vector2.LEFT}
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
		part.is_removable = type in scenario.removable_parts
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

	# Rastgele bozuk kablo: bu kartta gerçekten takılı olacak kablolar arasından seçilir
	if scenario.random_broken_cable:
		var candidates: Array[String] = []
		for data: ComponentData in cables:
			if board_has_slot(data.part_type) and not data.part_type in candidates:
				candidates.append(data.part_type)
		if not candidates.is_empty():
			var pick: String = GameManager.random_cable_pick if GameManager.random_cable_pick in candidates else candidates.pick_random()
			if not pick in GameManager.scenario_broken:
				GameManager.scenario_broken.append(pick)
			if scenario.spare_for_broken:
				var spare: ComponentData = InventoryManager.create_part(pick)
				spare.is_new = true
				InventoryManager.add_part(spare)

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

func board_has_slot(type: String) -> bool:
	for slot: MotherboardSlot in slots:
		if slot.accepted_type == type:
			return true
	return false

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
			_reject(part, "Önce fanı söküp eski macunu alkollü bezle temizlemelisin!", true)
		elif GameManager.cpu_state != "locked_full":
			_reject(part, "Önce işlemciyi takıp kilitlemelisin!", true)
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
			_reject(part, "Önce fanı sök (vidalarına basılı tut)!", true)
		else:
			cpu_socket.start_cleaning(part)
		return

	if slot == null or slot.accepted_type != type or slot.is_occupied:
		_reject(part)
		return

	match type:
		"cpu":
			if GameManager.cpu_state != "open":
				_reject(part, "Önce soket mandalına tıklayarak kilidi açmalısın!", true)
				return
			GameManager.set_cpu_state("installed")
		"fan":
			if GameManager.cpu_state != "paste_applied":
				_reject(part, "İşlemciye termal macun sürmeden fanı takamazsın!", true)
				return

	var scenario: ScenarioData = GameManager.current_scenario
	part.is_removable = scenario != null and type in scenario.removable_parts
	slot.install(part)
	AudioManager.play_sfx("place")
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
	elif not part.data.is_new:
		# Sağlam (asıl) parçayı sökmek yanlış teşhistir
		EventBus.mistake_made.emit("healthy_removed")
	# Elde taşınma hissi
	part.pivot_offset = part.size / 2.0
	create_tween().tween_property(part, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_check_complete()

# Mandallar kapalıyken parça tutulmaya çalışıldı: mandalları göster
func _on_part_locked_touched(part_node: Control) -> void:
	var slot: MotherboardSlot = part_node.get_parent() as MotherboardSlot
	if slot and slot.accepted_type == "ram":
		slot.flash_latches()
		EventBus.warning_requested.emit("Önce RAM yuvasının iki ucundaki mandalları aç (mandallara tıkla)!")
	elif slot and slot.accepted_type == "m2":
		EventBus.warning_requested.emit("Önce SSD'yi sabitleyen vidayı sök (vidaya basılı tut)!")

# M.2 vidası sıkıldı: SSD sabitlendi
func _on_m2_secured() -> void:
	GameManager.m2_secured = true
	_check_complete()

# M.2 vidası söküldü: SSD yaylanarak açılı biçimde yukarı kalkar, artık tutup çekilebilir
func _on_m2_unscrewed(part: PartItem) -> void:
	GameManager.m2_secured = false
	var screws: Node = part.get_node_or_null("ScrewMechanic")
	if screws:
		screws.queue_free()
	part.is_loose = true
	part.pivot_offset = Vector2(0, part.size.y / 2.0) # Altın uç tarafında menteşe gibi
	var pop: Tween = create_tween().set_parallel(true)
	pop.tween_property(part, "rotation", -0.12, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(part, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	part.refresh_interaction()
	EventBus.info_requested.emit("Vida söküldü. SSD'yi tutup envantere taşı.")
	_check_complete()

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
		"m2":
			# Sökülebilir M.2: ucundaki tek vidayla sabitlenir
			if part.is_removable:
				GameManager.m2_secured = false
				var m2_screw: ScrewMechanic = ScrewMechanicScene.instantiate()
				m2_screw.mode = "m2"
				m2_screw.unscrew_allowed = true
				part.add_child(m2_screw)
				m2_screw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				m2_screw.all_screws_done.connect(_on_m2_secured)
				m2_screw.all_screws_removed.connect(_on_m2_unscrewed.bind(part))
				m2_screw.start(prelocked)
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
		if part.data.cable_from == "fan":
			_reject(part, "Önce CPU fanını takmalısın!")
		else:
			_reject(part, "Önce güç kaynağını takmalısın!")
		return
	match part.data.part_type:
		"pcie8":
			if gpu_slot == null:
				_reject(part, "Bu anakartta ekran kartı yuvası yok.")
				return
			if not gpu_slot.is_occupied:
				_reject(part, "Önce ekran kartını takmalısın!")
				return
		"satapwr", "satadata":
			if sata_slot == null:
				_reject(part, "Bu anakartta SATA disk yeri yok.")
				return
			if not sata_slot.is_occupied:
				_reject(part, "Önce SATA SSD'yi takmalısın!")
				return

	var target: MotherboardSlot = null
	for slot: MotherboardSlot in slots:
		if slot.accepted_type == part.data.part_type and slot.is_visible_in_tree() \
				and slot.get_global_rect().grow(CABLE_SNAP * UIStyle.ui_scale(get_viewport())).has_point(global_point):
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
	AudioManager.play_sfx("place")
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
	pull.tween_callback(AudioManager.play_sfx.bind("pop"))
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

# Fanın dört vidası söküldü: önce fan kablosu çıkar, sonra fan yuvadan çıkıp envantere döner
func _on_fan_unmounted() -> void:
	for plug: PartItem in _placed_parts_of("cpufan"):
		var header: MotherboardSlot = plug.get_parent() as MotherboardSlot
		header.uninstall()
		cable_layer.remove_cable(plug)
		if plug.is_broken:
			GameManager.broken_parts.erase("cpufan")
		plug.unplace()
		EventBus.part_return_requested.emit(plug)
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
	EventBus.info_requested.emit("Fan ve kablosu söküldü. Şimdi eski macunu temizle.")
	_check_complete()

# Tüm yuvalar dolu, fan vidalı, macun yeni ve bozuk kablo yoksa bilgisayar hazırdır
func _check_complete() -> void:
	var done: bool = GameManager.fan_mounted and not GameManager.paste_old and GameManager.m2_secured \
		and GameManager.broken_parts.is_empty()
	for slot: MotherboardSlot in slots:
		if not slot.is_occupied:
			done = false
	GameManager.mark_complete(done)

func _reveal(slot: MotherboardSlot, animate: bool) -> void:
	if slot == null:
		return
	slot.visible = true
	if animate:
		slot.modulate.a = 0.0
		create_tween().tween_property(slot, "modulate:a", 1.0, 0.3)

# penalty: parçaya zarar verecek gerçek sıra hatası (yardım mesajları ceza kesmez)
func _reject(part: PartItem, message: String = "", penalty: bool = false) -> void:
	if penalty:
		EventBus.mistake_made.emit("sequence")
	if message != "":
		EventBus.warning_requested.emit(message)
	EventBus.part_return_requested.emit(part)

# --- Çizim -------------------------------------------------------------------

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var canvas: RID = get_canvas_item()

	if board == null:
		return

	# 1. Arka plan, yuvarlak köşeler ve gölge
	UIStyle.box(board.pcb_color, 12, 0, Color.TRANSPARENT, Color(0, 0, 0, 0.5), 15, Vector2(0, 10)).draw(canvas, rect)

	# 2. Izgara çizgileri (20 px)
	var inner: Rect2 = rect.grow(-BORDER)
	var x: float = inner.position.x + 0.5
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), board.grid_color, 1.0)
		x += GRID_STEP
	var y: float = inner.position.y + 0.5
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), board.grid_color, 1.0)
		y += GRID_STEP

	# 3. Süslemeler: arka G/Ç paneli, devre yolları, vida delikleri, SATA portu
	_draw_rear_io()
	_draw_traces()
	for hole: Vector2 in [Vector2(20, 20), Vector2(size.x - 20, 20), Vector2(20, size.y - 20), Vector2(size.x - 20, size.y - 20)]:
		draw_circle(hole, 8.0, Color(0.83, 0.69, 0.3, 0.25))
		draw_circle(hole, 5.0, board.pcb_color.darkened(0.6))
	if sata_port:
		_draw_sata_port()

	# 4. Kenarlık
	UIStyle.box(Color.TRANSPARENT, 12, int(BORDER), board.border_color).draw(canvas, rect)

	# 5. Başlık
	var font: Font = UIStyle.ui_font(true, 2)
	draw_string(font, TITLE_POS + Vector2(0, font.get_ascent(14)), board.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, board.title_color)

# Kartın sol kenarındaki arka G/Ç paneli (USB, ses, ağ portları); sadece görsel, sönük
func _draw_rear_io() -> void:
	var strip: Rect2 = Rect2(7, 60, 18, minf(270.0, size.y - 120.0))
	UIStyle.box(Color(0.55, 0.58, 0.62, 0.22), 3).draw(get_canvas_item(), strip)
	var py: float = strip.position.y + 8.0
	while py < strip.end.y - 14.0:
		draw_rect(Rect2(strip.position.x + 4, py, 10, 12), Color(0, 0, 0, 0.35))
		py += 22.0

# Devre yolları: işlemciden RAM'lere ve aşağıdaki yuvalara (karttaki yuvalara göre)
func _draw_traces() -> void:
	var cpu: Rect2 = Rect2(cpu_socket.position, cpu_socket.size)
	for slot: MotherboardSlot in slots:
		var r: Rect2 = Rect2(slot.position, slot.size)
		if slot.accepted_type == "ram":
			for i: int in range(5):
				var ty: float = cpu.position.y + 20.0 + i * 9.0
				draw_line(Vector2(cpu.end.x, ty), Vector2(r.position.x, ty), board.trace_color, 1.5)
		elif slot.accepted_type in ["m2", "gpu"] and r.position.y > cpu.end.y:
			for i: int in range(5):
				var tx: float = cpu.position.x + 22.0 + i * 16.0
				draw_line(Vector2(tx, cpu.end.y), Vector2(tx, r.position.y), board.trace_color, 1.5)

func _draw_sata_port() -> void:
	var r: Rect2 = Rect2(sata_port.position, sata_port.size)
	UIStyle.box(Color("#111827"), 2, 1, Color(0.94, 0.27, 0.27, 0.8)).draw(get_canvas_item(), r)
	draw_rect(Rect2(r.position + Vector2(4, 5), Vector2(r.size.x - 10, 4)), Color("#374151"))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 8, 5), Vector2(3, 7)), Color("#374151"))
	_center_text(r.get_center() + Vector2(0, -16), "SATA", 7, Color("#94a3b8"))

func _center_text(center: Vector2, text: String, fs: int, color: Color) -> void:
	var font: Font = UIStyle.ui_font(true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-w / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
