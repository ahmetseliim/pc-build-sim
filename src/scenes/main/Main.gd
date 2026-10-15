class_name Main
extends Control

# Ana sahne yöneticisi
# Ahşap masa arka planını çizer, içeriği ekranda ortalar ve oyun akışını kontrol eder.

const CONTENT_SIZE: Vector2 = Vector2(960, 980) ## Anakart + envanter + buton yüksekliği

@onready var content: VBoxContainer = $Content
@onready var workbench: Workbench = $Content/Workbench

func _ready() -> void:
	UIStyle.setup_window(get_window())
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

func _draw() -> void:
	UIStyle.draw_wood(self, Rect2(Vector2.ZERO, size))

func _on_build_complete() -> void:
	print("Tüm parçalar yerleştirildi! Bilgisayar başlatılmaya hazır.")
