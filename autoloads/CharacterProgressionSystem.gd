extends Node
## CharacterProgressionSystem — Vintage Story-style deep character progression.
##
## Features:
## - Skill trees with branching paths
## - Time-intensive mastery (hours of real work)
## - Tool quality affects progression speed
## - Specialization vs generalization tradeoffs
## - Knowledge transfer through teaching
## - Physical/mental trait development
## - Reputation and fame from achievements
##
## Design principles:
## - Mastery takes real time investment
## - No instant leveling — skill comes from repetition
## - Tool quality matters (better tools = faster learning)
## - Specialization has opportunity costs
## - Skills can atrophy without use
## - Teaching accelerates others' learning

# ============================================================
# CONSTANTS
# ============================================================

## Skill categories
enum SkillCategory {
	SURVIVAL,    # Foraging, hunting, fire-making
	CRAFTING,    # Tool making, building, pottery
	COMBAT,      # Melee, ranged, tactics
	SOCIAL,      # Leadership, teaching, diplomacy
	KNOWLEDGE,   # Research, reading, astronomy
	AGRICULTURE, # Farming, animal husbandry
}

const SKILL_CATEGORY_NAMES: PackedStringArray = [
	"Survival", "Crafting", "Combat", "Social", "Knowledge", "Agriculture",
]

## Skill levels (Vintage Story-style)
enum SkillLevel {
	NOVICE,       # 0-100
	APPRENTICE,   # 100-500
	JOURNEYMAN,   # 500-1500
	EXPERT,       # 1500-4000
	MASTER,       # 4000-10000
	GRANDMASTER,  # 10000+
}

const SKILL_LEVEL_NAMES: PackedStringArray = [
	"Novice", "Apprentice", "Journeyman", "Expert", "Master", "Grandmaster",
]

const SKILL_LEVEL_THRESHOLDS: PackedInt32Array = [
	0, 100, 500, 1500, 4000, 10000,
]

## XP rewards per action
const XP_REWARDS: Dictionary = {
	"chop_wood": 2,
	"mine_stone": 3,
	"forage": 1,
	"hunt": 5,
	"fish": 2,
	"build": 3,
	"craft_tool": 5,
	"craft_weapon": 4,
	"craft_armor": 6,
	"cook": 2,
	"farm_plant": 2,
	"farm_harvest": 3,
	"teach": 8,
	"learn": 4,
	"trade": 2,
	"lead": 5,
	"fight": 6,
	"heal": 4,
	"research": 5,
}

## Tool quality multipliers for XP gain
const TOOL_QUALITY_XP_MULT: Dictionary = {
	"none": 0.5,
	"crude": 0.7,
	"basic": 1.0,
	"good": 1.3,
	"excellent": 1.6,
	"masterwork": 2.0,
}

## Skill atrophy rate (per 10000 ticks without use)
const SKILL_ATROPHY_RATE: float = 0.02

## Teaching efficiency (how much XP the student gets)
const TEACHING_EFFICIENCY: float = 0.6

## How often to check skill atrophy (ticks)
const ATROPHY_CHECK_INTERVAL: int = 10000

# ============================================================
# SKILL DATA
# ============================================================

## Specific skills within categories
const SKILLS: Dictionary = {
	SkillCategory.SURVIVAL: ["foraging", "hunting", "fire_making", "tracking", "shelter_building"],
	SkillCategory.CRAFTING: ["woodworking", "stoneworking", "pottery", "tool_making", "weaving"],
	SkillCategory.COMBAT: ["melee", "ranged", "tactics", "armor_use", "shield_use"],
	SkillCategory.SOCIAL: ["leadership", "teaching", "diplomacy", "persuasion", "empathy"],
	SkillCategory.KNOWLEDGE: ["research", "reading", "astronomy", "medicine", "engineering"],
	SkillCategory.AGRICULTURE: ["farming", "animal_husbandry", "irrigation", "seed_selection", "preservation"],
}

## pawn_id -> skill data
## {
##   "pawn_id": int,
##   "skills": Dictionary,  # skill_name -> {"xp": int, "level": int, "last_used": int}
##   "category_levels": Dictionary,  # category -> average level
##   "specialization": String,  # focused skill category
##   "tool_quality": Dictionary,  # skill_name -> tool_quality_string
##   "achievements": Array[String],
##   "reputation": float,
##   "fame": float,
## }
var character_data: Dictionary = {}

## Skill achievements
const ACHIEVEMENTS: Dictionary = {
	"first_blood": {"name": "First Blood", "desc": "First kill in combat", "condition": "kills >= 1"},
	"woodcutter": {"name": "Woodcutter", "desc": "Chop 100 wood", "condition": "chop_wood >= 100"},
	"master_builder": {"name": "Master Builder", "desc": "Build 50 structures", "condition": "build >= 50"},
	"veteran": {"name": "Veteran", "desc": "Fight in 10 battles", "condition": "battles >= 10"},
	"teacher": {"name": "Teacher", "desc": "Teach 5 students", "condition": "teach >= 5"},
	"farmer": {"name": "Farmer", "desc": "Harvest 100 crops", "condition": "farm_harvest >= 100"},
	"explorer": {"name": "Explorer", "desc": "Discover 50 unique tiles", "condition": "explored >= 50"},
	"leader": {"name": "Leader", "desc": "Command an army of 20+", "condition": "commanded >= 20"},
}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Check skill atrophy
	if tick % ATROPHY_CHECK_INTERVAL == 0:
		_check_skill_atrophy(tick)
	# Check achievements
	_check_achievements(tick)


# ============================================================
# SKILL PROGRESSION
# ============================================================

func record_action(pawn_id: int, action: String, tick: int) -> void:
	"""Record a skill-building action for a pawn."""
	_ensure_character_record(pawn_id)
	var data: Dictionary = character_data.get(pawn_id, {})
	if data.is_empty():
		return
	# Find which skill this action belongs to
	var skill_name: String = _action_to_skill(action)
	if skill_name == "":
		return
	# Initialize skill if needed
	if not data["skills"].has(skill_name):
		data["skills"][skill_name] = {"xp": 0, "level": 0, "last_used": tick, "actions": 0}
	var skill: Dictionary = data["skills"][skill_name]
	# Calculate XP gain
	var base_xp: int = XP_REWARDS.get(action, 1)
	var tool_mult: float = _get_tool_quality_multiplier(data, skill_name)
	var teacher_bonus: float = _get_teacher_bonus(pawn_id, skill_name)
	var xp_gain: float = float(base_xp) * tool_mult * teacher_bonus
	skill["xp"] += int(xp_gain)
	skill["level"] = _xp_to_level(skill["xp"])
	skill["last_used"] = tick
	skill["actions"] = int(skill.get("actions", 0)) + 1
	# Update category levels
	_update_category_levels(data)
	# Update reputation/fame for significant milestones
	var new_level: int = skill["level"]
	if new_level >= SkillLevel.EXPERT:
		data["reputation"] = minf(100.0, float(data.get("reputation", 0.0)) + 5.0)
	if new_level >= SkillLevel.MASTER:
		data["fame"] = minf(100.0, float(data.get("fame", 0.0)) + 10.0)
		_add_achievement_if_missing(data, "master_%s" % skill_name)


func _action_to_skill(action: String) -> String:
	"""Map an action to its corresponding skill."""
	var mapping: Dictionary = {
		"chop_wood": "woodworking",
		"mine_stone": "stoneworking",
		"forage": "foraging",
		"hunt": "hunting",
		"fish": "hunting",
		"build": "shelter_building",
		"craft_tool": "tool_making",
		"craft_weapon": "tool_making",
		"craft_armor": "tool_making",
		"cook": "fire_making",
		"farm_plant": "farming",
		"farm_harvest": "farming",
		"teach": "teaching",
		"learn": "research",
		"trade": "diplomacy",
		"lead": "leadership",
		"fight": "melee",
		"heal": "medicine",
		"research": "research",
	}
	return mapping.get(action, "")


func _get_tool_quality_multiplier(data: Dictionary, skill_name: String) -> float:
	"""Get XP multiplier based on tool quality."""
	var tool_quality: String = str(data.get("tool_quality", {}).get(skill_name, "basic"))
	return float(TOOL_QUALITY_XP_MULT.get(tool_quality, 1.0))


func _get_teacher_bonus(pawn_id: int, skill_name: String) -> float:
	"""Get XP bonus from being taught."""
	# Check if pawn is currently being taught this skill
	# In full implementation, this would check active teaching relationships
	return 1.0


func _xp_to_level(xp: int) -> int:
	"""Convert XP to skill level."""
	for i in range(SKILL_LEVEL_THRESHOLDS.size() - 1, -1, -1):
		if xp >= SKILL_LEVEL_THRESHOLDS[i]:
			return i
	return 0


func _update_category_levels(data: Dictionary) -> void:
	"""Update average skill levels per category."""
	data["category_levels"] = {}
	for category in range(SKILL_CATEGORY_NAMES.size()):
		var skills: Array = SKILLS[category]
		var total_level: int = 0
		var count: int = 0
		for skill_name in skills:
			if data["skills"].has(skill_name):
				total_level += int(data["skills"][skill_name].get("level", 0))
				count += 1
		if count > 0:
			data["category_levels"][category] = float(total_level) / float(count)
		else:
			data["category_levels"][category] = 0.0
	# Determine specialization
	var best_category: int = 0
	var best_level: float = 0.0
	for cat in data["category_levels"].keys():
		if float(data["category_levels"][cat]) > best_level:
			best_level = float(data["category_levels"][cat])
			best_category = int(cat)
	data["specialization"] = SKILL_CATEGORY_NAMES[best_category]


# ============================================================
# SKILL ATROPHY
# ============================================================

func _check_skill_atrophy(tick: int) -> void:
	"""Decay skills that haven't been used recently."""
	for pawn_id in character_data.keys():
		var data: Dictionary = character_data[pawn_id]
		for skill_name in data["skills"].keys():
			var skill: Dictionary = data["skills"][skill_name]
			var last_used: int = int(skill.get("last_used", 0))
			if last_used > 0:
				var ticks_since_use: int = tick - last_used
				if ticks_since_use > ATROPHY_CHECK_INTERVAL:
					var current_xp: int = int(skill.get("xp", 0))
					var atrophy_amount: float = float(current_xp) * SKILL_ATROPHY_RATE
					skill["xp"] = maxi(0, current_xp - int(atrophy_amount))
					skill["level"] = _xp_to_level(skill["xp"])


# ============================================================
# TEACHING SYSTEM
# ============================================================

func record_teaching(teacher_id: int, student_id: int, skill_name: String, tick: int) -> void:
	"""Record a teaching session."""
	_ensure_character_record(teacher_id)
	_ensure_character_record(student_id)
	var teacher_data: Dictionary = character_data.get(teacher_id, {})
	var student_data: Dictionary = character_data.get(student_id, {})
	if teacher_data.is_empty() or student_data.is_empty():
		return
	# Teacher gains XP for teaching
	record_action(teacher_id, "teach", tick)
	# Student gains XP based on teacher's skill level
	var teacher_skill: Dictionary = teacher_data.get("skills", {}).get(skill_name, {})
	var teacher_level: int = int(teacher_skill.get("level", 0))
	var student_skill: Dictionary = student_data.get("skills", {}).get(skill_name, {})
	if not student_data["skills"].has(skill_name):
		student_data["skills"][skill_name] = {"xp": 0, "level": 0, "last_used": tick, "actions": 0}
	student_skill = student_data["skills"][skill_name]
	# Teaching efficiency scales with teacher level
	var xp_gain: float = float(XP_REWARDS.get("teach", 8)) * TEACHING_EFFICIENCY * (1.0 + float(teacher_level) * 0.2)
	student_skill["xp"] += int(xp_gain)
	student_skill["level"] = _xp_to_level(student_skill["xp"])
	student_skill["last_used"] = tick


# ============================================================
# ACHIEVEMENTS
# ============================================================

func _check_achievements(tick: int) -> void:
	"""Check for new achievements."""
	for pawn_id in character_data.keys():
		var data: Dictionary = character_data[pawn_id]
		for ach_id in ACHIEVEMENTS.keys():
			if ach_id in data.get("achievements", []):
				continue
			if _check_achievement_condition(data, ach_id):
				_add_achievement_if_missing(data, ach_id)
				# Log achievement
				var pawn_name: String = _get_pawn_name(pawn_id)
				var ach_name: String = str(ACHIEVEMENTS[ach_id].get("name", ""))
				if ChronicleLog != null:
					ChronicleLog.append_entry(tick, "world", "%s achieved: %s!" % [pawn_name, ach_name],
						PackedStringArray(["achievement", pawn_name, ach_name]))


func _check_achievement_condition(data: Dictionary, ach_id: String) -> bool:
	"""Check if a pawn meets an achievement condition."""
	var condition: String = str(ACHIEVEMENTS[ach_id].get("condition", ""))
	# Parse simple conditions like "kills >= 1"
	var parts: Array = condition.split(" ")
	if parts.size() != 3:
		return false
	var stat: String = parts[0]
	var op: String = parts[1]
	var threshold: int = int(parts[2])
	# Get stat value
	var value: int = _get_stat_value(data, stat)
	# Check condition
	match op:
		">=": return value >= threshold
		">": return value > threshold
		"==": return value == threshold
		_: return false


func _get_stat_value(data: Dictionary, stat: String) -> int:
	"""Get a stat value from character data."""
	# Check skill actions
	for skill_name in data.get("skills", {}).keys():
		var skill: Dictionary = data["skills"][skill_name]
		if stat == skill_name:
			return int(skill.get("actions", 0))
	# Check special stats
	match stat:
		"kills": return int(data.get("kills", 0))
		"battles": return int(data.get("battles", 0))
		"commanded": return int(data.get("commanded", 0))
		"explored": return int(data.get("explored", 0))
		"teach": return int(data.get("teach_actions", 0))
	return 0


func _add_achievement_if_missing(data: Dictionary, ach_id: String) -> void:
	"""Add an achievement if not already earned."""
	if not data.has("achievements"):
		data["achievements"] = []
	if not ach_id in data["achievements"]:
		data["achievements"].append(ach_id)


# ============================================================
# HELPERS
# ============================================================

func _ensure_character_record(pawn_id: int) -> void:
	"""Ensure a character record exists."""
	if character_data.has(pawn_id):
		return
	character_data[pawn_id] = {
		"pawn_id": pawn_id,
		"skills": {},
		"category_levels": {},
		"specialization": "None",
		"tool_quality": {},
		"achievements": [],
		"reputation": 0.0,
		"fame": 0.0,
		"kills": 0,
		"battles": 0,
		"commanded": 0,
		"explored": 0,
		"teach_actions": 0,
	}


func _get_pawn_name(pawn_id: int) -> String:
	var pawn: Node = _get_pawn_by_id(pawn_id)
	if pawn == null or pawn.data == null:
		return "Unknown"
	var _name = pawn.data.get("name")
	if _name == null:
		return "Unknown"
	return str(_name)


func _get_pawn_by_id(pawn_id: int) -> Node:
	if PawnAccess == null:
		return null
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			if int(p.data.id) == pawn_id:
				return p
	return null


# ============================================================
# PUBLIC API
# ============================================================

func get_character_data(pawn_id: int) -> Dictionary:
	return character_data.get(pawn_id, {})


func get_skill_level(pawn_id: int, skill_name: String) -> int:
	var data: Dictionary = character_data.get(pawn_id, {})
	var skill: Dictionary = data.get("skills", {}).get(skill_name, {})
	return int(skill.get("level", 0))


func get_skill_name(level: int) -> String:
	if level < 0 or level >= SKILL_LEVEL_NAMES.size():
		return "Unknown"
	return SKILL_LEVEL_NAMES[level]


func get_category_level(pawn_id: int, category: int) -> float:
	var data: Dictionary = character_data.get(pawn_id, {})
	return float(data.get("category_levels", {}).get(category, 0.0))


func get_specialization(pawn_id: int) -> String:
	var data: Dictionary = character_data.get(pawn_id, {})
	return str(data.get("specialization", "None"))


func get_achievements(pawn_id: int) -> Array[String]:
	var data: Dictionary = character_data.get(pawn_id, {})
	return data.get("achievements", [])


func get_reputation(pawn_id: int) -> float:
	var data: Dictionary = character_data.get(pawn_id, {})
	return float(data.get("reputation", 0.0))


func get_fame(pawn_id: int) -> float:
	var data: Dictionary = character_data.get(pawn_id, {})
	return float(data.get("fame", 0.0))


func set_tool_quality(pawn_id: int, skill_name: String, quality: String) -> void:
	"""Set tool quality for a skill."""
	_ensure_character_record(pawn_id)
	var data: Dictionary = character_data[pawn_id]
	if not data.has("tool_quality"):
		data["tool_quality"] = {}
	data["tool_quality"][skill_name] = quality


func get_character_count() -> int:
	return character_data.size()
