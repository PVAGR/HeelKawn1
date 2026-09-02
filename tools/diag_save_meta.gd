extends SceneTree

## Read-only autosave metadata dump. Prims: version, tick, pawn_count, zone
## count, settlement_memory sizing. No world boot, no autoload references.

const SAVE_PATH := "user://heelkawn_colony_autosave.sav"

func _initialize() -> void:
	call_deferred("_go")

func _go() -> void:
	var abs: String = ProjectSettings.globalize_path(SAVE_PATH)
	print("SAVE_META: exists=%s size=%d" % [FileAccess.file_exists(SAVE_PATH), (FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(SAVE_PATH)).size() if FileAccess.file_exists(SAVE_PATH) else -1)])
	var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
	var t0: int = Time.get_ticks_usec()
	var d: Dictionary = gs.call("read_file", SAVE_PATH)
	var t1: int = Time.get_ticks_usec()
	var keys: Array = d.keys()
	keys.sort()
	print("SAVE_META: read_us=%d top_keys=%d" % [(t1 - t0), keys.size()])
	for k in keys:
		var v = d[k]
		var desc: String = str(v)
		if desc.length() > 96:
			desc = desc.substr(0, 96) + "..."
		print("SAVE_META: key=%s type=%s val=%s" % [k, str(typeof(v)), desc])
	var pawns: Array = d.get("pawns", [])
	print("SAVE_META: pawn_count_field=%d pawn_entries=%d" % [int(d.get("pawn_count", -1)), pawns.size()])
	print("SAVE_META: v=%d tick=%d game_speed=%s is_paused=%s" % [
		int(d.get("v", -1)), int(d.get("tick", -1)), str(d.get("game_speed", "?")), str(d.get("is_paused", "?"))])
	if d.has("world") and d["world"] is Dictionary:
		var w: Dictionary = d["world"]
		print("SAVE_META: world keys=%s" % str(w.keys()))
	quit(0)