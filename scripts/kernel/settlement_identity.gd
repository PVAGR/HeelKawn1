extends Node
## Autoload singleton (must not use [class_name] — same symbol as node name hides the autoload).

## Fired when an abandoned settlement reoccupies and receives a full identity.
signal identity_resolved(resolved_id: String, name: String, traits: PackedStringArray, lineage_parent: String)

const TRAIT_TAGS: Dictionary = {
	"ruin": "Scarred",
	"stabilizing_biome": "Regrowth",
	"death_cluster": "Mourning",
	"trade_routes": "Crossroads",
}


## Deterministic name + tags from [param settlement] and [WorldMeaning] / [WorldMemory] (no RNG).
func resolve_for(settlement: Dictionary) -> Dictionary:
	var ckr: int = int(settlement.get("center_region", -1))
	var zone_id: String = str(settlement.get("zone_id", ""))
	if zone_id.is_empty():
		zone_id = str(ckr) if ckr >= 0 else str(settlement.get("id", ""))
	var lineage_parent: String = str(settlement.get("id", zone_id))
	var reocc_tick: int = int(settlement.get("reoccupied_tick", 0))
	var stats: Dictionary = WorldMemory.get_zone_aggregate(zone_id)

	var traits: PackedStringArray = PackedStringArray()
	for tag in WorldMeaning.get_zone_tags(zone_id):
		if tag in TRAIT_TAGS and not _traits_has_label(traits, str(TRAIT_TAGS[tag])):
			traits.append(str(TRAIT_TAGS[tag]))
	# From persist flags
	var pflags: Variant = settlement.get("persist_flags", [])
	if pflags is Array and "ruin" in (pflags as Array) and not _traits_has_label(traits, "Scarred"):
		traits.append(str(TRAIT_TAGS.get("ruin", "Scarred")))
	# From aggregate (fact-based, same display names)
	if int(stats.get("death_clusters", 0)) > 0 and not _traits_has_label(traits, "Mourning"):
		traits.append(str(TRAIT_TAGS.get("death_cluster", "Mourning")))
	if int(stats.get("trade_routes", 0)) > 0 and not _traits_has_label(traits, "Crossroads"):
		traits.append(str(TRAIT_TAGS.get("trade_routes", "Crossroads")))

	var new_name: String = _derive_name(zone_id, reocc_tick, traits.size())
	var new_id: String = "set_%s_%d" % [zone_id, reocc_tick]

	identity_resolved.emit(new_id, new_name, traits, lineage_parent)
	return {
		"id": new_id,
		"name": new_name,
		"traits": traits,
		"lineage_parent": lineage_parent,
		"state": "active",
	}


func _derive_name(zone_id: String, era: int, trait_count: int) -> String:
	var seed: int = 0
	for i in range(zone_id.length()):
		seed = (seed * 31 + zone_id.unicode_at(i)) & 0x7FFFFFFF
	seed = (seed ^ era ^ (trait_count * 37)) & 0x7FFFFFFF
	var prefixes: Array[String] = [
		"Ash", "Stone", "Root", "Iron", "Salt", "Wind", "Marrow", "Ember"
	]
	var suffixes: Array[String] = [
		"hold", "weald", "crest", "ford", "vale", "reach", "peak", "fen"
	]
	return "%s%s" % [prefixes[(seed >> 8) % 8], suffixes[(seed >> 4) % 8]]


static func _traits_has_label(traits: PackedStringArray, label: String) -> bool:
	for i in range(traits.size()):
		if str(traits[i]) == label:
			return true
	return false
