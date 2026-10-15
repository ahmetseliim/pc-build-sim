class_name Main
extends Control

# Ana sahne yöneticisi
# Ahşap masa arka planını çizer, içeriği ekranda ortalar ve oyun akışını kontrol eder.

const BASE_SIZE: Vector2 = Vector2(1080, 1000) ## project.godot'taki tasarım çözünürlüğü
const CONTENT_SIZE: Vector2 = Vector2(960, 980) ## Anakart + envanter + buton yüksekliği
const WOOD_LIGHT: Color = Color("#6d4c41")
const WOOD_DARK: Color = Color("#5d4037")
const STRIPE_WIDTH: float = 20.0

@onready var content: VBoxContainer = $Content
@onready var workbench: Workbench = $Content/Workbench

func _ready() -> void:
	# Tüm arayüz için varsayılan yazı tipi
	var theme_res: Theme = Theme.new()
	theme_res.default_font = UIStyle.ui_font(false)
	get_tree().root.theme = theme_res

	_fit_window_to_screen()
	_layout()

	# EventBus sinyallerine bağlan
	EventBus.build_complete.connect(_on_build_complete)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

# İçeriği yatayda ortala, dikeyde sabit bir yüksekliğe göre ortala
# (envanter boşaldıkça anakart kaymasın)
func _layout() -> void:
	if not is_node_ready():
		return
	content.position = Vector2(roundf((size.x - CONTENT_SIZE.x) / 2.0), maxf(0.0, roundf((size.y - CONTENT_SIZE.y) / 2.0)))
	content.size = Vector2(CONTENT_SIZE.x, 0)

# Masaüstünde pencereyi ekrana sığacak şekilde boyutlandır
func _fit_window_to_screen() -> void:
	if not OS.has_feature("pc"):
		return
	var window: Window = get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	var scale_factor: float = minf(1.0, minf(usable.size.x * 0.95 / BASE_SIZE.x, usable.size.y * 0.9 / BASE_SIZE.y))
	var win_size: Vector2i = Vector2i(BASE_SIZE * scale_factor)
	window.size = win_size
	window.position = usable.position + (usable.size - win_size) / 2

func _draw() -> void:
	# Ahşap masa: 20 px'lik dikey şeritler
	draw_rect(Rect2(Vector2.ZERO, size), WOOD_LIGHT)
	var x: float = STRIPE_WIDTH
	while x < size.x:
		draw_rect(Rect2(x, 0, STRIPE_WIDTH, size.y), WOOD_DARK)
		x += STRIPE_WIDTH * 2.0

func _on_build_complete() -> void:
	print("Tüm parçalar yerleştirildi! Bilgisayar başlatılmaya hazır.")
