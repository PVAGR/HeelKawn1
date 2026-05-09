extends PlaceableItem

class_name BookItem

## Book item with custom written content.
## Placeable in world, tradable, readable.

var content: String = ""
var author_id: int = -1
var creation_tick: int = -1
var title: String = ""

func _init(content_text: String = "") -> void:
	content = content_text
	item_type = Item.Type.BOOK

## Populates the book with historical events from world memory.
func write_chronicle(pawn: HeelKawnian, radius: int = 50) -> void:
	author_id = pawn.data.id
	creation_tick = GameManager.tick_count
	
	var world_mem = pawn.get_node_or_null("/root/WorldMemory")
	if not world_mem: return
	
	var events = world_mem._events # Accessing for logic, replace with proper getter if available
	var local_events = []
	var rk = world_mem._region_key(pawn.data.tile_pos.x, pawn.data.tile_pos.y)
	
	# Sample recent meaningful events near the pawn or related to their lineage
	for i in range(events.size() - 1, max(-1, events.size() - 200), -1):
		var e = events[i]
		if e.get("r") == rk or e.get("pid") == author_id:
			local_events.append(e)
	
	title = "The Acts of %s" % pawn.data.display_name
	content = "Recorded on tick %d by %s.\n\n" % [creation_tick, pawn.data.display_name]
	
	for e in local_events:
		var line = "- Tick %d: %s" % [e.get("t", 0), e.get("type", "unknown event")]
		if e.has("n"): line += " (%s)" % e["n"]
		content += line + "\n"
	
	item_type = Item.Type.WRITTEN_BOOK

static func from_dict(d: Dictionary) -> BookItem:
	var b: BookItem = BookItem.new(d.get("content", ""))
	b.item_type = d.get("type", Item.Type.BOOK)
	b.world_tile = d.get("world_tile", Vector2i.ZERO)
	b.rotation_degrees = d.get("rotation", 0)
	b.placed_by_pawn_id = d.get("placed_by", 0)
	b.placed_tick = d.get("placed_tick", 0)
	b.author_id = d.get("author_id", -1)
	b.creation_tick = d.get("creation_tick", -1)
	b.title = d.get("title", "")
	return b

func to_save_dict() -> Dictionary:
	return {
		"type": item_type,
		"content": content,
		"world_tile": world_tile,
		"rotation": rotation_degrees,
		"placed_by": placed_by_pawn_id,
		"placed_tick": placed_tick,
		"author_id": author_id,
		"creation_tick": creation_tick,
		"title": title,
	}

func describe() -> String:
	var prefix = "Written " if item_type == Item.Type.WRITTEN_BOOK else ""
	return "%sBook: '%s' by %d (placed at %s tick %d)" % [prefix, title if title != "" else content.substr(0,20), author_id, world_tile, placed_tick]
