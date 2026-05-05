class_name GameSave
extends Object

## Multi-slot `store_var` save. Version key lives in the snapshot dict ("v").
## Slots: 1-3. Slot 0 is the legacy single-file path.
const SAVE_VERSION: int = 4
const DEFAULT_PATH: String = "user://heelkawn_colony.sav"
const SLOT_COUNT: int = 3


static func get_save_path(slot: int = 0) -> String:
	if slot <= 0:
		return DEFAULT_PATH
	return "user://heelkawn_slot_%d.sav" % clampi(slot, 1, SLOT_COUNT)


static func write_file(path: String, snapshot: Dictionary) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(snapshot, true)
	f.close()
	return OK


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(true)
	f.close()
	if v is Dictionary:
		return v
	return {}


## Check if a save file exists at the given slot.
static func slot_exists(slot: int = 0) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


## Read metadata from a save slot without loading the full snapshot.
## Returns {tick, settlement_name, pawn_count, timestamp, empty} or empty dict.
static func get_slot_metadata(slot: int = 0) -> Dictionary:
	var d: Dictionary = read_file(get_save_path(slot))
	if d.is_empty():
		return {"empty": true}
	return {
		"empty": false,
		"tick": int(d.get("tick", 0)),
		"settlement_name": str(d.get("settlement_name", "Unknown")),
		"pawn_count": int(d.get("pawn_count", 0)),
		"timestamp": str(d.get("timestamp", "")),
	}


## List all non-empty slot metadata.
static func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in range(SLOT_COUNT):
		result.append(get_slot_metadata(s + 1))
	return result
