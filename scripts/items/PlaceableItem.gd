extends Item

class_name PlaceableItem

## Base class for placeable items like books, tools, furniture.
## Persists position/rotation/creator in WorldPersistence.

var is_placeable: bool = true

var world_tile: Vector2i = Vector2i.ZERO

var rotation_degrees: int = 0

var placed_by_pawn_id: int = 0

var placed_tick: int = 0

func place_at(tile: Vector2i, rot: int, placer_id: int) -> void:
	world_tile = tile
	rotation_degrees = rot % 360
	placed_by_pawn_id = placer_id
	placed_tick = GameManager.tick_count

func to_save_dict() -> Dictionary:
	return {
		"type": type,
		"world_tile": world_tile,
		"rotation": rotation_degrees,
		"placed_by": placed_by_pawn_id,
		"placed_tick": placed_tick,
	}

static func from_dict(d: Dictionary) -> PlaceableItem:
	var item_type = d.get("type", Item.Type.NONE)
	var item = Item.new()
	item.type = item_type
	item.is_placeable = true
	item.world_tile = d.get("world_tile", Vector2i.ZERO)
	item.rotation_degrees = d.get("rotation", 0)
	item.placed_by_pawn_id = d.get("placed_by", 0)
	item.placed_tick = d.get("placed_tick", 0)
	return item

func pickup_by_pawn(pawn_id: int) -> bool:
	if world_tile != Vector2i.ZERO:
		# Add to pawn inventory logic here
		world_tile = Vector2i.ZERO
		return true
	return false
