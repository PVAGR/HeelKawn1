extends Node
## Central **seeded** random streams for emergent simulation (see docs/HEELKAWN_STATE.md).
## Different `world_seed` → different geography + different subsystem rolls; same seed → reproducible debug.
## Heavy systems should prefer named streams instead of raw global `randf()` so behavior stays tunable.

var _world_seed: int = 0
var _compat_sequence: int = 0


func configure_from_seed(configured_seed: int) -> void:
	_world_seed = configured_seed


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


## Backward-compatible integer range helper used by legacy systems.
## Call order contributes to the salt so repeated no-salt calls still vary.
func rangei(min_value: int, max_value: int, salt: int = 0, stream_name: StringName = &"compat:rangei") -> int:
	var lo: int = mini(min_value, max_value)
	var hi: int = maxi(min_value, max_value)
	if hi <= lo:
		return lo
	_compat_sequence += 1
	var raw: float = range_for(stream_name, float(lo), float(hi + 1), salt + _compat_sequence)
	return clampi(int(floor(raw)), lo, hi)
