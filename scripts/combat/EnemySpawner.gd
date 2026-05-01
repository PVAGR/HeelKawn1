## EnemySpawner.gd — Manages enemy spawning, waves, and difficulty scaling.
class_name EnemySpawner
extends Node

const INITIAL_RAID_SIZE: int = 3
const MAX_ENEMIES: int = 20
const RAID_INTERVAL_TICKS: int = 3000  # ~5 minutes at 1x speed = one raid every 5 in-game days
const SPAWN_INTERVAL_TICKS: int = RAID_INTERVAL_TICKS
const DIFFICULTY_SCALE: float = 1.1  # Increase difficulty by 10% each raid
const NO_TARGET_DESPAWN_TICKS: int = 200
const RAID_DURATION_TICKS: int = 500

var enemies: Array[Enemy] = []
@warning_ignore("unused_private_class_variable")
var _tick_counter: int = 0
@warning_ignore("unused_private_class_variable")
var _next_raid_tick: int = RAID_INTERVAL_TICKS
var _raid_number: int = 0
var _difficulty: float = 1.0
var _is_battle_active: bool = false
var _no_target_since_tick: int = -1
var _raid_start_tick: int = -1
var _encounter_kind: String = "none"
var _war_source_settlement_id: int = -1
var _war_target_settlement_id: int = -1
var _war_strength: float = 0.0
var _last_cleanup_tick: int = -1
var _cached_alive_pawns: int = 0
var _cached_pawns_tick: int = -1


func _ready() -> void:
	pass


func process_tick(world: World, tick: int) -> void:
	# Cleanup dead enemies at most once per tick (get_enemy_count also calls it).
	if _last_cleanup_tick != tick:
		cleanup_dead_enemies()
		_last_cleanup_tick = tick
	_is_battle_active = enemies.size() > 0
	if _is_battle_active:
		if _raid_start_tick >= 0 and (tick - _raid_start_tick) >= RAID_DURATION_TICKS:
			despawn_all()
			_no_target_since_tick = -1
			if tick % 100 == 0:
				print("[Combat] Battle cleared: timeout reached.")
			return
		# Cache alive pawn count; refresh every 10 ticks to avoid repeated
		# get_nodes_in_group + filter allocations on every sim tick.
		if _cached_pawns_tick != tick / 10:
			_cached_alive_pawns = get_tree().get_nodes_in_group("pawns").filter(
				func(p: Node) -> bool: return is_instance_valid(p)
			).size()
			_cached_pawns_tick = tick / 10
		var alive_pawns: int = _cached_alive_pawns
		if alive_pawns < 2:
			if _no_target_since_tick < 0:
				_no_target_since_tick = tick
			elif tick - _no_target_since_tick >= NO_TARGET_DESPAWN_TICKS:
				despawn_all()
				_is_battle_active = false
				_no_target_since_tick = -1
				if tick % 100 == 0:
					print("[Combat] Raid cleared: No targets remaining.")
		else:
			_no_target_since_tick = -1
	else:
		_no_target_since_tick = -1
		_raid_start_tick = -1
	# Timed automatic raid spawning is disabled.
	# Raids must be spawned explicitly by war/battle state systems.


func spawn_raid(world: World) -> void:
	_raid_number += 1
	_difficulty = pow(DIFFICULTY_SCALE, _raid_number)
	var raid_size: int = int(INITIAL_RAID_SIZE * _difficulty)
	raid_size = clampi(raid_size, 1, MAX_ENEMIES - enemies.size())
	var spawn_edge: int = int((_raid_number + GameManager.tick_count / SPAWN_INTERVAL_TICKS) % 4)  # deterministic
	var spawned_count: int = _spawn_forces_internal(world, raid_size, spawn_edge, "raid", -1, -1, 0.0)
	if GameManager.tick_count % 100 == 0:
		print("[EnemySpawner] Raid #%d spawned: %d enemies (difficulty %.1fx)" % [_raid_number, spawned_count, _difficulty])


func spawn_war_forces(
		world: World,
		source_settlement_id: int,
		target_settlement_id: int,
		strength: float
) -> bool:
	if world == null or _is_battle_active or enemies.size() > 0:
		return false
	var norm_strength: float = maxf(0.0, strength)
	var war_size: int = clampi(2 + int(norm_strength / 60.0), 2, MAX_ENEMIES)
	var edge_mix: int = int((source_settlement_id * 73856093) ^ (target_settlement_id * 19349663) ^ int(norm_strength * 100.0))
	var spawn_edge: int = abs(edge_mix) % 4
	var spawned_count: int = _spawn_forces_internal(
		world,
		war_size,
		spawn_edge,
		"war",
		source_settlement_id,
		target_settlement_id,
		norm_strength
	)
	if spawned_count <= 0:
		return false
	WorldMemory.record_event({
		"type": "war_battle_spawned",
		"source_settlement_id": source_settlement_id,
		"target_settlement_id": target_settlement_id,
		"strength": norm_strength,
		"spawned": spawned_count,
		"tick": GameManager.tick_count,
	})
	print("[War] Battle forces mobilized: %d units (src=%d -> dst=%d, strength=%.1f)" %
		[spawned_count, source_settlement_id, target_settlement_id, norm_strength])
	return true


func _spawn_forces_internal(
		world: World,
		force_size: int,
		spawn_edge: int,
		encounter_kind: String,
		source_settlement_id: int,
		target_settlement_id: int,
		strength: float
) -> int:
	_raid_start_tick = GameManager.tick_count
	_encounter_kind = encounter_kind
	_war_source_settlement_id = source_settlement_id
	_war_target_settlement_id = target_settlement_id
	_war_strength = strength
	var spawn_tiles: Array[Vector2i] = []

	# Pick spawn tiles along one edge
	match spawn_edge:
		0:  # Top edge
			for x in range(0, WorldData.WIDTH, 5):
				spawn_tiles.append(Vector2i(x, 0))
		1:  # Bottom edge
			for x in range(0, WorldData.WIDTH, 5):
				spawn_tiles.append(Vector2i(x, WorldData.HEIGHT - 1))
		2:  # Left edge
			for y in range(0, WorldData.HEIGHT, 5):
				spawn_tiles.append(Vector2i(0, y))
		3:  # Right edge
			for y in range(0, WorldData.HEIGHT, 5):
				spawn_tiles.append(Vector2i(WorldData.WIDTH - 1, y))
	
	# Deterministic pseudo-shuffle: sort by stable hash tied to raid number.
	spawn_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var kind_seed: int = 1 if encounter_kind == "war" else _raid_number
		var ha: int = int(((a.x * 73856093) ^ (a.y * 19349663) ^ (kind_seed * 83492791)) & 0x7FFFFFFF)
		var hb: int = int(((b.x * 73856093) ^ (b.y * 19349663) ^ (kind_seed * 83492791)) & 0x7FFFFFFF)
		return ha < hb
	)

	var spawned: int = 0
	for tile in spawn_tiles:
		if spawned >= force_size:
			break

		if not world.pathfinder.is_passable(tile):
			continue

		# Pick enemy type deterministically; war composition scales from strength.
		var enemy_type: int = Enemy.Type.RAIDER
		var ticket: int = int(((tile.x * 31 + tile.y * 17 + (spawned + 1) * 13 + spawn_edge * 19) & 0xFF))
		if encounter_kind == "war":
			if strength >= 220.0 and ticket % 10 < 4:
				enemy_type = Enemy.Type.BRIGAND
			if strength >= 360.0 and ticket % 10 < 2:
				enemy_type = Enemy.Type.WARLORD
		else:
			if _difficulty > 2.0 and ticket % 10 < 3:
				enemy_type = Enemy.Type.BRIGAND
			if _difficulty > 4.0 and ticket % 10 < 2:
				enemy_type = Enemy.Type.WARLORD

		var enemy := Enemy.new()
		add_child(enemy)
		enemy.bind(enemy_type, tile, world)
		enemies.append(enemy)
		spawned += 1
	_is_battle_active = enemies.size() > 0
	return spawned


func cleanup_dead_enemies() -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e != null)
	if enemies.is_empty():
		_is_battle_active = false


func get_enemy_count() -> int:
	cleanup_dead_enemies()
	return enemies.size()


func despawn_all() -> void:
	cleanup_dead_enemies()
	for e in enemies:
		if e != null and is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_is_battle_active = false
	_raid_start_tick = -1
	_encounter_kind = "none"
	_war_source_settlement_id = -1
	_war_target_settlement_id = -1
	_war_strength = 0.0


func describe() -> String:
	return "Enemies: %d active / %d max (raid #%d, difficulty %.1fx)" % [
		get_enemy_count(), MAX_ENEMIES, _raid_number, _difficulty
	]
