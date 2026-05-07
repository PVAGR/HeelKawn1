## WorldEventSeedManager.gd
## Simple registry for deterministic world event seeds
extends Node

var _seeds := {}

## Ensure default seeds exist (idempotent)
func ensure_default_seeds() -> void:
    if not _seeds.has("seasonal_1"):
        var SeedClass = preload("res://autoloads/WorldEventSeed.gd")
        var s = SeedClass.new("seasonal_1", "SeasonalSeed", 42, {"season_id": 1})
        _seeds["seasonal_1"] = s
    if not _seeds.has("social_1"):
        var SeedClass2 = preload("res://autoloads/WorldEventSeed.gd")
        var s2 = SeedClass2.new("social_1", "SocialSeed", 7, {"density": 0.2})
        _seeds["social_1"] = s2

func register_seed(seed_id: String, seed_type: String, seed_value: int, params: Dictionary = {}) -> void:
    var SeedClass = preload("res://autoloads/WorldEventSeed.gd")
    var s = SeedClass.new(seed_id, seed_type, seed_value, params)
    _seeds[seed_id] = s

func get_seed(seed_id: String) -> WorldEventSeed:
    return _seeds.get(seed_id, null)

func advance_all(current_tick: int) -> Array:
    var events := []
    for seed_id in _seeds.keys():
        var seed = _seeds[seed_id]
        if seed:
            var e = seed.next_event(current_tick)
            if e:
                events.append(e)
    return events

func describe_seed(seed_id: String) -> String:
    var s = _seeds.get(seed_id, null)
    if s:
        return "%s:%s" % [seed_id, s.seed_type]
    return "Unknown"
