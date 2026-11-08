class_name CounterScene
extends Control

# Tezgâh Sahnesi (Counter)
# Dükkânın ön yüzü: müşteriler kapıdan girip sıraya dizilir, öndeki tezgâha
# yürür ve arızayı anlatır; "Atölyeye Al" ile tamir masasına geçilir.
# İş bitince buraya dönülür: müşteri yorumunu, yıldızını ve ödemesini söyleyip
# kapıdan çıkar, arkadaki müşteriler birer adım ilerler.
#
# Sahne 1920×1080'lik bir "dünya" (World) üzerinde kurulur ve ekrana ölçeklenir;
# müşteri konumları bu dünya koordinatlarındadır (ayak noktası).

const WORLD_SIZE: Vector2 = Vector2(1920, 1080)
const VISIBLE_SPAN: Vector2 = Vector2(420, 1600) ## Dar ekranda bile görünmesi gereken yatay aralık (kapı → sıra)
const DOOR_POS: Vector2 = Vector2(687, 700) ## Kapı eşiği
const DOOR_SCALE: float = 0.4
const COUNTER_POS: Vector2 = Vector2(1000, 1010) ## Tezgâhın arkası (alt kısım tezgâhla örtülür)
const COUNTER_SCALE: float = 1.0
const QUEUE_FIRST: Vector2 = Vector2(1265, 790) ## Sıradaki ilk bekleme noktası
const QUEUE_STEP: Vector2 = Vector2(108, -17) ## Her arkadaki kişi için kayma
const QUEUE_FIRST_SCALE: float = 0.56
const QUEUE_SCALE_STEP: float = 0.045
const ENTER_DELAY: float = 0.9 ## Gün başında müşterilerin kapıdan giriş aralığı (sn)
const TYPE_SPEED: float = 55.0 ## Konuşma balonunda harf/sn

## Kariyer modunda boş şikâyetli (rastgele kablo arızalı) işler için genel şikâyet
const GENERIC_COMPLAINT: String = "Bilgisayar çalışırken birden kapandı, kasadan da yanık kokusu geldi. O günden beri düzgün açılmıyor."

## Yıldıza göre genel yorumlar (5 yıldızda müşterinin kendi sözü kullanılır)
const REVIEWS: Dictionary = {
	4: "Gayet iyi, eline sağlık. Ufak tefek aksilikler oldu ama sorun değil.",
	3: "İdare eder... Biraz uğraştırdı galiba ama sonunda çalışıyor.",
	2: "Çalışıyor ama açıkçası pek memnun kalmadım.",
	1: "Bir dahaki sefere başka dükkâna giderim herhalde...",
}
## Hataya göre müşterinin ekleyeceği sitem
const MISTAKE_REMARKS: Dictionary = {
	"paste_spill": "Kasanın içi macun olmuş bu arada!",
	"healthy_removed": "Sağlam parçamı neden söktün ki?",
	"extra_boot": "Bu kadar açıp kapatmak şart mıydı?",
	"sequence": "Biraz acemice uğraştın gibi geldi.",
}

# Tasarım dosyasındaki renkler
const INK: Color = Color("#1E1A17")
const CREAM: Color = Color("#FFFDF7")
const BUTTON_BG: Color = Color("#F4EBDD")
const WOOD_SHADOW: Color = Color("#6A4226")
const WALL: Color = Color("#E8C98E")
const GOLD: Color = Color("#E1A83A")
const GREEN: Color = Color("#4F9A6B")
const RED: Color = Color("#B4544A")

## SVG'deki yazılar (Godot SVG yazısı çizmediği için etiket olarak eklenir): metin, orta-alt nokta, boyut, renk
const SIGN_TEXTS: Array = [
	["AÇIK", Vector2(687, 306), 30, Color("#B4544A")],
	["PC TAMİRCİSİ", Vector2(990, 156), 30, Color("#1E1A17")],
	["TAMİR", Vector2(990, 276), 22, Color("#F2C14E")],
	["Format · Kurulum", Vector2(990, 300), 16, Color("#F4EBDD")],
	["Parça Değişimi", Vector2(990, 321), 16, Color("#F4EBDD")],
	["Termal Bakım", Vector2(990, 342), 16, Color("#F4EBDD")],
	["RAM", Vector2(1816, 268), 20, Color("#1E1A17")],
	["SSD", Vector2(1817, 608), 16, Color("#1E1A17")],
]
const TILL_POS: Vector2 = Vector2(1651, 738) ## Yazar kasa ekranı (kasadaki parayı gösterir)

@onready var backdrop: ColorRect = $Backdrop
@onready var world: Node2D = $World
@onready var signs: Node2D = $World/Signs
@onready var crowd: Node2D = $World/Crowd
@onready var ui: Control = $UI

var _at_counter: CustomerWalker = null
var _queue: Array[CustomerWalker] = [] ## Sırada bekleyenler (önden arkaya)

# Arayüz
var _bubble: PanelContainer = null
var _name_tag: PanelContainer = null
var _name_label: Label = null
var _role_label: Label = null
var _text_label: Label = null
var _extras: VBoxContainer = null ## Yorumdaki yıldızlar ve fiş satırları
var _action_button: Button = null
var _money_label: Label = null
var _day_label: Label = null
var _queue_label: Label = null
var _till_label: Label = null

var _typing: bool = false
var _type_progress: float = 0.0
var _after_typing: Callable = Callable()
var _shown_money: float = 0.0 ## Kasada görünen para (ödemede sayarak artar)
var _counting: bool = false

func _ready() -> void:
	UIStyle.setup_window(get_window())
	if CareerManager.day_queue.is_empty():
		GameManager.go_to_menu()
		return
	_build_signs()
	_build_ui()
	_shown_money = CareerManager.money
	if CareerManager.counter_mode == "farewell":
		_shown_money -= int(CareerManager.last_result.get("pay", 0))
		_setup_farewell()
	else:
		_setup_arrival()
	_update_hud()
	_fit_world()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fit_world()

func _process(delta: float) -> void:
	if _typing:
		_type_progress += delta * TYPE_SPEED
		_text_label.visible_characters = int(_type_progress)
		if _text_label.visible_characters >= _text_label.get_total_character_count():
			_finish_typing()
	# Ödeme: kasadaki para sayarak artar
	if _counting and _shown_money < CareerManager.money:
		_shown_money = minf(_shown_money + maxf(delta * 240.0, (CareerManager.money - _shown_money) * delta * 3.0), CareerManager.money)
		_update_money()
	_layout_bubble()

# --- Dünya yerleşimi ----------------------------------------------------------

# Dünyayı ekranı dolduracak şekilde ölçekler; dar/uzun ekranda kapı ile sıra
# görünür kalsın diye genişliğe göre sığdırıp alttan hizalar (üstte duvar rengi kalır).
func _fit_world() -> void:
	var cover: float = maxf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y)
	var span: float = VISIBLE_SPAN.y - VISIBLE_SPAN.x
	var s: float = minf(cover, size.x / span)
	world.scale = Vector2(s, s)
	var focus_x: float = (VISIBLE_SPAN.x + VISIBLE_SPAN.y) / 2.0
	var x: float = size.x / 2.0 - focus_x * s
	# Dünyanın kenarı ekranın içine girmesin
	x = clampf(x, size.x - WORLD_SIZE.x * s, 0.0)
	world.position = Vector2(x, size.y - WORLD_SIZE.y * s)
	backdrop.color = WALL

func _build_signs() -> void:
	for entry: Array in SIGN_TEXTS:
		_world_label(entry[0], entry[1], entry[2], entry[3])
	_till_label = _world_label("", TILL_POS, 26, INK)

func _world_label(text: String, bottom_center: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIStyle.shop_font(true, 800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size = Vector2(320, font_size * 1.4)
	label.position = bottom_center - Vector2(160, font_size * 1.15)
	signs.add_child(label)
	return label

func _queue_spot(i: int) -> Vector2:
	return QUEUE_FIRST + QUEUE_STEP * i

func _queue_scale(i: int) -> float:
	return QUEUE_FIRST_SCALE - QUEUE_SCALE_STEP * i

func _spawn(index: int, pos: Vector2, s: float) -> CustomerWalker:
	var walker: CustomerWalker = CustomerWalker.new()
	walker.setup(CareerManager.customer_at(index), pos, s)
	crowd.add_child(walker)
	return walker

# --- Müşteri gelişi -----------------------------------------------------------

func _setup_arrival() -> void:
	var first: int = CareerManager.job_index
	var day_start: bool = first == 0
	_at_counter = _spawn(first, DOOR_POS, DOOR_SCALE)
	_at_counter.modulate.a = 0.0
	_at_counter.walk_to(COUNTER_POS, COUNTER_SCALE, "in")
	_at_counter.arrived.connect(_on_customer_at_counter, CONNECT_ONE_SHOT)
	for i: int in range(first + 1, CareerManager.day_queue.size()):
		var slot: int = _queue.size()
		if day_start:
			# Gün başı: herkes sırayla kapıdan girip sıraya geçer
			var walker: CustomerWalker = _spawn(i, DOOR_POS, DOOR_SCALE)
			walker.modulate.a = 0.0
			get_tree().create_timer(ENTER_DELAY * (slot + 1)).timeout.connect(
				walker.walk_to.bind(_queue_spot(slot), _queue_scale(slot), "in"))
			_queue.append(walker)
		else:
			_queue.append(_spawn(i, _queue_spot(slot), _queue_scale(slot)))

func _on_customer_at_counter() -> void:
	_update_hud()
	var customer: CustomerData = _at_counter.data
	var scenario: ScenarioData = CareerManager.current_scenario()
	var complaint: String = scenario.complaint if scenario.complaint != "" else GENERIC_COMPLAINT
	var text: String = complaint if customer.greeting == "" else customer.greeting + " " + complaint
	_say(customer, text, _offer_workshop)

func _offer_workshop() -> void:
	_show_action("Bilgisayarı Atölyeye Al  ▶", CareerManager.enter_workshop)

# --- Teslim ve ödeme ----------------------------------------------------------

func _setup_farewell() -> void:
	var r: Dictionary = CareerManager.last_result
	var index: int = int(r.get("customer_index", CareerManager.job_index - 1))
	_at_counter = _spawn(index, COUNTER_POS, COUNTER_SCALE)
	for i: int in range(index + 1, CareerManager.day_queue.size()):
		var slot: int = _queue.size()
		_queue.append(_spawn(i, _queue_spot(slot), _queue_scale(slot)))
	var stars: int = int(r.get("stars", 0))
	_say(_at_counter.data, _review_text(_at_counter.data, stars, r.get("mistakes", {})), _show_payment.bind(r))
	_build_review_extras(r)

func _review_text(customer: CustomerData, stars: int, mistakes: Dictionary) -> String:
	var text: String = customer.thanks_line if stars >= CareerManager.MAX_STARS else REVIEWS.get(stars, REVIEWS[1])
	for kind: String in mistakes:
		if MISTAKE_REMARKS.has(kind):
			text += " " + MISTAKE_REMARKS[kind]
			break
	return text

# Yıldızlar ve fiş (konuşma bitince görünür)
func _build_review_extras(r: Dictionary) -> void:
	var stars: int = int(r.get("stars", 0))
	var star_text: String = ""
	for i: int in range(CareerManager.MAX_STARS):
		star_text += "★" if i < stars else "☆"
	var star_label: Label = _make_label(star_text, 40, GOLD, true)
	_extras.add_child(star_label)
	var price: int = int(r.get("price", 0))
	var pay: int = int(r.get("pay", 0))
	_extras.add_child(_receipt_row("İş ücreti", "%d ₺" % price, INK))
	var mistakes: Dictionary = r.get("mistakes", {})
	for kind: String in mistakes:
		var count: int = mistakes[kind]
		_extras.add_child(_receipt_row("%s × %d" % [CareerManager.MISTAKE_NAMES.get(kind, kind), count],
			"-%d%%" % int(count * CareerManager.MISTAKE_PENALTY * 100), RED))
	if mistakes.is_empty():
		_extras.add_child(_receipt_row("Hatasız iş!", "", GREEN))
	_extras.add_child(_receipt_row("Ödenen", "+%d ₺" % pay, GREEN, 26))
	_extras.visible = false

func _show_payment(r: Dictionary) -> void:
	_extras.visible = true
	# Para kasaya sayarak girer (_process); şimdiye kadar eski değerde bekliyordu
	_counting = true
	_show_action("Güle güle!  ▶", _send_off)

# Müşteri kapıdan çıkar, sıradakiler ilerler
func _send_off() -> void:
	_hide_bubble()
	_hide_action()
	var leaving: CustomerWalker = _at_counter
	_at_counter = null
	leaving.walk_to(DOOR_POS, DOOR_SCALE, "out")
	leaving.arrived.connect(leaving.queue_free, CONNECT_ONE_SHOT)
	if _queue.is_empty():
		leaving.arrived.connect(_on_day_finished, CONNECT_ONE_SHOT)
		return
	# Giden biraz uzaklaşınca sıradakiler adım atar
	await get_tree().create_timer(0.6).timeout
	_at_counter = _queue.pop_front()
	_at_counter.walk_to(COUNTER_POS, COUNTER_SCALE)
	_at_counter.arrived.connect(_on_customer_at_counter, CONNECT_ONE_SHOT)
	for i: int in range(_queue.size()):
		var walker: CustomerWalker = _queue[i]
		get_tree().create_timer(0.25 * (i + 1)).timeout.connect(
			walker.walk_to.bind(_queue_spot(i), _queue_scale(i)))
	_update_hud()

func _on_day_finished() -> void:
	_update_hud()
	_show_action("Bugünlük bu kadar · Gün Sonu Özeti  ▶", CareerManager.show_day_summary)

# --- Konuşma balonu -----------------------------------------------------------

func _say(customer: CustomerData, text: String, then: Callable) -> void:
	_name_label.text = customer.display_name
	_role_label.text = customer.role
	var tag_style: StyleBoxFlat = _name_tag.get_theme_stylebox("panel").duplicate()
	tag_style.bg_color = customer.accent
	_name_tag.add_theme_stylebox_override("panel", tag_style)
	_text_label.text = "“" + text + "”"
	_text_label.visible_characters = 0
	_type_progress = 0.0
	_typing = true
	_after_typing = then
	_bubble.visible = true
	_name_tag.visible = true
	_bubble.scale = Vector2(0.85, 0.85)
	_bubble.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bubble, "scale", Vector2.ONE, 0.25)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.15)

func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	if _after_typing.is_valid():
		var then: Callable = _after_typing
		_after_typing = Callable()
		then.call()

func _hide_bubble() -> void:
	_bubble.visible = false
	_name_tag.visible = false
	_extras.visible = false
	ui.queue_redraw()

# Balonu müşterinin başının üstüne (ekrana sığacak şekilde) yerleştirir
func _layout_bubble() -> void:
	if _bubble == null or not _bubble.visible:
		return
	var width: float = minf(size.x - 32.0, 700.0)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0)
	var head: Vector2 = _head_screen_pos()
	var top: float = 104.0
	var x: float = clampf(head.x - width * 0.45, 16.0, size.x - width - 16.0)
	_bubble.position = Vector2(x, top)
	_bubble.pivot_offset = Vector2(width / 2.0, _bubble.size.y)
	_name_tag.position = _bubble.position + Vector2(22, -24)
	ui.queue_redraw()

func _head_screen_pos() -> Vector2:
	var head_world: Vector2 = COUNTER_POS + Vector2(0, -CustomerWalker.FIGURE_HEIGHT * COUNTER_SCALE * 0.95)
	return world.get_global_transform() * head_world

# Balonun kuyruğu: müşterinin başına doğru üçgen
func _draw_tail() -> void:
	if _bubble == null or not _bubble.visible or _bubble.modulate.a < 0.99:
		return
	var head: Vector2 = _head_screen_pos()
	var bottom: float = _bubble.position.y + _bubble.size.y
	var base_x: float = clampf(head.x - 60.0, _bubble.position.x + 40.0, _bubble.position.x + _bubble.size.x - 100.0)
	var tip: Vector2 = Vector2(head.x + 10.0, maxf(bottom + 50.0, minf(head.y - 10.0, bottom + 90.0)))
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(base_x, bottom - 4.0), tip, Vector2(base_x + 56.0, bottom - 4.0)])
	ui.draw_colored_polygon(pts, CREAM)
	ui.draw_polyline(pts, INK, 4.0, true)

func _gui_input(event: InputEvent) -> void:
	# Ekrana dokunmak yazmayı hızlandırır (tüm metni gösterir)
	if _typing and event is InputEventMouseButton and event.pressed:
		_finish_typing()

# --- Arayüz -------------------------------------------------------------------

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ui.draw.connect(_draw_tail)

	# Sağ üst: kasa ve gün
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -18
	top.offset_right = -18
	top.offset_top = 18
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(top)
	var money_pill: PanelContainer = _dark_pill()
	var money_row: HBoxContainer = HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)
	var coin: Label = _make_label("₺", 18, INK, true)
	var coin_box: PanelContainer = PanelContainer.new()
	var coin_style: StyleBoxFlat = UIStyle.box(GOLD, 15)
	coin_style.set_content_margin_all(2)
	coin_style.content_margin_left = 8
	coin_style.content_margin_right = 8
	coin_box.add_theme_stylebox_override("panel", coin_style)
	coin_box.add_child(coin)
	money_row.add_child(coin_box)
	_money_label = _make_label("0", 28, BUTTON_BG, true)
	money_row.add_child(_money_label)
	money_pill.add_child(money_row)
	top.add_child(money_pill)
	var day_pill: PanelContainer = _dark_pill()
	_day_label = _make_label("", 22, BUTTON_BG, true)
	day_pill.add_child(_day_label)
	top.add_child(day_pill)

	# Sol üst: menü
	var menu_button: Button = _shop_button("◀ Menü", 18, 46)
	menu_button.position = Vector2(16, 18)
	menu_button.pressed.connect(GameManager.go_to_menu)
	ui.add_child(menu_button)

	# Sıradaki müşteri sayısı
	var queue_pill: PanelContainer = _dark_pill(999)
	_queue_label = _make_label("", 16, BUTTON_BG, false)
	queue_pill.add_child(_queue_label)
	queue_pill.anchor_left = 1.0
	queue_pill.anchor_right = 1.0
	queue_pill.offset_left = -18
	queue_pill.offset_right = -18
	queue_pill.offset_top = 82
	queue_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(queue_pill)

	# Konuşma balonu
	_bubble = PanelContainer.new()
	var bubble_style: StyleBoxFlat = UIStyle.box(CREAM, 22, 4, INK, INK, 1, Vector2(6, 6))
	bubble_style.content_margin_left = 26
	bubble_style.content_margin_right = 26
	bubble_style.content_margin_top = 34
	bubble_style.content_margin_bottom = 20
	_bubble.add_theme_stylebox_override("panel", bubble_style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_text_label = _make_label("", 24, INK, false)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Yazarken balon büyümesin: satırlar baştan tam metne göre dizilir
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	vbox.add_child(_text_label)
	_extras = VBoxContainer.new()
	_extras.add_theme_constant_override("separation", 2)
	vbox.add_child(_extras)
	_bubble.add_child(vbox)
	_bubble.visible = false
	ui.add_child(_bubble)

	# İsim etiketi (balonun üst kenarına taşar)
	_name_tag = PanelContainer.new()
	var tag_style: StyleBoxFlat = UIStyle.box(GOLD, 12, 4, INK)
	tag_style.content_margin_left = 14
	tag_style.content_margin_right = 14
	tag_style.content_margin_top = 2
	tag_style.content_margin_bottom = 2
	_name_tag.add_theme_stylebox_override("panel", tag_style)
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 8)
	_name_label = _make_label("", 24, INK, true)
	_role_label = _make_label("", 14, INK, false)
	_role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag_row.add_child(_name_label)
	tag_row.add_child(_role_label)
	_name_tag.add_child(tag_row)
	_name_tag.visible = false
	ui.add_child(_name_tag)

	# Alt: eylem butonu (tezgâhın üstünde)
	_action_button = _shop_button("", 26, 72)
	_action_button.anchor_left = 0.5
	_action_button.anchor_right = 0.5
	_action_button.anchor_top = 1.0
	_action_button.anchor_bottom = 1.0
	_action_button.offset_top = -36 - 72
	_action_button.offset_bottom = -36
	_action_button.visible = false
	ui.add_child(_action_button)

func _show_action(text: String, action: Callable) -> void:
	for connection: Dictionary in _action_button.pressed.get_connections():
		_action_button.pressed.disconnect(connection["callable"])
	_action_button.text = text
	_action_button.pressed.connect(action, CONNECT_ONE_SHOT)
	_action_button.visible = true
	_action_button.reset_size()
	_action_button.offset_left = -_action_button.size.x / 2.0
	_action_button.offset_right = _action_button.size.x / 2.0
	_action_button.pivot_offset = _action_button.size / 2.0
	_action_button.scale = Vector2(0.8, 0.8)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_action_button, "scale", Vector2.ONE, 0.2)

func _hide_action() -> void:
	_action_button.visible = false

func _update_hud() -> void:
	_update_money()
	_day_label.text = "GÜN %d" % CareerManager.day
	var waiting: int = _queue.size()
	_queue_label.text = "Sırada %d müşteri" % waiting if waiting > 0 else "Sırada kimse yok"

func _update_money() -> void:
	var text: String = _format_money(int(_shown_money))
	_money_label.text = text
	_till_label.text = "₺ " + text

# 12450 → "12.450"
func _format_money(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

func _make_label(text: String, font_size: int, color: Color, display: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", UIStyle.shop_font(display, 800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _receipt_row(left: String, right: String, color: Color, font_size: int = 19) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = _make_label(left, font_size, color, font_size > 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_make_label(right, font_size, color, true))
	return row

func _dark_pill(radius: int = 14) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UIStyle.box(INK, radius, 0, Color.TRANSPARENT, WOOD_SHADOW, 1, Vector2(4, 4))
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill

# Tasarımdaki krem renkli, kalın çerçeveli, sert gölgeli buton
func _shop_button(text: String, font_size: int, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, height)
	var normal: StyleBoxFlat = UIStyle.box(BUTTON_BG, 14, 4, INK, INK, 1, Vector2(5, 5))
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#FFF6E3")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.shadow_offset = Vector2(2, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", UIStyle.shop_font(true, 800))
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, INK)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
