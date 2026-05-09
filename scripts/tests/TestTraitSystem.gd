extends Node

func _ready() -> void:
	print("[TestTraitSystem] Starting test...")
	var pd: HeelKawnianData = HeelKawnianData.new()
	# Ensure fresh state
	pd.available_krond = 0.0
	pd.total_krond_earned = 0.0
	pd.active_traits = []

	pd.grant_krond(25.0)
	if int(round(pd.available_krond)) != 25 or int(round(pd.total_krond_earned)) != 25:
		print("[TestTraitSystem] FAIL: grant_krond did not set expected values: available=%s total=%s" % [str(pd.available_krond), str(pd.total_krond_earned)])
		return

	var t: TraitData = TraitData.new()
	t.krond_cost = 25.0
	t.id = "test_trait"
	var applied: bool = pd.apply_trait(t)
	if not applied:
		print("[TestTraitSystem] FAIL: apply_trait returned false despite sufficient krond")
		return
	if pd.active_traits.size() != 1:
		print("[TestTraitSystem] FAIL: active_traits size unexpected: %d" % pd.active_traits.size())
		return
	if int(round(pd.available_krond)) != 0:
		print("[TestTraitSystem] FAIL: available_krond not deducted: %s" % str(pd.available_krond))
		return

	print("[TestTraitSystem] PASS: grant_krond and apply_trait behaved as expected.")
	# Optionally quit the scene tree when run headless
	if Engine.has_singleton("GodotEditor"):
		# running inside editor - keep node
		return
	get_tree().quit()
