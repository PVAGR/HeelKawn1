extends Node

## Shared simulation budget coordinator.
## Keeps the hard wall-time budget in one place and provides a tiny throttled
## logging helper for high-frequency debug paths.

const TICK_BUDGET_MS: int = 16
const TICK_BUDGET_USEC: int = TICK_BUDGET_MS * 1000

var _last_log_msec_by_key: Dictionary = {}


func get_tick_budget_usec() -> int:
	return TICK_BUDGET_USEC


func should_yield(start_usec: int) -> bool:
	return Time.get_ticks_usec() - start_usec >= TICK_BUDGET_USEC


func remaining_usec(start_usec: int) -> int:
	return maxi(0, TICK_BUDGET_USEC - (Time.get_ticks_usec() - start_usec))


func log_throttled(key: String, message: String, interval_msec: int = 1000) -> void:
	if not OS.is_debug_build():
		return
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_last_log_msec_by_key.get(key, -1_000_000))
	if now_msec - last_msec < interval_msec:
		return
	_last_log_msec_by_key[key] = now_msec
	print(message)


func reset_throttles() -> void:
	_last_log_msec_by_key.clear()