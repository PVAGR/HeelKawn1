extends RefCounted
class_name ReactiveJobPriority

# Matches the Job.Type enum in scripts/jobs/Job.gd:
const JT_FORAGE := 0
const JT_HUNT   := 4
const JT_CHOP   := 3
const JT_BUILD_BED         := 5
const JT_BUILD_DOOR        := 7
const JT_BUILD_FIRE_PIT    := 15
const JT_BUILD_STORAGE_HUT := 16
const JT_BUILD_WALL        := 6
const JT_TEACHING          := 31

static func bonus_for(job, data, world: Node, colony_services) -> float:
	if job == null or data == null: return 0.0
	var bonus: float = 0.0
	var jtype: int = int(job.type)

	# Crisis amplifier — when colony is in trouble everything gets pushed
	if colony_services != null and colony_services.has_method("is_in_crisis"):
		if colony_services.is_in_crisis(): bonus += 20.0

	# Starving pawn — suppress build jobs
	var hunger: float = float(data.get("hunger", 1.0))
	if hunger < 0.3 and _is_build_job(jtype): bonus -= 15.0

	# Food jobs scale with colony food shortage
	if jtype == JT_FORAGE or jtype == JT_HUNT:
		var food_ratio: float = _food_ratio(colony_services)
		if food_ratio < 0.5: bonus += (1.0 - food_ratio) * 20.0

	# Build jobs scale with what's actually missing
	if _is_build_job(jtype):
		if jtype == JT_BUILD_FIRE_PIT and not _has_fire_pit(colony_services): bonus += 12.0
		if jtype == JT_BUILD_BED: bonus += float(_bed_deficit(colony_services)) * 8.0
		if jtype == JT_BUILD_STORAGE_HUT and _food_ratio(colony_services) > 0.7: bonus += 6.0

	# Teaching — protect rare knowledge
	if jtype == JT_TEACHING:
		if colony_services != null and colony_services.has_method("get_rarest_skill_count"):
			if int(colony_services.get_rarest_skill_count()) <= 1: bonus += 10.0

	# Gather — small floor so pawns are never truly idle
	if jtype == JT_FORAGE or jtype == JT_CHOP: bonus += 2.0

	return bonus

static func _is_build_job(jtype: int) -> bool:
	return jtype >= JT_BUILD_BED and jtype <= JT_BUILD_WALL

static func _food_ratio(cs) -> float:
	if cs != null and cs.has_method("get_food_ratio"): return float(cs.get_food_ratio())
	return 0.5

static func _bed_deficit(cs) -> int:
	if cs != null and cs.has_method("get_bed_deficit"): return int(cs.get_bed_deficit())
	return 0

static func _has_fire_pit(cs) -> bool:
	if cs != null and cs.has_method("has_fire_pit"): return bool(cs.has_fire_pit())
	return true
