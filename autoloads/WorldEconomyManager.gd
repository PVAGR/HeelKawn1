extends Node

## WorldEconomyManager - Consolidated economy and trade systems.
## Combines CurrencySystem and EconomyManager functionality.

# === Currency System ===
enum CurrencyPhase {
	BARTER,        # no currency, direct exchange
	COMMODITY,     # gems/salt used as reference value
	MINTED,        # settlement-minted coins
}

var _currency_phase: int = CurrencyPhase.BARTER
var _mints: Dictionary = {}
var _exchange_rates: Dictionary = {}
var _trade_volume: int = 0

# === Subsystems (loaded on-demand) ===
var _trade_planner: Node
var _trade_memory: Node
var _food_chain_manager: Node
var _tool_manager: Node

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(_tick: int) -> void:
	pass

# --- Currency Logic ---
func get_currency_phase() -> int:
	return _currency_phase

func record_market_trade(item_a: int, item_b: int, qty_a: int, qty_b: int) -> void:
	_trade_volume += 1
	var key: String = "%d_%d" % [mini(item_a, item_b), maxi(item_a, item_b)]
	if not _exchange_rates.has(key):
		_exchange_rates[key] = []
	_exchange_rates[key].append({"a": qty_a, "b": qty_b, "tick": GameManager.tick_count if GameManager != null else 0})
	
	if _trade_volume >= 50 and _currency_phase == CurrencyPhase.BARTER:
		_advance_currency_phase(CurrencyPhase.COMMODITY)
	if _trade_volume >= 200 and _currency_phase == CurrencyPhase.COMMODITY:
		if not _mints.is_empty():
			_advance_currency_phase(CurrencyPhase.MINTED)

func _advance_currency_phase(new_phase: int) -> void:
	_currency_phase = new_phase
	WorldMemory.record_event({
		"type": "currency_phase_advanced",
		"tick": GameManager.tick_count if GameManager != null else 0,
		"phase": new_phase,
		"trade_volume": _trade_volume,
	})

func establish_mint(settlement_id: int, mint_name: String) -> void:
	_mints[settlement_id] = {
		"name": mint_name,
		"tick_established": GameManager.tick_count if GameManager != null else 0,
		"coins_minted": 0,
	}

func get_item_value(item_type: int) -> int:
	match item_type:
		Item.Type.WOOD, Item.Type.STICK: return 1
		Item.Type.STONE, Item.Type.FLINT: return 2
		Item.Type.FOOD, Item.Type.BERRY: return 1
		Item.Type.MEAT: return 3
		Item.Type.HIDE: return 5
		Item.Type.GOLD_ORE: return 20
		Item.Type.GEM: return 50
		_: return 1

# --- Subsystem Management ---
func _load_sub(name: String, path: String) -> Node:
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null

func get_trade_planner() -> Node:
	return EconomyManager.get_trade_planner()

func get_trade_memory() -> Node:
	return EconomyManager.get_trade_memory()

func get_food_chain_manager() -> Node:
	if _food_chain_manager == null:
		_food_chain_manager = _load_sub("FoodChainManager", "res://autoloads/FoodChainManager.gd")
	return _food_chain_manager

func get_tool_manager() -> Node:
	if _tool_manager == null:
		_tool_manager = _load_sub("ToolManager", "res://autoloads/ToolManager.gd")
	return _tool_manager
