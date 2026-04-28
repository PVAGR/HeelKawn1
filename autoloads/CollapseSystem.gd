extends Node
## HEELKAWN Collapse Progression - Collapse is slow, systemic, and human.
## Default order: trust → authority → knowledge → environment.

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var KnowledgeSystem = get_node_or_null("/root/KnowledgeSystem")

enum CollapseStage {
	STABLE = 0,
	TRUST_DECAY = 1,
	AUTHORITY_DECAY = 2,
	KNOWLEDGE_DECAY = 3,
	ENVIRONMENTAL_DECAY = 4,
	COLLAPSED = 5
}

## Collapse metrics per settlement: settlement_id -> metrics
var collapse_metrics: Dictionary = {}

## Collapse signs detected: settlement_id -> Array of signs
var collapse_signs: Dictionary = {}

## Collapse history: record of collapse events
var collapse_history: Array[Dictionary] = []

## Post-collapse survivors: what survived collapse
var collapse_survivors: Dictionary = {}

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	if tick % 5000 == 0:
		_update_collapse_metrics()
	if tick % 10000 == 0:
		_detect_collapse_signs()
		_evaluate_collapse_stage()

# === Collapse Metrics ===

func initialize_settlement_metrics(settlement_id: int) -> void:
	collapse_metrics[settlement_id] = {
		"trust_level": 1.0,
		"authority_stability": 1.0,
		"knowledge_retention": 1.0,
		"environmental_health": 1.0,
		"stage": CollapseStage.STABLE
	}
	collapse_signs[settlement_id] = []

func update_trust_level(settlement_id: int, delta: float) -> void:
	if not collapse_metrics.has(settlement_id):
		initialize_settlement_metrics(settlement_id)
	
	var metrics: Dictionary = collapse_metrics[settlement_id]
	metrics["trust_level"] = clamp(metrics["trust_level"] + delta, 0.0, 1.0)
	_record_trust_change(settlement_id, delta)
	_notify_world_ai_collapse_metric_change(settlement_id, "trust_level", metrics["trust_level"])

func update_authority_stability(settlement_id: int, delta: float) -> void:
	if not collapse_metrics.has(settlement_id):
		initialize_settlement_metrics(settlement_id)
	
	var metrics: Dictionary = collapse_metrics[settlement_id]
	metrics["authority_stability"] = clamp(metrics["authority_stability"] + delta, 0.0, 1.0)
	_record_authority_change(settlement_id, delta)
	_notify_world_ai_collapse_metric_change(settlement_id, "authority_stability", metrics["authority_stability"])

func update_knowledge_retention(settlement_id: int, delta: float) -> void:
	if not collapse_metrics.has(settlement_id):
		initialize_settlement_metrics(settlement_id)
	
	var metrics: Dictionary = collapse_metrics[settlement_id]
	metrics["knowledge_retention"] = clamp(metrics["knowledge_retention"] + delta, 0.0, 1.0)
	_record_knowledge_change(settlement_id, delta)
	_notify_world_ai_collapse_metric_change(settlement_id, "knowledge_retention", metrics["knowledge_retention"])

func update_environmental_health(settlement_id: int, delta: float) -> void:
	if not collapse_metrics.has(settlement_id):
		initialize_settlement_metrics(settlement_id)
	
	var metrics: Dictionary = collapse_metrics[settlement_id]
	metrics["environmental_health"] = clamp(metrics["environmental_health"] + delta, 0.0, 1.0)
	_record_environmental_change(settlement_id, delta)
	_notify_world_ai_collapse_metric_change(settlement_id, "environmental_health", metrics["environmental_health"])

# === Collapse Signs Detection ===

func _detect_collapse_signs() -> void:
	# Analyze WorldMemory for collapse signs
	var events: Array = WorldMemory.to_save_dict().get("events", [])
	var recent_events: Array = []
	var current_tick: int = GameManager.tick_count
	
	# Get events from last 10000 ticks
	for event in events:
		if event.get("tick", 0) > current_tick - 10000:
			recent_events.append(event)
	
	# Detect signs per settlement
	for settlement_id in collapse_metrics:
		var signs: Array = []
		
		# Trust collapse signs
		if _has_hospitality_violations(recent_events, settlement_id):
			signs.append("broken_hospitality")
		if _has_stranger_fear(recent_events, settlement_id):
			signs.append("fear_of_strangers")
		if _has_hoarding(recent_events, settlement_id):
			signs.append("hoarding")
		
		# Authority collapse signs
		if _has_failed_teaching(recent_events, settlement_id):
			signs.append("failed_teaching")
		if _has_repair_knowledge_loss(recent_events, settlement_id):
			signs.append("loss_of_repair_knowledge")
		if _has_poor_succession(recent_events, settlement_id):
			signs.append("poor_succession")
		
		# Knowledge collapse signs
		if _has_weak_storage(recent_events, settlement_id):
			signs.append("weak_storage")
		if _has_repeated_starvation(recent_events, settlement_id):
			signs.append("repeated_starvation")
		if _has_abandoned_children(recent_events, settlement_id):
			signs.append("abandoned_children")
		
		# Environmental collapse signs
		if _has_shattered_roads(recent_events, settlement_id):
			signs.append("shattered_roads")
		if _has_unkept_graves(recent_events, settlement_id):
			signs.append("unkept_graves")
		if _has_derelict_hearths(recent_events, settlement_id):
			signs.append("derelict_hearths")
		if _has_shrine_neglect(recent_events, settlement_id):
			signs.append("shrine_neglect")
		
		collapse_signs[settlement_id] = signs
		
		# Update metrics based on signs
		_apply_sign_impact(settlement_id, signs)

func _apply_sign_impact(settlement_id: int, signs: Array) -> void:
	var trust_impact: float = 0.0
	var authority_impact: float = 0.0
	var knowledge_impact: float = 0.0
	var environmental_impact: float = 0.0
	
	for sign in signs:
		match sign:
			"broken_hospitality", "fear_of_strangers", "hoarding":
				trust_impact -= 0.1
			"failed_teaching", "loss_of_repair_knowledge", "poor_succession":
				authority_impact -= 0.1
			"weak_storage", "repeated_starvation", "abandoned_children":
				knowledge_impact -= 0.1
			"shattered_roads", "unkept_graves", "derelict_hearths", "shrine_neglect":
				environmental_impact -= 0.1
	
	if trust_impact != 0.0:
		update_trust_level(settlement_id, trust_impact)
	if authority_impact != 0.0:
		update_authority_stability(settlement_id, authority_impact)
	if knowledge_impact != 0.0:
		update_knowledge_retention(settlement_id, knowledge_impact)
	if environmental_impact != 0.0:
		update_environmental_health(settlement_id, environmental_impact)
	
	# Record collapse signs in WorldMemory
	if not signs.is_empty():
		WorldMemory.record_event({
			"type": "collapse_sign_detected",
			"settlement_id": settlement_id,
			"tick": GameManager.tick_count,
			"signs": signs,
		})

# === Collapse Stage Evaluation ===

func _evaluate_collapse_stage() -> void:
	for settlement_id in collapse_metrics:
		var metrics: Dictionary = collapse_metrics[settlement_id]
		var trust: float = metrics["trust_level"]
		var authority: float = metrics["authority_stability"]
		var knowledge: float = metrics["knowledge_retention"]
		var environment: float = metrics["environmental_health"]
		
		var current_stage: CollapseStage = metrics["stage"]
		var new_stage: CollapseStage = current_stage
		
		# Determine collapse stage based on metrics
		if environment < 0.2:
			new_stage = CollapseStage.COLLAPSED
		elif knowledge < 0.3:
			new_stage = CollapseStage.ENVIRONMENTAL_DECAY
		elif authority < 0.3:
			new_stage = CollapseStage.KNOWLEDGE_DECAY
		elif trust < 0.4:
			new_stage = CollapseStage.AUTHORITY_DECAY
		elif trust < 0.7:
			new_stage = CollapseStage.TRUST_DECAY
		else:
			new_stage = CollapseStage.STABLE
		
		if new_stage != current_stage:
			metrics["stage"] = new_stage
			_record_stage_change(settlement_id, current_stage, new_stage)
			
			# Record stage transition in WorldMemory
			WorldMemory.record_event({
				"type": "collapse_stage_transition",
				"settlement_id": settlement_id,
				"tick": GameManager.tick_count,
				"from_stage": current_stage,
				"to_stage": new_stage,
			})
			
			if new_stage == CollapseStage.COLLAPSED:
				_handle_collapse(settlement_id)

func _handle_collapse(settlement_id: int) -> void:
	# Record what survives collapse
	var survivors: Dictionary = {
		"techniques": _count_surviving_techniques(settlement_id),
		"ruins": true,
		"stories": _count_surviving_stories(settlement_id),
		"protected_names": _count_protected_names(settlement_id),
		"bloodlines": _count_surviving_bloodlines(settlement_id),
		"sacred_sites": _count_sacred_sites(settlement_id)
	}
	collapse_survivors[settlement_id] = survivors
	
	_record_collapse_event(settlement_id, survivors)
	
	# Record collapse in WorldMemory
	WorldMemory.record_event({
		"type": "settlement_collapse",
		"settlement_id": settlement_id,
		"tick": GameManager.tick_count,
		"survivors": survivors,
	})

# === Helper Functions ===

func _has_hospitality_violations(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "hospitality_violation" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_stranger_fear(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "stranger_fear" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_hoarding(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "hoarding" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_failed_teaching(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "teaching_failure" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_repair_knowledge_loss(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "knowledge_loss" and event.get("knowledge_type") == "repair":
			return true
	return false

func _has_poor_succession(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "succession_failure" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_weak_storage(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "storage_failure" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_repeated_starvation(events: Array, settlement_id: int) -> bool:
	var starvation_count: int = 0
	for event in events:
		if event.get("type") == "starvation" and event.get("settlement_id") == settlement_id:
			starvation_count += 1
	return starvation_count >= 3

func _has_abandoned_children(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "abandonment" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_shattered_roads(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "road_decay" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_unkept_graves(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "grave_neglect" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_derelict_hearths(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "hearth_abandonment" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _has_shrine_neglect(events: Array, settlement_id: int) -> bool:
	for event in events:
		if event.get("type") == "shrine_neglect" and event.get("settlement_id") == settlement_id:
			return true
	return false

func _count_surviving_techniques(settlement_id: int) -> int:
	# Count techniques that survived collapse
	var count: int = 0
	if KnowledgeSystem:
		for k in KnowledgeSystem.KnowledgeType.values():
			if KnowledgeSystem.get_carrier_count(k) > 0:
				count += 1
	return count

func _count_surviving_stories(settlement_id: int) -> int:
	# Count stories preserved in WorldMemory
	var count: int = 0
	var events: Array = WorldMemory.to_save_dict().get("events", [])
	for event in events:
		if event.get("type") == "story_preservation":
			count += 1
	return count

func _count_protected_names(settlement_id: int) -> int:
	# Count protected names
	var count: int = 0
	var events: Array = WorldMemory.to_save_dict().get("events", [])
	for event in events:
		if event.get("type") == "name_protection":
			count += 1
	return count

func _count_surviving_bloodlines(settlement_id: int) -> int:
	# Count surviving bloodlines
	var count: int = 0
	var events: Array = WorldMemory.to_save_dict().get("events", [])
	for event in events:
		if event.get("type") == "bloodline_survival":
			count += 1
	return count

func _count_sacred_sites(settlement_id: int) -> int:
	# Count sacred/practical sites
	var count: int = 0
	var events: Array = WorldMemory.to_save_dict().get("events", [])
	for event in events:
		if event.get("type") in ["sacred_site", "practical_site"]:
			count += 1
	return count

func _update_collapse_metrics() -> void:
	# Natural decay of metrics over time
	for settlement_id in collapse_metrics:
		var metrics: Dictionary = collapse_metrics[settlement_id]
		var stage: CollapseStage = metrics["stage"]
		
		# Metrics decay faster in later collapse stages
		var decay_rate: float = 0.01
		match stage:
			CollapseStage.TRUST_DECAY:
				decay_rate = 0.02
			CollapseStage.AUTHORITY_DECAY:
				decay_rate = 0.03
			CollapseStage.KNOWLEDGE_DECAY:
				decay_rate = 0.04
			CollapseStage.ENVIRONMENTAL_DECAY:
				decay_rate = 0.05
		
		metrics["trust_level"] = max(metrics["trust_level"] - decay_rate, 0.0)
		metrics["authority_stability"] = max(metrics["authority_stability"] - decay_rate, 0.0)
		metrics["knowledge_retention"] = max(metrics["knowledge_retention"] - decay_rate, 0.0)
		metrics["environmental_health"] = max(metrics["environmental_health"] - decay_rate, 0.0)

# === Event Recording ===

func _record_trust_change(settlement_id: int, delta: float) -> void:
	var event: Dictionary = {
		"type": "trust_change",
		"settlement_id": settlement_id,
		"delta": delta,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_authority_change(settlement_id: int, delta: float) -> void:
	var event: Dictionary = {
		"type": "authority_change",
		"settlement_id": settlement_id,
		"delta": delta,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_knowledge_change(settlement_id: int, delta: float) -> void:
	var event: Dictionary = {
		"type": "knowledge_change",
		"settlement_id": settlement_id,
		"delta": delta,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_environmental_change(settlement_id: int, delta: float) -> void:
	var event: Dictionary = {
		"type": "environmental_change",
		"settlement_id": settlement_id,
		"delta": delta,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_stage_change(settlement_id: int, old_stage: CollapseStage, new_stage: CollapseStage) -> void:
	var record: Dictionary = {
		"settlement_id": settlement_id,
		"old_stage": old_stage,
		"new_stage": new_stage,
		"tick": GameManager.tick_count
	}
	collapse_history.append(record)
	
	var event: Dictionary = {
		"type": "collapse_stage_change",
		"settlement_id": settlement_id,
		"old_stage": old_stage,
		"new_stage": new_stage,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_collapse_event(settlement_id: int, survivors: Dictionary) -> void:
	var event: Dictionary = {
		"type": "settlement_collapse",
		"settlement_id": settlement_id,
		"survivors": survivors,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)


# === Public Query Functions ===

func get_tracked_settlement_count() -> int:
	return collapse_metrics.size()

func get_collapsed_settlement_count() -> int:
	var count: int = 0
	for settlement_id in collapse_metrics:
		var metrics: Dictionary = collapse_metrics[settlement_id]
		var stage: CollapseStage = metrics.get("stage", CollapseStage.STABLE)
		if stage == CollapseStage.COLLAPSED:
			count += 1
	return count

# === Public Interface ===

func get_collapse_stage(settlement_id: int) -> CollapseStage:
	if collapse_metrics.has(settlement_id):
		return collapse_metrics[settlement_id]["stage"]
	return CollapseStage.STABLE

func get_collapse_metrics(settlement_id: int) -> Dictionary:
	if collapse_metrics.has(settlement_id):
		return collapse_metrics[settlement_id].duplicate(true)
	return {}

func get_collapse_signs(settlement_id: int) -> Array:
	if collapse_signs.has(settlement_id):
		return collapse_signs[settlement_id]
	return []

func get_collapse_status() -> Dictionary:
	var status: Dictionary = {}
	
	for settlement_id in collapse_metrics:
		status[settlement_id] = {
			"metrics": collapse_metrics[settlement_id],
			"signs": collapse_signs.get(settlement_id, []),
			"survivors": collapse_survivors.get(settlement_id, {})
		}
	
	return status

func _notify_world_ai_collapse_metric_change(settlement_id: int, metric_name: String, new_value: float) -> void:
	# Notify WorldAI of collapse metric change to update neural network
	if WorldAI != null and WorldAI.has_method("on_collapse_metric_change"):
		WorldAI.on_collapse_metric_change(settlement_id, metric_name, new_value)

func clear() -> void:
	collapse_metrics.clear()
	collapse_signs.clear()
	collapse_history.clear()
	collapse_survivors.clear()
