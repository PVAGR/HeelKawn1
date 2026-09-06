extends SceneTree
const SAVE_PATH := "user://heelkawn_colony_autosave.sav"
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("need fence")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")):
		push_error("fence not active")
		quit(1)

func _process(_d: float) -> bool:
	if _printed:
		return false
	if _gm == null:
		_gm = _al("GameManager")
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_pawn_spawner") == null:
			return false
		# Wait for starter pawns to spawn (Main _ready spawns them)
		var spawner: Node = _main.get("_pawn_spawner")
		var pawns: Array = spawner.get("pawns") if spawner != null else []
		if pawns.is_empty():
			return false
		print("PHASE boot: starter pawns before load=%d" % pawns.size())
		for p in pawns.slice(0, 5):
			if p != null and is_instance_valid(p):
				var pd = p.get("data")
				if pd != null:
					print("  starter id=%d name=%s tile=%s" % [int(pd.get("id")), str(pd.get("display_name")), str(pd.get("tile_pos"))])
		_phase = "load"
		_do_load()
		return false
	if _phase == "load":
		# wait a frame after load
		_phase = "dump"
		return false
	if _phase == "dump":
		_do_dump()
		_printed = true
		quit(0)
	return false

func _do_load() -> void:
	var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
	var d: Dictionary = gs.call("read_file", SAVE_PATH)
	if d.is_empty():
		print("save empty")
		return
	var pawns_save: Array = d.get("pawns", [])
	print("SAVE FILE: pawn_entry_count=%d" % pawns_save.size())
	var id_counts: Dictionary = {}
	var id_to_names: Dictionary = {}
	var id_to_tiles: Dictionary = {}
	for entry in pawns_save:
		if not (entry is Dictionary):
			continue
		var pid: int = int(entry.get("id", -1))
		id_counts[pid] = int(id_counts.get(pid, 0)) + 1
		if not id_to_names.has(pid):
			id_to_names[pid] = []
		id_to_names[pid].append(str(entry.get("display_name", "?")))
		id_to_tiles[pid] = str(entry.get("tile_pos", entry.get("tile", "?")))
	var dups: Array = []
	for pid in id_counts.keys():
		if int(id_counts[pid]) > 1:
			dups.append(pid)
	print("SAVE duplicate IDs: %d" % dups.size())
	for pid in dups.slice(0, 10):
		print("  dup id=%d count=%d names=%s tiles=%s" % [pid, int(id_counts[pid]), str(id_to_names[pid]), str(id_to_tiles[pid])])
	if dups.is_empty():
		print("SAVE no duplicate stable IDs — save itself is clean")
	else:
		print("SAVE CONTAINS DUPLICATE IDs — save corruption")
	# Now apply
	print("Applying save via _apply_save_dict...")
	_main.call("_apply_save_dict", d)
	var gm_tick: int = int(_gm.get("tick_count"))
	var tm: Node = _al("TickManager")
	var tm_tick: int = int(tm.get("current_tick")) if tm != null else -1
	print("After _apply_save_dict gm_tick=%d tm_tick=%d" % [gm_tick, tm_tick])

func _do_dump() -> void:
	print("=== AFTER LOAD DUMP ===")
	var spawner: Node = _main.get("_pawn_spawner")
	var pawns: Array = spawner.get("pawns") if spawner != null else []
	print("spawner pawns count=%d" % pawns.size())
	var pa: Node = _al("PawnAccess")
	var alive: Array = pa.call("find_alive_pawns") if pa != null and pa.has_method("find_alive_pawns") else []
	print("PawnAccess alive count=%d" % alive.size())
	# Check via group
	var grp: Array = get_nodes_in_group("pawns")
	print("group pawns count=%d" % grp.size())
	# Map id -> list
	var id_to_nodes: Dictionary = {}
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(pd.get("id"))
		if not id_to_nodes.has(pid):
			id_to_nodes[pid] = []
		id_to_nodes[pid].append(p)
	var dup_ids: Array = []
	for pid in id_to_nodes.keys():
		if (id_to_nodes[pid] as Array).size() > 1:
			dup_ids.append(pid)
	print("spawner duplicate IDs: %d" % dup_ids.size())
	for pid in dup_ids.slice(0, 10):
		var lst: Array = id_to_nodes[pid]
		var names: Array = []
		var tiles: Array = []
		for n in lst:
			var pd = n.get("data")
			names.append(str(pd.get("display_name")))
			tiles.append(str(pd.get("tile_pos")))
		print("  dup id=%d count=%d names=%s tiles=%s" % [pid, lst.size(), str(names), str(tiles)])
	if dup_ids.is_empty():
		print("NO duplicate IDs in spawner after load — load faithful")
	else:
		print("DUPLICATE IDs in scene after load — harness or game load bug")
	# Also check alive duplicates
	var alive_ids: Dictionary = {}
	var alive_dups: Array = []
	for p in alive:
		if p == null or not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(pd.get("id"))
		alive_ids[pid] = int(alive_ids.get(pid, 0)) + 1
	for pid in alive_ids.keys():
		if int(alive_ids[pid]) > 1:
			alive_dups.append(pid)
	print("alive duplicate IDs: %d" % alive_dups.size())
	for pid in alive_dups.slice(0, 5):
		print("  alive dup id=%d count=%d" % [pid, int(alive_ids[pid])])
	# Check stable ID allocator
	var next_id: int = -1
	if _main != null and _main.get("_pawn_spawner") != null:
		var sp2: Node = _main.get("_pawn_spawner")
		if sp2.get("_next_pawn_id") != null:
			next_id = int(sp2.get("_next_pawn_id"))
		elif sp2.get("_next_id") != null:
			next_id = int(sp2.get("_next_id"))
	print("next pawn id allocator=%d max_id_in_save=%d" % [next_id, _max_id_in_save()])
	# Check settlement assignment
	for p in pawns.slice(0, 5):
		if p == null:
			continue
		var pd = p.get("data")
		print("  sample pawn id=%d name=%s sid=%d tile=%s" % [int(pd.get("id")), str(pd.get("display_name")), int(pd.get("settlement_id")), str(pd.get("tile_pos"))])

func _max_id_in_save() -> int:
	var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
	var d: Dictionary = gs.call("read_file", SAVE_PATH)
	var pawns_save: Array = d.get("pawns", [])
	var max_id: int = -1
	for entry in pawns_save:
		if entry is Dictionary:
			max_id = maxi(max_id, int(entry.get("id", -1)))
	return max_id
