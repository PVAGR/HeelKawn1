extends Node

"""
Lightweight autoload to post proto-camp survival orders when no formal
settlements exist. Uses AuthoritySystem to pick a provisional leader and
posts a small set of visible, authority-scoped jobs via JobManager.post_from_dict.

This is intentionally minimal: it does not create formal settlement records
and only posts a few survival orders (fire pit, gather) with issuer metadata
so pawns that follow local authority will see and claim them.
"""

const CHECK_INTERVAL: int = 64

func _ready() -> void:
	set_process(false)
	# DISABLED (P2): Re-enabling _on_game_tick would duplicate Main._seed_bootstrap_jobs /
	# ColonySimServices pressure seeding. Organic path: Main seeder + HeelKawnianManager
	# leader_direct_construction + matrix light/warmth biases. Keep file for issuer dict
	# reference and future authority-scoped orders only.
	# Each pawn follows its own needs (hunger → forage, cold → build hearth, etc.)

## Thin critical proto orders — only when no formal settlements and Main seeder is quiet.
## Call from Main._seed_bootstrap_jobs_near_pawn_cluster when pending survival jobs are absent.
static func post_critical_proto_survival_if_needed(leader_pawn: Node, center_tile: Vector2i) -> int:
	if SettlementMemory != null and SettlementMemory.get_formal_settlement_count() > 0:
		return 0
	if ColonySimServices == null or JobManager == null or leader_pawn == null or not is_instance_valid(leader_pawn):
		return 0
	if leader_pawn.data == null:
		return 0
	var posted: int = 0
	var leader_id: int = int(leader_pawn.data.id)
	var zones: int = StockpileManager.zone_count() if StockpileManager != null else 0
	var stock_food: int = StockpileManager.total_food() if StockpileManager != null else 0
	var food_press: float = ColonySimServices.get_food_pressure()
	var food_critical: bool = food_press > 0.65 or (zones <= 0 and stock_food <= 0)
	if food_critical:
		var food_prio: int = 80 if food_press >= 0.90 or stock_food <= 0 else 70
		if JobManager.count_pending_jobs_near(center_tile, Job.Type.FORAGE, 12) <= 0:
			var fj: Job = JobManager.post_from_dict({
				"type": Job.Type.FORAGE,
				"tile": center_tile + Vector2i(1, 0),
				"priority": food_prio,
				"work_ticks": 8,
				"issuer_pawn_id": leader_id,
				"issuer_role": "leader",
				"authority_scope": "proto_camp",
				"reason": "critical_food",
			})
			if fj != null:
				posted += 1
		if food_press >= 0.85 or stock_food <= 0:
			if JobManager.count_pending_jobs_near(center_tile, Job.Type.HUNT, 12) <= 0:
				var hj: Job = JobManager.post_from_dict({
					"type": Job.Type.HUNT,
					"tile": center_tile + Vector2i(-1, 0),
					"priority": food_prio - 5,
					"work_ticks": 12,
					"issuer_pawn_id": leader_id,
					"issuer_role": "leader",
					"authority_scope": "proto_camp",
					"reason": "critical_food",
				})
				if hj != null:
					posted += 1
			if JobManager.count_pending_jobs_near(center_tile, Job.Type.FISH, 12) <= 0:
				var fishj: Job = JobManager.post_from_dict({
					"type": Job.Type.FISH,
					"tile": center_tile + Vector2i(0, 1),
					"priority": food_prio - 8,
					"work_ticks": 10,
					"issuer_pawn_id": leader_id,
					"issuer_role": "leader",
					"authority_scope": "proto_camp",
					"reason": "critical_food",
				})
				if fishj != null:
					posted += 1
	if ColonySimServices.get_warmth_pressure() > 0.35 \
			and ColonySimServices.can_seed_fire_pit(-1, center_tile, 0, 1):
		if JobManager.count_pending_jobs_near(center_tile, Job.Type.BUILD_FIRE_PIT, 12) <= 0:
			var fire_tile: Vector2i = center_tile
			var main_node: Node = leader_pawn.get_tree().root.get_node_or_null("Main")
			if main_node != null and main_node.has_method("_find_build_tile_near"):
				var found: Variant = main_node.call("_find_build_tile_near", center_tile, 5)
				if found is Vector2i and (found as Vector2i).x >= 0:
					fire_tile = found as Vector2i
			if not JobManager.has_job_at(fire_tile):
				var pj: Job = JobManager.post_from_dict({
					"type": Job.Type.BUILD_FIRE_PIT,
					"tile": fire_tile,
					"priority": 75,
					"work_ticks": 12,
					"issuer_pawn_id": leader_id,
					"issuer_role": "leader",
					"authority_scope": "proto_camp",
					"reason": "critical_warmth",
				})
				if pj != null:
					posted += 1
	return posted


func _on_game_tick(tick: int) -> void:
	return  # Disabled — no authority-issued orders
	# If there are already formal settlements, no proto work needed
	if SettlementMemory != null and SettlementMemory.get_formal_settlement_count() > 0:
		return
	# Find alive pawns and pick a provisional leader via AuthoritySystem or fallback
	var pawns: Array = PawnAccess.find_alive_pawns()
	if pawns.size() == 0:
		return
	var best_pawn: Node = null
	var best_score: float = -1.0
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pid: int = int(p.data.id)
		var civ: float = FactionManager.get_authority_level(pid, FactionManager.AuthorityContext.CIVIL) if FactionManager != null else 0.0
		if civ > best_score:
			best_score = civ
			best_pawn = p
	# Fallback to first pawn
	if best_pawn == null:
		best_pawn = pawns[0]
	# Post minimal proto-camp survival orders near the leader
	if best_pawn != null and is_instance_valid(best_pawn) and best_pawn.data != null:
		var leader_id: int = int(best_pawn.data.id)
		var center_tile = best_pawn.data.tile_pos
		# Build a small list of starter jobs: Build fire pit, gather sticks, forage
		var jobs_to_post: Array = []
		jobs_to_post.append({
			"type": Job.Type.BUILD_FIRE_PIT,
			"tile": Vector2i(int(center_tile.x), int(center_tile.y)),
			"priority": 80,
			"work_ticks": 40,
			"issuer_pawn_id": leader_id,
			"issuer_role": "leader",
			"authority_scope": "proto_camp",
			"visible_to": "nearby",
			"reason": "survival",
			"social_weight": 1.0,
		})
		jobs_to_post.append({
			"type": Job.Type.GATHER_STICK,
			"tile": Vector2i(int(center_tile.x), int(center_tile.y)),
			"priority": 40,
			"work_ticks": 10,
			"issuer_pawn_id": leader_id,
			"issuer_role": "leader",
			"authority_scope": "proto_camp",
			"visible_to": "nearby",
			"reason": "fire_prep",
			"social_weight": 0.6,
		})
		jobs_to_post.append({
			"type": Job.Type.FORAGE,
			"tile": Vector2i(int(center_tile.x + 2), int(center_tile.y)),
			"priority": 60,
			"work_ticks": 8,
			"issuer_pawn_id": leader_id,
			"issuer_role": "leader",
			"authority_scope": "proto_camp",
			"visible_to": "nearby",
			"reason": "food",
			"social_weight": 1.0,
		})
		for jd in jobs_to_post:
			JobManager.post_from_dict(jd)
