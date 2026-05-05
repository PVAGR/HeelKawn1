import os
from PIL import Image, ImageDraw

def create_sprite(path, pixels):
    """
    Creates a 16x16 PNG from a list of pixel colors.
    pixels: list of 16 strings, each 16 chars long:
    '.' = transparent, 'X' = main color, 'H' = highlight, 'S' = shadow
    colors: dict of mapping char to (R, G, B, A)
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    for y, row in enumerate(pixels):
        for x, char in enumerate(row):
            if char in COLORS:
                draw.point((x, y), fill=COLORS[char])
    
    img.save(path)
    print(f"Saved: {path}")

# Default color palettes
# Pawn (Gray/Tan)
PAWN_COLORS = {
    'X': (160, 140, 120, 255), # Main tunic
    'H': (210, 190, 170, 255), # Skin/Head
    'S': (100, 80, 60, 255),   # Shadow
    'B': (40, 40, 40, 255),    # Outine/Eyes
}

# Tree (Dark Green - matching TileFeature.gd Type.TREE Color8(27, 73, 29))
TREE_COLORS = {
    'X': (27, 73, 29, 255),    # Foliage
    'H': (60, 110, 60, 255),   # Highlight
    'S': (15, 40, 15, 255),    # Deep shadow
    'T': (90, 60, 35, 255),    # Trunk (Wall color)
}

# Wood (Warm Brown - matching Item.gd Type.WOOD Color8(141, 85, 36))
WOOD_COLORS = {
    'X': (141, 85, 36, 255),   # Main wood
    'H': (180, 120, 70, 255),  # Highlight
    'S': (90, 50, 20, 255),    # Underside
    'B': (160, 130, 80, 255),  # Binding (Stick color)
}

# Meat (Blood Red - matching Item.gd Type.MEAT Color8(178, 60, 60))
MEAT_COLORS = {
    'X': (178, 60, 60, 255),   # Flesh
    'W': (240, 240, 240, 255), # Bone/Fat
    'S': (120, 40, 40, 255),   # Shadowed meat
}

# Berry (Bright Red - matching Item.gd Type.BERRY Color8(229, 57, 53))
BERRY_COLORS = {
    'X': (229, 57, 53, 255),   # Berries
    'H': (255, 100, 100, 255), # Gloss
    'S': (160, 30, 30, 255),   # Shadow
    'G': (50, 100, 50, 255),   # Stem
}

# Stone (Light Gray - matching Item.gd Type.STONE Color8(189, 189, 189))
STONE_COLORS = {
    'X': (189, 189, 189, 255), # Stone face
    'H': (220, 220, 220, 255), # Top highlight
    'S': (120, 120, 120, 255), # Bottom shadow
}

# 16x16 PIXEL MAPS
PAWN_PIXELS = [
    "................",
    "................",
    "......HHH.......",
    ".....HBBBH......",
    ".....HBHBH......",
    ".....HHHHH......",
    "......HHH.......",
    ".....XXXXX......",
    "....XXXXXXX.....",
    "....XXXXXXX.....",
    "....XXXXXXX.....",
    "....XXXXXXX.....",
    ".....SXSXS......",
    ".....S.S.S......",
    "................",
    "................",
]

TREE_PIXELS = [
    ".......X........",
    "......XXX.......",
    ".....XHXXX......",
    "....XXXXSXX.....",
    ".....XXXXX......",
    "....XXXXXXX.....",
    "...XXXXXHXXX....",
    "...XXSXXXXXX....",
    "....XXXXXXX.....",
    "...XXXXXXXXX....",
    "..XXXXXXXXXXX...",
    ".XXXXHXXXXSXXX..",
    ".......TT.......",
    ".......TT.......",
    ".......TT.......",
    "................",
]

WOOD_PIXELS = [
    "................",
    "................",
    "................",
    ".......HHH......",
    "....XXXXXXXXX...",
    "...XBBXXXXXBXX..",
    "..XBSSXXXXXSBXX.",
    "..XBSSXXXXXSBXX.",
    "...XBBXXXXXBXX..",
    "....XXXXSXXXX...",
    ".......SSS......",
    "................",
    "................",
    "................",
    "................",
    "................",
]

MEAT_PIXELS = [
    "................",
    "................",
    ".....XXXXX......",
    "....XXXXXXXS....",
    "...XXXXWXXXXS...",
    "..XXXXWXXXXXXS..",
    "..XXXWXXXXXXXS..",
    "..XXWXXXXXXXXS..",
    "..XWXXXXXXXXXS..",
    "..WWXXXXXXXXXS..",
    "...WSSXXXXXXS...",
    "....WSSSSSSS....",
    ".....WWWWWW.....",
    "................",
    "................",
    "................",
]

BERRY_PIXELS = [
    "................",
    ".......GG.......",
    "......G.........",
    ".....X..X.......",
    "....XHX..S......",
    "...XHX.XHX.S....",
    "...XS..XHX..S...",
    "....S..XHX..S...",
    "........S..S....",
    ".....X..X.......",
    "....XHX.XHX.....",
    "....XHX.XHX.....",
    ".....S...S......",
    "................",
    "................",
    "................",
]

STONE_PIXELS = [
    "................",
    "................",
    "................",
    "......HHHHH.....",
    "....HXXXXXXXH...",
    "...HXXXXXXXXXH..",
    "..HXXXXXXXXXXXS.",
    "..HXXXXXXXXXXXS.",
    "..HXXXXXXXXXXXS.",
    "..HXXXXXXXXXXXS.",
    "...SXXXXXXXXXS..",
    ".....SSSSSSS....",
    "................",
    "................",
    "................",
    "................",
]

if __name__ == "__main__":
    # Pawn
    COLORS = PAWN_COLORS
    create_sprite("assets/sprites/pawns/pawn.png", PAWN_PIXELS)
    
    # Tree
    COLORS = TREE_COLORS
    create_sprite("assets/sprites/terrain/tree.png", TREE_PIXELS)
    
    # Wood
    COLORS = WOOD_COLORS
    create_sprite("assets/sprites/items/wood.png", WOOD_PIXELS)
    
    # Meat
    COLORS = MEAT_COLORS
    create_sprite("assets/sprites/items/meat.png", MEAT_PIXELS)
    
    # Berry
    COLORS = BERRY_COLORS
    create_sprite("assets/sprites/items/berry.png", BERRY_PIXELS)
    
    # Stone
    COLORS = STONE_COLORS
    create_sprite("assets/sprites/items/stone.png", STONE_PIXELS)
