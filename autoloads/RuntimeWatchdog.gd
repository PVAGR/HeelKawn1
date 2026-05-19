extends Node

## RuntimeWatchdog
## Lightweight runtime guard that verifies critical systems remain connected.
## It attempts soft recovery for missing autoload nodes and broken tick wiring.

const CHECK_INTERVAL_SEC: float = 3.0
const TICK_STALL_TIMEOUT_SEC: float = 10.0
const STALL_LOG_COOLDOWN_SEC: float = 8.0
const MAX_RECOVERY_ATTEMPTS_PER_NAME: int = 3

const CRITICAL_AUTOLOADS: PackedStringArray = [
	"TickManager",
	"GameManager",
	"WorldMemory",
	"SettlementMemory",
	"FactionSystem",
	"FactionManager",
	"EconomyManager",
	"CurrencySystem",
	"MultiplayerSystem",
	"EventBus",
	"CommandAPI",
	"AIAgentManager",
]

const AUTOLOAD_FALLBACK_PATHS: Dictionary = {
	"TickManager": "res://autoloads/TickManager.gd",
	"GameManager": "res://autoloads/GameManager.gd",
	"WorldMemory": "res://autoloads/WorldMemory.gd",
	"SettlementMemory": "res://autoloads/SettlementMemory.gd",
	"FactionSystem": "res://autoloads/FactionSystem.gd",
	"FactionManager": "res://autoloads/FactionManager.gd",
	"EconomyManager": "res://autoloads/EconomyManager.gd",
	"CurrencySystem": "res://autoloads/CurrencySystem.gd",
	"MultiplayerSystem": "res://autoloads/MultiplayerSystem.gd",
	"EventBus": "res://autoloads/EventBus.gd",
	"CommandAPI": "res://autoloads/CommandAPI.gd",
	"AIAgentManager": "res://autoloads/AIAgentManager.gd",
}

var _check_timer: Timer = null
var _last_tick_count: int = -1
var _stall_elapsed_sec: float = 0.0
var _last_stall_log_sec: float = -9999.0
var _recovery_attempts: Dictionary = {}


func _ready() -> void:
	_check_timer = Timer.new()
	_check_timer.one_shot = false
	_check_timer.wait_time = CHECK_INTERVAL_SEC
	_check_timer.autostart = true
	add_child(_check_timer)
	_check_timer.timeout.connect(_on_watchdog_timeout)
	_on_watchdog_timeout()


func _on_watchdog_timeout() -> void:
	_verify_critical_autoloads()
	_ensure_tick_wiring()
	_ensure_game_tick_listeners()
	_verify_tick_progress()


func _verify_critical_autoloads() -> void:
	var root: Window = get_tree().root
	for name in CRITICAL_AUTOLOADS:
		var node: Node = root.get_node_or_null(name)
		if node != null and is_instance_valid(node):
			continue
		_try_recover_autoload(name)


func _try_recover_autoload(name: String) -> void:
	var attempts: int = int(_recovery_attempts.get(name, 0))
	if attempts >= MAX_RECOVERY_ATTEMPTS_PER_NAME:
		return
	_recovery_attempts[name] = attempts + 1
	var path: String = str(AUTOLOAD_FALLBACK_PATHS.get(name, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("[RuntimeWatchdog] Missing autoload '%s' and no valid fallback path." % name)
		return
	var script_ref: Variant = load(path)
	if script_ref == null:
		push_warning("[RuntimeWatchdog] Failed to load script for '%s' from %s." % [name, path])
		return
	var node: Node = script_ref.new()
	if node == null:
		push_warning("[RuntimeWatchdog] Failed to instantiate fallback autoload '%s'." % name)
		return
	node.name = name
	get_tree().root.add_child(node)
	push_warning("[RuntimeWatchdog] Recovered missing autoload '%s' (attempt %d)." % [name, int(_recovery_attempts.get(name, 0))])


func _ensure_tick_wiring() -> void:
	var tick_manager: Node = get_node_or_null("/root/TickManager")
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if tick_manager == null or game_manager == null:
		return
	if not tick_manager.has_signal("tick_processed"):
		return
	if not game_manager.has_method("_on_tick_manager_tick"):
		return
	var cb: Callable = Callable(game_manager, "_on_tick_manager_tick")
	if not tick_manager.is_connected("tick_processed", cb):
		tick_manager.connect("tick_processed", cb)
		push_warning("[RuntimeWatchdog] Reconnected TickManager.tick_processed -> GameManager._on_tick_manager_tick")


func _ensure_game_tick_listeners() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null or not game_manager.has_signal("game_tick"):
		return
	for name in CRITICAL_AUTOLOADS:
		if name == "GameManager" or name == "TickManager":
			continue
		var node: Node = get_node_or_null("/root/%s" % name)
		if node == null or not node.has_method("_on_game_tick"):
			continue
		var cb: Callable = Callable(node, "_on_game_tick")
		if not game_manager.is_connected("game_tick", cb):
			game_manager.connect("game_tick", cb)
			push_warning("[RuntimeWatchdog] Reconnected GameManager.game_tick -> %s._on_game_tick" % name)


func _verify_tick_progress() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		_stall_elapsed_sec = 0.0
		return
	var paused: bool = bool(game_manager.get("is_paused"))
	var tick_count: int = int(game_manager.get("tick_count"))
	if paused:
		_last_tick_count = tick_count
		_stall_elapsed_sec = 0.0
		return
	if _last_tick_count >= 0 and tick_count <= _last_tick_count:
		_stall_elapsed_sec += CHECK_INTERVAL_SEC
	else:
		_stall_elapsed_sec = 0.0
	_last_tick_count = tick_count
	if _stall_elapsed_sec < TICK_STALL_TIMEOUT_SEC:
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if now_sec - _last_stall_log_sec < STALL_LOG_COOLDOWN_SEC:
		return
	_last_stall_log_sec = now_sec
	push_warning("[RuntimeWatchdog] Tick progression stalled for %.1fs while unpaused. Verifying core wiring." % _stall_elapsed_sec)
	_ensure_tick_wiring()
	_verify_critical_autoloads()
