class_name TimeLapseRecorder
extends Node

const MAX_SNAPSHOTS: int = 100
const PLAYBACK_SPEED_MULTIPLIER: float = 10.0

enum Mode {
	IDLE,
	RECORDING,
	PLAYBACK,
}

signal mode_changed(mode_name: String)
signal snapshot_changed(snapshot: Dictionary)

var _world: World = null
var _pawn_spawner: PawnSpawner = null
var _camera: Camera2D = null
var _snapshots: Array[Dictionary] = []
var _mode: Mode = Mode.IDLE
var _playback_index: int = 0
var _playback_accum: float = 0.0
var _paused_before_playback: bool = false
var _last_recorded_tick: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_game_tick)


func bind_context(world_ref: World, pawn_spawner_ref: PawnSpawner, camera_ref: Camera2D = null) -> void:
	_world = world_ref
	_pawn_spawner = pawn_spawner_ref
	_camera = camera_ref


func clear() -> void:
	_snapshots.clear()
	_playback_index = 0
	_playback_accum = 0.0
	_last_recorded_tick = -1


func reset_session() -> void:
	clear()
	_mode = Mode.IDLE
	mode_changed.emit(_mode_name())


func record() -> void:
	clear()
	_mode = Mode.RECORDING
	mode_changed.emit(_mode_name())


func playback() -> void:
	if _snapshots.is_empty():
		return
	_mode = Mode.PLAYBACK
	_playback_index = 0
	_playback_accum = 0.0
	_paused_before_playback = GameManager.is_paused if has_node("/root/GameManager") else false
	if has_node("/root/GameManager") and not GameManager.is_paused:
		GameManager.pause()
	mode_changed.emit(_mode_name())
	_apply_snapshot(_snapshots[_playback_index])


func stop() -> void:
	var should_unpause: bool = _mode == Mode.PLAYBACK and not _paused_before_playback
	_mode = Mode.IDLE
	if should_unpause and has_node("/root/GameManager") and GameManager.is_paused:
		GameManager.unpause()
	mode_changed.emit(_mode_name())


func toggle_mode() -> void:
	match _mode:
		Mode.IDLE:
			record()
		Mode.RECORDING:
			playback()
		Mode.PLAYBACK:
			stop()


func get_mode() -> Mode:
	return _mode


func get_snapshots() -> Array[Dictionary]:
	return _snapshots.duplicate(true)


func get_current_snapshot() -> Dictionary:
	if _mode == Mode.PLAYBACK and not _snapshots.is_empty():
		return _snapshots[clampi(_playback_index, 0, _snapshots.size() - 1)]
	if _snapshots.is_empty():
		return {}
	return _snapshots[_snapshots.size() - 1]


func _on_game_tick(tick: int) -> void:
	if _mode != Mode.RECORDING:
		return
	if tick == _last_recorded_tick:
		return
	_capture_snapshot(tick)
	_last_recorded_tick = tick


func _process(delta: float) -> void:
	if _mode != Mode.PLAYBACK or _snapshots.is_empty():
		return
	_playback_accum += delta * PLAYBACK_SPEED_MULTIPLIER
	if _playback_accum < 1.0:
		return
	var steps: int = int(floor(_playback_accum))
	_playback_accum -= float(steps)
	for _i in range(steps):
		_playback_index += 1
		if _playback_index >= _snapshots.size():
			_playback_index = 0
		var snapshot: Dictionary = _snapshots[_playback_index]
		_apply_snapshot(snapshot)


func _capture_snapshot(tick: int) -> void:
	if _world == null or _pawn_spawner == null:
		return
	var valid_pawns: int = 0
	var pawn_positions: Array[Dictionary] = []
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		valid_pawns += 1
		var tile_pos: Vector2i = pawn.data.tile_pos if "tile_pos" in pawn.data else Vector2i.ZERO
		pawn_positions.append({
			"pawn_id": int(pawn.data.id),
			"tile": tile_pos,
		})
	var building_count: int = 0
	if WorldMemory != null and WorldMemory.has_method("get_event_type_counts"):
		var counts: Dictionary = WorldMemory.get_event_type_counts()
		building_count = maxi(0, int(counts.get("building_constructed", 0)) - int(counts.get("building_destroyed", 0)))
	var snapshot: Dictionary = {
		"tick": tick,
		"population": valid_pawns,
		"building_count": building_count,
		"pawn_positions": pawn_positions,
		"world_seed": WorldRNG.current_seed() if WorldRNG != null else 0,
	}
	if _camera != null and is_instance_valid(_camera):
		snapshot["camera_position"] = _camera.global_position
		snapshot["camera_zoom"] = _camera.zoom
	_snapshots.append(snapshot)
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()
	snapshot_changed.emit(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if has_node("/root/GameManager"):
		GameManager.tick_count = int(snapshot.get("tick", GameManager.tick_count))
	if _camera != null and is_instance_valid(_camera) and snapshot.has("camera_position"):
		_camera.global_position = snapshot.get("camera_position", _camera.global_position)
		if snapshot.has("camera_zoom"):
			_camera.zoom = snapshot.get("camera_zoom", _camera.zoom)
	snapshot_changed.emit(snapshot)


func _mode_name() -> String:
	match _mode:
		Mode.IDLE:
			return "idle"
		Mode.RECORDING:
			return "recording"
		Mode.PLAYBACK:
			return "playback"
		_:
			return "idle"
