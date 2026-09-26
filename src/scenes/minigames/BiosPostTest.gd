class_name BiosPostTest
extends Control

# BIOS POST test ekranı
# Tüm parçalar yerleştirildikten sonra çalışır.
# Satır satır boot mesajları gösterir.

@onready var bios_text: RichTextLabel = $BiosText
@onready var boot_timer: Timer = $BootTimer

var boot_sequence: Array[String] = [
	"BIOS DATE: 09/27/2026 15:15:00 VER: 2.10.128",
	"Power Signal (PWR_SW): OK",
	"CPU: Intel Core / AMD Ryzen Detected @ 4.80GHz",
	"Thermal Interface Material: APPLIED (TDP Normal)",
	"CPU_FAN Speed: 1520 RPM ... OPTIMAL",
	"Memory: 32768MB OK (DDR5 Dual Channel)",
	"Storage: M.2 NVMe Primary SSD OK",
	"PCIe Slot 1: Discrete GPU Initialized",
	"CMOS Battery: 3.28V Normal",
	"ATX 24-Pin Rail: 12V / 5V / 3.3V STABLE",
	"Booting into OS...",
	"",
	"⚡ TEBRİKLER! TÜM PARÇALAR, TERMAL MACUN VE KABLOLAMA EKSİKSİZ TAMAMLANDI!"
]

var current_line: int = 0
var is_running: bool = false

func _ready() -> void:
	visible = false
	boot_timer.wait_time = 0.28
	boot_timer.one_shot = false
	boot_timer.timeout.connect(_print_next_line)

func start_boot() -> void:
	visible = true
	current_line = 0
	bios_text.text = ""
	is_running = true
	EventBus.bios_boot_started.emit()
	boot_timer.start()

func _print_next_line() -> void:
	if current_line < boot_sequence.size():
		bios_text.text += boot_sequence[current_line] + "\n"
		current_line += 1
	else:
		boot_timer.stop()
		is_running = false
		EventBus.bios_boot_finished.emit()
