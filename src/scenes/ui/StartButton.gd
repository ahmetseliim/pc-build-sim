class_name StartButton
extends Button

# "Bilgisayarı Başlat" butonu (HTML'deki #start-btn)
# Tüm parçalar takılınca belirir ve nabız gibi atar.

func _ready() -> void:
	var style: StyleBoxFlat = UIStyle.box(Color("#10b981"), 8, 0, Color.TRANSPARENT, Color(16.0 / 255.0, 185.0 / 255.0, 129.0 / 255.0, 0.6), 10)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	for key: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(key, style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_font_override("font", UIStyle.ui_font(true))
	add_theme_font_size_override("font_size", 16)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(key, Color.WHITE)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Yer kaplasın ama görünmesin, böylece düzen kaymaz
	modulate.a = 0.0
	disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.build_complete.connect(_on_build_complete)
	pressed.connect(_on_pressed)

func _on_build_complete() -> void:
	modulate.a = 1.0
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.75).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE)

func _on_pressed() -> void:
	EventBus.bios_boot_requested.emit()
