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
	FAMINE       # Food shortage
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
		if randi() % (CATACLYSM_INTERVAL_MAX - CATACLYSM_INTERVAL_MIN) < 100:
			_trigger_random_cataclysm(tick)


# ==================== CATACLYSM TRIGGERING ====================

func _trigger_random_cataclysm(tick: int) -> void:
	var type: int = randi() % 5  # 5 cataclysm types
	var severity: int = randi_range(3, 10)
	
	trigger_cataclysm(type, severity, tick)
	_last_cataclysm_tick = tick


## Trigger a cataclysm
func trigger_cataclysm(type: int, severity: int, tick: int) -> void:
	var config: Dictionary = CATACLYSM_CONFIG.get(type, {})
	if config.is_empty():
		return
	
	# Generate affected regions
	var affected: Array[Vector2i] = _generate_affected_regions(severity)
	
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


func _generate_affected_regions(severity: int) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	var count: int = severity * 5  # More severity = more regions
	
	for i in range(count):
		# Random region coordinates
		var region: Vector2i = Vector2i(randi() % 100, randi() % 100)
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


# ==================== EFFECT APPLICATION ====================

func _apply_plague_effects(regions: Array[Vector2i], severity: int) -> void:
	# Affect pawns in regions
	var casualties: int = 0
	
	if _pawn_spawner != null:
		for pawn in _pawn_spawner.pawns:
			if pawn == null or not is_instance_valid(pawn):
				continue
			
			var tile: Vector2i = pawn.data.get("tile_pos", Vector2i(-1, -1))
			if regions.has(tile):
				# Chance of infection based on severity
				if randf() * 100.0 < severity * 2.0:
					casualties += 1
					# Apply disease to pawn
					if pawn.data.has_method("add_disease"):
						pawn.data.call("add_disease", "plague", severity)
	
	# Update casualties
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.PLAGUE and cataclysm.status == "active":
			cataclysm.casualties += casualties


func _apply_invasion_effects(regions: Array[Vector2i], severity: int) -> void:
	# Spawn enemies in affected regions
	# TODO: Integrate with EnemySpawner
	pass


func _apply_earthquake_effects(regions: Array[Vector2i], severity: int) -> void:
	# Damage buildings in affected regions
	var damage: Dictionary = {"buildings_destroyed": 0, "terrain_changed": 0}
	
	if _settlement_memory != null:
		# Check settlements in affected regions
		for region in regions:
			# Destroy buildings based on severity
			var buildings_destroyed: int = randi_range(0, severity * 2)
			damage.buildings_destroyed += buildings_destroyed
	
	# Update damage
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.EARTHQUAKE and cataclysm.status == "active":
			cataclysm.damage = damage


func _apply_meteor_effects(regions: Array[Vector2i], severity: int) -> void:
	# Massive terrain and building damage
	var damage: Dictionary = {
		"craters_created": 0,
		"buildings_destroyed": 0,
		"fires_started": 0
	}
	
	# Create craters and destruction
	for region in regions:
		damage.craters_created += 1
		damage.buildings_destroyed += randi_range(5, severity * 5)
		damage.fires_started += randi_range(0, severity)
	
	# Update damage
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.METEOR and cataclysm.status == "active":
			cataclysm.damage = damage


func _apply_famine_effects(regions: Array[Vector2i], severity: int) -> void:
	# Destroy food stockpiles
	var food_lost: int = 0
	
	if _settlement_memory != null:
		# Reduce food in affected settlements
		food_lost = severity * 100
	
	# Record food loss
	for cataclysm in active_cataclysms:
		if cataclysm.type == CataclysmType.FAMINE and cataclysm.status == "active":
			cataclysm.damage = {"food_lost": food_lost}


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
