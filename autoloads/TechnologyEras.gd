extends Node
## TechnologyEras — civilization-level technology progression through ages.
##
## Defines global technology eras (Stone Age -> Space Age). Eras require
## cumulative knowledge thresholds across categories. Each era unlocks
## new capabilities and changes world simulation parameters.
##
## Integrates with KnowledgeSystem for era requirements, VictorySystem
## for win conditions, and UI for display.
##
## Per-settlement era tracking + global era (highest among all).
## Tech diffusion: lower-era settlements gain knowledge diffusion bonus
## from higher-era neighbors. Supports era regression via cataclysm,
## advancement stall detection, literacy/lifespan tracking.

# ============================================================================
# Configuration Constants
# ============================================================================
const ERA_CHECK_INTERVAL: int = 5000
const TECH_DIFFUSION_INTERVAL: int = 2000
const LITERACY_UPDATE_INTERVAL: int = 3000
const LIFESPAN_UPDATE_INTERVAL: int = 5000
const ERA_REGRESSION_CHECK_INTERVAL: int = 1000
const ADVANCEMENT_STALL_CHECK_INTERVAL: int = 6000
const ADVANCEMENT_STALL_TICK_THRESHOLD: int = 15000
const KNOWLEDGE_DROP_THRESHOLD_FOR_REGRESSION: float = 0.40
const DIFFUSION_MAX_RADIUS_TILES: int = 120
const DIFFUSION_MAX_BONUS: float = 0.20
const DIFFUSION_BONUS_PER_ERA_GAP: float = 0.04
const DIFFUSION_DECAY_PER_TICK: float = 0.001
const LITERACY_BASE_RATE: float = 0.05
const LITERACY_PER_ERA: float = 0.07
const LITERACY_MAX: float = 1.0
const LIFESPAN_BASE_YEARS: float = 30.0
const LIFESPAN_PER_ERA: float = 8.0
const LIFESPAN_MAX_YEARS: float = 120.0
const RESEARCH_SPEED_BASE_MULTIPLIER: float = 1.0
const RESEARCH_SPEED_PER_ERA: float = 0.12
const BUILDING_SPEED_BASE_MULTIPLIER: float = 1.0
const BUILDING_SPEED_PER_ERA: float = 0.08
const MAX_POP_BASE: int = 50
const MAX_POP_PER_ERA: int = 40
const BUILDING_COST_SCALE_PER_ERA: float = 0.15
const MAX_STALLED_TICKS_BEFORE_WARNING: int = 10000

# ============================================================================
# Tech Era Enum
# ============================================================================
enum TechEra {
	STONE_AGE,       # Basic tools, fire, simple shelters
	COPPER_AGE,      # Copper smelting, basic trade
	BRONZE_AGE,      # Bronze weapons, writing, cities
	IRON_AGE,        # Iron tools, empire building, philosophy
	CLASSICAL,       # Advanced governance, engineering, medicine
	MEDIEVAL,        # Feudalism, religious institutions
	RENAISSANCE,     # Scientific method, exploration
	INDUSTRIAL,      # Factories, mass production
	ATOMIC,          # Advanced energy, computing
	SPACE_AGE,       # Interstellar capability
}

# ============================================================================
# Static Era Data — Names, Descriptions, Requirements
# ============================================================================
const ERA_NAMES: Dictionary = {
	TechEra.STONE_AGE:   "Stone Age",
	TechEra.COPPER_AGE:  "Copper Age",
	TechEra.BRONZE_AGE:  "Bronze Age",
	TechEra.IRON_AGE:    "Iron Age",
	TechEra.CLASSICAL:   "Classical Era",
	TechEra.MEDIEVAL:    "Medieval Era",
	TechEra.RENAISSANCE: "Renaissance",
	TechEra.INDUSTRIAL:  "Industrial Age",
	TechEra.ATOMIC:      "Atomic Age",
	TechEra.SPACE_AGE:   "Space Age",
}

const ERA_DESCRIPTIONS: Dictionary = {
	TechEra.STONE_AGE:
		"Simple stone tools, mastery of fire, nomadic hunter-gatherer bands. Survival depends on knowledge passed through oral tradition.",
	TechEra.COPPER_AGE:
		"Native copper hammered into ornaments and simple tools. Barter trade networks emerge between scattered settlements.",
	TechEra.BRONZE_AGE:
		"Tin and copper alloyed into bronze — superior tools and weapons. Writing systems appear. First walled cities rise.",
	TechEra.IRON_AGE:
		"Cheaper, stronger iron democratizes tool ownership. Empires expand through organized warfare. Philosophical traditions emerge.",
	TechEra.CLASSICAL:
		"Monumental architecture, aqueducts, codified law. Medicine advances beyond superstition. Standing armies and navies.",
	TechEra.MEDIEVAL:
		"Feudal hierarchy, religious institutions preserve knowledge through dark times. Manorialism organizes rural production.",
	TechEra.RENAISSANCE:
		"Scientific method challenges dogma. Ocean-going vessels connect continents. Printing press spreads knowledge widely.",
	TechEra.INDUSTRIAL:
		"Steam power, factories, mass production. Railroads shrink distances. Urbanization transforms society.",
	TechEra.ATOMIC:
		"Nuclear fission, transistor computing, spaceflight. Global communication networks. Biotechnology emerges.",
	TechEra.SPACE_AGE:
		"Interstellar travel, advanced AI, post-scarcity energy. Settlements span multiple star systems.",
}

const ERA_KNOWLEDGE_REQUIREMENTS: Dictionary = {
	TechEra.STONE_AGE:   0,
	TechEra.COPPER_AGE:  50,
	TechEra.BRONZE_AGE:  150,
	TechEra.IRON_AGE:    300,
	TechEra.CLASSICAL:   500,
	TechEra.MEDIEVAL:    750,
	TechEra.RENAISSANCE: 1000,
	TechEra.INDUSTRIAL:  1500,
	TechEra.ATOMIC:      2500,
	TechEra.SPACE_AGE:   4000,
}

# ============================================================================
# Era-Specific Unlock Tables
# ============================================================================
const ERA_UNLOCKED_BUILDINGS: Dictionary = {
	TechEra.STONE_AGE:   ["campfire", "lean_to", "stone_circle"],
	TechEra.COPPER_AGE:  ["copper_forge", "market_stall", "storage_pit"],
	TechEra.BRONZE_AGE:  ["bronze_forge", "wall", "temple", "granary"],
	TechEra.IRON_AGE:    ["iron_forge", "barracks", "road", "dock"],
	TechEra.CLASSICAL:   ["aqueduct", "library", "bathhouse", "colosseum", "harbor"],
	TechEra.MEDIEVAL:    ["castle", "cathedral", "workshop", "windmill", "monastery"],
	TechEra.RENAISSANCE: ["university", "printing_press", "observatory", "bank", "guild_hall"],
	TechEra.INDUSTRIAL:  ["factory", "railway", "coal_mine", "steel_mill", "power_plant"],
	TechEra.ATOMIC:      ["research_lab", "nuclear_reactor", "computer_center", "hospital"],
	TechEra.SPACE_AGE:   ["spaceport", "orbital_elevator", "ai_core", "fusion_reactor", "replicator"],
}

const ERA_UNLOCKED_JOBS: Dictionary = {
	TechEra.STONE_AGE:   ["hunter", "gatherer", "storyteller"],
	TechEra.COPPER_AGE:  ["trader", "smith_apprentice", "herder"],
	TechEra.BRONZE_AGE:  ["soldier", "priest", "scribe", "farmer"],
	TechEra.IRON_AGE:    ["philosopher", "engineer", "merchant"],
	TechEra.CLASSICAL:   ["physician", "architect", "librarian", "judge"],
	TechEra.MEDIEVAL:    ["knight", "alchemist", "monk", "artisan"],
	TechEra.RENAISSANCE: ["scientist", "explorer", "banker", "printer"],
	TechEra.INDUSTRIAL:  ["factory_worker", "engineer", "conductor", "machinist"],
	TechEra.ATOMIC:      ["physicist", "programmer", "surgeon", "pilot"],
	TechEra.SPACE_AGE:   ["astrobiologist", "ai_engineer", "xenologist", "orbital_navigator"],
}

const ERA_UNLOCKED_ITEMS: Dictionary = {
	TechEra.STONE_AGE:   ["stone_axe", "spear", "hide_clothing", "fire_bow"],
	TechEra.COPPER_AGE:  ["copper_dagger", "copper_pot", "trade_beads"],
	TechEra.BRONZE_AGE:  ["bronze_sword", "bronze_shield", "scroll", "bronze_armor"],
	TechEra.IRON_AGE:    ["iron_sword", "iron_plow", "iron_armor", "coin"],
	TechEra.CLASSICAL:   ["steel_gladius", "catapult", "sailing_ship", "concrete"],
	TechEra.MEDIEVAL:    ["longsword", "crossbow", "plate_armor", "windmill_blades"],
	TechEra.RENAISSANCE: ["musket", "telescope", "compass", "printing_press_device"],
	TechEra.INDUSTRIAL:  ["steam_engine", "rifle", "telegraph", "railroad_cart"],
	TechEra.ATOMIC:      ["computer", "antibiotics", "jet_engine", "nuclear_battery"],
	TechEra.SPACE_AGE:   ["fusion_core", "warp_drive", "ai_chip", "matter_deconstructor"],
}

# ============================================================================
# Internal State
# ============================================================================
var _settlement_eras: Dictionary = {}
var _global_era: int = TechEra.STONE_AGE
var _last_era_check: int = -999999
var _last_diffusion_update: int = -999999
var _last_literacy_update: int = -999999
var _last_lifespan_update: int = -999999
var _last_regression_check: int = -999999
var _last_stall_check: int = -999999

# Per-settlement literacy tracking
var _settlement_literacy: Dictionary = {}

# Per-settlement lifespan tracking
var _settlement_lifespan: Dictionary = {}

# Tech diffusion bonus per settlement: center -> float 0.0..MAX
var _diffusion_bonus: Dictionary = {}

# Advancement stall tracking: center -> { stall_ticks, warning_sent, last_era, stalled_since_tick }
var _advancement_stall: Dictionary = {}

# Previous knowledge snapshot per settlement for regression detection
var _settlement_prev_knowledge: Dictionary = {}

# Knowledge history window for trend detection (ring buffer of last N checks)
var _knowledge_history: Dictionary = {}
const KNOWLEDGE_HISTORY_DEPTH: int = 4

# Cache of building cost multipliers to avoid recomputation
var _building_cost_multiplier_cache: Dictionary = {}
var _building_cost_cache_dirty: bool = true

# ============================================================================
# Signals
# ============================================================================
signal era_advanced(center: int, old_era: int, new_era: int)
signal global_era_advanced(old_era: int, new_era: int)
signal settlement_literacy_changed(center: int, literacy: float)
signal settlement_lifespan_changed(center: int, lifespan: float)
signal era_diffusion_applied(center: int, bonus: float, source_center: int)
signal settlement_era_stalled(center: int, era: int, stall_ticks: int)
signal era_regressed(center: int, old_era: int, new_era: int, reason: String)

# ============================================================================
# Lifecycle
# ============================================================================
func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("get_node") and gm.has_signal("game_tick"):
		gm.game_tick.connect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("subscribe"):
		eb.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		if eb.has_signal("research_breakthrough"):
			eb.connect("research_breakthrough", self, "_on_research_breakthrough")

func _exit_tree() -> void:
	if not is_inside_tree():
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("game_tick") and gm.game_tick.is_connected(_on_game_tick):
		gm.game_tick.disconnect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("unsubscribe"):
		eb.unsubscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		if eb.is_connected("research_breakthrough", self, "_on_research_breakthrough"):
			eb.disconnect("research_breakthrough", self, "_on_research_breakthrough")

# ============================================================================
# Tick Handler
# ============================================================================
func _on_game_tick(tick: int) -> void:
	_update_building_cost_cache()
	if tick - _last_era_check >= ERA_CHECK_INTERVAL:
		_last_era_check = tick
		_process_era_checks(tick)
		_check_global_era(tick)
	if tick - _last_diffusion_update >= TECH_DIFFUSION_INTERVAL:
		_last_diffusion_update = tick
		_update_tech_diffusion(tick)
	if tick - _last_literacy_update >= LITERACY_UPDATE_INTERVAL:
		_last_literacy_update = tick
		_process_literacy_updates(tick)
	if tick - _last_lifespan_update >= LIFESPAN_UPDATE_INTERVAL:
		_last_lifespan_update = tick
		_process_lifespan_updates(tick)
	if tick - _last_regression_check >= ERA_REGRESSION_CHECK_INTERVAL:
		_last_regression_check = tick
		_process_regression_checks(tick)
	if tick - _last_stall_check >= ADVANCEMENT_STALL_CHECK_INTERVAL:
		_last_stall_check = tick
		_process_stall_checks(tick)

# ============================================================================
# Settlement Lifecycle Events
# ============================================================================
func _on_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	if _settlement_eras.has(center):
		return
	_settlement_eras[center] = TechEra.STONE_AGE
	_settlement_literacy[center] = LITERACY_BASE_RATE
	_settlement_lifespan[center] = LIFESPAN_BASE_YEARS
	_diffusion_bonus[center] = 0.0
	_advancement_stall[center] = {
		"stall_ticks": 0,
		"warning_sent": false,
		"last_era": TechEra.STONE_AGE,
		"stalled_since_tick": -1,
	}
	_settlement_prev_knowledge[center] = 0.0
	_knowledge_history[center] = []
	_building_cost_multiplier_cache[center] = 1.0
	if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
		print("[TechnologyEras] Registered new settlement %d at STONE_AGE" % center)

func _on_research_breakthrough(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	if _advancement_stall.has(center):
		var stall: Dictionary = _advancement_stall[center]
		stall["stall_ticks"] = maxi(0, stall.get("stall_ticks", 0) - 3000)
		stall["warning_sent"] = false
	if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
		print("[TechnologyEras] Research breakthrough reset stall counter for settlement %d" % center)

# ============================================================================
# Era Checks
# ============================================================================
func _process_era_checks(tick: int) -> void:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return
	var settlements: Array = sm.get_settlements()
	var highest_era: int = TechEra.STONE_AGE
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		if not _settlement_eras.has(center):
			_settlement_eras[center] = TechEra.STONE_AGE
		var old_era: int = _settlement_eras[center]
		var new_era: int = _determine_settlement_era(center, tick)
		_settlement_eras[center] = new_era
		if new_era > old_era:
			_on_era_advanced(center, old_era, new_era, tick)
		elif new_era < old_era:
			_on_era_regressed(center, old_era, new_era, tick)
		if new_era > highest_era:
			highest_era = new_era
	_last_era_check = tick
	_update_global_era(highest_era, tick)

func _determine_settlement_era(center: int, tick: int) -> int:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return TechEra.STONE_AGE
	var total_knowledge: float = 0.0
	if ks.has_method("get_total_knowledge"):
		total_knowledge = float(ks.get_total_knowledge(center))
	else:
		total_knowledge = _estimate_settlement_knowledge(center)
	var diffusion: float = _diffusion_bonus.get(center, 0.0)
	var effective_knowledge: float = total_knowledge * (1.0 + diffusion)
	var current_era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	for era in range(TechEra.SPACE_AGE, TechEra.STONE_AGE - 1, -1):
		var req: float = float(ERA_KNOWLEDGE_REQUIREMENTS.get(era, 99999))
		if effective_knowledge >= req:
			if era >= current_era:
				return era
			return current_era
	return current_era

func _estimate_settlement_knowledge(center: int) -> float:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("get_total_knowledge_count"):
		return 0.0
	var total_all: int = ks.get_total_knowledge_count()
	if total_all <= 0:
		return 0.0
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return float(total_all) / 10.0
	var settlement_count: int = sm.get_settlements().size()
	if settlement_count <= 1:
		return float(total_all) * 0.8
	return float(total_all) * (0.5 / float(settlement_count) + 0.3)

# ============================================================================
# Global Era
# ============================================================================
func _update_global_era(highest_era: int, tick: int) -> void:
	if highest_era > _global_era:
		var old: int = _global_era
		_global_era = highest_era
		global_era_advanced.emit(old, _global_era)
		_record_world_event("global_era_advanced", {
			"old_era": ERA_NAMES.get(old, "Unknown"),
			"new_era": ERA_NAMES.get(_global_era, "Unknown"),
			"tick": tick,
		})

func _check_global_era(tick: int) -> void:
	var highest_era: int = TechEra.STONE_AGE
	for center in _settlement_eras:
		var era: int = _settlement_eras[center]
		if era > highest_era:
			highest_era = era
	_update_global_era(highest_era, tick)

# ============================================================================
# Era Advancement Effects
# ============================================================================
func _on_era_advanced(center: int, old_era: int, new_era: int, tick: int) -> void:
	_apply_era_advancement_effects(center, new_era, old_era)
	era_advanced.emit(center, old_era, new_era)
	if _advancement_stall.has(center):
		var stall: Dictionary = _advancement_stall[center]
		stall["stall_ticks"] = 0
		stall["warning_sent"] = false
		stall["last_era"] = new_era
		stall["stalled_since_tick"] = -1
	_building_cost_cache_dirty = true
	_record_world_event("settlement_era_advanced", {
		"center": center,
		"old_era": ERA_NAMES.get(old_era, "Unknown"),
		"new_era": ERA_NAMES.get(new_era, "Unknown"),
		"tick": tick,
	})
	if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
		print("[TechnologyEras] Settlement %d advanced: %s -> %s (tick %d)" % [center, ERA_NAMES.get(old_era, "?"), ERA_NAMES.get(new_era, "?"), tick])

func _apply_era_advancement_effects(center: int, new_era: int, old_era: int) -> void:
	var era_gap: int = new_era - old_era
	if era_gap <= 0:
		return
	var literracy_bonus: float = float(era_gap) * LITERACY_PER_ERA
	var current_lit: float = _settlement_literacy.get(center, LITERACY_BASE_RATE)
	_settlement_literacy[center] = minf(current_lit + literracy_bonus, LITERACY_MAX)
	var lifespan_bonus: float = float(era_gap) * LIFESPAN_PER_ERA
	var current_ls: float = _settlement_lifespan.get(center, LIFESPAN_BASE_YEARS)
	_settlement_lifespan[center] = minf(current_ls + lifespan_bonus, LIFESPAN_MAX_YEARS)
	_building_cost_multiplier_cache.erase(center)
	var ps_node := get_node_or_null("/root/SettlementPlanner")
	if ps_node != null and ps_node.has_method("on_settlement_era_advanced"):
		ps_node.call("on_settlement_era_advanced", center, new_era, old_era)

# ============================================================================
# Tech Diffusion
# ============================================================================
func _update_tech_diffusion(tick: int) -> void:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return
	var settlements: Array = sm.get_settlements()
	var settlement_list: Array[Dictionary] = []
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
		var tile_v: Variant = st.get("tile_pos", st.get("position", null))
		if tile_v == null:
			continue
		var pos: Vector2i
		if tile_v is Dictionary:
			pos = Vector2i(int(tile_v.get("x", 0)), int(tile_v.get("y", 0)))
		elif tile_v is Vector2i:
			pos = tile_v as Vector2i
		else:
			continue
		settlement_list.append({"center": center, "era": era, "pos": pos})
	for entry in settlement_list:
		var center: int = entry["center"]
		var era: int = entry["era"]
		var pos: Vector2i = entry["pos"]
		var total_bonus: float = 0.0
		var sources: Array[int] = []
		for other in settlement_list:
			var oc: int = other["center"]
			if oc == center:
				continue
			var o_era: int = other["era"]
			if o_era <= era:
				continue
			var o_pos: Vector2i = other["pos"]
			var dist: int = absi(pos.x - o_pos.x) + absi(pos.y - o_pos.y)
			if dist > DIFFUSION_MAX_RADIUS_TILES:
				continue
			var era_gap: int = o_era - era
			var distance_factor: float = 1.0 - (float(dist) / float(DIFFUSION_MAX_RADIUS_TILES))
			var gap_bonus: float = float(era_gap) * DIFFUSION_BONUS_PER_ERA_GAP * distance_factor
			total_bonus = minf(total_bonus + gap_bonus, DIFFUSION_MAX_BONUS)
			sources.append(oc)
		var old_bonus: float = _diffusion_bonus.get(center, 0.0)
		_diffusion_bonus[center] = total_bonus
		if sources.size() > 0 and absf(total_bonus - old_bonus) > 0.001:
			era_diffusion_applied.emit(center, total_bonus, sources[0])
			if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
				print("[TechnologyEras] Diffusion: settlement %d gets +%.2f knowledge from %d higher-era neighbors" % [center, total_bonus, sources.size()])

# ============================================================================
# Literacy Tracking
# ============================================================================
func _process_literacy_updates(tick: int) -> void:
	for center in _settlement_eras:
		_update_settlement_literacy(center, tick)

func _update_settlement_literacy(center: int, tick: int) -> void:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	var target_literacy: float = minf(LITERACY_BASE_RATE + (float(era) * LITERACY_PER_ERA), LITERACY_MAX)
	var current: float = _settlement_literacy.get(center, LITERACY_BASE_RATE)
	var diff: float = target_literacy - current
	var adjustment: float = 0.0
	if absf(diff) > 0.001:
		adjustment = diff * 0.1
		if absf(adjustment) < 0.005:
			adjustment = 0.005 if diff > 0 else -0.005
		current = clampf(current + adjustment, LITERACY_BASE_RATE, LITERACY_MAX)
	else:
		return
	_settlement_literacy[center] = current
	settlement_literacy_changed.emit(center, current)
	_record_world_event("settlement_literacy_update", {
		"center": center,
		"literacy": current,
		"era": ERA_NAMES.get(era, "Unknown"),
		"tick": tick,
	})

# ============================================================================
# Lifespan Tracking
# ============================================================================
func _process_lifespan_updates(tick: int) -> void:
	for center in _settlement_eras:
		_update_settlement_lifespan(center, tick)

func _update_settlement_lifespan(center: int, tick: int) -> void:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	var target_lifespan: float = minf(LIFESPAN_BASE_YEARS + (float(era) * LIFESPAN_PER_ERA), LIFESPAN_MAX_YEARS)
	var current: float = _settlement_lifespan.get(center, LIFESPAN_BASE_YEARS)
	var diff: float = target_lifespan - current
	var adjustment: float = 0.0
	if absf(diff) > 0.05:
		adjustment = diff * 0.05
		if absf(adjustment) < 0.1:
			adjustment = 0.1 if diff > 0 else -0.1
		current = clampf(current + adjustment, LIFESPAN_BASE_YEARS, LIFESPAN_MAX_YEARS)
	else:
		return
	_settlement_lifespan[center] = current
	settlement_lifespan_changed.emit(center, current)

# ============================================================================
# Era Regression (Cataclysm / Knowledge Loss)
# ============================================================================
func _process_regression_checks(tick: int) -> void:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return
	for center in _settlement_eras:
		_check_era_regression(center, tick, ks)

func _check_era_regression(center: int, tick: int, ks: Node) -> void:
	var total_knowledge: float = 0.0
	if ks.has_method("get_total_knowledge"):
		total_knowledge = float(ks.get_total_knowledge(center))
	else:
		total_knowledge = _estimate_settlement_knowledge(center)
	var prev: float = _settlement_prev_knowledge.get(center, total_knowledge)
	var history: Array = _knowledge_history.get(center, [])
	history.append(total_knowledge)
	if history.size() > KNOWLEDGE_HISTORY_DEPTH:
		history.pop_front()
	_knowledge_history[center] = history
	var drop_ratio: float = 0.0
	if prev > 0.0 and total_knowledge < prev:
		drop_ratio = (prev - total_knowledge) / prev
	_settlement_prev_knowledge[center] = total_knowledge
	if drop_ratio < KNOWLEDGE_DROP_THRESHOLD_FOR_REGRESSION:
		return
	var current_era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	if current_era <= TechEra.STONE_AGE:
		return
	var candidate_era: int = current_era - 1
	while candidate_era > TechEra.STONE_AGE:
		var req: float = float(ERA_KNOWLEDGE_REQUIREMENTS.get(candidate_era, 0))
		if total_knowledge >= req:
			break
		candidate_era -= 1
	if candidate_era < current_era:
		_on_era_regressed(center, current_era, candidate_era, tick)
		_record_world_event("settlement_era_regressed", {
			"center": center,
			"old_era": ERA_NAMES.get(current_era, "Unknown"),
			"new_era": ERA_NAMES.get(candidate_era, "Unknown"),
			"knowledge_drop_ratio": drop_ratio,
			"tick": tick,
		})

func _on_era_regressed(center: int, old_era: int, new_era: int, tick: int) -> void:
	_settlement_eras[center] = new_era
	var lit_drop: float = float(old_era - new_era) * LITERACY_PER_ERA * 0.5
	var current_lit: float = _settlement_literacy.get(center, LITERACY_BASE_RATE)
	_settlement_literacy[center] = maxf(current_lit - lit_drop, LITERACY_BASE_RATE * 0.5)
	var ls_drop: float = float(old_era - new_era) * LIFESPAN_PER_ERA * 0.3
	var current_ls: float = _settlement_lifespan.get(center, LIFESPAN_BASE_YEARS)
	_settlement_lifespan[center] = maxf(current_ls - ls_drop, LIFESPAN_BASE_YEARS * 0.6)
	_diffusion_bonus.erase(center)
	_building_cost_multiplier_cache.erase(center)
	_building_cost_cache_dirty = true
	era_regressed.emit(center, old_era, new_era, "knowledge_loss")
	era_advanced.emit(center, old_era, new_era)
	if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
		print("[TechnologyEras] ERA REGRESSION: settlement %d fell from %s to %s (tick %d)" % [center, ERA_NAMES.get(old_era, "?"), ERA_NAMES.get(new_era, "?"), tick])

# ============================================================================
# Advancement Stall Detection
# ============================================================================
func _process_stall_checks(tick: int) -> void:
	for center in _settlement_eras:
		_check_advancement_stall(center, tick)

func _check_advancement_stall(center: int, tick: int) -> void:
	if not _advancement_stall.has(center):
		_advancement_stall[center] = {
			"stall_ticks": 0,
			"warning_sent": false,
			"last_era": _settlement_eras.get(center, TechEra.STONE_AGE),
			"stalled_since_tick": -1,
		}
	var stall: Dictionary = _advancement_stall[center]
	var current_era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	var last_era: int = stall.get("last_era", current_era)
	if current_era != last_era:
		stall["stall_ticks"] = 0
		stall["warning_sent"] = false
		stall["last_era"] = current_era
		stall["stalled_since_tick"] = -1
		return
	if current_era >= TechEra.SPACE_AGE:
		return
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return
	var total_knowledge: float = 0.0
	if ks.has_method("get_total_knowledge"):
		total_knowledge = float(ks.get_total_knowledge(center))
	else:
		total_knowledge = _estimate_settlement_knowledge(center)
	var next_era: int = mini(current_era + 1, TechEra.SPACE_AGE)
	var next_req: float = float(ERA_KNOWLEDGE_REQUIREMENTS.get(next_era, 99999))
	if total_knowledge >= next_req * 0.8 and total_knowledge < next_req:
		stall["stall_ticks"] = stall.get("stall_ticks", 0) + ADVANCEMENT_STALL_CHECK_INTERVAL
	else:
		stall["stall_ticks"] = maxi(0, stall.get("stall_ticks", 0) - 500)
	if stall.get("stalled_since_tick", -1) < 0 and stall.get("stall_ticks", 0) >= MAX_STALLED_TICKS_BEFORE_WARNING:
		stall["stalled_since_tick"] = tick
	var stall_ticks: int = stall.get("stall_ticks", 0)
	if stall_ticks >= ADVANCEMENT_STALL_TICK_THRESHOLD and not stall.get("warning_sent", false):
		stall["warning_sent"] = true
		settlement_era_stalled.emit(center, current_era, stall_ticks)
		_record_world_event("settlement_era_stalled", {
			"center": center,
			"era": ERA_NAMES.get(current_era, "Unknown"),
			"stall_ticks": stall_ticks,
			"knowledge_progress": total_knowledge,
			"next_era_requirement": next_req,
			"tick": tick,
		})
		if GameManager != null and GameManager.has_method("verbose_logs") and GameManager.verbose_logs():
			print("[TechnologyEras] STALL WARNING: settlement %d stuck at %s for %d ticks (knowledge %d/%d)" % [center, ERA_NAMES.get(current_era, "?"), stall_ticks, int(total_knowledge), int(next_req)])

# ============================================================================
# Building Cost Modifiers
# ============================================================================
func _update_building_cost_cache() -> void:
	if not _building_cost_cache_dirty:
		return
	_building_cost_multiplier_cache.clear()
	for center in _settlement_eras:
		var era: int = _settlement_eras[center]
		var multiplier: float = 1.0 + (float(era) * BUILDING_COST_SCALE_PER_ERA)
		_building_cost_multiplier_cache[center] = multiplier
	_building_cost_cache_dirty = false

func get_building_cost_multiplier(center: int) -> float:
	if _building_cost_multiplier_cache.has(center):
		return _building_cost_multiplier_cache[center]
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	var multiplier: float = 1.0 + (float(era) * BUILDING_COST_SCALE_PER_ERA)
	_building_cost_multiplier_cache[center] = multiplier
	return multiplier

func get_research_speed_multiplier(center: int) -> float:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	return RESEARCH_SPEED_BASE_MULTIPLIER + (float(era) * RESEARCH_SPEED_PER_ERA)

func get_building_speed_multiplier(center: int) -> float:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	return BUILDING_SPEED_BASE_MULTIPLIER + (float(era) * BUILDING_SPEED_PER_ERA)

func get_max_population_bonus(center: int) -> int:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	return MAX_POP_BASE + (era * MAX_POP_PER_ERA)

# ============================================================================
# Era Unlocks
# ============================================================================
func get_unlocked_buildings_for_era(era: int) -> Array:
	var result: Array = []
	for e in range(TechEra.STONE_AGE, era + 1):
		var buildings: Array = ERA_UNLOCKED_BUILDINGS.get(e, [])
		for b in buildings:
			if not (b in result):
				result.append(b)
	return result

func get_unlocked_jobs_for_era(era: int) -> Array:
	var result: Array = []
	for e in range(TechEra.STONE_AGE, era + 1):
		var jobs: Array = ERA_UNLOCKED_JOBS.get(e, [])
		for j in jobs:
			if not (j in result):
				result.append(j)
	return result

func get_unlocked_items_for_era(era: int) -> Array:
	var result: Array = []
	for e in range(TechEra.STONE_AGE, era + 1):
		var items: Array = ERA_UNLOCKED_ITEMS.get(e, [])
		for it in items:
			if not (it in result):
				result.append(it)
	return result

func get_settlement_unlocked_buildings(center: int) -> Array:
	return get_unlocked_buildings_for_era(_settlement_eras.get(center, TechEra.STONE_AGE))

func get_settlement_unlocked_jobs(center: int) -> Array:
	return get_unlocked_jobs_for_era(_settlement_eras.get(center, TechEra.STONE_AGE))

func get_settlement_unlocked_items(center: int) -> Array:
	return get_unlocked_items_for_era(_settlement_eras.get(center, TechEra.STONE_AGE))

func is_building_unlocked(building_type: String, center: int) -> bool:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	for e in range(TechEra.STONE_AGE, era + 1):
		var buildings: Array = ERA_UNLOCKED_BUILDINGS.get(e, [])
		if building_type in buildings:
			return true
	return false

func is_job_unlocked(job_type: String, center: int) -> bool:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	for e in range(TechEra.STONE_AGE, era + 1):
		var jobs: Array = ERA_UNLOCKED_JOBS.get(e, [])
		if job_type in jobs:
			return true
	return false

func is_item_unlocked(item_type: String, center: int) -> bool:
	var era: int = _settlement_eras.get(center, TechEra.STONE_AGE)
	for e in range(TechEra.STONE_AGE, era + 1):
		var items: Array = ERA_UNLOCKED_ITEMS.get(e, [])
		if item_type in items:
			return true
	return false

# ============================================================================
# Public Query API
# ============================================================================
func get_settlement_era(center: int) -> int:
	return _settlement_eras.get(center, TechEra.STONE_AGE)

func get_era_name(center: int) -> String:
	return ERA_NAMES.get(get_settlement_era(center), "Unknown")

func get_era_description(era: int) -> String:
	return ERA_DESCRIPTIONS.get(era, "An unknown age.")

func get_global_era() -> int:
	return _global_era

func get_global_era_name() -> String:
	return ERA_NAMES.get(_global_era, "Unknown")

func get_era_progress(center: int) -> float:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return 0.0
	var total: float = 0.0
	if ks.has_method("get_total_knowledge"):
		total = float(ks.get_total_knowledge(center))
	else:
		total = _estimate_settlement_knowledge(center)
	var diffusion: float = _diffusion_bonus.get(center, 0.0)
	var effective: float = total * (1.0 + diffusion)
	var current_era: int = get_settlement_era(center)
	var current_req: float = float(ERA_KNOWLEDGE_REQUIREMENTS.get(current_era, 0))
	var next_era: int = mini(current_era + 1, TechEra.SPACE_AGE)
	var next_req: float = float(ERA_KNOWLEDGE_REQUIREMENTS.get(next_era, 99999))
	if next_req <= current_req:
		return 1.0
	var raw_progress: float = (effective - current_req) / (next_req - current_req)
	return clampf(raw_progress, 0.0, 1.0)

func get_knowledge_requirement_for_era(era: int) -> int:
	return ERA_KNOWLEDGE_REQUIREMENTS.get(era, 99999)

func get_settlement_literacy(center: int) -> float:
	return _settlement_literacy.get(center, LITERACY_BASE_RATE)

func get_settlement_lifespan(center: int) -> float:
	return _settlement_lifespan.get(center, LIFESPAN_BASE_YEARS)

func get_tech_diffusion_bonus(center: int) -> float:
	return _diffusion_bonus.get(center, 0.0)

func get_settlement_knowledge_with_diffusion(center: int) -> Dictionary:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var raw: float = 0.0
	if ks != null and ks.has_method("get_total_knowledge"):
		raw = float(ks.get_total_knowledge(center))
	else:
		raw = _estimate_settlement_knowledge(center)
	var diffusion: float = _diffusion_bonus.get(center, 0.0)
	return {
		"raw_knowledge": raw,
		"diffusion_bonus": diffusion,
		"effective_knowledge": raw * (1.0 + diffusion),
		"era": get_settlement_era(center),
	}

func get_settlement_stall_info(center: int) -> Dictionary:
	if not _advancement_stall.has(center):
		return {"stall_ticks": 0, "warning_sent": false, "stalled": false}
	var stall: Dictionary = _advancement_stall[center]
	return {
		"stall_ticks": stall.get("stall_ticks", 0),
		"warning_sent": stall.get("warning_sent", false),
		"stalled_since_tick": stall.get("stalled_since_tick", -1),
		"stalled": stall.get("stall_ticks", 0) >= ADVANCEMENT_STALL_TICK_THRESHOLD,
		"last_era": stall.get("last_era", TechEra.STONE_AGE),
	}

# ============================================================================
# Debug / Stats
# ============================================================================
func get_era_report(center: int) -> Dictionary:
	var era: int = get_settlement_era(center)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var total: float = 0.0
	if ks != null and ks.has_method("get_total_knowledge"):
		total = float(ks.get_total_knowledge(center))
	var progress: float = get_era_progress(center)
	var literacy: float = get_settlement_literacy(center)
	var lifespan: float = get_settlement_lifespan(center)
	var diffusion: float = get_tech_diffusion_bonus(center)
	var stall: Dictionary = get_settlement_stall_info(center)
	var next_era: int = mini(era + 1, TechEra.SPACE_AGE)
	var next_req: int = get_knowledge_requirement_for_era(next_era)
	return {
		"center": center,
		"era": era,
		"era_name": ERA_NAMES.get(era, "Unknown"),
		"era_description": ERA_DESCRIPTIONS.get(era, ""),
		"knowledge": total,
		"next_era_requirement": next_req,
		"progress_to_next": progress,
		"literacy": literacy,
		"average_lifespan": lifespan,
		"diffusion_bonus": diffusion,
		"research_speed_multiplier": get_research_speed_multiplier(center),
		"building_speed_multiplier": get_building_speed_multiplier(center),
		"building_cost_multiplier": get_building_cost_multiplier(center),
		"max_population_bonus": get_max_population_bonus(center),
		"unlocked_buildings": get_settlement_unlocked_buildings(center),
		"unlocked_jobs": get_settlement_unlocked_jobs(center),
		"unlocked_items": get_settlement_unlocked_items(center),
		"stall": stall,
	}

func get_global_progress() -> Dictionary:
	var era_counts: Dictionary = {}
	var era_knowledge: Dictionary = {}
	for e in TechEra.values():
		era_counts[e] = 0
		era_knowledge[e] = 0.0
	var total_settlements: int = _settlement_eras.size()
	for center in _settlement_eras:
		var e: int = _settlement_eras[center]
		era_counts[e] = era_counts.get(e, 0) + 1
		var ks := get_node_or_null("/root/KnowledgeSystem")
		if ks != null and ks.has_method("get_total_knowledge"):
			era_knowledge[e] = era_knowledge.get(e, 0.0) + float(ks.get_total_knowledge(center))
	var most_common_era: int = TechEra.STONE_AGE
	var most_common_count: int = 0
	for e in TechEra.values():
		var c: int = era_counts.get(e, 0)
		if c > most_common_count:
			most_common_count = c
			most_common_era = e
	return {
		"global_era": _global_era,
		"global_era_name": ERA_NAMES.get(_global_era, "Unknown"),
		"total_settlements": total_settlements,
		"era_distribution": era_counts,
		"era_knowledge_totals": era_knowledge,
		"most_common_era": most_common_era,
		"most_common_era_name": ERA_NAMES.get(most_common_era, "Unknown"),
		"most_common_era_count": most_common_count,
		"average_progress": _calculate_average_era_progress(),
	}

func get_era_distribution_map() -> Dictionary:
	var distribution: Dictionary = {}
	for e in TechEra.values():
		distribution[ERA_NAMES.get(e, "Unknown")] = []
	for center in _settlement_eras:
		var e: int = _settlement_eras[center]
		var name: String = ERA_NAMES.get(e, "Unknown")
		if not distribution.has(name):
			distribution[name] = []
		distribution[name].append(center)
	return {
		"distribution": distribution,
		"total_by_era": _count_by_era(),
	}

func _calculate_average_era_progress() -> float:
	if _settlement_eras.is_empty():
		return 0.0
	var total_progress: float = 0.0
	var count: int = 0
	for center in _settlement_eras:
		total_progress += get_era_progress(center)
		count += 1
	if count <= 0:
		return 0.0
	return total_progress / float(count)

func _count_by_era() -> Dictionary:
	var counts: Dictionary = {}
	for e in TechEra.values():
		counts[ERA_NAMES.get(e, "Unknown")] = 0
	for center in _settlement_eras:
		var e: int = _settlement_eras[center]
		var name: String = ERA_NAMES.get(e, "Unknown")
		counts[name] = counts.get(name, 0) + 1
	return counts

func get_stats() -> Dictionary:
	var era_counts: Dictionary = _count_by_era()
	var total_knowledge_pool: float = 0.0
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("get_total_knowledge_count"):
		total_knowledge_pool = float(ks.get_total_knowledge_count())
	return {
		"global_era": ERA_NAMES.get(_global_era, "Unknown"),
		"global_era_index": _global_era,
		"era_counts": era_counts,
		"total_settlements": _settlement_eras.size(),
		"total_knowledge_pool": total_knowledge_pool,
		"average_literacy": _calculate_average_literacy(),
		"average_lifespan": _calculate_average_lifespan(),
	}

func _calculate_average_literacy() -> float:
	if _settlement_eras.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for center in _settlement_literacy:
		total += _settlement_literacy[center]
		count += 1
	if count <= 0:
		return 0.0
	return total / float(count)

func _calculate_average_lifespan() -> float:
	if _settlement_eras.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for center in _settlement_lifespan:
		total += _settlement_lifespan[center]
		count += 1
	if count <= 0:
		return 0.0
	return total / float(count)

# ============================================================================
# WorldMemory Event Recording
# ============================================================================
func _record_world_event(event_type: String, payload: Dictionary) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event(payload)

# ============================================================================
# Save / Load
# ============================================================================
func get_save_data() -> Dictionary:
	var era_data: Dictionary = {}
	for center in _settlement_eras:
		era_data[str(center)] = _settlement_eras[center]
	var literacy_data: Dictionary = {}
	for center in _settlement_literacy:
		literacy_data[str(center)] = _settlement_literacy[center]
	var lifespan_data: Dictionary = {}
	for center in _settlement_lifespan:
		lifespan_data[str(center)] = _settlement_lifespan[center]
	var diffusion_data: Dictionary = {}
	for center in _diffusion_bonus:
		diffusion_data[str(center)] = _diffusion_bonus[center]
	var stall_data: Dictionary = {}
	for center in _advancement_stall:
		stall_data[str(center)] = _advancement_stall[center].duplicate()
	var prev_knowledge_data: Dictionary = {}
	for center in _settlement_prev_knowledge:
		prev_knowledge_data[str(center)] = _settlement_prev_knowledge[center]
	var knowledge_history_data: Dictionary = {}
	for center in _knowledge_history:
		knowledge_history_data[str(center)] = _knowledge_history[center].duplicate()
	return {
		"version": 2,
		"settlement_eras": era_data,
		"global_era": _global_era,
		"last_era_check": _last_era_check,
		"last_diffusion_update": _last_diffusion_update,
		"settlement_literacy": literacy_data,
		"settlement_lifespan": lifespan_data,
		"diffusion_bonus": diffusion_data,
		"advancement_stall": stall_data,
		"settlement_prev_knowledge": prev_knowledge_data,
		"knowledge_history": knowledge_history_data,
	}

func load_from_save(data: Dictionary) -> void:
	clear()
	var version: int = int(data.get("version", 1))
	var era_data: Dictionary = data.get("settlement_eras", {})
	for key in era_data:
		var center: int = int(key)
		_settlement_eras[center] = int(era_data[key])
	_global_era = int(data.get("global_era", TechEra.STONE_AGE))
	_last_era_check = int(data.get("last_era_check", -999999))
	_last_diffusion_update = int(data.get("last_diffusion_update", -999999))
	var literacy_data: Dictionary = data.get("settlement_literacy", {})
	for key in literacy_data:
		_settlement_literacy[int(key)] = float(literacy_data[key])
	var lifespan_data: Dictionary = data.get("settlement_lifespan", {})
	for key in lifespan_data:
		_settlement_lifespan[int(key)] = float(lifespan_data[key])
	var diffusion_data: Dictionary = data.get("diffusion_bonus", {})
	for key in diffusion_data:
		_diffusion_bonus[int(key)] = float(diffusion_data[key])
	if version >= 2:
		var stall_data: Dictionary = data.get("advancement_stall", {})
		for key in stall_data:
			_advancement_stall[int(key)] = (stall_data[key] as Dictionary).duplicate()
		var prev_data: Dictionary = data.get("settlement_prev_knowledge", {})
		for key in prev_data:
			_settlement_prev_knowledge[int(key)] = float(prev_data[key])
		var hist_data: Dictionary = data.get("knowledge_history", {})
		for key in hist_data:
			_knowledge_history[int(key)] = (hist_data[key] as Array).duplicate()
	_building_cost_cache_dirty = true

func clear() -> void:
	_settlement_eras.clear()
	_global_era = TechEra.STONE_AGE
	_last_era_check = -999999
	_last_diffusion_update = -999999
	_last_literacy_update = -999999
	_last_lifespan_update = -999999
	_last_regression_check = -999999
	_last_stall_check = -999999
	_settlement_literacy.clear()
	_settlement_lifespan.clear()
	_diffusion_bonus.clear()
	_advancement_stall.clear()
	_settlement_prev_knowledge.clear()
	_knowledge_history.clear()
	_building_cost_multiplier_cache.clear()
	_building_cost_cache_dirty = true
