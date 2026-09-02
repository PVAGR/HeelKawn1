extends SceneTree

## Headless settlement-gate audit. Boots Main, runs at 200x to a mature tick,
## pauses, then dumps per-proto formalization diagnostics and pawn-membership
## contract checks.
##
## Purpose: prove the recompute formalization-gate fix — that _apply_guild_settlement_gate
## now runs on every recompute even under budget, so protos stop showing
## guild_candidate_reason="not_evaluated" and can actually formalize.
##
## NOTE: `--script` tools cannot reference autoload identifiers at parse time,
## so every autoload is resolved via root node lookups here. No preloads.

const RUN_TO_TICK := 12000
const FRAME_CAP := 15000
const GATE_PRINT_INTERVAL := 6000

var _frame := 0
var _phase := "boot"
var _printed := false
var _last_gate_frame := 0

var _gm: Node = null
var _main: Node = null
var _world: Node = null

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	## Permanent Tool Rule: this tool boots Main PAST the autosave boundary
	## (tick % 6000), so it MUST run with --playtest-no-save or it would
	## overwrite the production autosave. Refuse to run otherwise.
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("SETTLE_AUDIT: this tool boots Main past the autosave boundary and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("SETTLE_GATE_AUDIT: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	## Belt-and-suspenders: the fence must actually be active on Main.
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("SETTLE_AUDIT: Main autosave fence not active (Main._save_writes_disabled_for_playtest=false); refusing to run")
		quit(1)
		return

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		print("SETTLE_AUDIT: frame cap reached without reaching tick %d (tick=%s)" % [RUN_TO_TICK, _tick()])
		quit(1)
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			_gm.call("set_speed", 200.0)
			print("SETTLE_AUDIT: Main ready, 200x to tick %d" % RUN_TO_TICK)
		return false
	if _phase == "run":
		if _tick() >= RUN_TO_TICK:
			_phase = "dump"
			_gm.call("pause")
			var tm2: Node = root.get_node_or_null("/root/TickManager")
			if tm2 != null and tm2.has_method("pause"):
				tm2.call("pause")
			return false
		if _tick() - _last_gate_frame >= GATE_PRINT_INTERVAL:
			_last_gate_frame = _tick()
			_gate_status_line()
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _jk(obj, key: String, default: Variant) -> Variant:
	if obj == null or not "get" in obj:
		return default
	var v = obj.get(key)
	if v == null:
		return default
	return v

func _gate_status_line() -> void:
	var sm = _al("SettlementMemory")
	if sm == null or not sm.has_method("get_formal_settlements") or not sm.has_method("get_proto_sites"):
		return
	var formal: Array = sm.get_formal_settlements()
	var protos: Array = sm.get_proto_sites()
	print("SETTLE_AUDIT: @%d formal=%d proto=%d eval_reasons=%s" % [
		_tick(), formal.size(), protos.size(), str(_proto_reasons(protos))])

func _proto_reasons(protos: Array) -> Dictionary:
	var out: Dictionary = {}
	for ps in protos:
		if not (ps is Dictionary):
			continue
		var reason: String = str(ps.get("guild_candidate_reason", "UNSET"))
		out[reason] = int(out.get(reason, 0)) + 1
	return out

func _dump() -> void:
	_world = _main.get("_world")
	var tick: int = _tick()
	var sm = _al("SettlementMemory")
	var wm = _al("WorldMemory")
	var pawns: Array = []
	if _main != null:
		var spawner = _main.get("_pawn_spawner")
		if spawner != null:
			pawns = spawner.get("pawns")
	print("=== SETTLEMENT_GATE_AUDIT dump @ tick=%d pawn_count=%d ===" % [tick, pawns.size()])

	if sm == null:
		print("SETTLE_AUDIT: SettlementMemory unavailable")
		return

	var formal: Array = sm.get_formal_settlements() if sm.has_method("get_formal_settlements") else []
	var protos: Array = sm.get_proto_sites() if sm.has_method("get_proto_sites") else []
	var all_settlements: Array = sm.get_settlements() if sm.has_method("get_settlements") else []
	print("SETTLE_AUDIT: formal_settlements=%d proto_sites=%d all=%d" % [formal.size(), protos.size(), all_settlements.size()])

	# Per-pawn region -> index map, for contract checks (pawn.settlement_id is an ARRAY INDEX).
	var pawn_region: Dictionary = {}
	for p in pawns:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var rk: int = wm.call("_region_key", tile.x, tile.y)
		pawn_region[int(_jk(pd, "id", -1))] = rk

	for i in range(all_settlements.size()):
		if not (all_settlements[i] is Dictionary):
			continue
		var st: Dictionary = all_settlements[i]
		var ck: int = int(st.get("center_region", -1))
		var reason: String = str(st.get("guild_candidate_reason", "UNSET"))
		var formal_flag: bool = bool(st.get("is_formal_settlement", false))
		var regs: PackedInt32Array = st.get("regions", PackedInt32Array())
		# Actual living pawns inside this settlement's regions.
		var inside: Array = []
		for pid in pawn_region.keys():
			if regs.has(int(pawn_region[pid])):
				inside.append(pid)
		inside.sort()
		# Pawns whose data.settlement_id == this ARRAY INDEX (what _maybe_update_settlement_membership writes).
		var refs: Array = []
		for p in pawns:
			if not is_instance_valid(p):
				continue
			var pd = p.get("data")
			if pd == null:
				continue
			if int(_jk(pd, "settlement_id", -1)) == i:
				refs.append(int(_jk(pd, "id", -1)))
		refs.sort()
		var members_v: Variant = st.get("member_pawn_ids", null)
		var member_ids: Array = []
		if members_v is PackedInt32Array:
			for m in members_v:
				member_ids.append(int(m))
		var contract_error: String = ""
		if not refs.is_empty() and member_ids.is_empty() and not formal_flag:
			contract_error = "CONTRACT_ERROR(refs=%s but member_ids empty)" % str(refs)
		var cx: int = ck & 0xFFFF
		var cy: int = (ck >> 16) & 0xFFFF
		print("SETTLE_AUDIT: st[%d] center=(%d,%d)rk=%d kind=%s formal=%s pop=%d guild_members=%d stability=%d reason=%s founding_reason=%s founding_tick=%d inside=%s pawn_refs=%s %s" % [
			i, cx, cy, ck, str(st.get("settlement_kind", "?")), str(formal_flag),
			int(st.get("population", 0)), member_ids.size(), int(st.get("guild_candidate_stability_ticks", 0)),
			reason, str(st.get("founding_reason", "")), int(st.get("founding_tick", -1)),
			str(inside), str(refs), contract_error])

	print("SETTLE_AUDIT: guild_foundation_state keys=%d" % (sm.get("_guild_foundation_state").size() if sm.get("_guild_foundation_state") != null else -1))
	var gs: Dictionary = sm.get("_guild_foundation_state") if sm.get("_guild_foundation_state") is Dictionary else {}
	for k in gs.keys():
		var e: Dictionary = gs[k]
		print("SETTLE_AUDIT: guild_state rk=%d since=%d formal=%s members=%s" % [
			int(k), int(_jk(e, "since_tick", -1)), str(_jk(e, "formal", false)), str(_jk(e, "last_members", []))])

	print("SETTLE_AUDIT: publicity formal=%d proto=%d reasons=%s" % [formal.size(), protos.size(), str(_proto_reasons(protos))])

	# Pawn-side membership snapshot.
	print("SETTLE_AUDIT: pawn settlement_id distribution:")
	var sid_dist: Dictionary = {}
	for p in pawns:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var sid: int = int(_jk(pd, "settlement_id", -1))
		sid_dist[sid] = int(sid_dist.get(sid, 0)) + 1
	print("SETTLE_AUDIT: %s" % str(sid_dist))

	# ---- 01D/P1: F10 mid-world spatial-truth proof with REAL centers ----
	# The snapshot must decode every settlement/proto center_region (an encoded
	# region key) into an in-bounds representative tile, never a bogus flat index.
	print("--- F10 mid-world spatial truth (real settlement/proto centers) ---")
	var menu: Node = _main.get_node_or_null("CreatorDebugMenu") if _main != null else null
	if menu == null or not menu.has_method("_build_ai_snapshot_dict"):
		print("SETTLE_AUDIT: F10 menu unavailable; skipping spatial-truth proof")
	else:
		var snap: Variant = menu.call("_build_ai_snapshot_dict")
		if not (snap is Dictionary):
			print("SETTLE_AUDIT: F10 snapshot build returned non-Dictionary; spatial-truth proof FAILED")
		else:
			var spatial: Dictionary = (snap as Dictionary).get("spatial", {})
			var world_d: Dictionary = spatial.get("world", {})
			var wx: int = int(world_d.get("width", 256))
			var wy: int = int(world_d.get("height", 256))
			var pairs: Array = [
				["Settlement Centers", spatial.get("settlement_centers", [])],
				["Proto Site Centers", spatial.get("proto_centers", [])],
			]
			var verified := 0
			var failed := 0
			for pair in pairs:
				var label: String = str(pair[0])
				var arr: Variant = pair[1]
				if not (arr is Array):
					print("SETTLE_AUDIT: %s not an Array -> FAIL" % label)
					failed += 1
					continue
				for c in (arr as Array):
					if not (c is Dictionary):
						print("SETTLE_AUDIT: %s non-dictionary entry -> FAIL" % label)
						failed += 1
						continue
					var rk: int = int(c.get("center_region_key", -1))
					var coord: Variant = c.get("center_region_coord", Vector2i(-1, -1))
					var avail: bool = bool(c.get("center_tile_available", false))
					var tile: Variant = c.get("center_tile", Vector2i(-1, -1))
					var ok: bool = false
					if coord is Vector2i and tile is Vector2i:
						var exp: Vector2i = Vector2i((coord as Vector2i).x * 16 + 8, (coord as Vector2i).y * 16 + 8)
						ok = rk >= 0 and avail and (tile as Vector2i) == exp and (tile as Vector2i).x >= 0 and (tile as Vector2i).y >= 0 and (tile as Vector2i).x < wx and (tile as Vector2i).y < wy
						print("SETTLE_AUDIT: %s '%s' rk=%d region=%s tile=%s expected=%s %s" % [
							label, str(c.get("name", "?")), rk, str(coord), str(tile), str(exp), "OK" if ok else "FAIL"])
					else:
						print("SETTLE_AUDIT: %s '%s' missing Vector2i fields -> FAIL" % [label, str(c.get("name", "?"))])
					if ok:
						verified += 1
					else:
						failed += 1
			print("SETTLE_AUDIT: F10 mid-world centers verified=%d failed=%d (world=%dx%d)" % [verified, failed, wx, wy])
			if menu.has_method("_get_world_section"):
				print("SETTLE_AUDIT: [WORLD SECTION]\n%s" % str(menu.call("_get_world_section", snap)))
			if menu.has_method("_get_settlements_section"):
				print("SETTLE_AUDIT: [SETTLEMENTS SECTION]\n%s" % str(menu.call("_get_settlements_section", snap)))
	print("=== SETTLEMENT_GATE_AUDIT done ===")