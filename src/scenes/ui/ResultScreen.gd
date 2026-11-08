class_name ResultScreen
extends Control

# Gün sonu özeti ekranı
# Her işin ödemesi tezgâhta müşteriyle gösterilir (Counter); günün son müşterisi
# çıkınca bu ekran günün kazancını ve dükkân itibarını özetler.

@onready var panel: PanelContainer = $Center/Panel
@onready var box: VBoxContainer = $Center/Panel/VBox

func _ready() -> void:
	UIStyle.setup_window(get_window())
	var style: StyleBoxFlat = UIStyle.box(Color("#1c1210"), 14, 2, Color("#e2b083"), Color(0, 0, 0, 0.6), 16, Vector2(0, 10))
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	_show_day_summary()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	UIStyle.draw_wood(self, Rect2(Vector2.ZERO, size))

func _show_day_summary() -> void:
	_clear()
	_label("GÜN %d BİTTİ" % CareerManager.day, 12, Color("#e2b083"), true)
	_label("Gün Sonu Özeti", 26, Color.WHITE, true)
	_spacer(8)
	_row("Tamamlanan iş", str(CareerManager.day_jobs), Color.WHITE)
	_row("Bugünkü kazanç", "%d ₺" % CareerManager.day_earned, Color("#fbbf24"))
	var day_avg: float = float(CareerManager.day_star_total) / float(maxi(CareerManager.day_jobs, 1))
	_row("Bugünkü ortalama", "★ %.1f" % day_avg, Color("#fbbf24"))
	_divider()
	_row("Kasa", "%d ₺" % CareerManager.money, Color.WHITE, 20)
	_row("Dükkân itibarı", "★ %.1f  (%d iş)" % [CareerManager.average_stars(), CareerManager.jobs_done], Color("#cbd5e1"))
	_spacer(10)
	_button("%d. Güne Başla ▶" % (CareerManager.day + 1), CareerManager.start_next_day)
	_button("Menüye Dön", GameManager.go_to_menu, true)

# --- Arayüz yardımcıları -----------------------------------------------------

func _clear() -> void:
	for child: Node in box.get_children():
		child.queue_free()

func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", UIStyle.ui_font(bold))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return label

func _row(left: String, right: String, color: Color, size: int = 15) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(420, 0)
	var l: Label = Label.new()
	l.text = left
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r: Label = Label.new()
	r.text = right
	for label: Label in [l, r]:
		label.add_theme_font_override("font", UIStyle.ui_font(true))
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", color)
		row.add_child(label)
	box.add_child(row)

func _divider() -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)

func _spacer(h: float) -> void:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	box.add_child(s)

func _button(text: String, action: Callable, secondary: bool = false) -> void:
	var button: Button = Button.new()
	button.text = text
	var bg: Color = Color(0.2, 0.2, 0.25, 0.8) if secondary else Color("#10b981")
	var normal: StyleBoxFlat = UIStyle.box(bg, 8)
	normal.set_content_margin_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", UIStyle.ui_font(true))
	button.add_theme_font_size_override("font_size", 14 if secondary else 17)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	box.add_child(button)
