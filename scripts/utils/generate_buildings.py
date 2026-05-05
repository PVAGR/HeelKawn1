from PIL import Image, ImageDraw

def create_sprite(path, color, shape="rect"):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if shape == "rect":
        draw.rectangle([2, 4, 13, 13], fill=color, outline=(0, 0, 0, 255))
    elif shape == "bed":
        draw.rectangle([2, 10, 13, 14], fill=color, outline=(0, 0, 0, 255))
        draw.rectangle([2, 5, 5, 10], fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))
    elif shape == "wall":
        draw.rectangle([0, 0, 15, 15], fill=color, outline=(0, 0, 0, 255))
        draw.line([4, 0, 4, 15], fill=(0,0,0,100))
        draw.line([11, 0, 11, 15], fill=(0,0,0,100))
    img.save(path)

# Colors from TileFeature.gd
create_sprite("assets/sprites/terrain/wall.png", (90, 60, 35, 255), "wall")
create_sprite("assets/sprites/terrain/bed.png", (220, 180, 120, 255), "bed")
create_sprite("assets/sprites/terrain/door.png", (160, 100, 45, 255), "rect")
