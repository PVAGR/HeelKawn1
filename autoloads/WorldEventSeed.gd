# WorldEventSeed.gd
class_name WorldEventSeedData
# Lightweight representation of a deterministic event seed
extends RefCounted

var seed_id: String
var seed_type: String
var seed_value: int
var last_tick: int
var params: Dictionary = {}

func _init(_seed_id: String, _seed_type: String, _seed_value: int, _params: Dictionary = {}):
    seed_id = _seed_id
    seed_type = _seed_type
    seed_value = _seed_value
    last_tick = 0
    params = _params

func next_event(current_tick: int) -> Dictionary:
    # Minimal deterministic stub: produce a simple event payload
    if current_tick <= last_tick:
        return {}
    last_tick = current_tick
    return {
        "seed_id": seed_id,
        "type": seed_type,
        "payload": {
            "seed_value": seed_value,
            "params": params
        },
        "timestamp": current_tick
    }

static func new_seed(seed_id: String, seed_type: String, seed_value: int, params: Dictionary = {}) -> WorldEventSeedData:
    return WorldEventSeedData.new(seed_id, seed_type, seed_value, params)
