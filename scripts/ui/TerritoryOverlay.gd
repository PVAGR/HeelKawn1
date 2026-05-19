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
const MOBILE_UPDATE_EVERY_N_TICKS: int = 120
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
var _mobile_runtime: bool = false
var _update_every_n_ticks: int = UPDATE_EVERY_N_TICKS

# Cached territory data: settlement_index -> { color, regions_set, border_segments }
var _territories: Array[Dictionary] = []
var _skirmish_flash_tile: Vector2i = Vector2i(-1, -1)
var _skirmish_flash_until_tick: int = -1


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 2  # Above WorldTrace (1), below UI
	_mobile_runtime = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if _mobile_runtime:
		_update_every_n_ticks = MOBILE_UPDATE_EVERY_N_TICKS


## Force rebuild on next refresh (building completed, settlement promoted, etc.).
func invalidate_territories() -> void:
	_last_settlement_hash = -1
	_last_settlement_count = -1
	_refresh_territories()


## Brief red flash on a tile when a skirmish is recorded (Bannerlord stub).
func flash_skirmish_tile(tile: Vector2i, duration_ticks: int = 90) -> void:
	_skirmish_flash_tile = tile
	_skirmish_flash_until_tick = (GameManager.tick_count if GameManager != null else 0) + duration_ticks
	queue_redraw()


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % _update_every_n_ticks == 0:
		_refresh_territories()
	# Track zoom for rendering
	if _camera != null:
		_current_zoom = _camera.zoom.x


func _refresh_territories() -> void:
	if SettlementMemory == null:
		return
	# Formal settlements get fill + borders; proto camps get emergent borders only
	# (activity-weighted edges, no static grey region blocks).
	var settlements: Array = SettlementMemory.get_formal_settlements()
	var proto_only: bool = settlements.is_empty()
	if proto_only:
		settlements = SettlementMemory.get_proto_sites()
	# Quick check: only rebuild if settlement data changed
	var current_hash: int = settlements.size()
	for s in settlements:
		if s is Dictionary:
			var sd: Dictionary = s as Dictionary
			current_hash = current_hash * 31 + int(sd.get("center_region", 0))
			current_hash = current_hash * 31 + int(sd.get("buildings_constructed", 0))
			current_hash = current_hash * 31 + int(sd.get("population", 0))
			current_hash = current_hash * 31 + int(sd.get("polity_id", 0))
			if bool(sd.get("is_formal_settlement", false)):
				current_hash += 17
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
		# Color: polity hash (stable per settlement), then clan/nation if assigned.
		var polity_id: int = int(s.get("polity_id", center_region))
		var color: Color = SettlementMemory.color_for_polity_id(polity_id)
		var bc_v: Variant = s.get("border_color", null)
		if bc_v is PackedFloat32Array:
			var bc: PackedFloat32Array = bc_v as PackedFloat32Array
			if bc.size() >= 3:
				color = Color(bc[0], bc[1], bc[2], 1.0)
		elif bc_v is Array and (bc_v as Array).size() >= 3:
			var ba: Array = bc_v as Array
			color = Color(float(ba[0]), float(ba[1]), float(ba[2]), 1.0)
		var dominant_nation: int = int(s.get("dominant_nation_id", -1))
		var dominant_clan: int = int(s.get("dominant_clan_id", -1))
		if dominant_nation >= 0 and SocialManager != null:
			color = SocialManager.get_color_for_nation(dominant_nation)
		elif dominant_clan >= 0 and SocialManager != null:
			color = SocialManager.get_color_for_clan(dominant_clan)
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
		var is_formal: bool = bool(s.get("is_formal_settlement", false))
		var label_nm: String = str(s.get("polity_display_name", s.get("name", ""))).strip_edges()
		if label_nm.is_empty():
			label_nm = "Camp" if proto_only else "Realm"
		_territories.append({
			"color": color,
			"region_set": region_set,
			"regions": regions,
			"border_segments": border_segments,
			"center_region": center_region,
			"center_tile": SettlementPlanner._center_tile_of_region_key(center_region),
			"polity_id": polity_id,
			"label": label_nm,
			"proto_only": proto_only,
			"is_formal": is_formal,
			"activity_segments": _activity_border_segments_for_regions(regions, region_set),
		})
	# Register territory zones in ZoneRegistry so pawns get zone bias (formal only)
	if not proto_only:
		_register_territory_zones()
	queue_redraw()


## Extra border segments along worn paths / building footprints at the settlement edge.
func _activity_border_segments_for_regions(regions: PackedInt32Array, region_set: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _mobile_runtime:
		return out
	if GameManager != null and int(GameManager.game_speed) >= 50:
		return out
	if _world == null or _world.data == null:
		return out
	var region_tiles: int = 16
	for rk in regions:
		var rx: int = int(rk) & 0xFFFF
		var ry: int = (int(rk) >> 16) & 0xFFFF
		var base_x: int = rx * region_tiles
		var base_y: int = ry * region_tiles
		for ly in range(region_tiles):
			for lx in range(region_tiles):
				var tx: int = base_x + lx
				var ty: int = base_y + ly
				if not _world.data.in_bounds(tx, ty):
					continue
				var feat: int = int(_world.data.get_feature(tx, ty))
				var worn: bool = RoadMemory.get_traversal(tx, ty) >= RoadMemory.ROAD_T1
				var built: bool = feat == TileFeature.Type.FIRE_PIT or feat == TileFeature.Type.BED \
					or feat == TileFeature.Type.STORAGE_HUT or feat == TileFeature.Type.WALL \
					or feat == TileFeature.Type.DOOR
				if not worn and not built:
					continue
				for offset in NEIGHBOR_OFFSETS:
					var nrx: int = (rx + offset.x) & 0xFFFF
					var nry: int = (ry + offset.y) & 0xFFFF
					var nkey: int = nrx | (nry << 16)
					if region_set.has(nkey):
						continue
					var dir_idx: int = 0
					if offset.y < 0:
						dir_idx = 0
					elif offset.y > 0:
						dir_idx = 1
					elif offset.x > 0:
						dir_idx = 2
					else:
						dir_idx = 3
					out.append({"region_key": int(rk), "dir": dir_idx})
					break
	return out


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
		var proto_only_draw: bool = bool(territory.get("proto_only", false))
		var is_formal_draw: bool = bool(territory.get("is_formal", not proto_only_draw))
		var fill_alpha_use: float = 0.0 if proto_only_draw else fill_alpha
		var fill_color: Color = Color(color.r, color.g, color.b, fill_alpha_use)
		var border_color: Color
		if is_formal_draw:
			border_color = Color(color.r, color.g, color.b, 0.92)
		else:
			border_color = Color(
					clampf(color.r * 0.82 + 0.12, 0.0, 1.0),
					clampf(color.g * 0.82 + 0.10, 0.0, 1.0),
					clampf(color.b * 0.85 + 0.08, 0.0, 1.0),
					0.68,
			)
		# Draw fill for each region
		var regions: PackedInt32Array = territory["regions"]
		if fill_alpha_use > 0.0:
			for rk in regions:
				var rx: int = int(rk) & 0xFFFF
				var ry: int = (int(rk) >> 16) & 0xFFFF
				var tile_x: int = rx * region_tiles
				var tile_y: int = ry * region_tiles
				var world_pos: Vector2 = _world.tile_to_world(Vector2i(tile_x, tile_y))
				var rect_pos: Vector2 = world_pos - Vector2(half_tile, half_tile)
				var rect_size: Vector2 = Vector2(region_tiles * TILE_PX, region_tiles * TILE_PX)
				draw_rect(Rect2(rect_pos, rect_size), fill_color, true)
		# Draw border segments (region edges + activity-weighted proto outline)
		var segments: Array[Dictionary] = territory["border_segments"]
		if proto_only_draw:
			var activity_segs: Variant = territory.get("activity_segments", [])
			if activity_segs is Array:
				for act_seg in activity_segs as Array:
					if act_seg is Dictionary:
						segments.append(act_seg as Dictionary)
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
	_draw_trade_route_lines(border_width)
	_draw_caravan_markers(half_tile)
	_draw_polity_labels(zoom, half_tile)
	_draw_nation_borders(zoom, border_width, half_tile)
	if _skirmish_flash_tile.x >= 0 and GameManager != null:
		if GameManager.tick_count <= _skirmish_flash_until_tick:
			var flash_pos: Vector2 = _world.tile_to_world(_skirmish_flash_tile)
			var a: Vector2 = flash_pos - Vector2(half_tile, half_tile)
			var b: Vector2 = flash_pos + Vector2(half_tile, half_tile)
			draw_line(a, b, Color(0.95, 0.25, 0.2, 0.95), maxf(2.0, border_width + 1.0), true)
		else:
			_skirmish_flash_tile = Vector2i(-1, -1)


func _draw_trade_route_lines(line_width: float) -> void:
	if TradeMemory == null or not TradeMemory.has_method("get_routes_for_map_draw"):
		return
	var routes: Array = TradeMemory.get_routes_for_map_draw()
	if routes.is_empty():
		return
	var center_by_region: Dictionary = {}
	for territory in _territories:
		var cr: int = int(territory.get("center_region", -1))
		if cr >= 0:
			center_by_region[cr] = territory.get("center_tile", Vector2i.ZERO)
	for route_any in routes:
		if route_any is not Dictionary:
			continue
		var route: Dictionary = route_any as Dictionary
		var from_rk: int = int(route.get("from_settlement", -1))
		var to_rk: int = int(route.get("to_settlement", -1))
		if from_rk < 0 or to_rk < 0:
			continue
		var from_tile: Vector2i = center_by_region.get(from_rk, SettlementPlanner._center_tile_of_region_key(from_rk))
		var to_tile: Vector2i = center_by_region.get(to_rk, SettlementPlanner._center_tile_of_region_key(to_rk))
		var a: Vector2 = _world.tile_to_world(from_tile)
		var b: Vector2 = _world.tile_to_world(to_tile)
		var trade_col: Color = Color(0.92, 0.82, 0.35, 0.55)
		draw_line(a, b, trade_col, maxf(1.0, line_width * 0.65), true)


func _draw_caravan_markers(half_tile: float) -> void:
	if TradeMemory == null or not TradeMemory.has_method("get_caravan_markers"):
		return
	var markers: Array = TradeMemory.get_caravan_markers()
	if markers.is_empty():
		return
	var r: float = maxf(3.0, half_tile * 0.55)
	for marker_any in markers:
		if marker_any is not Dictionary:
			continue
		var marker: Dictionary = marker_any as Dictionary
		var tile: Vector2i = marker.get("tile", Vector2i.ZERO) as Vector2i
		if tile == Vector2i.ZERO:
			continue
		var center: Vector2 = _world.tile_to_world(tile)
		var fill: Color = Color(0.98, 0.78, 0.22, 0.92)
		var outline: Color = Color(0.12, 0.08, 0.02, 0.9)
		draw_circle(center, r, fill)
		draw_arc(center, r + 1.0, 0.0, TAU, 16, outline, 1.5, true)


func _draw_polity_labels(zoom: float, half_tile: float) -> void:
	if zoom > ZOOM_DETAIL:
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11 if zoom < ZOOM_STRATEGY else 9
	for territory in _territories:
		var label: String = str(territory.get("label", "")).strip_edges()
		if label.is_empty():
			continue
		var ct: Vector2i = territory.get("center_tile", Vector2i.ZERO) as Vector2i
		if ct == Vector2i.ZERO:
			continue
		var pos: Vector2 = _world.tile_to_world(ct) + Vector2(0.0, -half_tile * 2.0)
		var col: Color = territory["color"] as Color
		var shadow: Color = Color(0.05, 0.05, 0.08, 0.85)
		draw_string(font, pos + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col.lightened(0.15))


func _draw_nation_borders(zoom: float, border_width: float, half_tile: float) -> void:
	"""Draw nation-level borders on top of settlement territories."""
	if NationBorderSystem == null:
		return
	if zoom > ZOOM_DETAIL:
		return  # Only show at strategy/transition zoom
	var nations: Array[Dictionary] = NationBorderSystem.get_all_nations()
	if nations.is_empty():
		return
	var region_tiles: int = 16
	# Draw nation fills first (subtle tint over settlement fills)
	var fill_alpha: float = 0.08 if zoom < ZOOM_STRATEGY else 0.04
	for nation in nations:
		var color_hex: String = str(nation.get("color", "#888888"))
		var nation_color: Color = NationBorderSystem._hex_to_color(color_hex)
		nation_color.a = fill_alpha
		var territory: Dictionary = nation.get("territory", {})
		for rk in territory.keys():
			var rx: int = int(rk) & 0xFFFF
			var ry: int = (int(rk) >> 16) & 0xFFFF
			var tile_x: int = rx * region_tiles
			var tile_y: int = ry * region_tiles
			var world_pos: Vector2 = _world.tile_to_world(Vector2i(tile_x, tile_y)) - Vector2(half_tile, half_tile)
			var rect_size: Vector2 = Vector2(region_tiles * TILE_PX, region_tiles * TILE_PX)
			draw_rect(Rect2(world_pos, rect_size), nation_color, true)
	# Draw nation borders (thicker lines at nation edges)
	var nation_border_width: float = border_width * 1.5
	for nation in nations:
		var nation_id: int = int(nation.get("id", -1))
		var color_hex: String = str(nation.get("color", "#888888"))
		var nation_color: Color = NationBorderSystem._hex_to_color(color_hex)
		nation_color.a = 0.85
		var territory: Dictionary = nation.get("territory", {})
		if territory.is_empty():
			continue
		# Find border edges: regions where neighbor belongs to different nation or is unclaimed
		for rk in territory.keys():
			var rx: int = int(rk) & 0xFFFF
			var ry: int = (int(rk) >> 16) & 0xFFFF
			for dir_idx in range(4):
				var offset: Vector2i = NEIGHBOR_OFFSETS[dir_idx]
				var nrx: int = rx + offset.x
				var nry: int = ry + offset.y
				var neighbor_key: int = (nrx & 0xFFFF) | ((nry & 0xFFFF) << 16)
				var neighbor_nation: int = NationBorderSystem.get_nation_at_region(neighbor_key)
				if neighbor_nation != nation_id:
					# This is a nation border edge
					var tile_x: int = rx * region_tiles
					var tile_y: int = ry * region_tiles
					var corner_world: Vector2 = _world.tile_to_world(Vector2i(tile_x, tile_y)) - Vector2(half_tile, half_tile)
					var region_size: float = float(region_tiles * TILE_PX)
					var from: Vector2
					var to: Vector2
					match dir_idx:
						0:  # North
							from = corner_world
							to = corner_world + Vector2(region_size, 0.0)
						1:  # South
							from = corner_world + Vector2(0.0, region_size)
							to = corner_world + Vector2(region_size, region_size)
						2:  # East
							from = corner_world + Vector2(region_size, 0.0)
							to = corner_world + Vector2(region_size, region_size)
						3:  # West
							from = corner_world
							to = corner_world + Vector2(0.0, region_size)
					# Contested borders get dashed effect (draw shorter segments)
					var is_contested: bool = NationBorderSystem.is_region_contested(rk)
					var line_color: Color = nation_color
					if is_contested:
						line_color = Color(1.0, 0.3, 0.2, 0.9)  # Red for contested
					draw_line(from, to, line_color, nation_border_width, true)
	# Draw nation labels at strategy zoom
	if zoom < ZOOM_STRATEGY:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 13
		for nation in nations:
			var name: String = str(nation.get("name", ""))
			if name.is_empty():
				continue
			var capital_rk: int = int(nation.get("capital_region", -1))
			if capital_rk < 0:
				continue
			var cx: int = capital_rk & 0xFFFF
			var cy: int = (capital_rk >> 16) & 0xFFFF
			var center_tile: Vector2i = Vector2i(cx * 16 + 8, cy * 16 + 8)
			var pos: Vector2 = _world.tile_to_world(center_tile) + Vector2(0.0, -half_tile * 3.0)
			var color_hex: String = str(nation.get("color", "#888888"))
			var label_color: Color = NationBorderSystem._hex_to_color(color_hex)
			label_color.a = 0.95
			var gov: String = str(nation.get("government_type", ""))
			if gov != "":
				name = name + " (" + gov.capitalize() + ")"
			var shadow: Color = Color(0.05, 0.05, 0.08, 0.9)
			draw_string(font, pos + Vector2(1.0, 1.0), name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
			draw_string(font, pos, name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color.lightened(0.2))


## Deterministic color for a settlement based on its center region key.
## Uses golden ratio hue spacing for visually distinct colors.
static func _color_for_settlement(center_region_key: int) -> Color:
	# Golden ratio hash for well-distributed hues
	var hue: float = fmod(float(abs(center_region_key)) * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.55, 0.85, 1.0)
