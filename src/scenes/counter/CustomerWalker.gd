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
	else:
		# Beklerken hafif nefes alma
		_idle_time += delta
		_sprite.position.y = sin(_idle_time * 2.2) * 2.0
