extends SceneTree

## Pathfinder + job diagnostic at tick 500.

var _main: Node = null
var _tick: int = 0
var _world_tick: int = 0
const TARGET_TICK: int = 500

func _init() -> void:
	pass

func _process(_delta: float) -> bool:
	_tick += 1
	if _tick == 5:
		_spawn_main()
	if _tick >= 10 and _main != null:
		var gm = _main.get_node_or_null("/root/GameManager")
		if gm != null:
			_world_tick = gm.tick_count
			if _world_tick >= TARGET_TICK:
				_diagnose()
				quit()
		if _tick > 2000:
			_diagnose()
			quit()
	return false

func _spawn_main() -> void:
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	if main_scene == null:
		print("[DIAG] FAIL: Main.tscn not found")
		quit()
		return
	_main = main_scene.instantiate()
	root.add_child(_main)
	# Speed up to 50x
	var gm = _main.get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set_speed(50.0)

func _diagnose() -> void:
	print("\n===== PATHFINDER + JOB DIAGNOSTIC (tick %d) =====" % _world_tick)

	var world: Node = _main.get_node_or_null("WorldViewport/World")
	if world == null:
		print("[DIAG] FAIL: World not found")
		return

	var pf = world.pathfinder
	var data = world.data
	if pf == null or data == null:
		print("[DIAG] FAIL: pathfinder or data null")
		return

	var largest_comp: int = pf.largest_component_id()
	print("[DIAG] largest_component_id = %d" % largest_comp)

	# Pawn connectivity
	var spawner: Node = _main.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner != null:
		var pawns = spawner.pawns
		var connected: int = 0
		var stranded: int = 0
		var idle_count: int = 0
		var working_count: int = 0
		var walking_count: int = 0
		var sleeping_count: int = 0
		var hungry_count: int = 0
		var dead_count: int = 0
		for p in pawns:
			if p == null or not is_instance_valid(p):
				continue
			if p.data != null and bool(p.data.is_dead):
				dead_count += 1
				continue
			var tile: Vector2i = world.world_to_tile(p.global_position)
			var cid: int = pf.component_of(tile)
			if cid == largest_comp:
				connected += 1
			else:
				stranded += 1
			if p.data != null:
				if p.data.hunger <= 20.0:
					hungry_count += 1
			var state: int = p.get_state()
			if state == 0: idle_count += 1
			elif state == 1: walking_count += 1
			elif state == 2: working_count += 1
			elif state == 6: sleeping_count += 1
		print("[DIAG] pawns: alive=%d connected=%d stranded=%d dead=%d" % [connected + stranded, connected, stranded, dead_count])
		print("[DIAG] states: idle=%d walking=%d working=%d sleeping=%d hungry=%d" % [idle_count, walking_count, working_count, sleeping_count, hungry_count])

	# Job stats
	var jm = _main.get_node_or_null("/root/JobManager")
	if jm != null and jm.has_method("stats"):
		var stats = jm.stats()
		print("[DIAG] JobManager: %s" % str(stats).left(300))

	# Stockpile
	var sm = _main.get_node_or_null("/root/StockpileManager")
	if sm != null:
		print("[DIAG] StockpileManager: total_food=%d total_wood=%d total_stone=%d" % [sm.total_food(), sm.total_count_of(1), sm.total_count_of(2)])

	print("===== END DIAGNOSTIC =====")
