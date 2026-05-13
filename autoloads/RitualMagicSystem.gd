extends Node
## RitualMagicSystem — World-sourced ritual magic from ley lines and sacred sites.
## No fireballs. Magic is subtle, slow, costly — tied to place, memory, and community.
## Ley lines are natural energy flows across the map. Sacred sites are places
## where ley lines converge + enough world memory density.
## Rituals are community actions that cost resources and time, producing subtle effects:
##   - Blessing: +mood, +crop yield for a season
##   - Warding: animals avoid area, minor disaster resistance
##   - Remembrance: preserve knowledge in the land itself
##   - Binding: create a lasting cultural commitment (no violence here)
## All magic is deterministic and recorded in WorldMemory.

enum LeyLineType {
	ENERGY,    # generic life energy
	MEMORY,    # carries historical resonance
	GROWTH,    # fertility, harvest
	STILLNESS, # calm, peace, healing
}

const LEY_NAME: Dictionary = {
	LeyLineType.ENERGY: "energy",
	LeyLineType.MEMORY: "memory",
	LeyLineType.GROWTH: "growth",
	LeyLineType.STILLNESS: "stillness",
}

enum RitualType {
	BLESSING,
	WARDING,
	REMEMBRANCE,
	BINDING,
}

const RITUAL_COST: Dictionary = {
	RitualType.BLESSING: {"food": 10, "wood": 5, "participants": 3, "duration": 200},
	RitualType.WARDING: {"stone": 8, "wood": 4, "participants": 2, "duration": 300},
	RitualType.REMEMBRANCE: {"knowledge": 1, "stone": 10, "participants": 4, "duration": 500},
	RitualType.BINDING: {"food": 20, "stone": 15, "participants": 6, "duration": 400},
}

var ley_lines: Array = []
var sacred_sites: Array = []
var active_rituals: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_generate_ley_lines()

func _generate_ley_lines() -> void:
	if WorldRNG == null:
		return
	var seed_val: int = GameManager.tick_count if GameManager != null else 0
	for i in range(6):
		var start_x: int = WorldRNG.rangei(&"ley_start_x", 5, WorldData.WIDTH - 5, i * 2)
		var start_y: int = WorldRNG.rangei(&"ley_start_y", 5, WorldData.HEIGHT - 5, i * 2 + 1)
		var end_x: int = WorldRNG.rangei(&"ley_end_x", 5, WorldData.WIDTH - 5, i * 3)
		var end_y: int = WorldRNG.rangei(&"ley_end_y", 5, WorldData.HEIGHT - 5, i * 3 + 1)
		var ltype: int = i % 4
		ley_lines.append({
			"start": Vector2i(start_x, start_y),
			"end": Vector2i(end_x, end_y),
			"type": ltype,
			"strength": 0.5 + float(i) * 0.1,
		})
	for ll in ley_lines:
		_check_for_sacred_site(ll)

func _check_for_sacred_site(ll: Dictionary) -> void:
	var mid: Vector2i = Vector2i(
		int((ll.start.x + ll.end.x) / 2),
		int((ll.start.y + ll.end.y) / 2)
	)
	var key: String = "%d,%d" % [mid.x, mid.y]
	for site in sacred_sites:
		if site.get("tile_key") == key:
			site["ley_count"] = int(site.get("ley_count", 0)) + 1
			return
	sacred_sites.append({
		"tile": mid,
		"tile_key": key,
		"ley_count": 1,
		"memorial_count": 0,
		"rituals_performed": 0,
	})

func get_sacred_site_at(tile: Vector2i) -> Dictionary:
	var key: String = "%d,%d" % [tile.x, tile.y]
	for site in sacred_sites:
		if site.get("tile_key") == key:
			return site
	return {}

func get_ley_line_at(tile: Vector2i) -> Dictionary:
	for ll in ley_lines:
		var dx: int = absi(ll.end.x - ll.start.x)
		var dy: int = absi(ll.end.y - ll.start.y)
		var steps: int = maxi(dx, dy)
		if steps == 0:
			continue
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var px: int = int(ll.start.x + t * (ll.end.x - ll.start.x))
			var py: int = int(ll.start.y + t * (ll.end.y - ll.start.y))
			if px == tile.x and py == tile.y:
				return ll
	return {}

func start_ritual(ritual_type: int, tile: Vector2i, participants: Array) -> bool:
	var cost: Dictionary = RITUAL_COST.get(ritual_type, {})
	if participants.size() < int(cost.get("participants", 3)):
		return false
	var ritual_id: int = int(WorldRNG.rangei(&"ritual_id", 1, 99999, GameManager.tick_count if GameManager != null else 0))
	active_rituals[ritual_id] = {
		"type": ritual_type,
		"tile": tile,
		"participants": participants,
		"tick_started": GameManager.tick_count if GameManager != null else 0,
		"duration": cost.get("duration", 200),
		"progress": 0,
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"ritual_started": true,
		"ritual_type": ritual_type,
		"tile_x": tile.x, "tile_y": tile.y,
	})
	return true

func _on_game_tick(tick: int) -> void:
	if tick % 100 != 0:
		return
	_process_active_rituals(tick)

func _process_active_rituals(tick: int) -> void:
	var completed: Array = []
	for rid in active_rituals:
		var r: Dictionary = active_rituals[rid]
		r["progress"] = int(r.get("progress", 0)) + 100
		if int(r.get("progress", 0)) >= int(r.get("duration", 200)):
			completed.append(rid)
			_complete_ritual(rid, r, tick)
	for rid in completed:
		active_rituals.erase(rid)

func _complete_ritual(rid: int, r: Dictionary, tick: int) -> void:
	var rtype: int = int(r.get("type", 0))
	var tile: Vector2i = r.get("tile", Vector2i())
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": tick,
		"ritual_completed": true,
		"ritual_type": rtype,
		"tile_x": tile.x, "tile_y": tile.y,
	})
	var site: Dictionary = get_sacred_site_at(tile)
	if not site.is_empty():
		site["rituals_performed"] = int(site.get("rituals_performed", 0)) + 1

func get_active_rituals() -> Array:
	return active_rituals.values()
