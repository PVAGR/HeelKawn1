extends Node
class_name EconomyManager
## Consolidated Economy Manager
## Combines trade and economy systems into one autoload
## Reduces autoload count while preserving economy functionality

# Child nodes for economy subsystems (loaded on-demand)
var _trade_planner: Node
var _trade_memory: Node
var _food_chain_manager: Node
var _tool_manager: Node

var _trade_planner_loaded: bool = false
var _trade_memory_loaded: bool = false
var _food_chain_loaded: bool = false
var _tool_manager_loaded: bool = false

func _ready() -> void:
	pass

func _load_sub(name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + name)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null

func _ensure_trade_planner() -> void:
	if not _trade_planner_loaded:
		_trade_planner = _load_sub("TradePlanner", "res://autoloads/TradePlanner.gd")
		_trade_planner_loaded = true

func _ensure_trade_memory() -> void:
	if not _trade_memory_loaded:
		_trade_memory = _load_sub("TradeMemory", "res://autoloads/TradeMemory.gd")
		_trade_memory_loaded = true

func _ensure_food_chain() -> void:
	if not _food_chain_loaded:
		_food_chain_manager = _load_sub("FoodChainManager", "res://autoloads/FoodChainManager.gd")
		_food_chain_loaded = true

func _ensure_tool_manager() -> void:
	if not _tool_manager_loaded:
		_tool_manager = _load_sub("ToolManager", "res://autoloads/ToolManager.gd")
		_tool_manager_loaded = true

## Get a specific economy subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"trade_planner": _ensure_trade_planner(); return _trade_planner
		"trade_memory": _ensure_trade_memory(); return _trade_memory
		"food_chain_manager": _ensure_food_chain(); return _food_chain_manager
		"tool_manager": _ensure_tool_manager(); return _tool_manager
		_: return null

## Plan trade route (delegates to TradePlanner if available)
func plan_trade(settlement_id: int, target_settlement_id: int) -> void:
	_ensure_trade_planner()
	if _trade_planner != null and _trade_planner.has_method("plan_trade"):
		_trade_planner.plan_trade(settlement_id, target_settlement_id)

## Record trade (delegates to TradeMemory if available)
func record_trade(from_settlement: int, to_settlement: int, goods: Dictionary) -> void:
	_ensure_trade_memory()
	if _trade_memory != null and _trade_memory.has_method("record_trade"):
		_trade_memory.record_trade(from_settlement, to_settlement, goods)

## Update food chain (delegates to FoodChainManager if available)
func update_food_chain(world: World) -> void:
	_ensure_food_chain()
	if _food_chain_manager != null and _food_chain_manager.has_method("update"):
		_food_chain_manager.update(world)

## Forward getters for subsystems
func get_trade_planner() -> Node:
	return get_subsystem("trade_planner")

static func get_trade_memory() -> Node:
	var inst: EconomyManager = Engine.get_singleton("EconomyManager") as EconomyManager
	if inst == null:
		return null
	return inst.get_subsystem("trade_memory")

func get_food_chain_manager() -> Node:
	return get_subsystem("food_chain_manager")

func get_tool_manager() -> Node:
	return get_subsystem("tool_manager")
