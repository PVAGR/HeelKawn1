class_name World
extends Node2D

@onready var _age_memory := get_node("/root/AgeMemory")

## Pixels of screen space per tile. The world is rendered as a 256x256 Image
## baked into an ImageTexture, then scaled up so each source pixel = TILE_PIXELS.
const TILE_PIXELS: int = 10
const DEFAULT_WORLD_SEED: int = 20260429

@onready var _sprite: Sprite2D = $Sprite2D

var data: WorldData

## A* + reachability over `data`. Rebuilt in generate().
var pathfinder: PathFinder

## The colony's primary stockpile node, or null if not placed yet. Pawns
## read this to find deposit / eat targets. Main is responsible for
## instantiating and attaching it after each world generation.
var stockpile: Stockpile = null

## All tiles with a BED feature, in placement order. Pawns scan this when
## they want to sleep. Kept in sync via register_bed / unregister_bed.
var _bed_tiles: Array[Vector2i] = []
## bed tile -> HeelKawnian currently sleeping (or walking to) it. A bed is "free"
## if not present in this dict OR mapped to null.
var _bed_occupants: Dictionary = {}

## Loose item stacks on the ground: tile -> { Item.Type -> qty }. Not persisted in WorldData (v1).
var _ground_items: Dictionary = {}

## Cached base image + texture so we can patch individual tiles in-place
## (e.g. when a feature is harvested) without re-rendering the whole world.
var _image: Image
var _texture: ImageTexture
## 16x16 region_key -> "abandoned" | "permanently_abandoned" | "revivable" (Player-Readable Meaning v1). Rebuilt with terrain refresh.
var _player_meaning_region_state: Dictionary = {}
## 16x16 region_key -> derived label from WorldMeaning (quiet / scarred / bloodied / grave).
var _player_meaning_region_label: Dictionary = {}
## 16x16 region_key -> IntentMemory intent int (derived; rebuilt with terrain refresh).
var _player_meaning_region_intent: Dictionary = {}
## 16x16 region_key -> settlement center region key (for center-marker overlays).
var _player_meaning_region_center: Dictionary = {}
## Rebuilt once per terrain raster: region_key -> culture type for built-feature tint (O(settlements), not O(tiles)).
var _region_culture_tint_cache: Dictionary = {}
## Off-Main autoloads: coalesce at most one end-of-idle full [refresh_terrain_scar_tint] + [refresh_pawn_historic_path_weights] per [GameManager] tick.
var _off_main_terrain_raster_defer_at_tick: int = -1

# Track last-maintained tick for built features
var _feature_last_touched: Dictionary = {}  # "x,y" -> tick

# Footpath wearing: tile_key -> traffic count
var _foot_traffic: Dictionary = {}  # "x,y" -> int traffic_count

var _building_usage: Dictionary = {}  # "x,y" -> usage_count

var _blood_stains: Dictionary = {}  # "x,y" -> { tick, intensity }

var _door_open_tiles: Dictionary = {}  # "x,y" -> open_until_tick


func _ready() -> void:
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(TILE_PIXELS, TILE_PIXELS)
	add_to_group("colony_world")
	pathfinder = PathFinder.new()
	generate(_initial_world_seed())


func _initial_world_seed() -> int:
	for raw_arg in OS.get_cmdline_args():
		var arg: String = str(raw_arg)
		if arg.begins_with("--world-seed="):
			return int(arg.get_slice("=", 1))
	return DEFAULT_WORLD_SEED


func load_world_data(new_data: WorldData) -> void:
	_off_main_terrain_raster_defer_at_tick = -1
	data = new_data
	WorldRNG.configure_from_seed(int(new_data.world_seed))
	pathfinder.rebuild(data)
	_render()
	_bed_tiles.clear()
	_bed_occupants.clear()
	_ground_items.clear()
	resync_beds_from_map()


func generate(world_seed: int) -> void:
	_off_main_terrain_raster_defer_at_tick = -1
	var t0: int = Time.get_ticks_msec()
	data = WorldGenerator.generate(world_seed)
	WorldRNG.configure_from_seed(world_seed)
	var t_gen: int = Time.get_ticks_msec() - t0
	pathfinder.rebuild(data)
	var t_path: int = Time.get_ticks_msec() - t0 - t_gen
	_render()
	# Beds and their occupants don't survive a regen -- the tiles they sit
	# on are gone.
	_bed_tiles.clear()
	_bed_occupants.clear()
	_ground_items.clear()
	var dt: int = Time.get_ticks_msec() - t0
	if OS.is_debug_build() and GameManager.verbose_logs():
		print(
				"[World] Generated seed=%d  %dx%d  gen=%dms path=%dms total=%dms" %
				[world_seed, WorldData.WIDTH, WorldData.HEIGHT, t_gen, t_path, dt]
		)
		_print_distribution()


func _print_distribution() -> void:
	if not OS.is_debug_build() or not GameManager.verbose_logs():
		return
	var biome_counts: Dictionary = {}
	for biome in Biome.Type.values():
		biome_counts[biome] = 0
	var feature_counts: Dictionary = {}
	for f in TileFeature.Type.values():
		feature_counts[f] = 0
	for i in range(WorldData.TILE_COUNT):
		biome_counts[data.biomes[i]] += 1
		feature_counts[data.features[i]] += 1
	var total: float = float(WorldData.TILE_COUNT)
	var biome_line := "[World] Biomes:"
	for biome in Biome.Type.values():
		biome_line += "  %s=%.1f%%" % [Biome.name_for(biome), 100.0 * biome_counts[biome] / total]
	print(biome_line)
	var feature_line := "[World] Features:"
	for f in TileFeature.Type.values():
		if f == TileFeature.Type.NONE:
			continue
		feature_line += "  %s=%d" % [TileFeature.name_for(f), feature_counts[f]]
	print(feature_line)


func _render() -> void:
	_image = Image.create(WorldData.WIDTH, WorldData.HEIGHT, false, Image.FORMAT_RGB8)
	_refresh_terrain_image_pixels()
	_texture = ImageTexture.create_from_image(_image)
	_sprite.texture = _texture


## Re-raster all tiles (biome, features, and deterministic historical scar tint). Call after
## `WorldPersistence.recompute()` or when you need the map to match changed persistence
## without a full `generate` / `load_world_data` (e.g. after load, reroll, long-run death history).
func refresh_terrain_scar_tint() -> void:
	if _image == null or data == null or _texture == null:
		return
	_rebuild_player_meaning_region_state()
	_refresh_terrain_image_pixels()
	_texture.update(_image)


## After [WorldPersistence.recompute], refresh A* point weights for pawn-only historic scar aversion.
func refresh_pawn_historic_path_weights() -> void:
	if pathfinder != null:
		pathfinder.refresh_pawn_historic_scar_weights(self)


func _refresh_terrain_image_pixels() -> void:
	_rebuild_region_culture_tint_cache()
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			_image.set_pixel(x, y, _tile_color(x, y))


func _rebuild_region_culture_tint_cache() -> void:
	_region_culture_tint_cache.clear()
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s as Dictionary
		var ct: int = preload("res://autoloads/SettlementPlanner.gd").get_culture_type_for_settlement(d)
		var regs: Variant = d.get("regions", null)
		if regs is PackedInt32Array:
			for rk_any in regs as PackedInt32Array:
				_region_culture_tint_cache[int(rk_any)] = ct


func _tile_color(x: int, y: int) -> Color:
	var i: int = data.index(x, y)
	var feature: int = data.features[i]
	var base: Color
	if feature != TileFeature.Type.NONE:
		base = TileFeature.color_for(feature)
		# Phase 6: all built features (not wildlife/natural) get culture tints
		var is_built_feature: bool = (
			feature != TileFeature.Type.NONE
			and feature != TileFeature.Type.ORE_VEIN
			and feature != TileFeature.Type.FERTILE_SOIL
			and feature != TileFeature.Type.RUIN
			and feature != TileFeature.Type.TREE
			and feature != TileFeature.Type.RABBIT
			and feature != TileFeature.Type.DEER
			and feature != TileFeature.Type.RIVER
			and feature != TileFeature.Type.FORD
			and feature != TileFeature.Type.FLOOD_DEPOSIT
		)
		if is_built_feature:
			var rk_ct: int = WorldMemory._region_key(x, y) if WorldMemory != null else 0
			if _region_culture_tint_cache.has(rk_ct):
				# Landmark buildings get stronger cultural tint
				if feature == TileFeature.Type.FIRE_PIT or feature == TileFeature.Type.SHRINE or feature == TileFeature.Type.MARKER_STONE or feature == TileFeature.Type.BARRACKS or feature == TileFeature.Type.WATCHTOWER or feature == TileFeature.Type.LIBRARY or feature == TileFeature.Type.MARKET:
					base = TileFeature.apply_culture_landmark_tint(
							base, int(_region_culture_tint_cache[rk_ct])
					)
				else:
					base = TileFeature.apply_culture_tint_to_built_color(
							base, int(_region_culture_tint_cache[rk_ct])
					)
			# Apply settlement state tint (Phase 4: posture visual indicators)
			if is_instance_valid(SettlementMemory):
				var settlement_state: String = SettlementMemory.get_state_for_region(rk_ct)
				if not settlement_state.is_empty():
					base = TileFeature.apply_settlement_state_tint(base, settlement_state)
		# Crop growth stages for farm tiles
		if feature in [TileFeature.Type.FARM_WHEAT, TileFeature.Type.FARM_CORN, TileFeature.Type.FARM_VEGETABLES, TileFeature.Type.HERB_GARDEN]:
			var _fs: Node = get_node_or_null("/root/FarmingSystem")
			var stage: int = -1
			if _fs != null and _fs.has_method("get_growth_stage"):
				stage = int(_fs.call("get_growth_stage", Vector2i(x, y)))
			match stage:
				0:
					base = Color8(180, 160, 80, 200)
				1:
					base = Color8(100, 180, 60, 200)
				2:
					base = Color8(200, 180, 40, 220)
		# Door open animation: lighter when open
		if feature == TileFeature.Type.DOOR:
			var door_key: String = "%d,%d" % [x, y]
			if _door_open_tiles.has(door_key):
				base = base.lightened(0.3)
		if feature == TileFeature.Type.RUIN:
			# Further desaturate / drain rubble; land-recovery v1: ruin tint still uses max scar, not recovery_stage.
			var g: float = (base.r + base.g + base.b) * 0.33
			base = base.lerp(Color(g, g * 0.95, g * 0.9, 1.0), 0.22)
	else:
		base = Biome.color_for_season(data.biomes[i], Biome.season_for_tick(GameManager.tick_count))
		# Terrain noise: deterministic per-tile color variation for visual richness
		var noise_hash: int = (x * 19349663 + y * 73856093) & 0xFF
		var noise_val: float = float(noise_hash) / 255.0  # 0..1
		var biome: int = data.biomes[i]
		if biome == Biome.Type.WATER:
			# Water shimmer: subtle blue channel shift
			var shimmer: float = sin(float(GameManager.tick_count) * 0.01 + noise_val * TAU) * 0.05
			base = Color(base.r + shimmer * 0.3, base.g + shimmer * 0.5, base.b + shimmer, 1.0)
			# Water reflection: reflect adjacent built features
			var reflect_color: Color = Color.TRANSPARENT
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx: int = x + dx
					var ny: int = y + dy
					if data.in_bounds(nx, ny):
						var feat: int = data.get_feature(nx, ny)
						if feat != TileFeature.Type.NONE and feat != TileFeature.Type.RIVER:
							reflect_color = _tile_color_for_feature(feat, nx, ny)
							break
				if reflect_color.a > 0:
					break
			if reflect_color.a > 0:
				reflect_color.a = 0.3
				base = base.lerp(reflect_color, 0.2)
		else:
			# All other biomes: ±8% color variation
			var variation: float = 0.92 + noise_val * 0.16  # 0.92..1.08
			base = Color(base.r * variation, base.g * variation, base.b * variation, 1.0)
	# RUIN: full historical scar; meaning; road; trade; local Remnant patina; then epochal Age.
	return _apply_age_tint(
			_apply_remnant_patina(
					_apply_trade_route_tint(
							_apply_road_tint(
									_apply_player_meaning_tint(
											_apply_scar_visual_to_color(
													base, x, y, feature == TileFeature.Type.RUIN
											),
											x,
											y
									),
									x,
									y
							),
							x,
							y
					),
					x,
					y
			)
	)


func _tile_color_for_feature(feat: int, x: int, y: int) -> Color:
	if feat in [TileFeature.Type.WALL, TileFeature.Type.STORAGE_HUT]:
		return Color8(120, 100, 80)
	if feat in [TileFeature.Type.BED]:
		return Color8(180, 120, 80)
	if feat in [TileFeature.Type.DOOR]:
		return Color8(100, 80, 60)
	return Color8(150, 130, 110)


## Per-tile prior-Age desat + deterministic micro-shift (v1; read-only; after road/trade).
func _apply_remnant_patina(c: Color, x: int, y: int) -> Color:
	var d: int = RemnantMemory.get_tile_rem_delta(x, y, self)
	if d < 1:
		return c
	var y1: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var g1: Color = Color(y1, y1, y1, 1.0)
	var pat: float = 0.04 + 0.03 * float(d - 1)
	c = c.lerp(g1, minf(0.14, pat))
	if d >= 2:
		var h: int = int((x * 19349663 + y * 73856093) & 0x1F)
		var ph: float = 0.002 * (float(h) / 31.0)
		c = c.lerp(c * Color(0.99 + ph, 0.995, 0.99 - ph, 1.0), 0.12)
	return c


## Global slow desaturation with Age index (v1; read-only; no world reset).
func _apply_age_tint(c: Color) -> Color:
	var w: float = _age_memory.get_global_age_tint_strength()
	if w <= 0.0001:
		return c
	var y2: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var gray2: Color = Color(y2, y2, y2, 1.0)
	return c.lerp(gray2, w)


## Deterministic: same (region_key, stage) always yields the same modifier.
## Land uses `recovery_stage` (0..scar_level); ruins use `scar_level` so they never "heal" visually in v1.
## Does not change biome or walkability; visual only.
func _apply_scar_visual_to_color(c: Color, x: int, y: int, use_max_scar: bool) -> Color:
	# Calculate region key - handle case where singletons aren't ready yet
	var rk: int
	if WorldMemory != null:
		rk = WorldMemory._region_key(x, y)
	else:
		# Fallback calculation: region key from tile coordinates (16x16 tiles per region)
		var rx: int = int(x) >> 4
		var ry: int = int(y) >> 4
		rk = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
	
	var p: Dictionary
	if WorldPersistence != null:
		p = WorldPersistence.get_region_persistence(rk)
	else:
		p = {}  # Empty dictionary as fallback
		
	var sl: int = int(p.get("scar_level", 0))
	var tier: int
	if use_max_scar:
		tier = sl
	else:
		# If key missing (legacy): fall back to scar_level once; explicit 0 means healed-out visually.
		tier = int(p.get("recovery_stage", sl))
	if tier <= 0:
		return c
	# Slight (1) / moderate (2) / strong (3) darkening and browning toward a dead-land tone.
	var mul: Color
	var blend: float
	match tier:
		1:
			mul = Color(0.88, 0.84, 0.78, 1.0)
			blend = 0.10
		2:
			mul = Color(0.7, 0.58, 0.5, 1.0)
			blend = 0.22
		3:
			mul = Color(0.48, 0.38, 0.32, 1.0)
			blend = 0.36
		_:
			return c
	# c * mul tints; lerp blends strength per tier.
	return c.lerp(c * mul, blend)


func _rebuild_player_meaning_region_state() -> void:
	_player_meaning_region_state.clear()
	_player_meaning_region_label.clear()
	_player_meaning_region_intent.clear()
	_player_meaning_region_center.clear()
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var st: String = str(d.get("state", ""))
		if not SettlementMemory.is_collapsed_state(st) and st != "revivable":
			continue
		var ckr: int = int(d.get("center_region", -1))
		var intent: int = int(IntentMemory.settlement_intent.get(ckr, IntentMemory.INTENT_HOLD))
		var reg1: Variant = d.get("regions", null)
		if not (reg1 is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg1 as PackedInt32Array
		var label: String = str(WorldMeaning.get_region_meaning_label(int(d.get("center_region", -1))))
		for u in range(p.size()):
			var rk2: int = int(p[u])
			_player_meaning_region_state[rk2] = st
			_player_meaning_region_label[rk2] = label
			_player_meaning_region_intent[rk2] = intent
			_player_meaning_region_center[rk2] = ckr


## Stacks on scar; deterministic per 16x16 region (settlement state only).
func _apply_player_meaning_tint(c: Color, x: int, y: int) -> Color:
	# Handle case where WorldMemory isn't ready yet
	if WorldMemory == null:
		return c
	var rk: int = WorldMemory._region_key(x, y)
	if not _player_meaning_region_state.has(rk):
		return c
	var st: String = str(_player_meaning_region_state.get(rk, ""))
	var label: String = str(_player_meaning_region_label.get(rk, "quiet"))
	var now_tick: int = GameManager.tick_count
	if st == "permanently_abandoned":
		var yv0: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var gray0: Color = Color(yv0, yv0, yv0, 1.0)
		c = c.lerp(gray0, 0.28 if label == "grave" else 0.2)
		c = c * Color(0.82, 0.85, 0.9, 1.0)
		var center_rk: int = int(_player_meaning_region_center.get(rk, -1))
		if center_rk >= 0:
			var cx: int = (center_rk & 0xFFFF) * 16 + 8
			var cy: int = ((center_rk >> 16) & 0xFFFF) * 16 + 8
			var md: int = abs(x - cx) + abs(y - cy)
			if md <= 2:
				# Deterministic grave marker overlay at settlement center.
				return c.lerp(Color(0.86, 0.86, 0.9, 1.0), 0.5)
		if (abs((x + y + int(now_tick / 800)) % 9) == 0):
			c = c.lerp(Color(0.78, 0.8, 0.85, 1.0), 0.18)
		return c
	if st == "abandoned":
		var yv: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var gray: Color = Color(yv, yv, yv, 1.0)
		# Gray static: deterministic, non-pulsing abandoned presentation.
		c = c.lerp(gray, 0.18 if label == "bloodied" else 0.14)
		c = c * Color(0.88, 0.88, 0.88, 1.0)
		return c
	if st == "revivable":
		# Green pulse to show rebirth readiness.
		var pulse: float = 0.5 + 0.5 * sin(float(now_tick + rk) * 0.01)
		var pulse_strength: float = lerpf(0.08, 0.22, pulse)
		var pulse_color: Color = Color(0.8, 1.15, 0.82, 1.0)
		c = c.lerp(c * pulse_color, pulse_strength)
		return c
	return c


## Emergent path wear from [RoadMemory] (traversal). Biome-agnostic tint on top of other layers.
func _apply_road_tint(c: Color, x: int, y: int) -> Color:
	var t: int = RoadMemory.get_traversal(x, y)
	if t < RoadMemory.ROAD_T1:
		return c
	if t < RoadMemory.ROAD_T2:
		return c.lerp(c * Color(1.08, 1.06, 1.03, 1.0), 0.2)
	return c.lerp(c * Color(1.15, 1.12, 1.06, 1.0), 0.3)


## Recurring inter-settlement trade routes from [TradeMemory] (derived; stacks on roads / scar / meaning).
func _apply_trade_route_tint(c: Color, x: int, y: int) -> Color:
	var tr: int = TradeMemory.get_route_tier_at(x, y)
	if tr == TradeMemory.TIER_NONE:
		return c
	if tr == TradeMemory.TIER_ROUTE_1:
		return c.lerp(c * Color(1.08, 1.07, 1.05, 1.0), 0.15)
	return c.lerp(c * Color(1.18, 1.12, 0.95, 1.0), 0.25)


## Single-tile update after a traversal increment (pawns only).
func patch_road_tile_at(x: int, y: int) -> void:
	if _image == null or data == null or not data.in_bounds(x, y):
		return
	_image.set_pixel(x, y, _tile_color(x, y))
	if _texture != null:
		_texture.update(_image)


## Index form of [method patch_road_tile_at] for batch road-memory updates.
func patch_road_tile_at_index(idx: int) -> void:
	if idx < 0 or idx >= WorldData.TILE_COUNT:
		return
	var x: int = idx % WorldData.WIDTH
	var y: int = int(idx / float(WorldData.WIDTH))
	patch_road_tile_at(x, y)


## Full re-raster (decay of road memory).
func refresh_road_memory_terrain() -> void:
	if _image == null or data == null or _texture == null:
		return
	_refresh_terrain_image_pixels()
	_texture.update(_image)


## Full re-raster after [TradeMemory] route tiles change (same cost as road refresh).
func refresh_trade_memory_terrain() -> void:
	if _image == null or data == null or _texture == null:
		return
	_refresh_terrain_image_pixels()
	_texture.update(_image)


func _tick_erosion(tick: int) -> void:
	if tick % 2000 != 0:
		return
	var decay_count: int = 0
	for key in _feature_last_touched.keys():
		var last_tick: int = _feature_last_touched[key]
		if tick - last_tick > 10000:
			var parts: Array = key.split(",")
			if parts.size() != 2:
				continue
			var x: int = int(parts[0])
			var y: int = int(parts[1])
			var feat: int = data.get_feature(x, y)
			if feat in [TileFeature.Type.WALL, TileFeature.Type.DOOR, TileFeature.Type.FIRE_PIT,
					TileFeature.Type.STORAGE_HUT]:
				clear_feature(x, y)
				decay_count += 1
				if decay_count >= 5:
					break
	if decay_count > 0:
		_cleanup_erosion_tracking()


func _cleanup_erosion_tracking() -> void:
	var to_remove: Array[String] = []
	for key in _feature_last_touched.keys():
		var parts: Array = key.split(",")
		if parts.size() != 2:
			continue
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		if data.get_feature(x, y) == TileFeature.Type.NONE:
			to_remove.append(key)
	for key in to_remove:
		_feature_last_touched.erase(key)


## Deterministic ruins (v1): built structures in death-scarred, unoccupied
## regions become static `TileFeature.RUIN` (passable rubble, no use). No RNG.
## Call after `refresh_terrain_scar_tint()`; uses `WorldPersistence` + pawn positions only.
func apply_ruins_from_persistence() -> void:
	if data == null:
		return
	var region_has_pawn: Dictionary = {}
	for p in PawnSpawner.find_pawns():
		if not is_instance_valid(p):
			continue
		if p.data == null:
			continue
		var tp: Vector2i = p.data.tile_pos
		var rpk: int = WorldMemory._region_key(tp.x, tp.y) if WorldMemory != null else 0
		region_has_pawn[rpk] = true
	var any_change: bool = false
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var f: int = data.get_feature(x, y)
			if f != TileFeature.Type.BED and f != TileFeature.Type.WALL and f != TileFeature.Type.DOOR:
				continue
			var rk: int = WorldMemory._region_key(x, y) if WorldMemory != null else 0
			# Only ruinize structures in collapsed settlements.
			if not SettlementMemory.is_region_in_collapsed_settlement(rk):
				continue
			if WorldPersistence == null:
				continue
			if int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0)) < 2:
				continue
			if region_has_pawn.has(rk):
				continue
			if f == TileFeature.Type.BED:
				unregister_bed(Vector2i(x, y))
			var i: int = data.index(x, y)
			data.features[i] = TileFeature.Type.RUIN
			RemnantMemory.on_feature_set(self, x, y, int(TileFeature.Type.RUIN))
			any_change = true
			if _image != null:
				_image.set_pixel(x, y, _tile_color(x, y))
	if any_change and _texture != null:
		_texture.update(_image)
		if pathfinder != null:
			pathfinder.rebuild(data)
		notify_pawns_nav_changed()


## Remove a tile feature (used when FORAGE / MINE jobs complete). Patches the
## texture in-place so we don't re-render the whole world.
func clear_feature(x: int, y: int) -> void:
	set_feature(x, y, TileFeature.Type.NONE)


## Set or replace the feature at a tile and update the rendered texture.
## Used by FORAGE / MINE / CHOP completion (clear) and by the regrowth
## system (re-spawning trees and fertile soil after a delay). Returns true
## if the tile actually changed.
func set_feature(x: int, y: int, feature: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	var i: int = data.index(x, y)
	if data.features[i] == feature:
		return false
	data.features[i] = feature
	RemnantMemory.on_feature_set(self, x, y, feature)
	# Track for erosion
	if feature != TileFeature.Type.NONE and feature != TileFeature.Type.RIVER:
		_feature_last_touched["%d,%d" % [x, y]] = GameManager.tick_count if GameManager != null else 0
	# DORMANT WORLD: Unlock gates when HeelKawnians build key structures
	if DiscoveryGate != null:
		if feature == TileFeature.Type.FIRE_PIT:
			DiscoveryGate.unlock("first_fire")
		elif feature == TileFeature.Type.BED:
			DiscoveryGate.unlock("first_shelter")
	if _image != null:
		_image.set_pixel(x, y, _tile_color(x, y))
		_texture.update(_image)
	# Notify WorldOverlay to redraw building sprites
	var overlay: Node = get_node_or_null("WorldOverlay")
	if overlay != null and overlay.has_method("mark_dirty"):
		overlay.mark_dirty()
	return true


## Build a wall on the target tile: place the WALL feature, mark the tile
## impassable in the pathfinder, and recompute connected components. Returns
## true if the tile actually changed (false if it was already a wall, or out
## of bounds, or already impassable mountain/water -- those are nonsense
## build sites).
func build_wall(x: int, y: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	if not Biome.is_passable(data.biomes[data.index(x, y)]):
		return false
	# Shove pawns *before* the feature flips: tile may be reserved in A* or
	# still walkable in `data` — nudge by logical tile, not by solidity.
	nudge_occupants_off_tile_for_construction(x, y)
	if not set_feature(x, y, TileFeature.Type.WALL):
		return false
	# Clear any pending path reservation for this cell; _refresh re-reads WALL
	# from `data` as non-walkable.
	if pathfinder != null:
		pathfinder.set_job_construction_reservation(x, y, false, data)
	_bump_occupants_off_tile(x, y)
	notify_pawns_nav_changed()
	return true


## Nudge pawns off (x,y) when that tile is still walkable in `data` (e.g. just
## before a wall build completes, or a planned reservation).
func nudge_occupants_off_tile_for_construction(x: int, y: int) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or pathfinder == null:
		return
	var here := Vector2i(x, y)
	for _i in range(4):
		var any: bool = false
		for p in PawnSpawner.find_pawns():
			if p.data != null and p.data.tile_pos == here:
				p.evict_to_neighbor_of_tile(here)
				any = true
		if not any:
			break


func notify_pawns_nav_changed() -> void:
	for p in PawnSpawner.find_pawns():
		p.on_world_nav_changed()


# ==================== Footpath wearing ====================

func record_footstep(tile: Vector2i) -> void:
	var key: String = "%d,%d" % [tile.x, tile.y]
	var count: int = int(_foot_traffic.get(key, 0))
	_foot_traffic[key] = mini(count + 1, 100)
	if count % 5 == 0 and count > 0:
		_update_path_appearance(tile, count)
	# Also clear snow on footstep - DISABLED due to method signature issues
	# var _sa: Node = get_node_or_null("/root/SnowAccumulation")
	# if _sa != null and _sa.has_method("get_snow_depth"):
	# 	var sd: float = float(_sa.call("get_snow_depth", tile))
	# 	if sd > 0.0 and _sa.has_method("clear_snow_at"):
	# 		_sa.call("clear_snow_at", tile)


func _update_path_appearance(tile: Vector2i, traffic: int) -> void:
	if _image == null:
		return
	var c: Color = _image.get_pixel(tile.x, tile.y)
	var wear: float = mini(1.0, float(traffic) / 100.0)
	var worn: Color = Color8(140, 120, 100)
	c = c.lerp(worn, wear * 0.3)
	_image.set_pixel(tile.x, tile.y, c)
	_texture.update(_image)


# ==================== Building wear ====================

func record_building_usage(tile: Vector2i) -> void:
	var key: String = "%d,%d" % [tile.x, tile.y]
	var count: int = int(_building_usage.get(key, 0))
	_building_usage[key] = mini(count + 1, 200)
	_update_building_appearance(tile, _building_usage[key])


func _update_building_appearance(tile: Vector2i, usage: int) -> void:
	if _image == null:
		return
	var c: Color = _image.get_pixel(tile.x, tile.y)
	var wear: float = mini(1.0, float(usage) / 200.0)
	var soot: Color = Color8(60, 50, 40)
	c = c.lerp(soot, wear * 0.15)
	_image.set_pixel(tile.x, tile.y, c)
	_texture.update(_image)


# ==================== Blood stains ====================

func add_blood_stain(tile: Vector2i, intensity: float = 0.5) -> void:
	if not data.in_bounds(tile.x, tile.y):
		return
	var key: String = "%d,%d" % [tile.x, tile.y]
	_blood_stains[key] = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"intensity": clampf(intensity, 0.1, 1.0),
	}
	_update_blood_stain(tile, _blood_stains[key])


func _tick_blood_stains(tick: int) -> void:
	if tick % 100 != 0:
		return
	var to_remove: Array[String] = []
	for key in _blood_stains:
		var bdata: Dictionary = _blood_stains[key]
		var age: int = tick - int(bdata.get("tick", 0))
		if age > 500:
			to_remove.append(key)
		elif age > 400:
			var parts: Array = key.split(",")
			_redraw_tile(int(parts[0]), int(parts[1]))
	for key in to_remove:
		_blood_stains.erase(key)
		var parts: Array = key.split(",")
		_redraw_tile(int(parts[0]), int(parts[1]))


func _update_blood_stain(tile: Vector2i, bdata: Dictionary) -> void:
	if _image == null:
		return
	var c: Color = _image.get_pixel(tile.x, tile.y)
	var blood: Color = Color8(180, 30, 30)
	var intensity: float = float(bdata.get("intensity", 0.5))
	c = c.lerp(blood, intensity * 0.4)
	_image.set_pixel(tile.x, tile.y, c)
	_texture.update(_image)


func _redraw_tile(x: int, y: int) -> void:
	if _image == null or not data.in_bounds(x, y):
		return
	_image.set_pixel(x, y, _tile_color(x, y))
	_texture.update(_image)


# ==================== Door animation ====================

func open_door(tile: Vector2i, duration_ticks: int = 10) -> void:
	var key: String = "%d,%d" % [tile.x, tile.y]
	_door_open_tiles[key] = (GameManager.tick_count if GameManager != null else 0) + duration_ticks
	_redraw_tile(tile.x, tile.y)


func _tick_doors(tick: int) -> void:
	var to_close: Array[String] = []
	for key in _door_open_tiles:
		if int(_door_open_tiles[key]) <= tick:
			to_close.append(key)
	for key in to_close:
		_door_open_tiles.erase(key)
		var parts: Array = key.split(",")
		_redraw_tile(int(parts[0]), int(parts[1]))


## `JobManager` only: release path reservations on full job **cancel** (the job
## is destroyed). `abandon` does **not** call this — the site stays reserved
## for the next claim.
func on_construction_path_job_ended(job: Job) -> void:
	if data == null or pathfinder == null or job == null:
		return
	if job.type == Job.Type.BUILD_WALL:
		pathfinder.set_job_construction_reservation(job.tile.x, job.tile.y, false, data)
		notify_pawns_nav_changed()


## Pawns in group "pawns" whose `tile_pos` matches (x,y) are nudged to the
## nearest passable neighbor. Re-run a few times if multiple pawns share a tile.
func _bump_occupants_off_tile(x: int, y: int) -> void:
	var target: Vector2i = Vector2i(x, y)
	for _i in range(8):
		var any: bool = false
		for pawn in PawnSpawner.find_pawns():
			if pawn.data != null and pawn.data.tile_pos == target:
				pawn.nudge_if_standing_on_solid()
				any = true
		if not any:
			break


## Public alias: after a wall job reserves a cell, shove pawns nudged to solid.
func kick_occupants_off_reserved_build_tile(x: int, y: int) -> void:
	_bump_occupants_off_tile(x, y)


## Build a door on the target tile, OR replace an existing WALL (same tile).
## Doors stay passable in A*. Replacing a wall clears that tile's solidity.
func build_door(x: int, y: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	var i: int = data.index(x, y)
	var feat: int = data.features[i]
	# "Stronghold" style: punch a door through a wall without deleting the
	# rest of the line — swap feature and reopen the tile for pathing.
	if feat == TileFeature.Type.WALL:
		if not set_feature(x, y, TileFeature.Type.DOOR):
			return false
		if pathfinder != null:
			pathfinder.sync_tile_from_data(x, y, data)
		notify_pawns_nav_changed()
		return true
	# New door on empty passable land (Kenshi / RimWorld: door on an opening).
	if not Biome.is_passable(data.biomes[i]):
		return false
	if feat != TileFeature.Type.NONE:
		return false
	if not set_feature(x, y, TileFeature.Type.DOOR):
		return false
	if pathfinder != null:
		pathfinder.sync_tile_from_data(x, y, data)
	notify_pawns_nav_changed()
	return true


## Convert a MOUNTAIN tile into a STONE_FLOOR (passable). Used by MINE_WALL
## jobs to let pawns tunnel into mountain ranges. Updates the texture, the
## A* solidity map, and the connected-components map in one shot. Returns
## true if the tile was actually changed.
func mine_out_wall(x: int, y: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	var i: int = data.index(x, y)
	if data.biomes[i] != Biome.Type.MOUNTAIN:
		return false
	data.biomes[i] = Biome.Type.STONE_FLOOR
	# Any feature riding on the mountain (e.g. ORE_VEIN) is harvested at the
	# same time -- you can't extract ore without removing the rock around it.
	if data.features[i] != TileFeature.Type.NONE:
		data.features[i] = TileFeature.Type.NONE
	if _image != null:
		_image.set_pixel(x, y, _tile_color(x, y))
		_texture.update(_image)
	# Pathfinder: the tile is now passable; recompute components so anything
	# that was sealed behind this wall joins the right component.
	if pathfinder != null:
		pathfinder.sync_tile_from_data(x, y, data)
	notify_pawns_nav_changed()
	return true


## Convert a world-space point into tile coordinates. Returns (-1, -1) if
## the point is outside the map.
func world_to_tile(world_pos: Vector2) -> Vector2i:
	var half_w: float = WorldData.WIDTH * TILE_PIXELS * 0.5
	var half_h: float = WorldData.HEIGHT * TILE_PIXELS * 0.5
	var local := world_pos - global_position
	var tx: int = int(floor((local.x + half_w) / TILE_PIXELS))
	var ty: int = int(floor((local.y + half_h) / TILE_PIXELS))
	if not data.in_bounds(tx, ty):
		return Vector2i(-1, -1)
	return Vector2i(tx, ty)


## Convert tile coordinates into world-space (centered on the tile).
func tile_to_world(tile: Vector2i) -> Vector2:
	var half_w: float = WorldData.WIDTH * TILE_PIXELS * 0.5
	var half_h: float = WorldData.HEIGHT * TILE_PIXELS * 0.5
	return global_position + Vector2(
		tile.x * TILE_PIXELS - half_w + TILE_PIXELS * 0.5,
		tile.y * TILE_PIXELS - half_h + TILE_PIXELS * 0.5
	)


# ==================== beds ====================
#
# Beds are rendered through the regular feature pipeline (TileFeature.BED), but
# we additionally track them here so pawns can ask "is there a bed I can sleep
# in nearby?" without scanning every tile every tick.
#
# Reservation model: a tired pawn calls reserve_bed() before walking to it,
# then release_bed() on wake or panic-abort. Two pawns can never end up
# walking to the same bed and arguing over it.

func register_bed(tile: Vector2i) -> void:
	if not _bed_tiles.has(tile):
		_bed_tiles.append(tile)
	# Newly built beds start free.
	if not _bed_occupants.has(tile):
		_bed_occupants[tile] = null


func unregister_bed(tile: Vector2i) -> void:
	_bed_tiles.erase(tile)
	_bed_occupants.erase(tile)


func is_bed(tile: Vector2i) -> bool:
	return _bed_occupants.has(tile)


func is_bed_free(tile: Vector2i) -> bool:
	return _bed_occupants.has(tile) and _bed_occupants[tile] == null


## True if the bed is currently reserved/occupied by `pawn` specifically. Used
## by HeelKawnian._decay_needs to grant the bed sleep bonus only to its rightful sleeper.
func is_bed_owned_by(tile: Vector2i, pawn: HeelKawnian) -> bool:
	return _bed_occupants.get(tile, null) == pawn


## Atomically reserve the given bed for `pawn`. Returns false if it's not a
## bed or someone else already holds it. Successful reserve survives the walk
## to the bed and the entire sleep, then must be released.
func reserve_bed(tile: Vector2i, pawn: HeelKawnian) -> bool:
	if not _bed_occupants.has(tile):
		return false
	var current = _bed_occupants[tile]
	if current != null and current != pawn:
		return false
	_bed_occupants[tile] = pawn
	return true


func release_bed(tile: Vector2i, pawn: HeelKawnian) -> void:
	if not _bed_occupants.has(tile):
		return
	if _bed_occupants[tile] == pawn:
		_bed_occupants[tile] = null


## Find the closest unreserved bed reachable from `from_tile` for `pawn`. Closest
## by Chebyshev distance to keep this O(N_beds); reachability uses the connected-
## components map so we never propose a bed across an impassable wall. Returns
## Vector2i(-1,-1) if no bed qualifies.
func find_free_bed_for(pawn: HeelKawnian, from_tile: Vector2i) -> Vector2i:
	if _bed_tiles.is_empty() or pathfinder == null:
		return Vector2i(-1, -1)
	var my_component: int = pathfinder.component_of(from_tile)
	var best := Vector2i(-1, -1)
	var best_dist: int = 0x7FFFFFFF
	for t in _bed_tiles:
		if not is_bed_free(t):
			# Allow a pawn to "find" the bed it already holds (defensive).
			if _bed_occupants.get(t, null) != pawn:
				continue
		if pathfinder.component_of(t) != my_component:
			continue
		var d: int = max(abs(t.x - from_tile.x), abs(t.y - from_tile.y))
		if d < best_dist:
			best = t
			best_dist = d
	return best


func bed_count() -> int:
	return _bed_tiles.size()


## Return a Dictionary mapping each non-NONE TileFeature.Type to its count on the map.
## Used by the F10 debug panel's structure inventory report.
func get_feature_counts() -> Dictionary:
	var counts: Dictionary = {}
	if data == null:
		return counts
	for i in range(WorldData.TILE_COUNT):
		var f: int = data.features[i]
		if f == TileFeature.Type.NONE:
			continue
		if not counts.has(f):
			counts[f] = 0
		counts[f] += 1
	return counts


## Add loose items on the ground at `tile` (merge stacks). Ignores invalid tiles or NONE type.
func add_ground_item(tile: Vector2i, item_type: int, qty: int) -> void:
	if data == null or not data.in_bounds(tile.x, tile.y):
		return
	if item_type == Item.Type.NONE or qty <= 0:
		return
	if not _ground_items.has(tile):
		_ground_items[tile] = {}
	var inv: Dictionary = _ground_items[tile]
	inv[item_type] = int(inv.get(item_type, 0)) + qty


## Remove up to `qty` of `item_type` at `tile`. Returns amount actually removed.
func take_ground_items(tile: Vector2i, item_type: int, qty: int) -> int:
	if item_type == Item.Type.NONE or qty <= 0:
		return 0
	if not _ground_items.has(tile):
		return 0
	var inv: Dictionary = _ground_items[tile]
	var have: int = int(inv.get(item_type, 0))
	var taken: int = mini(have, qty)
	if taken <= 0:
		return 0
	inv[item_type] = have - taken
	if int(inv[item_type]) <= 0:
		inv.erase(item_type)
	if inv.is_empty():
		_ground_items.erase(tile)
	return taken


## Copy of per-type stacks at `tile` (empty if none).
func get_ground_stacks_at(tile: Vector2i) -> Dictionary:
	if not _ground_items.has(tile):
		return {}
	return (_ground_items[tile] as Dictionary).duplicate()


func has_any_ground_item_at(tile: Vector2i) -> bool:
	if not _ground_items.has(tile):
		return false
	var inv: Dictionary = _ground_items[tile]
	for t in inv.keys():
		if int(inv[t]) > 0:
			return true
	return false


## After loading a world from save (or any bulk feature change), rescan the
## map for BED features and repopulate `_bed_tiles` / free slots in
## `_bed_occupants`. No occupants carry over a regen, but load keeps data.
func resync_beds_from_map() -> void:
	_bed_tiles.clear()
	_bed_occupants.clear()
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			if data.get_feature(x, y) == TileFeature.Type.BED:
				var t: Vector2i = Vector2i(x, y)
				register_bed(t)
