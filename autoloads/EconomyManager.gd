extends Node
## Consolidated Economy Manager
## Combines trade and economy systems into one autoload
## Reduces autoload count while preserving economy functionality

# Child nodes for economy subsystems (loaded on-demand)
var _trade_planner: Node
var _trade_memory: Node
var _food_chain_manager: Node
var _tool_manager: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	_trade_planner = get_node_or_null("/root/TradePlanner")
	_trade_memory = get_node_or_null("/root/TradeMemory")
	_food_chain_manager = get_node_or_null("/root/FoodChainManager")
	_tool_manager = get_node_or_null("/root/ToolManager")
	
	if _trade_planner == null and FileAccess.file_exists("res://autoloads/TradePlanner.gd"):
		_trade_planner = load("res://autoloads/TradePlanner.gd").new()
		_trade_planner.name = "TradePlanner"
		add_child(_trade_planner)
	if _trade_memory == null and FileAccess.file_exists("res://autoloads/TradeMemory.gd"):
		_trade_memory = load("res://autoloads/TradeMemory.gd").new()
		_trade_memory.name = "TradeMemory"
		add_child(_trade_memory)
	if _food_chain_manager == null and FileAccess.file_exists("res://autoloads/FoodChainManager.gd"):
		_food_chain_manager = load("res://autoloads/FoodChainManager.gd").new()
		_food_chain_manager.name = "FoodChainManager"
		add_child(_food_chain_manager)
	if _tool_manager == null and FileAccess.file_exists("res://autoloads/ToolManager.gd"):
		_tool_manager = load("res://autoloads/ToolManager.gd").new()
		_tool_manager.name = "ToolManager"
		add_child(_tool_manager)
	
	_subsystems_loaded = true

## Get a specific economy subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"trade_planner": return _trade_planner
		"trade_memory": return _trade_memory
		"food_chain_manager": return _food_chain_manager
		"tool_manager": return _tool_manager
		_: return null

## Plan trade route (delegates to TradePlanner if available)
func plan_trade(settlement_id: int, target_settlement_id: int) -> void:
	if _trade_planner == null:
		_load_subsystems()
	if _trade_planner != null and _trade_planner.has_method("plan_trade"):
		_trade_planner.plan_trade(settlement_id, target_settlement_id)

## Record trade (delegates to TradeMemory if available)
func record_trade(from_settlement: int, to_settlement: int, goods: Dictionary) -> void:
	if _trade_memory == null:
		_load_subsystems()
	if _trade_memory != null and _trade_memory.has_method("record_trade"):
		_trade_memory.record_trade(from_settlement, to_settlement, goods)

## Update food chain (delegates to FoodChainManager if available)
func update_food_chain(world: World) -> void:
	if _food_chain_manager == null:
		_load_subsystems()
	if _food_chain_manager != null and _food_chain_manager.has_method("update"):
		_food_chain_manager.update(world)

## Forward getters for subsystems
func get_trade_planner() -> Node:
	return get_subsystem("trade_planner")

func get_trade_memory() -> Node:
	return get_subsystem("trade_memory")

func get_food_chain_manager() -> Node:
	return get_subsystem("food_chain_manager")

func get_tool_manager() -> Node:
	return get_subsystem("tool_manager")
