extends Node
## Consolidated Settlement Manager
## Combines SettlementPlanner, SettlementRebirth, and SettlementArchitect
## This reduces autoload count from 3 to 1 while preserving all functionality

# Child nodes that hold the actual implementation
var _planner: Node
var _rebirth: Node
var _architect: Node

# Autoload references
@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var SettlementMemory = get_node_or_null("/root/SettlementMemory")
@onready var JobManager = get_node_or_null("/root/JobManager")
@onready var CulturalStyleManager = get_node_or_null("/root/CulturalStyleManager")

func _ready() -> void:
	add_to_group("tickable")
	
	# Load the three settlement systems as children
	_planner = load("res://autoloads/SettlementPlanner.gd").new()
	_planner.name = "Planner"
	add_child(_planner)
	
	_rebirth = load("res://autoloads/SettlementRebirth.gd").new()
	_rebirth.name = "Rebirth"
	add_child(_rebirth)
	
	_architect = load("res://autoloads/SettlementArchitect.gd").new()
	_architect.name = "Architect"
	add_child(_architect)
	
	print("[SettlementManager] Initialized with Planner, Rebirth, Architect subsystems")

## Main process method called by tick system
func process(world: World, main: Node2D, from_memory_dirty: bool) -> void:
	if world == null or not is_instance_valid(world) or world.data == null:
		return
	if main == null:
		return
	
	# Run all three subsystems
	_planner.plan(world, main, from_memory_dirty)
	_rebirth.process(world, main, from_memory_dirty)
	_architect.process(world, main)

## Forward planner methods for backward compatibility
func plan(world: World, main: Node2D, from_memory_dirty: bool) -> void:
	_planner.plan(world, main, from_memory_dirty)

## Forward rebirth methods for backward compatibility
func get_rebirth_eligibility(world: World, settlement: Dictionary) -> Dictionary:
	if _rebirth.has_method("get_rebirth_eligibility"):
		return _rebirth.get_rebirth_eligibility(world, settlement)
	return {}

## Forward architect methods for backward compatibility
func process_architect(world: World, main: Node2D) -> void:
	_architect.process(world, main)

## Get culture audio bias for a settlement (delegates to planner if available)
func get_culture_audio_bias_for_settlement(settlement: Dictionary) -> float:
	if _planner != null and _planner.has_method("get_culture_audio_bias_for_settlement"):
		return _planner.get_culture_audio_bias_for_settlement(settlement)
	return 0.0

## Expose planner constants for backward compatibility
const PLANNING_INTERVAL_TICKS: int = 500
const CORE_BOX_R: int = 2
const VILLAGE_SPAN: int = 7
const PERIM_R_OPEN: int = 3
const PERIM_R_DEF: int = 1
const DOOR2_MIN_SPAN_OPEN: int = 7
const DOOR2_MIN_SPAN_DEF: int = 4
const OPEN_VILLAGE_WALL_PAWNS: int = 10
const DEF_VILLAGE_WALL_PAWNS: int = 3
const OPEN_BED2_BEFORE_EXPAND: int = 3
const OPEN_DOOR2_PAWNS: int = 10
const OPEN_DOOR2_BEDS: int = 4
const ZONE_W: int = 3
const ZONE_H: int = 3
const CULTURE_OPEN: int = 0
const CULTURE_CAUTIOUS: int = 1
const CULTURE_DEFENSIVE: int = 2
const PLANNING_REGION_RADIUS: int = 4
const PLANNING_REGION_HARD_CAP: int = 96
const PLANNER_MAX_SETTLEMENTS_PER_PASS: int = 5
const PLANNER_BED_SCAN_CAP: int = 24
const PLANNER_BED_PATH_PROBE_CAP: int = 4
const PLANNER_WALL_SCAN_CAP: int = 256

## Expose rebirth constants for backward compatibility
const CHECK_INTERVAL_TICKS: int = 1000
const REBIRTH_PEACE_TICKS: int = 5000
const REBIRTH_INTERVAL_TICKS: int = 20000
const REBIRTH_SPAWN_BASE_COUNT: int = 2
const REBIRTH_SPAWN_COUNT_VARIANCE: int = 2
const TILE_SCORE_STRUCT_NEIGHBOR: int = 85
const TILE_SCORE_SCAR_WEIGHT: int = 40
const TILE_SCORE_ROAD_WEIGHT: int = 120
const TILE_SCORE_TRADE_WEIGHT: int = 90
const TILE_SCORE_DISTANCE_WEIGHT: int = 1
const TILE_CACHE_REFRESH_TICKS: int = 10000

## Expose architect constants for backward compatibility
const ARCHITECT_INTERVAL_TICKS: int = 5000
