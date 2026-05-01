extends Node
## HEELKAWN CORE: Deterministic Tick Manager
## Replaces frame-dependent _process() with a fixed-step accumulation loop.
## Ensures 1 tick = 1 logical update, regardless of FPS or lag spikes.

signal tick_processed(tick_number: int)
signal speed_changed(new_speed: float)
signal paused(is_paused: bool)

var current_tick: int = 0
var base_interval: float = 0.1  # 10 ticks per second at 1.0x speed
var speed_multiplier: float = 1.0
var accumulated_time: float = 0.0
var is_paused: bool = false

func _ready() -> void:
	add_to_group("tick_manager")
	print("[TickManager] Initialized. Base Interval: %fs" % base_interval)

func _process(delta: float) -> void:
	if is_paused:
		return
	
	accumulated_time += delta
	
	var target_interval = base_interval / speed_multiplier
	
	# Catch-up loop: processes multiple ticks if frame time was long
	while accumulated_time >= target_interval:
		process_tick()
		accumulated_time -= target_interval

func process_tick() -> void:
	current_tick += 1
	emit_signal("tick_processed", current_tick)
	
	# Optional: Debug print every 1000 ticks to verify continuity
	if current_tick % 1000 == 0:
		print("[TickManager] Tick %d reached. Real time elapsed: %.2fs" % [current_tick, get_real_time_seconds()])

func set_speed(speed: float) -> void:
	speed = max(0.1, min(64.0, speed)) # Clamp between 0.1x and 64x
	speed_multiplier = speed
	emit_signal("speed_changed", speed_multiplier)
	print("[TickManager] Speed set to %.1fx" % speed_multiplier)

func pause() -> void:
	if not is_paused:
		is_paused = true
		emit_signal("paused", true)
		print("[TickManager] Paused at tick %d" % current_tick)

func resume() -> void:
	if is_paused:
		is_paused = false
		emit_signal("paused", false)
		accumulated_time = 0.0 # Reset accumulator to prevent jump
		print("[TickManager] Resumed at tick %d" % current_tick)

func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()

func get_current_tick() -> int:
	return current_tick

func get_real_time_seconds() -> float:
	return float(current_tick) * base_interval

func get_ticks_per_second() -> float:
	return 1.0 / base_interval * speed_multiplier
