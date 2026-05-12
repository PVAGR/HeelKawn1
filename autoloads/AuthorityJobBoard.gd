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
	# Listen to global game tick for periodic checks
	if GameManager != null and GameManager.has_signal("game_tick"):
		GameManager.connect("game_tick", Callable(self, "_on_game_tick"))

func _on_game_tick(tick: int) -> void:
	if tick % CHECK_INTERVAL != 0:
		return
	# If there are already formal settlements, no proto work needed
	if SettlementMemory != null and SettlementMemory.get_formal_settlement_count() > 0:
		return
	# Find alive pawns and pick a provisional leader via AuthoritySystem or fallback
	var pawns: Array = PawnSpawner.find_alive_pawns()
	if pawns.size() == 0:
		return
	var best_pawn: Node = null
	var best_score: float = -1.0
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pid: int = int(p.data.id)
		var civ: float = AuthoritySystem.get_authority_level(pid, AuthoritySystem.AuthorityContext.CIVIL) if AuthoritySystem != null else 0.0
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
