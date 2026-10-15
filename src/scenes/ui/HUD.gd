class_name HUD
extends CanvasLayer

# Oyun içi arayüz katmanı
# Oyuncuya kısa uyarı mesajları gösterir (HTML'deki alert yerine).

const TOAST_DURATION: float = 2.2

@onready var toast: PanelContainer = $Toast
@onready var toast_label: Label = $Toast/Label

var _tween: Tween = null

func _ready() -> void:
	var panel: StyleBoxFlat = UIStyle.box(Color(0.06, 0.09, 0.16, 0.96), 8, 2, Color("#ef4444"), Color(0, 0, 0, 0.5), 10, Vector2(0, 6))
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	toast.add_theme_stylebox_override("panel", panel)
	toast_label.add_theme_font_override("font", UIStyle.ui_font(true))
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast.visible = false
	EventBus.warning_requested.connect(show_warning)

func show_warning(message: String) -> void:
	toast_label.text = "⚠️  " + message
	toast.visible = true
	toast.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(TOAST_DURATION)
	_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(toast.hide)
