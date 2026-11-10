class_name Main
extends Control

# Ana sahne yöneticisi
# Ahşap masa arka planını çizer, içeriği ekranda ortalar ve oyun akışını kontrol eder.

const CONTENT_SIZE: Vector2 = Vector2(960, 980) ## Anakart + envanter + buton yüksekliği
const BOARD_SIZE: Vector2 = Vector2(960, 540)
const SIDE_GAP: float = 24.0
const TOP_BAR: float = 60.0 ## Yatay telefonda üst şerit (menü ve durum)

@onready var content: VBoxContainer = $Content
@onready var workbench: Workbench = $Content/Workbench
@onready var inventory: InventoryDrawer = $Content/InventoryDrawer
@onready var start_row: CenterContainer = $Content/StartRow

var side_panel: VBoxContainer = null ## Yatay telefonda envanter ve Başlat butonu sütunu

func _ready() -> void:
	UIStyle.setup_window(get_window())
	if UIStyle.is_compact():
		_build_side_panel()
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
	if side_panel:
		_layout_landscape()
		return
	content.position = Vector2(roundf((size.x - CONTENT_SIZE.x) / 2.0), maxf(0.0, roundf((size.y - CONTENT_SIZE.y) / 2.0)))
	content.size = Vector2(CONTENT_SIZE.x, 0)

# Yatay telefon: anakart solda tam boy, envanter ve Başlat sağ sütunda
func _build_side_panel() -> void:
	side_panel = VBoxContainer.new()
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_panel.add_theme_constant_override("separation", 12)
	add_child(side_panel)
	move_child(side_panel, content.get_index() + 1)
	inventory.reparent(side_panel, false)
	start_row.reparent(side_panel, false)
	inventory.use_side_layout()

func _layout_landscape() -> void:
	var left: float = UIStyle.safe_side() + SIDE_GAP / 2.0
	var top: float = maxf(TOP_BAR, roundf((size.y - BOARD_SIZE.y) / 2.0))
	content.position = Vector2(left, top)
	content.size = Vector2(BOARD_SIZE.x, 0)
	var side_x: float = left + BOARD_SIZE.x + SIDE_GAP
	var side_width: float = size.x - side_x - UIStyle.safe_side() - SIDE_GAP / 2.0
	inventory.custom_minimum_size.x = side_width
	side_panel.position = Vector2(side_x, TOP_BAR)
	side_panel.size = Vector2(side_width, size.y - TOP_BAR - 12.0)

func _draw() -> void:
	UIStyle.draw_wood(self, Rect2(Vector2.ZERO, size))

func _on_build_complete() -> void:
	print("Tüm parçalar yerleştirildi! Bilgisayar başlatılmaya hazır.")
