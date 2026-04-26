extends Node

## Sparse tick: compress old chronicle lines into [WorldMeaning] persistent zone tags.
const COMPRESS_EVERY_TICKS := 1200
const ENTRY_AGE_THRESHOLD := 1800

var _tick_counter: int = 0


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_tick_counter += 1
	if _tick_counter >= COMPRESS_EVERY_TICKS:
		_tick_counter = 0
		_compress_ancient_history()


func _compress_ancient_history() -> void:
	var current_tick: int = GameManager.tick_count
	var zone_impact: Dictionary = {}

	for entry in ChronicleLog.entries:
		if current_tick - int(entry.get("tick", 0)) <= ENTRY_AGE_THRESHOLD:
			continue
		var zid: String = str(entry.get("zone_id", ""))
		if zid.is_empty():
			continue
		if not zone_impact.has(zid):
			zone_impact[zid] = {"found": 0, "fall": 0, "ruin": 0}

		var msg: String = str(entry.get("message", ""))
		if "Founded" in msg:
			zone_impact[zid]["found"] = int(zone_impact[zid]["found"]) + 1
		elif "State transition" in msg and "ruin" in msg:
			zone_impact[zid]["ruin"] = int(zone_impact[zid]["ruin"]) + 1
		elif "State transition" in msg:
			zone_impact[zid]["fall"] = int(zone_impact[zid]["fall"]) + 1

	for zone_id in zone_impact.keys():
		var counts: Dictionary = zone_impact[zone_id]
		var n_found: int = int(counts.get("found", 0))
		var n_fall: int = int(counts.get("fall", 0))
		var n_ruin: int = int(counts.get("ruin", 0))
		var persistent: PackedStringArray = PackedStringArray()
		if n_ruin > 0:
			persistent.append("ancient_ruin")
		elif n_found > 0 and n_ruin == 0:
			persistent.append("myth_origin")
		if n_fall >= 2:
			persistent.append("echo_falls")
		if not persistent.is_empty():
			WorldMeaning.append_persistent_tag(zone_id, persistent)

	ChronicleLog.compress_older_than(ENTRY_AGE_THRESHOLD)
