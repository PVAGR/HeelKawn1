extends Node
class_name TickSystem

## Central batch event processor for simulation ticks.
## Processes events in batches for performance at high speed multipliers.

signal batch_processed(tick_count: int, events_processed: int)

## Maximum events to process per batch frame (prevents frame hitches)
const MAX_EVENTS_PER_BATCH: int = 100

## Events pending batch processing
var _pending_events: Array[Dictionary] = []

## Batch statistics
var _batch_stats: Dictionary = {
	"total_batches": 0,
	"total_events": 0,
	"avg_events_per_batch": 0.0,
	"last_batch_size": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _pending_events.is_empty():
		return
	
	_process_event_batch()


## Queue an event for batch processing
func queue_event(event: Dictionary) -> void:
	_pending_events.append(event)


## Queue multiple events at once
func queue_events(events: Array[Dictionary]) -> void:
	_pending_events.append_array(events)


## Process queued events in batches
func _process_event_batch() -> void:
	var events_processed: int = 0
	var batch_size: int = mini(_pending_events.size(), MAX_EVENTS_PER_BATCH)
	
	for i in range(batch_size):
		var event: Dictionary = _pending_events.pop_front()
		_process_single_event(event)
		events_processed += 1
	
	# Update statistics
	_batch_stats["total_batches"] = int(_batch_stats.get("total_batches", 0)) + 1
	_batch_stats["total_events"] = int(_batch_stats.get("total_events", 0)) + events_processed
	_batch_stats["last_batch_size"] = events_processed
	
	# Calculate running average
	var total_batches: int = int(_batch_stats.get("total_batches", 1))
	var total_events: int = int(_batch_stats.get("total_events", 0))
	_batch_stats["avg_events_per_batch"] = float(total_events) / float(total_batches)
	
	batch_processed.emit(total_batches, events_processed)


## Process a single event - override in subclasses
func _process_single_event(event: Dictionary) -> void:
	var event_type: String = event.get("type", "unknown")
	match event_type:
		"pawn_tick":
			_process_pawn_event(event)
		"settlement_tick":
			_process_settlement_event(event)
		"world_tick":
			_process_world_event(event)
		_:
			# Unknown event type - skip
			pass


## Process pawn-related events
func _process_pawn_event(event: Dictionary) -> void:
	# Override in subclasses for custom pawn event handling
	pass


## Process settlement-related events
func _process_settlement_event(event: Dictionary) -> void:
	# Override in subclasses for custom settlement event handling
	pass


## Process world-level events
func _process_world_event(event: Dictionary) -> void:
	# Override in subclasses for custom world event handling
	pass


## Get pending event count
func get_pending_count() -> int:
	return _pending_events.size()


## Get batch statistics
func get_stats() -> Dictionary:
	return _batch_stats.duplicate(true)


## Clear pending events (e.g., on game load)
func clear_pending() -> void:
	_pending_events.clear()