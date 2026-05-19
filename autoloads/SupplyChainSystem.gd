extends Node
## SupplyChainSystem — EVE-style economy with supply chains, caravans, and market dynamics.
##
## Features:
## - Trade routes between settlements/nations
## - Caravan system with physical movement
## - Supply/demand pricing per settlement
## - Resource scarcity propagation
## - Trade hubs and market centers
## - Supply line vulnerability (raids, blockades)
## - Economic interdependence between regions
##
## Design principles:
## - Prices emerge from supply/demand, not fixed
## - Trade routes are physical entities on the map
## - Supply chains can be disrupted
## - Economic power influences political power
## - Scarcity in one region creates opportunity in another

# ============================================================
# CONSTANTS
# ============================================================

## How often to update market prices (ticks)
const MARKET_UPDATE_INTERVAL: int = 600

## How often to spawn caravans (ticks)
const CARAVAN_SPAWN_INTERVAL: int = 1200

## How often to check supply chain health (ticks)
const SUPPLY_CHECK_INTERVAL: int = 300

## Base caravan speed (tiles per tick)
const CARAVAN_SPEED: float = 0.5

## Caravan capacity (items)
const CARAVAN_CAPACITY: int = 50

## Trade route decay rate (unused routes fade)
const ROUTE_DECAY_RATE: float = 0.01

## Trade route growth rate (successful trades strengthen)
const ROUTE_GROWTH_RATE: float = 0.02

## Price elasticity (how much price changes per unit of supply/demand)
const PRICE_ELASTICITY: float = 0.05

## Minimum price (can't go below this)
const MIN_PRICE: float = 0.1

## Maximum price multiplier
const MAX_PRICE_MULTIPLIER: float = 10.0

## Raid probability per tick on contested routes
const RAID_BASE_CHANCE: float = 0.001

## Item types tracked in economy
const ECONOMY_ITEMS: PackedStringArray = [
	"wood", "stone", "food", "meat", "fish", "berry",
	"stick", "flint", "hide", "bone", "resin", "gem",
	"seeds", "cooked_meat", "dried_meat", "cooked_fish",
]

# ============================================================
# MARKET DATA
# ============================================================

## settlement_region -> {item_type -> {"supply": int, "demand": float, "price": float, "last_update": int}}
var markets: Dictionary = {}

## trade_routes: route_id -> Dictionary
## {
##   "id": int,
##   "from_region": int,
##   "to_region": int,
##   "item_type": String,
##   "quantity": int,
##   "progress": float,  # 0.0-1.0
##   "caravan_pos": Vector2,
##   "status": String,  # "active", "completed", "raided", "abandoned"
##   "created_tick": int,
##   "strength": float,  # 0.0-1.0, how established the route is
## }
var trade_routes: Dictionary = {}
var _next_route_id: int = 1

## active_caravans: caravan_id -> Dictionary
## {
##   "id": int,
##   "route_id": int,
##   "pos": Vector2,
##   "target": Vector2,
##   "cargo": Dictionary,  # item_type -> quantity
##   "guard_strength": int,
##   "speed": float,
##   "status": String,
## }
var active_caravans: Dictionary = {}
var _next_caravan_id: int = 1

## supply_chains: chain_id -> Dictionary
## {
##   "id": int,
##   "source_region": int,
##   "destination_region": int,
##   "item_type": String,
##   "flow_rate": float,  # items per tick
##   "health": float,  # 0.0-1.0
##   "disruptions": Array,  # reasons for disruption
## }
var supply_chains: Dictionary = {}
var _next_chain_id: int = 1

## Economic events log
var economic_events: Array[Dictionary] = []

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Update market prices
	if tick % MARKET_UPDATE_INTERVAL == 0:
		_update_market_prices(tick)
	# Spawn new caravans
	if tick % CARAVAN_SPAWN_INTERVAL == 0:
		_spawn_caravans(tick)
	# Move active caravans
	_move_caravans(tick)
	# Check supply chain health
	if tick % SUPPLY_CHECK_INTERVAL == 0:
		_check_supply_chains(tick)
	# Process trade route decay/growth
	_update_trade_routes(tick)


# ============================================================
# MARKET SYSTEM
# ============================================================

func _update_market_prices(tick: int) -> void:
	"""Update supply/demand pricing for all settlements."""
	if SettlementMemory == null:
		return
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var region: int = int(st.get("center_region", -1))
		if region < 0:
			continue
		var pop: int = int(st.get("population", 0))
		if pop <= 0:
			continue
		# Initialize market if needed
		if not markets.has(region):
			markets[region] = {}
			for item in ECONOMY_ITEMS:
				markets[region][item] = {
					"supply": 0,
					"demand": float(pop) * 0.5,
					"price": 1.0,
					"last_update": tick,
				}
		# Update supply from stockpiles
		_update_market_supply(region, st, tick)
		# Update demand based on population and needs
		_update_market_demand(region, st, tick)
		# Calculate prices
		_calculate_prices(region, tick)


func _update_market_supply(region: int, settlement: Dictionary, tick: int) -> void:
	"""Update market supply from settlement stockpiles."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty():
		return
	# Estimate supply from stockpile data
	var stockpile_data: Dictionary = settlement.get("stockpiles", {})
	for item in ECONOMY_ITEMS:
		if market.has(item):
			var current_supply: int = int(market[item].get("supply", 0))
			var stockpile_qty: int = int(stockpile_data.get(item, 0))
			# Smooth supply update (not instant)
			market[item]["supply"] = int(current_supply * 0.7 + stockpile_qty * 0.3)


func _update_market_demand(region: int, settlement: Dictionary, tick: int) -> void:
	"""Update market demand based on population and season."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty():
		return
	var pop: int = int(settlement.get("population", 0))
	var season: int = Biome.season_for_tick(tick) if Biome != null else 0
	# Base demand scales with population
	for item in ECONOMY_ITEMS:
		if market.has(item):
			var base_demand: float = float(pop) * 0.5
			# Seasonal modifiers
			match item:
				"food", "berry", "meat", "fish":
					if season == Biome.Season.WINTER:
						base_demand *= 1.5  # Higher food demand in winter
					elif season == Biome.Season.SUMMER:
						base_demand *= 0.8  # Lower in summer (abundance)
				"wood":
					if season == Biome.Season.WINTER:
						base_demand *= 1.3  # More wood for heating
				"seeds":
					if season == Biome.Season.SPRING:
						base_demand *= 2.0  # Planting season
					else:
						base_demand *= 0.3
			market[item]["demand"] = base_demand


func _calculate_prices(region: int, tick: int) -> void:
	"""Calculate prices based on supply/demand ratio."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty():
		return
	for item in ECONOMY_ITEMS:
		if not market.has(item):
			continue
		var supply: float = float(market[item].get("supply", 0))
		var demand: float = float(market[item].get("demand", 1.0))
		var current_price: float = float(market[item].get("price", 1.0))
		# Price = base * (demand / supply) with elasticity
		var ratio: float = 1.0
		if supply > 0:
			ratio = demand / supply
		else:
			ratio = 10.0  # High price when no supply
		var target_price: float = clampf(ratio, MIN_PRICE, MAX_PRICE_MULTIPLIER)
		# Smooth price transition
		var new_price: float = current_price + (target_price - current_price) * PRICE_ELASTICITY
		market[item]["price"] = clampf(new_price, MIN_PRICE, MAX_PRICE_MULTIPLIER)
		market[item]["last_update"] = tick


func get_price_for_item(region: int, item: String) -> float:
	"""Get current market price for an item in a region."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty() or not market.has(item):
		return 1.0
	return float(market[item].get("price", 1.0))


func get_supply_for_item(region: int, item: String) -> int:
	"""Get current supply for an item in a region."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty() or not market.has(item):
		return 0
	return int(market[item].get("supply", 0))


func get_demand_for_item(region: int, item: String) -> float:
	"""Get current demand for an item in a region."""
	var market: Dictionary = markets.get(region, {})
	if market.is_empty() or not market.has(item):
		return 0.0
	return float(market[item].get("demand", 0.0))


# ============================================================
# TRADE ROUTES
# ============================================================

func _spawn_caravans(tick: int) -> void:
	"""Spawn caravans on profitable trade routes."""
	if SettlementMemory == null:
		return
	var settlements: Array = SettlementMemory.settlements
	if settlements.size() < 2:
		return
	# Find profitable trade opportunities
	for i in range(settlements.size()):
		var st_a: Dictionary = settlements[i] as Dictionary
		if not (st_a is Dictionary):
			continue
		var region_a: int = int(st_a.get("center_region", -1))
		if region_a < 0:
			continue
		for j in range(i + 1, settlements.size()):
			var st_b: Dictionary = settlements[j] as Dictionary
			if not (st_b is Dictionary):
				continue
			var region_b: int = int(st_b.get("center_region", -1))
			if region_b < 0:
				continue
			# Check for price arbitrage opportunities
			var best_item: String = ""
			var best_profit: float = 0.0
			for item in ECONOMY_ITEMS:
				var price_a: float = get_price_for_item(region_a, item)
				var price_b: float = get_price_for_item(region_b, item)
				var profit: float = abs(price_b - price_a)
				if profit > 0.5 and profit > best_profit:  # Minimum profit threshold
					best_profit = profit
					best_item = item
			if best_item != "" and best_profit > 0.5:
				# Check if route already exists
				var existing_route: bool = false
				for rid in trade_routes.keys():
					var route: Dictionary = trade_routes[rid]
					if (int(route.get("from_region", -1)) == region_a and int(route.get("to_region", -1)) == region_b) or \
					   (int(route.get("from_region", -1)) == region_b and int(route.get("to_region", -1)) == region_a):
						if str(route.get("item_type", "")) == best_item:
							existing_route = true
							break
				if not existing_route:
					_create_trade_route(region_a, region_b, best_item, tick)


func _create_trade_route(from_region: int, to_region: int, item_type: String, tick: int) -> void:
	"""Create a new trade route between two regions."""
	var rid: int = _next_route_id
	_next_route_id += 1
	var from_tile: Vector2 = _region_to_tile(from_region)
	var to_tile: Vector2 = _region_to_tile(to_region)
	var distance: float = from_tile.distance_to(to_tile)
	var quantity: int = mini(CARAVAN_CAPACITY, int(distance * 2))
	trade_routes[rid] = {
		"id": rid,
		"from_region": from_region,
		"to_region": to_region,
		"item_type": item_type,
		"quantity": quantity,
		"progress": 0.0,
		"caravan_pos": from_tile,
		"status": "active",
		"created_tick": tick,
		"strength": 0.5,
		"distance": distance,
	}
	# Spawn caravan
	_spawn_caravan(rid, from_tile, to_tile, item_type, quantity, tick)
	# Log route creation
	if ChronicleLog != null:
		var from_name: String = _get_settlement_name(from_region)
		var to_name: String = _get_settlement_name(to_region)
		ChronicleLog.append_entry(tick, "world", "A trade route was established between %s and %s for %s." % [from_name, to_name, item_type],
			PackedStringArray(["trade_route", from_name, to_name]))


func _spawn_caravan(route_id: int, from_pos: Vector2, to_pos: Vector2, item_type: String, quantity: int, tick: int) -> void:
	"""Spawn a physical caravan entity."""
	var cid: int = _next_caravan_id
	_next_caravan_id += 1
	active_caravans[cid] = {
		"id": cid,
		"route_id": route_id,
		"pos": from_pos,
		"target": to_pos,
		"cargo": {item_type: quantity},
		"guard_strength": 2,  # Basic guard
		"speed": CARAVAN_SPEED,
		"status": "moving",
		"created_tick": tick,
	}


func _move_caravans(tick: int) -> void:
	"""Move active caravans toward their destinations."""
	var to_remove: Array[int] = []
	for cid in active_caravans.keys():
		var caravan: Dictionary = active_caravans[cid]
		if str(caravan.get("status", "")) != "moving":
			continue
		var pos: Vector2 = caravan.get("pos", Vector2.ZERO)
		var target: Vector2 = caravan.get("target", Vector2.ZERO)
		var speed: float = float(caravan.get("speed", CARAVAN_SPEED))
		# Move toward target
		var direction: Vector2 = (target - pos).normalized()
		var new_pos: Vector2 = pos + direction * speed
		caravan["pos"] = new_pos
		# Update route progress
		var route_id: int = int(caravan.get("route_id", -1))
		var route: Dictionary = trade_routes.get(route_id, {})
		if not route.is_empty():
			var distance: float = float(route.get("distance", 1.0))
			var traveled: float = new_pos.distance_to(Vector2(route.get("from_region", 0)))
			route["progress"] = clampf(traveled / distance, 0.0, 1.0)
			route["caravan_pos"] = new_pos
		# Check if arrived
		if new_pos.distance_to(target) < 1.0:
			_deliver_caravan(cid, route_id, tick)
			to_remove.append(cid)
		# Check for raids
		if _check_caravan_raid(caravan, tick):
			_raid_caravan(cid, route_id, tick)
			to_remove.append(cid)
	# Remove completed/raided caravans
	for cid in to_remove:
		active_caravans.erase(cid)


func _deliver_caravan(caravan_id: int, route_id: int, tick: int) -> void:
	"""Deliver caravan cargo to destination."""
	var caravan: Dictionary = active_caravans.get(caravan_id, {})
	var route: Dictionary = trade_routes.get(route_id, {})
	if caravan.is_empty() or route.is_empty():
		return
	var to_region: int = int(route.get("to_region", -1))
	var cargo: Dictionary = caravan.get("cargo", {})
	# Update destination market supply
	if markets.has(to_region):
		for item in cargo.keys():
			if markets[to_region].has(item):
				var current_supply: int = int(markets[to_region][item].get("supply", 0))
				markets[to_region][item]["supply"] = current_supply + int(cargo[item])
	# Mark route as completed
	route["status"] = "completed"
	route["strength"] = minf(1.0, float(route.get("strength", 0.5)) + ROUTE_GROWTH_RATE)
	# Log delivery
	var from_name: String = _get_settlement_name(int(route.get("from_region", -1)))
	var to_name: String = _get_settlement_name(to_region)
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "A caravan arrived at %s from %s." % [to_name, from_name],
			PackedStringArray(["caravan_delivery", to_name]))


func _check_caravan_raid(caravan: Dictionary, tick: int) -> bool:
	"""Check if a caravan is raided."""
	var route_id: int = int(caravan.get("route_id", -1))
	var route: Dictionary = trade_routes.get(route_id, {})
	if route.is_empty():
		return false
	# Higher raid chance on contested routes
	var from_region: int = int(route.get("from_region", -1))
	var to_region: int = int(route.get("to_region", -1))
	var contested: bool = false
	if NationBorderSystem != null:
		var nation_a: int = NationBorderSystem.get_nation_at_region(from_region)
		var nation_b: int = NationBorderSystem.get_nation_at_region(to_region)
		if nation_a >= 0 and nation_b >= 0 and nation_a != nation_b:
			contested = true
	var raid_chance: float = RAID_BASE_CHANCE
	if contested:
		raid_chance *= 5.0
	# Guard strength reduces raid chance
	var guard_strength: int = int(caravan.get("guard_strength", 0))
	raid_chance *= maxf(0.1, 1.0 - float(guard_strength) * 0.15)
	return WorldRNG != null and WorldRNG.chance_for(StringName("caravan_raid_%d" % caravan.get("id", 0)), raid_chance, tick)


func _raid_caravan(caravan_id: int, route_id: int, tick: int) -> void:
	"""Process a caravan raid."""
	var route: Dictionary = trade_routes.get(route_id, {})
	if route.is_empty():
		return
	route["status"] = "raided"
	route["strength"] = maxf(0.0, float(route.get("strength", 0.5)) - 0.2)
	# Log raid
	var from_name: String = _get_settlement_name(int(route.get("from_region", -1)))
	var to_name: String = _get_settlement_name(int(route.get("to_region", -1)))
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "A caravan from %s to %s was raided on the road!" % [from_name, to_name],
			PackedStringArray(["caravan_raid", from_name, to_name]))
	economic_events.append({
		"type": "caravan_raid",
		"tick": tick,
		"route_id": route_id,
		"from": from_name,
		"to": to_name,
	})


# ============================================================
# SUPPLY CHAINS
# ============================================================

func _check_supply_chains(tick: int) -> void:
	"""Check health of supply chains between settlements."""
	# Identify critical supply dependencies
	if SettlementMemory == null:
		return
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var region: int = int(st.get("center_region", -1))
		if region < 0:
			continue
		var market: Dictionary = markets.get(region, {})
		if market.is_empty():
			continue
		# Check for critical shortages
		for item in ECONOMY_ITEMS:
			if not market.has(item):
				continue
			var supply: int = int(market[item].get("supply", 0))
			var demand: float = float(market[item].get("demand", 1.0))
			if supply < demand * 0.3 and demand > 5.0:
				# Critical shortage — log event
				var settlement_name: String = str(st.get("name", "Unknown"))
				economic_events.append({
					"type": "supply_shortage",
					"tick": tick,
					"settlement": settlement_name,
					"region": region,
					"item": item,
					"severity": 1.0 - (float(supply) / demand),
				})
				if ChronicleLog != null:
					ChronicleLog.append_entry(tick, "world", "%s faces a critical shortage of %s!" % [settlement_name, item],
						PackedStringArray(["supply_shortage", settlement_name, item]))


func _update_trade_routes(tick: int) -> void:
	"""Update trade route strength and decay unused routes."""
	for rid in trade_routes.keys():
		var route: Dictionary = trade_routes[rid]
		var status: String = str(route.get("status", ""))
		if status == "completed":
			# Reset for next caravan
			route["status"] = "active"
			route["progress"] = 0.0
			var from_tile: Vector2 = _region_to_tile(int(route.get("from_region", 0)))
			route["caravan_pos"] = from_tile
		elif status == "active":
			# Decay unused routes
			var age: int = tick - int(route.get("created_tick", tick))
			if age > 5000:
				route["strength"] = maxf(0.0, float(route.get("strength", 0.5)) - ROUTE_DECAY_RATE)
				if float(route.get("strength", 0.0)) <= 0.0:
					route["status"] = "abandoned"


# ============================================================
# HELPERS
# ============================================================

func _region_to_tile(region: int) -> Vector2:
	"""Convert region key to center tile."""
	var rx: int = region & 0xFFFF
	var ry: int = (region >> 16) & 0xFFFF
	return Vector2(rx * 16 + 8, ry * 16 + 8)


func _get_settlement_name(region: int) -> String:
	"""Get settlement name for a region."""
	if SettlementMemory == null:
		return "Unknown"
	var st: Variant = SettlementMemory.get_settlement_at_region(region)
	if st is Dictionary:
		return str(st.get("name", "Unknown"))
	return "Unknown"


# ============================================================
# PUBLIC API
# ============================================================

func get_market_data(region: int) -> Dictionary:
	"""Get full market data for a region."""
	return markets.get(region, {})


func get_trade_routes() -> Array[Dictionary]:
	"""Get all active trade routes."""
	var result: Array[Dictionary] = []
	for rid in trade_routes.keys():
		var route: Dictionary = trade_routes[rid]
		if str(route.get("status", "")) in ["active", "moving"]:
			result.append(route)
	return result


func get_active_caravans() -> Array[Dictionary]:
	"""Get all active caravans."""
	var result: Array[Dictionary] = []
	for cid in active_caravans.keys():
		result.append(active_caravans[cid])
	return result


func get_economic_events_since(tick: int) -> Array[Dictionary]:
	"""Get economic events since a given tick."""
	var result: Array[Dictionary] = []
	for evt in economic_events:
		if int(evt.get("tick", 0)) >= tick:
			result.append(evt)
	return result


func get_trade_route_count() -> int:
	return trade_routes.size()


func get_caravan_count() -> int:
	return active_caravans.size()


func get_market_count() -> int:
	return markets.size()


func find_best_trade_route(from_region: int) -> Dictionary:
	"""Find the most profitable trade route from a region."""
	var best_route: Dictionary = {}
	var best_profit: float = 0.0
	var market_a: Dictionary = markets.get(from_region, {})
	if market_a.is_empty():
		return best_route
	for to_region in markets.keys():
		if to_region == from_region:
			continue
		var market_b: Dictionary = markets[to_region]
		for item in ECONOMY_ITEMS:
			if market_a.has(item) and market_b.has(item):
				var price_a: float = float(market_a[item].get("price", 1.0))
				var price_b: float = float(market_b[item].get("price", 1.0))
				var profit: float = abs(price_b - price_a)
				if profit > best_profit:
					best_profit = profit
					best_route = {
						"from": from_region,
						"to": to_region,
						"item": item,
						"buy_price": price_a,
						"sell_price": price_b,
						"profit": profit,
					}
	return best_route
