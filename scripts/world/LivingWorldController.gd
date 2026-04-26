extends Node
class_name LivingWorldController

@export var initial_pawn_count := 6
@export var global_pressure_interval := 30.0

var world_seconds := 0.0
var _ticks_since_global_pressure: int = 0


func _ready() -> void:
	# After Main._ready bootstraps world + first pawn batch, add extra pawns.
	call_deferred("_spawn_initial_pawns")
	if not GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.connect(_on_game_tick)


func _exit_tree() -> void:
	if GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	world_seconds += GameManager.TICK_INTERVAL_SECONDS
	_ticks_since_global_pressure += 1
	var pressure_every_ticks: int = maxi(1, int(round(global_pressure_interval / GameManager.TICK_INTERVAL_SECONDS)))
	if _ticks_since_global_pressure >= pressure_every_ticks:
		_ticks_since_global_pressure = 0
		_apply_global_pressure()
	_apply_local_pressure()


func _apply_local_pressure() -> void:
	if not get_parent().has_node("WorldTrace"):
		return
	var world_trace: WorldTrace = get_parent().get_node("WorldTrace") as WorldTrace
	if world_trace == null:
		return
	for t in world_trace.traces:
		if t is Dictionary and t.get("kind", "") == "death" and float(t.get("age", 0.0)) < 120.0:
			GameManager.add_global_stress(1)


func _spawn_initial_pawns() -> void:
	if not get_parent().has_node("PawnSpawner"):
		if OS.is_debug_build():
			push_warning("LivingWorldController: PawnSpawner not found")
		return

	var spawner: PawnSpawner = get_parent().get_node("PawnSpawner") as PawnSpawner
	if spawner == null:
		return
	for i in range(initial_pawn_count):
		spawner.spawn_pawn()


func _apply_global_pressure() -> void:
	# The world should not stay stable.
	# Pressure is subtle but constant.
	GameManager.add_global_stress(5)
