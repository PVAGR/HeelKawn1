extends Node
## Phase 4 Identity: Visual meaning for settlement states and cultures
## Handles visual transformations (graves, scorched earth) for permanently abandoned settlements
## without affecting gameplay mechanics (those remain in SettlementPlanner/SettlementMemory)
##
## Cultural architectural styles:
## - Open culture: warm colors, larger spaces, decorative markers
## - Defensive culture: cool colors, compact layouts, reinforced walls
## - Cautious culture: neutral tones, balanced layout, hidden markers
## - Receptive culture: varied colors, communal spaces, shared hearths

const ARCHITECT_INTERVAL_TICKS: int = 5000  # Run infrequently - visual updates only

# Cultural style definitions
const CULTURE_STYLES: Dictionary = {
	SettlementPlanner.CULTURE_OPEN: {
		"wall_color": Color8(180, 120, 60),    # warm wood
		"bed_color": Color8(240, 200, 140),     # bright wheat
		"door_color": Color8(200, 150, 80),     # golden wood
		"fire_color": Color8(255, 160, 50),     # bright fire
		"marker_style": "open_stone",            # welcoming markers
	},
	SettlementPlanner.CULTURE_DEFENSIVE: {
		"wall_color": Color8(60, 50, 40),        # dark, fortified
		"bed_color": Color8(140, 120, 100),      # muted
		"door_color": Color8(100, 70, 40),       # heavy wood
		"fire_color": Color8(220, 120, 30),      # contained fire
		"marker_style": "fortified_stone",        # warning markers
	},
	SettlementPlanner.CULTURE_CAUTIOUS: {
		"wall_color": Color8(110, 90, 70),       # neutral brown
		"bed_color": Color8(180, 160, 130),      # soft tan
		"door_color": Color8(130, 100, 60),      # standard wood
		"fire_color": Color8(240, 140, 40),      # moderate fire
		"marker_style": "subtle_stone",           # discreet markers
	},
}

var _last_architect_tick: int = -1_000_000_000


func process(world: World, main: Node2D) -> void:
	if world == null or not is_instance_valid(world) or world.data == null:
		return
	
	var tick_now: int = GameManager.tick_count
	if tick_now - _last_architect_tick < ARCHITECT_INTERVAL_TICKS:
		return
	
	_last_architect_tick = tick_now
	
	# Process permanently abandoned settlements for visual decay
	var settlements: Array = SettlementMemory.settlements
	for s in settlements:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s as Dictionary
		var state: String = str(d.get("state", ""))
		if state != "permanently_abandoned":
			continue
		
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var regions: PackedInt32Array = reg as PackedInt32Array
		if regions.is_empty():
			continue
		
		_apply_permanent_abandonment_visuals(world, regions)


## Apply visual decay to permanently abandoned settlement regions
## Converts some built features to graves/scorched earth tiles for visual storytelling
func _apply_permanent_abandonment_visuals(world: World, regions: PackedInt32Array) -> void:
	var rng_seed: int = GameManager.tick_count
	
	for rk in regions:
		var center_tile: Vector2i = _center_tile_of_region_key(rk)
		
		# Convert some BED features to graves (visual only)
		# Scan a 5x5 area around the region center
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var tx: int = center_tile.x + dx
				var ty: int = center_tile.y + dy
				if tx < 0 or tx >= WorldData.WIDTH or ty < 0 or ty >= WorldData.HEIGHT:
					continue
				
				var feature: int = world.data.get_feature(tx, ty)
				
				# Convert BED to RUIN (grave marker) with low probability
				# This is deterministic based on position and tick
				var feature_hash: int = (tx * 73856093) ^ (ty * 19349663) ^ rng_seed
				var grave_chance: float = float(feature_hash & 0xFFFF) / 65536.0
				
				if feature == TileFeature.Type.BED and grave_chance < 0.15:
					# Convert to RUIN (visual grave marker)
					world.set_feature(tx, ty, TileFeature.Type.RUIN)
				
				# Convert WALL to RUIN (scorched/collapsed wall) with lower probability
				if feature == TileFeature.Type.WALL and grave_chance < 0.08:
					world.set_feature(tx, ty, TileFeature.Type.RUIN)


static func _center_tile_of_region_key(rk: int) -> Vector2i:
	var rx: int = int(rk) & 0xFFFF
	var ry: int = (int(rk) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


## Get the cultural style for a settlement at a given region.
## Returns a Dictionary with color/style overrides, or null if no culture.
func get_culture_style_for_region(rk: int) -> Dictionary:
	var settlement_data: Variant = SettlementMemory.get_settlement_at_region(rk)
	if settlement_data == null or not (settlement_data is Dictionary):
		return {}
	
	var d: Dictionary = settlement_data as Dictionary
	var culture_type: int = int(d.get("culture_type", SettlementPlanner.CULTURE_CAUTIOUS))
	return CULTURE_STYLES.get(culture_type, CULTURE_STYLES[SettlementPlanner.CULTURE_CAUTIOUS])


## Apply cultural color tint to a building feature. Returns the tinted color.
func apply_culture_tint(base_color: Color, feature_type: int, rk: int) -> Color:
	var style: Dictionary = get_culture_style_for_region(rk)
	if style.is_empty():
		return base_color
	
	var tint_key: String = ""
	match feature_type:
		TileFeature.Type.WALL: tint_key = "wall_color"
		TileFeature.Type.BED: tint_key = "bed_color"
		TileFeature.Type.DOOR: tint_key = "door_color"
		TileFeature.Type.FIRE_PIT: tint_key = "fire_color"
		_: return base_color
	
	if style.has(tint_key):
		var culture_color: Color = style[tint_key]
		# Blend between base and culture color (60% culture influence)
		return base_color.lerp(culture_color, 0.6)
	
	return base_color


## Record a cultural marker event when a settlement builds something significant.
func record_cultural_building(pawn_id: int, tile: Vector2i, feature_type: int) -> void:
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	var style: Dictionary = get_culture_style_for_region(rk)
	if style.is_empty():
		return
	
	var marker_style: String = style.get("marker_style", "standard")
	WorldMemory.record_event({
		"type": "cultural_building",
		"pawn_id": pawn_id,
		"feature_type": feature_type,
		"feature_name": TileFeature.name_for(feature_type),
		"marker_style": marker_style,
		"tick": GameManager.tick_count,
		"tile": {"x": tile.x, "y": tile.y},
		"region": rk,
	})
