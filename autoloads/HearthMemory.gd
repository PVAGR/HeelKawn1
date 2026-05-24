extends Node
## HearthMemory & Inner Fire: settlement formation from repeated activity.
##
## This works exactly like RoadMemory but for civilization infrastructure:
## - Roads: repeated movement → T1/T2 roads
## - Hearth: repeated deposits → pile → stockpile → settlement
##
## All deterministic, no RNG, purely from accumulated pawn behavior.
##
## Inner Fire drives are tile-based pressure values that create job biases
## in the HeelKawnian Matrix AI:
## - hearth_spark: proximity to fire, warmth pressure, pawn clustering
## - storage_pressure: items carried with no drop zone, ground item accumulation
## - shelter_pressure: tired pawns with no bed, night time, cold
## - survival_pressure: hunger, health, danger

const PILE_T1: int = 3
const PILE_T2: int = 8
const PILE_FORMAL: int = 15
const HEARTH_T1: int = 5
const HEARTH_T2: int = 12
const ACTIVITY_DECAY_TICKS: int = 20000
const MAX_PATCH_PER_FLUSH: int = 128

var _pile_trav: PackedInt32Array = PackedInt32Array()
var _hearth_trav: PackedInt32Array = PackedInt32Array()
var _shelter_trav: PackedInt32Array = PackedInt32Array()
var _dirty_tiles: PackedInt32Array = PackedInt32Array()
var _ready_connected: bool = false
var _formal_pile_regions: Dictionary = {}

static func _get_instance() -> HearthMemory:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop as SceneTree
		var inst_v: Variant = tree.get_root().get_node_or_null("HearthMemory")
		if inst_v is HearthMemory:
			return inst_v as HearthMemory
	return null


func _ready() -> void:
	if not _ready_connected:
		_ready_connected = true
		if GameManager != null:
			GameManager.game_tick.connect(_on_game_tick)
	_ensure_size()


func clear() -> void:
	_ensure_size()
	for i3 in range(WorldData.TILE_COUNT):
		_pile_trav[i3] = 0
		_hearth_trav[i3] = 0
		_shelter_trav[i3] = 0
	_dirty_tiles.clear()
	_formal_pile_regions.clear()


func _ensure_size() -> void:
	if _pile_trav.size() != WorldData.TILE_COUNT:
		_pile_trav.resize(WorldData.TILE_COUNT)
		_hearth_trav.resize(WorldData.TILE_COUNT)
		_shelter_trav.resize(WorldData.TILE_COUNT)
		for i0 in range(WorldData.TILE_COUNT):
			_pile_trav[i0] = 0
			_hearth_trav[i0] = 0
			_shelter_trav[i0] = 0


static func record_pile_deposit(tile: Vector2i, item_type: int) -> void:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return
	inst._record_pile_impl(tile, item_type)


func _record_pile_impl(tile: Vector2i, item_type: int) -> void:
	_ensure_size()
	if tile.x < 0 or tile.y < 0 or tile.x >= WorldData.WIDTH or tile.y >= WorldData.HEIGHT:
		return
	var idx: int = tile.y * WorldData.WIDTH + tile.x
	if idx < 0 or idx >= _pile_trav.size():
		return
	_pile_trav[idx] = _pile_trav[idx] + 1
	_pile_trav[idx] = mini(_pile_trav[idx], PILE_FORMAL + 20)
	_dirty_tiles.append(idx)
	
	if _pile_trav[idx] >= PILE_T1:
		var rk: int = WorldMemory._region_key(tile.x, tile.y)
		if not _formal_pile_regions.has(rk):
			_formal_pile_regions[rk] = {"first_pile_tile": idx, "since_tick": _tick()}
		if DiscoveryGate != null:
			DiscoveryGate.unlock("first_pile")
	
	if _pile_trav[idx] >= PILE_FORMAL:
		if DiscoveryGate != null:
			DiscoveryGate.unlock("first_formal_stockpile")


static func record_hearth_activity(tile: Vector2i) -> void:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return
	inst._record_hearth_impl(tile)


func _record_hearth_impl(tile: Vector2i) -> void:
	_ensure_size()
	if tile.x < 0 or tile.y < 0 or tile.x >= WorldData.WIDTH or tile.y >= WorldData.HEIGHT:
		return
	var idx: int = tile.y * WorldData.WIDTH + tile.x
	if idx < 0 or idx >= _hearth_trav.size():
		return
	_hearth_trav[idx] = _hearth_trav[idx] + 1
	_hearth_trav[idx] = mini(_hearth_trav[idx], HEARTH_T2 + 20)
	_dirty_tiles.append(idx)
	
	if _hearth_trav[idx] >= HEARTH_T1:
		if DiscoveryGate != null:
			DiscoveryGate.unlock("first_hearth_cluster")


static func record_shelter_usage(tile: Vector2i) -> void:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return
	inst._record_shelter_impl(tile)


func _record_shelter_impl(tile: Vector2i) -> void:
	_ensure_size()
	if tile.x < 0 or tile.y < 0 or tile.x >= WorldData.WIDTH or tile.y >= WorldData.HEIGHT:
		return
	var idx: int = tile.y * WorldData.WIDTH + tile.x
	if idx < 0 or idx >= _shelter_trav.size():
		return
	_shelter_trav[idx] = _shelter_trav[idx] + 1
	_shelter_trav[idx] = mini(_shelter_trav[idx], 30)
	_dirty_tiles.append(idx)


static func get_pile_level(x: int, y: int) -> int:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return 0
	return inst._get_pile_level_impl(x, y)


func _get_pile_level_impl(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return 0
	if _pile_trav.size() != WorldData.TILE_COUNT:
		return 0
	var t: int = int(_pile_trav[y * WorldData.WIDTH + x])
	if t >= PILE_FORMAL:
		return 3
	if t >= PILE_T2:
		return 2
	if t >= PILE_T1:
		return 1
	return 0


static func get_hearth_level(x: int, y: int) -> int:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return 0
	return inst._get_hearth_level_impl(x, y)


func _get_hearth_level_impl(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return 0
	if _hearth_trav.size() != WorldData.TILE_COUNT:
		return 0
	var t: int = int(_hearth_trav[y * WorldData.WIDTH + x])
	if t >= HEARTH_T2:
		return 2
	if t >= HEARTH_T1:
		return 1
	return 0


static func get_pile_pressure(x: int, y: int, radius: int = 3) -> float:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return 0.0
	return inst._get_pile_pressure_impl(x, y, radius)


func _get_pile_pressure_impl(x: int, y: int, radius: int) -> float:
	_ensure_size()
	var max_p: int = 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tx: int = x + dx
			var ty: int = y + dy
			if tx < 0 or ty < 0 or tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
				continue
			var idx: int = ty * WorldData.WIDTH + tx
			if idx >= 0 and idx < _pile_trav.size():
				max_p = maxi(max_p, int(_pile_trav[idx]))
	return clampf(float(max_p) / float(PILE_FORMAL), 0.0, 1.0)


static func get_hearth_pressure(x: int, y: int, radius: int = 5) -> float:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return 0.0
	return inst._get_hearth_pressure_impl(x, y, radius)


func _get_hearth_pressure_impl(x: int, y: int, radius: int) -> float:
	_ensure_size()
	var max_h: int = 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tx: int = x + dx
			var ty: int = y + dy
			if tx < 0 or ty < 0 or tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
				continue
			var idx: int = ty * WorldData.WIDTH + tx
			if idx >= 0 and idx < _hearth_trav.size():
				max_h = maxi(max_h, int(_hearth_trav[idx]))
	return clampf(float(max_h) / float(HEARTH_T2), 0.0, 1.0)


static func should_create_temp_pile(tile: Vector2i) -> bool:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return false
	return inst._should_create_temp_pile_impl(tile)


func _should_create_temp_pile_impl(tile: Vector2i) -> bool:
	var level: int = _get_pile_level_impl(tile.x, tile.y)
	return level >= 1


static func should_formalize_pile(tile: Vector2i) -> bool:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return false
	return inst._should_formalize_pile_impl(tile)


func _should_formalize_pile_impl(tile: Vector2i) -> bool:
	var level: int = _get_pile_level_impl(tile.x, tile.y)
	return level >= 3


static func get_inner_fire_for_pawn(tile: Vector2i, data: HeelKawnianData = null) -> Dictionary:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return {}
	return inst._get_inner_fire_impl(tile, data)


func _get_inner_fire_impl(tile: Vector2i, data: HeelKawnianData) -> Dictionary:
	_ensure_size()
	
	var hearth_press: float = _get_hearth_pressure_impl(tile.x, tile.y, 5)
	var pile_press: float = _get_pile_pressure_impl(tile.x, tile.y, 3)
	
	var is_carrying: bool = data != null and data.is_carrying()
	var is_night: bool = DayNightCycle.is_night_for_tick(_tick()) if DayNightCycle != null else false
	
	var hunger: float = data.hunger if data != null else 50.0
	var rest: float = data.rest if data != null else 50.0
	var health: float = data.health if data != null else 100.0
	
	var survival_drive: float = clampf((100.0 - hunger) / 50.0, 0.0, 1.0)
	if health < 50.0:
		survival_drive = maxf(survival_drive, clampf((50.0 - health) / 25.0, 0.0, 1.0))
	
	var hearth_drive: float = 0.0
	if is_night:
		hearth_drive += 0.3
	hearth_drive += (1.0 - hearth_press) * 0.5
	if data != null:
		var rk: int = WorldMemory._region_key(data.tile_pos.x, data.tile_pos.y)
		var warmth_press: float = ColonySimServices.get_warmth_pressure(rk) if ColonySimServices != null else 0.0
		hearth_drive += warmth_press * 0.5
	hearth_drive = clampf(hearth_drive, 0.0, 1.0)
	
	var storage_drive: float = 0.0
	if is_carrying:
		storage_drive += 0.6
	storage_drive += pile_press * 0.3
	storage_drive = clampf(storage_drive, 0.0, 1.0)
	
	var shelter_drive: float = 0.0
	if rest < 30.0:
		shelter_drive += clampf((30.0 - rest) / 15.0, 0.0, 1.0)
	if is_night and hearth_press < 0.3:
		shelter_drive += 0.3
	shelter_drive = clampf(shelter_drive, 0.0, 1.0)
	
	return {
		"survival_drive": survival_drive,
		"hearth_drive": hearth_drive,
		"storage_drive": storage_drive,
		"shelter_drive": shelter_drive,
		"hearth_pressure": hearth_press,
		"pile_pressure": pile_press,
	}


func _tick() -> int:
	return GameManager.tick_count if GameManager != null else 0


func _on_game_tick(tick: int) -> void:
	_ensure_size()
	if (int(tick) % ACTIVITY_DECAY_TICKS) != 0:
		return
	_decay_step()
	var tree0: SceneTree = get_tree()
	if tree0 == null:
		return
	var wn2: Node = tree0.get_first_node_in_group("colony_world")
	if wn2 != null and is_instance_valid(wn2) and (wn2 is World):
		flush_dirty_tiles(wn2 as World)


func _decay_step() -> void:
	var any_changed: bool = false
	for i2 in range(WorldData.TILE_COUNT):
		if _pile_trav[i2] > 0:
			_pile_trav[i2] = maxi(0, _pile_trav[i2] - 1)
			any_changed = true
		if _hearth_trav[i2] > 0:
			_hearth_trav[i2] = maxi(0, _hearth_trav[i2] - 1)
			any_changed = true
		if _shelter_trav[i2] > 0:
			_shelter_trav[i2] = maxi(0, _shelter_trav[i2] - 1)
			any_changed = true
	
	if any_changed:
		var tree0: SceneTree = get_tree()
		if tree0 == null:
			return
		var wn: Node = tree0.get_first_node_in_group("colony_world")
		if wn != null and is_instance_valid(wn) and (wn is World):
			var w0: World = wn as World
			w0.refresh_pawn_historic_path_weights()


func flush_dirty_tiles(world: World) -> void:
	if _dirty_tiles.is_empty() or world == null or not is_instance_valid(world):
		return
	if _dirty_tiles.is_empty():
		return
	var n1: int = mini(MAX_PATCH_PER_FLUSH, _dirty_tiles.size())
	_dirty_tiles = _dirty_tiles.slice(n1, _dirty_tiles.size())


static func get_regions_with_formal_piles() -> Dictionary:
	var inst: HearthMemory = _get_instance()
	if inst == null:
		return {}
	return inst._formal_pile_regions.duplicate()
