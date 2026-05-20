extends Node

## FoodChainManager — manages food spoilage, cooking, preservation, and famine.
##
## This autoload handles:
## - Per-tick spoilage tracking for perishable food in stockpiles
## - Cooking job validation (requires fire pit nearby)
## - Famine detection and emergency food measures
## - Seed planting and crop growth tracking
## - Preservation bonuses (cellar doubles shelf life, drying/smoking)

const SPOILAGE_CHECK_INTERVAL: int = 100  # Check spoilage every N ticks
const FAMINE_FOOD_THRESHOLD: int = 5      # Total food units below this = famine
const EARLY_PROTECTION_DAYS: int = 35
const FIRST_YEAR_HARMFUL_SLOWDOWN: int = 300

var _crop_tiles: Dictionary = {}  # tile_key -> {planted_tick, growth_ticks, type}
const CROP_GROWTH_TICKS: int = 5000  # Ticks for crops to mature

# Per-zone spoilage tracking: "zone_key" -> {"type": accumulated_ticks, ...}
var _zone_spoilage: Dictionary = {}
# Smoking/drying racks: tile_key -> tick_started
var _drying_racks: Dictionary = {}


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	# Periodic spoilage check
	if GameManager.tick_count % SPOILAGE_CHECK_INTERVAL == 0:
		if not _early_protection_active():
			_check_stockpile_spoilage()
	
	# Periodic crop growth check
	if GameManager.tick_count % 50 == 0:
		_tick_crop_growth()
	
	# Periodic famine check
	if GameManager.tick_count % 500 == 0:
		if not _early_protection_active():
			_check_famine_conditions()


## Check all stockpiles for spoiled food and remove it.
func _check_stockpile_spoilage() -> void:
	if StockpileManager == null:
		return
	
	for zone in StockpileManager.zones():
		_spoilage_check_zone(zone)


## Check spoilage for a single stockpile zone.
func _spoilage_check_zone(zone: Stockpile) -> void:
	if zone == null:
		return
	
	var zone_key: String = _zone_key(zone)
	var is_cellar: bool = _is_near_feature(zone.tile, TileFeature.Type.CELLAR, 3) if zone != null else false
	
	# Ensure zone tracking data exists
	if not _zone_spoilage.has(zone_key):
		_zone_spoilage[zone_key] = {}
	
	var zone_data: Dictionary = _zone_spoilage[zone_key]
	
	# Check each perishable item type
	for item_type in [Item.Type.MEAT, Item.Type.BERRY, Item.Type.FISH,
			Item.Type.COOKED_MEAT, Item.Type.COOKED_FISH,
			Item.Type.COOKED_BERRIES, Item.Type.DRIED_MEAT]:
		var count: int = zone.count_of(item_type)
		if count <= 0:
			zone_data.erase(item_type)
			continue
		
		var spoilage_ticks: int = Item.food_spoilage_ticks(item_type)
		if spoilage_ticks <= 0:
			continue  # Never spoils
		
		# Accumulate ticks for this food type in this zone
		var accumulated: int = zone_data.get(item_type, 0)
		accumulated += SPOILAGE_CHECK_INTERVAL
		
		# Apply preservation bonuses
		var effective_ticks: int = spoilage_ticks
		if is_cellar:
			effective_ticks *= 2  # Cellar doubles shelf life
		if item_type == Item.Type.DRIED_MEAT:
			effective_ticks = int(float(effective_ticks) * 1.5)  # Dried lasts longer
		if GameManager != null and GameManager.tick_count < SimTime.TICKS_PER_SIM_YEAR:
			effective_ticks *= FIRST_YEAR_HARMFUL_SLOWDOWN
		
		# Deterministic spoilage: spoil 1 item per threshold crossed
		var spoil_count: int = 0
		while accumulated >= effective_ticks and count > 0:
			spoil_count += 1
			accumulated -= effective_ticks
			count -= 1
		
		zone_data[item_type] = accumulated % effective_ticks
		
		if spoil_count > 0:
			zone.take_item(item_type, spoil_count)
			WorldMemory.record_event({
				"type": "food_spoiled",
				"k": WorldMemory.Kind.STARVATION_EVENT,
				"item_type": item_type,
				"item_name": Item.name_for(item_type),
				"qty": spoil_count,
				"tick": GameManager.tick_count,
				"zone": {"x": zone.tile.x, "y": zone.tile.y},
			})
			if GameManager.verbose_logs() and TickBudgetManager != null:
				TickBudgetManager.log_throttled(
					"FoodChain.spoiled",
					"[FoodChain] %d %s spoiled in stockpile (cellar=%s)" % [spoil_count, Item.name_for(item_type), is_cellar]
				)


## Check if a fire pit exists near the given tile (for cooking jobs).
func has_fire_pit_nearby(tile: Vector2i, radius: int = 8) -> bool:
	var world: World = _get_world()
	if world == null or world.data == null:
		return false
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_tile: Vector2i = tile + Vector2i(dx, dy)
			if not world.data.in_bounds(check_tile.x, check_tile.y):
				continue
			var feat: int = world.data.get_feature(check_tile.x, check_tile.y)
			if feat == TileFeature.Type.FIRE_PIT:
				return true
	return false


## Register a planted crop tile.
func plant_seeds(tile: Vector2i, seed_type: int = Item.Type.SEEDS) -> bool:
	var world: World = _get_world()
	if world == null or world.data == null:
		return false
	
	# Must be planted on fertile soil
	var feat: int = world.data.get_feature(tile.x, tile.y)
	if feat != TileFeature.Type.FERTILE_SOIL:
		return false
	
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	_crop_tiles[tile_key] = {
		"planted_tick": GameManager.tick_count,
		"growth_ticks": CROP_GROWTH_TICKS,
		"type": seed_type,
		"tile": tile,
	}
	
	WorldMemory.record_event({
		"type": "seeds_planted",
		"k": WorldMemory.Kind.FOOD_EVENT,
		"tile": {"x": tile.x, "y": tile.y},
		"tick": GameManager.tick_count,
	})
	
	if GameManager.verbose_logs() and TickBudgetManager != null:
		TickBudgetManager.log_throttled(
			"FoodChain.seeds_planted",
			"[FoodChain] Seeds planted @(%d,%d)" % [tile.x, tile.y]
		)
	
	return true


## Check if a crop is ready to harvest.
func is_crop_ready(tile: Vector2i) -> bool:
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	if not _crop_tiles.has(tile_key):
		return false
	
	var crop: Dictionary = _crop_tiles[tile_key]
	return (GameManager.tick_count - crop.planted_tick) >= crop.growth_ticks


## Harvest a crop tile. Returns the item type produced, or NONE if not ready.
func harvest_crop(tile: Vector2i) -> int:
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	if not _crop_tiles.has(tile_key):
		return Item.Type.NONE
	
	var crop: Dictionary = _crop_tiles[tile_key]
	if not is_crop_ready(tile):
		return Item.Type.NONE
	
	# Remove crop registration
	_crop_tiles.erase(tile_key)
	
	# Clear the fertile soil feature (consumed)
	var world: World = _get_world()
	if world != null:
		world.clear_feature(tile.x, tile.y)
	
	WorldMemory.record_event({
		"type": "crop_harvested",
		"k": WorldMemory.Kind.FOOD_EVENT,
		"tile": {"x": tile.x, "y": tile.y},
		"tick": GameManager.tick_count,
	})
	
	# Crops yield more than foraging: 2-3 berries
	return Item.Type.BERRY


## Advance crop growth for all registered crops.
func _tick_crop_growth() -> void:
	# Crops grow passively; no action needed here since we check maturity on harvest
	pass


## Check if the colony is in famine conditions.
func _check_famine_conditions() -> void:
	if StockpileManager == null:
		return
	if _early_protection_active():
		return

	var total_food: int = StockpileManager.total_food()

	if total_food <= FAMINE_FOOD_THRESHOLD:
		# Derive region from first stockpile zone; fall back to first settlement center
		var region_key: int = 0
		var zones: Array = StockpileManager.zones()
		if zones.size() > 0 and zones[0] != null and is_instance_valid(zones[0]):
			var z_pos: Vector2i = zones[0].tile_pos if zones[0].get("tile_pos") != null else Vector2i.ZERO
			region_key = WorldMemory._region_key(z_pos.x, z_pos.y)
		elif SettlementMemory != null and SettlementMemory.get_formal_settlements().size() > 0:
			var s: Dictionary = SettlementMemory.get_formal_settlements()[0] as Dictionary
			var cv: Variant = s.get("center_tile")
			if cv is Dictionary:
				region_key = WorldMemory._region_key(int(cv.get("x", 0)), int(cv.get("y", 0)))

		WorldMemory.record_event({
			"type": "famine_warning",
			"k": WorldMemory.Kind.STARVATION_EVENT,
			"r": region_key,
			"total_food": total_food,
			"tick": GameManager.tick_count,
		})

		if GameManager.verbose_logs() and TickBudgetManager != null:
			TickBudgetManager.log_throttled(
				"FoodChain.famine_warning",
				"[FoodChain] FAMINE WARNING: only %d food units remaining (region=%d)" % [total_food, region_key]
			)


## Returns the total food value of all stockpiles (weighted by nutrition).
func get_total_nutrition() -> float:
	if StockpileManager == null:
		return 0.0
	
	var total: float = 0.0
	for zone in StockpileManager.zones():
		for item_type in [Item.Type.BERRY, Item.Type.MEAT, Item.Type.FISH,
				Item.Type.COOKED_MEAT, Item.Type.COOKED_FISH,
				Item.Type.DRIED_MEAT, Item.Type.COOKED_BERRIES]:
			var count: int = zone.count_of(item_type)
			total += float(count) * Item.hunger_restore(item_type)
	
	return total


func _get_world() -> World:
	var nodes = get_tree().get_nodes_in_group("world")
	if nodes.is_empty():
		return null
	return nodes[0] as World


func _spoilage_roll_salt(zone: Stockpile, item_type: int, item_index: int) -> int:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var anchor: Vector2i = zone.tile if zone != null else Vector2i.ZERO
	return tick * 1000003 + anchor.x * 73856093 + anchor.y * 19349663 + item_type * 83492791 + item_index


func _zone_key(zone: Stockpile) -> String:
	return "%d,%d-%d,%d" % [zone.rect.position.x, zone.rect.position.y, zone.rect.size.x, zone.rect.size.y]


## Check if a specific tile feature exists within radius of a tile
func _is_near_feature(tile: Vector2i, feature_type: int, radius: int) -> bool:
	var world: World = _get_world()
	if world == null or world.data == null:
		return false
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check: Vector2i = tile + Vector2i(dx, dy)
			if not world.data.in_bounds(check.x, check.y):
				continue
			if world.data.get_feature(check.x, check.y) == feature_type:
				return true
	return false


func _early_protection_active() -> bool:
	if GameManager == null:
		return false
	return GameManager.tick_count < EARLY_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY
