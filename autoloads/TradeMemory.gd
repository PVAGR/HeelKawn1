extends Node
## TradeMemory - Inter-settlement trade route tracking
## 
## Tracks:
## - Active trade routes between settlements
## - Caravan positions and progress
## - Goods exchanged
## - Trade-based knowledge spread

# Trade route tiers for visual rendering
const TIER_NONE: int = 0
const TIER_ROUTE_1: int = 1
const TIER_ROUTE_2: int = 2

# Trade route roles
const ROLE_NONE: String = ""
const ROLE_SOURCE: String = "source"
const ROLE_DESTINATION: String = "destination"
const ROLE_WAYPOINT: String = "waypoint"
const ROLE_DEPENDENT: String = "dependent"

# Trade route data structure
## {
##   "route_id": int,
##   "from_settlement": int,  # center_region
##   "to_settlement": int,
##   "caravan_pawn_id": int,
##   "goods": Dictionary,  # {item_type: quantity}
##   "progress": float,  # 0.0 to 1.0
##   "status": String,  # "en_route", "delivered", "returning"
##   "created_tick": int,
##   "last_updated_tick": int
## }
var trade_routes: Array[Dictionary] = []
var _next_route_id: int = 1

# Trade statistics for diagnostics
var stats: Dictionary = {
	"total_routes": 0,
	"active_routes": 0,
	"completed_routes": 0,
	"total_goods_traded": 0,
	"knowledge_spread_count": 0
}

# Configuration
const TRADE_ROUTE_CHECK_INTERVAL: int = 1000  # Check for new routes every 1000 ticks
const TRADE_ROUTE_DURATION_TICKS: int = 5000  # How long a route takes
const TRADE_GOODS_PER_ROUTE: int = 10  # Base goods per caravan
const MAX_TRADE_ROUTES_PER_SETTLEMENT: int = 3  # Limit concurrent routes


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Check for new trade routes periodically
	if tick % TRADE_ROUTE_CHECK_INTERVAL == 0:
		_try_create_trade_routes(tick)
	
	# Update existing routes
	_update_trade_routes(tick)
	
	# Update stats
	_update_stats()


func _try_create_trade_routes(tick: int) -> void:
	if SettlementMemory == null or SettlementMemory.settlements.is_empty():
		return
	
	# Get all active settlements
	var active_settlements: Array = []
	for st in SettlementMemory.settlements:
		if st is Dictionary:
			var state: String = str(st.get("state", ""))
			if state == "active" or state == "revivable":
				var center: int = int(st.get("center_region", -1))
				if center >= 0:
					active_settlements.append(center)
	
	# Need at least 2 settlements for trade
	if active_settlements.size() < 2:
		return
	
	# Try to create routes between settlements
	for i in range(active_settlements.size()):
		var from_settlement: int = active_settlements[i]
		
		# Check if this settlement already has max routes
		var existing_routes: int = _count_routes_for_settlement(from_settlement)
		if existing_routes >= MAX_TRADE_ROUTES_PER_SETTLEMENT:
			continue
		
		# Find a destination settlement
		for j in range(i + 1, active_settlements.size()):
			var to_settlement: int = active_settlements[j]
			
			# Check if route already exists
			if _route_exists(from_settlement, to_settlement):
				continue
			
			# Create new trade route
			_create_trade_route(from_settlement, to_settlement, tick)
			break  # One route per settlement per check


func _create_trade_route(from_settlement: int, to_settlement: int, tick: int) -> void:
	# Find a pawn to be the trader
	var trader_pawn: Pawn = _find_available_trader(from_settlement)
	if trader_pawn == null:
		return  # No available traders
	
	# Create goods based on settlement surplus
	var goods: Dictionary = _generate_trade_goods(from_settlement)
	
	# Calculate total goods count
	var goods_count: int = 0
	for value in goods.values():
		goods_count += int(value)
	
	# Create route
	var route: Dictionary = {
		"route_id": _next_route_id,
		"from_settlement": from_settlement,
		"to_settlement": to_settlement,
		"caravan_pawn_id": int(trader_pawn.data.id),
		"goods": goods,
		"progress": 0.0,
		"status": "en_route",
		"created_tick": tick,
		"last_updated_tick": tick
	}
	
	trade_routes.append(route)
	_next_route_id += 1
	
	# Record trade event
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "trade_route_started",
			"from": from_settlement,
			"to": to_settlement,
			"pawn_id": int(trader_pawn.data.id),
			"goods_count": goods_count,
			"tick": tick
		})

	if OS.is_debug_build():
		print("[TradeMemory] Created route %d: %d → %d (%d goods)" % [
			route.route_id, from_settlement, to_settlement, goods_count
		])


func _find_available_trader(settlement_region: int) -> Pawn:
	var _ps: Node = _get_pawn_spawner()
	if _ps == null:
		return null
	
	# Find pawns in or near the settlement
	for pawn in _ps.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		# Check if pawn is in the settlement region
		var pawn_region: int = _WM._region_key(pawn.data.tile_pos.x, pawn.data.tile_pos.y)
		if pawn_region != settlement_region:
			continue
		
		# Check if pawn is idle or has Trader profession
		if pawn.data.current_profession == PawnData.Profession.NONE or \
		   pawn._state == Pawn.State.IDLE:
			return pawn
	
	return null


func _generate_trade_goods(settlement_region: int) -> Dictionary:
	var goods: Dictionary = {}

	# Check stockpile for surplus items
	if StockpileManager != null and StockpileManager.has_method("total_count_of"):
		# Food surplus (use BERRY type which exists)
		var food_count: int = StockpileManager.total_count_of(1)  # Item.Type.BERRY
		if food_count > 20:
			goods["food"] = min(TRADE_GOODS_PER_ROUTE, food_count / 2)

		# Wood surplus
		var wood_count: int = StockpileManager.total_count_of(3)  # Item.Type.WOOD
		if wood_count > 15:
			goods["wood"] = min(TRADE_GOODS_PER_ROUTE, wood_count / 2)

		# Stone surplus
		var stone_count: int = StockpileManager.total_count_of(2)  # Item.Type.STONE
		if stone_count > 10:
			goods["stone"] = min(TRADE_GOODS_PER_ROUTE, stone_count / 2)

	# Default goods if no surplus
	if goods.is_empty():
		goods["misc"] = TRADE_GOODS_PER_ROUTE

	return goods


func _update_trade_routes(tick: int) -> void:
	for i in range(trade_routes.size() - 1, -1, -1):
		var route: Dictionary = trade_routes[i]
		
		if route.status != "en_route":
			continue
		
		# Update progress
		var elapsed: int = tick - route.last_updated_tick
		var progress_increment: float = float(elapsed) / float(TRADE_ROUTE_DURATION_TICKS)
		route.progress += progress_increment
		route.last_updated_tick = tick
		
		# Check if route is complete
		if route.progress >= 1.0:
			_complete_trade_route(i, tick)


func _complete_trade_route(route_index: int, tick: int) -> void:
	var route: Dictionary = trade_routes[route_index]
	route.status = "delivered"
	
	# Spread knowledge from origin to destination
	_spread_knowledge(route.from_settlement, route.to_settlement, route.goods)

	# Record completion event
	if WorldMemory != null:
		var goods_total: int = 0
		for value in route.goods.values():
			goods_total += int(value)
		
		WorldMemory.record_event({
			"type": "trade_route_completed",
			"from": route.from_settlement,
			"to": route.to_settlement,
			"goods_count": goods_total,
			"tick": tick
		})
	
	if OS.is_debug_build():
		print("[TradeMemory] Route %d completed: %d → %d" % [
			route.route_id, route.from_settlement, route.to_settlement
		])
	
	# Remove route after completion (could keep for history)
	trade_routes.remove_at(route_index)


func _spread_knowledge(from_region: int, to_region: int, goods: Dictionary) -> void:
	if KnowledgeSystem == null:
		return
	
	# Trade spreads knowledge types based on goods traded
	var knowledge_types: Array = []
	
	if goods.has("food") or goods.has("misc"):
		knowledge_types.append(KnowledgeSystem.KnowledgeType.FOOD_STORAGE)
	
	if goods.has("wood") or goods.has("stone"):
		knowledge_types.append(KnowledgeSystem.KnowledgeType.TOOL_MAKING)
	
	# Add knowledge to destination settlement
	for kt in knowledge_types:
		# Find pawns in destination settlement
		var pawns: Array = _get_pawns_in_region(to_region)
		for pawn in pawns:
			if pawn != null and is_instance_valid(pawn) and pawn.data != null:
				if not KnowledgeSystem.has_knowledge(int(pawn.data.id), kt):
					KnowledgeSystem.add_knowledge_carrier(int(pawn.data.id), kt)
	
	stats.knowledge_spread_count += knowledge_types.size()
	
	if OS.is_debug_build() and not knowledge_types.is_empty():
		print("[TradeMemory] Spread %d knowledge types from region %d to %d" % [
			knowledge_types.size(), from_region, to_region
		])


func _get_pawns_in_region(region: int) -> Array:
	var pawns: Array = []
	var _ps: Node = _get_pawn_spawner()
	if _ps == null:
		return pawns
	
	for pawn in _ps.pawns:
		if pawn == null or not is_instance_valid(pawn):
			continue
		
		var pawn_region: int = _WM._region_key(pawn.data.tile_pos.x, pawn.data.tile_pos.y)
		if pawn_region == region:
			pawns.append(pawn)
	
	return pawns


func _route_exists(from: int, to: int) -> bool:
	for route in trade_routes:
		if (route.from_settlement == from and route.to_settlement == to) or \
		   (route.from_settlement == to and route.to_settlement == from):
			return true
	return false


func _count_routes_for_settlement(settlement: int) -> int:
	var count: int = 0
	for route in trade_routes:
		if route.from_settlement == settlement or route.to_settlement == settlement:
			count += 1
	return count


func _update_stats() -> void:
	stats.total_routes = trade_routes.size()
	stats.active_routes = 0
	for route in trade_routes:
		if route.status == "en_route":
			stats.active_routes += 1


# ==================== Autoload References ====================

@onready var _WM = get_node_or_null("/root/WorldMemory")


func _get_pawn_spawner() -> Node:
	var _main: Node = get_tree().get_root().get_node_or_null("Main") if get_tree() != null else null
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")


# ==================== Public API ====================

## Get all active trade routes
func get_active_routes() -> Array[Dictionary]:
	return trade_routes.filter(func(r): return r.status == "en_route")


## Get trade statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Get goods in transit for a settlement
func get_goods_in_transit(settlement: int) -> Dictionary:
	var total: Dictionary = {}
	for route in trade_routes:
		if route.to_settlement == settlement and route.status == "en_route":
			for item in route.goods:
				total[item] = total.get(item, 0) + route.goods[item]
	return total


## Get trade route tier at a tile (for World rendering)
func get_route_tier_at(x: int, y: int) -> int:
	# Simplified: check if tile is on a trade route path
	# In full implementation, would track actual route paths
	for route in trade_routes:
		if route.status == "en_route":
			# Check if tile is near route endpoints (simplified)
			# Full implementation would interpolate along path
			var from_settlement: Variant = SettlementMemory.get_settlement_at_region(route.from_settlement)
			var to_settlement: Variant = SettlementMemory.get_settlement_at_region(route.to_settlement)
			
			if from_settlement is Dictionary:
				var from_center: int = int(from_settlement.get("center_region", -1))
				if from_center >= 0:
					# Simplified: just check distance to endpoints
					var dist_from: int = abs(x - (from_center % 256)) + abs(y - (from_center / 256))
					var dist_to: int = abs(x - (route.to_settlement % 256)) + abs(y - (route.to_settlement / 256))
					
					if dist_from < 8 or dist_to < 8:
						return TIER_ROUTE_1
	
	return TIER_NONE


## Get pathfinding weight multiplier for trade route at tile
## Used by PathFinder.gd to determine if pawns should prefer trade paths
func get_trade_path_weight_mul(x: int, y: int) -> float:
	var route_tier: int = get_route_tier_at(x, y)
	
	match route_tier:
		TIER_NONE:
			return 1.0  # No route (default cost)
		TIER_ROUTE_1:
			return 0.8  # Minor route (slightly faster - 20% bonus)
		TIER_ROUTE_2:
			return 0.5  # Major route (significantly faster - 50% bonus)
		_:
			return 1.0  # Default


## Manually create a trade route (for testing)
func debug_create_route(from: int, to: int) -> void:
	_create_trade_route(from, to, GameManager.tick_count)


## Returns the count of T2 (Tier 2 / Advanced) trade route tiles.
## Required by IntentMemory.recompute to assess trade capabilities.
func count_t2_tiles() -> int:
	# TODO: Implement actual trade route logic.
	# Currently returns 0 to prevent IntentMemory crash.
	return 0


## Returns the last tick when T2 trade routes existed.
## Required by IntentMemory for trade history assessment.
func get_last_tick_t2_existed() -> int:
	# TODO: Implement actual trade route tracking.
	# Currently returns 0 (no trade routes yet).
	return 0


## Count total tiles across all active trade route paths.
func count_route_tiles() -> int:
	var total: int = 0
	for route in trade_routes:
		if route.has("path") and route.path is Array:
			total += route.path.size()
		elif route.has("tiles") and route.tiles is Array:
			total += route.tiles.size()
		else:
			# Each route counts as at least 1 tile (origin)
			total += 1
	return total


## Returns the trade role at a given tile/region key.
## Required by IntentMemory.recompute for trade intent calculation.
func get_role(region_key: Variant) -> String:
	# TODO: Implement actual trade route role tracking.
	# Currently returns empty string (no trade role).
	return ""


## Clear all trade data (for world reroll/new game)
func clear() -> void:
	trade_routes.clear()
	_next_route_id = 1
	# Reset any other trade data as needed
