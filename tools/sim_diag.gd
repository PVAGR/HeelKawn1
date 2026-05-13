extends SceneTree

## Quick diagnostic: boot the sim, run 500 ticks, report pawn states and job stats.

const TICK_LIMIT: int = 500

var _main_spawned: bool = false
var _boot_wait: int = 30
var _done: bool = false
var _started: bool = false

func _process(_delta: float) -> bool:
	if _done:
		return false
	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_spawn_main()
		return false
	if not _main_spawned:
		return false
	if not _started:
		_started = true
		var tm = root.get_node_or_null("TickManager")
		if tm and tm.has_method("set_speed"):
			tm.call("set_speed", 100.0)
		return false

	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick = int(gm.get("tick_count"))
	if tick >= TICK_LIMIT:
		_report(tick)
		_done = true
		quit(0)
		return true
	return false

func _spawn_main():
	var packed = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[DIAG] FAIL: Main.tscn not found")
		quit(1)
		return
	var main = packed.instantiate()
	root.add_child(main)
	var tm = root.get_node_or_null("TickManager")
	if tm and tm.has_method("resume"):
		tm.call("resume")
	var gm = root.get_node_or_null("GameManager")
	if gm and gm.has_method("resume"):
		gm.call("resume")
	_main_spawned = true

func _report(tick: int):
	print("\n========== DIAGNOSTIC REPORT tick=%d ==========" % tick)

	# Pawn states
	var pawns_node = root.get_node_or_null("Main/WorldViewport/PawnSpawner")
	if pawns_node == null:
		print("[DIAG] PawnSpawner not found")
		return

	var pawns = []
	if pawns_node.has_method("get_all_pawns"):
		pawns = pawns_node.call("get_all_pawns")
	elif pawns_node.has_method("pawns"):
		pawns = pawns_node.get("pawns")

	var state_counts: Dictionary = {}
	var idle_reasons: Dictionary = {}
	var hunger_counts: Dictionary = {}
	var total_pawns: int = 0
	var dead_pawns: int = 0

	for p in pawns:
		if not is_instance_valid(p):
			continue
		total_pawns += 1
		var data = p.get("data") if p.has_method("get") else null
		if data == null and p.has_method("get_pawn_data"):
			data = p.call("get_pawn_data")
		if data == null:
			continue

		if data.get("is_dead", false):
			dead_pawns += 1
			continue

		# State
		var state = int(p.get("_state") if p.has_method("get") else -1)
		var state_name: String = "unknown"
		# Map state enum to name
		var state_names = ["IDLE", "WALKING_TO_JOB", "WORKING", "HAULING", "GOING_TO_EAT",
			"EATING", "SLEEPING", "FETCHING_MATERIAL", "GOING_TO_BED", "TEACHING",
			"CHALLENGE", "DRAFT_WALK", "GATHERING", "CRAFTING", "FLEEING",
			"HIDING", "PILGRIMAGE", "DIRECT_FORAGING"]
		if state >= 0 and state < state_names.size():
			state_name = state_names[state]
		state_counts[state_name] = int(state_counts.get(state_name, 0)) + 1

		# Hunger
		var hunger = float(data.get("hunger", 0))
		if hunger < 20:
			hunger_counts["starving"] = int(hunger_counts.get("starving", 0)) + 1
		elif hunger < 40:
			hunger_counts["hungry"] = int(hunger_counts.get("hungry", 0)) + 1
		else:
			hunger_counts["fed"] = int(hunger_counts.get("fed", 0)) + 1

		# Idle reason
		if state_name == "IDLE":
			var reason = str(p.get("last_claim_failure_reason") if p.has_method("get") else "no_data")
			if reason == "" or reason == "null":
				reason = "no_reason_set"
			idle_reasons[reason] = int(idle_reasons.get(reason, 0)) + 1

	print("PAWNS: total=%d dead=%d alive=%d" % [total_pawns, dead_pawns, total_pawns - dead_pawns])
	print("STATES: %s" % str(state_counts))
	print("HUNGER: %s" % str(hunger_counts))
	if not idle_reasons.is_empty():
		print("IDLE_REASONS: %s" % str(idle_reasons))

	# Job stats
	var jm = root.get_node_or_null("JobManager")
	if jm:
		var open_count = int(jm.call("open_count")) if jm.has_method("open_count") else -1
		var claimed = int(jm.get("_claimed_count") if jm.has_method("get") else -1)
		print("JOBS: open=%d" % open_count)
		if jm.has_method("stats"):
			print("JOB_STATS: %s" % str(jm.call("stats")))

	# Stockpile
	var sm = root.get_node_or_null("StockpileManager")
	if sm and sm.has_method("total_count_of"):
		var Item = load("res://autoloads/Item.gd")
		if Item:
			var food = int(sm.call("total_count_of", Item.Type.BERRY)) + int(sm.call("total_count_of", Item.Type.MEAT)) + int(sm.call("total_count_of", Item.Type.FISH))
			var wood = int(sm.call("total_count_of", Item.Type.WOOD))
			var stone = int(sm.call("total_count_of", Item.Type.STONE))
			print("STOCKPILE: food=%d wood=%d stone=%d" % [food, wood, stone])

	print("========== END REPORT ==========")
