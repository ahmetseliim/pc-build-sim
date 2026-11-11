class_name CustomerWalker
extends Node2D

# Tezgâhtaki müşteri figürü
# Düğüm konumu müşterinin "ayak" noktasıdır (görselin alt ortası); bu sayede
# y-sıralama ile öndeki müşteri arkadakinin üstünde çizilir ve salınım
# (sağa-sola dönme) ayak noktası etrafında olur.
# Yürürken: hedefe doğru ilerler, perspektif için boyutu değişir, küçük açılarla
# saat yönünde / tersine salınır ve adım adım hafifçe zıplar ("fıtı fıtı").

signal arrived

const FIGURE_HEIGHT: float = 640.0 ## scale = 1 iken figürün dünya birimindeki yüksekliği
const STEP_SPEED: float = 15.0 ## Adım frekansı (radyan/sn)
const SWAY_DEG: float = 6.0 ## Salınım açısı
const BOB_HEIGHT: float = 18.0 ## Adım zıplaması (scale = 1 iken dünya birimi)
const WALK_SPEED: float = 300.0 ## Dünya birimi/sn (yakın plandaki hız)
## Belden yukarı görsellerde yüzün yeri (görsel yüksekliğine oran): merkez üstten, yarı genişlik
const FACE_CENTER_Y: float = 0.40
const FACE_HALF_WIDTH: float = 0.13
## Tezgâhta belirme ve kaybolma (Good Pizza, Great Pizza'daki gibi: müşteri tezgâhın arkasından yükselir)
const RISE_DEPTH: float = 0.8 ## Başlangıçta figür yüksekliğinin bu kadarı tezgâhın altında
const RISE_TIME: float = 0.32
const SINK_TIME: float = 0.26
const TALK_INTERVAL: float = 0.11 ## Konuşurken ağız açma-kapama aralığı (sn)

var data: CustomerData = null

var _sprite: Sprite2D = null
var _walking: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _from_scale: float = 1.0
var _to_scale: float = 1.0
var _duration: float = 1.0
var _t: float = 0.0
var _phase: float = 0.0
var _fade: String = "" ## "in": girişte belir, "out": çıkışta kaybol
var _idle_time: float = 0.0
var _animating: bool = false ## Yükselme/alçalma sırasında nefes alma durur
var _mood: String = "normal"
var _talking: bool = false
var _talk_time: float = 0.0

func setup(customer: CustomerData, start: Vector2, start_scale: float) -> void:
	data = customer
	_sprite = Sprite2D.new()
	_sprite.texture = customer.texture
	_sprite.centered = false
	var tex_size: Vector2 = customer.texture.get_size()
	_sprite.offset = Vector2(-tex_size.x / 2.0, -tex_size.y)
	_sprite.scale = Vector2.ONE * (FIGURE_HEIGHT / tex_size.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	position = start
	set_figure_scale(start_scale)
	_idle_time = randf() * TAU

# Yüz ifadesi: "normal", "happy" (memnun), "sad" (kırgın). Görseli olmayan ifade normal kalır.
func set_mood(mood: String) -> void:
	_mood = mood
	_sprite.texture = _mood_texture()

func current_mood() -> String:
	return _mood

func _mood_texture() -> Texture2D:
	if _mood == "happy" and data.texture_happy:
		return data.texture_happy
	if _mood == "sad" and data.texture_sad:
		return data.texture_sad
	return data.texture

# Konuşurken ağız açılıp kapanır (konuşma görseli varsa); yoksa yalnız hafif baş sallama
func set_talking(value: bool) -> void:
	_talking = value
	_talk_time = 0.0
	_sprite.texture = _mood_texture()
	_sprite.scale.y = _sprite.scale.x

# Tezgâhın arkasından yükselir (bitince "arrived")
func rise_in() -> void:
	_animating = true
	_sprite.position = Vector2(0, FIGURE_HEIGHT * RISE_DEPTH)
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, "position:y", 0.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, RISE_TIME * 0.3)
	tween.chain().tween_callback(func() -> void:
		_animating = false
		arrived.emit())

# Tezgâhın arkasına iner ve kaybolur (bitince "arrived")
func sink_out() -> void:
	_animating = true
	set_talking(false)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position:y", FIGURE_HEIGHT * RISE_DEPTH, SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: arrived.emit())

# Sıradaki küçük figür yerini tezgâhtaki büyük figüre bırakırken söner
func fade_out(duration: float = 0.2) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)

# Yüzün dünya koordinatındaki merkezi ve yarı genişliği (konuşma balonu yüzü kapatmasın diye)
func face_center() -> Vector2:
	return position + Vector2(0, -FIGURE_HEIGHT * figure_scale() * (1.0 - FACE_CENTER_Y))

func face_half_width() -> float:
	return FIGURE_HEIGHT * figure_scale() * FACE_HALF_WIDTH

func set_figure_scale(s: float) -> void:
	scale = Vector2(s, s)

func figure_scale() -> float:
	return scale.x

# Hedefe yürür; bitince "arrived" yayılır. fade: "in" / "out" / ""
func walk_to(target: Vector2, target_scale: float, fade: String = "") -> void:
	_from = position
	_to = target
	_from_scale = figure_scale()
	_to_scale = target_scale
	# Uzaktaki (küçük) figür ekranda daha az yol alır; süreyi ortalama boyuta göre ayarla
	var avg_scale: float = (_from_scale + _to_scale) / 2.0
	_duration = clampf(_from.distance_to(_to) / (WALK_SPEED * maxf(avg_scale, 0.3)), 0.6, 3.2)
	_t = 0.0
	_fade = fade
	_walking = true
	if fade == "in":
		modulate.a = 0.0

func is_walking() -> bool:
	return _walking

# Adımlar yolun başında ve sonunda yavaşlayarak söner
func _process(delta: float) -> void:
	if _walking:
		_t = minf(_t + delta / _duration, 1.0)
		var e: float = _t * _t * (3.0 - 2.0 * _t)
		position = _from.lerp(_to, e)
		set_figure_scale(lerpf(_from_scale, _to_scale, e))
		_phase += delta * STEP_SPEED
		# Adım genliği yolun başında ve sonunda söner
		var amp: float = clampf(minf(_t, 1.0 - _t) * 8.0, 0.0, 1.0)
		rotation = deg_to_rad(SWAY_DEG) * sin(_phase) * amp
		_sprite.position.y = -absf(sin(_phase)) * BOB_HEIGHT * amp
		if _fade == "in":
			modulate.a = clampf(_t * 5.0, 0.0, 1.0)
		elif _fade == "out":
			modulate.a = clampf((1.0 - _t) * 4.0, 0.0, 1.0)
		if _t >= 1.0:
			_walking = false
			rotation = 0.0
			_sprite.position = Vector2.ZERO
			arrived.emit()
	elif not _animating:
		# Beklerken hafif nefes alma
		_idle_time += delta
		_sprite.position.y = sin(_idle_time * 2.2) * 2.0
	if _talking:
		_talk_time += delta
		var open: bool = int(_talk_time / TALK_INTERVAL) % 2 == 1
		if _mood == "normal" and data.texture_talk:
			_sprite.texture = data.texture_talk if open else data.texture
		else:
			# Konuşma görseli yoksa: hece başına çok hafif esneme
			_sprite.scale.y = _sprite.scale.x * (1.012 if open else 1.0)
