extends Node
## MultiplayerSystem — Co-op multiplayer architecture stubs.
## Architecture for up to 4 players in observer/incarnated mode.
## Uses deterministic lockstep: all clients process same ticks.
## Only observer commands (edits) need network sync.
## Player pawns are synchronized via tick-ordered action queues.
## 
## Phase 1: Peer-to-peer, 2 players, observer+incarnated.
## Phase 2: 4 players, host migration.
## Phase 3: Dedicated server, reconnection.

enum MPRole {
	SINGLE,       # single-player (default)
	HOST,         # hosts the simulation
	CLIENT,       # connects to host
	DEDICATED,    # headless server
}

signal player_connected(player_id: int)
signal player_disconnected(player_id: int)

const PLAYER_STALE_TICKS: int = 1800

var role: int = MPRole.SINGLE
var connected_players: Array = []
var player_pawns: Dictionary = {}
var _last_seen_tick_by_player: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func is_multiplayer() -> bool:
	return role != MPRole.SINGLE

func is_host() -> bool:
	return role == MPRole.HOST or role == MPRole.DEDICATED

func get_player_count() -> int:
	if role == MPRole.SINGLE:
		return 1
	return connected_players.size() + 1

func register_player_pawn(player_id: int, pawn_id: int) -> void:
	player_pawns[player_id] = pawn_id
	_touch_player(player_id)

func register_connection(player_id: int) -> void:
	if player_id <= 0:
		return
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		player_connected.emit(player_id)
	_touch_player(player_id)

func heartbeat(player_id: int) -> void:
	if player_id <= 0:
		return
	_touch_player(player_id)

func disconnect_player(player_id: int) -> void:
	if connected_players.has(player_id):
		connected_players.erase(player_id)
	player_pawns.erase(player_id)
	_last_seen_tick_by_player.erase(player_id)
	player_disconnected.emit(player_id)

func get_status() -> Dictionary:
	return {
		"role": role,
		"is_multiplayer": is_multiplayer(),
		"is_host": is_host(),
		"player_count": get_player_count(),
		"connected_players": connected_players.duplicate(),
	}

func _touch_player(player_id: int) -> void:
	var tick: int = 0
	if GameManager != null:
		tick = int(GameManager.tick_count)
	_last_seen_tick_by_player[player_id] = tick

func _on_game_tick(tick: int) -> void:
	if role != MPRole.HOST and role != MPRole.DEDICATED:
		return
	var stale: Array[int] = []
	for pid_variant in connected_players:
		var pid: int = int(pid_variant)
		var last_seen: int = int(_last_seen_tick_by_player.get(pid, tick))
		if tick - last_seen > PLAYER_STALE_TICKS:
			stale.append(pid)
	for stale_pid in stale:
		disconnect_player(stale_pid)
