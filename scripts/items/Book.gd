extends PlaceableItem

class_name BookItem

## Book item with custom written content.
## Placeable in world, tradable, readable.

var content: String = ""

func _init(content_text: String = "") -> void:
	content = content_text
	item_type = Item.Type.BOOK

static func from_dict(d: Dictionary) -> BookItem:
	var b: BookItem = BookItem.new(d.get("content", ""))
	b.item_type = Item.Type.BOOK
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
