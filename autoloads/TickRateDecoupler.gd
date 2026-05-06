extends Node
## TickRateDecoupler - Asynchronous system updates for performance
##
## Not all systems need to run every frame. This system manages update
## frequencies for different game systems to reduce CPU load.
##
## Usage:
##   TickRateDecoupler.register_system("AI", 5)  # Update every 5 ticks
##   TickRateDecoupler.register_system("Physics", 1)  # Every tick
##   TickRateDecoupler.should_update("AI")  # Check if should update this frame

# System registration: name -> update interval (in ticks)
var system_intervals: Dictionary = {}
var system_counters: Dictionary = {}

# Performance tracking
var stats: Dictionary = {
	"total_systems": 0,
	"updates_this_frame": 0,
	"updates_skipped_this_frame": 0,
	"total_updates": 0,
	"total_skipped": 0
}

# Global tick counter
var _global_tick: int = 0


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	
	# Register default systems
	_register_default_systems()


func _register_default_systems() -> void:
	# High priority (every tick)
	register_system("Input", 1)
	register_system("Camera", 1)
	register_system("UI", 1)
	
	# Medium priority (every 2-3 ticks)
	register_system("Physics", 2)
	register_system("Pathfinding", 2)
	
	# Low priority (every 5-10 ticks)
	register_system("AI", 5)
	register_system("Economy", 5)
	register_system("Social", 5)
	
	# Very low priority (every 10-20 ticks)
	register_system("Weather", 10)
	register_system("Foliage", 10)
	register_system("AmbientAudio", 10)
	
	# Background (every 30-60 ticks)
	register_system("MemoryCleanup", 60)
	register_system("StatsCollection", 60)


func _on_game_tick(tick: int) -> void:
	_global_tick = tick
	stats.updates_this_frame = 0
	stats.updates_skipped_this_frame = 0
	
	# Update counters for all systems
	for system_name in system_intervals:
		system_counters[system_name] = system_counters.get(system_name, 0) + 1


## Register a system with update interval
func register_system(system_name: String, update_interval: int) -> void:
	if update_interval < 1:
		update_interval = 1
	
	system_intervals[system_name] = update_interval
	system_counters[system_name] = 0
	stats.total_systems += 1
	
	if OS.is_debug_build():
		print("[TickDecoupler] Registered system: %s (interval: %d ticks)" % [
			system_name, update_interval
		])


## Check if a system should update this frame
func should_update(system_name: String) -> bool:
	if not system_intervals.has(system_name):
		return true  # Unknown systems update every tick
	
	var interval: int = system_intervals[system_name]
	var counter: int = system_counters.get(system_name, 0)
	
	if counter >= interval:
		# Reset counter and allow update
		system_counters[system_name] = 0
		stats.updates_this_frame += 1
		stats.total_updates += 1
		return true
	else:
		# Skip update this frame
		system_counters[system_name] = counter
		stats.updates_skipped_this_frame += 1
		stats.total_skipped += 1
		return false


## Force update a system this frame (regardless of interval)
func force_update(system_name: String) -> void:
	system_counters[system_name] = system_intervals.get(system_name, 1)


## Get update interval for a system
func get_interval(system_name: String) -> int:
	return system_intervals.get(system_name, 1)


## Set update interval for a system
func set_interval(system_name: String, interval: int) -> void:
	if interval < 1:
		interval = 1
	system_intervals[system_name] = interval


## Get statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Get system-specific statistics
func get_system_stats(system_name: String) -> Dictionary:
	if not system_intervals.has(system_name):
		return {}
	
	var interval: int = system_intervals[system_name]
	var counter: int = system_counters.get(system_name, 0)
	
	return {
		"interval": interval,
		"counter": counter,
		"progress": float(counter) / float(interval) * 100.0,
		"next_update_in": interval - counter
	}


## Debug: Print all system statistics
func debug_print_stats() -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== TICK DECOUPLER STATISTICS ===")
	print("Total Systems: %d" % stats.total_systems)
	print("Updates This Frame: %d" % stats.updates_this_frame)
	print("Skipped This Frame: %d" % stats.updates_skipped_this_frame)
	print("Total Updates: %d" % stats.total_updates)
	print("Total Skipped: %d" % stats.total_skipped)
	
	if stats.total_updates + stats.total_skipped > 0:
		var efficiency: float = float(stats.total_skipped) / float(stats.total_updates + stats.total_skipped) * 100.0
		print("CPU Savings: %.1f%% (from skipped updates)" % efficiency)
	
	print("\nPer-System Status:")
	for system_name in system_intervals:
		var ss: Dictionary = get_system_stats(system_name)
		print("  %s: %d/%d ticks (%.1f%%) - next in %d ticks" % [
			system_name,
			ss.counter,
			ss.interval,
			ss.progress,
			ss.next_update_in
		])
	print("=== END STATISTICS ===\n")


## Get recommended interval for a system type
static func get_recommended_interval(system_type: String) -> int:
	match system_type:
		"critical":  # Input, camera, UI
			return 1
		"high":  # Physics, pathfinding
			return 2
		"medium":  # AI, economy, social
			return 5
		"low":  # Weather, foliage, audio
			return 10
		"background":  # Cleanup, stats
			return 60
		_:
			return 5  # Default
