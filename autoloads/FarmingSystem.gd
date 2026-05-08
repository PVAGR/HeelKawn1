extends Node
## FarmingSystem - Agriculture and crop cultivation
##
## Pawns can plant, tend, and harvest crops:
## - Wheat (basic food, bread ingredient)
## - Corn (high yield, stores well)
## - Vegetables (nutrition bonus)
## - Herbs (medicine ingredient)
##
## Farming provides stable food supply vs foraging randomness.

# Crop types
enum CropType { WHEAT, CORN, VEGETABLES, HERBS }

# Farm plot data
## {
##   "plot_id": int,
##   "tile": Vector2i,
##   "crop_type": int,  # CropType enum
##   "planted_tick": int,
##   "growth_progress": float,  # 0.0 to 1.0
##   "health": float,  # 0.0 to 1.0
##   "water_level": float,  # 0.0 to 1.0
##   "tended_by": int,  # pawn_id
##   "status": String,  # "planted", "growing", "ready", "withered"
##   "yield_quantity": int
## }
var farm_plots: Array[Dictionary] = []
var _next_plot_id: int = 1

# Crop configuration - BALANCED FOR FUN (Option C)
const CROP_CONFIG: Dictionary = {
	CropType.WHEAT: {
		"growth_ticks": 2400,  # ~40 minutes at 1x (REDUCED from 3000 for faster gameplay)
		"water_need": 0.25,  # Water consumption per tick (REDUCED for less micromanagement)
		"base_yield": 4,  # (INCREASED from 3 for better reward)
		"nutrition": 50,  # (INCREASED from 40 for viable food source)
		"seed_item": "wheat_seeds"
	},
	CropType.CORN: {
		"growth_ticks": 3200,  # ~53 minutes (REDUCED from 4000)
		"water_need": 0.3,  # (REDUCED from 0.4)
		"base_yield": 6,  # (INCREASED from 5 - highest yield crop)
		"nutrition": 60,  # (INCREASED from 50)
		"seed_item": "corn_seeds"
	},
	CropType.VEGETABLES: {
		"growth_ticks": 2000,  # ~33 minutes - fastest crop (REDUCED from 2500)
		"water_need": 0.35,  # (REDUCED from 0.5)
		"base_yield": 5,  # (INCREASED from 4)
		"nutrition": 75,  # (INCREASED from 60 - best nutrition)
		"seed_item": "vegetable_seeds"
	},
	CropType.HERBS: {
		"growth_ticks": 1600,  # ~27 minutes - quick medicine (REDUCED from 2000)
		"water_need": 0.15,  # (REDUCED from 0.2 - low maintenance)
		"base_yield": 3,  # (INCREASED from 2)
		"nutrition": 15,  # (INCREASED from 10)
		"seed_item": "herb_seeds",
		"medicine_bonus": true
	}
}

# Farming job types
const FARMING_JOBS: Dictionary = {
	"plant_wheat": {"crop": CropType.WHEAT, "work_ticks": 30},
	"plant_corn": {"crop": CropType.CORN, "work_ticks": 30},
	"plant_vegetables": {"crop": CropType.VEGETABLES, "work_ticks": 30},
	"plant_herbs": {"crop": CropType.HERBS, "work_ticks": 30},
	"water_crops": {"work_ticks": 20},
	"tend_crops": {"work_ticks": 25},
	"harvest_crops": {"work_ticks": 40}
}

# References
@onready var _world: Node = null
@onready var _world_memory: Node = null
@onready var _job_manager: Node = null
@onready var _stockpile_manager: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	await get_tree().process_frame
	_world = get_node_or_null("/root/Main/World")
	_world_memory = get_node_or_null("/root/WorldMemory")
	_job_manager = get_node_or_null("/root/JobManager")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")


func _on_game_tick(tick: int) -> void:
	# Update crop growth
	_update_crop_growth(tick)
	
	# Check for withered crops
	_check_crop_health(tick)


func _update_crop_growth(tick: int) -> void:
	for plot in farm_plots:
		if plot.status != "growing":
			continue
		
		# Get crop configuration
		var config: Dictionary = CROP_CONFIG[plot.crop_type]
		
		# Calculate growth increment
		var growth_increment: float = 1.0 / float(config.growth_ticks)
		
		# Apply water modifier (less water = slower growth)
		var water_modifier: float = maxf(0.2, plot.water_level)
		growth_increment *= water_modifier
		
		# Apply health modifier
		growth_increment *= plot.health
		
		# Update growth progress
		plot.growth_progress += growth_increment
		
		# Consume water
		plot.water_level -= config.water_need / 100.0
		plot.water_level = maxf(0.0, plot.water_level)
		
		# Check if ready to harvest
		if plot.growth_progress >= 1.0:
			plot.status = "ready"
			plot.yield_quantity = int(config.base_yield * plot.health * (1.0 + plot.water_level))
			
			# Record harvest ready event
			if _world_memory != null:
				_world_memory.record_event({
					"type": "crop_ready",
					"crop_type": _crop_type_to_string(plot.crop_type),
					"tile": {"x": plot.tile.x, "y": plot.tile.y},
					"yield": plot.yield_quantity,
					"tick": tick
				})


func _check_crop_health(tick: int) -> void:
	for plot in farm_plots:
		if plot.status == "withered":
			continue
		
		# Check water level - BALANCED: Slower withering for less frustration
		if plot.water_level <= 0.0:
			plot.health -= 0.005  # Lose 0.5% health per tick (REDUCED from 1% - gives 200 ticks grace period)
			if plot.health <= 0.0:
				plot.status = "withered"
				plot.health = 0.0
		
		# Record withered event
		if plot.status == "withered" and _world_memory != null:
			_world_memory.record_event({
				"type": "crop_withered",
				"crop_type": _crop_type_to_string(plot.crop_type),
				"tile": {"x": plot.tile.x, "y": plot.tile.y},
				"reason": "lack_of_water",
				"tick": tick
			})


func _crop_type_to_string(crop_type: int) -> String:
	match crop_type:
		CropType.WHEAT:
			return "wheat"
		CropType.CORN:
			return "corn"
		CropType.VEGETABLES:
			return "vegetables"
		CropType.HERBS:
			return "herbs"
		_:
			return "unknown"


# ==================== Planting ====================

## Create a new farm plot
func create_farm_plot(tile: Vector2i, crop_type: int, planter_pawn_id: int = -1) -> int:
	# Check if tile is suitable (must be passable, no existing plot)
	if not _is_suitable_farm_tile(tile):
		return -1
	
	# Check if plot already exists at this tile
	for plot in farm_plots:
		if plot.tile == tile:
			return -1  # Already a plot here
	
	# Create new plot
	var plot: Dictionary = {
		"plot_id": _next_plot_id,
		"tile": tile,
		"crop_type": crop_type,
		"planted_tick": GameManager.tick_count,
		"growth_progress": 0.0,
		"health": 1.0,
		"water_level": 0.5,  # Start with some moisture
		"tended_by": planter_pawn_id,
		"status": "planted",
		"yield_quantity": 0
	}
	
	farm_plots.append(plot)
	
	# Start growth after planting delay
	call_deferred("_start_crop_growth", plot)
	
	_next_plot_id += 1
	
	# Record planting event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "crop_planted",
			"crop_type": _crop_type_to_string(crop_type),
			"tile": {"x": tile.x, "y": tile.y},
			"pawn_id": planter_pawn_id,
			"tick": GameManager.tick_count
		})
	
	if OS.is_debug_build():
		print("[Farming] Planted %s at (%d,%d)" % [_crop_type_to_string(crop_type), tile.x, tile.y])
	
	return plot.plot_id


func _start_crop_growth(plot: Dictionary) -> void:
	plot.status = "growing"


func _is_suitable_farm_tile(tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	
	# Must be in bounds
	if not _world.data.in_bounds(tile.x, tile.y):
		return false
	
	# Must be passable
	if not _world.data.is_passable(tile.x, tile.y):
		return false
	
	# Must be on suitable biome (plains or forest cleared)
	var biome: int = _world.data.get_biome(tile.x, tile.y)
	return biome == 1 or biome == 2  # PLAINS or cleared FOREST


## Post farming jobs
func post_farming_jobs(settlement_center: Vector2i, radius: int) -> void:
	if _job_manager == null:
		return
	
	# Find plots that need attention
	for plot in farm_plots:
		var dist: float = plot.tile.distance_to(settlement_center)
		if dist > radius:
			continue
		
		match plot.status:
			"planted", "growing":
				# Check if needs watering
				if plot.water_level < 0.3:
					_post_water_job(plot)
				# Check if needs tending
				elif plot.health < 0.8:
					_post_tend_job(plot)
			
			"ready":
				_post_harvest_job(plot)


func _post_water_job(plot: Dictionary) -> void:
	var job_data: Dictionary = {
		"type": "water_crops",
		"work_tile": plot.tile,
		"priority": 5,
		"work_ticks": FARMING_JOBS["water_crops"].work_ticks,
		"plot_id": plot.plot_id
	}
	_job_manager.post_from_dict(job_data)


func _post_tend_job(plot: Dictionary) -> void:
	var job_data: Dictionary = {
		"type": "tend_crops",
		"work_tile": plot.tile,
		"priority": 4,
		"work_ticks": FARMING_JOBS["tend_crops"].work_ticks,
		"plot_id": plot.plot_id
	}
	_job_manager.post_from_dict(job_data)


func _post_harvest_job(plot: Dictionary) -> void:
	var job_data: Dictionary = {
		"type": "harvest_crops",
		"work_tile": plot.tile,
		"priority": 6,
		"work_ticks": FARMING_JOBS["harvest_crops"].work_ticks,
		"plot_id": plot.plot_id
	}
	_job_manager.post_from_dict(job_data)


# ==================== Job Completion ====================

## Complete a farming job and apply effects
func complete_farming_job(job_type: String, plot_id: int, pawn_id: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"items_gained": {},
		"plot_updated": false
	}
	
	# Find the plot
	var plot: Dictionary = _get_plot_by_id(plot_id)
	if plot == null:
		return result
	
	match job_type:
		"water_crops":
			plot.water_level = minf(1.0, plot.water_level + 0.4)
			result.success = true
			result.plot_updated = true
		
		"tend_crops":
			plot.health = minf(1.0, plot.health + 0.2)
			result.success = true
			result.plot_updated = true
		
		"harvest_crops":
			if plot.status == "ready":
				# Gain crops
				var crop_name: String = _crop_type_to_string(plot.crop_type)
				result.items_gained[crop_name] = plot.yield_quantity
				
				# Gain seeds for replanting
				result.items_gained[crop_name + "_seeds"] = max(1, plot.yield_quantity / 3)
				
				# Clear the plot
				plot.status = "harvested"
				result.success = true
				result.plot_updated = true
				
				# Record harvest event
				if _world_memory != null:
					_world_memory.record_event({
						"type": "crop_harvested",
						"crop_type": crop_name,
						"yield": plot.yield_quantity,
						"pawn_id": pawn_id,
						"tick": GameManager.tick_count
					})
	
	return result


## Complete a farming job by tile position (used by Pawn._complete_current_job
## when GROW_FOOD completes). Finds the plot at the tile, then delegates
## to complete_farming_job.
func complete_farming_job_by_tile(tile: Vector2i, pawn_id: int) -> Dictionary:
	for plot in farm_plots:
		if plot.tile == tile:
			# Determine job type from plot status
			var job_type: String = "grow_food"
			if plot.water_level < 0.3:
				job_type = "water_crops"
			elif plot.health < 0.8:
				job_type = "tend_crops"
			return complete_farming_job(job_type, plot.plot_id, pawn_id)
	return {"success": false, "items_gained": {}, "plot_updated": false}


func _get_plot_by_id(plot_id: int) -> Dictionary:
	for plot in farm_plots:
		if plot.plot_id == plot_id:
			return plot
	return {}  # Return empty dict instead of null


# ==================== Public API ====================

## Get all farm plots
func get_all_plots() -> Array[Dictionary]:
	return farm_plots.duplicate()

## Get plots by status
func get_plots_by_status(status: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for plot in farm_plots:
		if plot.status == status:
			result.append(plot.duplicate())
	return result

## Get total food production potential
func get_total_food_potential() -> int:
	var total: int = 0
	for plot in farm_plots:
		if plot.status == "ready":
			var config: Dictionary = CROP_CONFIG[plot.crop_type]
			total += config.nutrition * plot.yield_quantity
	return total

## Get crop statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_plots": farm_plots.size(),
		"planted": 0,
		"growing": 0,
		"ready": 0,
		"withered": 0,
		"harvested": 0,
		"total_potential_yield": 0
	}
	
	for plot in farm_plots:
		var status: String = plot.status
		if status in stats:
			stats[status] += 1
		
		if plot.status == "ready":
			stats.total_potential_yield += plot.yield_quantity
	
	return stats

## Check if a tile has a farm plot
func has_plot_at_tile(tile: Vector2i) -> bool:
	for plot in farm_plots:
		if plot.tile == tile:
			return true
	return false

## Get plot at tile
func get_plot_at_tile(tile: Vector2i) -> Dictionary:
	for plot in farm_plots:
		if plot.tile == tile:
			return plot.duplicate()
	return {}

## Remove a farm plot (for building construction, etc.)
func remove_plot(plot_id: int) -> void:
	for i in range(farm_plots.size() - 1, -1, -1):
		if farm_plots[i].plot_id == plot_id:
			farm_plots.remove_at(i)
			return

## Debug: Add instant-growth farm plots (for testing)
func debug_add_ready_plots(count: int, crop_type: int = -1) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = GameManager.tick_count + 999
	
	for i in range(count):
		# Find random suitable tile
		var tile: Vector2i = Vector2i(rng.randi_range(0, 100), rng.randi_range(0, 100))
		if _is_suitable_farm_tile(tile) and not has_plot_at_tile(tile):
			var crop: int = crop_type if crop_type >= 0 else rng.randi() % 4
			var plot_id: int = create_farm_plot(tile, crop, -1)
			
			# Instant growth
			var plot: Dictionary = _get_plot_by_id(plot_id)
			if plot != null:
				plot.growth_progress = 1.0
				plot.status = "ready"
				var config: Dictionary = CROP_CONFIG[crop]
				plot.yield_quantity = config.base_yield
	
	print("[Farming] Debug: Added %d ready plots" % count)

## Debug: Clear all plots
func debug_clear_all() -> void:
	farm_plots.clear()
	_next_plot_id = 1
	print("[Farming] Debug: All plots cleared")
