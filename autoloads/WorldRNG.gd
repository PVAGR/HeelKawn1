extends Node
## Central **seeded** random streams for emergent simulation (see docs/HEELKAWN_STATE.md).
## Different `world_seed` → different geography + different subsystem rolls; same seed → reproducible debug.
## Heavy systems should prefer named streams instead of raw global `randf()` so behavior stays tunable.

var _world_seed: int = 0


func configure_from_seed(seed: int) -> void:
	_world_seed = seed


func current_seed() -> int:
	return _world_seed


func stream_seed(stream_name: StringName, salt: int = 0) -> int:
	return int(hash(str(_world_seed) + "::" + str(stream_name) + "::" + str(salt))) & 0x7FFFFFFF


func rng_for(stream_name: StringName, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = stream_seed(stream_name, salt)
	return r


func unit_for(stream_name: StringName, salt: int = 0) -> float:
	return float(stream_seed(stream_name, salt) % 1000000) / 1000000.0


func range_for(stream_name: StringName, min_value: float, max_value: float, salt: int = 0) -> float:
	return lerpf(min_value, max_value, unit_for(stream_name, salt))


func chance_for(stream_name: StringName, probability: float, salt: int = 0) -> bool:
	return unit_for(stream_name, salt) < clamp(probability, 0.0, 1.0)


func index_for(stream_name: StringName, size: int, salt: int = 0) -> int:
	if size <= 0:
		return -1
	return stream_seed(stream_name, salt) % size
