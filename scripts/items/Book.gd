extends Item

class_name BookItem

extends Item

## Book item with custom written content.
## Placeable in world, tradable, readable.

var content: String = ""

var is_placeable: bool = true

var world_tile: Vector2i = Vector2i.ZERO

var rotation_degrees: int = 0  # 0,90,180,270

var placed_by_pawn_id: int = 0

var placed_tick: int = 0

func _init(content_text: String = "") -> void:
	content = content_text
	type = Item.Type.BOOK  # assume defined in Item.Type

static func from_dict(d: Dictionary) -> BookItem:
	var b = BookItem.new(d.get("content", ""))
	b.world_tile = d.get("world_tile", Vector2i.ZERO)
	b.rotation_degrees = d.get("rotation", 0)
	b.placed_by_pawn_id = d.get("placed_by", 0)
	b.placed_tick = d.get("placed_tick", 0)
	return b

func to_save_dict() -> Dictionary:
	return {
		"type": Item.Type.BOOK,
		"content": content,
		"world_tile": world_tile,
		"rotation": rotation_degrees,
		"placed_by": placed_by_pawn_id,
		"placed_tick": placed_tick,
	}

func describe() -> String:
	return "Book: '%s' (placed at %s by pawn %d tick %d)" % [content.substr(0,30) + "..." if content.length() > 30 else content, world_tile, placed_by_pawn_id, placed_tick]
