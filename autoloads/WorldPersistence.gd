extends Node
## Phase 2.3: deterministic consequences from WorldMeaning only.
## Does not write to WorldMemory or WorldMeaning. No RNG, no UI.

## Quiet period (ticks) with no new deaths in region before one step of *visual* recovery.
const RECOVERY_TICKS: int = 20000

## region_key (int) -> persistence record
var persistent_regions: Dictionary = {}


func clear() -> void:
	persistent_regions.clear()


func to_save_dict() -> Dictionary:
	return {"persistent_regions": persistent_regions.duplicate(true)}


func from_save_dict(d: Dictionary) -> void:
	persistent_regions.clear()
	if d.is_empty():
		return
	var raw: Variant = d.get("persistent_regions", {})
	if not raw is Dictionary:
		return
	for k in (raw as Dictionary).keys():
		var region_key: int
		if typeof(k) == TYPE_INT:
			region_key = k as int
		else:
			region_key = int(str(k))
		var rec: Variant = (raw as Dictionary)[k]
		if not rec is Dictionary:
			continue
		persistent_regions[region_key] = (rec as Dictionary).duplicate(true)


func _default_entry() -> Dictionary:
	return {
		"scarred": false,
		"scar_level": 0,
		"last_applied_tick": -1,
		"last_death_tick": -1,
		"recovery_stage": 0,
		"next_recovery_at_tick": 0,
	}


func get_region_persistence(region_key: int) -> Dictionary:
	if persistent_regions.has(region_key):
		return (persistent_regions[region_key] as Dictionary).duplicate(true)
	return _default_entry()


func recompute() -> void:
	var old: Dictionary = persistent_regions.duplicate(true)
	persistent_regions.clear()
	# -- Phase 1: scar_level / meaning merge + recovery state (scar_level never decreases)
	for rk in WorldMeaning.meaning_by_region.keys():
		var region_key: int = int(rk)
		var m: Dictionary = WorldMeaning.get_region_meaning(region_key)
		var density: String = str(m.get("death_density", "none"))
		var target: int = _scar_level_from_density(density)
		var prev_level: int = 0
		if old.has(region_key):
			prev_level = int((old[region_key] as Dictionary).get("scar_level", 0))
		var final_level: int = maxi(target, prev_level)
		var last_d: int = int(m.get("last_death_tick", -1))
		var old_p: Dictionary = (old[region_key] as Dictionary) if old.has(region_key) else {}
		var old_last_d: int = int(old_p.get("last_death_tick", -999999))
		var rs: int
		var nxt: int
		if not old.has(region_key):
			rs = final_level
			nxt = _initial_next_recovery_at(last_d)
		else:
			if last_d > old_last_d:
				rs = final_level
				nxt = _initial_next_recovery_at(last_d)
			else:
				rs = int(old_p.get("recovery_stage", final_level))
				rs = mini(rs, final_level)
				nxt = int(old_p.get("next_recovery_at_tick", _initial_next_recovery_at(last_d)))
		persistent_regions[region_key] = {
			"scarred": final_level >= 3,
			"scar_level": final_level,
			"last_applied_tick": last_d,
			"last_death_tick": last_d,
			"recovery_stage": rs,
			"next_recovery_at_tick": nxt,
		}
	# Orphans: fall out of WorldMeaning; keep full prior record; merge in missing keys
	for rk in old.keys():
		if not persistent_regions.has(rk):
			var o: Dictionary = (old[rk] as Dictionary).duplicate(true)
			if not o.has("last_death_tick"):
				o["last_death_tick"] = int(o.get("last_applied_tick", -1))
			if not o.has("recovery_stage"):
				o["recovery_stage"] = int(o.get("scar_level", 0))
			if not o.has("next_recovery_at_tick"):
				o["next_recovery_at_tick"] = _initial_next_recovery_at(int(o.get("last_death_tick", -1)))
			persistent_regions[rk] = o
	# -- Phase 2: one step of visual recovery (recovery_stage only; never scar_level; ticks only)
	var now: int = GameManager.tick_count
	for rk2 in persistent_regions.keys():
		var pr: Dictionary = persistent_regions[rk2]
		var slev: int = int(pr.get("scar_level", 0))
		if slev < 1:
			continue
		var rstage: int = int(pr.get("recovery_stage", 0))
		if rstage <= 0:
			continue
		var nxt2: int = int(pr.get("next_recovery_at_tick", 0))
		var ldeath: int = int(pr.get("last_death_tick", -1))
		if nxt2 <= 0 and ldeath >= 0:
			nxt2 = ldeath + RECOVERY_TICKS
			pr["next_recovery_at_tick"] = nxt2
		elif nxt2 <= 0 and ldeath < 0:
			# Inconsistent (scar with no last_death); do not free-run recoveries.
			pr["next_recovery_at_tick"] = now + RECOVERY_TICKS
			continue
		if now < nxt2:
			continue
		pr["recovery_stage"] = maxi(0, rstage - 1)
		pr["next_recovery_at_tick"] = now + RECOVERY_TICKS


func _initial_next_recovery_at(last_death: int) -> int:
	if last_death < 0:
		return 0
	return last_death + RECOVERY_TICKS


func _scar_level_from_density(density: String) -> int:
	match density:
		"none":
			return 0
		"low":
			return 1
		"medium":
			return 2
		"high":
			return 3
	return 0
