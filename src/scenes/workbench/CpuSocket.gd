class_name CpuSocket
extends MotherboardSlot

# İşlemci soketi
# Mandal aç/kapat tıklamalarını, durum kaplamasını ve termal macun
# mini oyununu (HTML'deki canvas + "Kapsama" kutusu) yönetir.

const BORDER_LOCKED: Color = Color("#ef4444")
const BORDER_OPEN: Color = Color("#00ffcc")
const BORDER_CLOSED: Color = Color("#94a3b8")
const SPILL_COLOR: Color = Color(239.0 / 255.0, 68.0 / 255.0, 68.0 / 255.0, 0.9)

@onready var paste_dot: PasteDot = $PasteDot
@onready var paste_app: ThermalPasteApp = $ThermalPasteApp
@onready var overlay: SlotOverlay = $Overlay
@onready var inline_ui: PanelContainer = $PasteInlineUI
@onready var coverage_label: Label = $PasteInlineUI/VBox/CoverageLabel
@onready var clear_button: Button = $PasteInlineUI/VBox/ClearButton

var spill_flash: float = 0.0:
	set(value):
		spill_flash = value
		queue_redraw()

var _paste_part: PartItem = null
var _border_tween: Tween = null

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_inline_ui()
	inline_ui.visible = false
	paste_app.visible = false

	EventBus.cpu_state_changed.connect(_on_cpu_state_changed)
	paste_app.coverage_changed.connect(_on_coverage_changed)
	paste_app.paste_complete.connect(_on_paste_complete)
	paste_app.paste_spilled.connect(_on_paste_spilled)
	paste_app.clean_complete.connect(_on_clean_complete)
	clear_button.pressed.connect(_on_clear_pressed)

	_apply_state(GameManager.cpu_state, false)

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		match GameManager.cpu_state:
			"locked_empty":
				GameManager.set_cpu_state("open")
			"installed":
				GameManager.set_cpu_state("locked_full")

# Termal macun soketin üstüne bırakıldığında mini oyunu başlatır
func start_paste(part: PartItem) -> void:
	_paste_part = part
	part.visible = false
	GameManager.set_cpu_state("painting")
	inline_ui.visible = true
	clear_button.visible = true
	paste_app.start()

# Alkollü bez soketin üstüne bırakıldığında kurumuş macunu silme mini oyununu başlatır
func start_cleaning(part: PartItem) -> void:
	_paste_part = part
	part.visible = false
	paste_dot.ratio = 0.0
	GameManager.set_cpu_state("cleaning")
	inline_ui.visible = true
	clear_button.visible = false
	paste_app.start_cleaning()

# Hazır gelen bilgisayarda macun zaten sürülmüştür (dried: kurumuş eski macun)
func apply_paste_instant(dried: bool = false) -> void:
	paste_dot.dried = dried
	paste_dot.ratio = PasteDot.FINAL_RATIO
	paste_dot.modulate.a = 1.0
	GameManager.paste_old = dried
	GameManager.set_cpu_state("paste_applied")

func _on_cpu_state_changed(state: String) -> void:
	_apply_state(state, true)

func _apply_state(state: String, animate: bool) -> void:
	match state:
		"locked_empty":
			_set_border(BORDER_LOCKED, animate)
			overlay.set_content(Color(0, 0, 0, 0.6), [{"text": "🔒 MANDAL KAPALI"}, {"text": "(Tıkla)"}], animate)
		"open":
			_set_border(BORDER_OPEN, animate)
			overlay.set_content(Color(0, 1, 0.8, 0.15), [{"text": "🔓 SOKET AÇIK"}, {"text": "(İşlemciyi Bırak)"}], animate)
		"installed":
			overlay.set_content(Color(0.937, 0.267, 0.267, 0.85), [{"text": "⚠️ MANDALI KAPAT"}, {"text": "(Tıkla)"}], animate)
		"locked_full":
			_set_border(BORDER_CLOSED, animate)
			overlay.set_content(Color(0, 0, 0, 0.5), [
				{"text": "🔒 KİLİTLENDİ"},
				{"text": "(Termal Macun Sür)", "size": 9, "color": Color("#f59e0b")},
			], animate)
		"painting":
			_show_paint_prompt()
		"cleaning":
			overlay.set_content(Color(0, 0, 0, 0.45), [{"text": "OVALAYARAK"}, {"text": "TEMİZLE"}], false)
		"paste_old":
			_show_dried_prompt(animate)
		"paste_applied", "fan_mounted":
			if GameManager.paste_old:
				_show_dried_prompt(animate)
			elif state == "paste_applied":
				overlay.set_content(Color(16.0 / 255.0, 185.0 / 255.0, 129.0 / 255.0, 0.3), [{"text": "✅ MACUNLANDI", "icon": true}], animate)

func _show_dried_prompt(animate: bool) -> void:
	var tip: String = "(Fanı sök)" if GameManager.fan_mounted else "(Alkollü bezle temizle)"
	overlay.set_content(Color(0.45, 0.33, 0.15, 0.55), [
		{"text": "⚠️ KURUMUŞ MACUN"},
		{"text": tip, "size": 9, "color": Color("#fcd34d")},
	], animate)

func _set_border(color: Color, animate: bool) -> void:
	if _border_tween:
		_border_tween.kill()
	if animate:
		_border_tween = create_tween()
		_border_tween.tween_property(self, "border_color", color, 0.2)
	else:
		border_color = color

func _show_paint_prompt() -> void:
	overlay.set_content(Color(0, 0, 0, 0.6), [{"text": "MACUN SÜR"}], false)

func _on_coverage_changed(percent: int) -> void:
	coverage_label.text = ("Temizlik: %d%%" if paste_app.cleaning else "Kapsama: %d%%") % percent

func _on_paste_spilled() -> void:
	overlay.set_content(Color(0.937, 0.267, 0.267, 0.8), [{"text": "⚠️ TAŞTI!"}], true)
	spill_flash = 1.0
	create_tween().tween_property(self, "spill_flash", 0.0, 0.5)

func _on_clear_pressed() -> void:
	spill_flash = 0.0
	_show_paint_prompt()
	paste_app.start()

func _on_paste_complete(_coverage: float) -> void:
	paste_app.stop()
	paste_app.visible = false
	inline_ui.visible = false
	GameManager.set_cpu_state("paste_applied")
	paste_dot.apply()
	if _paste_part:
		InventoryManager.remove_part(_paste_part.data)
		_paste_part.queue_free()
		_paste_part = null

func _on_clean_complete() -> void:
	paste_app.stop()
	paste_app.visible = false
	inline_ui.visible = false
	paste_dot.dried = false
	GameManager.paste_old = false
	GameManager.set_cpu_state("locked_full")
	if _paste_part:
		InventoryManager.remove_part(_paste_part.data)
		_paste_part.queue_free()
		_paste_part = null
	EventBus.info_requested.emit("Eski macun temizlendi. Şimdi yeni macun sür.")

func _draw() -> void:
	super._draw()
	# Taşma anında macun alanının etrafında kırmızı parlama
	if spill_flash > 0.0:
		UIStyle.draw_rect_glow(self, Rect2(paste_app.position, paste_app.size), 20.0, Color(SPILL_COLOR, SPILL_COLOR.a * spill_flash))

func _style_inline_ui() -> void:
	var panel: StyleBoxFlat = UIStyle.box(Color(0, 0, 0, 0.85), 4, 1, Color("#475569"))
	panel.set_content_margin_all(4)
	inline_ui.add_theme_stylebox_override("panel", panel)

	coverage_label.add_theme_font_override("font", UIStyle.ui_font(false))
	coverage_label.add_theme_font_size_override("font_size", 10)
	coverage_label.add_theme_color_override("font_color", Color.WHITE)

	var btn: StyleBoxFlat = UIStyle.box(Color("#ef4444"), 3)
	btn.content_margin_left = 5
	btn.content_margin_right = 5
	btn.content_margin_top = 2
	btn.content_margin_bottom = 2
	var btn_hover: StyleBoxFlat = btn.duplicate()
	btn_hover.bg_color = Color("#dc2626")
	clear_button.add_theme_stylebox_override("normal", btn)
	clear_button.add_theme_stylebox_override("hover", btn_hover)
	clear_button.add_theme_stylebox_override("pressed", btn_hover)
	clear_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	clear_button.add_theme_font_override("font", UIStyle.ui_font(false))
	clear_button.add_theme_font_size_override("font_size", 9)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		clear_button.add_theme_color_override(key, Color.WHITE)
	clear_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clear_button.focus_mode = Control.FOCUS_NONE
