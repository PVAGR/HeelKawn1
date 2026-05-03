extends SceneTree

## Headless settlement lifecycle validation.
## Run: Godot --headless --path . -s res://tools/sim_settlement_lifecycle_smoke.gd
##
## Validates the pure settlement state classification function
## (SettlementMemory._settlement_state_v1) by calling it with controlled inputs.
## This tests the state machine logic in isolation — it does NOT validate
## the full live settlement lifecycle (recompute, hysteresis, material
## activity overrides, or WorldMemory transition logging).
##
## Read-only: does not modify core game logic, does not save world state,
## does not mutate GameManager (only reads tick_count).


var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_lifecycle_validation()
	return true


func _run_lifecycle_validation() -> void:
	print("[LIFECYCLE] START")

	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm == null:
		print("[LIFECYCLE] FAIL: SettlementMemory autoload not found")
		quit(1)
		return

	if not sm.has_method("_settlement_state_v1"):
		print("[LIFECYCLE] FAIL: _settlement_state_v1 not found")
		quit(1)
		return

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		print("[LIFECYCLE] FAIL: GameManager autoload not found")
		quit(1)
		return

	var current_tick: int = int(gm.get("tick_count"))

	# --- Test 1: active ---
	# scar_max=0, reputation_min=0, last_activity_tick=-1 (no recent activity),
	# last_pawn_death_tick=-1 (no deaths => 1B ticks since collapse = full peace),
	# culture_branch=1 (CAUTIOUS, peace_threshold=30000)
	# collapse_component=100, peace_component=100, scar_penalty=0,
	# branch_bonus=5, rep_bonus=0 => base_score=100
	# scar<=2, peace>=30000, score>=88, scar<=1, peace>=60000 => "active"
	var state_active: String = sm.call(
		"_settlement_state_v1", 0, 0, -1, -1, 1
	)
	if state_active == "active":
		print("[LIFECYCLE] active OK")
	else:
		print("[LIFECYCLE] FAIL: expected active, got %s" % state_active)
		quit(1)
		return

	# --- Test 2: abandoned (scar >= 3, recent collapse) ---
	# scar_max=3, last_pawn_death_tick = current_tick (0 ticks since collapse)
	# => ticks_since_collapse=0, which <= HARD_COLLAPSE_TICKS(30000) => "abandoned"
	var state_abandoned: String = sm.call(
		"_settlement_state_v1", 3, 0, current_tick, current_tick, 1
	)
	if state_abandoned == "abandoned":
		print("[LIFECYCLE] abandoned OK")
	else:
		print("[LIFECYCLE] FAIL: expected abandoned, got %s" % state_abandoned)
		quit(1)
		return

	# --- Test 3: revivable ---
	# scar_max=1, reputation_min=0, last_activity_tick=-1,
	# last_pawn_death_tick=-1 (1B ticks peace), culture_branch=1
	# collapse_component=100, peace_component=100, scar_penalty=25,
	# branch_bonus=5, rep_bonus=0 => base_score=80
	# scar<=2, peace>=30000, score 80>=70 but <88 => "revivable"
	var state_revivable: String = sm.call(
		"_settlement_state_v1", 1, 0, -1, -1, 1
	)
	if state_revivable == "revivable":
		print("[LIFECYCLE] reviving OK")
	else:
		print("[LIFECYCLE] FAIL: expected revivable, got %s" % state_revivable)
		quit(1)
		return

	# --- Test 4: permanently_abandoned ---
	# scar_max=3, last_pawn_death_tick = current_tick - 40000
	# => ticks_since_collapse=40000, which > HARD_COLLAPSE_TICKS(30000)
	# => scar>=3 and not recent => "permanently_abandoned"
	var state_permanent: String = sm.call(
		"_settlement_state_v1", 3, 0, current_tick - 40000, current_tick - 40000, 1
	)
	if state_permanent == "permanently_abandoned":
		print("[LIFECYCLE] permanent_ruin OK")
	else:
		print("[LIFECYCLE] FAIL: expected permanently_abandoned, got %s" % state_permanent)
		quit(1)
		return

	print("[LIFECYCLE] OK")
	print("[LIFECYCLE] NOTE: This does not validate live recompute, hysteresis, WorldMemory transition logging, or material activity overrides.")
	quit(0)
