class_name Workbench
extends Control

# Montaj masası sahnesi
# Bu işte gelen bilgisayarın anakartını (BoardData.scene_path) yükler ve masada ortalar.
# Küçük kartlar (ITX) masanın ortasına yerleşir.

var motherboard: Motherboard = null

func _ready() -> void:
	var board: BoardData = GameManager.current_board if GameManager.current_board else load(GameManager.DEFAULT_BOARD)
	var scene: PackedScene = load(board.scene_path)
	motherboard = scene.instantiate()
	motherboard.name = "Motherboard"
	add_child(motherboard)
	motherboard.position = Vector2(roundf((custom_minimum_size.x - motherboard.size.x) / 2.0), 0)
	print("Montaj masası hazır: %s" % board.display_name)
