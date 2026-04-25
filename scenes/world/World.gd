class_name World
extends Node2D

@onready var _age_memory := get_node("/root/AgeMemory")

## Pixels of screen space per tile. The world is rendered as a 256x256 Image
## baked into an ImageTexture, then scaled up so each source pixel = TILE_PIXELS.
const TILE_PIXELS: int = 8

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
## bed tile -> Pawn currently sleeping (or walking to) it. A bed is "free"
## if not present in this dict OR mapped to null.
var _bed_occupants: Dictionary = {}

## Cached base image + texture so we can patch individual tiles in-place
## (e.g. when a feature is harvested) without re-rendering the whole world.
var _image: Image
var _texture: ImageTexture
## 16x16 region_key -> "abandoned" | "permanently_abandoned" | "revivable" (Player-Readable Meaning v1). Rebuilt with terrain refresh.
var _player_meaning_region_state: Dictionary = {}
## Off-Main autoloads: coalesce at most one end-of-idle full [refresh_terrain_scar_tint] + [refresh_pawn_historic_path_weights] per [GameManager] tick.
var _off_main_terrain_raster_defer_at_tick: int = -1


func _ready() -> void:
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(TILE_PIXELS, TILE_PIXELS)
	add_to_group("colony_world")
	pathfinder = PathFinder.new()
	generate(randi())


func load_world_data(new_data: WorldData) -> void:
	_off_main_terrain_raster_defer_at_tick = -1
	data = new_data
	pathfinder.rebuild(data)
	_render()
	_bed_tiles.clear()
	_bed_occupants.clear()
	resync_beds_from_map()


func generate(world_seed: int) -> void:
	_off_main_terrain_raster_defer_at_tick = -1
	var t0: int = Time.get_ticks_msec()
	data = WorldGenerator.generate(world_seed)
	var t_gen: int = Time.get_ticks_msec() - t0
	pathfinder.rebuild(data)
	var t_path: int = Time.get_ticks_msec() - t0 - t_gen
	_render()
	# Beds and their occupants don't survive a regen -- the tiles they sit
	# on are gone.
	_bed_tiles.clear()
	_bed_occupants.clear()
	var dt: int = Time.get_ticks_msec() - t0
	if OS.is_debug_build():
		print(
				"[World] Generated seed=%d  %dx%d  gen=%dms path=%dms total=%dms" %
				[world_seed, WorldData.WIDTH, WorldData.HEIGHT, t_gen, t_path, dt]
		)
		_print_distribution()


func _print_distribution() -> void:
	if not OS.is_debug_build():
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
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			_image.set_pixel(x, y, _tile_color(x, y))


func _tile_color(x: int, y: int) -> Color:
	var i: int = data.index(x, y)
	var feature: int = data.features[i]
	var base: Color
	if feature != TileFeature.Type.NONE:
		base = TileFeature.color_for(feature)
		if feature == TileFeature.Type.RUIN:
			# Further desaturate / drain rubble; land-recovery v1: ruin tint still uses max scar, not recovery_stage.
			var g: float = (base.r + base.g + base.b) * 0.33
			base = base.lerp(Color(g, g * 0.95, g * 0.9, 1.0), 0.22)
	else:
		base = Biome.color_for(data.biomes[i])
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
	var rk: int = WorldMemory._region_key(x, y)
	var p: Dictionary = WorldPersistence.get_region_persistence(rk)
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
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var st: String = str(d.get("state", ""))
		if not SettlementMemory.is_collapsed_state(st) and st != "revivable":
			continue
		var reg1: Variant = d.get("regions", null)
		if not (reg1 is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg1 as PackedInt32Array
		for u in range(p.size()):
			_player_meaning_region_state[int(p[u])] = st


## Stacks on scar; deterministic per 16x16 region (settlement state only).
func _apply_player_meaning_tint(c: Color, x: int, y: int) -> Color:
	var rk: int = WorldMemory._region_key(x, y)
	if not _player_meaning_region_state.has(rk):
		return c
	var st: String = str(_player_meaning_region_state.get(rk, ""))
	if st == "abandoned" or st == "permanently_abandoned":
		var yv: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var gray: Color = Color(yv, yv, yv, 1.0)
		c = c.lerp(gray, 0.075)
		return c * Color(0.93, 0.93, 0.9, 1.0)
	if st == "revivable":
		return c.lerp(c * Color(1.04, 1.02, 0.99, 1.0), 0.05)
	return c


## Emergent path wear from [RoadMemory] (traversal). Biome-agnostic tint on top of other layers.
func _apply_road_tint(c: Color, x: int, y: int) -> Color:
	var t: int = RoadMemory.get_traversal(x, y)
	if t < RoadMemory.ROAD_T1:
		return c
	if t < RoadMemory.ROAD_T2:
		return c.lerp(c * Color(1.05, 1.045, 1.04, 1.0), 0.1)
	return c.lerp(c * Color(1.1, 1.08, 1.05, 1.0), 0.16)


## Recurring inter-settlement trade routes from [TradeMemory] (derived; stacks on roads / scar / meaning).
func _apply_trade_route_tint(c: Color, x: int, y: int) -> Color:
	var tr: int = TradeMemory.get_route_tier_at(x, y)
	if tr == TradeMemory.TIER_NONE:
		return c
	if tr == TradeMemory.TIER_ROUTE_1:
		return c.lerp(c * Color(1.06, 1.055, 1.04, 1.0), 0.1)
	return c.lerp(c * Color(1.14, 1.09, 0.97, 1.0), 0.17)


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


## Deterministic ruins (v1): built structures in death-scarred, unoccupied
## regions become static `TileFeature.RUIN` (passable rubble, no use). No RNG.
## Call after `refresh_terrain_scar_tint()`; uses `WorldPersistence` + pawn positions only.
func apply_ruins_from_persistence() -> void:
	if data == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var region_has_pawn: Dictionary = {}
	for node in tree.get_nodes_in_group("pawns"):
		if not is_instance_valid(node) or not (node is Pawn):
			continue
		var p: Pawn = node
		if p.data == null:
			continue
		var tp: Vector2i = p.data.tile_pos
		var rpk: int = WorldMemory._region_key(tp.x, tp.y)
		region_has_pawn[rpk] = true
	var any_change: bool = false
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var f: int = data.get_feature(x, y)
			if f != TileFeature.Type.BED and f != TileFeature.Type.WALL and f != TileFeature.Type.DOOR:
				continue
			var rk: int = WorldMemory._region_key(x, y)
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
	if _image != null:
		_image.set_pixel(x, y, _tile_color(x, y))
		_texture.update(_image)
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
		for node in scene_tree.get_nodes_in_group("pawns"):
			if node is Pawn:
				var p: Pawn = node
				if p.data != null and p.data.tile_pos == here:
					p.evict_to_neighbor_of_tile(here)
					any = true
		if not any:
			break


func notify_pawns_nav_changed() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	for node in scene_tree.get_nodes_in_group("pawns"):
		if node is Pawn:
			(node as Pawn).on_world_nav_changed()


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
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	for _i in range(8):
		var any: bool = false
		for node in scene_tree.get_nodes_in_group("pawns"):
			if node is Pawn:
				var pawn: Pawn = node
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
## by Pawn._decay_needs to grant the bed sleep bonus only to its rightful sleeper.
func is_bed_owned_by(tile: Vector2i, pawn: Pawn) -> bool:
	return _bed_occupants.get(tile, null) == pawn


## Atomically reserve the given bed for `pawn`. Returns false if it's not a
## bed or someone else already holds it. Successful reserve survives the walk
## to the bed and the entire sleep, then must be released.
func reserve_bed(tile: Vector2i, pawn: Pawn) -> bool:
	if not _bed_occupants.has(tile):
		return false
	var current = _bed_occupants[tile]
	if current != null and current != pawn:
		return false
	_bed_occupants[tile] = pawn
	return true


func release_bed(tile: Vector2i, pawn: Pawn) -> void:
	if not _bed_occupants.has(tile):
		return
	if _bed_occupants[tile] == pawn:
		_bed_occupants[tile] = null


## Find the closest unreserved bed reachable from `from_tile` for `pawn`. Closest
## by Chebyshev distance to keep this O(N_beds); reachability uses the connected-
## components map so we never propose a bed across an impassable wall. Returns
## Vector2i(-1,-1) if no bed qualifies.
func find_free_bed_for(pawn: Pawn, from_tile: Vector2i) -> Vector2i:
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
