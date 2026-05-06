extends Node
## EventBus - Centralized event dispatching system (Observer Pattern)
##
## Decouples systems by allowing them to communicate through events
## instead of direct references. Systems subscribe to events they care
## about and react asynchronously.
##
## Usage:
##   EventBus.connect("weather_changed", self, "_on_weather_changed")
##   EventBus.emit("weather_changed", {"weather": "rain", "intensity": 0.8})
##   EventBus.disconnect("weather_changed", self, "_on_weather_changed")

# Event subscriptions: event_name -> Array of {object, callback}
var subscriptions: Dictionary = {}

# Event history (for late subscribers)
var event_history: Dictionary = {}
const MAX_HISTORY_SIZE: int = 100

# Performance tracking
var stats: Dictionary = {
	"total_events_emitted": 0,
	"total_subscribers": 0,
	"events_this_frame": 0,
	"average_emit_time_us": 0.0
}

# Signal for global event monitoring (debug/profiling)
signal event_emitted(event_name: String, payload: Dictionary)


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Reset per-frame stats
	stats.events_this_frame = 0


## Subscribe to an event
func subscribe(event_name: String, subscriber: Object, callback: String) -> void:
	if not subscriptions.has(event_name):
		subscriptions[event_name] = []
	
	# Check if already subscribed
	for sub in subscriptions[event_name]:
		if sub.object == subscriber and sub.callback == callback:
			push_warning("EventBus: Already subscribed to '%s'" % event_name)
			return
	
	subscriptions[event_name].append({
		"object": subscriber,
		"callback": callback
	})
	
	stats.total_subscribers = _count_total_subscribers()
	
	if OS.is_debug_build():
		print("[EventBus] Subscribed: %s → %s.%s" % [event_name, subscriber.name, callback])


## Unsubscribe from an event
func unsubscribe(event_name: String, subscriber: Object, callback: String) -> void:
	if not subscriptions.has(event_name):
		return
	
	for i in range(subscriptions[event_name].size() - 1, -1, -1):
		var sub: Dictionary = subscriptions[event_name][i]
		if sub.object == subscriber and sub.callback == callback:
			subscriptions[event_name].remove_at(i)
	
	stats.total_subscribers = _count_total_subscribers()
	
	# Clean up empty subscription lists
	if subscriptions[event_name].is_empty():
		subscriptions.erase(event_name)


## Emit an event to all subscribers
func emit(event_name: String, payload: Dictionary = {}) -> void:
	var start_time: int = Time.get_ticks_usec()
	
	# Add to history
	_add_to_history(event_name, payload)
	
	# Notify subscribers
	if subscriptions.has(event_name):
		# Create copy to prevent modification during iteration
		var subs: Array = subscriptions[event_name].duplicate()
		
		for sub: Dictionary in subs:
			if is_instance_valid(sub.object) and sub.object.has_method(sub.callback):
				sub.object.call(sub.callback, payload)
	
	# Emit global signal for monitoring
	event_emitted.emit(event_name, payload)
	
	# Track stats
	stats.total_events_emitted += 1
	stats.events_this_frame += 1
	var emit_time: int = Time.get_ticks_usec() - start_time
	stats.average_emit_time_us = lerp(stats.average_emit_time_us, float(emit_time), 0.1)
	
	if OS.is_debug_build() and emit_time > 1000:  # Warn if >1ms
		push_warning("[EventBus] Slow event '%s': %d µs" % [event_name, emit_time])


## Emit event with delay (in ticks)
func emit_delayed(event_name: String, payload: Dictionary, delay_ticks: int) -> void:
	if delay_ticks <= 0:
		emit(event_name, payload)
		return
	
	# Create delayed emitter
	var timer: Timer = Timer.new()
	timer.wait_time = float(delay_ticks) / 60.0  # Convert ticks to seconds
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(func():
		emit(event_name, payload)
		timer.queue_free()
	)
	
	timer.start()


## Check if anyone is subscribed to an event
func has_subscribers(event_name: String) -> bool:
	return subscriptions.has(event_name) and not subscriptions[event_name].is_empty()


## Get subscriber count for an event
func get_subscriber_count(event_name: String) -> int:
	if not subscriptions.has(event_name):
		return 0
	return subscriptions[event_name].size()


## Get event history
func get_history(event_name: String = "", limit: int = 10) -> Array:
	if event_name != "":
		if event_history.has(event_name):
			return event_history[event_name].slice(-limit)
		return []
	
	# Return all recent events
	var all_events: Array = []
	for evt_name in event_history:
		for evt in event_history[evt_name].slice(-limit):
			all_events.append({
				"name": evt_name,
				"payload": evt
			})
	
	all_events.sort_custom(func(a, b): return a.tick > b.tick)
	return all_events.slice(0, limit)


## Clear all subscriptions (use with caution)
func clear_all() -> void:
	subscriptions.clear()
	event_history.clear()
	stats = {
		"total_events_emitted": 0,
		"total_subscribers": 0,
		"events_this_frame": 0,
		"average_emit_time_us": 0.0
	}


func _add_to_history(event_name: String, payload: Dictionary) -> void:
	if not event_history.has(event_name):
		event_history[event_name] = []
	
	event_history[event_name].append({
		"payload": payload.duplicate(),
		"tick": GameManager.tick_count,
		"time": Time.get_ticks_msec()
	})
	
	# Trim history
	while event_history[event_name].size() > MAX_HISTORY_SIZE:
		event_history[event_name].pop_front()


func _count_total_subscribers() -> int:
	var total: int = 0
	for event_name in subscriptions:
		total += subscriptions[event_name].size()
	return total


## Get statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Debug: Print all subscriptions
func debug_print_subscriptions() -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== EVENT BUS SUBSCRIPTIONS ===")
	print("Total Events: %d" % subscriptions.size())
	print("Total Subscribers: %d" % stats.total_subscribers)
	print("Events This Frame: %d" % stats.events_this_frame)
	print("Average Emit Time: %.2f µs" % stats.average_emit_time_us)
	
	print("\nPer-Event Breakdown:")
	for event_name in subscriptions:
		var count: int = subscriptions[event_name].size()
		print("  %s: %d subscribers" % [event_name, count])
		
		for sub: Dictionary in subscriptions[event_name]:
			print("    → %s.%s" % [sub.object.name, sub.callback])
	
	print("=== END SUBSCRIPTIONS ===\n")


## Debug: Print recent event history
func debug_print_history(limit: int = 10) -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== EVENT HISTORY (Last %d) ===" % limit)
	var history: Array = get_history("", limit)
	
	for evt in history:
		print("  [%d] %s: %s" % [evt.tick, evt.name, str(evt.payload)])
	
	print("=== END HISTORY ===\n")


# ==================== PREDEFINED EVENT CONSTANTS ====================

# Game State Events
const EVENT_GAME_STARTED: String = "game_started"
const EVENT_GAME_PAUSED: String = "game_paused"
const EVENT_GAME_RESUMED: String = "game_resumed"
const EVENT_GAME_SPEED_CHANGED: String = "game_speed_changed"

# World Events
const EVENT_WEATHER_CHANGED: String = "weather_changed"
const EVENT_SEASON_CHANGED: String = "season_changed"
const EVENT_TIME_OF_DAY_CHANGED: String = "time_of_day_changed"
const EVENT_DISASTER_STARTED: String = "disaster_started"
const EVENT_DISASTER_ENDED: String = "disaster_ended"

# Settlement Events
const EVENT_SETTLEMENT_FOUNDED: String = "settlement_founded"
const EVENT_SETTLEMENT_EXPANDED: String = "settlement_expanded"
const EVENT_SETTLEMENT_ABANDONED: String = "settlement_abandoned"
const EVENT_SETTLEMENT_ATTACKED: String = "settlement_attacked"

# Pawn Events
const EVENT_PAWN_BORN: String = "pawn_born"
const EVENT_PAWN_DIED: String = "pawn_died"
const EVENT_PAWN_HIRED: String = "pawn_hired"
const EVENT_PAWN_FIRED: String = "pawn_fired"
const EVENT_PAWN_LEVEL_UP: String = "pawn_level_up"
const EVENT_PAWN_PROFESSSION_CHANGED: String = "pawn_profession_changed"

# Job Events
const EVENT_JOB_POSTED: String = "job_posted"
const EVENT_JOB_COMPLETED: String = "job_completed"
const EVENT_JOB_CANCELLED: String = "job_cancelled"

# Resource Events
const EVENT_RESOURCE_GAINED: String = "resource_gained"
const EVENT_RESOURCE_LOST: String = "resource_lost"
const EVENT_RESOURCE_DEPLETED: String = "resource_depleted"

# Combat Events
const EVENT_COMBAT_STARTED: String = "combat_started"
const EVENT_COMBAT_ENDED: String = "combat_ended"
const EVENT_UNIT_DAMAGED: String = "unit_damaged"
const EVENT_UNIT_HEALED: String = "unit_healed"

# Technology Events
const EVENT_RESEARCH_STARTED: String = "research_started"
const EVENT_RESEARCH_COMPLETED: String = "research_completed"
const EVENT_TECHNOLOGY_UNLOCKED: String = "technology_unlocked"

# Social Events
const EVENT_RELATIONSHIP_CHANGED: String = "relationship_changed"
const EVENT_FACTION_FORMED: String = "faction_formed"
const EVENT_FACTION_DISSOLVED: String = "faction_dissolved"
const EVENT_TRADE_ROUTE_ESTABLISHED: String = "trade_route_established"
