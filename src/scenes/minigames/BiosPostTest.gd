class_name BiosPostTest
extends Control

# BIOS POST test ekranı
# "Bilgisayarı Başlat"a basılınca satır satır açılış mesajları gösterir.
# Takılı parçaları ve kabloları kontrol eder; arıza varsa kırmızı hata satırıyla
# durur ve tıklayınca tamire geri döner. Başarılıysa tıklayınca menüye döner.

const OK_COLOR: String = "#00ff66"
const FAIL_COLOR: String = "#ff5f5f"
const NOTE_COLOR: String = "#94a3b8"
const BIOS_TODAY: Array[int] = [15, 11, 2026] ## Dükkân takvimindeki tarih (gün, ay, yıl): saat işinde BIOS'a girilmesi gereken tarih
const DEFAULT_DATE: Array[int] = [1, 1, 2000] ## CMOS sıfırlanınca BIOS'un döndüğü tarih
## Gizli arıza bip kodları: tür -> [bip deseni (L: uzun, S: kısa), POST kartı kodu, POST kartının çözdüğü anlam]
const HIDDEN_CODES: Dictionary = {
	"ram": ["LSSS", "0x2A", "Bellek testi başarısız"],
	"gpu": ["LSSSS", "0x3D", "Ekran kartı cevap vermiyor (PCIe Slot 1)"],
	"m2": ["LL", "0x5C", "M.2 NVMe disk cevap vermiyor"],
}

@onready var bios_text: RichTextLabel = $BiosText
@onready var boot_timer: Timer = $BootTimer

# Her satır: [metin, renk]
var boot_sequence: Array = []
var current_line: int = 0
var is_running: bool = false
var boot_ok: bool = false
var can_close: bool = false
var needs_date: bool = false ## POST geçti ama CMOS tarihi sıfır: BIOS Setup'ta tarih ayarlanmalı (arıza sayılmaz)
var date_value: Array[int] = [1, 1, 2000] ## Tarih ekranında ayarlanan değer: gün, ay, yıl
var date_panel: PanelContainer = null
var _date_label: Label = null
var _latent_checked: bool = false

func _ready() -> void:
	visible = false
	bios_text.bbcode_enabled = true
	bios_text.add_theme_font_override("normal_font", UIStyle.mono_font())
	bios_text.add_theme_font_size_override("normal_font_size", UIStyle.scaled(get_viewport(), 16))
	bios_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.bios_boot_requested.connect(start_boot)
	boot_timer.wait_time = 0.28
	boot_timer.one_shot = false
	boot_timer.timeout.connect(_print_next_line)
	_build_date_panel()

func start_boot() -> void:
	if date_panel:
		date_panel.visible = false
	_build_sequence()
	visible = true
	current_line = 0
	can_close = false
	bios_text.clear()
	is_running = true
	EventBus.bios_boot_started.emit()
	boot_timer.start()

# Takılı parçalara göre POST satırlarını hazırlar
func _build_sequence() -> void:
	boot_sequence.clear()
	boot_ok = true
	needs_date = false
	# Arızalı güç kaynağı: düğmeye basılır ama hiçbir şey olmaz (BIOS bile açılmaz)
	if "psu" in GameManager.broken_parts:
		_fail("Power Button pressed: NO RESPONSE")
		_fail("PSU: NO POWER OUTPUT — 12V / 5V RAILS DEAD")
		_halt()
		return
	_ok("BIOS DATE: 09/11/2026 15:15:00 VER: 2.10.128")
	if not GameManager.is_working("atx24"):
		_fail("Motherboard Power (ATX 24-Pin): NO SIGNAL")
		_halt()
		return
	var scenario: ScenarioData = GameManager.current_scenario
	var power_check: bool = scenario != null and scenario.power_check
	var psu_watt: int = PowerCalc.psu_watt_of(GameManager.installed_part_of("psu"))
	_ok("PSU: %dW 80+ Gold ... OK" % (psu_watt if power_check else 750))
	_ok("ATX 24-Pin Rail: 12V / 5V / 3.3V STABLE")
	if not GameManager.is_working("eps8"):
		_fail("CPU Power (EPS 8-Pin): NOT DETECTED")
		_fail("CPU: NOT INITIALIZED")
		_halt()
		return
	_ok("CPU Power (EPS 8-Pin): CONNECTED")
	var socket: String = GameManager.current_board.socket if GameManager.current_board else ""
	match socket:
		"LGA1150":
			_ok("CPU: Intel Core i5-4590 @ 3.30GHz (LGA1150)")
		"AM5":
			_ok("CPU: AMD Ryzen 7 7800X3D @ 4.20GHz (AM5)")
		_:
			_ok("CPU: Intel Core i7-14700K @ 5.40GHz (LGA1700)")
	if GameManager.board_has("cmos") or (scenario != null and scenario.clock_reset):
		if _check_cmos():
			return
	if not GameManager.fan_mounted:
		_fail("CPU_FAN: NOT DETECTED")
		_fail("CPU Temperature: 105°C — CRITICAL, SHUTTING DOWN")
		_halt()
		return
	if GameManager.board_has("cpufan") and not GameManager.is_working("cpufan"):
		_fail("CPU_FAN Speed: 0 RPM — NOT DETECTED")
		_ok("")
		_fail("CPU Fan Error!")
		_fail("Press F1 to Resume")
		_halt()
		return
	if GameManager.paste_old:
		_ok("CPU_FAN Speed: 3800 RPM ... MAX")
		_fail("CPU Temperature: 96°C — OVERHEAT WARNING")
		_fail("Thermal Interface Material: DRIED / DEGRADED")
		_halt()
		return
	if GameManager.dusty:
		# Toz: macun yeni, fan dönüyor ama ısı dışarı atılamıyor (kasa içi hava akışı kapalı)
		_ok("Thermal Interface Material: APPLIED (TDP Normal)")
		_ok("CPU_FAN Speed: 3900 RPM ... MAX")
		_fail("Heatsink Airflow: RESTRICTED (INTAKE CLOGGED)")
		_fail("CPU Temperature: 94°C — THERMAL THROTTLING ACTIVE")
		_fail("CPU Clock: 5400 MHz -> 1200 MHz (THROTTLED)")
		_halt()
		return
	_ok("Thermal Interface Material: APPLIED (TDP Normal)")
	_ok("CPU_FAN Speed: 1520 RPM ... OPTIMAL")
	_ok("CPU Temperature: 42°C ... NORMAL")
	var ram_count: int = GameManager.installed.get("ram", 0)
	# Gizli arıza: BIOS neyin bozuk olduğunu söylemez, yalnız bip kodu verir (POST kartı varsa kod çözülür)
	if GameManager.hidden_fault_type != "" and GameManager.hidden_fault_type in GameManager.broken_parts:
		_hidden_fault_output(GameManager.hidden_fault_type)
		return
	if "ram" in GameManager.broken_parts:
		_fail("Memory: %s — MEMORY TEST FAILED at 0x3F2A0000" % _dimm_name(GameManager.faulty_slot_label))
		_fail("*** BEEP BEEP BEEP (Memory Error) ***")
		_halt()
		return
	# Kartın RAM türü ve boyutu
	var board: BoardData = GameManager.current_board
	var ram_type: String = board.ram_type if board else "DDR5"
	var stick_mb: int = (board.ram_size_gb if board else 16) * 1024
	if ram_count >= 2:
		_ok("Memory: %dMB OK (%s Dual Channel)" % [stick_mb * ram_count, ram_type])
	elif ram_count == 1:
		_fail("Memory: %dMB (Single Channel) — 1 DIMM SLOT EMPTY" % stick_mb)
	else:
		_fail("Memory: NO DIMM DETECTED")
		_fail("*** BEEP — BEEP — BEEP (No Memory) ***")
		_halt()
		return

	# Diskler: M.2'li kartta sistem diski M.2'dir; M.2'siz eski kartta SATA disk
	var sata_ok: bool = GameManager.is_working("sata") and GameManager.is_working("satapwr") and GameManager.is_working("satadata")
	var boot_drive_ok: bool = sata_ok
	if GameManager.board_has("m2"):
		boot_drive_ok = GameManager.is_working("m2") and GameManager.m2_secured
		if boot_drive_ok:
			_ok("Storage: M.2 NVMe Primary SSD OK")
		elif "m2" in GameManager.broken_parts:
			_fail("Storage: M.2 NVMe — NOT RESPONDING (S.M.A.R.T. FAILURE)")
		else:
			_fail("Storage: M.2 NVMe — NOT DETECTED")
	# Eski SATA diski sökülebilen işte (NVMe yükseltme) disk sökülmüşse BIOS SATA aramaz
	var sata_removed: bool = GameManager.sata_is_optional() and GameManager.installed.get("sata", 0) == 0
	if GameManager.board_has("sata") and not sata_removed:
		var role: String = "Secondary" if GameManager.board_has("m2") else "Primary"
		if sata_ok:
			_ok("Storage: SATA SSD %s (6 Gb/s) OK" % role)
		else:
			_fail("Storage: SATA SSD %s — NOT FOUND" % role)

	# Ekran kartı; yuvası olmayan kartta işlemcinin dahili grafiği
	if not GameManager.board_has("gpu"):
		_ok("Onboard Graphics: %s ... OK" % (board.onboard_graphics if board else "iGPU"))
	elif "gpu" in GameManager.broken_parts:
		# Arızalı ekran kartı: kablo takılı ama kart cevap vermez, görüntü gelmez, kasa bip kodu verir
		_fail("PCIe Slot 1: GPU NOT RESPONDING — NO VIDEO SIGNAL")
		_fail("*** BEEP — BEEP BEEP BEEP (Video Card Error) ***")
		_halt()
		return
	elif GameManager.is_working("gpu") and GameManager.is_working("pcie8"):
		_ok("PCIe Slot 1: Discrete GPU Initialized")
		_ok("GPU Power (PCIe 8-Pin): CONNECTED")
		if power_check:
			var gpu_watt: int = PowerCalc.gpu_watt_of(GameManager.installed_part_of("gpu"))
			if PowerCalc.enough(psu_watt, gpu_watt):
				_ok("Power Budget: %dW of %dW SAFE LIMIT (%dW PSU) ... OK" % [PowerCalc.total_load(gpu_watt), PowerCalc.psu_limit(psu_watt), psu_watt])
			else:
				_fail("POWER WARNING: GPU %dW + SYSTEM %dW = %dW EXCEEDS PSU SAFE LIMIT %dW (%dW PSU)" % [gpu_watt, PowerCalc.SYSTEM_BASE_WATT, PowerCalc.total_load(gpu_watt), PowerCalc.psu_limit(psu_watt), psu_watt])
				_fail("*** BEEP BEEP BEEP BEEP (Power Overload) ***")
				_fail("PSU yetersiz: en az %d W güç kaynağı gerekir" % PowerCalc.needed_psu_watt(gpu_watt))
				_halt()
				return
	else:
		_fail("GPU Power (PCIe 8-Pin): NOT DETECTED")
		_fail("PCIe Slot 1: GPU NOT RESPONDING")
	if not boot_drive_ok:
		_ok("")
		_fail("Reboot and Select proper Boot device")
		_fail("or Insert Boot Media in selected Boot device and press a key")
	if not boot_ok:
		_halt()
		return
	# Çift arıza: ilk arıza çözüldü, ikincisi şimdi ortaya çıkar ve POST baştan koşturulur
	if GameManager.latent_pending and not _latent_checked:
		_latent_checked = true
		GameManager.latent_pending = false
		EventBus.latent_fault_triggered.emit(GameManager.latent_fault_type)
		_build_sequence()
		_latent_checked = false
		return
	# Saat sıfırlanması: pil sağlam ama tarih yok; BIOS Setup'ta ayarlanmalı
	if GameManager.clock_pending:
		_ok("")
		_fail("System Date/Time: NOT SET (01/01/2000) — Enter BIOS Setup")
		_line("", OK_COLOR)
		_line("(Tarihi ayarlamak için tıkla)", NOTE_COLOR)
		needs_date = true
		return
	_ok("Booting into OS...")
	_ok("")
	_ok("⚡ TEBRİKLER! BİLGİSAYAR SORUNSUZ ÇALIŞIYOR. MÜŞTERİYE TESLİM EDİLEBİLİR!")
	_line("", OK_COLOR)
	_line("(Ödemeyi almak için tıkla)" if CareerManager.is_career else "(Menüye dönmek için tıkla)", NOTE_COLOR)

# CMOS pili: bitikse BIOS saati sıfırlar ve durur. Dönüş: true -> POST burada bitti (_halt çağrıldı)
func _check_cmos() -> bool:
	if GameManager.installed.get("cmos", 0) == 0:
		_fail("CMOS Battery: NOT DETECTED")
	elif "cmos" in GameManager.broken_parts:
		_fail("CMOS Checksum Error — CMOS Battery: 0.4V LOW")
		_fail("System Date/Time reset to default (01/01/2000)")
	else:
		_ok("CMOS Battery: 3.0V ... OK")
		return false
	_fail("Press F1 to Resume")
	_halt()
	return true

# Gizli arıza: bip kodu (POST kartı varsa kod çözülüp arızalı parça yazılır); BIOS başka bir şey söylemez
func _hidden_fault_output(type: String) -> void:
	var code: Array = HIDDEN_CODES[type]
	var beeps: PackedStringArray = PackedStringArray()
	for letter: String in (code[0] as String):
		beeps.append("BEEEP" if letter == "L" else "bip")
	_fail("POST: HARDWARE FAULT — NO DISPLAY")
	_fail("*** %s ***" % " ".join(beeps))
	_line("", OK_COLOR)
	if CareerManager.post_card_active():
		var detail: String = " — %s" % _dimm_name(GameManager.faulty_slot_label) if type == "ram" and GameManager.faulty_slot_label != "" else ""
		_line("POST KARTI [%s]: %s%s" % [code[1], code[2], detail], "#38bdf8")
	else:
		_line("(Bip kodunun anlamı bilinmiyor. POST kartı kodu okuyabilirdi.)", NOTE_COLOR)
	_halt()

# --- BIOS Setup: tarih ekranı (saat sıfırlanıyor işi) ----------------------------

func _build_date_panel() -> void:
	date_value = DEFAULT_DATE.duplicate()
	date_panel = PanelContainer.new()
	var style: StyleBoxFlat = UIStyle.box(Color("#0b1220"), 8, 2, Color("#38bdf8"), Color(0, 0, 0, 0.6), 14, Vector2(0, 8))
	style.set_content_margin_all(20)
	date_panel.add_theme_stylebox_override("panel", style)
	date_panel.visible = false
	date_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	date_panel.add_child(box)
	box.add_child(_setup_label("BIOS SETUP — System Date", 18, "#38bdf8"))
	box.add_child(_setup_label("Dükkân takvimi: %02d.%02d.%d" % BIOS_TODAY, 14, "#fbbf24"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var names: Array[String] = ["Gün", "Ay", "Yıl"]
	for field: int in range(3):
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.add_child(_setup_label(names[field], 12, NOTE_COLOR))
		col.add_child(_setup_button("▲", date_step.bind(field, 1)))
		var value_label: Label = _setup_label("", 22, "#ffffff")
		value_label.name = "Value%d" % field
		col.add_child(value_label)
		col.add_child(_setup_button("▼", date_step.bind(field, -1)))
		row.add_child(col)
	_date_label = _setup_label("", 12, NOTE_COLOR)
	box.add_child(_date_label)
	box.add_child(_setup_button("KAYDET VE ÇIK", date_save))
	add_child(date_panel)
	_refresh_date_panel()

func _setup_label(text: String, size: int, color: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIStyle.mono_font())
	label.add_theme_font_size_override("font_size", UIStyle.scaled(get_viewport(), size))
	label.add_theme_color_override("font_color", Color(color))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _setup_button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(70, 36) * UIStyle.ui_scale(get_viewport())
	button.add_theme_font_override("font", UIStyle.mono_font())
	button.add_theme_font_size_override("font_size", UIStyle.scaled(get_viewport(), 16))
	button.pressed.connect(action)
	return button

func _open_date_screen() -> void:
	date_value = DEFAULT_DATE.duplicate()
	_refresh_date_panel()
	date_panel.visible = true

# Tarih alanını (0 gün, 1 ay, 2 yıl) bir adım değiştirir; sınırlarda döner
func date_step(field: int, delta: int) -> void:
	var limits: Array = [[1, 31], [1, 12], [2000, 2035]]
	var low: int = limits[field][0]
	var high: int = limits[field][1]
	var next: int = date_value[field] + delta
	if next > high:
		next = low
	elif next < low:
		next = high
	date_value[field] = next
	_refresh_date_panel()

func _refresh_date_panel() -> void:
	for field: int in range(3):
		var label: Label = date_panel.find_child("Value%d" % field, true, false) as Label
		if label:
			label.text = ("%04d" if field == 2 else "%02d") % date_value[field]
	_date_label.text = ""

# Kaydet: tarih dükkân takvimiyle aynıysa saat ayarlıdır ve POST baştan koşar; değilse uyarır. Dönüş: kabul edildi mi
func date_save() -> bool:
	if date_value != BIOS_TODAY:
		_date_label.text = "Tarih takvimle uyuşmuyor!"
		EventBus.warning_requested.emit("Tarih yanlış: dükkân takvimindeki günü ayarla.")
		return false
	GameManager.clock_pending = false
	date_panel.visible = false
	start_boot()
	return true

# "RAM 2" -> "DIMM_A2 (RAM 2)"
func _dimm_name(slot_label: String) -> String:
	return "DIMM_A%s (%s)" % [slot_label.get_slice(" ", 1), slot_label]

func _ok(text: String) -> void:
	_line(text, OK_COLOR)

func _fail(text: String) -> void:
	boot_ok = false
	_line(text, FAIL_COLOR)

func _halt() -> void:
	boot_ok = false
	_line("", OK_COLOR)
	_line("✖ SYSTEM HALTED — ARIZA TESPİT EDİLDİ", FAIL_COLOR)
	_line("", OK_COLOR)
	_line("(Tamire dönmek için tıkla)", NOTE_COLOR)

func _line(text: String, color: String) -> void:
	boot_sequence.append([text, color])

func _print_next_line() -> void:
	if current_line < boot_sequence.size():
		var entry: Array = boot_sequence[current_line]
		bios_text.push_color(Color(entry[1]))
		bios_text.add_text(entry[0])
		bios_text.pop()
		bios_text.newline()
		current_line += 1
	else:
		boot_timer.stop()
		is_running = false
		can_close = true
		if boot_ok:
			EventBus.bios_boot_finished.emit()
		elif not needs_date: # Tarih ayarı bekleyen POST arıza değildir (BIOS Setup'a girilir)
			EventBus.boot_failed.emit()

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not (mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
		return
	accept_event()
	# Yazılırken tıklanırsa kalan satırları hemen göster
	if is_running:
		while is_running:
			_print_next_line()
		return
	if not can_close:
		return
	if needs_date:
		_open_date_screen()
		return
	if boot_ok:
		if CareerManager.is_career:
			CareerManager.finish_job()
		else:
			GameManager.go_to_menu()
	else:
		visible = false
