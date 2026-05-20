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
class_name TradeMemory

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
var _route_tile_tiers: Dictionary = {}  # region_key -> tier
var _route_roles_by_region: Dictionary = {}  # center_region -> role
var _route_incoming_by_center: Dictionary = {}
var _route_outgoing_by_center: Dictionary = {}
var _last_tick_t2_existed: int = -1

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
	_rebuild_route_caches(tick)
	
	# Update stats
	_update_stats()


func _try_create_trade_routes(tick: int) -> void:
	if SettlementMemory == null:
		return
	
	# Get all active settlements (formal first, then well-developed proto camps).
	var active_settlements: Array = []
	for st in SettlementMemory.get_formal_settlements():
		if st is Dictionary:
			var state: String = str(st.get("state", ""))
			if state == "active" or state == "revivable":
				var center: int = int(st.get("center_region", -1))
				if center >= 0:
					active_settlements.append(center)
	if active_settlements.size() < 2:
		for st in SettlementMemory.get_proto_sites():
			if st is not Dictionary:
				continue
			var sd: Dictionary = st as Dictionary
			if int(sd.get("population", 0)) < 3:
				continue
			var center_proto: int = int(sd.get("center_region", -1))
			if center_proto >= 0 and not active_settlements.has(center_proto):
				active_settlements.append(center_proto)
	
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
	var trader_pawn: HeelKawnian = _find_available_trader(from_settlement)
	var trader_id: int = -1
	if trader_pawn != null and trader_pawn.data != null:
		trader_id = int(trader_pawn.data.id)

	var goods: Dictionary = _generate_trade_goods(from_settlement)
	if goods.is_empty():
		goods = {"food": TRADE_GOODS_PER_ROUTE}

	var goods_count: int = 0
	for value in goods.values():
		goods_count += int(value)

	var from_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(from_settlement)
	var to_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(to_settlement)
	var path: Array = _route_path_tiles(from_tile, to_tile)

	var route: Dictionary = {
		"route_id": _next_route_id,
		"from_settlement": from_settlement,
		"to_settlement": to_settlement,
		"caravan_pawn_id": trader_id,
		"goods": goods,
		"progress": 0.05,
		"status": "en_route",
		"created_tick": tick,
		"last_updated_tick": tick,
		"path": path,
		"tiles": path,
	}
	route["tier"] = _classify_route_tier(route)

	trade_routes.append(route)
	_next_route_id += 1

	if DiscoveryGate != null:
		DiscoveryGate.unlock("first_trade")

	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "trade_route_started",
			"from": from_settlement,
			"to": to_settlement,
			"pawn_id": trader_id,
			"goods_count": goods_count,
			"tick": tick,
		})

	if OS.is_debug_build():
		print("[TradeMemory] Created route %d: %d → %d (%d goods, path=%d)" % [
			route.route_id, from_settlement, to_settlement, goods_count, path.size()
		])


func _route_path_tiles(from_tile: Vector2i, to_tile: Vector2i) -> Array:
	var path: Array = []
	var steps: int = maxi(absi(to_tile.x - from_tile.x), absi(to_tile.y - from_tile.y))
	steps = maxi(steps, 1)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var tile: Vector2i = Vector2i(
				int(lerpf(float(from_tile.x), float(to_tile.x), t)),
				int(lerpf(float(from_tile.y), float(to_tile.y), t)),
		)
		if path.is_empty() or path[path.size() - 1] != tile:
			path.append(tile)
	return path


func _pawn_in_settlement(pawn: HeelKawnian, settlement_center_rk: int) -> bool:
	if pawn == null or pawn.data == null or settlement_center_rk < 0:
		return false
	var pawn_rk: int = _WM._region_key(pawn.data.tile_pos.x, pawn.data.tile_pos.y)
	if pawn_rk == settlement_center_rk:
		return true
	if SettlementMemory != null:
		return SettlementMemory.get_center_region_for_region(pawn_rk) == settlement_center_rk
	return false


func _find_available_trader(settlement_center_rk: int) -> HeelKawnian:
	var _ps: Node = _get_pawn_spawner()
	if _ps == null:
		return null

	var best: HeelKawnian = null
	var best_score: int = -1
	for pawn in _ps.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		if not _pawn_in_settlement(pawn, settlement_center_rk):
			continue
		var score: int = 0
		if pawn.data.current_profession == HeelKawnianData.Profession.TRADER:
			score += 4
		if pawn._state == HeelKawnian.State.IDLE:
			score += 2
		elif pawn._state == HeelKawnian.State.WALKING_TO_JOB:
			score += 1
		if score > best_score:
			best_score = score
			best = pawn
	return best


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
	_deliver_route_goods(route)
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
			"tick": tick,
		})
		WorldMemory.record_event({
			"type": "trade_goods_arrived",
			"from": route.from_settlement,
			"to": route.to_settlement,
			"goods": route.get("goods", {}),
			"goods_count": goods_total,
			"tick": tick,
		})
	
	if OS.is_debug_build():
		print("[TradeMemory] Route %d completed: %d → %d" % [
			route.route_id, route.from_settlement, route.to_settlement
		])
	
	# Remove route after completion (could keep for history)
	trade_routes.remove_at(route_index)
	_rebuild_route_caches(tick)


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


## Diplomatic / map link when FactionManager opens formal trade (caravan optional).
func ensure_route_between(from_settlement: int, to_settlement: int, tick: int) -> void:
	if from_settlement < 0 or to_settlement < 0 or from_settlement == to_settlement:
		return
	if _route_exists(from_settlement, to_settlement):
		return
	var goods: Dictionary = _generate_trade_goods(from_settlement)
	if goods.is_empty():
		goods = {"food": TRADE_GOODS_PER_ROUTE}
	var from_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(from_settlement)
	var to_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(to_settlement)
	var path: Array = _route_path_tiles(from_tile, to_tile)
	var route: Dictionary = {
		"route_id": _next_route_id,
		"from_settlement": from_settlement,
		"to_settlement": to_settlement,
		"caravan_pawn_id": -1,
		"goods": goods,
		"progress": 0.05,
		"status": "en_route",
		"created_tick": tick,
		"last_updated_tick": tick,
		"path": path,
		"tiles": path,
	}
	route["tier"] = _classify_route_tier(route)
	trade_routes.append(route)
	_next_route_id += 1
	if DiscoveryGate != null:
		DiscoveryGate.unlock("first_trade")
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "trade_route_started",
			"tick": tick,
			"from": from_settlement,
			"to": to_settlement,
		})
	_rebuild_route_caches(tick)


func _goods_key_to_item_type(key: String) -> int:
	match key:
		"food", "berry":
			return Item.Type.BERRY
		"wood":
			return Item.Type.WOOD
		"stone":
			return Item.Type.STONE
		"fish":
			return Item.Type.FISH
		"meat":
			return Item.Type.MEAT
		_:
			return Item.Type.BERRY


func _deliver_route_goods(route: Dictionary) -> void:
	if StockpileManager == null:
		return
	var dest_rk: int = int(route.get("to_settlement", -1))
	if dest_rk < 0:
		return
	var dest_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(dest_rk)
	var goods: Dictionary = route.get("goods", {}) as Dictionary
	for key in goods:
		var qty: int = int(goods[key])
		if qty <= 0:
			continue
		var item_type: int = _goods_key_to_item_type(str(key))
		var zone: Stockpile = StockpileManager.find_drop_zone_for_settlement(dest_rk, item_type, dest_tile, null)
		if zone == null:
			zone = StockpileManager.find_drop_zone(item_type, dest_tile, null)
		if zone != null:
			zone.add_item(item_type, qty)


## Moving caravan markers for map overlay (interpolated along route progress).
func get_caravan_markers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for route_any in trade_routes:
		if route_any is not Dictionary:
			continue
		var route: Dictionary = route_any as Dictionary
		if str(route.get("status", "")) != "en_route":
			continue
		var from_rk: int = int(route.get("from_settlement", -1))
		var to_rk: int = int(route.get("to_settlement", -1))
		if from_rk < 0 or to_rk < 0:
			continue
		var from_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(from_rk)
		var to_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(to_rk)
		var prog: float = clampf(float(route.get("progress", 0.0)), 0.0, 1.0)
		var tile: Vector2i = Vector2i(
				int(lerpf(float(from_tile.x), float(to_tile.x), prog)),
				int(lerpf(float(from_tile.y), float(to_tile.y), prog)),
		)
		out.append({
			"tile": tile,
			"from_settlement": from_rk,
			"to_settlement": to_rk,
			"progress": prog,
			"caravan_pawn_id": int(route.get("caravan_pawn_id", -1)),
		})
	return out


## Routes visible on strategy map (includes diplomatic links without caravan).
func get_routes_for_map_draw() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in trade_routes:
		if str(r.get("status", "")) in ["en_route", "returning", "delivered"]:
			out.append(r)
	return out


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
	var result: Array[Dictionary] = []
	for r in trade_routes:
		if r.status == "en_route":
			result.append(r)
	return result


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
	if _WM == null:
		return TIER_NONE
	var rk: int = _WM._region_key(x, y)
	return int(_route_tile_tiers.get(rk, TIER_NONE))


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


## PERFORMANCE: Return regions that have active trade routes.
func get_regions_with_trade() -> Dictionary:
	var result: Dictionary = {}
	for route in trade_routes:
		if route.status == "en_route":
			var from_center: int = int(route.from_settlement)
			var to_center: int = int(route.to_settlement)
			result[from_center] = true
			result[to_center] = true
	return result


## Manually create a trade route (for testing)
func debug_create_route(from: int, to: int) -> void:
	_create_trade_route(from, to, GameManager.tick_count)


## Returns the count of T2 (Tier 2 / Advanced) trade route tiles.
## Required by IntentMemory.recompute to assess trade capabilities.
func count_t2_tiles() -> int:
	var total: int = 0
	for rk_any in _route_tile_tiers.keys():
		if int(_route_tile_tiers.get(rk_any, TIER_NONE)) >= TIER_ROUTE_2:
			total += 1
	return total


## Returns the last tick when T2 trade routes existed.
## Required by IntentMemory for trade history assessment.
func get_last_tick_t2_existed() -> int:
	return _last_tick_t2_existed


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
	var rk: int = int(region_key)
	var incoming: int = int(_route_incoming_by_center.get(rk, 0))
	var outgoing: int = int(_route_outgoing_by_center.get(rk, 0))
	if incoming >= 2 and outgoing == 0:
		return ROLE_DEPENDENT
	if incoming > outgoing * 2 and incoming >= 3:
		return ROLE_DEPENDENT
	return str(_route_roles_by_region.get(rk, ROLE_NONE))


## Clear all trade data (for world reroll/new game)
func clear() -> void:
	trade_routes.clear()
	_next_route_id = 1
	_route_tile_tiers.clear()
	_route_roles_by_region.clear()
	_route_incoming_by_center.clear()
	_route_outgoing_by_center.clear()
	_last_tick_t2_existed = -1
	# Reset any other trade data as needed


func has_active_route_between(from_settlement: int, to_settlement: int) -> bool:
	if from_settlement < 0 or to_settlement < 0:
		return false
	for route_any in trade_routes:
		if route_any is not Dictionary:
			continue
		var route: Dictionary = route_any as Dictionary
		if str(route.get("status", "")) != "en_route":
			continue
		var from_rk: int = int(route.get("from_settlement", -1))
		var to_rk: int = int(route.get("to_settlement", -1))
		if (from_rk == from_settlement and to_rk == to_settlement) \
				or (from_rk == to_settlement and to_rk == from_settlement):
			return true
	return false


func _classify_route_tier(route: Dictionary) -> int:
	var goods_v: Variant = route.get("goods", {})
	var goods: Dictionary = goods_v as Dictionary if goods_v is Dictionary else {}
	var goods_total: int = 0
	for g in goods.values():
		goods_total += int(g)
	var path_v: Variant = route.get("path", [])
	var path: Array = path_v as Array if path_v is Array else []
	# Tier-2 routes represent higher-throughput or long-haul links.
	if goods_total >= TRADE_GOODS_PER_ROUTE * 2 or path.size() >= 30:
		return TIER_ROUTE_2
	return TIER_ROUTE_1


func _rebuild_route_caches(tick: int = -1) -> void:
	_route_tile_tiers.clear()
	_route_roles_by_region.clear()
	_route_incoming_by_center.clear()
	_route_outgoing_by_center.clear()
	var saw_t2: bool = false
	for route_any in trade_routes:
		if route_any is not Dictionary:
			continue
		var route: Dictionary = route_any as Dictionary
		var status: String = str(route.get("status", ""))
		if status != "en_route":
			continue
		var from_rk: int = int(route.get("from_settlement", -1))
		var to_rk: int = int(route.get("to_settlement", -1))
		if from_rk >= 0:
			_route_roles_by_region[from_rk] = ROLE_SOURCE
			_route_outgoing_by_center[from_rk] = int(_route_outgoing_by_center.get(from_rk, 0)) + 1
		if to_rk >= 0:
			_route_roles_by_region[to_rk] = ROLE_DESTINATION
			_route_incoming_by_center[to_rk] = int(_route_incoming_by_center.get(to_rk, 0)) + 1
		var tier: int = int(route.get("tier", TIER_ROUTE_1))
		if tier >= TIER_ROUTE_2:
			saw_t2 = true
		var tiles_v: Variant = route.get("tiles", route.get("path", []))
		var tiles: Array = tiles_v as Array if tiles_v is Array else []
		for tile_any in tiles:
			if tile_any is not Vector2i:
				continue
			var tile: Vector2i = tile_any as Vector2i
			if _WM == null:
				continue
			var rk: int = _WM._region_key(tile.x, tile.y)
			var existing: int = int(_route_tile_tiers.get(rk, TIER_NONE))
			if tier > existing:
				_route_tile_tiers[rk] = tier
				if existing == TIER_NONE and not _route_roles_by_region.has(rk):
					_route_roles_by_region[rk] = ROLE_WAYPOINT
	if saw_t2:
		if tick < 0 and GameManager != null:
			_last_tick_t2_existed = GameManager.tick_count
		elif tick >= 0:
			_last_tick_t2_existed = tick
