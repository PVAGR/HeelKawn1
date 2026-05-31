extends Node
## ResearchSystem — research projects, discovery, and technology progression.
##
## Settlements allocate scholars to research projects. Progress accumulates
## deterministically based on knowledge levels, library quality, population,
## and technology era. Breakthroughs boost all knowledge categories.
##
## Integrates with KnowledgeSystem, LibrarySystem, TechnologyEras, EventBus,
## WorldMemory, and SettlementMemory.

const RESEARCH_INTERVAL: int = 2000
const DECAY_INTERVAL: int = 8000
const BREAKTHROUGH_BASE_CHANCE: float = 0.02
const CATEGORY_COUNT: int = 8
const BASE_KNOWLEDGE_LEVEL: float = 10.0
const BASE_SCHOLAR_PROGRESS: float = 0.5
const SCHOLAR_PER_POP_PROGRESS: float = 0.02
const SCHOLAR_PER_LIBRARY_PROGRESS: float = 0.5
const ERA_BASE_SPEED: float = 1.0
const ERA_SPEED_INCREMENT: float = 0.05
const KNOWLEDGE_LEVEL_PROGRESS_FACTOR: float = 0.01
const COLLABORATION_RANGE_TILES: int = 200
const COLLABORATION_PROGRESS_FRACTION: float = 0.3
const DISTANCE_PENALTY_FACTOR: float = 0.001
const MAX_CATEGORY_LEVEL: float = 100.0
const DECAY_THRESHOLD_TICKS: int = 12000
const DECAY_BASE_AMOUNT: float = 2.0
const PROTECTED_PROGRESS_FRACTION: float = 0.2

enum ResearchCategory {
	FARMING = 1,
	CRAFTING = 2,
	WARFARE = 3,
	MEDICINE = 4,
	CULTURE = 5,
	TRADE = 6,
	SCIENCE = 7,
	MAGIC = 8,
}

const CATEGORY_NAMES: Dictionary = {
	ResearchCategory.FARMING: "Farming",
	ResearchCategory.CRAFTING: "Crafting",
	ResearchCategory.WARFARE: "Warfare",
	ResearchCategory.MEDICINE: "Medicine",
	ResearchCategory.CULTURE: "Culture",
	ResearchCategory.TRADE: "Trade",
	ResearchCategory.SCIENCE: "Science",
	ResearchCategory.MAGIC: "Magic",
}

const CATEGORY_COLORS: Dictionary = {
	ResearchCategory.FARMING: "#4CAF50",
	ResearchCategory.CRAFTING: "#FF9800",
	ResearchCategory.WARFARE: "#F44336",
	ResearchCategory.MEDICINE: "#00BCD4",
	ResearchCategory.CULTURE: "#9C27B0",
	ResearchCategory.TRADE: "#FFEB3B",
	ResearchCategory.SCIENCE: "#2196F3",
	ResearchCategory.MAGIC: "#E91E63",
}

class ResearchProject:
	var name: String
	var category: int
	var cost: float
	var progress: float
	var started_tick: int
	var breakthrough: bool
	var contributing_scholars: Array[int]
	var last_progress_tick: int
	var decay_started_tick: int

	func _init(
		p_name: String,
		p_category: int,
		p_cost: float,
		p_started_tick: int
	):
		name = p_name
		category = p_category
		cost = p_cost
		progress = 0.0
		started_tick = p_started_tick
		breakthrough = false
		contributing_scholars = []
		last_progress_tick = p_started_tick
		decay_started_tick = -1

class ResearchQueueEntry:
	var category: int
	var name: String
	var auto_assigned: bool
	var queued_tick: int

	func _init(p_category: int, p_name: String, p_auto: bool, p_tick: int):
		category = p_category
		name = p_name
		auto_assigned = p_auto
		queued_tick = p_tick

var _active_projects: Dictionary = {}
var _project_queues: Dictionary = {}
var _completed_projects: Array[Dictionary] = []
var _last_research_tick: int = -999999
var _last_decay_check: int = -999999
var _category_knowledge_levels: Dictionary = {}
var _breakthrough_count: int = 0
var _total_projects_completed: int = 0

signal research_started(center: int, project_name: String, category: int)
signal research_completed(center: int, project_name: String, category: int)
signal breakthrough_achieved(center: int, project_name: String)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null:
		if eb.has_method("subscribe"):
			eb.subscribe("settlement_founded", self, "_on_settlement_founded")
		if eb.has_method("subscribe"):
			eb.subscribe("scholar_arrival", self, "_on_scholar_arrival")

func _on_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	if not _active_projects.has(center):
		_active_projects[center] = []
	if not _project_queues.has(center):
		_project_queues[center] = []
	if not _category_knowledge_levels.has(center):
		_category_knowledge_levels[center] = {}
		for cat in range(1, CATEGORY_COUNT + 1):
			_category_knowledge_levels[center][cat] = BASE_KNOWLEDGE_LEVEL

func _on_scholar_arrival(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	if not _active_projects.has(center):
		return
	var projects: Array = _active_projects[center]
	if projects.is_empty():
		return
	for rp in projects:
		if rp is ResearchProject:
			var sid: int = int(payload.get("scholar_id", payload.get("pawn_id", -1)))
			if sid >= 0 and not (sid in rp.contributing_scholars):
				rp.contributing_scholars.append(sid)

func _on_game_tick(tick: int) -> void:
	if tick - _last_research_tick < RESEARCH_INTERVAL:
		return
	_last_research_tick = tick
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	for st_v in sm.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_process_settlement_research(center, st, tick)
	if tick - _last_decay_check >= DECAY_INTERVAL:
		_last_decay_check = tick
		_apply_global_decay(tick)

func _process_settlement_research(center: int, st: Dictionary, tick: int) -> void:
	if not _active_projects.has(center):
		_active_projects[center] = []
	if not _project_queues.has(center):
		_project_queues[center] = []
	if not _category_knowledge_levels.has(center):
		_category_knowledge_levels[center] = {}
		for cat in range(1, CATEGORY_COUNT + 1):
			_category_knowledge_levels[center][cat] = BASE_KNOWLEDGE_LEVEL
	var pop: int = int(st.get("population", 0))
	var max_active: int = _get_max_concurrent_projects(pop, center)
	var active: Array = _active_projects[center]
	if active.is_empty():
		var queue: Array = _project_queues[center]
		if not queue.is_empty():
			var next_entry: ResearchQueueEntry = queue.pop_front()
			start_research(center, next_entry.category, tick)
		elif pop >= 3:
			_auto_start_research(center, st, tick)
		return
	if active.size() < max_active:
		var queue: Array = _project_queues[center]
		if not queue.is_empty():
			while active.size() < max_active and not queue.is_empty():
				var next_entry: ResearchQueueEntry = queue.pop_front()
				start_research(center, next_entry.category, tick)
	var to_remove: Array[int] = []
	for i in range(active.size()):
		var rp = active[i]
		if not (rp is ResearchProject):
			continue
		if rp.decay_started_tick >= 0 and tick - rp.decay_started_tick >= DECAY_THRESHOLD_TICKS:
			_cancel_research(center, rp, tick)
			to_remove.append(i)
		else:
			_process_active_project(center, rp, st, tick)
	for idx in to_remove.size():
		var ri: int = to_remove[to_remove.size() - 1 - idx]
		if ri < active.size():
			active.remove_at(ri)
	_active_projects[center] = active
	var queue_after: Array = _project_queues[center]
	if active.size() < max_active and queue_after.is_empty() and pop >= 3:
		_auto_start_research(center, st, tick)

func _get_max_concurrent_projects(pop: int, center: int) -> int:
	if pop <= 0:
		return 0
	var base_max: int = maxi(1, int(pop / 10))
	var era_node := get_node_or_null("/root/TechnologyEras")
	if era_node != null and era_node.has_method("get_settlement_era"):
		var era: int = era_node.get_settlement_era(center)
		base_max += int(era / 2)
	var lib_node := get_node_or_null("/root/LibrarySystem")
	if lib_node != null and lib_node.has_method("has_library"):
		if lib_node.has_library(center):
			base_max += 1
	return mini(base_max, 8)

func start_research(center: int, category: int, tick: int) -> bool:
	if category < 1 or category > CATEGORY_COUNT:
		return false
	if not _active_projects.has(center):
		_active_projects[center] = []
	var projects: Array = _active_projects[center]
	var already_running: bool = false
	for rp in projects:
		if rp is ResearchProject and rp.category == category:
			already_running = true
			break
	if already_running:
		return false
	var sm := get_node_or_null("/root/SettlementMemory")
	var pop: int = 0
	if sm != null:
		for st_v in sm.settlements:
			if (st_v is Dictionary) and int(st_v.get("center_region", -1)) == center:
				pop = int(st_v.get("population", 0))
	var max_active: int = _get_max_concurrent_projects(pop, center)
	if projects.size() >= max_active:
		return false
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var knowledge_level: float = _get_knowledge_level_in_category(ks, center, category)
	var lib := get_node_or_null("/root/LibrarySystem")
	var scholar_bonus: float = BASE_SCHOLAR_PROGRESS
	if lib != null and lib.has_method("get_scholar_count"):
		scholar_bonus += float(lib.get_scholar_count(center)) * SCHOLAR_PER_LIBRARY_PROGRESS
	var era_node := get_node_or_null("/root/TechnologyEras")
	var era_speed: float = ERA_BASE_SPEED
	if era_node != null and era_node.has_method("get_settlement_era"):
		var era: int = era_node.get_settlement_era(center)
		era_speed += float(era) * ERA_SPEED_INCREMENT
	var base_cost: float = 100.0 * (1.0 + knowledge_level / 20.0)
	var cost: float = base_cost / maxf(scholar_bonus, 0.5)
	cost = cost / maxf(era_speed, 0.5)
	cost = clampf(cost, 20.0, 5000.0)
	var rp := ResearchProject.new(
		CATEGORY_NAMES.get(category, "Research"),
		category,
		cost,
		tick
	)
	if lib != null and lib.has_method("get_scholar_count"):
		var scholar_count: int = lib.get_scholar_count(center)
		for sid_idx in range(mini(scholar_count, 5)):
			var fake_scholar_id: int = center * 1000 + sid_idx
			if not (fake_scholar_id in rp.contributing_scholars):
				rp.contributing_scholars.append(fake_scholar_id)
	projects.append(rp)
	_active_projects[center] = projects
	research_started.emit(center, rp.name, category)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "research_started",
			"center": center,
			"category": CATEGORY_NAMES.get(category, "Research"),
			"category_id": category,
			"cost": cost,
			"tick": tick,
		})
	return true

func queue_research(center: int, category: int, tick: int) -> bool:
	if category < 1 or category > CATEGORY_COUNT:
		return false
	if not _project_queues.has(center):
		_project_queues[center] = []
	var queue: Array = _project_queues[center]
	for entry in queue:
		if entry is ResearchQueueEntry and entry.category == category:
			return false
	if queue.size() >= 10:
		return false
	var entry := ResearchQueueEntry.new(category, CATEGORY_NAMES.get(category, "Research"), false, tick)
	queue.append(entry)
	_project_queues[center] = queue
	return true

func cancel_research(center: int, category: int) -> bool:
	if not _active_projects.has(center):
		return false
	var projects: Array = _active_projects[center]
	for i in range(projects.size()):
		var rp = projects[i]
		if rp is ResearchProject and rp.category == category:
			projects.remove_at(i)
			_active_projects[center] = projects
			return true
	return false

func remove_from_queue(center: int, category: int) -> bool:
	if not _project_queues.has(center):
		return false
	var queue: Array = _project_queues[center]
	for i in range(queue.size()):
		var entry = queue[i]
		if entry is ResearchQueueEntry and entry.category == category:
			queue.remove_at(i)
			_project_queues[center] = queue
			return true
	return false

func _auto_start_research(center: int, st: Dictionary, tick: int) -> void:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return
	if not _active_projects.has(center):
		_active_projects[center] = []
	var projects: Array = _active_projects[center]
	var pop: int = int(st.get("population", 0))
	var max_active: int = _get_max_concurrent_projects(pop, center)
	if projects.size() >= max_active:
		return
	var all_maxed: bool = true
	for cat in range(1, CATEGORY_COUNT + 1):
		var level: float = _get_knowledge_level_in_category(ks, center, cat)
		if level < MAX_CATEGORY_LEVEL:
			all_maxed = false
			break
	if all_maxed:
		return
	var already_active: Array[int] = []
	for rp in projects:
		if rp is ResearchProject:
			already_active.append(rp.category)
	var lowest_cat: int = _find_lowest_category(center, ks, already_active)
	if lowest_cat < 0:
		return
	if _category_knowledge_levels.has(center):
		var levels: Dictionary = _category_knowledge_levels[center]
		if levels.get(lowest_cat, 0.0) >= MAX_CATEGORY_LEVEL:
			for cat in range(1, CATEGORY_COUNT + 1):
				if levels.get(cat, 0.0) < MAX_CATEGORY_LEVEL and not (cat in already_active):
					lowest_cat = cat
					break
	if not queue_research(center, lowest_cat, tick):
		if not start_research(center, lowest_cat, tick):
			pass

func _find_lowest_category(center: int, ks: Node, exclude: Array[int]) -> int:
	var lowest_val: float = 999.0
	var lowest_cat: int = -1
	for cat in range(1, CATEGORY_COUNT + 1):
		if cat in exclude:
			continue
		var val: float = _get_knowledge_level_in_category(ks, center, cat)
		if val < lowest_val:
			lowest_val = val
			lowest_cat = cat
	return lowest_cat

func _get_knowledge_level_in_category(ks: Node, center: int, category: int) -> float:
	if _category_knowledge_levels.has(center):
		var levels: Dictionary = _category_knowledge_levels[center]
		if levels.has(category):
			return float(levels[category])
	if ks != null and ks.has_method("get_knowledge"):
		return float(ks.get_knowledge(center, category))
	return BASE_KNOWLEDGE_LEVEL

func _set_knowledge_level_in_category(center: int, category: int, value: float) -> void:
	if not _category_knowledge_levels.has(center):
		_category_knowledge_levels[center] = {}
		for cat in range(1, CATEGORY_COUNT + 1):
			_category_knowledge_levels[center][cat] = BASE_KNOWLEDGE_LEVEL
	_category_knowledge_levels[center][category] = clampf(value, 0.0, MAX_CATEGORY_LEVEL)

func _process_active_project(center: int, rp: ResearchProject, st: Dictionary, tick: int) -> void:
	var progress_rate: float = _calculate_progress_rate(center, rp.category, st, rp)
	if rp.last_progress_tick < 0:
		rp.last_progress_tick = tick
	else:
		var gap: int = tick - rp.last_progress_tick
		if gap > 0:
			var interval_factor: float = float(gap) / float(RESEARCH_INTERVAL)
			progress_rate *= interval_factor
	rp.progress += progress_rate
	rp.last_progress_tick = tick
	if rp.decay_started_tick >= 0:
		rp.decay_started_tick = -1
	if rp.progress >= rp.cost:
		_complete_research(center, rp, tick)

func _calculate_progress_rate(center: int, category: int, st: Dictionary, rp: ResearchProject) -> float:
	var pop: int = int(st.get("population", 0))
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var knowledge_level: float = _get_knowledge_level_in_category(ks, center, category)
	var rate: float = BASE_SCHOLAR_PROGRESS
	rate += float(pop) * SCHOLAR_PER_POP_PROGRESS
	rate += knowledge_level * KNOWLEDGE_LEVEL_PROGRESS_FACTOR
	var lib := get_node_or_null("/root/LibrarySystem")
	if lib != null and lib.has_method("get_scholar_count"):
		rate += float(lib.get_scholar_count(center)) * SCHOLAR_PER_LIBRARY_PROGRESS
	var era_node := get_node_or_null("/root/TechnologyEras")
	if era_node != null and era_node.has_method("get_settlement_era"):
		var era: int = era_node.get_settlement_era(center)
		rate += float(era) * ERA_SPEED_INCREMENT
	if not rp.contributing_scholars.is_empty():
		var collab_bonus: float = float(rp.contributing_scholars.size()) * 0.3
		rate += collab_bonus
	if pop <= 0:
		rate *= 0.1
	var even_tick: int = GameManager.tick_count if GameManager != null else 0
	if even_tick % 100 == 0:
		var wm := get_node_or_null("/root/WorldMemory")
		if wm != null and wm.has_method("get_world_stability"):
			var stability: float = wm.get_world_stability()
			rate *= (0.8 + stability * 0.2)
	return maxf(rate, 0.1)

func _complete_research(center: int, rp: ResearchProject, tick: int) -> void:
	_total_projects_completed += 1
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var knowledge_gain: float = 5.0 + rp.cost * 0.02
	var current_level: float = _get_knowledge_level_in_category(ks, center, rp.category)
	var new_level: float = current_level + knowledge_gain * 0.1
	_set_knowledge_level_in_category(center, rp.category, new_level)
	if ks != null and ks.has_method("add_knowledge"):
		ks.add_knowledge(center, rp.category, knowledge_gain, tick)
	rp.breakthrough = false
	var rng_node := get_node_or_null("/root/WorldRNG")
	if rng_node != null and rng_node.has_method("chance_for"):
		var rng_key: StringName = StringName("research_breakthrough:%d:%d" % [center, rp.category])
		var salt: int = tick + center * 1009 + rp.category * 37
		if rng_node.chance_for(rng_key, BREAKTHROUGH_BASE_CHANCE, salt):
			rp.breakthrough = true
	var completion: Dictionary = {
		"center": center,
		"category": rp.category,
		"name": rp.name,
		"tick": tick,
		"breakthrough": rp.breakthrough,
		"cost": rp.cost,
		"progress_final": rp.progress,
	}
	_completed_projects.append(completion)
	if _active_projects.has(center):
		var projects: Array = _active_projects[center]
		for i in range(projects.size()):
			var p = projects[i]
			if p == rp:
				projects.remove_at(i)
				break
		_active_projects[center] = projects
	research_completed.emit(center, rp.name, rp.category)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "research_completed",
			"center": center,
			"category": rp.name,
			"category_id": rp.category,
			"breakthrough": rp.breakthrough,
			"tick": tick,
		})
	if rp.breakthrough:
		_apply_breakthrough(center, rp, tick)
	var queue: Array = _project_queues.get(center, [])
	if not queue.is_empty():
		var sm := get_node_or_null("/root/SettlementMemory")
		var pop: int = 0
		if sm != null:
			for st_v in sm.settlements:
				if (st_v is Dictionary) and int(st_v.get("center_region", -1)) == center:
					pop = int(st_v.get("population", 0))
		var max_active: int = _get_max_concurrent_projects(pop, center)
		var active_projects: Array = _active_projects.get(center, [])
		while active_projects.size() < max_active and not queue.is_empty():
			var next_entry: ResearchQueueEntry = queue.pop_front()
			start_research(center, next_entry.category, tick)
			if active_projects.size() < max_active:
				active_projects = _active_projects.get(center, [])

func _apply_breakthrough(center: int, rp: ResearchProject, tick: int) -> void:
	_breakthrough_count += 1
	breakthrough_achieved.emit(center, rp.name)
	var rng_node := get_node_or_null("/root/WorldRNG")
	var spread_roll: float = 0.5
	if rng_node != null and rng_node.has_method("unit"):
		var spread_key: StringName = StringName("research_spread:%d" % center)
		spread_roll = rng_node.unit(spread_key, tick)
	for cat in range(1, CATEGORY_COUNT + 1):
		if cat == rp.category:
			var cat_boost: float = 10.0 + rp.cost * 0.03
			var current: float = _get_knowledge_level_in_category(null, center, cat)
			_set_knowledge_level_in_category(center, cat, current + cat_boost)
		else:
			var other_boost: float = 3.0 + rp.cost * 0.01
			var current: float = _get_knowledge_level_in_category(null, center, cat)
			if current < MAX_CATEGORY_LEVEL:
				_set_knowledge_level_in_category(center, cat, current + other_boost)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("add_knowledge"):
		for cat in range(1, CATEGORY_COUNT + 1):
			if cat != rp.category:
				ks.add_knowledge(center, cat, 2.0 + rp.cost * 0.005, tick)
	if ks != null and ks.has_method("add_knowledge"):
		ks.add_knowledge(center, rp.category, 15.0 + rp.cost * 0.05, tick)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "breakthrough_achieved",
			"center": center,
			"category": rp.name,
			"category_id": rp.category,
			"tick": tick,
		})
	if spread_roll < 0.3:
		var sm := get_node_or_null("/root/SettlementMemory")
		if sm != null:
			for st_v in sm.settlements:
				if (st_v is Dictionary) and int(st_v.get("center_region", -1)) != center:
					var sc: int = int(st_v.get("center_region", -1))
					if ks != null and ks.has_method("transfer_knowledge"):
						ks.transfer_knowledge(center, sc, tick, 0.1)
					for cat in range(1, CATEGORY_COUNT + 1):
						var src_level: float = _get_knowledge_level_in_category(null, center, cat)
						var dst_level: float = _get_knowledge_level_in_category(null, sc, cat)
						var transfer: float = (src_level - dst_level) * 0.05
						if transfer > 0.5:
							_set_knowledge_level_in_category(sc, cat, dst_level + transfer)

func _cancel_research(center: int, rp: ResearchProject, tick: int) -> void:
	if _active_projects.has(center):
		var projects: Array = _active_projects[center]
		for i in range(projects.size()):
			var p = projects[i]
			if p == rp:
				projects.remove_at(i)
				break
		_active_projects[center] = projects
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "research_cancelled",
			"center": center,
			"category": rp.name,
			"category_id": rp.category,
			"progress": rp.progress,
			"reason": "decay",
			"tick": tick,
		})

func _apply_global_decay(tick: int) -> void:
	for center in _active_projects.keys():
		var projects: Array = _active_projects[center]
		for rp in projects:
			if rp is ResearchProject:
				if rp.last_progress_tick >= 0 and tick - rp.last_progress_tick >= DECAY_THRESHOLD_TICKS:
					if rp.decay_started_tick < 0:
						rp.decay_started_tick = rp.last_progress_tick
				elif rp.last_progress_tick >= 0 and tick - rp.last_progress_tick < DECAY_THRESHOLD_TICKS / 2:
					if rp.decay_started_tick >= 0:
						rp.decay_started_tick = -1
	var pop_buckets: Dictionary = {}
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm != null:
		for st_v in sm.settlements:
			if not (st_v is Dictionary):
				continue
			var st: Dictionary = st_v as Dictionary
			var c: int = int(st.get("center_region", -1))
			if c >= 0:
				pop_buckets[c] = int(st.get("population", 0))
	for center in _category_knowledge_levels.keys():
		var pop: int = pop_buckets.get(center, 0)
		var levels: Dictionary = _category_knowledge_levels[center]
		for cat in range(1, CATEGORY_COUNT + 1):
			if levels.has(cat):
				var val: float = float(levels[cat])
				if val > BASE_KNOWLEDGE_LEVEL:
					var decay: float = DECAY_BASE_AMOUNT * 0.01
					if pop <= 0:
						decay *= 2.0
					if val < BASE_KNOWLEDGE_LEVEL + 5.0:
						decay *= 0.5
					levels[cat] = maxf(val - decay, BASE_KNOWLEDGE_LEVEL)

func _get_max_progress_by_category(center: int) -> Dictionary:
	var out: Dictionary = {}
	var projects: Array = _active_projects.get(center, [])
	for rp in projects:
		if rp is ResearchProject:
			if not out.has(rp.category):
				out[rp.category] = 0.0
			out[rp.category] += rp.progress
	return out

func get_research_report(center: int) -> Dictionary:
	var report: Dictionary = {}
	report["center"] = center
	var active: Array = _active_projects.get(center, [])
	var active_list: Array[Dictionary] = []
	for rp in active:
		if rp is ResearchProject:
			active_list.append({
				"name": rp.name,
				"category": rp.category,
				"category_name": CATEGORY_NAMES.get(rp.category, "Unknown"),
				"progress": rp.progress,
				"cost": rp.cost,
				"progress_pct": clampf(rp.progress / maxf(rp.cost, 0.01) * 100.0, 0.0, 100.0),
				"breakthrough": rp.breakthrough,
				"scholars": rp.contributing_scholars.size(),
				"started_tick": rp.started_tick,
				"decaying": rp.decay_started_tick >= 0,
			})
	report["active_projects"] = active_list
	var queue: Array = _project_queues.get(center, [])
	var queue_list: Array[Dictionary] = []
	for entry in queue:
		if entry is ResearchQueueEntry:
			queue_list.append({
				"name": entry.name,
				"category": entry.category,
				"auto_assigned": entry.auto_assigned,
				"queued_tick": entry.queued_tick,
			})
	report["queue"] = queue_list
	var sm := get_node_or_null("/root/SettlementMemory")
	var pop: int = 0
	if sm != null:
		for st_v in sm.settlements:
			if (st_v is Dictionary) and int(st_v.get("center_region", -1)) == center:
				pop = int(st_v.get("population", 0))
	report["population"] = pop
	report["max_concurrent"] = _get_max_concurrent_projects(pop, center)
	var completed: Array[Dictionary] = []
	for cp in _completed_projects:
		if cp.get("center", -1) == center:
			completed.append(cp.duplicate())
	report["completed_count"] = completed.size()
	report["completed_projects"] = completed
	var cat_levels: Dictionary = {}
	if _category_knowledge_levels.has(center):
		var levels: Dictionary = _category_knowledge_levels[center]
		for cat in range(1, CATEGORY_COUNT + 1):
			cat_levels[cat] = {
				"name": CATEGORY_NAMES.get(cat, "Unknown"),
				"level": levels.get(cat, BASE_KNOWLEDGE_LEVEL),
				"color": CATEGORY_COLORS.get(cat, "#FFFFFF"),
			}
	report["category_levels"] = cat_levels
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("get_research_points"):
		report["research_points"] = ks.get_research_points(center)
	else:
		report["research_points"] = 0
	return report

func get_global_stats() -> Dictionary:
	var total_active: int = 0
	var total_queue: int = 0
	var settlement_count: int = 0
	for center in _active_projects.keys():
		total_active += _active_projects[center].size()
		settlement_count += 1
	for center in _project_queues.keys():
		total_queue += _project_queues[center].size()
	var avg_progress: float = 0.0
	var all_cats: Dictionary = {}
	for center in _category_knowledge_levels.keys():
		var levels: Dictionary = _category_knowledge_levels[center]
		for cat in range(1, CATEGORY_COUNT + 1):
			if not all_cats.has(cat):
				all_cats[cat] = 0.0
			all_cats[cat] += float(levels.get(cat, BASE_KNOWLEDGE_LEVEL))
	for cat in all_cats.keys():
		all_cats[cat] = float(all_cats[cat]) / maxf(settlement_count, 1)
	var total_level: float = 0.0
	for cat in all_cats.keys():
		total_level += float(all_cats[cat])
	avg_progress = total_level / maxf(CATEGORY_COUNT, 1)
	var wm := get_node_or_null("/root/WorldMemory")
	var total_history_events: int = 0
	if wm != null and wm.has_method("event_count"):
		total_history_events = wm.event_count()
	return {
		"active_projects": total_active,
		"queued_projects": total_queue,
		"settlements_researching": settlement_count,
		"completed_projects": _completed_projects.size(),
		"breakthroughs": _breakthrough_count,
		"average_knowledge_level": avg_progress,
		"total_knowledge_level": total_level,
		"category_averages": all_cats,
		"total_world_events": total_history_events,
	}

func get_category_breakdown(center: int) -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []
	for cat in range(1, CATEGORY_COUNT + 1):
		var level: float = _get_knowledge_level_in_category(null, center, cat)
		var progress_current: float = 0.0
		var projects: Array = _active_projects.get(center, [])
		for rp in projects:
			if rp is ResearchProject and rp.category == cat:
				progress_current += rp.progress
		var queue_count: int = 0
		var queue: Array = _project_queues.get(center, [])
		for entry in queue:
			if entry is ResearchQueueEntry and entry.category == cat:
				queue_count += 1
		var completed: int = 0
		for cp in _completed_projects:
			if cp.get("center", -1) == center and cp.get("category", -1) == cat:
				completed += 1
		var maxed: bool = level >= MAX_CATEGORY_LEVEL
		var progress_pct: float = clampf(level / MAX_CATEGORY_LEVEL * 100.0, 0.0, 100.0)
		breakdown.append({
			"category": cat,
			"name": CATEGORY_NAMES.get(cat, "Unknown"),
			"color": CATEGORY_COLORS.get(cat, "#FFFFFF"),
			"level": level,
			"progress": progress_current,
			"queue_count": queue_count,
			"completed_count": completed,
			"maxed": maxed,
			"progress_pct": progress_pct,
		})
	breakdown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("category", 99)) < int(b.get("category", 99))
	)
	return breakdown

func get_active_project(center: int, category: int):
	if not _active_projects.has(center):
		return null
	var projects: Array = _active_projects[center]
	for rp in projects:
		if rp is ResearchProject and rp.category == category:
			return rp
	return null

func get_all_active_projects(center: int) -> Array:
	return _active_projects.get(center, []).duplicate()

func get_completed_projects(center: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cp in _completed_projects:
		if cp.get("center", -1) == center:
			out.append(cp.duplicate())
	return out

func get_queue(center: int) -> Array:
	return _project_queues.get(center, []).duplicate()

func get_breakthrough_count() -> int:
	return _breakthrough_count

func get_total_completed() -> int:
	return _total_projects_completed

func is_category_maxed(center: int, category: int) -> bool:
	var level: float = _get_knowledge_level_in_category(null, center, category)
	return level >= MAX_CATEGORY_LEVEL

func get_category_level(center: int, category: int) -> float:
	return _get_knowledge_level_in_category(null, center, category)

func get_stats() -> Dictionary:
	return {
		"active_projects": _active_projects.size(),
		"completed_projects": _completed_projects.size(),
		"breakthroughs": _breakthrough_count,
		"total_completed": _total_projects_completed,
	}

func to_save_dict() -> Dictionary:
	var active_save: Dictionary = {}
	for center in _active_projects.keys():
		var projects: Array = _active_projects[center]
		var project_list: Array[Dictionary] = []
		for rp in projects:
			if rp is ResearchProject:
				project_list.append({
					"name": rp.name,
					"category": rp.category,
					"cost": rp.cost,
					"progress": rp.progress,
					"started_tick": rp.started_tick,
					"breakthrough": rp.breakthrough,
					"contributing_scholars": rp.contributing_scholars.duplicate(),
					"last_progress_tick": rp.last_progress_tick,
					"decay_started_tick": rp.decay_started_tick,
				})
		active_save[center] = project_list
	var queue_save: Dictionary = {}
	for center in _project_queues.keys():
		var queue: Array = _project_queues[center]
		var entry_list: Array[Dictionary] = []
		for entry in queue:
			if entry is ResearchQueueEntry:
				entry_list.append({
					"category": entry.category,
					"name": entry.name,
					"auto_assigned": entry.auto_assigned,
					"queued_tick": entry.queued_tick,
				})
		queue_save[center] = entry_list
	var levels_save: Dictionary = {}
	for center in _category_knowledge_levels.keys():
		var levels: Dictionary = _category_knowledge_levels[center]
		var levels_copy: Dictionary = {}
		for cat in levels.keys():
			levels_copy[int(cat)] = float(levels[cat])
		levels_save[center] = levels_copy
	return {
		"active_projects": active_save,
		"project_queues": queue_save,
		"completed_projects": _completed_projects.duplicate(),
		"category_knowledge_levels": levels_save,
		"last_research_tick": _last_research_tick,
		"last_decay_check": _last_decay_check,
		"breakthrough_count": _breakthrough_count,
		"total_projects_completed": _total_projects_completed,
	}

func from_save_dict(data: Dictionary) -> void:
	clear()
	if data.is_empty():
		return
	var active_save: Dictionary = data.get("active_projects", {})
	for center_key in active_save.keys():
		var center: int = int(center_key)
		var project_list: Array = active_save[center_key]
		var projects: Array = []
		for pd in project_list:
			if pd is Dictionary:
				var d: Dictionary = pd as Dictionary
				var rp := ResearchProject.new(
					str(d.get("name", "Research")),
					int(d.get("category", 1)),
					float(d.get("cost", 100.0)),
					int(d.get("started_tick", 0))
				)
				rp.progress = float(d.get("progress", 0.0))
				rp.breakthrough = bool(d.get("breakthrough", false))
				rp.contributing_scholars = (d.get("contributing_scholars", []) as Array).duplicate()
				rp.last_progress_tick = int(d.get("last_progress_tick", -1))
				rp.decay_started_tick = int(d.get("decay_started_tick", -1))
				projects.append(rp)
		_active_projects[center] = projects
	var queue_save: Dictionary = data.get("project_queues", {})
	for center_key in queue_save.keys():
		var center: int = int(center_key)
		var entry_list: Array = queue_save[center_key]
		var queue: Array = []
		for ed in entry_list:
			if ed is Dictionary:
				var d: Dictionary = ed as Dictionary
				var entry := ResearchQueueEntry.new(
					int(d.get("category", 1)),
					str(d.get("name", "Research")),
					bool(d.get("auto_assigned", false)),
					int(d.get("queued_tick", 0))
				)
				queue.append(entry)
		_project_queues[center] = queue
	var completed: Array = data.get("completed_projects", [])
	for cp in completed:
		if cp is Dictionary:
			_completed_projects.append((cp as Dictionary).duplicate())
	var levels_save: Dictionary = data.get("category_knowledge_levels", {})
	for center_key in levels_save.keys():
		var center: int = int(center_key)
		var levels: Dictionary = levels_save[center_key]
		_category_knowledge_levels[center] = {}
		for cat_key in levels.keys():
			_category_knowledge_levels[center][int(cat_key)] = float(levels[cat_key])
	_last_research_tick = int(data.get("last_research_tick", -999999))
	_last_decay_check = int(data.get("last_decay_check", -999999))
	_breakthrough_count = int(data.get("breakthrough_count", 0))
	_total_projects_completed = int(data.get("total_projects_completed", 0))

func add_collaborator(center: int, project_category: int, scholar_id: int, tick: int) -> bool:
	if not _active_projects.has(center):
		return false
	var projects: Array = _active_projects[center]
	for rp in projects:
		if rp is ResearchProject and rp.category == project_category:
			if scholar_id in rp.contributing_scholars:
				return false
			rp.contributing_scholars.append(scholar_id)
			var contributor_center: int = _find_contributor_settlement(scholar_id)
			if contributor_center >= 0 and contributor_center != center:
				var dist: int = _settlement_distance(center, contributor_center)
				if dist > 0:
					var penalty: float = float(dist) * DISTANCE_PENALTY_FACTOR
					var rng_key: StringName = StringName("collab_accept:%d:%d" % [scholar_id, center])
					var rng_node := get_node_or_null("/root/WorldRNG")
					var accept: bool = true
					if rng_node != null and rng_node.has_method("chance_for"):
						var chance: float = clampf(1.0 - penalty, 0.0, 1.0)
						accept = rng_node.chance_for(rng_key, chance, tick + scholar_id)
					if not accept:
						rp.contributing_scholars.erase(scholar_id)
						return false
			var wm := get_node_or_null("/root/WorldMemory")
			if wm != null and wm.has_method("record_event"):
				wm.record_event({
					"type": "collaborator_added",
					"center": center,
					"scholar_id": scholar_id,
					"category": rp.name,
					"tick": tick,
				})
			return true
	return false

func remove_collaborator(center: int, project_category: int, scholar_id: int) -> bool:
	if not _active_projects.has(center):
		return false
	var projects: Array = _active_projects[center]
	for rp in projects:
		if rp is ResearchProject and rp.category == project_category:
			if scholar_id in rp.contributing_scholars:
				rp.contributing_scholars.erase(scholar_id)
				return true
			return false
	return false

func _find_contributor_settlement(scholar_id: int) -> int:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return -1
	var ps := get_node_or_null("/root/PawnSpawner")
	if ps == null or not ps.has_method("pawn_data_for_id"):
		return -1
	var pawn_data = ps.call("pawn_data_for_id", scholar_id)
	if pawn_data == null:
		return -1
	if not pawn_data.has("tile_pos"):
		return -1
	var pos: Vector2i = pawn_data.tile_pos
	var rk: int = -1
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("_region_key"):
		rk = wm._region_key(pos.x, pos.y)
	if rk < 0:
		return -1
	if sm.has_method("get_center_region_for_region"):
		return sm.get_center_region_for_region(rk)
	return -1

func _settlement_distance(center_a: int, center_b: int) -> int:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return 9999
	var sp := get_node_or_null("/root/SettlementPlanner")
	if sp == null or not sp.has_method("_center_tile_of_region_key"):
		return 9999
	var tile_a: Vector2i = sp._center_tile_of_region_key(center_a)
	var tile_b: Vector2i = sp._center_tile_of_region_key(center_b)
	return absi(tile_a.x - tile_b.x) + absi(tile_a.y - tile_b.y)

func prune_completed_projects(max_records: int = 500) -> int:
	if _completed_projects.size() <= max_records:
		return 0
	var pruned: int = _completed_projects.size() - max_records
	_completed_projects = _completed_projects.slice(-max_records)
	return pruned

func get_completed_projects_global(limit: int = -1, offset: int = 0) -> Array[Dictionary]:
	if limit < 0:
		var out: Array[Dictionary] = []
		for cp in _completed_projects:
			out.append(cp.duplicate())
		return out
	var slice_end: int = mini(offset + limit, _completed_projects.size())
	if offset >= _completed_projects.size():
		return []
	var out: Array[Dictionary] = []
	for i in range(offset, slice_end):
		out.append(_completed_projects[i].duplicate())
	return out

func get_breakthrough_projects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cp in _completed_projects:
		if bool(cp.get("breakthrough", false)):
			out.append(cp.duplicate())
	return out

func get_research_progress_summary() -> Dictionary:
	var summary: Dictionary = {}
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return summary
	for st_v in sm.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var report: Dictionary = get_research_report(center)
		var simplified: Dictionary = {
			"active_count": report.get("active_projects", []).size(),
			"queue_count": report.get("queue", []).size(),
			"completed_count": report.get("completed_count", 0),
		}
		var cat_levels: Dictionary = report.get("category_levels", {})
		var total: float = 0.0
		var count: int = 0
		for cat_key in cat_levels:
			var entry: Dictionary = cat_levels[cat_key]
			total += float(entry.get("level", 0.0))
			count += 1
		simplified["avg_level"] = total / maxf(count, 1)
		summary[center] = simplified
	return summary

func _get_settlement_name(center: int) -> String:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return "Center %d" % center
	for st_v in sm.settlements:
		if (st_v is Dictionary) and int(st_v.get("center_region", -1)) == center:
			return str(st_v.get("name", "Unknown"))
	return "Unknown"

func clear() -> void:
	_active_projects.clear()
	_project_queues.clear()
	_completed_projects.clear()
	_category_knowledge_levels.clear()
	_last_research_tick = -999999
	_last_decay_check = -999999
	_breakthrough_count = 0
	_total_projects_completed = 0
