extends Node

# Ses Yöneticisi (AudioManager)
# Oyun içi ses efektlerini ve müziği yönetir. Efektler harici dosya gerektirmesin diye
# açılışta kodla üretilir; ileride gerçek kayıtlar aynı adla loaded_sounds'a konabilir.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 6
const SETTINGS_PATH: String = "user://ayarlar.cfg"

enum Wave { SINE, SQUARE, SAW }

var muted: bool = false
var loaded_sounds: Dictionary = {}

var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _loop_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _mistake_frame: int = -1

func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_loop_player = AudioStreamPlayer.new()
	add_child(_loop_player)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_load_settings()
	_build_sounds()

	EventBus.part_drag_started.connect(func(_part: Control) -> void: play_sfx("pick"))
	EventBus.warning_requested.connect(_on_warning)
	EventBus.mistake_made.connect(_on_mistake)
	EventBus.paste_failed.connect(func() -> void: _on_mistake("paste_spill"))
	EventBus.paste_applied.connect(func() -> void: play_sfx("done"))
	EventBus.bios_boot_started.connect(func() -> void: play_sfx("boot_beep"))
	EventBus.bios_boot_finished.connect(func() -> void: play_sfx("boot_ok"))
	EventBus.boot_failed.connect(func() -> void: play_sfx("boot_fail"))
	get_tree().node_added.connect(_on_node_added)

# Ses efekti çalar (aynı anda birkaç efekt üst üste gelebilir)
func play_sfx(sound_name: String) -> void:
	if muted or not loaded_sounds.has(sound_name):
		return
	var player: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = loaded_sounds[sound_name]
	player.play()

# Basılı tutma boyunca çalan döngülü ses (vida sıkma)
func start_loop(sound_name: String) -> void:
	if muted or not loaded_sounds.has(sound_name):
		return
	_loop_player.stream = loaded_sounds[sound_name]
	_loop_player.play()

func stop_loop() -> void:
	_loop_player.stop()

# Müzik çalar
func play_music(track_name: String) -> void:
	if muted or not loaded_sounds.has(track_name):
		return
	_music_player.stream = loaded_sounds[track_name]
	_music_player.play()

# Müziği durdurur
func stop_music() -> void:
	_music_player.stop()

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_loop()
		stop_music()
	var config: ConfigFile = ConfigFile.new()
	config.set_value("ses", "kapali", muted)
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		muted = bool(config.get_value("ses", "kapali", false))

# Yeni oluşan her buton tıklama sesi alır
func _on_node_added(node: Node) -> void:
	var button: Button = node as Button
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play_sfx("click")

func _on_mistake(_kind: String) -> void:
	_mistake_frame = Engine.get_process_frames()
	play_sfx("mistake")

# Aynı karede hata sesi çaldıysa uyarı sesi üstüne binmesin
func _on_warning(_message: String) -> void:
	if Engine.get_process_frames() != _mistake_frame:
		play_sfx("warn")

# --- Ses üretimi --------------------------------------------------------------

func _build_sounds() -> void:
	var click: PackedFloat32Array = _buffer(0.05)
	_tone(click, 0.0, 0.05, 1400.0, 900.0, 0.22)
	_store("click", click)

	var pick: PackedFloat32Array = _buffer(0.09)
	_tone(pick, 0.0, 0.09, 420.0, 760.0, 0.25)
	_store("pick", pick)

	var place: PackedFloat32Array = _buffer(0.1)
	_tone(place, 0.0, 0.025, 2300.0, 1200.0, 0.3, Wave.SQUARE)
	_tone(place, 0.012, 0.085, 190.0, 110.0, 0.45)
	_store("place", place)

	var latch: PackedFloat32Array = _buffer(0.05)
	_tone(latch, 0.0, 0.05, 1900.0, 2500.0, 0.25, Wave.SQUARE)
	_store("latch", latch)

	var pop: PackedFloat32Array = _buffer(0.12)
	_tone(pop, 0.0, 0.12, 900.0, 180.0, 0.4)
	_store("pop", pop)

	var screw_done: PackedFloat32Array = _buffer(0.14)
	_tone(screw_done, 0.0, 0.03, 2000.0, 1300.0, 0.3, Wave.SQUARE)
	_tone(screw_done, 0.03, 0.11, 1250.0, 1250.0, 0.2)
	_store("screw_done", screw_done)

	var done: PackedFloat32Array = _buffer(0.32)
	_tone(done, 0.0, 0.12, 659.0, 659.0, 0.25)
	_tone(done, 0.1, 0.22, 988.0, 988.0, 0.25)
	_store("done", done)

	var warn: PackedFloat32Array = _buffer(0.16)
	_tone(warn, 0.0, 0.16, 330.0, 240.0, 0.25)
	_store("warn", warn)

	var mistake: PackedFloat32Array = _buffer(0.28)
	_tone(mistake, 0.0, 0.14, 165.0, 150.0, 0.3, Wave.SQUARE)
	_tone(mistake, 0.13, 0.15, 131.0, 118.0, 0.3, Wave.SQUARE)
	_store("mistake", mistake)

	var boot_beep: PackedFloat32Array = _buffer(0.2)
	_tone(boot_beep, 0.0, 0.2, 1000.0, 1000.0, 0.22, Wave.SQUARE, false)
	_store("boot_beep", boot_beep)

	var boot_ok: PackedFloat32Array = _buffer(0.62)
	_tone(boot_ok, 0.0, 0.16, 523.0, 523.0, 0.28)
	_tone(boot_ok, 0.14, 0.16, 659.0, 659.0, 0.28)
	_tone(boot_ok, 0.28, 0.34, 784.0, 784.0, 0.32)
	_store("boot_ok", boot_ok)

	var boot_fail: PackedFloat32Array = _buffer(0.7)
	for i: int in range(3):
		_tone(boot_fail, 0.24 * i, 0.16, 800.0, 800.0, 0.22, Wave.SQUARE, false)
	_store("boot_fail", boot_fail)

	var coin: PackedFloat32Array = _buffer(0.42)
	_tone(coin, 0.0, 0.08, 1319.0, 1319.0, 0.25)
	_tone(coin, 0.07, 0.35, 1760.0, 1760.0, 0.28)
	_store("coin", coin)

	var bell: PackedFloat32Array = _buffer(0.8)
	_tone(bell, 0.0, 0.8, 1568.0, 1568.0, 0.2)
	_tone(bell, 0.0, 0.5, 2349.0, 2349.0, 0.1)
	_tone(bell, 0.16, 0.64, 1319.0, 1319.0, 0.18)
	_store("bell", bell)

	# Tornavida cızırtısı: tam sayıda dalgayla kesintisiz döner
	var loop: PackedFloat32Array = _buffer(0.25)
	_tone(loop, 0.0, 0.25, 120.0, 120.0, 0.11, Wave.SAW, false)
	_tone(loop, 0.0, 0.25, 240.0, 240.0, 0.06, Wave.SQUARE, false)
	_store("screw_loop", loop, true)

func _buffer(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(duration * MIX_RATE))
	return samples

# Tampona frekansı f0'dan f1'e kayan bir ton ekler
func _tone(samples: PackedFloat32Array, start: float, duration: float, f0: float, f1: float, volume: float, wave: Wave = Wave.SINE, decay: bool = true) -> void:
	var first: int = int(start * MIX_RATE)
	var count: int = mini(int(duration * MIX_RATE), samples.size() - first)
	var phase: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / float(count)
		phase = fmod(phase + lerpf(f0, f1, t) / MIX_RATE, 1.0)
		var value: float = sin(TAU * phase)
		if wave == Wave.SQUARE:
			value = 1.0 if phase < 0.5 else -1.0
		elif wave == Wave.SAW:
			value = 2.0 * phase - 1.0
		var envelope: float = exp(-5.0 * t) if decay else 1.0
		# Başta ve sonda çıt sesi olmasın
		var edge: float = minf(1.0, minf(float(i), float(count - i)) / 40.0)
		samples[first + i] += value * volume * envelope * edge

func _store(sound_name: String, samples: PackedFloat32Array, loop: bool = false) -> void:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	loaded_sounds[sound_name] = stream
