class_name ResultScreen
extends Control

# Gün sonu özeti ve dükkân mağazası
# Her işin ödemesi tezgâhta müşteriyle gösterilir (Counter); günün son müşterisi
# çıkınca bu ekran günün kazancını, bahşişi, geri gönderilen müşterileri ve dükkân
# itibarını özetler. Buradan mağazaya geçilir: Raf (yeni iş türü), Alet (kolaylık),
# Dekor (bahşiş ve müşteri). Good Pizza, Great Pizza'daki gün arası alışveriş gibi.

const CATEGORIES: Array = [
	["raf", "Raf"],
	["alet", "Alet"],
	["dekor", "Dekor"],
]
const CATEGORY_INFO: Dictionary = {
	"raf": "Raf yeni iş türü açar. Rafı olmayan işin müşterisi geri döner.",
	"alet": "Aletler işi kolaylaştırır ve hızlandırır.",
	"dekor": "Dekor dükkânı güzelleştirir, bahşiş ve müşteri getirir.",
}
const GREEN: Color = Color("#10b981")
const AMBER: Color = Color("#f59e0b")
const GOLD_TEXT: Color = Color("#fbbf24")
const MUTED: Color = Color("#94a3b8")
const RED_TEXT: Color = Color("#f87171")

@onready var panel: PanelContainer = $Center/Panel
@onready var box: VBoxContainer = $Center/Panel/VBox

var _category: String = "raf"

func _ready() -> void:
	UIStyle.setup_window(get_window())
	var style: StyleBoxFlat = UIStyle.box(Color("#1c1210"), 14, 2, Color("#e2b083"), Color(0, 0, 0, 0.6), 16, Vector2(0, 10))
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	_show_day_summary()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	UIStyle.draw_wood(self, Rect2(Vector2.ZERO, size))

func _ui() -> float:
	return UIStyle.ui_scale(get_viewport())

# --- Gün sonu özeti ----------------------------------------------------------

func _show_day_summary() -> void:
	_clear()
	_label(box, "GÜN %d BİTTİ" % CareerManager.day, 12, Color("#e2b083"), true)
	_label(box, "Gün Sonu Özeti", 26, Color.WHITE, true)
	_spacer(6)
	_row("Tamamlanan iş", str(CareerManager.day_jobs), Color.WHITE)
	_row("Bugünkü kazanç", "%d ₺" % CareerManager.day_earned, GOLD_TEXT)
	if CareerManager.day_tips > 0:
		_row("   içinde bahşiş", "%d ₺" % CareerManager.day_tips, MUTED, 13)
	var day_avg: float = float(CareerManager.day_star_total) / float(maxi(CareerManager.day_jobs, 1))
	_row("Bugünkü ortalama", "★ %.1f" % day_avg, GOLD_TEXT)
	if CareerManager.day_missed > 0:
		_row("Geri gönderilen müşteri", "%d  ·  kaçan %d ₺" % [CareerManager.day_missed, CareerManager.day_lost], RED_TEXT)
		var names: PackedStringArray = PackedStringArray()
		for id: String in CareerManager.day_missed_needs:
			var upgrade: UpgradeData = CareerManager.get_upgrade(id)
			if upgrade:
				names.append(upgrade.title)
		if not names.is_empty():
			var hint: Label = _label(box, "Rafında olmayan: %s. Mağazadan alabilirsin." % ", ".join(names), 12, MUTED, false)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.custom_minimum_size.x = 420.0 * _ui()
	_divider()
	_row("Kasa", "%d ₺" % CareerManager.money, Color.WHITE, 20)
	_row("Dükkân itibarı", "★ %.1f  (%d iş)" % [CareerManager.average_stars(), CareerManager.jobs_done], Color("#cbd5e1"))
	_spacer(8)
	var affordable: int = _affordable_count()
	var shop_text: String = "Dükkân Mağazası" + ("  ·  %d alınabilir" % affordable if affordable > 0 else "")
	_button(box, shop_text, _open_shop, AMBER)
	_button(box, "%d. Güne Başla ▶" % (CareerManager.day + 1), CareerManager.start_next_day, GREEN)
	_button(box, "Menüye Dön", GameManager.go_to_menu, Color(0.2, 0.2, 0.25, 0.8), true)

func _affordable_count() -> int:
	var n: int = 0
	for upgrade: UpgradeData in CareerManager.catalog():
		if CareerManager.purchase_block_reason(upgrade) == "":
			n += 1
	return n

# --- Mağaza ------------------------------------------------------------------

func _open_shop() -> void:
	# Bugün müşteri kaçıran bir eksik varsa mağaza o sekmede açılır
	_category = "raf"
	for id: String in CareerManager.day_missed_needs:
		var upgrade: UpgradeData = CareerManager.get_upgrade(id)
		if upgrade and not CareerManager.has_upgrade(id):
			_category = upgrade.category
			break
	_show_shop()

func _show_shop() -> void:
	_clear()
	var head: HBoxContainer = HBoxContainer.new()
	head.custom_minimum_size.x = 560.0 * _ui()
	box.add_child(head)
	var title: Label = _label(head, "Dükkân Mağazası", 24, Color.WHITE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(head, "Kasa  %d ₺" % CareerManager.money, 18, GOLD_TEXT, true)

	# Sekmeler
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for entry: Array in CATEGORIES:
		var key: String = entry[0]
		var selected: bool = key == _category
		var tab: Button = _button(tabs, entry[1], _select_category.bind(key),
			Color("#e2b083") if selected else Color(1, 1, 1, 0.08), true)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_color_override("font_color", Color("#1c1210") if selected else Color.WHITE)
		tab.add_theme_color_override("font_hover_color", Color("#1c1210") if selected else Color.WHITE)
	var info: Label = _label(box, CATEGORY_INFO[_category], 12, MUTED, false)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 560.0 * _ui()

	# Alımlar (ileride çoğalınca kaydırılabilir)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var items: Array[UpgradeData] = CareerManager.catalog(_category)
	if items.is_empty():
		_label(list, "Bu bölümde şimdilik bir şey yok.", 14, MUTED, false)
	for upgrade: UpgradeData in items:
		list.add_child(_item_card(upgrade))
	# Liste ekrana sığmazsa kaydırılır; sığarsa boş alan bırakmaz
	await get_tree().process_frame
	if is_instance_valid(scroll):
		var max_height: float = get_viewport_rect().size.y * 0.5
		scroll.custom_minimum_size.y = minf(list.get_combined_minimum_size().y, max_height)

	_spacer(4)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	box.add_child(bottom)
	var back: Button = _button(bottom, "◀ Özete Dön", _show_day_summary, Color(0.2, 0.2, 0.25, 0.8), true)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next: Button = _button(bottom, "%d. Güne Başla ▶" % (CareerManager.day + 1), CareerManager.start_next_day, GREEN)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _select_category(key: String) -> void:
	_category = key
	_show_shop()

func _item_card(upgrade: UpgradeData) -> PanelContainer:
	var owned: bool = CareerManager.has_upgrade(upgrade.id)
	var reason: String = CareerManager.purchase_block_reason(upgrade)
	var card: PanelContainer = PanelContainer.new()
	var needed_today: bool = not owned and CareerManager.day_missed_needs.has(upgrade.id)
	var border: Color = AMBER if needed_today else Color(1, 1, 1, 0.12)
	var style: StyleBoxFlat = UIStyle.box(Color(1, 1, 1, 0.05), 10, 2 if needed_today else 1, border)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_label(text, upgrade.title, 17, Color.WHITE, true)
	var effect: Label = _label(text, upgrade.effect, 12, Color("#cbd5e1"), false)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size.x = 360.0 * _ui()
	if needed_today:
		_label(text, "Bugün %s yüzünden müşteri geri döndü" % upgrade.title, 12, AMBER, true)

	var side: VBoxContainer = VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.custom_minimum_size.x = 150.0 * _ui()
	row.add_child(side)
	if owned:
		_label(side, "✓ Alındı", 16, GREEN, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return card
	var buy: Button = _button(side, "%d ₺" % upgrade.price, _buy.bind(upgrade), GREEN)
	if reason != "":
		buy.disabled = true
		var why: Label = _label(side, reason, 11, RED_TEXT if reason.begins_with("Kasada") else MUTED, false)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card

func _buy(upgrade: UpgradeData) -> void:
	if CareerManager.buy_upgrade(upgrade):
		AudioManager.play_sfx("coin")
		_show_shop()

# --- Arayüz yardımcıları -----------------------------------------------------

func _clear() -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _label(parent: Control, text: String, font_size: int, color: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", UIStyle.ui_font(bold))
	label.add_theme_font_size_override("font_size", UIStyle.scaled(get_viewport(), font_size))
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _row(left: String, right: String, color: Color, font_size: int = 15) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(420.0 * _ui(), 0)
	box.add_child(row)
	var l: Label = _label(row, left, font_size, color, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, right, font_size, color, true)

func _divider() -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)

func _spacer(h: float) -> void:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	box.add_child(s)

func _button(parent: Control, text: String, action: Callable, bg: Color, secondary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	var normal: StyleBoxFlat = UIStyle.box(bg, 8)
	normal.set_content_margin_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", UIStyle.ui_font(true))
	button.add_theme_font_size_override("font_size", UIStyle.scaled(get_viewport(), 14 if secondary else 17))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button
