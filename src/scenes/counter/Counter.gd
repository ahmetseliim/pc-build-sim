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
const COUNTER_SCALE: float = 1.24 ## Tezgâhtaki müşteri büyük görünür (belden yukarı, yüzü açık)
const BUBBLE_GAP: float = 34.0 ## Balon ile yüz arasındaki boşluk (ekran birimi)
const QUEUE_FIRST: Vector2 = Vector2(1265, 790) ## Sıradaki ilk bekleme noktası
const QUEUE_STEP: Vector2 = Vector2(108, -17) ## Her arkadaki kişi için kayma
const QUEUE_FIRST_SCALE: float = 0.56
const QUEUE_SCALE_STEP: float = 0.045
const ENTER_DELAY: float = 0.9 ## Gün başında müşterilerin kapıdan giriş aralığı (sn)
const TYPE_SPEED: float = 55.0 ## Konuşma balonunda harf/sn
const BUBBLE_DELAY: float = 0.25 ## Müşteri yerine oturduktan sonra balonun açılması (sn)
const EXIT_SPOT: Vector2 = Vector2(1000, 800) ## Tezgâhtan inen müşterinin küçük hâliyle kapıya yürümeye başladığı yer

## Rafta parça olmadığı için geri gönderilen müşterinin sözü
const TURNED_AWAY_LINE: String = "Hay aksi... Peki, başka bir dükkâna bakarım o zaman."

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
	["AÇIK", Vector2(688, 284), 30, Color("#B4544A")],
	["PC TAMİRCİSİ", Vector2(990, 104), 30, Color("#1E1A17")],
	["TAMİR", Vector2(990, 244), 22, Color("#F2C14E")],
	["Format · Kurulum", Vector2(990, 268), 16, Color("#F4EBDD")],
	["Parça Değişimi", Vector2(990, 289), 16, Color("#F4EBDD")],
	["Termal Bakım", Vector2(990, 310), 16, Color("#F4EBDD")],
	["RAM", Vector2(1813, 226), 20, Color("#1E1A17")],
	["SSD", Vector2(1814, 606), 16, Color("#1E1A17")],
]
const TILL_POS: Vector2 = Vector2(1653, 712) ## Yazar kasa ekranı (kasadaki parayı gösterir)
## Satın alınınca tezgâhın üstünde görünen dekorlar: alım id'si -> [görsel, tezgâh üstündeki alt orta nokta, genişlik]
const COUNTER_DECOR: Dictionary = {
	"cay_ocagi": ["res://assets/shop/cay_ocagi.png", Vector2(800, 852), 200.0],
}

@onready var backdrop: ColorRect = $Backdrop
@onready var world: Node2D = $World
@onready var signs: Node2D = $World/Signs
@onready var crowd: Node2D = $World/Crowd
@onready var front: Sprite2D = $World/Front
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
	_build_decor()
	_build_ui()
	_shown_money = CareerManager.money
	if CareerManager.counter_mode == "farewell":
		_shown_money -= int(CareerManager.last_result.get("pay", 0)) + int(CareerManager.last_result.get("tip", 0))
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

# Alınan dekorlar tezgâhın önündeki katmanın üstüne konur (Good Pizza'daki gibi alım dükkânda görünür)
func _build_decor() -> void:
	for id: String in COUNTER_DECOR:
		var entry: Array = COUNTER_DECOR[id]
		if not CareerManager.has_upgrade(id) or not ResourceLoader.exists(entry[0]):
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(entry[0])
		sprite.centered = false
		var tex_size: Vector2 = sprite.texture.get_size()
		var s: float = float(entry[2]) / tex_size.x
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(entry[1]) - Vector2(tex_size.x * s / 2.0, tex_size.y * s)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		world.add_child(sprite)
		world.move_child(sprite, front.get_index() + 1)

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
	AudioManager.play_sfx("bell")
	var first: int = CareerManager.job_index
	var day_start: bool = first == 0
	_at_counter = _spawn(first, COUNTER_POS, COUNTER_SCALE)
	_at_counter.modulate.a = 0.0
	get_tree().create_timer(0.35).timeout.connect(_rise_at_counter.bind(_at_counter))
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

# Müşteri tezgâhın arkasından yükselir; yerine oturunca kısa bir bekleyişle konuşmaya başlar
func _rise_at_counter(walker: CustomerWalker) -> void:
	if not is_instance_valid(walker):
		return
	walker.arrived.connect(func() -> void:
		get_tree().create_timer(BUBBLE_DELAY).timeout.connect(_on_customer_at_counter), CONNECT_ONE_SHOT)
	walker.rise_in()

func _on_customer_at_counter() -> void:
	if _at_counter == null:
		return
	_update_hud()
	var customer: CustomerData = _at_counter.data
	# Arıza burada belirlenir: müşterinin anlattığı ile iş emrindeki aynı olur
	GameManager.prepare_job(CareerManager.current_scenario())
	var complaint: String = GameManager.get_complaint()
	var text: String = complaint if customer.greeting == "" else customer.greeting + " " + complaint
	var missing: UpgradeData = CareerManager.current_job_missing()
	if missing:
		_say(customer, text, _offer_turn_away.bind(missing))
	else:
		_say(customer, text, _offer_workshop)

func _offer_workshop() -> void:
	_show_action("Bilgisayarı Atölyeye Al  ▶", CareerManager.enter_workshop)

# Bu işin parçası rafta yok: iş kabul edilemez (gün sonu mağazasından alınır)
func _offer_turn_away(missing: UpgradeData) -> void:
	_show_action("%s yok · Üzgünüm, yapamam  ▶" % missing.title, _turn_away)

func _turn_away() -> void:
	_hide_action()
	CareerManager.turn_away_current()
	AudioManager.play_sfx("warn")
	_at_counter.set_mood("sad")
	_say(_at_counter.data, TURNED_AWAY_LINE, _leave_after.bind(1.2))

func _leave_after(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_send_off()

# --- Teslim ve ödeme ----------------------------------------------------------

func _setup_farewell() -> void:
	var r: Dictionary = CareerManager.last_result
	var index: int = int(r.get("customer_index", CareerManager.job_index - 1))
	_at_counter = _spawn(index, COUNTER_POS, COUNTER_SCALE)
	for i: int in range(index + 1, CareerManager.day_queue.size()):
		var slot: int = _queue.size()
		_queue.append(_spawn(i, _queue_spot(slot), _queue_scale(slot)))
	var stars: int = int(r.get("stars", 0))
	_at_counter.set_mood("happy" if stars >= 4 else ("sad" if stars <= 2 else "normal"))
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
	var tip: int = int(r.get("tip", 0))
	if tip > 0:
		_extras.add_child(_receipt_row("Bahşiş", "+%d ₺" % tip, Color("#A16207")))
	_extras.add_child(_receipt_row("Ödenen", "+%d ₺" % (pay + tip), GREEN, 26))
	_extras.visible = false

func _show_payment(r: Dictionary) -> void:
	_extras.visible = true
	# Para kasaya sayarak girer (_process); şimdiye kadar eski değerde bekliyordu
	_counting = true
	AudioManager.play_sfx("coin")
	_show_action("Güle güle!  ▶", _send_off)

# Müşteri kapıdan çıkar, sıradakiler ilerler
func _send_off() -> void:
	_hide_bubble()
	_hide_action()
	var leaving: CustomerWalker = _at_counter
	_at_counter = null
	# Tezgâhın arkasına iner, sonra küçük hâliyle kapıdan çıkar
	var index: int = _customer_index_of(leaving)
	leaving.arrived.connect(func() -> void:
		leaving.queue_free()
		if index >= 0:
			var walker: CustomerWalker = _spawn(index, EXIT_SPOT, QUEUE_FIRST_SCALE)
			walker.set_mood(leaving.current_mood())
			walker.walk_to(DOOR_POS, DOOR_SCALE, "out")
			walker.arrived.connect(walker.queue_free, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
	leaving.sink_out()
	if _queue.is_empty():
		get_tree().create_timer(1.6).timeout.connect(_on_day_finished)
		return
	# Sıradaki öne çıkar: küçük hâli söner, büyük hâli tezgâhın arkasından yükselir
	await get_tree().create_timer(0.45).timeout
	var next_small: CustomerWalker = _queue.pop_front()
	var next_index: int = CareerManager.job_index
	next_small.fade_out()
	_at_counter = _spawn(next_index, COUNTER_POS, COUNTER_SCALE)
	_at_counter.modulate.a = 0.0
	_rise_at_counter(_at_counter)
	for i: int in range(_queue.size()):
		var walker: CustomerWalker = _queue[i]
		get_tree().create_timer(0.25 * (i + 1)).timeout.connect(
			walker.walk_to.bind(_queue_spot(i), _queue_scale(i)))
	_update_hud()

# Figürün günün kaçıncı müşterisi olduğu (kapıdan çıkan küçük hâli için)
func _customer_index_of(walker: CustomerWalker) -> int:
	for i: int in range(CareerManager.day_customers.size()):
		if CareerManager.customer_at(i) == walker.data:
			return i
	return -1

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
	if _at_counter:
		_at_counter.set_talking(true)
	_bubble.visible = true
	_name_tag.visible = true
	_bubble.scale = Vector2(0.85, 0.85)
	_bubble.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bubble, "scale", Vector2.ONE, 0.25)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.15)

func _finish_typing() -> void:
	_typing = false
	if _at_counter:
		_at_counter.set_talking(false)
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

# Balonu yüzün yanına, ekranda daha geniş olan tarafa yerleştirir (yüzü kapatmaz;
# müşterinin ifadesi hep görünür). Yer yetmezse eski düzene, başın üstüne döner.
func _layout_bubble() -> void:
	if _bubble == null or not _bubble.visible:
		return
	var ui_zoom: float = UIStyle.ui_scale(get_viewport())
	var face: Vector2 = _face_screen_pos()
	var half: float = _face_half_screen()
	var margin: float = 16.0 + UIStyle.safe_side()
	var left_room: float = face.x - half - BUBBLE_GAP - margin
	var right_room: float = size.x - (face.x + half + BUBBLE_GAP) - margin
	var on_right: bool = right_room >= left_room
	var room: float = maxf(left_room, right_room)
	var width: float = minf(room, 700.0 * ui_zoom)
	var beside: bool = width >= 380.0 * ui_zoom
	if not beside:
		width = minf(size.x - 2.0 * margin, 700.0 * ui_zoom)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0)
	var height: float = _bubble.get_combined_minimum_size().y
	var top_limit: float = 90.0 * ui_zoom
	if UIStyle.is_compact() and _queue_label:
		# Yatay telefonda sıra etiketi sol üstte: isim etiketi onun üstüne binmesin
		top_limit = maxf(top_limit, _queue_label.get_parent().get_global_rect().end.y + 30.0 * ui_zoom)
	var bottom_limit: float = size.y - (_action_button.size.y + 60.0 if _action_button.visible else 40.0)
	var x: float
	var y: float
	if beside:
		x = face.x + half + BUBBLE_GAP if on_right else face.x - half - BUBBLE_GAP - width
		y = clampf(face.y - height * 0.35, top_limit, maxf(top_limit, bottom_limit - height))
	else:
		x = clampf(face.x - width * 0.45, margin, size.x - width - margin)
		y = top_limit
	_bubble.position = Vector2(x, y)
	_bubble.pivot_offset = Vector2(0.0 if on_right else width, height * 0.35) if beside else Vector2(width / 2.0, height)
	_name_tag.position = _bubble.position + Vector2(22, -24.0 * ui_zoom)
	ui.queue_redraw()

func _face_screen_pos() -> Vector2:
	if _at_counter:
		return world.get_global_transform() * _at_counter.face_center()
	var face_world: Vector2 = COUNTER_POS + Vector2(0, -CustomerWalker.FIGURE_HEIGHT * COUNTER_SCALE * (1.0 - CustomerWalker.FACE_CENTER_Y))
	return world.get_global_transform() * face_world

func _face_half_screen() -> float:
	return CustomerWalker.FIGURE_HEIGHT * COUNTER_SCALE * CustomerWalker.FACE_HALF_WIDTH * world.scale.x

# Balonun kuyruğu: yüze doğru üçgen (balon yandaysa yandan, üstteyse alttan çıkar)
func _draw_tail() -> void:
	if _bubble == null or not _bubble.visible or _bubble.modulate.a < 0.99:
		return
	var face: Vector2 = _face_screen_pos()
	var half: float = _face_half_screen()
	var r: Rect2 = Rect2(_bubble.position, _bubble.size)
	var pts: PackedVector2Array
	if face.x - half >= r.end.x - 4.0 or face.x + half <= r.position.x + 4.0:
		var right_side: bool = face.x > r.end.x
		var edge: float = r.end.x - 4.0 if right_side else r.position.x + 4.0
		var base_y: float = clampf(face.y - 26.0, r.position.y + 30.0, r.end.y - 70.0)
		var tip_x: float = face.x - half - 6.0 if right_side else face.x + half + 6.0
		var tip: Vector2 = Vector2(tip_x, clampf(face.y, r.position.y + 20.0, r.end.y + 40.0))
		pts = PackedVector2Array([Vector2(edge, base_y), tip, Vector2(edge, base_y + 52.0)])
	else:
		var bottom: float = r.end.y
		var base_x: float = clampf(face.x - 60.0, r.position.x + 40.0, r.end.x - 100.0)
		var tip_down: Vector2 = Vector2(face.x + 10.0, maxf(bottom + 50.0, minf(face.y - half, bottom + 90.0)))
		pts = PackedVector2Array([Vector2(base_x, bottom - 4.0), tip_down, Vector2(base_x + 56.0, bottom - 4.0)])
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
	top.offset_left = -18.0 - UIStyle.safe_side()
	top.offset_right = -18.0 - UIStyle.safe_side()
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
	menu_button.position = Vector2(16.0 + UIStyle.safe_side(), 18.0)
	menu_button.pressed.connect(GameManager.go_to_menu)
	ui.add_child(menu_button)

	# Sıradaki müşteri sayısı
	var queue_pill: PanelContainer = _dark_pill(999)
	_queue_label = _make_label("", 16, BUTTON_BG, false)
	queue_pill.add_child(_queue_label)
	queue_pill.anchor_left = 1.0
	queue_pill.anchor_right = 1.0
	queue_pill.offset_left = -18.0 - UIStyle.safe_side()
	queue_pill.offset_right = -18.0 - UIStyle.safe_side()
	queue_pill.offset_top = 82.0 * UIStyle.ui_scale(get_viewport())
	queue_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if UIStyle.is_compact():
		# Yatay telefonda balonla çakışmasın diye menünün altına
		queue_pill.anchor_left = 0.0
		queue_pill.anchor_right = 0.0
		queue_pill.offset_left = 16.0 + UIStyle.safe_side()
		queue_pill.offset_right = 16.0 + UIStyle.safe_side()
		queue_pill.grow_horizontal = Control.GROW_DIRECTION_END
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
	var action_height: float = _action_button.custom_minimum_size.y
	_action_button.anchor_left = 0.5
	_action_button.anchor_right = 0.5
	_action_button.anchor_top = 1.0
	_action_button.anchor_bottom = 1.0
	_action_button.offset_top = -36.0 - action_height
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
	font_size = UIStyle.scaled(get_viewport(), font_size)
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
	font_size = UIStyle.scaled(get_viewport(), font_size)
	height *= UIStyle.ui_scale(get_viewport())
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
