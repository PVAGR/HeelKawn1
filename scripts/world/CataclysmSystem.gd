extends Node
## CataclysmSystem - EVE/Stronghold-style world-shaping events
##
## Features:
## - 5 cataclysm types (Plague, Invasion, Earthquake, Meteor, Famine)
## - World-scale impact
## - Recovery mechanics
## - Historical recording

# Cataclysm types
enum CataclysmType {
	PLAGUE,      # Disease outbreak
	INVASION,    # Enemy forces
	EARTHQUAKE,  # Terrain destruction
	METEOR,      # Impact event
	FAMINE,      # Food shortage
	TORNADO,     # Wind destruction
	VOLCANIC_ERUPTION, # Magma + ash cloud
	TSUNAMI,     # Coastal flooding
}

# Active cataclysm data
## {
##   "cataclysm_id": int,
##   "type": int,  # CataclysmType enum
##   "severity": int,  # 1-10
##   "affected_regions": Array[Vector2i],
##   "start_tick": int,
##   "duration_ticks": int,
##   "casualties": int,
##   "damage": Dictionary,
##   "recovery_progress": float,  # 0-100
##   "status": String  # "active", "recovering", "ended"
## }
var active_cataclysms: Array[Dictionary] = []
var _next_cataclysm_id: int = 1

# Cataclysm configuration
const CATACLYSM_CONFIG: Dictionary = {
	CataclysmType.PLAGUE: {
		"name": "Plague",
		"base_duration": 5000,
		"casualty_rate": 0.1,
		"recovery_rate": 0.5
	},
	CataclysmType.INVASION: {
		"name": "Invasion",
		"base_duration": 3000,
		"casualty_rate": 0.2,
		"recovery_rate": 0.3
	},
	CataclysmType.EARTHQUAKE: {
		"name": "Earthquake",
		"base_duration": 2000,
		"casualty_rate": 0.05,
		"recovery_rate": 0.2
	},
	CataclysmType.METEOR: {
		"name": "Meteor Impact",
		"base_duration": 10000,
		"casualty_rate": 0.3,
		"recovery_rate": 0.1
	},
	CataclysmType.FAMINE: {
		"name": "Great Famine",
		"base_duration": 8000,
		"casualty_rate": 0.15,
		"recovery_rate": 0.4
	},
	CataclysmType.TORNADO: {
		"name": "Tornado",
		"base_duration": 200,
		"casualty_rate": 0.08,
		"recovery_rate": 1.0
	},
	CataclysmType.VOLCANIC_ERUPTION: {
		"name": "Volcanic Eruption",
		"base_duration": 4000,
		"casualty_rate": 0.25,
		"recovery_rate": 0.15
	},
	CataclysmType.TSUNAMI: {
		"name": "Tsunami",
		"base_duration": 1000,
		"casualty_rate": 0.2,
		"recovery_rate": 0.5
	}
}

# Configuration
const CATACLYSM_INTERVAL_MIN: int = 10000  # Min ticks between cataclysms
const CATACLYSM_INTERVAL_MAX: int = 50000  # Max ticks between cataclysms
var _last_cataclysm_tick: int = 0

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


func _on_game_tick(tick: int) -> void:
	# Update active cataclysms
	_update_cataclysms(tick)
	
	# Check for new cataclysms
	if tick - _last_cataclysm_tick > CATACLYSM_INTERVAL_MIN:
		var interval_span: int = maxi(CATACLYSM_INTERVAL_MAX - CATACLYSM_INTERVAL_MIN, 1)
		var roll: int = _deterministic_index(&"cataclysm:interval", interval_span, tick + _last_cataclysm_tick + _next_cataclysm_id)
		if roll < 100:
			_trigger_random_cataclysm(tick)


# ==================== CATACLYSM TRIGGERING ====================

func _trigger_random_cataclysm(tick: int) -> void:
	var type: int = _deterministic_index(&"cataclysm:type", 5, tick + _next_cataclysm_id)  # 5 cataclysm types
	var severity: int = _deterministic_rangei(&"cataclysm:severity", 3, 10, tick + _next_cataclysm_id * 17)
	
	trigger_cataclysm(type, severity, tick)
	_last_cataclysm_tick = tick


## Trigger a cataclysm
func trigger_cataclysm(type: int, severity: int, tick: int) -> void:
	var config: Dictionary = CATACLYSM_CONFIG.get(type, {})
	if config.is_empty():
		return
	
	# Generate affected regions
	var affected: Array[Vector2i] = _generate_affected_regions(severity, tick)
	
	# Create cataclysm data
	var cataclysm: Dictionary = {
		"cataclysm_id": _next_cataclysm_id,
		"type": type,
		"severity": severity,
		"affected_regions": affected,
		"start_tick": tick,
		"duration_ticks": config.base_duration * (severity / 5.0),
		"casualties": 0,
		"damage": {},
		"recovery_progress": 0.0,
		"status": "active"
	}
	
	active_cataclysms.append(cataclysm)
	_next_cataclysm_id += 1
	
	# Apply immediate effects
	_apply_cataclysm_effects(cataclysm)
	
	# Record event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "cataclysm_started",
			"cataclysm_id": cataclysm.cataclysm_id,
			"name": config.get("name", "Unknown"),
			"severity": severity,
			"affected_regions": affected.size(),
			"tick": tick
		})


func _generate_affected_regions(severity: int, tick: int) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	var count: int = severity * 5  # More severity = more regions
	
	for i in range(count):
		# Deterministic region coordinates from seed + tick + index.
		var rx: int = _deterministic_index(&"cataclysm:region_x", 100, tick + severity * 31 + i * 7 + _next_cataclysm_id * 13)
		var ry: int = _deterministic_index(&"cataclysm:region_y", 100, tick + severity * 53 + i * 11 + _next_cataclysm_id * 17)
		var region: Vector2i = Vector2i(rx, ry)
		if not affected.has(region):
			affected.append(region)
	
	return affected


func _apply_cataclysm_effects(cataclysm: Dictionary) -> void:
	var type: int = cataclysm.type
	var severity: int = cataclysm.severity
	var affected: Array[Vector2i] = cataclysm.affected_regions
	
	# Apply effects based on type
	match type:
		CataclysmType.PLAGUE:
			_apply_plague_effects(affected, severity)
		CataclysmType.INVASION:
			_apply_invasion_effects(affected, severity)
		CataclysmType.EARTHQUAKE:
			_apply_earthquake_effects(affected, severity)
		CataclysmType.METEOR:
			_apply_meteor_effects(affected, severity)
		CataclysmType.FAMINE:
			_apply_famine_effects(affected, severity)
		CataclysmType.TORNADO:
			_apply_tornado_effects(affected, severity)
		CataclysmType.VOLCANIC_ERUPTION:
			_apply_volcanic_effects(affected, severity)
		CataclysmType.TSUNAMI:
			_apply_tsunami_effects(affected, severity)


# ==================== EFFECT APPLICATION ====================

func _apply_plague_effects(regions: Array[Vector2i], severity: int) -> void:
	# Affect pawns in regions
	var casualties: int = 0

	if _pawn_spawner != null:
		for pawn in _pawn_spawner.pawns:
			if pawn == null or not is_instance_valid(pawn):
				continue

			# Safe access for HeelKawnianData (RefCounted, not Dictionary)
			var tile: Vector2i = Vector2i(-1, -1)
			if pawn.data != null:
				if pawn.data.has_method("get"):
					tile = pawn.data.call("get", "tile_pos")
					if tile == null:
						tile = Vector2i(-1, -1)
				elif "tile_pos" in pawn.data:
					tile = pawn.data.tile_pos
			
			if regions.has(tile):
				# Deterministic chance of infection based on severity and pawn_id
				var pawn_id: int = int(pawn.data.id) if pawn.data != null else 0
				var hash_val: int = absi(str(pawn_id).hash() ^ str(GameManager.tick_count).hash())
				if (hash_val % 1000) < int(severity * 2.0 * 10.0):  # severity * 2.0 is percentage
					casualties += 1
					# Apply disease to pawn
					if DiseaseSystem != null:
						DiseaseSystem.add_disease(pawn.data, DiseaseSystem.DiseaseType.PLAGUE, float(severity), "cataclysm")

	# Update casualties
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.PLAGUE and cataclysm.status == "active":
			cataclysm.casualties += casualties


func _apply_invasion_effects(regions: Array[Vector2i], severity: int) -> void:
	# Spawn enemies in affected regions via EnemySpawner
	var es := get_node_or_null("/root/Main/WorldViewport/EnemySpawner") as Node
	var world := get_node_or_null("/root/Main/WorldViewport/World") as Node
	if es == null or world == null:
		return
	if es.has_method("spawn_war_forces"):
		var strength: float = float(severity) * 40.0
		es.spawn_war_forces(world, -1, -1, strength)
	# Alternatively spawn multiple raids if EnemySpawner has multiple-capability
	if regions.size() > 3 and es.has_method("spawn_raid"):
		for i in range(mini(severity / 3, 3)):
			es.spawn_raid(world)


func _apply_earthquake_effects(regions: Array[Vector2i], severity: int) -> void:
	# Damage buildings and terrain in affected regions
	var damage: Dictionary = {"buildings_destroyed": 0, "terrain_changed": 0}
	var world_data := _get_world_data()
	
	if _settlement_memory != null:
		for region in regions:
			var rx: int = region.x
			var ry: int = region.y
			var salt: int = int(rx) * 73856093 ^ int(ry) * 19349663 ^ severity * 83492791
			var buildings_destroyed: int = _deterministic_rangei(&"cataclysm:earthquake:destroy", 0, severity * 2, salt)
			damage.buildings_destroyed += buildings_destroyed
			# Shake: randomly change a subset of tiles to rocky terrain
			if world_data != null and world_data.in_bounds(rx, ry):
				var tile_count: int = _deterministic_rangei(&"cataclysm:earthquake:tiles", 1, severity * 3, salt + 101)
				for t in range(tile_count):
					var tx: int = clampi(rx + (t * 7 + salt) % 5 - 2, 0, 99)
					var ty: int = clampi(ry + (t * 13 + salt) % 5 - 2, 0, 99)
					if world_data.in_bounds(tx, ty):
						world_data.set_biome(tx, ty, 1)  # Rocky terrain
						damage.terrain_changed += 1
	
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.EARTHQUAKE and cataclysm.status == "active":
			cataclysm.damage = damage


func _get_world_data():
	var w := get_node_or_null("/root/Main/WorldViewport/World")
	if w != null and w.has_method("get_data"):
		return w.get_data()
	if w != null:
		return w.data
	return null


func _apply_meteor_effects(regions: Array[Vector2i], severity: int) -> void:
	# Massive terrain and building damage
	var damage: Dictionary = {
		"craters_created": 0,
		"buildings_destroyed": 0,
		"fires_started": 0
	}
	var world_data := _get_world_data()
	var ecology := get_node_or_null("/root/EcologySystem")
	
	for region in regions:
		var rx: int = region.x
		var ry: int = region.y
		var salt: int = int(rx) * 92311 ^ int(ry) * 68917 ^ severity * 29791
		damage.craters_created += 1
		damage.buildings_destroyed += _deterministic_rangei(&"cataclysm:meteor:destroy", 5, maxi(5, severity * 5), salt + 101)
		damage.fires_started += _deterministic_rangei(&"cataclysm:meteor:fire", 0, maxi(0, severity), salt + 211)
		# Carve impact crater in terrain
		if world_data != null:
			var radius: int = clampi(severity / 3, 1, 5)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var tx: int = clampi(rx + dx, 0, 99)
					var ty: int = clampi(ry + dy, 0, 99)
					if world_data.in_bounds(tx, ty):
						world_data.set_biome(tx, ty, 2)  # Barren/crater
		# Start fires
		if ecology != null and ecology.has_method("start_fire_at"):
			for f in range(damage.fires_started):
				var fx: int = clampi(rx + (f * 11 + salt) % 10 - 5, 0, 99)
				var fy: int = clampi(ry + (f * 17 + salt) % 10 - 5, 0, 99)
				ecology.start_fire_at(fx, fy, minf(1.0 + float(severity) * 0.2, 5.0))
	
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.METEOR and cataclysm.status == "active":
			cataclysm.damage = damage


func _apply_famine_effects(regions: Array[Vector2i], severity: int) -> void:
	# Destroy food stockpiles
	var food_lost: int = 0
	var sm := get_node_or_null("/root/StockpileManager")
	if sm != null and sm.has_method("zones"):
		for z in sm.zones():
			if z == null or not is_instance_valid(z):
				continue
			if not (z.has_method("inventory") or "inventory" in z):
				continue
			var zt: Vector2i = z.tile if z.has_method("get_tile") else (z.tile if "tile" in z else Vector2i(-1, -1))
			if zt.x < 0:
				continue
			if not _region_in_list(zt, regions):
				continue
			var inv := z.inventory if "inventory" in z else {}
			for item_type in inv.keys():
				var qty: int = int(inv[item_type])
				if qty > 0 and Item.is_food(int(item_type)):
					var remove_qty: int = mini(qty, severity * 5)
					if z.has_method("remove_item"):
						z.remove_item(int(item_type), remove_qty)
					else:
						inv[int(item_type)] = qty - remove_qty
					food_lost += remove_qty
	
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.FAMINE and cataclysm.status == "active":
			cataclysm.damage = {"food_lost": food_lost}


func _region_in_list(tile: Vector2i, regions: Array[Vector2i]) -> bool:
	for r in regions:
		if abs(r.x - tile.x) <= 2 and abs(r.y - tile.y) <= 2:
			return true
	return false


func _apply_tornado_effects(regions: Array[Vector2i], severity: int) -> void:
	# Tornado: narrow path of destruction, mostly buildings, some terrain
	var damage: Dictionary = {"buildings_destroyed": 0, "trees_uprooted": 0}
	var world_data := _get_world_data()
	if _settlement_memory != null:
		for region in regions:
			var salt: int = int(region.x) * 31337 ^ int(region.y) * 53113 ^ severity * 7919
			var destroyed: int = _deterministic_rangei(&"cataclysm:tornado:destroy", 1, severity * 3, salt)
			damage.buildings_destroyed += destroyed
			if world_data != null and world_data.in_bounds(region.x, region.y):
				for t in range(destroyed * 2):
					var tx: int = clampi(region.x + (t * 5 + salt) % 7 - 3, 0, 99)
					var ty: int = clampi(region.y + (t * 11 + salt) % 7 - 3, 0, 99)
					if world_data.in_bounds(tx, ty):
						var biome: int = world_data.get_biome(tx, ty)
						if biome == 3:  # Forest
							world_data.set_biome(tx, ty, 0)  # Clear
							damage.trees_uprooted += 1
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.TORNADO and cataclysm.status == "active":
			cataclysm.damage = damage


func _apply_volcanic_effects(regions: Array[Vector2i], severity: int) -> void:
	# Volcanic eruption: ash clouds, lava flows, destroys nearby settlements
	var damage: Dictionary = {"settlements_destroyed": 0, "tiles_covered": 0, "casualties": 0}
	var world_data := _get_world_data()
	if _settlement_memory != null:
		for region in regions:
			var salt: int = int(region.x) * 19531 ^ int(region.y) * 27917 ^ severity * 32323
			var radius: int = clampi(severity / 2, 1, 4)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var tx: int = clampi(region.x + dx, 0, 99)
					var ty: int = clampi(region.y + dy, 0, 99)
					if world_data != null and world_data.in_bounds(tx, ty):
						world_data.set_biome(tx, ty, 5)  # Ash/wasteland
						damage.tiles_covered += 1
			var destroyed: int = _deterministic_rangei(&"cataclysm:volcano:destroy", 0, severity * 2, salt + 51)
			damage.settlements_destroyed += destroyed
			if _pawn_spawner != null:
				for pawn in _pawn_spawner.pawns:
					if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
						continue
					var pt: Vector2i = pawn.data.tile_pos if "tile_pos" in pawn.data else Vector2i(-1, -1)
					if pt.x < 0:
						continue
					for r in regions:
						if abs(r.x - pt.x) <= radius + 1 and abs(r.y - pt.y) <= radius + 1:
							damage.casualties += 1
							pawn.data.health = 0.0
							break
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.VOLCANIC_ERUPTION and cataclysm.status == "active":
			cataclysm.damage = damage


func _apply_tsunami_effects(regions: Array[Vector2i], severity: int) -> void:
	# Tsunami: coastal flooding, destroys coastal buildings
	var damage: Dictionary = {"coastal_tiles_flooded": 0, "buildings_destroyed": 0, "casualties": 0}
	var world_data := _get_world_data()
	if _settlement_memory != null:
		for region in regions:
			var salt: int = int(region.x) * 65537 ^ int(region.y) * 257 ^ severity * 7919
			var flooded: int = _deterministic_rangei(&"cataclysm:tsunami:flood", severity * 2, severity * 8, salt)
			# Convert coastal tiles to water (assume water biome is 4)
			if world_data != null:
				for f in range(flooded):
					var tx: int = clampi(region.x + (f * 3 + salt) % 6 - 3, 0, 99)
					var ty: int = clampi(region.y + (f * 7 + salt) % 6 - 3, 0, 99)
					if world_data.in_bounds(tx, ty):
						var biome: int = world_data.get_biome(tx, ty)
						if biome != 4:  # Not already water
							world_data.set_biome(tx, ty, 4)  # Flood to water
							damage.coastal_tiles_flooded += 1
			var destroyed: int = _deterministic_rangei(&"cataclysm:tsunami:destroy", 0, severity * 2, salt + 17)
			damage.buildings_destroyed += destroyed
			# Pawn casualties in coastal areas
			if _pawn_spawner != null:
				for pawn in _pawn_spawner.pawns:
					if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
						continue
					var pt: Vector2i = pawn.data.tile_pos if "tile_pos" in pawn.data else Vector2i(-1, -1)
					if pt.x < 0:
						continue
					for r in regions:
						if abs(r.x - pt.x) <= 1 and abs(r.y - pt.y) <= 1:
							damage.casualties += 1
							pawn.data.health = 0.0
							break
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.TSUNAMI and cataclysm.status == "active":
			cataclysm.damage = damage


# ==================== CATACLYSM UPDATES ====================

func _update_cataclysms(tick: int) -> void:
	for i in range(active_cataclysms.size() - 1, -1, -1):
		var cataclysm: Dictionary = active_cataclysms[i]
		
		if cataclysm.status == "active":
			# Check if duration ended
			var elapsed: int = tick - cataclysm.start_tick
			if elapsed >= cataclysm.duration_ticks:
				cataclysm.status = "recovering"
				
				# Record end
				if _world_memory != null:
					_world_memory.record_event({
						"type": "cataclysm_ended",
						"cataclysm_id": cataclysm.cataclysm_id,
						"casualties": cataclysm.casualties,
						"tick": tick
					})
		
		elif cataclysm.status == "recovering":
			# Recovery progress
			var config: Dictionary = CATACLYSM_CONFIG.get(cataclysm.type, {})
			var recovery_rate: float = config.get("recovery_rate", 0.5)
			
			cataclysm.recovery_progress += recovery_rate
			
			if cataclysm.recovery_progress >= 100.0:
				cataclysm.status = "ended"
				active_cataclysms.remove_at(i)


# ==================== PUBLIC API ====================

## Get active cataclysms
func get_active_cataclysms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cataclysm in active_cataclysms:
		if cataclysm.status == "active" or cataclysm.status == "recovering":
			result.append(cataclysm.duplicate())
	return result

## Get cataclysm by ID
func get_cataclysm(cataclysm_id: int) -> Dictionary:
	for cataclysm in active_cataclysms:
		if cataclysm.cataclysm_id == cataclysm_id:
			return cataclysm.duplicate()
	return {}

## Check if region is affected
func is_region_affected(region: Vector2i) -> bool:
	for cataclysm in active_cataclysms:
		if cataclysm.status == "active" and cataclysm.affected_regions.has(region):
			return true
	return false

## Get cataclysm severity in region
func get_cataclysm_severity(region: Vector2i) -> int:
	for cataclysm in active_cataclysms:
		if cataclysm.status == "active" and cataclysm.affected_regions.has(region):
			return cataclysm.severity
	return 0

## Clear all cataclysms (for world reroll)
func clear() -> void:
	active_cataclysms.clear()
	_next_cataclysm_id = 1
	_last_cataclysm_tick = 0

## Get statistics
func get_stats() -> Dictionary:
	var active: int = 0
	var recovering: int = 0
	var total_casualties: int = 0
	
	for cataclysm in active_cataclysms:
		if cataclysm.status == "active":
			active += 1
		elif cataclysm.status == "recovering":
			recovering += 1
		total_casualties += cataclysm.casualties
	
	return {
		"active_cataclysms": active,
		"recovering": recovering,
		"total_casualties": total_casualties,
		"last_cataclysm_tick": _last_cataclysm_tick
	}


func _deterministic_rangei(stream: StringName, min_value: int, max_value: int, salt: int) -> int:
	if WorldRNG != null:
		return int(WorldRNG.rangei(min_value, max_value, salt, stream))
	var lo: int = mini(min_value, max_value)
	var hi: int = maxi(min_value, max_value)
	if hi <= lo:
		return lo
	var seed: int = int(str(stream).hash() ^ salt ^ (GameManager.tick_count if GameManager != null else 0))
	return lo + (absi(seed) % (hi - lo + 1))


func _deterministic_index(stream: StringName, size: int, salt: int) -> int:
	if size <= 0:
		return -1
	if WorldRNG != null:
		return int(WorldRNG.index_for(stream, size, salt))
	var seed: int = int(str(stream).hash() ^ salt ^ (GameManager.tick_count if GameManager != null else 0))
	return absi(seed) % size
