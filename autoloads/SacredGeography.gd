extends Node
## SacredGeography — Emergent cultural significance from memorial density
##
## Tiles with multiple memorials become culturally significant:
## - 1-2 memorials: "remembered" (minor significance)
## - 3-4 memorials: "sacred" (moderate significance)
## - 5+ memorials: "holy_ground" (major significance)
##
## Pawns crossing sacred tiles:
## - Move slower (reverence)
## - Gain mood bonus ("Awe" +5)
## - Avoid combat (if possible)

const SIGNIFICANCE_LEVELS: Dictionary = {
	"remembered": {"min_density": 1, "color": Color(0.9, 0.9, 1.0, 0.3)},
	"sacred": {"min_density": 3, "color": Color(0.7, 0.8, 1.0, 0.5)},
	"holy_ground": {"min_density": 5, "color": Color(0.5, 0.7, 1.0, 0.7)},
}

# Sacred tile data
## {
##   "tile": Vector2i,
##   "memorial_count": int,
##   "significance": String,
##   "associated_memorials": Array[int],
##   "last_crossed_tick": int,
##   "crossing_count": int
## }
var sacred_tiles: Dictionary = {}  # String tile key → data

# References
@onready var _memorial_system: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_memorial_system = get_node_or_null("/root/MemorialSystem")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


func _on_game_tick(tick: int) -> void:
	# Update sacred geography when memorials change
	if tick % 100 == 0:
		_update_sacred_geography()
	
	# Track pawn crossings (for statistics, future features)
	if tick % 50 == 0:
		_track_pawn_crossings(tick)


# ==================== SACRED GEOGRAPHY CALCULATION ====================

func _update_sacred_geography() -> void:
	if _memorial_system == null:
		return
	
	# Clear old data
	sacred_tiles.clear()
	
	# Count memorials per tile
	var memorials = _memorial_system.get_memorials()
	for memorial in memorials:
		var tile_key = _tile_to_key(memorial.tile)
		
		if not sacred_tiles.has(tile_key):
			sacred_tiles[tile_key] = {
				"tile": memorial.tile,
				"memorial_count": 0,
				"significance": "remembered",
				"associated_memorials": [],
				"last_crossed_tick": 0,
				"crossing_count": 0
			}
		
		sacred_tiles[tile_key].memorial_count += 1
		sacred_tiles[tile_key].associated_memorials.append(memorial.memorial_id)
	
	# Classify significance by density
	for tile_key in sacred_tiles:
		var data = sacred_tiles[tile_key]
		data.significance = _get_significance_for_density(data.memorial_count)


func _get_significance_for_density(count: int) -> String:
	if count >= 5:
		return "holy_ground"
	elif count >= 3:
		return "sacred"
	elif count >= 1:
		return "remembered"
	return ""


# ==================== PAWN INTERACTION ====================

## Check if tile is sacred and apply effects to pawn
func check_sacred_tile_effect(pawn: Node) -> void:
	if pawn.data == null:
		return
	
	var tile: Vector2i = Vector2i(pawn.position)
	var tile_key = _tile_to_key(tile)
	
	if not sacred_tiles.has(tile_key):
		return  # Not sacred
	
	var data = sacred_tiles[tile_key]
	
	# Apply mood bonus (once per crossing)
	if data.last_crossed_tick < GameManager.tick_count - 100:
		_apply_sacred_mood(pawn, data.significance)
		data.last_crossed_tick = GameManager.tick_count
		data.crossing_count += 1
	
	# Apply movement slowdown (reverence)
	_apply_reverence_slowdown(pawn, data.significance)


func _apply_sacred_mood(pawn: Node, significance: String) -> void:
	var mood_bonus: float = 0.0
	
	match significance:
		"holy_ground":
			mood_bonus = 10.0  # Major bonus
		"sacred":
			mood_bonus = 5.0   # Moderate bonus
		"remembered":
			mood_bonus = 2.0   # Minor bonus
	
	if pawn.data.has("mood"):
		pawn.data.mood = minf(100.0, pawn.data.mood + mood_bonus)


func _apply_reverence_slowdown(pawn: Node, significance: String) -> void:
	# Reduce pawn movement speed on sacred tiles
	var speed_mult: float = 1.0
	
	match significance:
		"holy_ground":
			speed_mult = 0.5  # 50% speed (deep reverence)
		"sacred":
			speed_mult = 0.7  # 70% speed
		"remembered":
			speed_mult = 0.9  # 90% speed (slight respect)
	
	if pawn.has_method("set_movement_speed_mult"):
		pawn.call("set_movement_speed_mult", speed_mult)


func _track_pawn_crossings(tick: int) -> void:
	if _pawn_spawner == null:
		return
	
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		check_sacred_tile_effect(pawn)


# ==================== COMBAT AVOIDANCE ====================

## Check if combat should be avoided on sacred tile
func should_avoid_combat_on_tile(tile: Vector2i) -> bool:
	var tile_key = _tile_to_key(tile)
	if not sacred_tiles.has(tile_key):
		return false
	
	var significance = sacred_tiles[tile_key].significance
	# Avoid combat on sacred and holy_ground tiles
	return significance in ["sacred", "holy_ground"]


# ==================== VISUAL HELPERS ====================

## Get color tint for sacred tile (for visual overlay)
func get_sacred_tile_color(tile: Vector2i) -> Color:
	var tile_key = _tile_to_key(tile)
	if not sacred_tiles.has(tile_key):
		return Color.TRANSPARENT
	
	var significance = sacred_tiles[tile_key].significance
	return SIGNIFICANCE_LEVELS.get(significance, {}).get("color", Color.TRANSPARENT)


## Get all sacred tiles within radius (for rendering, pathfinding)
func get_sacred_tiles_in_radius(center: Vector2i, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for tile_key in sacred_tiles:
		var data = sacred_tiles[tile_key]
		var distance = data.tile.distance_to(center)
		if distance <= radius:
			result.append(data)
	
	return result


# ==================== STATISTICS ====================

## Get total count of sacred tiles by significance
func get_sacred_tile_counts() -> Dictionary:
	var counts = {"remembered": 0, "sacred": 0, "holy_ground": 0}
	
	for tile_key in sacred_tiles:
		var significance = sacred_tiles[tile_key].significance
		if counts.has(significance):
			counts[significance] += 1
	
	return counts


## Get most sacred tile (highest memorial density)
func get_most_sacred_tile() -> Dictionary:
	var max_density = 0
	var most_sacred = {}
	
	for tile_key in sacred_tiles:
		var data = sacred_tiles[tile_key]
		if data.memorial_count > max_density:
			max_density = data.memorial_count
			most_sacred = data
	
	return most_sacred


## Get total crossings across all sacred tiles
func get_total_crossings() -> int:
	var total = 0
	for tile_key in sacred_tiles:
		total += sacred_tiles[tile_key].crossing_count
	return total


# ==================== HELPERS ====================

func _tile_to_key(tile: Vector2i) -> String:
	return str(tile.x) + "_" + str(tile.y)


func _key_to_tile(key: String) -> Vector2i:
	var parts = key.split("_")
	return Vector2i(int(parts[0]), int(parts[1]))


# ==================== DEBUG ====================

func get_all_sacred_tiles() -> Array[Dictionary]:
	return sacred_tiles.values()


func get_sacred_tile_at(tile: Vector2i) -> Dictionary:
	var tile_key = _tile_to_key(tile)
	return sacred_tiles.get(tile_key, {})
