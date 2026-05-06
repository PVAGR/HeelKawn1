extends Node
## BattleReporter - Records battles to WorldMemory for history
##
## Features:
## - Battle reports saved to WorldMemory
## - Witnessed heroism/cowardice tracking
## - War memory affecting settlements, families, grudges
## - Casualty notifications to families
## - Memorial markers for significant battles

# Battle report data structure
## {
##   "battle_id": int,
##   "name": String,
##   "location": Vector2i,
##   "tick": int,
##   "duration_ticks": int,
##   "attackers": Array[int],  # pawn_ids or squad_ids
##   "defenders": Array[int],
##   "victor": String,  # "attacker", "defender", "draw"
##   "casualties": Dictionary,
##   "heroism": Array[Dictionary],
##   "cowardice": Array[Dictionary],
##   "significance": int,  # 1-10 scale
##   "memorial_marker": bool
## }
var battle_reports: Array[Dictionary] = []
var _next_battle_id: int = 1

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null
@onready var _grudge_manager: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_grudge_manager = get_node_or_null("/root/GrudgeManager")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


# ==================== BATTLE RECORDING ====================

## Start recording a battle
func start_battle(attacker_ids: Array[int], defender_ids: Array[int], 
 location: Vector2i, battle_name: String = "") -> int:
	
	if battle_name == "":
		battle_name = _generate_battle_name(location)
	
	var battle: Dictionary = {
		"battle_id": _next_battle_id,
		"name": battle_name,
		"location": location,
		"start_tick": GameManager.tick_count,
		"duration_ticks": 0,
		"attackers": attacker_ids,
		"defenders": defender_ids,
		"victor": "",
		"casualties": {
			"attackers_kia": 0,
			"attackers_wia": 0,
			"defenders_kia": 0,
			"defenders_wia": 0
		},
		"heroism": [],
		"cowardice": [],
		"significance": 1,
		"memorial_marker": false,
		"completed": false
	}
	
	battle_reports.append(battle)
	_next_battle_id += 1
	
	# Record battle start
	if _world_memory != null:
		_world_memory.record_event({
			"type": "battle_started",
			"battle_id": battle.battle_id,
			"name": battle.name,
			"location": {"x": location.x, "y": location.y},
			"attackers": attacker_ids.size(),
			"defenders": defender_ids.size(),
			"tick": GameManager.tick_count
		})
	
	return battle.battle_id


## Record casualty in battle
func record_casualty(battle_id: int, pawn_id: int, side: String, 
 casualty_type: String) -> void:
	# side: "attacker" or "defender"
	# casualty_type: "kia" (killed in action) or "wia" (wounded in action)
	
	var battle: Dictionary = _get_battle(battle_id)
	if battle == null or battle.completed:
		return
	
	var casualty_key: String = "%s_%s" % [side, casualty_type]
	if battle.casualties.has(casualty_key):
		battle.casualties[casualty_key] += 1
	
	# Record individual casualty
	if casualty_type == "kia":
		_notify_family_of_death(pawn_id, battle)


## Record act of heroism
func record_heroism(battle_id: int, pawn_id: int, description: String, 
 significance: int = 5) -> void:
	var battle: Dictionary = _get_battle(battle_id)
	if battle == null:
		return
	
	battle.heroism.append({
		"pawn_id": pawn_id,
		"description": description,
		"significance": significance,
		"tick": GameManager.tick_count
	})
	
	# Update battle significance
	battle.significance = maxi(battle.significance, significance)
	
	# Record heroism
	if _world_memory != null:
		_world_memory.record_event({
			"type": "battle_heroism",
			"battle_id": battle_id,
			"pawn_id": pawn_id,
			"description": description,
			"significance": significance,
			"tick": GameManager.tick_count
		})


## Record act of cowardice
func record_cowardice(battle_id: int, pawn_id: int, description: String, 
 significance: int = 3) -> void:
	var battle: Dictionary = _get_battle(battle_id)
	if battle == null:
		return
	
	battle.cowardice.append({
		"pawn_id": pawn_id,
		"description": description,
		"significance": significance,
		"tick": GameManager.tick_count
	})
	
	# Record cowardice
	if _world_memory != null:
		_world_memory.record_event({
			"type": "battle_cowardice",
			"battle_id": battle_id,
			"pawn_id": pawn_id,
			"description": description,
			"tick": GameManager.tick_count
		})


## End battle with victor
func end_battle(battle_id: int, victor: String) -> void:
	var battle: Dictionary = _get_battle(battle_id)
	if battle == null or battle.completed:
		return
	
	battle.completed = true
	battle.victor = victor
	battle.duration_ticks = GameManager.tick_count - battle.start_tick
	
	# Calculate significance based on casualties and participants
	battle.significance = _calculate_battle_significance(battle)
	
	# Create memorial for significant battles
	if battle.significance >= 7:
		battle.memorial_marker = true
		_create_memorial(battle)
	
	# Apply war memory to settlements
	_apply_war_memory(battle)
	
	# Record battle end
	if _world_memory != null:
		_world_memory.record_event({
			"type": "battle_ended",
			"battle_id": battle_id,
			"name": battle.name,
			"victor": victor,
			"duration": battle.duration_ticks,
			"casualties": battle.casualties,
			"significance": battle.significance,
			"tick": GameManager.tick_count
		})
	
	# Record full battle log
	_record_full_battle_log(battle)


# ==================== MEMORY SYSTEM ====================

func _apply_war_memory(battle: Dictionary) -> void:
	# Create grudges between opposing sides
	if _grudge_manager != null and _grudge_manager.has_method("record_grudge"):
		for attacker_id in battle.attackers:
			for defender_id in battle.defenders:
				var grudge_type: String = "battle_" + battle.victor
				_grudge_manager.record_grudge(attacker_id, defender_id, 
					grudge_type, battle.battle_id, "battle", battle.start_tick)
	
	# Affect settlement morale/reputation
	if _settlement_memory != null:
		# TODO: Apply battle effects to nearby settlements
		pass


func _create_memorial(battle: Dictionary) -> void:
	# Create a memorial marker at battle location
	# This could be a physical marker or just a memory marker
	
	if _world_memory != null:
		_world_memory.record_event({
			"type": "memorial_created",
			"battle_id": battle.battle_id,
			"battle_name": battle.name,
			"location": {"x": battle.location.x, "y": battle.location.y},
			"casualties": battle.casualties.defenders_kia + battle.casualties.attackers_kia,
			"tick": GameManager.tick_count
		})


func _notify_family_of_death(pawn_id: int, battle: Dictionary) -> void:
	# Notify family members of death
	if _pawn_spawner == null or not _pawn_spawner.has_method("pawn_data_for_id"):
		return
	
	var pawn_data: Node = _pawn_spawner.call("pawn_data_for_id", pawn_id)
	if pawn_data == null:
		return

	# Get family members
	var family: Array = []
	if pawn_data.has_meta("family_members"):
		family = pawn_data.get_meta("family_members")

	for family_id in family:
		if _world_memory != null:
			_world_memory.record_event({
				"type": "family_death_notification",
				"deceased_id": pawn_id,
				"family_id": family_id,
				"battle_id": battle.battle_id,
				"battle_name": battle.name,
				"tick": GameManager.tick_count
			})


# ==================== UTILITY ====================

func _get_battle(battle_id: int) -> Dictionary:
	for battle in battle_reports:
		if battle.battle_id == battle_id:
			return battle
	return {}


func _generate_battle_name(location: Vector2i) -> String:
	# Generate battle name based on location
	return "Battle at (%d, %d)" % [location.x, location.y]


func _calculate_battle_significance(battle: Dictionary) -> int:
	var total_casualties: int = (
		battle.casualties.attackers_kia +
		battle.casualties.attackers_wia +
		battle.casualties.defenders_kia +
		battle.casualties.defenders_wia
	)
	
	var total_participants: int = battle.attackers.size() + battle.defenders.size()
	
	# Base significance from casualties
	var significance: int = 1
	if total_casualties > 5:
		significance = 3
	if total_casualties > 20:
		significance = 5
	if total_casualties > 50:
		significance = 7
	if total_casualties > 100:
		significance = 9
	
	# Bonus for heroism
	if battle.heroism.size() > 0:
		significance += 1
	
	# Bonus for participants
	if total_participants > 20:
		significance += 1
	if total_participants > 50:
		significance += 2
	
	return mini(10, significance)


func _record_full_battle_log(battle: Dictionary) -> void:
	# Create comprehensive battle log for historical record
	var log: PackedStringArray = []
	
	log.append("=== BATTLE REPORT ===")
	log.append("Name: %s" % battle.name)
	log.append("ID: %d" % battle.battle_id)
	log.append("Location: (%d, %d)" % [battle.location.x, battle.location.y])
	log.append("Victor: %s" % battle.victor)
	log.append("Duration: %d ticks" % battle.duration_ticks)
	log.append("")
	log.append("CASUALTIES:")
	log.append("  Attackers KIA: %d" % battle.casualties.attackers_kia)
	log.append("  Attackers WIA: %d" % battle.casualties.attackers_wia)
	log.append("  Defenders KIA: %d" % battle.casualties.defenders_kia)
	log.append("  Defenders WIA: %d" % battle.casualties.defenders_wia)
	log.append("")
	
	if battle.heroism.size() > 0:
		log.append("HEROISM:")
		for act in battle.heroism:
			log.append("  - Pawn %d: %s" % [act.pawn_id, act.description])
		log.append("")
	
	if battle.cowardice.size() > 0:
		log.append("COWARDICE:")
		for act in battle.cowardice:
			log.append("  - Pawn %d: %s" % [act.pawn_id, act.description])
		log.append("")
	
	log.append("Significance: %d/10" % battle.significance)
	log.append("Memorial: %s" % ("Yes" if battle.memorial_marker else "No"))
	log.append("====================")
	
	var full_log: String = "\n".join(log)
	
	# Store in WorldMemory
	if _world_memory != null:
		_world_memory.record_event({
			"type": "battle_report",
			"battle_id": battle.battle_id,
			"log": full_log,
			"tick": GameManager.tick_count
		})


# ==================== PUBLIC API ====================

## Get battle report
func get_battle_report(battle_id: int) -> Dictionary:
	var battle: Dictionary = _get_battle(battle_id)
	if battle == null:
		return {}
	return battle.duplicate()

## Get all battle reports
func get_all_battle_reports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle in battle_reports:
		result.append(battle.duplicate())
	return result

## Get battles by significance
func get_significant_battles(min_significance: int = 7) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle in battle_reports:
		if battle.significance >= min_significance:
			result.append(battle.duplicate())
	return result

## Get battles near a location
func get_battles_near(location: Vector2i, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle in battle_reports:
		var dist: float = battle.location.distance_to(location)
		if dist <= radius:
			result.append(battle.duplicate())
	return result

## Clear all data (for world reroll)
func clear() -> void:
	battle_reports.clear()
	_next_battle_id = 1

## Get statistics
func get_stats() -> Dictionary:
	var total_battles: int = battle_reports.size()
	var total_casualties: int = 0
	var total_heroism: int = 0
	var significant_battles: int = 0
	
	for battle in battle_reports:
		total_casualties += (
			battle.casualties.attackers_kia +
			battle.casualties.attackers_wia +
			battle.casualties.defenders_kia +
			battle.casualties.defenders_wia
		)
		total_heroism += battle.heroism.size()
		if battle.significance >= 7:
			significant_battles += 1
	
	return {
		"total_battles": total_battles,
		"total_casualties": total_casualties,
		"total_heroism": total_heroism,
		"total_cowardice": battle_reports.reduce(func(acc, b): return acc + b.cowardice.size(), 0),
		"significant_battles": significant_battles,
		"memorials": battle_reports.filter(func(b): return b.memorial_marker).size()
	}
