from PIL import Image, ImageDraw

def create_sprite(path, size, color, text=""):
    img = Image.new('RGBA', size, color)
    draw = ImageDraw.Draw(img)
    if text:
        # Simple text drawing in center
        pass
    img.save(path)

# Board
create_sprite('assets/sprites/motherboard/board.png', (960, 540), (11, 25, 44, 255))
create_sprite('assets/sprites/motherboard/cpu_socket.png', (115, 115), (255, 68, 68, 100))
create_sprite('assets/sprites/motherboard/ram_slot.png', (42, 130), (15, 23, 42, 150))
create_sprite('assets/sprites/motherboard/pcie_slot.png', (480, 52), (15, 23, 42, 150))

# Components
create_sprite('assets/sprites/components/cpu.png', (115, 115), (203, 213, 225, 255))
create_sprite('assets/sprites/components/ram.png', (42, 130), (14, 165, 233, 255))
create_sprite('assets/sprites/components/gpu.png', (480, 52), (147, 51, 234, 255))
create_sprite('assets/sprites/components/m2.png', (140, 38), (245, 158, 11, 255))
create_sprite('assets/sprites/components/fan.png', (115, 115), (2, 132, 199, 255))

# Tools
create_sprite('assets/sprites/tools/paste.png', (60, 40), (100, 116, 139, 255))
