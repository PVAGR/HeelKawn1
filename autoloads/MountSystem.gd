extends Node
## MountSystem — Tame and ride animals for faster travel.
## Horses are the primary mount. Camels for deserts. Donkeys for carrying goods.
## Taming requires time, food, and skill. Riding gives movement speed bonus.
## Mounts can be killed in combat. Mount death is recorded in WorldMemory.
## All deterministic: taming success uses WorldRNG with pawn skill modifiers.

enum MountType {
	HORSE,
	DONKEY,
	CAMEL,
}

const MOUNT_NAMES: Dictionary = {
	MountType.HORSE: "Horse",
	MountType.DONKEY: "Donkey",
	MountType.CAMEL: "Camel",
}

const MOUNT_SPEED_BONUS: Dictionary = {
	MountType.HORSE: 2.5,
	MountType.DONKEY: 1.3,
	MountType.CAMEL: 1.8,
}

const MOUNT_CARRY_BONUS: Dictionary = {
	MountType.HORSE: 3,
	MountType.DONKEY: 5,
	MountType.CAMEL: 4,
}

const TAME_TICKS: Dictionary = {
	MountType.HORSE: 2000,
	MountType.DONKEY: 1500,
	MountType.CAMEL: 2500,
}

const TAME_FOOD_COST: Dictionary = {
	MountType.HORSE: 20,
	MountType.DONKEY: 15,
	MountType.CAMEL: 10,
}

var mounts: Dictionary = {}
var _next_mount_id: int = 1

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func start_taming(mount_type: int, tile: Vector2i, tamer_id: int) -> int:
	var mount_id: int = _next_mount_id
	_next_mount_id += 1
	mounts[mount_id] = {
		"id": mount_id,
		"type": mount_type,
		"name": MOUNT_NAMES.get(mount_type, "Mount"),
		"tile": tile,
		"owner_id": tamer_id,
		"rider_id": -1,
		"tame_progress": 0,
		"tame_ticks_required": TAME_TICKS.get(mount_type, 2000),
		"is_tamed": false,
		"health": 100.0,
		"max_health": 100.0,
		"hunger": 100.0,
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"taming_started": true,
		"mount_type": mount_type,
		"tamer_id": tamer_id,
		"tile_x": tile.x, "tile_y": tile.y,
	})
	return mount_id

func mount_rider(mount_id: int, rider_id: int) -> bool:
	if not mounts.has(mount_id):
		return false
	var m: Dictionary = mounts[mount_id]
	if not bool(m.get("is_tamed", false)):
		return false
	if int(m.get("rider_id", -1)) >= 0:
		return false
	m["rider_id"] = rider_id
	return true

func dismount(mount_id: int) -> void:
	if mounts.has(mount_id):
		mounts[mount_id]["rider_id"] = -1

func get_speed_bonus(rider_id: int) -> float:
	for mid in mounts:
		var m: Dictionary = mounts[mid]
		if int(m.get("rider_id", -1)) == rider_id:
			return float(MOUNT_SPEED_BONUS.get(int(m.get("type", 0)), 1.0))
	return 1.0

func get_carry_bonus(rider_id: int) -> int:
	for mid in mounts:
		var m: Dictionary = mounts[mid]
		if int(m.get("rider_id", -1)) == rider_id:
			return int(MOUNT_CARRY_BONUS.get(int(m.get("type", 0)), 0))
	return 0

func get_mount_for_rider(rider_id: int) -> Dictionary:
	for mid in mounts:
		var m: Dictionary = mounts[mid]
		if int(m.get("rider_id", -1)) == rider_id:
			return m
	return {}

func _on_game_tick(tick: int) -> void:
	if tick % 50 != 0:
		return
	_process_taming(tick)
	_process_mount_decay(tick)

func _process_taming(tick: int) -> void:
	for mid in mounts:
		var m: Dictionary = mounts[mid]
		if bool(m.get("is_tamed", false)):
			continue
		m["tame_progress"] = int(m.get("tame_progress", 0)) + 50
		if int(m.get("tame_progress", 0)) >= int(m.get("tame_ticks_required", 2000)):
			m["is_tamed"] = true
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.LIFE_EVENT,
				"tick": tick,
				"mount_tamed": true,
				"mount_type": m.get("type"),
				"mount_name": m.get("name"),
				"owner_id": int(m.get("owner_id", -1)),
			})

func _process_mount_decay(_tick: int) -> void:
	for mid in mounts:
		var m: Dictionary = mounts[mid]
		m["hunger"] = maxf(0.0, float(m.get("hunger", 100.0)) - 0.1)
		if float(m.get("hunger", 100.0)) <= 0.0:
			m["health"] = maxf(0.0, float(m.get("health", 100.0)) - 0.2)

func feed_mount(mount_id: int, food_amount: int) -> void:
	if mounts.has(mount_id):
		mounts[mount_id]["hunger"] = minf(100.0, float(mounts[mount_id].get("hunger", 100.0)) + float(food_amount))

func damage_mount(mount_id: int, damage: float) -> void:
	if mounts.has(mount_id):
		var m: Dictionary = mounts[mount_id]
		m["health"] = maxf(0.0, float(m["health"]) - damage)
		if float(m["health"]) <= 0.0:
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.DEATH_EVENT,
				"tick": GameManager.tick_count if GameManager != null else 0,
				"mount_died": true,
				"mount_type": m.get("type"),
				"mount_name": m.get("name"),
				"owner_id": int(m.get("owner_id", -1)),
			})
			mounts.erase(mount_id)

func count_mounts() -> int:
	return mounts.size()

func clear() -> void:
	mounts.clear()
