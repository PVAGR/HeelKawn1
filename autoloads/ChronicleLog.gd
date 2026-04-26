extends Node

signal entry_added(entry: Dictionary)
## Fired after [method from_save_dict] or [method clear] so UI can fully refresh.
signal entries_reloaded()

const MAX_ENTRIES: int = 200
var entries: Array[Dictionary] = []


func append_entry(
		tick: int, zone_id: String, message: String, tags: PackedStringArray = PackedStringArray()
) -> void:
	var entry: Dictionary = {
		"tick": tick,
		"zone_id": zone_id,
		"message": message,
		"tags": tags,
	}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.remove_at(0)
	entry_added.emit(entry)


func clear() -> void:
	entries.clear()
	entries_reloaded.emit()


func to_save_dict() -> Dictionary:
	var arr: Array = []
	for e in entries:
		arr.append((e as Dictionary).duplicate(true))
	return {"entries": arr}


func from_save_dict(data: Variant) -> void:
	entries.clear()
	if data == null or not (data is Dictionary):
		return
	var raw: Variant = (data as Dictionary).get("entries", [])
	if not (raw is Array):
		return
	for item in raw as Array:
		if item is Dictionary:
			var d: Dictionary = (item as Dictionary).duplicate(true)
			# Normalize tags after store_var round-trip
			var tv: Variant = d.get("tags", PackedStringArray())
			if tv is Array:
				var ps: PackedStringArray = PackedStringArray()
				for t in tv as Array:
					ps.append(str(t))
				d["tags"] = ps
			entries.append(d)
	entries_reloaded.emit()


## Drop entries whose tick is older than [param age_threshold] (vs current sim tick).
func compress_older_than(age_threshold: int) -> void:
	var cutoff: int = GameManager.tick_count - age_threshold
	var before: int = entries.size()
	var kept: Array[Dictionary] = []
	for e in entries:
		if int(e.get("tick", 0)) >= cutoff:
			kept.append(e)
	entries.clear()
	for e in kept:
		entries.append(e)
	if entries.size() < before:
		entries_reloaded.emit()
