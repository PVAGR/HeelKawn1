extends Node
## WarProductionSystem — DSS War Party-style autonomous war production.
## Combines city building for war efforts with relentless soldier production.
## Features:
## - Production chains for weapons and equipment
## - Worker priority queues for war manufacturing
## - Automatic army recruitment from settlements
## - Resource flow management to war effort
## - Scalable from 1 to 10,000+ entities
##
## Design principles:
## - Set-and-watch autonomy (WorldBox-style)
## - Active production chains (DSS War Party)
## - Deterministic simulation
## - CPU-efficient for large entity counts

# ============================================================
# CONSTANTS
# ============================================================

## Production chain types
enum ProductionChain {
	NONE,
	WEAPONS,      # Spears, swords, bows
	ARMOR,        # Leather, hide armor
	SHIELDS,      # Wooden shields
	SIEGE,        # Battering rams, towers
	SUPPLIES,     # Food packs for armies
	RECRUITMENT,  # Training new soldiers
}

const CHAIN_NAMES: Dictionary = {
	ProductionChain.NONE: "None",
	ProductionChain.WEAPONS: "Weapons",
	ProductionChain.ARMOR: "Armor",
	ProductionChain.SHIELDS: "Shields",
	ProductionChain.SIEGE: "Siege",
	ProductionChain.SUPPLIES: "Supplies",
	ProductionChain.RECRUITMENT: "Recruitment",
}

## Production priorities (higher = more urgent)
const PRIORITY_EMERGENCY: int = 100
const PRIORITY_HIGH: int = 75
const PRIORITY_NORMAL: int = 50
const PRIORITY_LOW: int = 25

## How often to check production needs (ticks)
const PRODUCTION_CHECK_INTERVAL: int = 200

## How often to recruit soldiers (ticks)
const RECRUITMENT_INTERVAL: int = 500

## Base production time per item (ticks)
const PRODUCTION_TIMES: Dictionary = {
	"wooden_spear": 120,
	"stone_axe": 180,
	"flint_knife": 90,
	"wooden_bow": 240,
	"leather_armor": 300,
	"hide_shield": 150,
	"wooden_shield": 100,
	"food_pack": 60,
	"recruit_train": 600,
}

## Resource requirements per item
const RESOURCE_REQUIREMENTS: Dictionary = {
	"wooden_spear": {"wood": 2, "flint": 1},
	"stone_axe": {"wood": 1, "stone": 2, "flint": 1},
	"flint_knife": {"wood": 1, "flint": 2},
	"wooden_bow": {"wood": 3, "hide": 1},
	"leather_armor": {"hide": 3, "bone": 1},
	"hide_shield": {"hide": 2, "wood": 1},
	"wooden_shield": {"wood": 3},
	"food_pack": {"food": 5},
}

## Soldier equipment loadouts
const SOLDIER_LOADOUTS: Dictionary = {
	"militia": ["wooden_spear"],
	"warrior": ["stone_axe", "hide_shield"],
	"archer": ["wooden_bow", "flint_knife"],
	"veteran": ["stone_axe", "leather_armor", "wooden_shield"],
}

# ============================================================
# STATE
# ============================================================

## settlement_id -> production queue
var _production_queues: Dictionary = {}

## settlement_id -> active workers on war production
var _war_workers: Dictionary = {}

## settlement_id -> current production chain specialization
var _chain_specializations: Dictionary = {}

## Global war production stats
var _total_items_produced: int = 0
var _total_soldiers_recruited: int = 0
var _production_failures: int = 0

## Last update ticks
var _last_production_check: int = -999999
var _last_recruitment: int = -999999

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Check production needs
	if tick - _last_production_check >= PRODUCTION_CHECK_INTERVAL:
		_last_production_check = tick
		_update_production_queues(tick)
	
	# Process recruitment
	if tick - _last_recruitment >= RECRUITMENT_INTERVAL:
		_last_recruitment = tick
		_process_recruitment(tick)
	
	# Update worker assignments
	_update_war_workers(tick)


# ============================================================
# PRODUCTION QUEUE MANAGEMENT
# ============================================================

func _update_production_queues(tick: int) -> void:
	"""Update production queues based on war demands."""
	if SettlementMemory == null or StockpileManager == null:
		return
	
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		
		var pop: int = int(st.get("population", 0))
		if pop <= 0:
			continue
		
		# Initialize queue if needed
		if not _production_queues.has(center):
			_production_queues[center] = []
		
		var queue: Array = _production_queues[center]
		
		# Determine production priorities based on threat level and stockpiles
		var threat_level: float = _calculate_threat_level(st, tick)
		var stockpiles: Dictionary = _get_settlement_stockpiles(center)
		
		# Clear completed/obsolete jobs
		queue = _prune_queue(queue, stockpiles, tick)
		
		# Add new production jobs based on needs
		_add_production_jobs(queue, stockpiles, threat_level, st, tick)
		
		_production_queues[center] = queue


func _calculate_threat_level(settlement: Dictionary, tick: int) -> float:
	"""Calculate threat level for a settlement (0.0-1.0)."""
	var center: int = int(settlement.get("center_region", -1))
	var scar_count: int = int(settlement.get("scar_max", 0))
	
	# Check nearby hostile nations
	var nearby_hostiles: int = 0
	if NationBorderSystem != null:
		var my_nation: int = NationBorderSystem.get_nation_at_region(center)
		for rk in range(maxi(0, center - 5), mini(1000, center + 5)):
			var other_nation: int = NationBorderSystem.get_nation_at_region(rk)
			if other_nation >= 0 and other_nation != my_nation:
				if NationBorderSystem.are_nations_at_war(my_nation, other_nation):
					nearby_hostiles += 1
	
	# Calculate threat score
	var threat: float = 0.0
	threat += clampf(float(scar_count) / 10.0, 0.0, 0.4)
	threat += clampf(float(nearby_hostiles) / 3.0, 0.0, 0.6)
	
	return clampf(threat, 0.0, 1.0)


func _get_settlement_stockpiles(center: int) -> Dictionary:
	"""Get current stockpile levels for a settlement."""
	var stockpiles: Dictionary = {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"flint": 0,
		"hide": 0,
		"bone": 0,
		"weapons": 0,
		"armor": 0,
		"shields": 0,
	}
	
	if StockpileManager == null:
		return stockpiles
	
	# Find settlement regions
	var settlement: Dictionary = {}
	for st_v in SettlementMemory.settlements:
		if (st_v is Dictionary) and int(st_v.get("center_region", -1)) == center:
			settlement = st_v
			break
	
	if settlement.is_empty():
		return stockpiles
	
	var regions: Variant = settlement.get("regions", null)
	if not (regions is PackedInt32Array):
		return stockpiles
	
	# Scan stockpiles in settlement regions
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		var zt: Vector2i = z.tile
		var rk_z: int = WorldMemory._region_key(zt.x, zt.y)
		if not (rk_z in (regions as PackedInt32Array)):
			continue
		
		for t in z.inventory:
			var q: int = int(z.inventory[t])
			if t == Item.Type.WOOD:
				stockpiles["wood"] += q
			elif t == Item.Type.STONE:
				stockpiles["stone"] += q
			elif Item.is_food(t):
				stockpiles["food"] += q
			elif t == Item.Type.FLINT:
				stockpiles["flint"] += q
			elif t == Item.Type.HIDE:
				stockpiles["hide"] += q
			elif t == Item.Type.BONE:
				stockpiles["bone"] += q
	
	return stockpiles


func _prune_queue(queue: Array, stockpiles: Dictionary, tick: int) -> Array:
	"""Remove completed or unnecessary jobs from queue."""
	var pruned: Array = []
	for job in queue:
		if not (job is Dictionary):
			continue
		var job_dict: Dictionary = job as Dictionary
		var item_type: String = str(job_dict.get("item_type", ""))
		var status: String = str(job_dict.get("status", "pending"))
		
		# Remove completed jobs
		if status == "completed":
			continue
		
		# Remove jobs for items we now have enough of
		if status == "pending" and _have_sufficient_stock(item_type, stockpiles):
			continue
		
		pruned.append(job)
	
	return pruned


func _have_sufficient_stock(item_type: String, stockpiles: Dictionary) -> bool:
	"""Check if we have enough of an item type."""
	match item_type:
		"wooden_spear", "stone_axe", "flint_knife", "wooden_bow":
			return int(stockpiles.get("weapons", 0)) >= 20
		"leather_armor":
			return int(stockpiles.get("armor", 0)) >= 10
		"hide_shield", "wooden_shield":
			return int(stockpiles.get("shields", 0)) >= 15
		"food_pack":
			return int(stockpiles.get("food", 0)) >= 100
	return false


func _add_production_jobs(queue: Array, stockpiles: Dictionary, threat_level: float, 
						  settlement: Dictionary, tick: int) -> void:
	"""Add new production jobs based on needs and threats."""
	var center: int = int(settlement.get("center_region", -1))
	var pop: int = int(settlement.get("population", 0))
	
	# Determine production focus based on specialization
	var specialization: String = str(_chain_specializations.get(center, "mixed"))
	
	# Queue size limits based on population
	var max_queue_size: int = maxi(5, pop * 2)
	
	# Add weapon production if threatened or low on weapons
	if threat_level > 0.3 or int(stockpiles.get("weapons", 0)) < 10:
		var weapon_priority: int = int(PRIORITY_NORMAL + threat_level * 50.0)
		if int(stockpiles.get("wood", 0)) >= 2 and int(stockpiles.get("flint", 0)) >= 1:
			_add_job_to_queue(queue, "wooden_spear", weapon_priority, tick)
		if int(stockpiles.get("wood", 0)) >= 1 and int(stockpiles.get("stone", 0)) >= 2:
			_add_job_to_queue(queue, "stone_axe", weapon_priority, tick)
	
	# Add armor/shields if heavily threatened
	if threat_level > 0.5:
		var defense_priority: int = PRIORITY_HIGH
		if int(stockpiles.get("hide", 0)) >= 3:
			_add_job_to_queue(queue, "leather_armor", defense_priority, tick)
		if int(stockpiles.get("wood", 0)) >= 3:
			_add_job_to_queue(queue, "wooden_shield", defense_priority, tick)
	
	# Add food supplies for armies
	if threat_level > 0.4 or int(stockpiles.get("food", 0)) < 50:
		var supply_priority: int = PRIORITY_NORMAL
		if int(stockpiles.get("food", 0)) >= 5:
			_add_job_to_queue(queue, "food_pack", supply_priority, tick)
	
	# Specialization bonuses
	match specialization:
		"weapons":
			if queue.size() < max_queue_size and int(stockpiles.get("wood", 0)) >= 2:
				_add_job_to_queue(queue, "wooden_bow", PRIORITY_LOW, tick)
		"defense":
			if queue.size() < max_queue_size and int(stockpiles.get("hide", 0)) >= 2:
				_add_job_to_queue(queue, "hide_shield", PRIORITY_LOW, tick)


func _add_job_to_queue(queue: Array, item_type: String, priority: int, tick: int) -> void:
	"""Add a production job to the queue."""
	# Check if similar job already pending
	for job in queue:
		if (job is Dictionary) and str(job.get("item_type", "")) == item_type and str(job.get("status", "")) == "pending":
			return  # Already queued
	
	queue.append({
		"item_type": item_type,
		"priority": priority,
		"status": "pending",
		"queued_tick": tick,
		"progress": 0,
		"production_time": PRODUCTION_TIMES.get(item_type, 120),
	})
	
	# Sort by priority (highest first)
	queue.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))


# ============================================================
# WORKER MANAGEMENT
# ============================================================

func _update_war_workers(tick: int) -> void:
	"""Assign workers to production tasks."""
	if SettlementMemory == null or JobManager == null:
		return
	
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		
		var pop: int = int(st.get("population", 0))
		if pop <= 0:
			continue
		
		# Initialize worker tracking
		if not _war_workers.has(center):
			_war_workers[center] = {
				"assigned": 0,
				"max_workers": maxi(1, pop / 4),  # 25% of pop can work on war production
				"active_jobs": [],
			}
		
		var worker_data: Dictionary = _war_workers[center]
		var queue: Array = _production_queues.get(center, [])
		
		# Assign workers to pending jobs
		var available_workers: int = worker_data["max_workers"] - worker_data["assigned"]
		if available_workers > 0 and queue.size() > 0:
			_assign_workers_to_jobs(center, queue, worker_data, available_workers, tick)


func _assign_workers_to_jobs(center: int, queue: Array, worker_data: Dictionary, 
							 available_workers: int, tick: int) -> void:
	"""Assign workers to pending production jobs."""
	for job in queue:
		if available_workers <= 0:
			break
		if not (job is Dictionary):
			continue
		
		var job_dict: Dictionary = job as Dictionary
		if str(job_dict.get("status", "")) != "pending":
			continue
		
		# Mark job as in progress
		job_dict["status"] = "in_progress"
		job_dict["worker_count"] = mini(available_workers, 3)  # Max 3 workers per job
		job_dict["started_tick"] = tick
		
		worker_data["assigned"] += job_dict["worker_count"]
		worker_data["active_jobs"].append(job_dict)
		
		# Post actual jobs to JobManager for resource gathering
		var item_type: String = str(job_dict.get("item_type", ""))
		if RESOURCE_REQUIREMENTS.has(item_type):
			var requirements: Dictionary = RESOURCE_REQUIREMENTS[item_type]
			for resource in requirements.keys():
				var amount: int = int(requirements[resource])
				_post_gathering_job(center, resource, amount, tick)


func _post_gathering_job(center: int, resource: String, amount: int, tick: int) -> void:
	"""Post a gathering job to JobManager."""
	# This would integrate with the existing JobManager system
	# For now, we just track it internally
	pass


# ============================================================
# RECRUITMENT SYSTEM
# ============================================================

func _process_recruitment(tick: int) -> void:
	"""Process soldier recruitment from settlements."""
	if SettlementMemory == null:
		return
	
	var pm := get_node_or_null("/root/PawnManager")
	if pm == null or not pm.has_method("get_pawn_count"):
		return
	
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		
		var pop: int = int(st.get("population", 0))
		if pop < 3:  # Need minimum population
			continue
		
		# Check threat level and existing military
		var threat_level: float = _calculate_threat_level(st, tick)
		var existing_soldiers: int = _count_settlement_soldiers(st)
		
		# Determine how many soldiers to recruit
		var target_soldiers: int = int(pop * 0.3)  # 30% of pop as soldiers
		if threat_level > 0.7:
			target_soldiers = int(pop * 0.5)  # 50% in emergencies
		
		if existing_soldiers < target_soldiers:
			_recruit_soldiers(st, target_soldiers - existing_soldiers, tick)


func _count_settlement_soldiers(settlement: Dictionary) -> int:
	"""Count existing soldiers in a settlement."""
	# This would query the ArmyBattleSystem for soldiers assigned to this settlement
	# For now, return placeholder
	return 0


func _recruit_soldiers(settlement: Dictionary, count: int, tick: int) -> void:
	"""Recruit new soldiers from a settlement."""
	var center: int = int(settlement.get("center_region", -1))
	var pop: int = int(settlement.get("population", 0))
	
	# Check equipment availability
	var stockpiles: Dictionary = _get_settlement_stockpiles(center)
	var soldiers_to_recruit: int = mini(count, pop - 2)  # Keep at least 2 civilians
	
	for i in range(soldiers_to_recruit):
		# Determine loadout based on available equipment
		var loadout: String = "militia"
		if int(stockpiles.get("weapons", 0)) > 5 and int(stockpiles.get("shields", 0)) > 2:
			loadout = "warrior"
		elif int(stockpiles.get("weapons", 0)) > 3:
			loadout = "archer"
		
		# Create soldier pawn (would integrate with PawnManager)
		_create_soldier_pawn(settlement, loadout, tick)
		
		_total_soldiers_recruited += 1


func _create_soldier_pawn(settlement: Dictionary, loadout: String, tick: int) -> void:
	"""Create a new soldier pawn."""
	# This would integrate with PawnManager to create a trained soldier
	# For now, placeholder
	pass


# ============================================================
# PRODUCTION EXECUTION
# ============================================================

func process_production_progress(tick: int) -> void:
	"""Process ongoing production and complete finished items."""
	for center in _production_queues.keys():
		var queue: Array = _production_queues[center]
		var worker_data: Dictionary = _war_workers.get(center, {})
		
		for job in queue:
			if not (job is Dictionary):
				continue
			var job_dict: Dictionary = job as Dictionary
			if str(job_dict.get("status", "")) != "in_progress":
				continue
			
			# Update progress
			var started_tick: int = int(job_dict.get("started_tick", tick))
			var production_time: int = int(job_dict.get("production_time", 120))
			var elapsed: int = tick - started_tick
			
			job_dict["progress"] = clampf(float(elapsed) / float(production_time), 0.0, 1.0)
			
			# Complete if finished
			if job_dict["progress"] >= 1.0:
				_complete_production_job(center, job_dict, tick)


func _complete_production_job(center: int, job_dict: Dictionary, tick: int) -> void:
	"""Complete a production job and add item to stockpile."""
	var item_type: String = str(job_dict.get("item_type", ""))
	
	# Add to stockpile (would integrate with StockpileManager)
	_add_item_to_stockpile(center, item_type, 1)
	
	job_dict["status"] = "completed"
	job_dict["completed_tick"] = tick
	
	_total_items_produced += 1
	
	# Update worker availability
	var worker_data: Dictionary = _war_workers.get(center, {})
	if worker_data.has("active_jobs"):
		var worker_count: int = int(job_dict.get("worker_count", 1))
		worker_data["assigned"] = maxi(0, worker_data["assigned"] - worker_count)
		worker_data["active_jobs"].erase(job_dict)


func _add_item_to_stockpile(center: int, item_type: String, quantity: int) -> void:
	"""Add produced item to settlement stockpile."""
	# This would integrate with StockpileManager
	# For now, placeholder
	pass


# ============================================================
# SPECIALIZATION MANAGEMENT
# ============================================================

func set_settlement_specialization(center: int, specialization: String) -> void:
	"""Set a settlement's production specialization."""
	_chain_specializations[center] = specialization


func get_settlement_specialization(center: int) -> String:
	"""Get a settlement's production specialization."""
	return str(_chain_specializations.get(center, "mixed"))


# ============================================================
# DEBUG / STATS
# ============================================================

func get_production_stats() -> Dictionary:
	"""Get production statistics."""
	return {
		"total_items_produced": _total_items_produced,
		"total_soldiers_recruited": _total_soldiers_recruited,
		"production_failures": _production_failures,
		"active_queues": _production_queues.size(),
		"total_war_workers": _sum_war_workers(),
	}


func _sum_war_workers() -> int:
	"""Sum total war workers across all settlements."""
	var total: int = 0
	for center in _war_workers.keys():
		total += int(_war_workers[center].get("assigned", 0))
	return total


func get_queue_status(center: int) -> Array:
	"""Get production queue status for a settlement."""
	return _production_queues.get(center, []).duplicate()
