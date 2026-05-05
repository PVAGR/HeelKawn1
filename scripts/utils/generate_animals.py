from PIL import Image, ImageDraw

def create_animal(path, color, detail_color):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Body
    draw.ellipse([3, 6, 13, 13], fill=color, outline=(0,0,0,255))
    # Head
    draw.ellipse([10, 3, 15, 8], fill=color, outline=(0,0,0,255))
    # Details (Eyes/Ears)
    draw.point([13, 5], fill=detail_color)
    img.save(path)

# Colors from TileFeature.gd
# Rabbit: Color8(245, 240, 230)
create_animal("assets/sprites/animals/rabbit.png", (245, 240, 230, 255), (0,0,0,255))
# Deer: Color8(170, 110,  55)
create_animal("assets/sprites/animals/deer.png", (170, 110, 55, 255), (255,255,255,255))
