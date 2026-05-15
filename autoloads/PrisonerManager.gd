extends Node

## Tracks incapacitated enemies that have been captured instead of killed.
## Prisoners can be guarded (preventing escape), recruited (converting to colonists),
## or escape if left unguarded too long.

const ESCAPE_CHECK_TICKS: int = 300
const ESCAPE_CHANGE_BASE: float = 0.02
const ESCAPE_CHANGE_GUARD_SUPPRESSED: float = 0.001
const GUARD_RANGE_TILES: float = 8.0
const RECRUIT_TICKS_REQUIRED: int = 5000
const RECRUIT_TICK_INTERVAL: int = 200
const MAX_PRISONERS: int = 10

var _prisoners: Dictionary = {}
var _next_prisoner_id: int = 1


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	if _prisoners.is_empty():
		return
	if tick % ESCAPE_CHECK_TICKS == 0:
		_tick_prisoners(tick)


func _tick_prisoners(tick: int) -> void:
	var to_remove: Array[int] = []
	for pid in _prisoners.keys():
		var entry: Dictionary = _prisoners[pid]
		var node: Node = _resolve_node(entry)
		if node == null:
			to_remove.append(pid)
			continue
		if entry.get("recruited", false):
			to_remove.append(pid)
			continue

		var pos: Vector2i = entry.tile_pos
		var has_guard_nearby: bool = _has_guard_nearby(pos)

		if has_guard_nearby:
			entry.recruit_progress += float(RECRUIT_TICK_INTERVAL) / float(RECRUIT_TICKS_REQUIRED) * 100.0
			if entry.recruit_progress >= 100.0:
				_recruit_prisoner(pid)
				continue
		else:
			if WorldRNG.chance_for("prisoner_escape:%d" % pid, ESCAPE_CHANGE_BASE, tick):
				_escape_prisoner(pid)
				continue
			if WorldRNG.chance_for("prisoner_escape_die:%d" % pid, ESCAPE_CHANGE_BASE * 0.3, tick + 97):
				_die_prisoner(pid)
				continue
		entry.escape_progress = minf(100.0, entry.escape_progress + (0.0 if has_guard_nearby else 1.0))

	for pid in to_remove:
		_prisoners.erase(pid)


func _has_guard_nearby(pos: Vector2i) -> bool:
	for pawn in PawnAccess.find_pawns():
		if not is_instance_valid(pawn) or pawn.data == null:
			continue
		var work_guard_v: Variant = pawn.data.get("work_guard")
		if work_guard_v != null and not bool(work_guard_v):
			continue
		if pawn.data.is_dead:
			continue
		var dist: float = pawn.data.tile_pos.distance_to(pos)
		if dist <= GUARD_RANGE_TILES:
			return true
	return false


func capture_enemy(enemy_node: Node) -> bool:
	if _prisoners.size() >= MAX_PRISONERS:
		return false
	var pid: int = _next_prisoner_id
	_next_prisoner_id += 1
	var entry: Dictionary = {
		"id": pid,
		"node_ref": weakref(enemy_node),
		"tile_pos": enemy_node.tile_pos,
		"capture_tick": GameManager.tick_count,
		"recruit_progress": 0.0,
		"escape_progress": 0.0,
		"enemy_type": int(enemy_node.get("enemy_type") if enemy_node.get("enemy_type") != null else 0),
		"species_name": enemy_node.get_species_name() if enemy_node.has_method("get_species_name") else "Prisoner",
	}
	_prisoners[pid] = entry
	print("[Prisoner] Captured %s (id=%d)" % [entry.species_name, pid])
	return true


func get_prisoner_count() -> int:
	return _prisoners.size()


func get_prisoners() -> Array:
	var result: Array = []
	for pid in _prisoners.keys():
		var entry: Dictionary = _prisoners[pid]
		var node: Node = _resolve_node(entry)
		if node != null:
			result.append(entry.duplicate())
	return result


func _recruit_prisoner(pid: int) -> void:
	var entry: Dictionary = _prisoners.get(pid, {})
	if entry.is_empty():
		return
	var node: Node = _resolve_node(entry)
	if node != null:
		var tile: Vector2i = node.tile_pos
		node.queue_free()
		var world: Node = get_node_or_null("/root/Main/WorldViewport/World")
		var spawner: PawnSpawner = get_tree().get_first_node_in_group("pawn_spawner") as PawnSpawner
		if world != null and spawner != null:
			var tick_seed: int = GameManager.tick_count if GameManager != null else 0
			spawner.spawn_pawn_at(world, tile, tick_seed)
	entry.recruited = true
	print("[Prisoner] Recruited %s into colony!" % entry.get("species_name", "Prisoner"))


func _escape_prisoner(pid: int) -> void:
	var entry: Dictionary = _prisoners.get(pid, {})
	if entry.is_empty():
		return
	var node: Node = _resolve_node(entry)
	if node != null:
		node.queue_free()
	print("[Prisoner] %s escaped!" % entry.get("species_name", "Prisoner"))
	_prisoners.erase(pid)


func _die_prisoner(pid: int) -> void:
	var entry: Dictionary = _prisoners.get(pid, {})
	if entry.is_empty():
		return
	var node: Node = _resolve_node(entry)
	if node != null:
		node.queue_free()
	print("[Prisoner] %s died during captivity" % entry.get("species_name", "Prisoner"))
	_prisoners.erase(pid)


func _resolve_node(entry: Dictionary) -> Node:
	var ref: WeakRef = entry.get("node_ref")
	if ref == null:
		return null
	var node: Node = ref.get_ref() as Node
	if node == null or not is_instance_valid(node):
		return null
	return node


func _generate_prisoner_name(species: String) -> String:
	match species.to_lower():
		"raider": return "Rurik"
		"brigand": return "Bastian"
		"warlord": return "Wulfric"
		_: return "Valtor"


func clear() -> void:
	for entry in _prisoners.values():
		var node: Node = _resolve_node(entry)
		if node != null:
			node.queue_free()
	_prisoners.clear()
	_next_prisoner_id = 1
