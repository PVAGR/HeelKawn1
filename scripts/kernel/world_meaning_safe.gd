extends RefCounted
## Safe wrapper: older project copies may lack [method WorldMeaning.get_zone_tags].
## Always returns a [PackedStringArray] (empty if autoload is stale).


static func zone_tags(zone_id: String) -> PackedStringArray:
	if WorldMeaning.has_method("get_zone_tags"):
		var v: Variant = WorldMeaning.call("get_zone_tags", zone_id)
		if v is PackedStringArray:
			return v as PackedStringArray
	push_warning(
			"HeelKawn: WorldMeaning.get_zone_tags missing — replace autoloads/WorldMeaning.gd with the repo version."
	)
	return PackedStringArray()
