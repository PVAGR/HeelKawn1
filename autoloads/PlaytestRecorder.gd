extends Node
## PlaytestRecorder — AUTOMATED PLAYTEST RECORDING SYSTEM
##
## Records EVERYTHING from game boot to close:
## - All game events (tick-by-tick)
## - All pawn actions and state changes
## - All UI interactions (button clicks, selections)
## - All errors and warnings
## - Performance metrics (FPS, memory, tick timing)
## - Player actions (mouse clicks, key presses, camera movement)
## - Settlement changes, job completions, births, deaths
## - Knowledge changes, grudge formation, gossip spread
##
## Output: JSON report saved to logs/playtest/YYYY-MM-DD-HHMMSS_playtest.json
## Also saves replay file for deterministic replay debugging

# Configuration
const OUTPUT_DIR: String = "user://logs/playtest/"
const MAX_RECORDS_PER_SESSION: int = 100000  # Prevent memory explosion
const PERFORMANCE_SAMPLE_INTERVAL: int = 60  # Sample FPS every 60 ticks
# Auto-save intervals scale with game progress:
# Early game (few events): save less often. Mid/late game: save more often.
# The interval is based on WorldMemory event count, not fixed tick intervals.
const AUTO_SAVE_MIN_INTERVAL: int = 500    # Never save more often than 500 ticks
const AUTO_SAVE_MAX_INTERVAL: int = 5000   # Never wait longer than 5000 ticks
var _auto_save_interval_index: int = 0

# Recording state
var is_recording: bool = false
var session_id: String = ""
var session_start_tick: int = 0
var session_start_time: String = ""
var records: Array[Dictionary] = []
var performance_samples: Array[Dictionary] = []
var _record_count: int = 0
var _last_auto_save_tick: int = 0
var _next_auto_save_tick: int = 0
var _fps_history: Array[float] = []

# Performance tracking
var _last_frame_time: float = 0.0
var _tick_durations: Array[float] = []
var _peak_tick_duration: float = 0.0
var _total_tick_time: float = 0.0

# Error tracking
var errors_encountered: Array[Dictionary] = []
var warnings_encountered: Array[Dictionary] = []

# Signals for external systems to log events
signal event_recorded(event_type: String, data: Dictionary)


func _ready() -> void:
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	
	# Start recording immediately on game boot
	start_recording()
	
	# Connect to game events
	_connect_to_game_events()
	
	# Start performance monitoring
	set_process(true)


func _connect_to_game_events() -> void:
	# Connect to GameManager for speed changes, pauses
	if GameManager != null:
		GameManager.speed_changed.connect(_on_game_speed_changed)
	
	# Connect to WorldMemory for all world events
	if WorldMemory != null and WorldMemory.has_signal("event_appended"):
		WorldMemory.event_appended.connect(_on_world_event)
	
	# Connect to TickManager for tick timing
	if TickManager != null and TickManager.has_signal("tick_processed"):
		TickManager.tick_processed.connect(_on_tick_processed)
	
	# Connect to JobManager for job events
	if JobManager != null:
		if JobManager.has_signal("job_posted"):
			JobManager.job_posted.connect(_on_job_posted)
		if JobManager.has_signal("job_claimed"):
			JobManager.job_claimed.connect(_on_job_claimed)
		if JobManager.has_signal("job_completed"):
			JobManager.job_completed.connect(_on_job_completed)
	
	# Connect to PawnSpawner for pawn events
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null:
		# Monitor pawn spawns/deaths via WorldMemory instead
		pass
	
	# Connect to SettlementMemory for settlement events
	if SettlementMemory != null and SettlementMemory.has_signal("settlement_founded"):
		SettlementMemory.settlement_founded.connect(_on_settlement_founded)


func _process(_delta: float) -> void:
	if not is_recording:
		return
	
	# Sample performance metrics
	if GameManager != null and GameManager.tick_count % PERFORMANCE_SAMPLE_INTERVAL == 0:
		_sample_performance()
	
	# Auto-save at varied tick intervals (100, 500, 1000, 1500)
	if GameManager != null and GameManager.tick_count >= _next_auto_save_tick:
		_auto_save_records()
		_last_auto_save_tick = GameManager.tick_count
		_next_auto_save_tick = GameManager.tick_count + _get_next_auto_save_interval()


func _sample_performance() -> void:
	var current_fps: float = Engine.get_frames_per_second()
	_fps_history.append(current_fps)
	if _fps_history.size() > 60:
		_fps_history.pop_front()
	
	var avg_fps: float = 0.0
	if not _fps_history.is_empty():
		avg_fps = _fps_history.reduce(func(a, b): return a + b) / float(_fps_history.size())
	
	var memory_usage: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	performance_samples.append({
		"tick": GameManager.tick_count if GameManager != null else 0,
		"fps": current_fps,
		"avg_fps": avg_fps,
		"memory_mb": float(memory_usage) / 1048576.0,
		"peak_tick_ms": _peak_tick_duration * 1000.0,
		"avg_tick_ms": (_total_tick_time / maxf(1.0, float(_tick_durations.size()))) * 1000.0,
		"timestamp": Time.get_datetime_string_from_system()
	})
	
	# Reset tick tracking
	_peak_tick_duration = 0.0
	_tick_durations.clear()


func _on_tick_processed(tick: int) -> void:
	if not is_recording:
		return
	
	# Record tick processing (sample every 10th tick to reduce overhead)
	if tick % 10 == 0:
		_record_event("tick", {
			"tick": tick,
			"game_speed": GameManager.game_speed if GameManager != null else 1.0,
			"is_paused": GameManager.is_paused if GameManager != null else false
		})


func _on_world_event(event: Dictionary) -> void:
	if not is_recording:
		return
	
	# Record all world events
	_record_event("world_event", {
		"event_type": event.get("type", "unknown"),
		"tick": event.get("tick", 0),
		"data": event.duplicate(true)
	})


func _on_job_posted(job: Object) -> void:
	if not is_recording or job == null:
		return

	var job_data: Dictionary = {}
	if job.has_method("to_dict"):
		job_data = job.call("to_dict")
	else:
		# Safe access for RefCounted Job object
		var job_type: Variant = -1
		var work_tile: Variant = Vector2i.ZERO
		var priority: Variant = 0
		
		if job.has_method("get"):
			job_type = job.call("get", "type")
			work_tile = job.call("get", "work_tile")
			priority = job.call("get", "priority")
		
		job_data = {
			"type": str(job_type if job_type != null else -1),
			"work_tile": str(work_tile if work_tile != null else Vector2i.ZERO),
			"priority": priority if priority != null else 0
		}

	_record_event("job_posted", job_data)


func _on_job_claimed(job: Object, pawn: Node) -> void:
	if not is_recording or job == null or pawn == null:
		return

	var pawn_id: int = -1
	if pawn.has_method("get_pawn_data"):
		var pd = pawn.call("get_pawn_data")
		if pd != null:
			pawn_id = int(pd.id)

	# Safe access for RefCounted Job object
	var job_type: Variant = -1
	if job.has_method("get"):
		job_type = job.call("get", "type")
	elif "type" in job:
		job_type = job.type

	_record_event("job_claimed", {
		"job_type": str(job_type if job_type != null else -1),
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func _on_job_completed(job: Object) -> void:
	if not is_recording or job == null:
		return

	# Safe access for RefCounted Job object
	var job_type: Variant = -1
	if job.has_method("get"):
		job_type = job.call("get", "type")
	elif "type" in job:
		job_type = job.type

	_record_event("job_completed", {
		"job_type": str(job_type if job_type != null else -1),
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func _on_game_speed_changed(new_speed: float, _is_paused: bool = false) -> void:
	_record_event("speed_change", {
		"old_speed": records[-1].get("game_speed", 1.0) if not records.is_empty() else 1.0,
		"new_speed": new_speed,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func _on_settlement_founded(settlement_id: int, tile: Vector2i, culture_name: String) -> void:
	_record_event("settlement_founded", {
		"settlement_id": settlement_id,
		"tile": {"x": tile.x, "y": tile.y},
		"culture_name": culture_name,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func _record_event(event_type: String, data: Dictionary) -> void:
	if _record_count >= MAX_RECORDS_PER_SESSION:
		push_warning("[PlaytestRecorder] Max records reached, stopping recording")
		stop_recording()
		return
	
	var record: Dictionary = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"timestamp": Time.get_ticks_msec(),
		"event_type": event_type,
		"data": data
	}
	
	records.append(record)
	_record_count += 1
	
	event_recorded.emit(event_type, data)


func start_recording() -> void:
	if is_recording:
		return
	
	session_id = _generate_session_id()
	session_start_tick = GameManager.tick_count if GameManager != null else 0
	session_start_time = Time.get_datetime_string_from_system()
	is_recording = true
	records.clear()
	performance_samples.clear()
	errors_encountered.clear()
	warnings_encountered.clear()
	_record_count = 0
	_last_auto_save_tick = session_start_tick
	_next_auto_save_tick = session_start_tick + AUTO_SAVE_MAX_INTERVAL
	_auto_save_interval_index = 0
	
	_record_event("session_start", {
		"session_id": session_id,
		"start_tick": session_start_tick,
		"start_time": session_start_time,
		"godot_version": Engine.get_version_info()["string"],
		"project_name": ProjectSettings.get_setting("application/config/name", "HeelKawn")
	})
	
	print("[PlaytestRecorder] Started recording session %s" % session_id)


func _get_next_auto_save_interval() -> int:
	# Scale interval with game progress (event count).
	# First 100 events → 5000 ticks between saves
	# 100-500 events → 3000 ticks
	# 500-1000 events → 2000 ticks
	# 1000+ events → 1000 ticks
	# At high speed (50x+), further reduce frequency.
	var event_count: int = 0
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("event_count"):
		event_count = wm.event_count()
	var interval: int
	if event_count < 100:
		interval = 5000
	elif event_count < 500:
		interval = 3000
	elif event_count < 1000:
		interval = 2000
	else:
		interval = 1000
	return maxi(AUTO_SAVE_MIN_INTERVAL, mini(AUTO_SAVE_MAX_INTERVAL, interval))


func stop_recording() -> void:
	if not is_recording:
		return
	
	is_recording = false
	
	_record_event("session_end", {
		"session_id": session_id,
		"end_tick": GameManager.tick_count if GameManager != null else 0,
		"end_time": Time.get_datetime_string_from_system(),
		"total_records": _record_count,
		"performance_samples": performance_samples.size(),
		"errors": errors_encountered.size(),
		"warnings": warnings_encountered.size()
	})
	
	# Save final report
	_save_playtest_report()
	
	print("[PlaytestRecorder] Stopped recording. Saved to %s" % _get_output_filename())


func _generate_session_id() -> String:
	return Time.get_date_string_from_system().replace("-", "") + "_" + Time.get_time_string_from_system().replace(":", "").replace(".", "")


func _get_output_filename() -> String:
	return OUTPUT_DIR + session_id + "_playtest.json"


func _save_playtest_report() -> void:
	var report: Dictionary = {
		"session_id": session_id,
		"session_start_time": session_start_time,
		"session_end_time": Time.get_datetime_string_from_system(),
		"start_tick": session_start_tick,
		"end_tick": GameManager.tick_count if GameManager != null else 0,
		"total_ticks": (GameManager.tick_count if GameManager != null else 0) - session_start_tick,
		"total_records": _record_count,
		"performance_samples": performance_samples,
		"errors": errors_encountered,
		"warnings": warnings_encountered,
		"records": records
	}
	
	var file: FileAccess = FileAccess.open(_get_output_filename(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("[PlaytestRecorder] Report saved: %s (%.2f MB)" % [_get_output_filename(), float(FileAccess.get_file_as_bytes(_get_output_filename()).size()) / 1048576.0])
	else:
		push_error("[PlaytestRecorder] Failed to save report: %s" % _get_output_filename())


func _auto_save_records() -> void:
	if records.is_empty():
		return
	
	# Save incremental backup
	var backup_file: String = OUTPUT_DIR + session_id + "_backup_tick_%d.json" % _last_auto_save_tick
	var file: FileAccess = FileAccess.open(backup_file, FileAccess.WRITE)
	if file != null:
		var backup_data: Dictionary = {
			"session_id": session_id,
			"backup_tick": _last_auto_save_tick,
			"backup_time": Time.get_datetime_string_from_system(),
			"record_count": records.size(),
			"records": records,
			"performance_samples": performance_samples
		}
		file.store_string(JSON.stringify(backup_data, "  "))
		file.close()
		print("[PlaytestRecorder] Auto-saved backup at tick %d: %s (%.2f MB)" % [_last_auto_save_tick, backup_file, float(FileAccess.get_file_as_bytes(backup_file).size()) / 1048576.0])


func log_error(error_text: String, source: String = "") -> void:
	if not is_recording:
		return
	
	var error_record: Dictionary = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"timestamp": Time.get_ticks_msec(),
		"error": error_text,
		"source": source
	}
	
	errors_encountered.append(error_record)
	_record_event("error", error_record)


func log_warning(warning_text: String, source: String = "") -> void:
	if not is_recording:
		return
	
	var warning_record: Dictionary = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"timestamp": Time.get_ticks_msec(),
		"warning": warning_text,
		"source": source
	}
	
	warnings_encountered.append(warning_record)
	_record_event("warning", warning_record)


func log_player_action(action_type: String, data: Dictionary) -> void:
	if not is_recording:
		return
	
	_record_event("player_action", {
		"action_type": action_type,
		"data": data,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func get_session_summary() -> Dictionary:
	return {
		"session_id": session_id,
		"is_recording": is_recording,
		"start_time": session_start_time,
		"current_tick": GameManager.tick_count if GameManager != null else 0,
		"total_records": _record_count,
		"errors": errors_encountered.size(),
		"warnings": warnings_encountered.size(),
		"avg_fps": performance_samples[-1].get("avg_fps", 0.0) if not performance_samples.is_empty() else 0.0
	}

func record_pawn_selection(pawn_id: int, pawn_name: String, tile_pos: Vector2i) -> void:
	if not is_recording:
		return
	_record_event("pawn_selection", {
		"pawn_id": pawn_id,
		"pawn_name": pawn_name,
		"tile_x": tile_pos.x,
		"tile_y": tile_pos.y,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func record_camera_movement(camera_pos: Vector2, camera_zoom: float) -> void:
	if not is_recording:
		return
	_record_event("camera_movement", {
		"pos_x": camera_pos.x,
		"pos_y": camera_pos.y,
		"zoom": camera_zoom,
		"tick": GameManager.tick_count if GameManager != null else 0
	})