class_name HUD
extends CanvasLayer

# Oyun içi arayüz katmanı
# Başta müşterinin iş emrini gösterir, kısa uyarı/bilgi mesajları ve menü butonu içerir.

const TOAST_DURATION: float = 2.2
const ERROR_COLOR: Color = Color("#ef4444")
const INFO_COLOR: Color = Color("#10b981")

@onready var menu_button: Button = $MenuButton
@onready var toast: PanelContainer = $Toast
@onready var toast_label: Label = $Toast/Label
@onready var dim: ColorRect = $Dim
@onready var order_card: PanelContainer = $OrderCard
@onready var header_label: Label = $OrderCard/VBox/Header
@onready var title_label: Label = $OrderCard/VBox/Title
@onready var customer_label: Label = $OrderCard/VBox/Customer
@onready var complaint_label: Label = $OrderCard/VBox/Complaint
@onready var hint_label: Label = $OrderCard/VBox/Hint
@onready var start_work_button: Button = $OrderCard/VBox/StartWork

var _tween: Tween = null

func _ready() -> void:
	_style_labels()
	_style_button(menu_button, Color(0.06, 0.09, 0.16, 0.85), 13)
	_style_button(start_work_button, Color("#10b981"), 15)
	toast.visible = false
	menu_button.pressed.connect(GameManager.go_to_menu)
	start_work_button.pressed.connect(_close_order_card)
	EventBus.warning_requested.connect(show_warning)
	EventBus.info_requested.connect(show_info)
	_show_order_card()

# --- İş emri -----------------------------------------------------------------

func _show_order_card() -> void:
	var scenario: ScenarioData = GameManager.current_scenario
	if scenario == null:
		_close_order_card()
		return
	var stage: String = "1. DÜKKÂN · TAMİR" if scenario.shop_stage == 1 else "2. DÜKKÂN · MONTAJ"
	header_label.text = "İŞ EMRİ  ·  " + stage
	title_label.text = scenario.title
	customer_label.text = "Müşteri: " + scenario.customer
	complaint_label.text = "“" + GameManager.get_complaint() + "”"
	hint_label.visible = scenario.hint != ""
	hint_label.text = scenario.hint

func _close_order_card() -> void:
	dim.visible = false
	order_card.visible = false

# --- Mesajlar ----------------------------------------------------------------

func show_warning(message: String) -> void:
	_show_toast("⚠️  " + message, ERROR_COLOR)

func show_info(message: String) -> void:
	_show_toast("✅  " + message, INFO_COLOR)

func _show_toast(text: String, border: Color) -> void:
	var panel: StyleBoxFlat = UIStyle.box(Color(0.06, 0.09, 0.16, 0.96), 8, 2, border, Color(0, 0, 0, 0.5), 10, Vector2(0, 6))
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	toast.add_theme_stylebox_override("panel", panel)
	toast_label.text = text
	toast.visible = true
	toast.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(TOAST_DURATION)
	_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(toast.hide)

# --- Stil --------------------------------------------------------------------

func _style_labels() -> void:
	toast_label.add_theme_font_override("font", UIStyle.ui_font(true))
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("font_color", Color.WHITE)

	var card: StyleBoxFlat = UIStyle.box(Color("#1c1210"), 12, 2, Color("#e2b083"), Color(0, 0, 0, 0.6), 16, Vector2(0, 10))
	card.set_content_margin_all(26)
	order_card.add_theme_stylebox_override("panel", card)
	_label(header_label, 12, Color("#e2b083"), true)
	_label(title_label, 24, Color.WHITE, true)
	_label(customer_label, 14, Color("#cbd5e1"), true)
	_label(complaint_label, 16, Color("#f8fafc"), false)
	_label(hint_label, 13, Color("#94a3b8"), false)

func _label(label: Label, size: int, color: Color, bold: bool) -> void:
	label.add_theme_font_override("font", UIStyle.ui_font(bold))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

func _style_button(button: Button, bg: Color, font_size: int) -> void:
	var normal: StyleBoxFlat = UIStyle.box(bg, 8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", UIStyle.ui_font(true))
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
