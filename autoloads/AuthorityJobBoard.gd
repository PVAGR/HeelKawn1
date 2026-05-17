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
	if ColonySimServices.get_food_pressure() > 0.65:
		if JobManager.count_pending_jobs_near(center_tile, Job.Type.FORAGE, 12) <= 0:
			var fj: Job = JobManager.post_from_dict({
				"type": Job.Type.FORAGE,
				"tile": center_tile + Vector2i(1, 0),
				"priority": 70,
				"work_ticks": 8,
				"issuer_pawn_id": leader_id,
				"issuer_role": "leader",
				"authority_scope": "proto_camp",
				"reason": "critical_food",
			})
			if fj != null:
				posted += 1
	if ColonySimServices.get_warmth_pressure() > 0.35 \
			and ColonySimServices.can_seed_fire_pit(-1, center_tile, 0, 1):
		if JobManager.count_pending_jobs_near(center_tile, Job.Type.BUILD_FIRE_PIT, 12) <= 0:
			var pj: Job = JobManager.post_from_dict({
				"type": Job.Type.BUILD_FIRE_PIT,
				"tile": center_tile,
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
