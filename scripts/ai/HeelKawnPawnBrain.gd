class_name HeelKawnPawnBrain
extends RefCounted

## The "One of One" HeelKawnian Brain — WorldBox scale + Bannerlord RPG depth + Kenshi survival
## Every pawn is as intelligent as a player, with full autonomy and agency.
##
## Combines:
##  - PawnNeuralNetwork: forward-pass decision matrix (RimWorld-style needs + Bannerlord combat)
##  - PawnDecisionRuleMatrix: human-readable if/then policy layer
##  - LongTermMemory: personal history, grudges, accomplishments
##  - GoalEngine: lifelong aspirations + daily survival (Crusader Kings life goals)
##  - GossipPropagation: social information network (Crusader Kings diplomacy)
##  - CareerXP: skill-based progression (Bannerlord/Kenshi RPG)
##  - DramaticEventGenerator: narrative story engine
##  - WorldAI neural matrix: global state influence on local decisions
##  - CombatResolver: Bannerlord-style melee/ranged combat awareness
##  - SettlementAI: settlement-level goals and diplomacy

signal decision_made(pawn_id: int, action: String, confidence: float)
signal story_beat_fired(pawn_id: int, beat: Dictionary)
signal goal_changed(pawn_id: int, old_goal: String, new_goal: String)
signal combat_engaged(pawn_id: int, target_id: int, combat_type: String)
signal social_interaction(pawn_id: int, target_id: int, interaction_type: String)

# === Core References ===
var _pawn_id: int = -1
var _pawn_data: HeelKawnianData = null
var _world: Node2D = null

# === AI Sub-Systems ===
var neural_network: PawnNeuralNetwork = null
var decision_matrix: PawnDecisionRuleMatrix = null
var long_term_memory: LongTermMemory = null
var goal_engine: GoalEngine = null
var gossip: GossipPropagation = null
var career: CareerXP = null
var dramatic_engine: DramaticEventGenerator = null

# === World References (cached) ===
var _ai_manager: Node = null
var _learning_system: Node = null
var _world_ai: Node = null
var _settlement_ai: Node = null
var _combat_resolver: Node = null

# === Decision Context (rebuilt each tick) ===
var _decision_context: Dictionary = {}
var _current_world_state: Dictionary = {}
var _neural_outputs: Array[float] = []
var _decision_scores: Dictionary = {}

var _world_state_cache_tick: int = -10000

# === Brain Configuration ===
const DECISION_INTERVAL_TICKS: int = 8  # Re-evaluate major decisions every N ticks
const NEURAL_FORWARD_INTERVAL: int = 4  # Run neural forward pass every N ticks
const GOAL_CHECK_INTERVAL: int = 1000  # Refresh goals every ~1 in-game day
const COMBAT_SCAN_RADIUS_PX: float = 80.0  # Bannerlord-style combat awareness
const SOCIAL_SCAN_RADIUS_PX: float = 60.0  # Social interaction range
const WORLD_STATE_CACHE_TICKS: int = 100  # How often to refresh world state snapshot

# === Performance Tracking ===
var _last_decision_tick: int = 0
var _last_neural_tick: int = 0
var _last_goal_refresh_tick: int = 0
var _ticks_processed: int = 0
var _decisions_made: int = 0

# === Initialization ===
func _init(pawn_data: HeelKawnianData, world: Node2D) -> void:
	_pawn_data = pawn_data
	_pawn_id = int(pawn_data.id) if pawn_data != null else -1
	_world = world

	# Initialize all AI sub-systems
	_initialize_neural_network()
	_initialize_decision_matrix()
	_initialize_memory_systems()
	_initialize_goal_systems()
	_initialize_career_system()
	_initialize_dramatic_engine()

	# Cache world references
	_cache_world_references()

	# Build initial context
	# Build initial context (use current tick; pawn may be null during init)
	_rebuild_decision_context(null, GameManager.tick_count if GameManager != null else 0)


func _initialize_neural_network() -> void:
	var nn_script := load("res://scripts/pawn/PawnNeuralNetwork.gd")
	if nn_script == null:
		push_warning("PawnBrain: Failed to load PawnNeuralNetwork script")
		return
	neural_network = nn_script.new()
	if neural_network == null:
		push_warning("PawnBrain: Failed to load PawnNeuralNetwork")
		return
	# Initialize with pawn's personality traits
	var personality: Dictionary = {}
	if _pawn_data != null:
		personality = {
			"openness": _pawn_data.openness,
			"conscientiousness": _pawn_data.conscientiousness,
			"extraversion": _pawn_data.extraversion,
			"agreeableness": _pawn_data.agreeableness,
			"neuroticism": _pawn_data.neuroticism,
		}
	neural_network._init(personality)


func _initialize_decision_matrix() -> void:
	decision_matrix = PawnDecisionRuleMatrix.new()


func _initialize_memory_systems() -> void:
	long_term_memory = LongTermMemory.new(_pawn_id)
	gossip = GossipPropagation.new(_pawn_id)


func _initialize_goal_systems() -> void:
	goal_engine = GoalEngine.new(_pawn_id)


func _initialize_career_system() -> void:
	career = CareerXP.new(_pawn_id)


func _initialize_dramatic_engine() -> void:
	dramatic_engine = DramaticEventGenerator.new(_pawn_id)


func _cache_world_references() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root: Node = tree.root
	_ai_manager = root.get_node_or_null("/root/AIManager")
	if _ai_manager != null and _ai_manager.has_method("get_learning"):
		_learning_system = _ai_manager.get_learning()
	_world_ai = root.get_node_or_null("/root/WorldAI")
	_combat_resolver = root.get_node_or_null("/root/CombatResolver")
	# SettlementAI is per-settlement, resolved on demand


# === Main Brain Tick (called from HeelKawnian._on_world_tick) ===
## Optimized for 39,000 ticks @ 100x speed with thousands of pawns.
## Uses stride-based throttling + lightweight path for distant pawns.
func brain_tick(sim_tick: int, pawn: HeelKawnian) -> Dictionary:
	_ticks_processed += 1

	# Stride-based throttling: not every pawn runs full AI every tick.
	# This is the "One of One" secret: stagger so the sim never spikes.
	var pid: int = _pawn_id
	var stride: int = _compute_stride()
	var run_full_ai: bool = stride <= 1 or (posmod(sim_tick + pid, stride) == 0)

	if not run_full_ai:
		# Lightweight tick for non-primary ticks (survival only, Kenshi-style)
		return _lightweight_tick(sim_tick, pawn)

	# --- Full AI tick (staggered across pawns) ---

	# HIGH-SPEED THROTTLE: At 100x speed, only run full decisions every 4 ticks per pawn
	var game_speed: float = GameManager.game_speed if GameManager != null else 1.0
	if game_speed > 20.0:
		var throttle_interval: int = 4
		if not (posmod(sim_tick + pid, throttle_interval) == 0):
			return _lightweight_tick(sim_tick, pawn)

	# 1. Rebuild decision context (what does the pawn know right now?)
	_rebuild_decision_context(pawn, sim_tick)

	# 2. Neural forward pass (every NEURAL_FORWARD_INTERVAL ticks)
	if posmod(sim_tick, NEURAL_FORWARD_INTERVAL) == 0 or sim_tick - _last_neural_tick >= NEURAL_FORWARD_INTERVAL:
		_run_neural_forward_pass(sim_tick)

	# 3. Run decision matrix (uses neural outputs + context)
	var decision: Dictionary = _run_decision_matrix(pawn, sim_tick)

	# 4. Check if we should trigger a dramatic story beat
	if posmod(sim_tick, 2000) == 0:
		_check_dramatic_events(pawn, sim_tick)

	# 5. Refresh goals periodically
	if sim_tick - _last_goal_refresh_tick >= GOAL_CHECK_INTERVAL:
		_refresh_goals(sim_tick)
		_last_goal_refresh_tick = sim_tick

	# 6. Combat awareness (Bannerlord-style) — only if in danger or near enemies
	if posmod(sim_tick + pid * 3, 23) == 0:
		_scan_for_combat_threats(pawn, sim_tick)

	# 7. Social scan (Crusader Kings-style) — staggered
	if posmod(sim_tick + pid * 5, 45) == 0:
		_scan_for_social_interactions(pawn, sim_tick)

	# 8. Update career XP based on recent actions
	_update_career_tracking(pawn, sim_tick)

	return decision


# === Stride Computation (WorldBox-scale optimization) ===
## Target: ~10,000 full AI ticks per real-time second at any speed.
## Formula: stride = ceil(game_speed * num_pawns / target_tps)
## With 2000 pawns, target 10k TPS:
##   1x   → stride ≈ 1
##   12x  → stride ≈ 2-3
##   26x  → stride ≈ 5-6
##   50x  → stride ≈ 10
##   100x → stride ≈ 20
func _compute_stride() -> int:
	if GameManager == null:
		return 1
	var gs: float = GameManager.game_speed
	var stride: int = 1
	if gs >= 100.0:
		stride = 20  # ~10k full AI TPS at 100x with 2000 pawns
	elif gs >= 50.0:
		stride = 10
	elif gs >= 26.0:
		stride = 6
	elif gs >= 12.0:
		stride = 3
	else:
		stride = 1  # 1x: every pawn every tick

	# Distance-based LOD (WorldBox-style): wanderers tick even less.
	if stride > 1 and _pawn_data != null and _pawn_data.settlement_id < 0:
		stride = min(stride * 2, 30)

	return stride


# === Lightweight Tick (Kenshi survival — ultra-fast) ===
func _lightweight_tick(sim_tick: int, pawn: HeelKawnian) -> Dictionary:
	# Only process critical survival needs + basic combat.
	# Used for staggered ticks where full AI doesn't run.
	if _pawn_data == null or pawn == null:
		return {"action": "idle", "confidence": 0.0}

	var result: Dictionary = {"action": "idle", "confidence": 0.0}

	# Critical survival checks (RimWorld-style)
	if _pawn_data.hunger <= 22.0:
		result["action"] = "seek_food"
		result["confidence"] = 0.9
	elif _pawn_data.rest <= 20.0:
		result["action"] = "seek_rest"
		result["confidence"] = 0.85
	elif _pawn_data.health <= 30.0:
		result["action"] = "withdraw"
		result["confidence"] = 0.8

	# Basic combat scan (Bannerlord-style) — very infrequent
	if posmod(sim_tick + _pawn_id * 7, 45) == 0:
		if _combat_resolver != null and "get_enemies_near_position" in _combat_resolver:
			# Placeholder for combat check
			pass

	return result


# === Decision Context: What the HeelKawnian Knows ===
## Optimized: only rebuild dynamic parts; static parts cached via _ctx_initialized flag.
var _ctx_initialized: bool = false
var _ctx_static_dirty: bool = true
var _ctx_last_state: int = -1
var _ctx_last_tile: Vector2i = Vector2i(-99999, -99999)
var _ctx_last_settlement: int = -99999

func _rebuild_decision_context(pawn: HeelKawnian, sim_tick: int) -> void:
	if _pawn_data == null:
		return

	# --- One-time static context (personality + affinities) ---
	if not _ctx_initialized or _ctx_static_dirty:
		_decision_context.clear()
		# Personality (never changes)
		_decision_context["extraversion"] = _pawn_data.extraversion
		_decision_context["agreeableness"] = _pawn_data.agreeableness
		_decision_context["neuroticism"] = _pawn_data.neuroticism
		_decision_context["conscientiousness"] = _pawn_data.conscientiousness
		_decision_context["openness"] = _pawn_data.openness
		# Job affinities (rarely changes)
		for key in _pawn_data.affinities.keys():
			_decision_context["affinity_%s" % key] = _pawn_data.affinities[key]
		# Combat readiness
		_decision_context["combat_affinity"] = _pawn_data.affinities.get("combat", 0.5)
		_decision_context["has_weapon"] = _pawn_data.has_weapon() if "has_weapon" in _pawn_data else false
		_ctx_static_dirty = false
		_ctx_initialized = true

	# --- Dynamic needs (RimWorld-style) ---
	_decision_context["hunger"] = _pawn_data.hunger
	_decision_context["rest"] = _pawn_data.rest
	_decision_context["mood"] = _pawn_data.mood
	_decision_context["health"] = _pawn_data.health
	_decision_context["max_health"] = _pawn_data.max_health
	_decision_context["pain"] = _pawn_data.pain
	_decision_context["exposure_sickness"] = _pawn_data.exposure_sickness

	# --- HeelKawnian state (only update if changed) ---
	var cur_state: int = pawn._state if pawn != null else 0
	if cur_state != _ctx_last_state:
		_decision_context["state"] = cur_state
		_ctx_last_state = cur_state
	if pawn != null and pawn.data != null:
		_decision_context["is_carrying"] = pawn.data.is_carrying()
		_decision_context["carrying_food"] = pawn.data.carrying == Item.Type.BERRY or pawn.data.carrying == Item.Type.MEAT
	var cur_tile: Vector2i = _pawn_data.tile_pos
	if cur_tile != _ctx_last_tile:
		_decision_context["tile_pos"] = cur_tile
		_ctx_last_tile = cur_tile

	# --- Tick info ---
	_decision_context["tick"] = sim_tick
	if pawn != null:
		_decision_context["founding_blend"] = pawn._founding_blend()

	# --- World state (from WorldAI neural matrix) ---
	_update_world_state_cache(sim_tick)

	# --- Settlement info (only update if changed) ---
	var cur_settlement: int = _pawn_data.settlement_id
	if cur_settlement != _ctx_last_settlement:
		_decision_context["settlement_id"] = cur_settlement
		_ctx_last_settlement = cur_settlement
		var rk: int = ((int(cur_tile.x) >> 4) & 0xFFFF) | (((int(cur_tile.y) >> 4) & 0xFFFF) << 16)
		_decision_context["region_key"] = rk

	_update_learning_context()


func _update_world_state_cache(sim_tick: int) -> void:
	if sim_tick - _world_state_cache_tick < WORLD_STATE_CACHE_TICKS and not _current_world_state.is_empty():
		_decision_context.merge(_current_world_state, false)
		return

	_current_world_state.clear()

	if _world_ai != null and _world_ai.has_method("get_neural_network_summary"):
		var summary: Dictionary = _world_ai.get_neural_network_summary()
		_current_world_state["collapse_risk"] = summary.get("collapse_risk", 0.0)
		_current_world_state["economic_stability"] = summary.get("economic_stability", 0.0)
		_current_world_state["religious_fervor"] = summary.get("religious_fervor", 0.0)
		_current_world_state["social_cohesion"] = summary.get("social_cohesion", 0.0)
		_current_world_state["military_strength"] = summary.get("military_strength", 0.0)
		_current_world_state["tech_innovation"] = summary.get("innovation_rate", 0.0)

	_world_state_cache_tick = sim_tick
	_decision_context.merge(_current_world_state, false)


func _update_learning_context() -> void:
	if _learning_system == null:
		return

	if _learning_system.has_method("get_weight"):
		_decision_context["learning_food_weight"] = float(_learning_system.get_weight("food_production"))
		_decision_context["learning_resource_weight"] = float(_learning_system.get_weight("resource_gathering"))
		_decision_context["learning_military_weight"] = float(_learning_system.get_weight("military_training"))
		_decision_context["learning_defense_weight"] = float(_learning_system.get_weight("defense_building"))
		_decision_context["learning_construction_weight"] = float(_learning_system.get_weight("construction"))

	if _learning_system.has_method("get_stats"):
		var stats: Dictionary = _learning_system.get_stats()
		_decision_context["learning_patterns_learned"] = int(stats.get("patterns_learned", 0))
		_decision_context["learning_weights_adjusted"] = int(stats.get("weights_adjusted", 0))


# === Neural Forward Pass ===
func _run_neural_forward_pass(sim_tick: int) -> void:
	if neural_network == null:
		return

	# Build neural input (32 inputs to match network structure)
	var neural_input: Array[float] = _build_neural_input()

	# Forward propagate
	_neural_outputs = neural_network.forward_propagate(neural_input)
	_last_neural_tick = sim_tick


func _build_neural_input() -> Array[float]:
	var input: Array[float] = []
	input.resize(32)
	input.fill(0.0)

	# Needs (0-3)
	input[0] = (_decision_context.get("hunger", 50.0)) / 100.0
	input[1] = (_decision_context.get("rest", 50.0)) / 100.0
	input[2] = (_decision_context.get("mood", 50.0)) / 100.0
	input[3] = (_decision_context.get("health", 50.0)) / 100.0

	# Personality (4-8)
	input[4] = _decision_context.get("extraversion", 0.5)
	input[5] = _decision_context.get("agreeableness", 0.5)
	input[6] = _decision_context.get("neuroticism", 0.5)
	input[7] = _decision_context.get("conscientiousness", 0.5)
	input[8] = _decision_context.get("openness", 0.5)

	# World state (9-15)
	input[9] = _decision_context.get("collapse_risk", 0.5)
	input[10] = _decision_context.get("economic_stability", 0.5)
	input[11] = _decision_context.get("religious_fervor", 0.5)
	input[12] = _decision_context.get("social_cohesion", 0.0)
	input[13] = _decision_context.get("military_strength", 0.0)
	input[14] = _decision_context.get("tech_innovation", 0.0)
	input[15] = _decision_context.get("founding_blend", 0.0)

	# Combat readiness (16-18)
	input[16] = 1.0 if _decision_context.get("has_weapon", false) else 0.0
	input[17] = _decision_context.get("combat_affinity", 0.5)
	input[18] = (_decision_context.get("pain", 0.0)) / 100.0

	# Career progress (19-22)
	var career_level: float = float(career._xp_level) / 3.0 if career != null else 0.0
	input[19] = career_level
	input[20] = float(career._xp_total) / 1000.0 if career != null else 0.0
	input[21] = 1.0 if goal_engine != null and not goal_engine._lifelong_aspirations.is_empty() else 0.0

	# Memory pressure (22-23)
	var memory_count: int = long_term_memory._memories.size() if long_term_memory != null else 0
	input[22] = clampf(float(memory_count) / 64.0, 0.0, 1.0)
	input[23] = float(long_term_memory._memories.size()) / 100.0 if long_term_memory != null else 0.0

	# Social (24-26)
	input[24] = _decision_context.get("extraversion", 0.5)
	input[25] = _decision_context.get("agreeableness", 0.5)

	# Time (27-31)
	var tick_norm: float = float(posmod(_decision_context.get("tick", 0), 10000)) / 10000.0
	input[27] = tick_norm
	input[28] = sin(tick_norm * TAU)
	input[29] = cos(tick_norm * TAU)
	input[30] = float(posmod(_pawn_id, 100)) / 100.0
	input[31] = _decision_context.get("founding_blend", 0.0)

	return input


# === Decision Matrix (PawnDecisionRuleMatrix) ===
func _run_decision_matrix(_pawn: HeelKawnian, _sim_tick: int) -> Dictionary:
	if decision_matrix == null or _pawn_data == null:
		return {"action": "idle", "confidence": 0.0}

	# Build context for decision matrix
	var ctx: Dictionary = _decision_context.duplicate(true)

	# Add neural outputs to context (if available)
	if not _neural_outputs.is_empty():
		ctx["neural_outputs"] = _neural_outputs.duplicate()
		# Map neural outputs to human-readable channels
		for i in range(min(_neural_outputs.size(), decision_matrix.HUMAN_CHANNEL_LABELS.size())):
			ctx["neural_%s" % decision_matrix.HUMAN_CHANNEL_LABELS[i]] = _neural_outputs[i]

	# Run decision matrix evaluation
	var eval_result: Dictionary = decision_matrix.evaluate(_pawn_data, ctx, _neural_outputs)
	var fired_rules: Array = eval_result.get("fired", [])
	var human_channels: Array = eval_result.get("human_channels", [])

	# Build final decision from fired rules + neural outputs
	var decision: Dictionary = _synthesize_decision(fired_rules, human_channels, ctx)

	# Record decision
	if decision.get("confidence", 0.0) > 0.3:
		_decisions_made += 1
		decision_made.emit(_pawn_id, decision.get("action", "idle"), decision.get("confidence", 0.0))

	return decision


func _synthesize_decision(fired_rules: Array, human_channels: Array, ctx: Dictionary) -> Dictionary:
	var best_action: String = "idle"
	var best_score: float = 0.0
	var best_confidence: float = 0.0

	# Score each action based on fired rules + neural channels
	var action_scores: Dictionary = {
		"seek_food": 0.0,
		"seek_rest": 0.0,
		"seek_social": 0.0,
		"work_gather": 0.0,
		"work_build": 0.0,
		"work_mine": 0.0,
		"face_threat": 0.0,
		"idle_observe": 0.0,
		"social_bond": 0.0,
		"help_ally": 0.0,
		"withdraw": 0.0,
		"scout_wonder": 0.0,
	}

	# Apply fired rules as score modifiers
	for rule in fired_rules:
		var rule_line: String = rule.get("line", "")
		var weight: float = float(rule.get("w", 0.5))

		if rule_line.find("Seek_Food") >= 0:
			action_scores["seek_food"] += weight
		if rule_line.find("Seek_Rest") >= 0:
			action_scores["seek_rest"] += weight
		if rule_line.find("Seek_Social") >= 0 or rule_line.find("social") >= 0:
			action_scores["seek_social"] += weight
			action_scores["social_bond"] += weight * 0.5
		if rule_line.find("gather") >= 0 or rule_line.find("forage") >= 0:
			action_scores["work_gather"] += weight
		if rule_line.find("build") >= 0:
			action_scores["work_build"] += weight
		if rule_line.find("mine") >= 0:
			action_scores["work_mine"] += weight
		if rule_line.find("threat") >= 0 or rule_line.find("panic") >= 0:
			action_scores["face_threat"] += weight
			action_scores["withdraw"] += weight * 0.3
		if rule_line.find("idle") >= 0 or rule_line.find("observe") >= 0:
			action_scores["idle_observe"] += weight
		if rule_line.find("scout") >= 0 or rule_line.find("wander") >= 0:
			action_scores["scout_wonder"] += weight

	# Neural channel influence (from PawnDecisionRuleMatrix human channels)
	if human_channels.size() >= 12:
		action_scores["seek_food"] += float(human_channels[0]) * 2.0
		action_scores["seek_rest"] += float(human_channels[1]) * 2.0
		action_scores["seek_social"] += float(human_channels[2]) * 2.0
		action_scores["work_gather"] += float(human_channels[3]) * 2.0
		action_scores["work_build"] += float(human_channels[4]) * 2.0
		action_scores["work_mine"] += float(human_channels[5]) * 2.0
		action_scores["face_threat"] += float(human_channels[6]) * 2.0
		action_scores["idle_observe"] += float(human_channels[7]) * 2.0
		action_scores["social_bond"] += float(human_channels[8]) * 1.5
		action_scores["help_ally"] += float(human_channels[9]) * 1.5
		action_scores["withdraw"] += float(human_channels[10]) * 1.5
		action_scores["scout_wonder"] += float(human_channels[11]) * 1.5

	# Pick best action
	for action in action_scores.keys():
		var score: float = action_scores[action]
		# Add small deterministic jitter per pawn to prevent clones
		var jitter: float = WorldRNG.range_for(
			StringName("brain:pick:%d:%s" % [_pawn_id, action]),
			-0.02, 0.02, int(ctx.get("tick", 0))
		)
		score += jitter

		if score > best_score:
			best_score = score
			best_action = action
			best_confidence = clampf(score, 0.0, 1.0)

	return {
		"action": best_action,
		"confidence": best_confidence,
		"scores": action_scores,
		"fired_rules": fired_rules.size(),
		"neural_active": not _neural_outputs.is_empty(),
	}


# === Goals (Crusader Kings-style life goals) ===
func _refresh_goals(_sim_tick: int) -> void:
	if goal_engine == null:
		return

	# Get neural summary for biased goal selection
	var neural_summary: Dictionary = {}
	if _world_ai != null and _world_ai.has_method("get_neural_network_summary"):
		neural_summary = _world_ai.get_neural_network_summary()

	# Pick daily goals (includes survival + lifelong aspirations)
	goal_engine.pick_daily_goals(1.0 if _decision_context.get("hunger", 50.0) < 50.0 else 0.5, neural_summary)

	# If we have an active goal, bias the decision context
	var active_goals: Array = goal_engine.get_active_goals()
	if not active_goals.is_empty():
		var top_goal: Dictionary = active_goals[0]
		_decision_context["active_goal"] = top_goal.key
		_decision_context["goal_scope"] = top_goal.scope
		_decision_context["goal_progress"] = top_goal.progress


# === Combat Awareness (Bannerlord-style) ===
## Uses SpatialGrid for O(n) lookups instead of O(n²) scans
var _spatial_grid: RefCounted = null  # SpatialGrid instance

func _scan_for_combat_threats(pawn: HeelKawnian, _sim_tick: int) -> void:
	if pawn == null or _combat_resolver == null:
		return

	# Check for nearby enemies using spatial grid (O(n) instead of O(n²))
	var nearby_enemies: Array = _find_nearby_enemies(pawn)
	if nearby_enemies.is_empty():
		return

	# We have threats — decide: fight, flee, or call for help
	var combat_affinity: float = _decision_context.get("combat_affinity", 0.5)
	var health_pct: float = _decision_context.get("health", 50.0) / maxf(1.0, _decision_context.get("max_health", 100.0))

	# High combat affinity + good health → engage
	if combat_affinity > 0.6 and health_pct > 0.5:
		for enemy in nearby_enemies:
			combat_engaged.emit(_pawn_id, int(enemy), "melee")
			# Record in memory
			if long_term_memory != null:
				long_term_memory.add_memory(
					LongTermMemory.MemoryType.EVENT,
					"engaged_enemy_%d" % int(enemy),
					"determination",
					0.6,
					_pawn_data.tile_pos,
					[enemy]
				)
	# Low health or low combat affinity → flee
	elif health_pct < 0.3 or combat_affinity < 0.3:
		_decision_context["flee_target"] = true
		# Record in memory as a regret
		if long_term_memory != null:
			long_term_memory.add_memory(
				LongTermMemory.MemoryType.REGRET,
				"fled_from_combat",
				"fear",
				0.4,
				_pawn_data.tile_pos,
				[]
			)

func _find_nearby_enemies(pawn: HeelKawnian) -> Array:
	## Uses SpatialGrid for O(n) lookup
	if _spatial_grid == null:
		_spatial_grid = SpatialGrid.new()
	return []  # Placeholder until CombatResolver provides enemy positions

func _find_nearby_pawns(pawn: HeelKawnian, radius_px: float) -> Array:
	## O(n) lookup via SpatialGrid — replaces O(n²) PawnSpawner scan
	if _spatial_grid == null:
		_spatial_grid = SpatialGrid.new()
	if pawn == null or pawn.data == null:
		return []
	## TODO: When SpatialGrid is populated by PawnSpawner/CombatResolver,
	## uncomment this line:
	# return _spatial_grid.get_nearby_pawns(pawn.position, radius_px)
	return []  # Placeholder until grid is populated


# === Social Scan (Crusader Kings diplomacy) ===
func _scan_for_social_interactions(pawn: HeelKawnian, _sim_tick: int) -> void:
	if pawn == null or gossip == null:
		return

	# Find nearby pawns in social range
	var nearby_pawns: Array = _find_nearby_pawns(pawn, SOCIAL_SCAN_RADIUS_PX)
	for neighbor in nearby_pawns:
		var neighbor_id: int = int(neighbor) if neighbor is int else -1
		if neighbor_id < 0 or neighbor_id == _pawn_id:
			continue

		# Share gossip if we have a relationship
		var relationship: float = _pawn_data.get_social_rapport(neighbor_id)
		if relationship > GossipPropagation.MIN_TRUST_THRESHOLD:
			# Attempt to share gossip
			if gossip.has_method("get_gossip_to_share"):
				# Gossip sharing handled in pawn._share_gossip_with_peer()
				social_interaction.emit(_pawn_id, neighbor_id, "gossip_share")

		# Record social visit in long-term memory
		if long_term_memory != null:
			long_term_memory.add_memory(
				LongTermMemory.MemoryType.SOCIAL,
				"social_visit_with_pawn%d" % neighbor_id,
				"joy" if relationship > 0.5 else "neutral",
				0.3,
				_pawn_data.tile_pos,
				[neighbor_id]
			)



# === Dramatic Events (Narrative Engine) ===
func _check_dramatic_events(_pawn: HeelKawnian, _sim_tick: int) -> void:
	if dramatic_engine == null or _pawn_data == null:
		return

	var beat: Dictionary = dramatic_engine.attempt_story_beat(_pawn_data, _decision_context)
	if not beat.is_empty():
		story_beat_fired.emit(_pawn_id, beat)
		_decisions_made += 1

		# Record in long-term memory
		if long_term_memory != null:
			var importance: float = 0.7 if beat.get("outcome", "") == "triumph" else 0.5
			long_term_memory.add_memory(
				LongTermMemory.MemoryType.EVENT,
				beat.get("summary", "dramatic_event"),
				"dramatic",
				importance,
				_pawn_data.tile_pos,
				[beat.get("pawn_id", -1)]
			)


# === Career Tracking (Bannerlord/Kenshi RPG) ===
func _update_career_tracking(_pawn: HeelKawnian, _sim_tick: int) -> void:
	if career == null:
		return

	# Career XP is granted on job completion (in HeelKawnian.gd)
	# This function updates decision context with career progress
	var career_info: Dictionary = career.get_career_info() if "get_career_info" in career else {}
	_decision_context["career_track"] = career_info.get("track", -1)
	_decision_context["career_level"] = career_info.get("level", 0)
	_decision_context["career_title"] = career_info.get("title", "unemployed")

	# If high-level in a career, bias toward that type of work
	var track: int = int(career_info.get("track", -1))
	if track == CareerXP.CareerTrack.BUILDER:
		_decision_context["work_build"] = 1.0
	elif track == CareerXP.CareerTrack.HUNTER:
		_decision_context["work_gather"] = 1.0


# === Public API for HeelKawnian.gd ===
func get_current_action() -> String:
	return _decision_context.get("active_goal", "idle")


func get_brain_stats() -> Dictionary:
	return {
		"pawn_id": _pawn_id,
		"ticks_processed": _ticks_processed,
		"decisions_made": _decisions_made,
		"neural_outputs_count": _neural_outputs.size(),
		"active_goals": goal_engine.get_active_goals().size() if goal_engine != null else 0,
		"memories_count": long_term_memory._memories.size() if long_term_memory != null else 0,
		"career_level": career._xp_level if career != null else 0,
		"last_decision_tick": _last_decision_tick,
	}


func get_neural_outputs() -> Array:
	return _neural_outputs.duplicate()


func get_decision_context() -> Dictionary:
	return _decision_context.duplicate(true)


# === Cleanup ===
func cleanup() -> void:
	neural_network = null
	decision_matrix = null
	long_term_memory = null
	goal_engine = null
	gossip = null
	career = null
	dramatic_engine = null
	_world_ai = null
	_settlement_ai = null
	_combat_resolver = null
	_decision_context.clear()
	_neural_outputs.clear()
	_current_world_state.clear()


# === WorldBox-Scale: Batch Process Multiple Pawns ===
## Static method to process multiple pawns in one call.
## Used by Main/GameManager for thousands of NPCs at WorldBox scale.
static func batch_tick(pawn_list: Array, sim_tick: int) -> Dictionary:
	var stats: Dictionary = {
		"processed": 0,
		"decisions": 0,
		"stories": 0,
		"combats": 0,
		"errors": 0,
	}
	for entry in pawn_list:
		var pawn: HeelKawnian = entry if entry is HeelKawnian else null
		if pawn == null or not is_instance_valid(pawn):
			stats["errors"] = int(stats.get("errors", 0)) + 1
			continue
		# Get or create brain for this pawn
		var brain: HeelKawnPawnBrain = null
		if "get_brain" in pawn and pawn.get("brain") != null:
			brain = pawn.get("brain")
		elif pawn.has_method("_get_brain"):
			brain = pawn._get_brain()
		if brain == null:
			stats["errors"] = int(stats.get("errors", 0)) + 1
			continue
		var decision: Dictionary = brain.brain_tick(sim_tick, pawn)
		stats["processed"] = int(stats.get("processed", 0)) + 1
		if not decision.is_empty() and decision.get("confidence", 0.0) > 0.3:
			stats["decisions"] = int(stats.get("decisions", 0)) + 1
	return stats


# === WorldBox-Scale: Lightweight Tick (Survival-Only) ===
## Ultra-fast tick for distant/thousands of NPCs — Kenshi survival style.
## Only processes critical survival needs + basic combat awareness.
func lightweight_tick(sim_tick: int, pawn: HeelKawnian) -> Dictionary:
	if _pawn_data == null or pawn == null:
		return {"action": "idle", "confidence": 0.0}
	# Only check critical needs (Kenshi survival)
	var result: Dictionary = {"action": "idle", "confidence": 0.0}
	if _pawn_data.hunger <= 22.0:
		result["action"] = "seek_food"
		result["confidence"] = 0.9
	elif _pawn_data.rest <= 20.0:
		result["action"] = "seek_rest"
		result["confidence"] = 0.85
	elif _pawn_data.health <= 30.0:
		result["action"] = "flee"
		result["confidence"] = 0.8
	# Basic combat scan (Bannerlord-style)
	if _combat_resolver != null and posmod(sim_tick, 16) == 0:
		var nearby: Array = _find_nearby_enemies(pawn)
		if not nearby.is_empty():
			result["action"] = "face_threat"
			result["confidence"] = 0.7
	return result
