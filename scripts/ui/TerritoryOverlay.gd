class_name TerritoryOverlay
extends Node2D

## TerritoryOverlay — Crusader Kings borders + Songs of Syx fill
##
## Draws colored territory fills and border outlines around each settlement's
## region cluster. Territories emerge automatically from SettlementMemory.
##
## Visual style:
##   - Fill: subtle colored tint per settlement (SoS style)
##   - Borders: thick colored lines along settlement edges (CK style)
##   - Zoom-aware: more prominent at low zoom (strategy map), subtle at high zoom
##
## Update cadence: every 60 ticks, only redraws when settlement data changes.

const UPDATE_EVERY_N_TICKS: int = 60
const TILE_PX: int = 10  # Must match World.TILE_PIXELS

# Zoom-dependent rendering thresholds
const ZOOM_STRATEGY: float = 0.5   # Below this: full strategy map mode
const ZOOM_DETAIL: float = 1.0     # Above this: full detail mode

# Border appearance per zoom level
const BORDER_WIDTH_STRATEGY: float = 3.0
const BORDER_WIDTH_TRANSITION: float = 2.0
const BORDER_WIDTH_DETAIL: float = 1.0
const FILL_ALPHA_STRATEGY: float = 0.15
const FILL_ALPHA_TRANSITION: float = 0.10
const FILL_ALPHA_DETAIL: float = 0.05

# Neighbor offsets for border detection (N, S, E, W in region coords)
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),  # North
	Vector2i(0, 1),   # South
	Vector2i(1, 0),   # East
	Vector2i(-1, 0),  # West
]

var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0
var _last_settlement_count: int = -1
var _last_settlement_hash: int = -1
var _current_zoom: float = 1.0

# Cached territory data: settlement_index -> { color, regions_set, border_segments }
var _territories: Array[Dictionary] = []


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 2  # Above WorldTrace (1), below UI


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % UPDATE_EVERY_N_TICKS == 0:
		_refresh_territories()
	# Track zoom for rendering
	if _camera != null:
		_current_zoom = _camera.zoom.x


func _refresh_territories() -> void:
	if SettlementMemory == null:
		return
	# Use only formal settlements for territory rendering — proto-sites should
	# not be treated as authoritative territory or register territory zones.
	var settlements: Array = SettlementMemory.get_formal_settlements()
	# Quick check: only rebuild if settlement data changed
	var current_hash: int = settlements.size()
	for s in settlements:
		if s is Dictionary:
			current_hash = current_hash * 31 + int(s.get("center_region", 0))
	if current_hash == _last_settlement_hash and settlements.size() == _last_settlement_count:
		return
	_last_settlement_count = settlements.size()
	_last_settlement_hash = current_hash
	_territories.clear()
	# Build a global lookup: region_key -> settlement_index
	var region_to_settlement: Dictionary = {}
	for i in range(settlements.size()):
		var s: Dictionary = settlements[i] as Dictionary
		if s == null:
			continue
		var regions: PackedInt32Array = s.get("regions", PackedInt32Array())
		for rk in regions:
			region_to_settlement[int(rk)] = i
	# Build territory data per settlement
	for i in range(settlements.size()):
		var s: Dictionary = settlements[i] as Dictionary
		if s == null:
			continue
		var center_region: int = int(s.get("center_region", 0))
		var regions: PackedInt32Array = s.get("regions", PackedInt32Array())
		if regions.is_empty():
			continue
		# Color: prefer clan/nation color, fall back to settlement hash
		var color: Color = _color_for_settlement(center_region)
		var dominant_nation: int = int(s.get("dominant_nation_id", -1))
		var dominant_clan: int = int(s.get("dominant_clan_id", -1))
		if dominant_nation >= 0 and KinshipSystem != null:
			color = KinshipSystem.get_color_for_nation(dominant_nation)
		elif dominant_clan >= 0 and KinshipSystem != null:
			color = KinshipSystem.get_color_for_clan(dominant_clan)
		# Build set of region keys for fast lookup
		var region_set: Dictionary = {}
		for rk in regions:
			region_set[int(rk)] = true
		# Find border segments: edges where neighbor is different settlement or out of bounds
		var border_segments: Array[Dictionary] = []
		for rk in regions:
			var rx: int = int(rk) & 0xFFFF
			var ry: int = (int(rk) >> 16) & 0xFFFF
			for dir_idx in range(4):
				var offset: Vector2i = NEIGHBOR_OFFSETS[dir_idx]
				var nrx: int = rx + offset.x
				var nry: int = ry + offset.y
				var neighbor_key: int = (nrx & 0xFFFF) | ((nry & 0xFFFF) << 16)
				# Border if neighbor not in this settlement
				if not region_set.has(neighbor_key):
					border_segments.append({
						"region_key": int(rk),
						"dir": dir_idx,
					})
		_territories.append({
			"color": color,
			"region_set": region_set,
			"regions": regions,
			"border_segments": border_segments,
			"center_region": center_region,
		})
	# Register territory zones in ZoneRegistry so pawns get zone bias
	_register_territory_zones()
	queue_redraw()


## Register each settlement's regions as TERRITORY zones in ZoneRegistry.
## This gives pawns a priority bonus for building/working inside their territory.
## We register each 16×16 region as a separate rect for accurate coverage
## (bounding boxes would include non-settlement tiles for irregular shapes).
func _register_territory_zones() -> void:
	if ZoneRegistry == null:
		return
	# Clear old territory zones
	var old_territory_zones: Array = ZoneRegistry.zones_of_type(ZoneRegistry.ZoneType.TERRITORY).duplicate()
	for r in old_territory_zones:
		ZoneRegistry.unregister(ZoneRegistry.ZoneType.TERRITORY, r)
	# Register new territory zones from settlements
	for territory in _territories:
		var regions: PackedInt32Array = territory["regions"]
		if regions.is_empty():
			continue
		# Register each region as a separate 16×16 tile rect
		for rk in regions:
			var rx: int = int(rk) & 0xFFFF
			var ry: int = (int(rk) >> 16) & 0xFFFF
			var rect: Rect2i = Rect2i(rx * 16, ry * 16, 16, 16)
			ZoneRegistry.register(ZoneRegistry.ZoneType.TERRITORY, rect)


func _draw() -> void:
	if _world == null:
		return
	var zoom: float = _current_zoom
	# Compute zoom-dependent rendering params
	var border_width: float = BORDER_WIDTH_DETAIL
	var fill_alpha: float = FILL_ALPHA_DETAIL
	if zoom < ZOOM_STRATEGY:
		border_width = BORDER_WIDTH_STRATEGY
		fill_alpha = FILL_ALPHA_STRATEGY
	elif zoom < ZOOM_DETAIL:
		var t: float = (zoom - ZOOM_STRATEGY) / (ZOOM_DETAIL - ZOOM_STRATEGY)
		border_width = lerpf(BORDER_WIDTH_STRATEGY, BORDER_WIDTH_DETAIL, t)
		fill_alpha = lerpf(FILL_ALPHA_STRATEGY, FILL_ALPHA_DETAIL, t)
	var half_tile: float = TILE_PX * 0.5
	var region_tiles: int = 16  # 16x16 tiles per region
	for territory in _territories:
		var color: Color = territory["color"]
		var fill_color: Color = Color(color.r, color.g, color.b, fill_alpha)
		var border_color: Color = Color(color.r, color.g, color.b, 0.85)
		# Draw fill for each region
		var regions: PackedInt32Array = territory["regions"]
		for rk in regions:
			var rx: int = int(rk) & 0xFFFF
			var ry: int = (int(rk) >> 16) & 0xFFFF
			# Region top-left tile in world coords
			var tile_x: int = rx * region_tiles
			var tile_y: int = ry * region_tiles
			var world_pos: Vector2 = _world.tile_to_world(Vector2i(tile_x, tile_y))
			var rect_pos: Vector2 = world_pos - Vector2(half_tile, half_tile)
			var rect_size: Vector2 = Vector2(region_tiles * TILE_PX, region_tiles * TILE_PX)
			draw_rect(Rect2(rect_pos, rect_size), fill_color, true)
		# Draw border segments
		var segments: Array[Dictionary] = territory["border_segments"]
		for seg in segments:
			var rk: int = int(seg["region_key"])
			var dir: int = int(seg["dir"])
			var rx: int = rk & 0xFFFF
			var ry: int = (rk >> 16) & 0xFFFF
			var tile_x: int = rx * region_tiles
			var tile_y: int = ry * region_tiles
			# Get the world position of the region's top-left corner
			var corner_world: Vector2 = _world.tile_to_world(Vector2i(tile_x, tile_y)) - Vector2(half_tile, half_tile)
			var region_size: float = float(region_tiles * TILE_PX)
			# Draw border line along the appropriate edge
			var from: Vector2
			var to: Vector2
			match dir:
				0:  # North edge (top of region)
					from = corner_world
					to = corner_world + Vector2(region_size, 0.0)
				1:  # South edge (bottom of region)
					from = corner_world + Vector2(0.0, region_size)
					to = corner_world + Vector2(region_size, region_size)
				2:  # East edge (right of region)
					from = corner_world + Vector2(region_size, 0.0)
					to = corner_world + Vector2(region_size, region_size)
				3:  # West edge (left of region)
					from = corner_world
					to = corner_world + Vector2(0.0, region_size)
			draw_line(from, to, border_color, border_width, true)


## Deterministic color for a settlement based on its center region key.
## Uses golden ratio hue spacing for visually distinct colors.
static func _color_for_settlement(center_region_key: int) -> Color:
	# Golden ratio hash for well-distributed hues
	var hue: float = fmod(float(abs(center_region_key)) * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.55, 0.85, 1.0)
