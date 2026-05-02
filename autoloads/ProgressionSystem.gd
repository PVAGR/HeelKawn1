extends Node

## Cumulative impact from completed jobs (deterministic). Used for reputation / tier labels.

var impact_by_pawn: Dictionary = {}


func record_impact(pawn_id: int, amount: int, job_type_name: String) -> void:
	if pawn_id <= 0 or amount <= 0:
		return
	var cur: int = int(impact_by_pawn.get(pawn_id, 0))
	impact_by_pawn[pawn_id] = cur + amount
	if OS.is_debug_build():
		print(
				"[Progression] pawn=%d +%d (%s) total=%d"
				% [pawn_id, amount, job_type_name, cur + amount]
		)


func get_impact(pawn_id: int) -> int:
	if pawn_id <= 0:
		return 0
	return int(impact_by_pawn.get(pawn_id, 0))


func get_impact_tier_label(pawn_id: int) -> String:
	var t: int = get_impact(pawn_id)
	if t >= 5000:
		return "Enduring"
	if t >= 1000:
		return "Mythic"
	if t >= 200:
		return "Noticed"
	if t >= 50:
		return "Remembered"
	if t >= 10:
		return "Known"
	return "Obscure"
