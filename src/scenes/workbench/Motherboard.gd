class_name Motherboard
extends Node2D

# Anakart yöneticisi
# Slotları ve parça yerleştirme mantığını yönetir.
# CSS benzeri çizim işlemlerini yapar.

var slots: Array[Node] = []
var board_size: Vector2 = Vector2(960, 540)
var corner_radius: float = 12.0
var border_width: float = 4.0

func _ready() -> void:
	# Tüm alt slot düğümlerini topla (Slots node'u içindekiler)
	if has_node("Slots"):
		for child in $Slots.get_children():
			if child is MotherboardSlot:
				slots.append(child)
	
	# EventBus bağlantıları
	EventBus.part_installed.connect(_on_part_installed)

func _on_part_installed(slot_id: String, part_data: Resource) -> void:
	print("%s slotuna parça yerleştirildi: %s" % [slot_id, part_data])

func _draw() -> void:
	var rect = Rect2(Vector2(-board_size.x/2, -board_size.y/2), board_size)
	
	# 1. Arka plan rengi ve yuvarlak köşeler
	var bg_color = Color("#0b192c")
	draw_rect(rect, bg_color) # Yuvarlak köşe için StyleBox da kullanılabilirdi ama basit rect ile başlayalım
	# Not: Tam yuvarlatılmış köşe için polygon çizilebilir.
	
	# 2. Izgara çizgileri (Grid pattern)
	var grid_color = Color(30.0/255.0, 62.0/255.0, 98.0/255.0, 0.2)
	var step = 20.0
	
	# Dikey çizgiler
	var start_x = rect.position.x
	while start_x <= rect.end.x:
		draw_line(Vector2(start_x, rect.position.y), Vector2(start_x, rect.end.y), grid_color, 1.0)
		start_x += step
		
	# Yatay çizgiler
	var start_y = rect.position.y
	while start_y <= rect.end.y:
		draw_line(Vector2(rect.position.x, start_y), Vector2(rect.end.x, start_y), grid_color, 1.0)
		start_y += step

	# 3. Kenarlık (Border)
	var border_color = Color("#1e3e62")
	draw_rect(rect, border_color, false, border_width)
	
	# 4. Üst yazı (Motherboard Title)
	var font = ThemeDB.fallback_font
	var text_pos = Vector2(rect.position.x + 35, rect.position.y + 40)
	draw_string(font, text_pos, "ANAKART • Z790 • DDR5 EXPERT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#00ffcc"))
