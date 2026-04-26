extends Node

## Read-only narrative queries. Never mutates simulation state.


func get_zone_narrative(zone_id: String) -> String:
	var tags: PackedStringArray = WorldMeaning.get_zone_tags(zone_id)
	if _pack_has(tags, "ancient_ruin"):
		return "Ancient Ruin"
	if _pack_has(tags, "myth_origin"):
		return "Myth of Origin"
	if _pack_has(tags, "echo_falls"):
		return "Scarred Ground"
	if _pack_has(tags, "stabilizing_biome"):
		return "Regrowth"
	return "Unmarked"


func get_chronicler_focus() -> Array[Dictionary]:
	var focus: Array[Dictionary] = []
	for zone_id in SettlementRegistry.get_abandoned_zone_ids():
		var tags: PackedStringArray = WorldMeaning.get_zone_tags(zone_id)
		if _pack_has(tags, "ancient_ruin") or _pack_has(tags, "echo_falls"):
			focus.append({"zone": zone_id, "narrative": get_zone_narrative(zone_id)})
	return focus


static func _pack_has(p: PackedStringArray, tag: String) -> bool:
	for i in range(p.size()):
		if str(p[i]) == tag:
			return true
	return false
