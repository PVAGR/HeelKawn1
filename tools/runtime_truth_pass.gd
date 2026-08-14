#!/usr/bin/env -S godot --headless --script
## Runtime Truth Pass — Headless F10 Diagnostic Verification
## Exercises every F10 diagnostic code path programmatically and reports [PASS]/[FAIL]
## Run: Godot --path . -s res://tools/runtime_truth_pass.gd --headless

extends SceneTree

const REQUIRED_AUTOLOADS: Array[String] = [
	"GameManager", "TickManager", "WorldMemory", "SettlementMemory",
	"JobManager", "WorldAI", "StockpileManager", "ColonySimServices",
	"PawnAccess", "HeelKawnianManager", "CivilizationStage",
	"KnowledgeSystem", "EgregoreMemory", "FactionManager",
	"MemoryManager", "SocialManager", "EconomyManager",
	"EventBus", "DayNightCycle", "SimTime", "WorldRNG",
	"WorldEnvironmentManager", "TechnologySystem"
]

func _get_autoload(name: String) -> Node:
	return root.get_node_or_null(name)

func _get_autoload_script(name: String) -> Variant:
	var node: Node = _get_autoload(name)
	if node != null:
		return node.get_script()
	return null

const F10_DIAGNOSTICS: Array[Dictionary] = [
	{"id": "backbone_status", "name": "F10 #35 · Backbone / First-Play (LIVE vs DEFERRED)", "func": "_test_backbone_status"},
	{"id": "heelkawnians", "name": "F10 #49 · HeelKawnians (Individual Development AI Profiles)", "func": "_test_heelkawnians"},
	{"id": "civilization_stage", "name": "F10 #03B · Civilization Stage (Derived Era Lens)", "func": "_test_civilization_stage"},
	{"id": "chronicle_view", "name": "F10 #71 · Chronicle View (Settlement History as Story)", "func": "_test_chronicle_view"},
	{"id": "settlement_legends", "name": "F10 #72 · Settlement Legends (Emergent Myths & Stories)", "func": "_test_settlement_legends"},
	{"id": "dynasty_tree", "name": "F10 #74 · Dynasty Tree (Visual Family Tree)", "func": "_test_dynasty_tree"},
	{"id": "legacy_milestones", "name": "F10 #75 · Legacy Milestones (Historical Progress)", "func": "_test_legacy_milestones"},
	{"id": "pawn_info_panel", "name": "Pawn Info Panel Data Path (selection → narrative/skills/family)", "func": "_test_pawn_info_panel"},
	{"id": "settlement_info_panel", "name": "Settlement Info Panel Data Path (selection → population/buildings/era)", "func": "_test_settlement_info_panel"},
	{"id": "knowledge_carriers", "name": "F10 #44 · Knowledge Carriers (Masters, at-risk knowledge)", "func": "_test_knowledge_carriers"},
	{"id": "life_arcs", "name": "F10 #43 · Life Arcs (Readable Pawn Narratives)", "func": "_test_life_arcs"},
	{"id": "myth_formation", "name": "F10 #45 · Myth Formation (Feared/Revered Regions)", "func": "_test_myth_formation"},
	{"id": "record_carriers", "name": "F10 #46 · Record Carriers (Knowledge Preservation Stones)", "func": "_test_record_carriers"},
	{"id": "memorial_system", "name": "F10 #47 · Memorial System (Memorials, Sacred Geography, Pilgrimage)", "func": "_test_memorial_system"},
	{"id": "knowledge_system", "name": "F10 #48 · Knowledge Systems (Carriers, Teaching, Loss/Rediscovery)", "func": "_test_knowledge_system"},
	{"id": "ai_pipeline_health", "name": "F10 #80 · AI Pipeline Health (Food + Survival + Structures + Jobs)", "func": "_test_ai_pipeline_health"},
	{"id": "playtest_truth_all", "name": "F10 ★ ALL PLAYTEST TRUTH (One Paste Pack)", "func": "_test_playtest_truth_all"},
]

var _test_results: Array[Dictionary] = []
var _world: Node = null
var _main: Node = null
var _start_time: int = 0

func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	print("=== HEELKAWN RUNTIME TRUTH PASS START ===")
	print("Timestamp: %s" % Time.get_datetime_string_from_system())
	print("Godot Version: %s" % Engine.get_version_info().string)
	print("")
	
	# Wait one frame for autoloads
	call_deferred("_run_all_diagnostics")

func _run_all_diagnostics() -> void:
	_check_autoloads()
	_create_test_world()
	
	for diag in F10_DIAGNOSTICS:
		_run_diagnostic(diag)
	
	_print_summary()
	print("")
	print("=== HEELKAWN RUNTIME TRUTH PASS END ===")
	
	var has_fail: bool = false
	for r in _test_results:
		if not r.passed:
			has_fail = true
			break
	
	if has_fail:
		quit(1)
	else:
		quit(0)

func _check_autoloads() -> void:
	print("--- AUTOLOAD VERIFICATION ---")
	var missing: Array[String] = []
	for name in REQUIRED_AUTOLOADS:
		var node: Node = root.get_node_or_null(name)
		if node == null:
			missing.append(name)
			print("[FAIL] Autoload missing: %s" % name)
		else:
			print("[OK] Autoload: %s" % name)
	
	if missing.is_empty():
		print("[PASS] All required autoloads present")
	else:
		print("[FAIL] Missing %d autoloads: %s" % [missing.size(), str(missing)])
	print("")

func _create_test_world() -> void:
	print("--- TEST WORLD CREATION ---")
	
	_main = root.get_node_or_null("Main")
	if _main == null:
		print("[FAIL] Main node not found — creating minimal Main")
		_main = _create_minimal_main()
	
	_world = _main.get_node_or_null("WorldViewport/World")
	if _world == null:
		print("[WARN] World node not found under Main/WorldViewport")
	
	var ps: Node = _main.get_node_or_null("WorldViewport/PawnSpawner")
	if ps == null:
		print("[FAIL] PawnSpawner not found")
		return
	
	# Spawn 20 test pawns
	var spawned: int = 0
	for i in range(20):
		var pos: Vector2i = Vector2i(120 + (i % 5) * 4, 120 + (i / 5) * 4)
		var pawn: Node = ps.call("spawn_pawn", pos, -1, {})
		if pawn != null and is_instance_valid(pawn):
			spawned += 1
			var pd: HeelKawnianData = pawn.get("data") as HeelKawnianData
			if pd != null:
				_patch_pawn_for_diagnostics(pd, i)
	
	var settlement_mem: Node = _get_autoload("SettlementMemory")
	if settlement_mem != null and settlement_mem.has_method("recompute"):
		settlement_mem.call("recompute", _world)
	
	var knowledge_sys: Node = _get_autoload("KnowledgeSystem")
	if knowledge_sys != null:
		knowledge_sys.call("_refresh_pawn_cache")
	
	print("[OK] Spawned %d test pawns" % spawned)
	print("[OK] Test world ready")
	print("")

func _create_minimal_main() -> Node:
	var main_script: Script = ResourceLoader.load("res://scenes/main/Main.gd", "Script")
	var main: Node2D = main_script.new()
	root.add_child(main)
	main.name = "Main"
	return main

func _patch_pawn_for_diagnostics(pd: HeelKawnianData, index: int) -> void:
	# Add skills using skill type ints (0=farming, 1=building, 2=crafting, etc.)
	var skill_types: Array[int] = [0, 1, 2, 3, 4, 5, 6] # FARMING, BUILDING, CRAFTING, COMBAT, DIPLOMACY, TEACHING, MEDICINE
	for st in skill_types:
		pd.add_skill_xp(st, int(randi() % 50 + 10))
	
	var knowledge_sys: Node = _get_autoload("KnowledgeSystem")
	if knowledge_sys != null:
		var ktypes: Array[int] = [0, 1, 2, 3, 6, 11, 13, 16] # FIRE_KEEPING, FOOD_STORAGE, TOOL_MAKING, SEASON_READING, SHELTER_BUILDING, TEACHING, FARMING, CRAFTING
		for kt in ktypes:
			if randi() % 3 == 0:
				knowledge_sys.call("add_knowledge_carrier", int(pd.id), kt)
	
	# Set profession based on highest skill
	var prof_map: Dictionary = {
		0: HeelKawnianData.Profession.FARMER,
		1: HeelKawnianData.Profession.BUILDER,
		2: HeelKawnianData.Profession.CARPENTER,
		3: HeelKawnianData.Profession.WARRIOR,
		4: HeelKawnianData.Profession.TRADER,
		5: HeelKawnianData.Profession.SCHOLAR,
		6: HeelKawnianData.Profession.HEALER
	}
	var top_skill: int = -1
	var top_xp: int = 0
	for skill in pd.skill_trees.keys():
		if pd.skill_trees[skill].total_xp > top_xp:
			top_xp = pd.skill_trees[skill].total_xp
			top_skill = skill
	if top_skill >= 0 and prof_map.has(top_skill):
		pd.current_profession = prof_map[top_skill]

func _run_diagnostic(diag: Dictionary) -> void:
	var start: int = Time.get_ticks_msec()
	print(">>> Running: %s" % diag.name)
	
	var passed: bool = true
	var error_msg: String = ""
	var return_val: Variant = null
	var stack_trace: String = ""
	
	# Use call() which is safe - returns null on error
	return_val = call(diag.func)
	
	var elapsed: int = Time.get_ticks_msec() - start
	if elapsed > 100:
		print("[WARN] %s took %d ms (>100ms threshold)" % [diag.name, elapsed])
	
	if passed:
		var struct_ok: bool = _validate_return(diag.id, return_val)
		if not struct_ok:
			passed = false
			error_msg = "Return value validation failed (empty/null/malformed)"
	
	var result: Dictionary = {
		"id": diag.id,
		"name": diag.name,
		"passed": passed,
		"elapsed_ms": elapsed,
		"error": error_msg,
		"stack_trace": stack_trace,
		"return_type": typeof(return_val),
		"return_summary": _summarize_return(return_val)
	}
	_test_results.append(result)
	
	if passed:
		print("[PASS] %s (%d ms)" % [diag.name, elapsed])
	else:
		print("[FAIL] %s (%d ms) — %s" % [diag.name, elapsed, error_msg])
	print("")

func _validate_return(diag_id: String, val: Variant) -> bool:
	if val == null:
		return false
	if val is Array and val.is_empty():
		return false
	if val is Dictionary and val.is_empty():
		return false
	return true

func _summarize_return(val: Variant) -> String:
	if val == null:
		return "null"
	if val is Array:
		return "Array[%d]" % val.size()
	if val is Dictionary:
		return "Dict{%s}" % str(val.keys())
	if val is String:
		return "String(len=%d)" % val.length()
	return str(typeof(val))

func _print_summary() -> void:
	print("")
	print("=== RUNTIME TRUTH PASS SUMMARY ===")
	var pass_count: int = 0
	var fail_count: int = 0
	for r in _test_results:
		if r.passed:
			pass_count += 1
		else:
			fail_count += 1
	
	print("Total: %d | PASS: %d | FAIL: %d" % [_test_results.size(), pass_count, fail_count])
	print("")
	
	for r in _test_results:
		var status: String = "PASS" if r.passed else "FAIL"
		print("[%s] %s (%d ms)" % [status, r.name, r.elapsed_ms])
		if not r.passed and r.error != "":
			print("       Error: %s" % r.error)
		if not r.passed and r.stack_trace != "":
			print("       Stack: %s" % r.stack_trace.substr(0, 200))
	
	if fail_count > 0:
		print("")
		print("!!! %d DIAGNOSTICS FAILED — RUNTIME TRUTH PASS NOT CLEAN !!!" % fail_count)

	quit(fail_count)

# ============ DIAGNOSTIC TEST FUNCTIONS ============

func _test_backbone_status() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_backbone_status")
	(menu as Node).queue_free()

func _test_heelkawnians() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_heelkawnians")
	(menu as Node).queue_free()

func _test_civilization_stage() -> void:
	var civ_stage: Node = _get_autoload("CivilizationStage")
	if civ_stage == null:
		push_error("CivilizationStage autoload missing")
		return
	
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu != null:
		var menu_class: Variant = creator_debug_menu.get_script()
		if menu_class != null:
			var menu: Object = menu_class.new()
			root.add_child(menu as Node)
			menu.call("_report_civilization_stage")
			(menu as Node).queue_free()
	
	# Test new continuous metrics APIs
	var world_snap: Dictionary = civ_stage.call("get_world_stage_snapshot")
	assert(world_snap.has("stage"))
	assert(world_snap.has("score"))
	assert(world_snap.has("breakdown"))
	assert(world_snap.has("continuous_metrics"))
	
	var all_snaps: Array[Dictionary] = civ_stage.call("get_all_stage_snapshots", 12)
	
	var lit_rate: float = civ_stage.call("get_literacy_rate", 0)
	var tech_diff: float = civ_stage.call("get_tech_diffusion_score", 0)
	var egregore: Dictionary = civ_stage.call("get_egregore_signature", 0)
	var norms: Array = civ_stage.call("get_active_norms", 0)
	var div: Dictionary = civ_stage.call("get_divergence_snapshot", 0)
	var gov: String = civ_stage.call("get_governance_form", 0)
	var guild: Dictionary = civ_stage.call("get_guild_data", 0)
	var metrics: Dictionary = civ_stage.call("get_continuous_metrics", 0)
	var all_metrics: Array[Dictionary] = civ_stage.call("get_all_continuous_metrics")

func _test_chronicle_view() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_chronicle_view")
	(menu as Node).queue_free()

func _test_settlement_legends() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_settlement_legends")
	(menu as Node).queue_free()
	
	var legend_script: GDScript = load("res://scripts/world/SettlementLegend.gd")
	if legend_script != null:
		var test_events: Array[Dictionary] = [
			{"type": "settlement_founded", "sid": 0, "n": "TestVale"},
			{"type": "building_constructed", "sid": 0, "building_type": "fire_pit"},
			{"type": "birth", "sid": 0, "n": "Child1"},
			{"type": "pawn_death", "sid": 0, "n": "Elder1", "c": "old_age"},
			{"type": "knowledge_inscribed", "sid": 0},
		]
		var legend: String = legend_script.call("generate_legend", 0, "TestVale", test_events)
		assert(legend.contains("LEGEND OF TESTVALE"))

func _test_dynasty_tree() -> void:
	var legacy_sys: Node = root.get_node_or_null("SocialManager")
	if legacy_sys == null:
		print("[WARN] SocialManager not found — dynasty tree data path skipped")
		return
	
	if legacy_sys.has_method("get_dynasty_summary"):
		var dynasties: Variant = legacy_sys.get("dynasties")
		if dynasties != null and dynasties is Dictionary:
			for did in dynasties:
				var summary: Dictionary = legacy_sys.call("get_dynasty_summary", int(did))
				assert(summary.has("name"))
				assert(summary.has("generations"))
				assert(summary.has("members"))
				assert(summary.has("legacy_score_total"))
				
				if legacy_sys.has_method("get_dynasty_members"):
					var members: Array[int] = legacy_sys.call("get_dynasty_members", int(did))
					for pid in members:
						var ps: Node = root.get_node_or_null("Main/WorldViewport/PawnSpawner")
						if ps != null and ps.has_method("pawn_data_for_id"):
							var pd: HeelKawnianData = ps.call("pawn_data_for_id", pid)
							assert(pd != null)
				break

func _test_legacy_milestones() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_endgame_status")
	(menu as Node).queue_free()

func _test_pawn_info_panel() -> void:
	var main_node: Node = root.get_node_or_null("Main")
	if main_node == null:
		push_error("Main not found")
		return
	
	var ps: Node = main_node.get_node_or_null("WorldViewport/PawnSpawner")
	if ps == null:
		push_error("PawnSpawner not found")
		return
	
	var test_pawn: Node = null
	for p in ps.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			test_pawn = p
			break
	
	if test_pawn == null:
		push_error("No valid pawns to test")
		return
	
	var pd: HeelKawnianData = test_pawn.data
	
	if pd.has_method("compose_life_arc"):
		var life_arc: String = pd.compose_life_arc()
		assert(not life_arc.is_empty())
	
	assert(pd.skill_trees != null)
	var skills_count: int = pd.skill_trees.size()
	assert(skills_count > 0)
	
	var kin: Node = root.get_node_or_null("SocialManager")
	if kin != null:
		if kin.has_method("get_lineage_parents"):
			var parents: Array = kin.call("get_lineage_parents", int(pd.id))
		if kin.has_method("get_lineage_children"):
			var children: Array = kin.call("get_lineage_children", int(pd.id))
	
	var knowledge_sys: Node = _get_autoload("KnowledgeSystem")
	if knowledge_sys != null and knowledge_sys.has_method("has_knowledge"):
		var has_writing: bool = knowledge_sys.call("has_knowledge", int(pd.id), 24)
	
	assert(pd.id >= 0)
	assert(pd.display_name != "")
	assert(pd.age_years >= 0)
	assert(pd.hunger >= 0)
	assert(pd.rest >= 0)
	assert(pd.mood >= -100 and pd.mood <= 100)

func _test_settlement_info_panel() -> void:
	var settlement_mem: Node = _get_autoload("SettlementMemory")
	if settlement_mem == null:
		push_error("SettlementMemory not found")
		return
	
	var settlements: Array = settlement_mem.call("get_formal_settlements")
	if settlements.is_empty():
		print("[WARN] No formal settlements yet — skipping settlement info panel test")
		return
	
	var st: Dictionary = settlements[0] as Dictionary
	
	assert(st.has("center_region"))
	assert(st.has("culture_name"))
	assert(st.has("state"))
	assert(st.has("population"))
	assert(st.has("current_intent"))
	
	var civ_stage: Node = _get_autoload("CivilizationStage")
	if civ_stage != null:
		var snap: Dictionary = civ_stage.call("get_stage_snapshot", 0)
		assert(snap.has("stage"))
		assert(snap.has("score"))
		assert(snap.has("stage_name"))
		assert(snap.has("breakdown"))
		assert(snap.has("continuous_metrics"))
	
	var egregore_mem: Node = _get_autoload("EgregoreMemory")
	if egregore_mem != null:
		var center: int = int(st.get("center_region", -1))
		if center >= 0:
			var sig: Dictionary = egregore_mem.call("get_settlement_signature", center)
			var norms: Array = egregore_mem.call("get_settlement_active_norms", center)
			var div: Dictionary = egregore_mem.call("get_settlement_divergence_snapshot", center)
	
	var faction_mgr: Node = _get_autoload("FactionManager")
	if faction_mgr != null:
		if faction_mgr.has_method("get_polity_relation_score"):
			pass

func _test_knowledge_carriers() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_knowledge_carriers")
	(menu as Node).queue_free()

func _test_life_arcs() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_life_arcs")
	(menu as Node).queue_free()

func _test_myth_formation() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_myth_formation")
	(menu as Node).queue_free()

func _test_record_carriers() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_record_carriers")
	(menu as Node).queue_free()

func _test_memorial_system() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_memorial_system")
	(menu as Node).queue_free()

func _test_knowledge_system() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_knowledge_system")
	(menu as Node).queue_free()

func _test_ai_pipeline_health() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_ai_pipeline_health")
	(menu as Node).queue_free()

func _test_playtest_truth_all() -> void:
	var creator_debug_menu: Node = _get_autoload("CreatorDebugMenu")
	if creator_debug_menu == null:
		push_error("CreatorDebugMenu autoload missing")
		return
	
	var menu_class: Variant = creator_debug_menu.get_script()
	if menu_class == null:
		push_error("CreatorDebugMenu script not found")
		return
	
	var menu: Object = menu_class.new()
	root.add_child(menu as Node)
	menu.call("_report_playtest_truth_all")
	(menu as Node).queue_free()