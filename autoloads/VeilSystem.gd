extends Node
## VeilSystem — metaphysical barrier between the mortal realm and the supernatural.
## Thickness (0.0–100.0) governs permeability: thin = spirits walk, thick = mundane safe.
## Regional variation, thin spots, rends, natural fluctuation, and full deterministic replay.

const VEIL_CHECK_INTERVAL: int = 4000
const FLUCTUATION_INTERVAL: int = 1000
const FLUCTUATION_AMPLITUDE: float = 3.0
const FLUCTUATION_PERIOD_TICKS: float = 120000.0
const DEFAULT_THICKNESS: float = 50.0
const MAX_THIN_SPOTS: int = 40
const MAX_RENDS: int = 10
const REND_DECAY_RATE: float = 0.02
const THIN_SPOT_GEN_RADIUS: int = 10
const OVERLAP_MERGE_RADIUS: int = 3
const EVENT_THINNING_THRESHOLD: float = 25.0
const EVENT_TEAR_THRESHOLD: float = 10.0
const EVENT_RESTORATION_THRESHOLD: float = 70.0
const ASHA_THICKEN_RATE: float = 0.15
const DRUJ_THIN_RATE: float = 0.25
const ECHO_AMPLIFY_RATE: float = 0.02
const MIN_TICK_DELTA: int = 1
const SENSE_RADIUS: int = 8
const PAWN_SENSE_COOLDOWN: int = 2000

enum ThinSpotType {
	ANCIENT_BATTLEFIELD = 0,
	SACRED_SITE = 1,
	DISASTER_ZONE = 2,
	MASS_GRAVE = 3,
	LEY_NODE = 4,
	FAERIE_CROSSING = 5,
	DEEP_GROVE = 6,
	ANCIENT_RUIN = 7,
}

enum RendCause {
	CATACLYSM = 0,
	MASS_DEATH = 1,
	DARK_RITUAL = 2,
	DRUJ_ASCENDANCY = 3,
	ECHO_OVERLOAD = 4,
	UNKNOWN = 5,
}

enum VeilEventType {
	THINNING = 0,
	TEAR = 1,
	RESTORATION = 2,
}

class ThinSpot:
	var location: Vector2i
	var radius: int
	var thinness: float
	var spot_type: int
	var creation_tick: int
	var persistent: bool

	func _init(loc: Vector2i, rad: int, thin: float, stype: int, tick: int, persist: bool = false) -> void:
		location = loc
		radius = maxi(rad, 1)
		thinness = clampf(thin, 0.0, 100.0)
		spot_type = clampi(stype, 0, ThinSpotType.size() - 1)
		creation_tick = tick
		persistent = persist

	func to_dict() -> Dictionary:
		return {
			"location_x": location.x,
			"location_y": location.y,
			"radius": radius,
			"thinness": thinness,
			"spot_type": spot_type,
			"creation_tick": creation_tick,
			"persistent": persistent,
		}

	static func from_dict(d: Dictionary) -> ThinSpot:
		var s := ThinSpot.new(
			Vector2i(int(d.get("location_x", 0)), int(d.get("location_y", 0))),
			int(d.get("radius", 3)),
			float(d.get("thinness", 30.0)),
			int(d.get("spot_type", 0)),
			int(d.get("creation_tick", 0)),
			bool(d.get("persistent", false))
		)
		return s

class Rend:
	var location: Vector2i
	var severity: float
	var creation_tick: int
	var duration: int
	var cause: int
	var active: bool

	func _init(loc: Vector2i, sev: float, tick: int, dur: int, cau: int = RendCause.UNKNOWN) -> void:
		location = loc
		severity = clampf(sev, 0.0, 100.0)
		creation_tick = tick
		duration = maxi(dur, 1)
		cause = clampi(cau, 0, RendCause.size() - 1)
		active = true

	func age_frac(current_tick: int) -> float:
		return clampf(float(current_tick - creation_tick) / float(duration), 0.0, 1.0)

	func is_expired(current_tick: int) -> bool:
		return current_tick - creation_tick >= duration

	func current_severity(current_tick: int) -> float:
		var af: float = age_frac(current_tick)
		return clampf(severity * (1.0 - af), 0.0, severity)

	func to_dict() -> Dictionary:
		return {
			"location_x": location.x,
			"location_y": location.y,
			"severity": severity,
			"creation_tick": creation_tick,
			"duration": duration,
			"cause": cause,
			"active": active,
		}

	static func from_dict(d: Dictionary) -> Rend:
		var r := Rend.new(
			Vector2i(int(d.get("location_x", 0)), int(d.get("location_y", 0))),
			float(d.get("severity", 30.0)),
			int(d.get("creation_tick", 0)),
			int(d.get("duration", 10000)),
			int(d.get("cause", RendCause.UNKNOWN))
		)
		r.active = bool(d.get("active", true))
		return r

class PawnSenseRecord:
	var pawn_id: int
	var last_sense_tick: int
	var sensed_thickness: float
	var sensed_thin_spots: Array
	var sensed_rends: Array

	func _init(pid: int) -> void:
		pawn_id = pid
		last_sense_tick = -999999
		sensed_thickness = 50.0
		sensed_thin_spots = []
		sensed_rends = []

var _thickness: float = DEFAULT_THICKNESS
var _last_update_tick: int = -999999
var _last_fluctuation_tick: int = -999999
var _thin_spots: Array[ThinSpot] = []
var _rends: Array[Rend] = []
var _total_fluctuation_offset: float = 0.0
var _era_shift: float = 0.0
var _world_created: bool = false
var _recent_events: Array[Dictionary] = []
var _pawn_sense_records: Dictionary = {}
var _initialized: bool = false

signal veil_thickness_changed(thickness: float, delta: float, reason: String)
signal thin_spot_detected(spot: Dictionary)
signal veil_rended(rend: Dictionary)
signal veil_restored(thickness: float)
signal veil_event(event_type: int, payload: Dictionary)
signal pawn_sensed_veil(pawn_id: int, sensed_thickness: float, has_thin_spot: bool, has_rend: bool)

func _ready() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

	if EventBus != null:
		if EventBus.has_method("subscribe"):
			EventBus.subscribe("cataclysm_started", self, "_on_cataclysm_event")
			EventBus.subscribe("disaster_started", self, "_on_disaster_event")
			EventBus.subscribe("mass_death", self, "_on_mass_death_event")
			EventBus.subscribe("dark_ritual", self, "_on_dark_ritual_event")
			EventBus.subscribe("world_created", self, "_on_world_created")

func _on_game_tick(tick: int) -> void:
	if not _initialized:
		_initialize(tick)
		_initialized = true
	var dt: int = tick - _last_update_tick
	if dt < VEIL_CHECK_INTERVAL:
		return
	_last_update_tick = tick
	if dt < MIN_TICK_DELTA:
		dt = MIN_TICK_DELTA
	_update_thin_spots(tick)
	_update_rends(tick)
	_apply_fluctuation(tick)
	_apply_asha_druj_influence(tick)
	_apply_echo_influence(tick)
	_check_veil_events(tick)
	_garbage_collect_pawn_senses(tick)

func _initialize(tick: int) -> void:
	if _world_created:
		return
	_world_created = true
	if WorldRNG != null:
		var rng: RandomNumberGenerator = WorldRNG.rng_for(&"VeilSystem:genesis", tick)
		_era_shift = rng.randf_range(-10.0, 10.0)
		_thickness = DEFAULT_THICKNESS + _era_shift
		_thickness = clampf(_thickness, 0.0, 100.0)
		var spot_count: int = rng.randi_range(5, MAX_THIN_SPOTS)
		var map_extent: int = 256
		for i in spot_count:
			var loc := Vector2i(rng.randi_range(-map_extent, map_extent), rng.randi_range(-map_extent, map_extent))
			var radius: int = rng.randi_range(1, THIN_SPOT_GEN_RADIUS)
			var thinness: float = rng.randf_range(10.0, 60.0)
			var stype: int = rng.randi_range(0, ThinSpotType.size() - 1)
			var persist: bool = rng.randf() < 0.15
			_add_thin_spot(loc, radius, thinness, stype, tick, persist)
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "veil_world_initialized",
				"tick": tick,
				"thickness": _thickness,
				"thin_spots_generated": _thin_spots.size(),
				"era_shift": _era_shift,
			})
		if OS.is_debug_build():
			print("[VeilSystem] Initialized: thickness=%.1f spots=%d era_shift=%.1f" % [_thickness, _thin_spots.size(), _era_shift])
	else:
		_thickness = DEFAULT_THICKNESS
	_thickness = clampf(_thickness, 0.0, 100.0)

func _apply_fluctuation(tick: int) -> void:
	var dt: int = tick - _last_fluctuation_tick
	if dt < FLUCTUATION_INTERVAL:
		return
	_last_fluctuation_tick = tick
	var phase: float = float(tick) / FLUCTUATION_PERIOD_TICKS * TAU
	var sin_val: float = sin(phase) * FLUCTUATION_AMPLITUDE
	var noise_val: float = 0.0
	if WorldRNG != nil:
		noise_val = WorldRNG.range_for(&"VeilSystem:fluctuation", -1.0, 1.0, tick / 1000) * 0.5
	var fluctuation: float = sin_val + noise_val + _era_shift * 0.05
	_total_fluctuation_offset += fluctuation * 0.1
	var old: float = _thickness
	_thickness = clampf(_thickness + fluctuation * 0.1, 0.0, 100.0)
	var delta: float = _thickness - old
	if absf(delta) > 0.01:
		veil_thickness_changed.emit(_thickness, delta, "natural_fluctuation")
		if absf(delta) > 1.0 and WorldMemory != null:
			WorldMemory.record_event({
				"type": "veil_natural_fluctuation",
				"tick": tick,
				"thickness": _thickness,
				"delta": delta,
				"total_offset": _total_fluctuation_offset,
			})

func _apply_asha_druj_influence(tick: int) -> void:
	var ads := get_node_or_null("/root/AshaDrujSystem")
	if ads == null:
		return
	var asha: float = 0.0
	var druj: float = 0.0
	if ads.has_method("get_asha"):
		asha = ads.get_asha()
	if ads.has_method("get_druj"):
		druj = ads.get_druj()
	if asha <= 0.0 and druj <= 0.0:
		return
	var old: float = _thickness
	if asha > 55.0:
		var influence: float = (asha - 55.0) / 45.0 * ASHA_THICKEN_RATE
		_thickness = clampf(_thickness + influence, 0.0, 100.0)
	if druj > 55.0:
		var influence: float = (druj - 55.0) / 45.0 * DRUJ_THIN_RATE
		_thickness = clampf(_thickness - influence, 0.0, 100.0)
	var delta: float = _thickness - old
	if absf(delta) > 0.001 and WorldMemory != null:
		WorldMemory.record_event({
			"type": "veil_asha_druj_influence",
			"tick": tick,
			"thickness": _thickness,
			"delta": delta,
			"asha": asha,
			"druj": druj,
		})

func _apply_echo_influence(tick: int) -> void:
	var es := get_node_or_null("/root/EchoSystem")
	if es == null:
		return
	if not es.has_method("get_total_echoes"):
		return
	var echo_count: int = es.get_total_echoes()
	if echo_count <= 0:
		return
	var old: float = _thickness
	if echo_count > 30:
		var pressure: float = float(echo_count - 30) * ECHO_AMPLIFY_RATE
		var capped: float = minf(pressure, 3.0)
		_thickness = clampf(_thickness - capped * 0.05, 0.0, 100.0)
	var delta: float = _thickness - old
	if absf(delta) > 0.001 and WorldMemory != null:
		WorldMemory.record_event({
			"type": "veil_echo_influence",
			"tick": tick,
			"thickness": _thickness,
			"delta": delta,
			"echo_count": echo_count,
		})

func _update_thin_spots(tick: int) -> void:
	var to_remove: Array[int] = []
	for i in _thin_spots.size():
		var spot: ThinSpot = _thin_spots[i]
		if spot.persistent:
			continue
		var age: int = tick - spot.creation_tick
		var decay: float = float(age) / 200000.0
		spot.thinness = maxf(0.0, spot.thinness - decay)
		if spot.thinness <= 0.0:
			to_remove.append(i)
	for idx in to_remove:
		if _thin_spots[idx].persistent:
			continue
		_thin_spots.remove_at(idx)

func _update_rends(tick: int) -> void:
	var to_remove: Array[int] = []
	for i in _rends.size():
		var rend: Rend = _rends[i]
		if rend.is_expired(tick):
			var loc: Vector2i = rend.location
			to_remove.append(i)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "veil_rend_healed",
					"tick": tick,
					"location_x": loc.x,
					"location_y": loc.y,
					"severity": rend.severity,
					"duration": rend.duration,
					"cause": rend.cause,
				})
			veil_restored.emit(_thickness)
			veil_event.emit(VeilEventType.RESTORATION, {
				"tick": tick,
				"location_x": loc.x,
				"location_y": loc.y,
				"severity": rend.severity,
				"cause": rend.cause,
			})
			_append_recent_event("rend_healed", tick, {"x": loc.x, "y": loc.y})
	for idx in to_remove:
		var rend: Rend = _rends[idx]
		var final_sev: float = rend.current_severity(tick)
		if not EventBus == null and EventBus.has_method("emit"):
			EventBus.emit("veil_restored", {
				"tick": tick,
				"location_x": rend.location.x,
				"location_y": rend.location.y,
				"restored_severity": final_sev,
			})
		_rends.remove_at(idx)
	for rend in _rends:
		if not rend.active:
			continue
		var current_sev: float = rend.current_severity(tick)
		var local_influence: float = current_sev * 0.01
		var old: float = _thickness
		_thickness = clampf(_thickness - local_influence, 0.0, 100.0)

func _check_veil_events(tick: int) -> void:
	if _thickness <= EVENT_TEAR_THRESHOLD and _rends.is_empty():
		var rloc: Vector2i
		if _thin_spots.size() > 0:
			var idx: int = WorldRNG.index_for(&"VeilSystem:tear_loc", _thin_spots.size(), tick) if WorldRNG != null else 0
			rloc = _thin_spots[clampi(idx, 0, _thin_spots.size() - 1)].location
		else:
			rloc = Vector2i(WorldRNG.rangei(-128, 128, tick) if WorldRNG != null else 0, WorldRNG.rangei(-128, 128, tick + 1) if WorldRNG != null else 0)
		_create_rend(rloc, 40.0 + (50.0 - _thickness) * 0.5, tick, 15000 + int((100.0 - _thickness) * 200.0), RendCause.UNKNOWN)
		veil_event.emit(VeilEventType.TEAR, {
			"tick": tick,
			"location_x": rloc.x,
			"location_y": rloc.y,
			"thickness": _thickness,
		})
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "veil_spontaneous_tear",
				"tick": tick,
				"thickness": _thickness,
				"location_x": rloc.x,
				"location_y": rloc.y,
			})
	elif _thickness <= EVENT_THINNING_THRESHOLD:
		veil_event.emit(VeilEventType.THINNING, {
			"tick": tick,
			"thickness": _thickness,
		})
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "veil_thinning_event",
				"tick": tick,
				"thickness": _thickness,
			})
	elif _thickness >= EVENT_RESTORATION_THRESHOLD and _rends.is_empty():
		veil_event.emit(VeilEventType.RESTORATION, {
			"tick": tick,
			"thickness": _thickness,
		})

func _on_cataclysm_event(payload: Dictionary) -> void:
	var p: Dictionary = payload if payload is Dictionary else {}
	var tick: int = int(p.get("tick", GameManager.tick_count if GameManager != null else 0))
	var severity: int = int(p.get("severity", 5))
	var loc: Vector2i = Vector2i(
		int(p.get("location_x", int(p.get("x", -1)))),
		int(p.get("location_y", int(p.get("y", -1))))
	)
	if loc.x < 0 or loc.y < 0:
		loc = Vector2i(
			WorldRNG.rangei(-128, 128, tick) if WorldRNG != null else 0,
			WorldRNG.rangei(-128, 128, tick + 1) if WorldRNG != null else 0
		)
	var rend_severity: float = clampf(float(severity) * 6.0, 10.0, 90.0)
	var duration: int = clampf(severity * 4000, 5000, 80000)
	_create_rend(loc, rend_severity, tick, int(duration), RendCause.CATACLYSM)

func _on_disaster_event(payload: Dictionary) -> void:
	var p: Dictionary = payload if payload is Dictionary else {}
	var tick: int = int(p.get("tick", GameManager.tick_count if GameManager != null else 0))
	var severity: int = int(p.get("severity", 3))
	var loc: Vector2i = Vector2i(
		int(p.get("location_x", int(p.get("x", -1)))),
		int(p.get("location_y", int(p.get("y", -1))))
	)
	if loc.x < 0 or loc.y < 0:
		return
	var rend_severity: float = clampf(float(severity) * 4.0, 5.0, 60.0)
	var duration: int = clampf(severity * 3000, 3000, 50000)
	_create_rend(loc, rend_severity, tick, int(duration), RendCause.CATACLYSM)

func _on_mass_death_event(payload: Dictionary) -> void:
	var p: Dictionary = payload if payload is Dictionary else {}
	var tick: int = int(p.get("tick", GameManager.tick_count if GameManager != null else 0))
	var count: int = int(p.get("count", 10))
	var loc: Vector2i = Vector2i(
		int(p.get("location_x", int(p.get("x", -1)))),
		int(p.get("location_y", int(p.get("y", -1))))
	)
	if loc.x < 0 or loc.y < 0 or count < 5:
		return
	var rend_severity: float = clampf(float(count) * 0.8, 5.0, 75.0)
	var duration: int = clampf(count * 500, 2000, 60000)
	_create_rend(loc, rend_severity, tick, int(duration), RendCause.MASS_DEATH)

func _on_dark_ritual_event(payload: Dictionary) -> void:
	var p: Dictionary = payload if payload is Dictionary else {}
	var tick: int = int(p.get("tick", GameManager.tick_count if GameManager != null else 0))
	var power: float = float(p.get("power", 5.0))
	var loc: Vector2i = Vector2i(
		int(p.get("location_x", int(p.get("x", -1)))),
		int(p.get("location_y", int(p.get("y", -1))))
	)
	if loc.x < 0 or loc.y < 0:
		return
	if power < 3.0:
		_add_thin_spot(loc, 2, power * 5.0, ThinSpotType.FAERIE_CROSSING, tick, false)
		return
	var rend_severity: float = clampf(power * 5.0, 10.0, 95.0)
	var duration: int = clampf(int(power) * 5000, 5000, 100000)
	_create_rend(loc, rend_severity, tick, int(duration), RendCause.DARK_RITUAL)

func _on_world_created(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", 0) if payload is Dictionary else 0)
	if not _initialized:
		_initialize(tick)
		_initialized = true

func _create_rend(loc: Vector2i, severity: float, tick: int, duration: int, cause: int) -> void:
	if _rends.size() >= MAX_RENDS:
		var oldest_idx: int = 0
		var oldest_tick: int = _rends[0].creation_tick if _rends.size() > 0 else tick
		for i in _rends.size():
			if _rends[i].creation_tick < oldest_tick:
				oldest_tick = _rends[i].creation_tick
				oldest_idx = i
		_rends.remove_at(oldest_idx)
	var rend := Rend.new(loc, severity, tick, duration, cause)
	_rends.append(rend)
	var veil_tear: float = severity * 0.3
	_thickness = clampf(_thickness - veil_tear, 0.0, 100.0)
	var rend_dict: Dictionary = rend.to_dict()
	veil_rended.emit(rend_dict)
	veil_event.emit(VeilEventType.TEAR, rend_dict)
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "veil_rend_created",
			"tick": tick,
			"location_x": loc.x,
			"location_y": loc.y,
			"severity": severity,
			"duration": duration,
			"cause": cause,
		})
	if not EventBus == null and EventBus.has_method("emit"):
		EventBus.emit("veil_rended", rend_dict)
	_append_recent_event("rend_created", tick, {"x": loc.x, "y": loc.y, "sev": severity})

func _add_thin_spot(loc: Vector2i, radius: int, thinness: float, stype: int, tick: int, persist: bool = false) -> void:
	if _thin_spots.size() >= MAX_THIN_SPOTS:
		return
	for existing in _thin_spots:
		var dist: float = existing.location.distance_to(loc)
		if dist <= float(OVERLAP_MERGE_RADIUS):
			var overlap: float = float(OVERLAP_MERGE_RADIUS) - dist
			if overlap > 0.0:
				var ratio: float = overlap / float(OVERLAP_MERGE_RADIUS)
				existing.thinness = clampf(existing.thinness + thinness * ratio * 0.5, 0.0, 100.0)
				existing.radius = maxi(existing.radius, radius)
			return
	var spot := ThinSpot.new(loc, radius, thinness, stype, tick, persist)
	_thin_spots.append(spot)

func thin_veil(amount: float, tick: int, location: Vector2i = Vector2i(-1, -1)) -> void:
	if amount <= 0.0:
		return
	var old: float = _thickness
	_thickness = clampf(_thickness - amount, 0.0, 100.0)
	var delta: float = _thickness - old
	veil_thickness_changed.emit(_thickness, delta, "manual_thin")
	if delta < -0.5:
		_append_recent_event("veil_thinned", tick, {"amount": amount})
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "veil_thinned",
				"tick": tick,
				"thickness": _thickness,
				"delta": delta,
				"location_x": location.x if location.x >= 0 else null,
				"location_y": location.y if location.y >= 0 else null,
			})
	if location.x >= 0:
		var thin_val: float = clampf(amount * 2.0, 1.0, 100.0)
		for existing in _thin_spots:
			var dist: float = existing.location.distance_to(location)
			if dist <= float(OVERLAP_MERGE_RADIUS):
				existing.thinness = clampf(existing.thinness + thin_val * 0.3, 0.0, 100.0)
				return
		var stype: int = ThinSpotType.DISASTER_ZONE
		if WorldRNG != null:
			stype = WorldRNG.index_for(&"VeilSystem:thin_type", ThinSpotType.size(), tick)
		_add_thin_spot(location, 2, thin_val, stype, tick, false)

func thicken_veil(amount: float, tick: int) -> void:
	if amount <= 0.0:
		return
	var old: float = _thickness
	_thickness = clampf(_thickness + amount, 0.0, 100.0)
	var delta: float = _thickness - old
	veil_thickness_changed.emit(_thickness, delta, "manual_thicken")
	if delta > 0.5 and WorldMemory != null:
		WorldMemory.record_event({
			"type": "veil_thickened",
			"tick": tick,
			"thickness": _thickness,
			"delta": delta,
		})

func create_thin_spot(loc: Vector2i, radius: int, thinness: float, stype: int, tick: int, persist: bool = false) -> void:
	if loc.x < 0 or loc.y < 0:
		return
	radius = maxi(radius, 1)
	thinness = clampf(thinness, 1.0, 100.0)
	stype = clampi(stype, 0, ThinSpotType.size() - 1)
	_add_thin_spot(loc, radius, thinness, stype, tick, persist)
	var spot_dict: Dictionary = {"location": loc, "radius": radius, "thinness": thinness, "type": stype}
	thin_spot_detected.emit(spot_dict)
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "veil_thin_spot_created",
			"tick": tick,
			"location_x": loc.x,
			"location_y": loc.y,
			"radius": radius,
			"thinness": thinness,
			"spot_type": stype,
			"persistent": persist,
		})

func get_thickness_at(region: Vector2i) -> float:
	var base: float = _thickness
	var min_thickness: float = base
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(region)
		if dist <= float(spot.radius):
			var falloff: float = 1.0 - (dist / float(spot.radius))
			var local_thin: float = spot.thinness * falloff * 0.5
			min_thickness = minf(min_thickness, base - local_thin)
	for rend in _rends:
		if not rend.active:
			continue
		var dist: float = rend.location.distance_to(region)
		if dist <= 50.0:
			var falloff: float = 1.0 - (dist / 50.0)
			var rend_effect: float = rend.severity * falloff * 0.6
			min_thickness = minf(min_thickness, base - rend_effect)
	return clampf(min_thickness, 0.0, 100.0)

func get_thickness() -> float:
	return _thickness

func get_veil_thickness_description() -> String:
	if _thickness >= 90.0:
		return "The Veil is nearly sealed. The spirit world is utterly distant."
	elif _thickness >= 70.0:
		return "The Veil is thick. The supernatural recedes."
	elif _thickness >= 50.0:
		return "The Veil holds steady at normal levels."
	elif _thickness >= 35.0:
		return "The Veil thins. Whispers echo from beyond."
	elif _thickness >= 20.0:
		return "The Veil is dangerously thin. Spirits brush against the living world."
	elif _thickness >= 5.0:
		return "The Veil is torn! Supernatural forces press through every gap."
	else:
		return "THE VEIL IS OPEN. The mortal realm drowns in the supernatural."

func get_thin_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spot in _thin_spots:
		out.append(spot.to_dict())
	return out

func get_rends() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rend in _rends:
		out.append(rend.to_dict())
	return out

func get_thin_spot_at(tile: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_thinness: float = 0.0
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(tile)
		if dist <= float(spot.radius):
			var local_intensity: float = spot.thinness * (1.0 - dist / float(spot.radius))
			if local_intensity > best_thinness:
				best_thinness = local_intensity
				best = spot.to_dict()
	return best

func is_thin_at(tile: Vector2i) -> bool:
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(tile)
		if dist <= float(spot.radius) and spot.thinness > 15.0:
			return true
	return false

func get_thin_spot_intensity(tile: Vector2i) -> float:
	var max_intensity: float = 0.0
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(tile)
		if dist <= float(spot.radius):
			var local: float = spot.thinness * (1.0 - dist / float(spot.radius))
			max_intensity = maxf(max_intensity, local)
	return max_intensity

func get_rend_at(tile: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_sev: float = 0.0
	for rend in _rends:
		if not rend.active:
			continue
		var dist: float = rend.location.distance_to(tile)
		if dist <= 30.0:
			var current_sev: float = rend.current_severity(GameManager.tick_count if GameManager != null else 0)
			var local: float = current_sev * (1.0 - dist / 30.0)
			if local > best_sev:
				best_sev = local
				best = rend.to_dict()
	return best

func is_rend_at(tile: Vector2i) -> bool:
	for rend in _rends:
		if not rend.active:
			continue
		if rend.location.distance_to(tile) <= 30.0:
			return true
	return false

func get_ritual_power_multiplier(tile: Vector2i) -> float:
	var base: float = 1.0
	if _thickness < 50.0:
		base += (50.0 - _thickness) * 0.015
	elif _thickness > 70.0:
		base -= (_thickness - 70.0) * 0.01
	var thin_intensity: float = get_thin_spot_intensity(tile)
	if thin_intensity > 0.0:
		base += thin_intensity * 0.008
	var rend_dict: Dictionary = get_rend_at(tile)
	if not rend_dict.is_empty():
		var rend_sev: float = float(rend_dict.get("severity", 0.0))
		base += rend_sev * 0.01
	return clampf(base, 0.1, 5.0)

func get_echo_power_multiplier(tile: Vector2i) -> float:
	var base: float = 1.0
	if _thickness < 50.0:
		base += (50.0 - _thickness) * 0.01
	elif _thickness > 80.0:
		base = maxf(0.1, base - (_thickness - 80.0) * 0.02)
	var thin_intensity: float = get_thin_spot_intensity(tile)
	if thin_intensity > 0.0:
		base += thin_intensity * 0.006
	return clampf(base, 0.1, 4.0)

func get_ghost_spawn_chance_multiplier() -> float:
	if _thickness >= 80.0:
		return 0.1
	elif _thickness >= 60.0:
		return 0.3
	elif _thickness >= 45.0:
		return 0.6
	elif _thickness >= 30.0:
		return 1.5
	elif _thickness >= 15.0:
		return 3.0
	elif _thickness >= 5.0:
		return 5.0
	else:
		return 8.0

func get_spirit_activity_multiplier() -> float:
	var base: float = 1.0
	if _thickness < 50.0:
		base += (50.0 - _thickness) * 0.03
	elif _thickness > 50.0:
		base = maxf(0.05, base - (_thickness - 50.0) * 0.015)
	return clampf(base, 0.05, 5.0)

func get_magic_difficulty_modifier() -> float:
	if _thickness >= 80.0:
		return 2.5
	elif _thickness >= 60.0:
		return 1.5
	elif _thickness >= 40.0:
		return 1.0
	elif _thickness >= 20.0:
		return 0.6
	elif _thickness >= 5.0:
		return 0.3
	else:
		return 0.1

func sense_veil_for_pawn(pawn_id: int, pawn_location: Vector2i, tick: int, is_seer: bool = false) -> Dictionary:
	if _pawn_sense_records.has(pawn_id):
		var record: PawnSenseRecord = _pawn_sense_records[pawn_id]
		if tick - record.last_sense_tick < PAWN_SENSE_COOLDOWN and not is_seer:
			return {
				"sensed": true,
				"thickness": record.sensed_thickness,
				"thin_spots_nearby": record.sensed_thin_spots,
				"rends_nearby": record.sensed_rends,
				"cached": true,
				"description": _describe_sensed_veil(record.sensed_thickness, record.sensed_thin_spots.size() > 0, record.sensed_rends.size() > 0),
			}
	if not _pawn_sense_records.has(pawn_id):
		_pawn_sense_records[pawn_id] = PawnSenseRecord.new(pawn_id)
	var record: PawnSenseRecord = _pawn_sense_records[pawn_id]
	var local_thickness: float = get_thickness_at(pawn_location)
	var nearby_thin_spots: Array = []
	var nearby_rends: Array = []
	var sense_radius: int = SENSE_RADIUS * (2 if is_seer else 1)
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(pawn_location)
		if dist <= float(sense_radius + spot.radius):
			nearby_thin_spots.append(spot.to_dict())
	for rend in _rends:
		if not rend.active:
			continue
		var dist: float = rend.location.distance_to(pawn_location)
		if dist <= float(sense_radius * 2):
			nearby_rends.append(rend.to_dict())
	record.last_sense_tick = tick
	record.sensed_thickness = local_thickness
	record.sensed_thin_spots = nearby_thin_spots
	record.sensed_rends = nearby_rends
	pawn_sensed_veil.emit(pawn_id, local_thickness, nearby_thin_spots.size() > 0, nearby_rends.size() > 0)
	return {
		"sensed": true,
		"thickness": local_thickness,
		"thin_spots_nearby": nearby_thin_spots,
		"rends_nearby": nearby_rends,
		"cached": false,
		"description": _describe_sensed_veil(local_thickness, nearby_thin_spots.size() > 0, nearby_rends.size() > 0),
	}

func _describe_sensed_veil(thickness: float, has_thin_spot: bool, has_rend: bool) -> String:
	if thickness <= 5.0:
		var parts: PackedStringArray = ["The Veil is shattered. The supernatural presses in from all sides."]
		if has_rend:
			parts.append("You feel open wounds in reality nearby.")
		if has_thin_spot:
			parts.append("The air shimmers with thin places.")
		return " ".join(parts)
	elif thickness < 20.0:
		var parts: PackedStringArray = ["The Veil is torn and fraying. Spirits draw close."]
		if has_rend:
			parts.append("A rend pulses with dark energy nearby.")
		if has_thin_spot:
			parts.append("You sense a place where the Veil is worn thin.")
		return " ".join(parts)
	elif thickness < 35.0:
		if has_rend:
			return "The Veil is breached nearby. You feel a cold pull."
		if has_thin_spot:
			return "You sense a thin place where the Veil weakens."
		return "The Veil is thin. The supernatural feels near."
	elif thickness < 50.0:
		if has_rend or has_thin_spot:
			return "The Veil wavers. You perceive disturbances in the spiritual boundary."
		return "The Veil is thinner than normal. A faint hum reaches your senses."
	elif thickness < 70.0:
		if has_rend:
			return "Despite the stable Veil, you detect a wound in its fabric."
		if has_thin_spot:
			return "The Veil is calm, but you sense an ancient thin place."
		return "The Veil feels normal — quiet and secure."
	elif thickness < 90.0:
		return "The Veil is thick. The spirit world feels muffled and distant."
	else:
		return "The Veil is nearly sealed. You feel cut off from the supernatural entirely."

func get_thin_spots_near(tile: Vector2i, radius: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spot in _thin_spots:
		var dist: float = spot.location.distance_to(tile)
		if dist <= float(radius + spot.radius):
			out.append(spot.to_dict())
	return out

func get_rends_near(tile: Vector2i, radius: int = 20) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rend in _rends:
		if not rend.active:
			continue
		var dist: float = rend.location.distance_to(tile)
		if dist <= float(radius):
			out.append(rend.to_dict())
	return out

func get_veil_status() -> Dictionary:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	return {
		"thickness": _thickness,
		"description": get_veil_thickness_description(),
		"thin_spot_count": _thin_spots.size(),
		"rend_count": _rends.size(),
		"active_rends": _count_active_rends(),
		"total_fluctuation": _total_fluctuation_offset,
		"era_shift": _era_shift,
		"initialized": _initialized,
		"tick": tick,
	}

func get_stats() -> Dictionary:
	var rend_cause_counts: Dictionary = {}
	for rend in _rends:
		var cause_name: String = RendCause.keys()[rend.cause] if rend.cause < RendCause.size() else "UNKNOWN"
		rend_cause_counts[cause_name] = rend_cause_counts.get(cause_name, 0) + 1
	var spot_type_counts: Dictionary = {}
	for spot in _thin_spots:
		var type_name: String = ThinSpotType.keys()[spot.spot_type] if spot.spot_type < ThinSpotType.size() else "UNKNOWN"
		spot_type_counts[type_name] = spot_type_counts.get(type_name, 0) + 1
	var total_rend_severity: float = 0.0
	for rend in _rends:
		if rend.active:
			total_rend_severity += rend.severity
	return {
		"veil_thickness": _thickness,
		"thin_spots_total": _thin_spots.size(),
		"thin_spots_by_type": spot_type_counts,
		"persistent_thin_spots": _count_persistent_thin_spots(),
		"rends_total": _rends.size(),
		"rends_active": _count_active_rends(),
		"rends_by_cause": rend_cause_counts,
		"total_rend_severity": total_rend_severity,
		"total_fluctuation_offset": _total_fluctuation_offset,
		"era_shift": _era_shift,
		"description": get_veil_thickness_description(),
		"ghost_multiplier": get_ghost_spawn_chance_multiplier(),
		"spirit_activity_mult": get_spirit_activity_multiplier(),
		"magic_difficulty_mod": get_magic_difficulty_modifier(),
		"initialized": _initialized,
		"pawn_sense_records": _pawn_sense_records.size(),
		"recent_event_count": _recent_events.size(),
	}

func get_recent_veil_events(max_count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start: int = maxi(0, _recent_events.size() - max_count)
	for i in range(start, _recent_events.size()):
		out.append(_recent_events[i].duplicate())
	return out

func _count_active_rends() -> int:
	var count: int = 0
	var tick: int = GameManager.tick_count if GameManager != null else 0
	for rend in _rends:
		if rend.active and not rend.is_expired(tick):
			count += 1
	return count

func _count_persistent_thin_spots() -> int:
	var count: int = 0
	for spot in _thin_spots:
		if spot.persistent:
			count += 1
	return count

func _append_recent_event(event_type: String, tick: int, data: Dictionary) -> void:
	_recent_events.append({
		"type": event_type,
		"tick": tick,
		"data": data.duplicate(),
	})
	if _recent_events.size() > 200:
		_recent_events.pop_front()

func _garbage_collect_pawn_senses(tick: int) -> void:
	var stale: Array[int] = []
	for pid in _pawn_sense_records:
		var record: PawnSenseRecord = _pawn_sense_records[pid]
		if tick - record.last_sense_tick > 50000:
			stale.append(pid)
	for pid in stale:
		_pawn_sense_records.erase(pid)

func to_save_dict() -> Dictionary:
	var thin_spot_data: Array[Dictionary] = []
	for spot in _thin_spots:
		thin_spot_data.append(spot.to_dict())
	var rend_data: Array[Dictionary] = []
	for rend in _rends:
		rend_data.append(rend.to_dict())
	var pawn_sense_data: Dictionary = {}
	for pid in _pawn_sense_records:
		var rec: PawnSenseRecord = _pawn_sense_records[pid]
		pawn_sense_data[str(pid)] = {
			"last_sense_tick": rec.last_sense_tick,
			"sensed_thickness": rec.sensed_thickness,
		}
	return {
		"thickness": _thickness,
		"last_update_tick": _last_update_tick,
		"last_fluctuation_tick": _last_fluctuation_tick,
		"thin_spots": thin_spot_data,
		"rends": rend_data,
		"total_fluctuation_offset": _total_fluctuation_offset,
		"era_shift": _era_shift,
		"world_created": _world_created,
		"recent_events": _recent_events.duplicate(),
		"pawn_sense_records": pawn_sense_data,
		"initialized": _initialized,
	}

func from_save_dict(data: Variant) -> void:
	clear()
	if data == null or not (data is Dictionary):
		return
	var d: Dictionary = data as Dictionary
	_thickness = clampf(float(d.get("thickness", DEFAULT_THICKNESS)), 0.0, 100.0)
	_last_update_tick = int(d.get("last_update_tick", -999999))
	_last_fluctuation_tick = int(d.get("last_fluctuation_tick", -999999))
	_total_fluctuation_offset = float(d.get("total_fluctuation_offset", 0.0))
	_era_shift = float(d.get("era_shift", 0.0))
	_world_created = bool(d.get("world_created", false))
	_initialized = bool(d.get("initialized", false))
	var saved_spots: Array = d.get("thin_spots", [])
	if saved_spots is Array:
		for entry in saved_spots:
			if entry is Dictionary:
				var spot: ThinSpot = ThinSpot.from_dict(entry as Dictionary)
				_thin_spots.append(spot)
	var saved_rends: Array = d.get("rends", [])
	if saved_rends is Array:
		for entry in saved_rends:
			if entry is Dictionary:
				var rend: Rend = Rend.from_dict(entry as Dictionary)
				_rends.append(rend)
	var saved_events: Array = d.get("recent_events", [])
	if saved_events is Array:
		for entry in saved_events:
			if entry is Dictionary:
				_recent_events.append(entry as Dictionary)
	var saved_senses: Dictionary = d.get("pawn_sense_records", {})
	if saved_senses is Dictionary:
		for pid_str in saved_senses:
			var pid: int = int(pid_str)
			var rec_data: Dictionary = (saved_senses as Dictionary)[pid_str] as Dictionary
			var rec := PawnSenseRecord.new(pid)
			rec.last_sense_tick = int(rec_data.get("last_sense_tick", -999999))
			rec.sensed_thickness = float(rec_data.get("sensed_thickness", 50.0))
			_pawn_sense_records[pid] = rec

func clear() -> void:
	_thickness = DEFAULT_THICKNESS
	_last_update_tick = -999999
	_last_fluctuation_tick = -999999
	_thin_spots.clear()
	_rends.clear()
	_total_fluctuation_offset = 0.0
	_era_shift = 0.0
	_world_created = false
	_recent_events.clear()
	_pawn_sense_records.clear()
	_initialized = false

func debug_force_thickness(value: float) -> void:
	var old: float = _thickness
	_thickness = clampf(value, 0.0, 100.0)
	var delta: float = _thickness - old
	veil_thickness_changed.emit(_thickness, delta, "debug_override")
	if OS.is_debug_build():
		print("[VeilSystem] DEBUG: Forced thickness to %.1f" % _thickness)

func debug_force_rend(loc: Vector2i, severity: float, tick: int) -> void:
	if not OS.is_debug_build():
		return
	_create_rend(loc, clampf(severity, 5.0, 100.0), tick, 30000 + int(severity * 500.0), RendCause.UNKNOWN)
	print("[VeilSystem] DEBUG: Created rend at (%d,%d) severity=%.1f" % [loc.x, loc.y, severity])

func debug_force_thin_spot(loc: Vector2i, radius: int, thinness: float, stype: int, tick: int) -> void:
	if not OS.is_debug_build():
		return
	create_thin_spot(loc, radius, thinness, stype, tick)
	print("[VeilSystem] DEBUG: Created thin spot at (%d,%d) thinness=%.1f" % [loc.x, loc.y, thinness])

func debug_force_fluctuation_reset() -> void:
	if not OS.is_debug_build():
		return
	_total_fluctuation_offset = 0.0
	_era_shift = 0.0
	print("[VeilSystem] DEBUG: Fluctuation reset")
