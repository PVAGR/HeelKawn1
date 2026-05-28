extends Node

## Shared simulation budget coordinator (disabled).
## No mid-frame budget yield — the sim runs uncapped and uninterrupted.
## Keeps the throttled log helper for debug paths.

var _last_log_msec_by_key: Dictionary = {}


func get_tick_budget_usec() -> int:
	return 999999999


func should_yield(_start_usec: int) -> bool:
	return false


func remaining_usec(start_usec: int) -> int:
	return 999999999


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