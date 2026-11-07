class_name MainMenu
extends Control

# Ana menü
# Devam Et / Yeni Oyun ile kariyeri başlatır. Geliştirme sırasında tek tek
# denemek için tüm işler (senaryolar) küçük "Test" butonunun arkasında listelenir.

@onready var list: VBoxContainer = $Center/Panel/VBox/List
@onready var vbox: VBoxContainer = $Center/Panel/VBox
@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/VBox/Subtitle

var _new_game_button: Button = null
var _confirm_new: bool = false

func _ready() -> void:
	UIStyle.setup_window(get_window())
	var style: StyleBoxFlat = UIStyle.box(Color("#1c1210"), 14, 2, Color("#3d2314"), Color(0, 0, 0, 0.5), 16, Vector2(0, 10))
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	_label(title_label, 30, Color("#00ffcc"), true, 3)
	_label(subtitle_label, 14, Color("#e2b083"), false)

	# Kayıt özeti ve kariyer butonları
	var has_save: bool = CareerManager.has_save() and CareerManager.load_game()
	if has_save:
		subtitle_label.text = "Gün %d  ·  Kasa %d ₺  ·  İtibar ★ %.1f" % [CareerManager.day, CareerManager.money, CareerManager.average_stars()]
	else:
		subtitle_label.text = "Küçük tamir tezgâhında ilk gününe başla"
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)
	vbox.move_child(buttons, list.get_index())
	if has_save:
		buttons.add_child(_big_button("Devam Et ▶", Color("#10b981"), CareerManager.continue_game))
	_new_game_button = _big_button("Yeni Oyun", Color("#0ea5e9") if has_save else Color("#10b981"), _on_new_game)
	buttons.add_child(_new_game_button)

	# Test listesi (gizli)
	list.visible = false
	for path: String in GameManager.SCENARIOS:
		var scenario: ScenarioData = load(path)
		if scenario:
			list.add_child(_make_card(scenario))
	var test_button: Button = Button.new()
	test_button.text = "Test ▾"
	test_button.flat = true
	test_button.add_theme_font_override("font", UIStyle.ui_font(false))
	test_button.add_theme_font_size_override("font_size", 11)
	test_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	test_button.focus_mode = Control.FOCUS_NONE
	test_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var toggle: Callable = func() -> void:
		list.visible = not list.visible
		test_button.text = "Test ▴" if list.visible else "Test ▾"
	test_button.pressed.connect(toggle)
	vbox.add_child(test_button)

# Kayıt varsa ikinci basışta onay ister
func _on_new_game() -> void:
	if CareerManager.has_save() and not _confirm_new:
		_confirm_new = true
		_new_game_button.text = "Emin misin? Kayıt silinir — tekrar bas"
		return
	CareerManager.new_game()

func _big_button(text: String, color: Color, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(560, 0)
	var normal: StyleBoxFlat = UIStyle.box(color, 10)
	normal.set_content_margin_all(14)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", UIStyle.ui_font(true))
	button.add_theme_font_size_override("font_size", 20)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	UIStyle.draw_wood(self, Rect2(Vector2.ZERO, size))

func _make_card(scenario: ScenarioData) -> Control:
	var card: PanelContainer = PanelContainer.new()
	var accent: Color = Color("#f59e0b") if scenario.shop_stage == 1 else Color("#a855f7")
	var style: StyleBoxFlat = UIStyle.box(Color("#0b192c"), 10, 2, Color("#1e3e62"))
	style.border_width_left = 6
	style.border_color = accent
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, 0)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var stage: Label = Label.new()
	stage.text = "1. DÜKKÂN · TAMİR" if scenario.shop_stage == 1 else "2. DÜKKÂN · MONTAJ"
	_label(stage, 11, accent, true, 1)
	info.add_child(stage)

	var title: Label = Label.new()
	title.text = scenario.title
	_label(title, 20, Color.WHITE, true)
	info.add_child(title)

	var desc: Label = Label.new()
	desc.text = scenario.menu_description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(desc, 13, Color("#94a3b8"), false)
	info.add_child(desc)

	var play: Button = Button.new()
	play.text = "Başla ▶"
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var normal: StyleBoxFlat = UIStyle.box(Color("#10b981"), 8)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#34d399")
	play.add_theme_stylebox_override("normal", normal)
	play.add_theme_stylebox_override("hover", hover)
	play.add_theme_stylebox_override("pressed", hover)
	play.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play.add_theme_font_override("font", UIStyle.ui_font(true))
	play.add_theme_font_size_override("font_size", 15)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		play.add_theme_color_override(key, Color.WHITE)
	play.focus_mode = Control.FOCUS_NONE
	play.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	play.pressed.connect(CareerManager.start_test.bind(scenario))
	row.add_child(play)
	return card

func _label(label: Label, size: int, color: Color, bold: bool, spacing: int = 0) -> void:
	label.add_theme_font_override("font", UIStyle.ui_font(bold, spacing))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
