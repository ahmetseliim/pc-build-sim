class_name BiosPostTest
extends Control

# BIOS POST test ekranı
# "Bilgisayarı Başlat"a basılınca satır satır açılış mesajları gösterir.
# Takılı parçaları ve kabloları kontrol eder; arıza varsa kırmızı hata satırıyla
# durur ve tıklayınca tamire geri döner. Başarılıysa tıklayınca menüye döner.

const OK_COLOR: String = "#00ff66"
const FAIL_COLOR: String = "#ff5f5f"
const NOTE_COLOR: String = "#94a3b8"

@onready var bios_text: RichTextLabel = $BiosText
@onready var boot_timer: Timer = $BootTimer

# Her satır: [metin, renk]
var boot_sequence: Array = []
var current_line: int = 0
var is_running: bool = false
var boot_ok: bool = false
var can_close: bool = false

func _ready() -> void:
	visible = false
	bios_text.bbcode_enabled = true
	bios_text.add_theme_font_override("normal_font", UIStyle.mono_font())
	bios_text.add_theme_font_size_override("normal_font_size", 16)
	bios_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.bios_boot_requested.connect(start_boot)
	boot_timer.wait_time = 0.28
	boot_timer.one_shot = false
	boot_timer.timeout.connect(_print_next_line)

func start_boot() -> void:
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
	_ok("BIOS DATE: 09/11/2026 15:15:00 VER: 2.10.128")
	if not GameManager.is_working("atx24"):
		_fail("Motherboard Power (ATX 24-Pin): NO SIGNAL")
		_halt()
		return
	_ok("PSU: 750W 80+ Gold ... OK")
	_ok("ATX 24-Pin Rail: 12V / 5V / 3.3V STABLE")
	if not GameManager.is_working("eps8"):
		_fail("CPU Power (EPS 8-Pin): NOT DETECTED")
		_fail("CPU: NOT INITIALIZED")
		_halt()
		return
	_ok("CPU Power (EPS 8-Pin): CONNECTED")
	_ok("CPU: Intel Core / AMD Ryzen Detected @ 4.80GHz")
	if not GameManager.fan_mounted:
		_fail("CPU_FAN: NOT DETECTED")
		_fail("CPU Temperature: 105°C — CRITICAL, SHUTTING DOWN")
		_halt()
		return
	if GameManager.paste_old:
		_ok("CPU_FAN Speed: 3800 RPM ... MAX")
		_fail("CPU Temperature: 96°C — OVERHEAT WARNING")
		_fail("Thermal Interface Material: DRIED / DEGRADED")
		_halt()
		return
	_ok("Thermal Interface Material: APPLIED (TDP Normal)")
	_ok("CPU_FAN Speed: 1520 RPM ... OPTIMAL")
	_ok("CPU Temperature: 42°C ... NORMAL")
	var ram_count: int = GameManager.installed.get("ram", 0)
	if "ram" in GameManager.broken_parts:
		_fail("Memory: %s — MEMORY TEST FAILED at 0x3F2A0000" % _dimm_name(GameManager.faulty_slot_label))
		_fail("*** BEEP BEEP BEEP (Memory Error) ***")
		_halt()
		return
	elif ram_count >= 2:
		_ok("Memory: 32768MB OK (DDR5 Dual Channel)")
	elif ram_count == 1:
		_fail("Memory: 16384MB (Single Channel) — 1 DIMM SLOT EMPTY")
	else:
		_fail("Memory: NO DIMM DETECTED")
		_fail("*** BEEP — BEEP — BEEP (No Memory) ***")
		_halt()
		return
	_ok("Storage: M.2 NVMe Primary SSD OK")
	if GameManager.is_working("sata") and GameManager.is_working("satapwr") and GameManager.is_working("satadata"):
		_ok("Storage: SATA SSD (6 Gb/s) OK")
	else:
		_fail("Storage: SATA SSD NOT FOUND")
	if GameManager.is_working("gpu") and GameManager.is_working("pcie8"):
		_ok("PCIe Slot 1: Discrete GPU Initialized")
		_ok("GPU Power (PCIe 8-Pin): CONNECTED")
	else:
		_fail("GPU Power (PCIe 8-Pin): NOT DETECTED")
		_fail("PCIe Slot 1: GPU NOT RESPONDING")
	if not boot_ok:
		_halt()
		return
	_ok("Booting into OS...")
	_ok("")
	_ok("⚡ TEBRİKLER! BİLGİSAYAR SORUNSUZ ÇALIŞIYOR. MÜŞTERİYE TESLİM EDİLEBİLİR!")
	_line("", OK_COLOR)
	_line("(Menüye dönmek için tıkla)", NOTE_COLOR)

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
		else:
			EventBus.boot_failed.emit()

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not (mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed) or not can_close:
		return
	accept_event()
	if boot_ok:
		GameManager.go_to_menu()
	else:
		visible = false
