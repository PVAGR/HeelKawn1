extends Node

func _ready() -> void:
	print("[TestSkillTreeBonuses] Starting skill tree bonus verification...")
	
	var pd: HeelKawnianData = HeelKawnianData.new()
	pd.display_name = "TestPawn"
	
	# Test 1: Level 5 - Basic branch (work_speed_mult: 1.1)
	print("\n[TestSkillTreeBonuses] Test 1: Advancing to level 5...")
	_force_level_up(pd, 5)
	print("[TestSkillTreeBonuses] Level: %d" % pd.level)
	print("[TestSkillTreeBonuses] Skill trees: %s" % [pd.skill_trees.keys()])
	
	var speed_5: float = pd.work_speed_for(HeelKawnianData.Skill.FORAGING)
	print("[TestSkillTreeBonuses] work_speed_for(FORAGING) at level 5: %.3f (expect ~1.1)" % speed_5)
	if speed_5 < 1.09 or speed_5 > 1.11:
		print("[TestSkillTreeBonuses] WARN: Level 5 bonus out of range (got %.3f, expect ~1.1)" % speed_5)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 5 bonus correct")
	
	# Test 2: Level 10 - Intermediate branch (work_speed_mult: 1.2)
	print("\n[TestSkillTreeBonuses] Test 2: Advancing to level 10...")
	_force_level_up(pd, 10)
	print("[TestSkillTreeBonuses] Level: %d" % pd.level)
	
	var speed_10: float = pd.work_speed_for(HeelKawnianData.Skill.FORAGING)
	print("[TestSkillTreeBonuses] work_speed_for(FORAGING) at level 10: %.3f (expect ~1.2)" % speed_10)
	if speed_10 < 1.19 or speed_10 > 1.21:
		print("[TestSkillTreeBonuses] WARN: Level 10 bonus out of range (got %.3f, expect ~1.2)" % speed_10)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 10 bonus correct")
	
	# Test 3: Level 15 - Advanced branch (work_speed_mult: 1.3, quality_bonus: 1.1)
	print("\n[TestSkillTreeBonuses] Test 3: Advancing to level 15...")
	_force_level_up(pd, 15)
	print("[TestSkillTreeBonuses] Level: %d" % pd.level)
	
	var speed_15: float = pd.work_speed_for(HeelKawnianData.Skill.FORAGING)
	var quality_15: float = pd.harvest_quality_multiplier_for_job_skill(HeelKawnianData.Skill.FORAGING)
	print("[TestSkillTreeBonuses] work_speed_for(FORAGING) at level 15: %.3f (expect ~1.3)" % speed_15)
	print("[TestSkillTreeBonuses] harvest_quality_multiplier at level 15: %.3f (expect ~1.1)" % quality_15)
	if speed_15 < 1.29 or speed_15 > 1.31:
		print("[TestSkillTreeBonuses] WARN: Level 15 speed bonus out of range (got %.3f, expect ~1.3)" % speed_15)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 15 speed bonus correct")
	if quality_15 < 1.09 or quality_15 > 1.11:
		print("[TestSkillTreeBonuses] WARN: Level 15 quality bonus out of range (got %.3f, expect ~1.1)" % quality_15)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 15 quality bonus correct")
	
	# Test 4: Level 20 - Mastery branch (work_speed_mult: 1.5, quality_bonus: 1.2, leadership_mult: 1.3)
	print("\n[TestSkillTreeBonuses] Test 4: Advancing to level 20...")
	_force_level_up(pd, 20)
	print("[TestSkillTreeBonuses] Level: %d" % pd.level)
	
	var speed_20: float = pd.work_speed_for(HeelKawnianData.Skill.FORAGING)
	var quality_20: float = pd.harvest_quality_multiplier_for_job_skill(HeelKawnianData.Skill.FORAGING)
	var leadership_20: float = pd.leadership_presence_multiplier()
	print("[TestSkillTreeBonuses] work_speed_for(FORAGING) at level 20: %.3f (expect ~1.5)" % speed_20)
	print("[TestSkillTreeBonuses] harvest_quality_multiplier at level 20: %.3f (expect ~1.2)" % quality_20)
	print("[TestSkillTreeBonuses] leadership_presence_multiplier at level 20: %.3f (expect ~1.3)" % leadership_20)
	if speed_20 < 1.49 or speed_20 > 1.51:
		print("[TestSkillTreeBonuses] WARN: Level 20 speed bonus out of range (got %.3f, expect ~1.5)" % speed_20)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 20 speed bonus correct")
	if quality_20 < 1.19 or quality_20 > 1.21:
		print("[TestSkillTreeBonuses] WARN: Level 20 quality bonus out of range (got %.3f, expect ~1.2)" % quality_20)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 20 quality bonus correct")
	if leadership_20 < 1.29 or leadership_20 > 1.31:
		print("[TestSkillTreeBonuses] WARN: Level 20 leadership bonus out of range (got %.3f, expect ~1.3)" % leadership_20)
	else:
		print("[TestSkillTreeBonuses] PASS: Level 20 leadership bonus correct")
	
	# Test 5: XP multiplier also applied
	print("\n[TestSkillTreeBonuses] Test 5: Checking XP multiplier...")
	var xp_before: float = pd.get_skill_xp(HeelKawnianData.Skill.FORAGING)
	var test_xp_amount: float = 100.0
	pd.add_skill_xp(HeelKawnianData.Skill.FORAGING, test_xp_amount)
	var xp_after: float = pd.get_skill_xp(HeelKawnianData.Skill.FORAGING)
	var xp_applied: float = xp_after - xp_before
	# At level 20, xp_mult is 1.2, so 100 XP should become 120
	var expected_xp: float = test_xp_amount * 1.2
	print("[TestSkillTreeBonuses] Applied 100 XP, got %.1f (expect ~120)" % xp_applied)
	if xp_applied < 119.0 or xp_applied > 121.0:
		print("[TestSkillTreeBonuses] WARN: XP multiplier out of range (got %.1f, expect ~120)" % xp_applied)
	else:
		print("[TestSkillTreeBonuses] PASS: XP multiplier correct")
	
	print("\n[TestSkillTreeBonuses] All tests completed!")
	
	# Optionally quit
	if not Engine.has_singleton("GodotEditor"):
		get_tree().quit()


func _force_level_up(pd: HeelKawnianData, target_level: int) -> void:
	"""Force XP until reaching target_level."""
	while pd.level < target_level:
		var xp_needed: float = (target_level - pd.level) * HeelKawnianData.XP_PER_LEVEL
		# Directly set skill XP to avoid multipliers during setup
		pd.skill_xp[0] = xp_needed * 2  # Overestimate to ensure level
		pd.sync_level_from_total_skill_xp()
