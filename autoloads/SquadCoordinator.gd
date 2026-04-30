extends Node

## Soul & Society: idle pawns with strong mutual rapport form squads (shared anchor for movement).

const MIN_SQUAD_SIZE: int = 5
const RAPPORT_THRESHOLD: int = 1200

var active_squad_count: int = 0


func recompute(spawner: PawnSpawner) -> void:
	active_squad_count = 0
	if spawner == null:
		return
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			p.data.social_squad_anchor_id = -1
	var pl: Array[Pawn] = []
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			pl.append(p)
	if pl.size() < MIN_SQUAD_SIZE:
		return
	pl.sort_custom(func(a: Pawn, b: Pawn) -> bool: return a.data.id < b.data.id)
	var claimed: Dictionary = {}
	for seed_p in pl:
		var sid: int = int(seed_p.data.id)
		if claimed.has(sid):
			continue
		if not seed_p.is_eligible_for_social_squad():
			continue
		var clique: Array[Pawn] = _greedy_clique_from_seed_pawn(seed_p, pl, claimed)
		if clique.size() < MIN_SQUAD_SIZE:
			continue
		var all_idle: bool = true
		for m in clique:
			if not m.is_eligible_for_social_squad():
				all_idle = false
				break
		if not all_idle:
			continue
		var leader_id: int = _leader_id(clique)
		for m in clique:
			m.data.social_squad_anchor_id = leader_id
			claimed[int(m.data.id)] = true
		active_squad_count += 1


func _rapport_mutual(a: PawnData, b: PawnData) -> int:
	var av: int = int(a.social_rapport.get(str(b.id), 0))
	var bv: int = int(b.social_rapport.get(str(a.id), 0))
	return mini(av, bv)


func _greedy_clique_from_seed_pawn(clique_seed_pawn: Pawn, pl: Array[Pawn], claimed: Dictionary) -> Array[Pawn]:
	var out: Array[Pawn] = [clique_seed_pawn]
	for p in pl:
		if p == clique_seed_pawn:
			continue
		var pid: int = int(p.data.id)
		if claimed.has(pid):
			continue
		var ok: bool = true
		for c in out:
			if _rapport_mutual(p.data, c.data) < RAPPORT_THRESHOLD:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func _leader_id(members: Array[Pawn]) -> int:
	var best: int = 1_000_000_000
	for m in members:
		best = mini(best, int(m.data.id))
	return best
