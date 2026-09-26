extends Node

# Ses Yöneticisi (AudioManager)
# Oyun içi ses efektleri ve müzikleri yönetir.

@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

var loaded_sounds: Dictionary = {}

func _ready() -> void:
	add_child(sfx_player)
	add_child(music_player)

# Ses efekti çalar
func play_sfx(sound_name: String) -> void:
	if loaded_sounds.has(sound_name):
		sfx_player.stream = loaded_sounds[sound_name]
		sfx_player.play()

# Müzik çalar
func play_music(track_name: String) -> void:
	if loaded_sounds.has(track_name):
		music_player.stream = loaded_sounds[track_name]
		music_player.play()

# Müziği durdurur
func stop_music() -> void:
	music_player.stop()
