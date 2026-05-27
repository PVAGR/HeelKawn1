extends Node
class_name ConstructionVisualizer

## Event bridge between deterministic job completion and the visual layer.
## This node never mutates simulation state. It simply forwards build events
## to the renderer so completed structures become visible immediately.

var _world: World = null
var _camera: Camera2D = null
var _renderer: StructureRenderer = null
var _last_sync_tick: int = -999999


func initialize(world_ref: World, camera_ref: Camera2D, renderer_ref: StructureRenderer) -> void:
	_world = world_ref
	_camera = camera_ref
	_renderer = renderer_ref
	set_process(true)
	_connect_signals()
	_sync_renderer_from_world()


func _connect_signals() -> void:
	if JobManager != null and JobManager.has_signal("job_completed") and not JobManager.job_completed.is_connected(_on_job_completed):
		JobManager.job_completed.connect(_on_job_completed)


func _process(_delta: float) -> void:
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if tick_now - _last_sync_tick >= 90:
		_sync_renderer_from_world()


func _on_job_completed(job: Job) -> void:
	if _renderer == null or job == null:
		return
	_renderer.notify_completed_job(job)


func _sync_renderer_from_world() -> void:
	if _renderer == null:
		return
	_renderer.sync_from_world()
	_last_sync_tick = GameManager.tick_count if GameManager != null else _last_sync_tick
