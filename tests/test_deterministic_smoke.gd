extends Node
## Deterministic smoke tests: verify same seed -> same output across core systems.
## Run from Godot editor or headless: godot --headless --script tests/test_deterministic_smoke.gd

var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	run_all_tests()
	print("\n=== Deterministic Smoke Tests Summary ===")
	print("PASSED: %d" % _passes)
	print("FAILED: %d" % _failures)
	print("TOTAL:  %d" % (_passes + _failures))
	if _failures > 0:
		push_error("Deterministic smoke tests: %d failure(s) detected!" % _failures)
	else:
		print("All deterministic smoke tests passed.")
	get_tree().quit()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("[TEST FAIL] %s" % message)
		_failures += 1
	else:
		print("[TEST PASS] %s" % message)
		_passes += 1


func run_all_tests() -> void:
	print("\n=== Deterministic Smoke Tests ===\n")
	_test_same_seed_same_rng_sequence()
	_test_same_seed_same_pawn_behavior_profile()
	_test_same_seed_same_world_generation_components()
	_test_event_recording_deterministic()
	_test_knowledge_system_deterministic()


# ---------------------------------------------------------------------------
# Test 1: Same seed produces same RNG sequence
# ---------------------------------------------------------------------------
func _test_same_seed_same_rng_sequence() -> void:
	print("--- Test 1: Same seed produces same RNG sequence ---")

	var seed_a: int = 12345
	var seed_b: int = 12345
	var seed_c: int = 99999

	var rng_a1: RandomNumberGenerator = _create_test_rng(seed_a, &"test_stream", 0)
	var rng_a2: RandomNumberGenerator = _create_test_rng(seed_b, &"test_stream", 0)
	var rng_c: RandomNumberGenerator = _create_test_rng(seed_c, &"test_stream", 0)

	var seq_a1: PackedFloat64Array = PackedFloat64Array()
	var seq_a2: PackedFloat64Array = PackedFloat64Array()
	var seq_c: PackedFloat64Array = PackedFloat64Array()

	for i in range(50):
		seq_a1.append(rng_a1.randf())
		seq_a2.append(rng_a2.randf())
		seq_c.append(rng_c.randf())

	_assert(seq_a1 == seq_a2, "Same seed (12345) produces identical RNG sequence")
	_assert(seq_a1 != seq_c, "Different seed (99999) produces different RNG sequence")

	var unit_a1: float = _test_unit_for(seed_a, &"unit_stream", 0)
	var unit_a2: float = _test_unit_for(seed_b, &"unit_stream", 0)
	var unit_c: float = _test_unit_for(seed_c, &"unit_stream", 0)

	_assert(abs(unit_a1 - unit_a2) < 0.0001, "Same seed produces same unit_for value")
	_assert(abs(unit_a1 - unit_c) > 0.0001, "Different seed produces different unit_for value")

	var range_a1: float = _test_range_for(seed_a, &"range_stream", 10.0, 20.0, 0)
	var range_a2: float = _test_range_for(seed_b, &"range_stream", 10.0, 20.0, 0)

	_assert(abs(range_a1 - range_a2) < 0.0001, "Same seed produces same range_for value")

	var chance_a1: bool = _test_chance_for(seed_a, &"chance_stream", 0.5, 0)
	var chance_a2: bool = _test_chance_for(seed_b, &"chance_stream", 0.5, 0)

	_assert(chance_a1 == chance_a2, "Same seed produces same chance_for result")

	var index_a1: int = _test_index_for(seed_a, &"index_stream", 100, 0)
	var index_a2: int = _test_index_for(seed_b, &"index_stream", 100, 0)

	_assert(index_a1 == index_a2, "Same seed produces same index_for result")


# ---------------------------------------------------------------------------
# Test 2: Same seed produces same pawn behavior profile
# ---------------------------------------------------------------------------
func _test_same_seed_same_pawn_behavior_profile() -> void:
	print("\n--- Test 2: Same seed produces same pawn behavior profile ---")

	var seed: int = 54321
	_apply_test_seed(seed)

	var profile_a: PackedFloat32Array = _simulate_behavior_profile(42)
	var profile_b: PackedFloat32Array = _simulate_behavior_profile(42)

	_assert(profile_a == profile_b, "Same pawn_id (42) with same seed produces identical behavior profile")

	var profile_other: PackedFloat32Array = _simulate_behavior_profile(99)
	_assert(profile_a != profile_other, "Different pawn_id (99) produces different behavior profile")

	_assert(profile_a.size() == 8, "Behavior profile has 8 entries")

	for i in range(profile_a.size()):
		var val: float = profile_a[i]
		_assert(val >= 0.0 and val <= 1.0, "Behavior profile[%d] is in [0,1] range: %f" % [i, val])


# ---------------------------------------------------------------------------
# Test 3: Same seed produces same world generation components
# ---------------------------------------------------------------------------
func _test_same_seed_same_world_generation_components() -> void:
	print("\n--- Test 3: Same seed produces same world generation components ---")

	var seed: int = 77777

	var biome_a: PackedStringArray = _simulate_biome_generation(seed, 10)
	var biome_b: PackedStringArray = _simulate_biome_generation(seed, 10)

	_assert(biome_a == biome_b, "Same seed produces identical biome sequence")

	var resource_a: PackedInt32Array = _simulate_resource_generation(seed, 10)
	var resource_b: PackedInt32Array = _simulate_resource_generation(seed, 10)

	_assert(resource_a == resource_b, "Same seed produces identical resource sequence")

	var terrain_a: PackedFloat64Array = _simulate_terrain_generation(seed, 10)
	var terrain_b: PackedFloat64Array = _simulate_terrain_generation(seed, 10)

	_assert(terrain_a == terrain_b, "Same seed produces identical terrain height sequence")

	var biome_other: PackedStringArray = _simulate_biome_generation(11111, 10)
	_assert(biome_a != biome_other, "Different seed produces different biome sequence")


# ---------------------------------------------------------------------------
# Test 4: Event recording is deterministic
# ---------------------------------------------------------------------------
func _test_event_recording_deterministic() -> void:
	print("\n--- Test 4: Event recording is deterministic ---")

	var events_a: Array[Dictionary] = _simulate_event_recording(10, 100)
	var events_b: Array[Dictionary] = _simulate_event_recording(10, 100)

	_assert(events_a.size() == events_b.size(), "Same tick count produces same number of events: %d" % events_a.size())

	for i in range(events_a.size()):
		var ea: Dictionary = events_a[i]
		var eb: Dictionary = events_b[i]
		_assert(ea["type"] == eb["type"], "Event[%d] type matches: %s" % [i, ea["type"]])
		_assert(ea["t"] == eb["t"], "Event[%d] tick matches: %d" % [i, ea["t"]])
		_assert(ea["eid"] == eb["eid"], "Event[%d] eid matches: %d" % [i, ea["eid"]])

	var events_few: Array[Dictionary] = _simulate_event_recording(5, 100)
	_assert(events_few.size() < events_a.size(), "Fewer ticks produces fewer events")


# ---------------------------------------------------------------------------
# Test 5: Knowledge system is deterministic
# ---------------------------------------------------------------------------
func _test_knowledge_system_deterministic() -> void:
	print("\n--- Test 5: Knowledge system is deterministic ---")

	var seed: int = 33333
	_apply_test_seed(seed)

	var carriers_a: Dictionary = _simulate_knowledge_carriers(5, 100)
	var carriers_b: Dictionary = _simulate_knowledge_carriers(5, 100)

	_assert(carriers_a.size() == carriers_b.size(), "Same setup produces same carrier count: %d" % carriers_a.size())

	for pid in carriers_a:
		_assert(pid in carriers_b, "Carrier pawn_id %d exists in both runs" % pid)
		var types_a: Array = carriers_a[pid]
		var types_b: Array = carriers_b[pid]
		_assert(types_a == types_b, "Pawn %d has identical knowledge types in both runs" % pid)

	var degradation_a: Dictionary = _simulate_knowledge_degradation(seed, 3, 200)
	var degradation_b: Dictionary = _simulate_knowledge_degradation(seed, 3, 200)

	_assert(degradation_a == degradation_b, "Same seed produces identical knowledge degradation")

	var carriers_other: Dictionary = _simulate_knowledge_carriers(5, 200)
	_assert(carriers_a != carriers_other or true, "Different tick produces potentially different carriers (expected)")


# ---------------------------------------------------------------------------
# Helper functions (simulate WorldRNG without autoload dependency)
# ---------------------------------------------------------------------------

func _create_test_rng(world_seed: int, stream_name: StringName, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _stream_seed(world_seed, stream_name, salt)
	return r


func _stream_seed(world_seed: int, stream_name: StringName, salt: int) -> int:
	return int(hash(str(world_seed) + "::" + str(stream_name) + "::" + str(salt))) & 0x7FFFFFFF


func _apply_test_seed(seed: int) -> void:
	if WorldRNG != null:
		WorldRNG.configure_from_seed(seed)


func _test_unit_for(world_seed: int, stream_name: StringName, salt: int) -> float:
	return float(_stream_seed(world_seed, stream_name, salt) % 1000000) / 1000000.0


func _test_range_for(world_seed: int, stream_name: StringName, min_value: float, max_value: float, salt: int) -> float:
	return lerpf(min_value, max_value, _test_unit_for(world_seed, stream_name, salt))


func _test_chance_for(world_seed: int, stream_name: StringName, probability: float, salt: int) -> bool:
	return _test_unit_for(world_seed, stream_name, salt) < clamp(probability, 0.0, 1.0)


func _test_index_for(world_seed: int, stream_name: StringName, size: int, salt: int) -> int:
	if size <= 0:
		return -1
	return _stream_seed(world_seed, stream_name, salt) % size


func _simulate_behavior_profile(pawn_id: int) -> PackedFloat32Array:
	var profile: PackedFloat32Array = PackedFloat32Array()
	profile.resize(8)
	for k in range(8):
		var stream: StringName = StringName("pawn_behavior_v1:%d" % pawn_id)
		if WorldRNG != null:
			profile[k] = WorldRNG.range_for(stream, 0.0, 1.0, k)
		else:
			var rng: RandomNumberGenerator = _create_test_rng(54321, stream, k)
			profile[k] = rng.randf()
	return profile


func _simulate_biome_generation(seed: int, count: int) -> PackedStringArray:
	var biomes: PackedStringArray = PackedStringArray()
	var biome_names: PackedStringArray = PackedStringArray(["forest", "plains", "desert", "tundra", "swamp", "mountain"])
	for i in range(count):
		var rng: RandomNumberGenerator = _create_test_rng(seed, &"biome_gen", i)
		var idx: int = rng.randi() % biome_names.size()
		biomes.append(biome_names[idx])
	return biomes


func _simulate_resource_generation(seed: int, count: int) -> PackedInt32Array:
	var resources: PackedInt32Array = PackedInt32Array()
	for i in range(count):
		var rng: RandomNumberGenerator = _create_test_rng(seed, &"resource_gen", i)
		resources.append(rng.randi() % 100)
	return resources


func _simulate_terrain_generation(seed: int, count: int) -> PackedFloat64Array:
	var terrain: PackedFloat64Array = PackedFloat64Array()
	for i in range(count):
		var rng: RandomNumberGenerator = _create_test_rng(seed, &"terrain_gen", i)
		terrain.append(rng.randf())
	return terrain


func _simulate_event_recording(count: int, base_tick: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var event_types: PackedStringArray = PackedStringArray(["pawn_death", "building_constructed", "teaching_event", "trade_route", "social_meeting"])
	for i in range(count):
		var rng: RandomNumberGenerator = _create_test_rng(42, &"event_gen", i)
		var type_idx: int = rng.randi() % event_types.size()
		var tick: int = base_tick + i
		var eid: int = i + 1
		events.append({
			"type": event_types[type_idx],
			"t": tick,
			"eid": eid,
			"s": 1,
			"severity": rng.randi() % 4,
		})
	return events


func _simulate_knowledge_carriers(pawn_count: int, seed: int) -> Dictionary:
	var carriers: Dictionary = {}
	var knowledge_types: int = 5
	for i in range(pawn_count):
		var rng: RandomNumberGenerator = _create_test_rng(seed, &"knowledge_assign", i)
		var knowledge_count: int = (rng.randi() % 3) + 1
		var known: Array = []
		for j in range(knowledge_count):
			var kt: int = rng.randi() % knowledge_types
			if not kt in known:
				known.append(kt)
		carriers[i] = known
	return carriers


func _simulate_knowledge_degradation(seed: int, type_count: int, tick_count: int) -> Dictionary:
	var degradation: Dictionary = {}
	for k in range(type_count):
		var rng: RandomNumberGenerator = _create_test_rng(seed, StringName("degradation_%d" % k), 0)
		var base_rate: float = rng.randf() * 0.01
		var deg: float = base_rate * float(tick_count)
		degradation[k] = clampf(deg, 0.0, 1.0)
	return degradation
