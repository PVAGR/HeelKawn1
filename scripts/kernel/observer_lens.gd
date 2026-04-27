extends Node

## Read-only narrative queries. Never mutates simulation state.


func _abandoned_zone_ids_for_chronicler() -> PackedStringArray:
	# Resolve via scene tree so this file parses even if the GDScript language
	# server does not register autoload singleton names (same runtime behavior).
	var root: Window = Engine.get_main_loop().root as Window
	if root != null:
		var sr: Node = root.get_node_or_null("/root/SettlementRegistry")
		if sr != null and sr.has_method("get_abandoned_zone_ids"):
			return sr.call("get_abandoned_zone_ids") as PackedStringArray
	var out: PackedStringArray = PackedStringArray()
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s as Dictionary
		if str(d.get("state", "")) != "abandoned":
			continue
		var zid: String = str(int(d.get("center_region", -1)))
		if zid.is_empty() or zid == "-1":
			continue
		out.append(zid)
	return out


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
	for zone_id in _abandoned_zone_ids_for_chronicler():
		var tags: PackedStringArray = WorldMeaning.get_zone_tags(zone_id)
		if _pack_has(tags, "ancient_ruin") or _pack_has(tags, "echo_falls"):
			focus.append({"zone": zone_id, "narrative": get_zone_narrative(zone_id)})
	return focus


static func _pack_has(p: PackedStringArray, tag: String) -> bool:
	for i in range(p.size()):
		if str(p[i]) == tag:
			return true
	return false
