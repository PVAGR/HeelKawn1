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

var role: int = MPRole.SINGLE
var connected_players: Array = []
var player_pawns: Dictionary = {}

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

func _on_game_tick(tick: int) -> void:
	_ = tick
