## EnemySpawner.gd — Manages enemy spawning, waves, and difficulty scaling.
class_name EnemySpawner
extends Node

const INITIAL_RAID_SIZE: int = 3
const MAX_ENEMIES: int = 20
const RAID_INTERVAL_TICKS: int = 3000  # ~5 minutes at 1x speed = one raid every 5 in-game days
const SPAWN_INTERVAL_TICKS: int = RAID_INTERVAL_TICKS
const DIFFICULTY_SCALE: float = 1.1  # Increase difficulty by 10% each raid
const NO_TARGET_DESPAWN_TICKS: int = 200

var enemies: Array[Enemy] = []
@warning_ignore("unused_private_class_variable")
var _tick_counter: int = 0
@warning_ignore("unused_private_class_variable")
var _next_raid_tick: int = RAID_INTERVAL_TICKS
var _raid_number: int = 0
var _difficulty: float = 1.0
var _is_battle_active: bool = false
var _no_target_since_tick: int = -1


func _ready() -> void:
	pass


func process_tick(world: World, tick: int) -> void:
	cleanup_dead_enemies()
	_is_battle_active = enemies.size() > 0
	if _is_battle_active:
		var alive_pawns: int = get_tree().get_nodes_in_group("pawns").filter(
			func(p: Node) -> bool: return is_instance_valid(p)
		).size()
		if alive_pawns < 2:
			if _no_target_since_tick < 0:
				_no_target_since_tick = tick
			elif tick - _no_target_since_tick >= NO_TARGET_DESPAWN_TICKS:
				despawn_all()
				_is_battle_active = false
				_no_target_since_tick = -1
				print("[Combat] Raid cleared: No targets remaining.")
		else:
			_no_target_since_tick = -1
	else:
		_no_target_since_tick = -1
	# Active battle lock: don't stack raids while one is in progress.
	if _is_battle_active:
		return
	if tick > 0 and tick % SPAWN_INTERVAL_TICKS == 0:
		spawn_raid(world)


func spawn_raid(world: World) -> void:
	_raid_number += 1
	_difficulty = pow(DIFFICULTY_SCALE, _raid_number)
	
	var raid_size: int = int(INITIAL_RAID_SIZE * _difficulty)
	raid_size = clampi(raid_size, 1, MAX_ENEMIES - enemies.size())
	
	var spawn_edge: int = int((_raid_number + GameManager.tick_count / SPAWN_INTERVAL_TICKS) % 4)  # deterministic
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
		var ha: int = int(((a.x * 73856093) ^ (a.y * 19349663) ^ (_raid_number * 83492791)) & 0x7FFFFFFF)
		var hb: int = int(((b.x * 73856093) ^ (b.y * 19349663) ^ (_raid_number * 83492791)) & 0x7FFFFFFF)
		return ha < hb
	)
	
	var spawned: int = 0
	for tile in spawn_tiles:
		if spawned >= raid_size:
			break
		
		if not world.pathfinder.is_passable(tile):
			continue
		
		# Pick enemy type based on difficulty
		var enemy_type: int = Enemy.Type.RAIDER
		var ticket: int = int(((tile.x * 31 + tile.y * 17 + _raid_number * 13) & 0xFF))
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
	if GameManager.tick_count % 100 == 0:
		print("[EnemySpawner] Raid #%d spawned: %d enemies (difficulty %.1fx)" % [_raid_number, spawned, _difficulty])


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


func describe() -> String:
	return "Enemies: %d active / %d max (raid #%d, difficulty %.1fx)" % [
		get_enemy_count(), MAX_ENEMIES, _raid_number, _difficulty
	]
