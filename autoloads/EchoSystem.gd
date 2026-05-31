extends Node
## EchoSystem — psychic echoes of historical events affecting sensitive pawns.
##
## Significant events (cataclysm, massacre, betrayal, romance, founding, death of
## major figure) leave psychic imprints on the world.  Sensitive pawns within
## an echo's radius can be affected by nightmares, visions, skill modulation,
## compulsion, or madness.  Echoes decay linearly over time, but residual
## intensity lingers.  Multiple echoes in the same area layer their effects.
##
## Integrates with VeilSystem (thin veil = stronger echoes), AshaDrujSystem
## (Druj dominance = stronger echoes), WorldMemory (event recording), and
## EventBus (subscribes to high-significance events).

enum EchoType {
	TRAUMATIC = 0,   # nightmares, psychological damage
	INSPIRING = 1,   # skill boost, positive mood
	PROPHETIC = 2,   # visions of future patterns
	ROMANTIC = 3,    # emotional longing, attachment
	CATACLYSM = 4,   # raw destructive imprint
	SACRED = 5,      # holy ground, divine presence
	MALIGNANT = 6,   # cursed ground, corrupting influence
}

enum PawnEffect {
	NIGHTMARE = 0,
	VISION = 1,
	SKILL_BOOST = 2,
	SKILL_PENALTY = 3,
	COMPULSION = 4,
	MADNESS = 5,
	INSIGHT = 6,
	EMOTIONAL = 7,
}

const ECHO_CHECK_INTERVAL: int = 2500
const MAX_ECHOES_PER_LOCATION: int = 15
const DECAY_RATE_PER_TICK: float = 0.00025
const RESIDUAL_DECAY_RATE: float = 0.00005
const RESIDUAL_THRESHOLD: float = 2.0
const EXORCISM_INTENSITY_THRESHOLD: float = 5.0
const MAX_ECHO_AGE_FOR_GENERATION: int = 50000
const MIN_SIGNIFICANCE_FOR_ECHO: int = 3
const INTENSITY_SCAN_INTERVAL: int = 500
const PAWN_EFFECT_CHECK_INTERVAL: int = 1000
const RADIUS_PER_INTENSITY: float = 0.15
const MIN_RADIUS: float = 1.0
const MAX_RADIUS: float = 15.0
const LAYERING_INTENSITY_CAP: float = 150.0
const SENSITIVITY_BASE_CHANCE: float = 0.02
const SENSITIVITY_INHERIT_CHANCE: float = 0.35
const VISION_RNG_STREAM: StringName = &"EchoSystem:vision"
const NIGHTMARE_RNG_STREAM: StringName = &"EchoSystem:nightmare"
const COMPULSION_RNG_STREAM: StringName = &"EchoSystem:compulsion"
const EFFECT_RNG_STREAM: StringName = &"EchoSystem:effect"
const GENERATION_RNG_STREAM: StringName = &"EchoSystem:generation"
const EXORCISM_RNG_STREAM: StringName = &"EchoSystem:exorcism"
const SENSITIVITY_RNG_STREAM: StringName = &"EchoSystem:sensitivity"

class Echo:
	var echo_id: int
	var event_type: EchoType
	var tick_created: int
	var location: Vector2i
	var intensity: float
	var radius: float
	var description: String
	var affected_pawns: Array[int]
	var residual_intensity: float
	var source_event_id: int
	var permanent: bool
	var age_on_exorcism: int

	func _init(
		p_echo_id: int,
		p_event_type: EchoType,
		p_tick: int,
		p_location: Vector2i,
		p_intensity: float,
		p_description: String
	) -> void:
		echo_id = p_echo_id
		event_type = p_event_type
		tick_created = p_tick
		location = p_location
		intensity = p_intensity
		radius = clampf(p_intensity * RADIUS_PER_INTENSITY, MIN_RADIUS, MAX_RADIUS)
		description = p_description
		affected_pawns = []
		residual_intensity = 0.0
		source_event_id = -1
		permanent = p_intensity >= 80.0
		age_on_exorcism = -1

	func get_effective_intensity(veil_multiplier: float) -> float:
		return intensity * veil_multiplier

	func to_dict() -> Dictionary:
		return {
			"echo_id": echo_id,
			"event_type": event_type,
			"tick_created": tick_created,
			"location_x": location.x,
			"location_y": location.y,
			"intensity": intensity,
			"radius": radius,
			"description": description,
			"affected_pawns": affected_pawns.duplicate(),
			"residual_intensity": residual_intensity,
			"source_event_id": source_event_id,
			"permanent": permanent,
			"age_on_exorcism": age_on_exorcism,
		}

	static func from_dict(d: Dictionary) -> Echo:
		var echo := Echo.new(
			int(d.get("echo_id", 0)),
			int(d.get("event_type", 0)) as EchoType,
			int(d.get("tick_created", 0)),
			Vector2i(int(d.get("location_x", 0)), int(d.get("location_y", 0))),
			float(d.get("intensity", 0.0)),
			str(d.get("description", ""))
		)
		echo.affected_pawns = (d.get("affected_pawns", []) as Array).duplicate()
		echo.residual_intensity = float(d.get("residual_intensity", 0.0))
		echo.source_event_id = int(d.get("source_event_id", -1))
		echo.permanent = bool(d.get("permanent", false))
		echo.age_on_exorcism = int(d.get("age_on_exorcism", -1))
		return echo


var _echoes: Array[Echo] = []
var _next_echo_id: int = 1
var _last_update_tick: int = -999999
var _last_effect_check_tick: int = -999999
var _last_intensity_scan_tick: int = -999999
var _sensitive_pawn_cache: Dictionary = {}
var _sensitive_pawn_cache_tick: int = -1

signal echo_created(echo_id: int, location: Vector2i, event_type: int, intensity: float, description: String)
signal echo_faded(echo_id: int, location: Vector2i, residual_intensity: float)
signal echo_exorcised(echo_id: int, location: Vector2i, exorcist_id: int, age: int)
signal pawn_haunted(pawn_id: int, effect_type: int, echo_id: int, intensity: float)
signal pawn_insight(pawn_id: int, echo_id: int, vision_description: String)


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_subscribe_eventbus()


func _subscribe_eventbus() -> void:
	if EventBus == null:
		return
	EventBus.subscribe("cataclysm_started", self, "_on_eventbus_cataclysm")
	EventBus.subscribe("massacre", self, "_on_eventbus_massacre")
	EventBus.subscribe("betrayal", self, "_on_eventbus_betrayal")
	EventBus.subscribe("romance", self, "_on_eventbus_romance")
	EventBus.subscribe("settlement_founded", self, "_on_eventbus_founding")
	EventBus.subscribe("heroic_death", self, "_on_eventbus_heroic_death")
	EventBus.subscribe("major_figure_death", self, "_on_eventbus_major_death")
	EventBus.subscribe("miracle", self, "_on_eventbus_miracle")
	EventBus.subscribe("ritual_completed", self, "_on_eventbus_ritual")


func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	_unsubscribe_eventbus()


func _unsubscribe_eventbus() -> void:
	if EventBus == null:
		return
	EventBus.unsubscribe("cataclysm_started", self, "_on_eventbus_cataclysm")
	EventBus.unsubscribe("massacre", self, "_on_eventbus_massacre")
	EventBus.unsubscribe("betrayal", self, "_on_eventbus_betrayal")
	EventBus.unsubscribe("romance", self, "_on_eventbus_romance")
	EventBus.unsubscribe("settlement_founded", self, "_on_eventbus_founding")
	EventBus.unsubscribe("heroic_death", self, "_on_eventbus_heroic_death")
	EventBus.unsubscribe("major_figure_death", self, "_on_eventbus_major_death")
	EventBus.unsubscribe("miracle", self, "_on_eventbus_miracle")
	EventBus.unsubscribe("ritual_completed", self, "_on_eventbus_ritual")


func _on_game_tick(tick: int) -> void:
	if tick - _last_update_tick < ECHO_CHECK_INTERVAL:
		return
	_last_update_tick = tick
	_process_echo_decay(tick)
	if tick - _last_effect_check_tick >= PAWN_EFFECT_CHECK_INTERVAL:
		_last_effect_check_tick = tick
		_process_pawn_effects(tick)
	if tick - _last_intensity_scan_tick >= INTENSITY_SCAN_INTERVAL:
		_last_intensity_scan_tick = tick
		_scan_for_new_echoes(tick)


func _on_eventbus_cataclysm(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.CATACLYSM, payload,
		"cataclysm", 50.0 + float(int(payload.get("severity", 0))) * 5.0
	)


func _on_eventbus_massacre(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.TRAUMATIC, payload,
		"massacre", 40.0 + float(int(payload.get("death_count", 0))) * 2.0
	)


func _on_eventbus_betrayal(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.MALIGNANT, payload,
		"betrayal", 25.0 + float(int(payload.get("severity", 0))) * 5.0
	)


func _on_eventbus_romance(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.ROMANTIC, payload,
		"romance", 20.0
	)


func _on_eventbus_founding(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.SACRED, payload,
		"settlement_founded", 30.0
	)


func _on_eventbus_heroic_death(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.INSPIRING, payload,
		"heroic_death", 35.0 + float(int(payload.get("legacy_score", 0))) * 0.5
	)


func _on_eventbus_major_death(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.TRAUMATIC, payload,
		"major_figure_death", 45.0
	)


func _on_eventbus_miracle(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.SACRED, payload,
		"miracle", 60.0
	)


func _on_eventbus_ritual(payload: Dictionary) -> void:
	_create_echo_from_eventbus(
		EchoType.PROPHETIC, payload,
		"ritual_completed", 25.0
	)


func _create_echo_from_eventbus(etype: EchoType, payload: Dictionary, fallback_type: String, intensity: float) -> void:
	if intensity <= 0.0:
		return
	var tile_x: int = int(payload.get("tile_x", payload.get("x", -1)))
	var tile_y: int = int(payload.get("tile_y", payload.get("y", -1)))
	if tile_x < 0 or tile_y < 0:
		var loc_var: Variant = payload.get("location", null)
		if loc_var is Vector2i:
			var loc: Vector2i = loc_var as Vector2i
			tile_x = loc.x
			tile_y = loc.y
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	var desc: String = str(payload.get("description", str(payload.get("type", fallback_type))))
	_create_echo_internal(etype, Vector2i(tile_x, tile_y), intensity, tick, desc)


func _create_echo_internal(event_type: EchoType, location: Vector2i, intensity: float, tick: int, description: String) -> int:
	if intensity <= 0.0:
		return -1
	if location.x < 0 or location.y < 0:
		return -1
	var veil_mult: float = _get_veil_multiplier(location)
	var adjusted_intensity: float = intensity * veil_mult
	if adjusted_intensity <= 0.0:
		return -1
	var loc_count: int = 0
	for e in _echoes:
		if e.location == location:
			loc_count += 1
	if loc_count >= MAX_ECHOES_PER_LOCATION:
		return -1
	var echo := Echo.new(_next_echo_id, event_type, tick, location, adjusted_intensity, description)
	echo.source_event_id = _next_echo_id
	_next_echo_id += 1
	_echoes.append(echo)
	echo_created.emit(echo.echo_id, echo.location, echo.event_type, echo.intensity, echo.description)
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "echo_created",
			"echo_id": echo.echo_id,
			"event_type": event_type,
			"location_x": location.x,
			"location_y": location.y,
			"intensity": echo.intensity,
			"radius": echo.radius,
			"description": description,
			"tick": tick,
		})
	if EventBus != null:
		EventBus.emit("echo_created", {
			"echo_id": echo.echo_id,
			"event_type": event_type,
			"location": location,
			"intensity": echo.intensity,
		})
	return echo.echo_id


func _get_veil_multiplier(location: Vector2i) -> float:
	var mult: float = 1.0
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null:
		var veil: float = vs.get_veil_integrity()
		if veil < 50.0:
			mult += (50.0 - veil) * 0.02
		if vs.has_method("is_thin_at"):
			if vs.is_thin_at(location):
				if vs.has_method("get_thin_spot_intensity"):
					var spot: float = vs.get_thin_spot_intensity(location)
					mult += spot * 0.01
	var ads := get_node_or_null("/root/AshaDrujSystem")
	if ads != null:
		var druj: float = ads.get_druj()
		if druj > 50.0:
			mult += (druj - 50.0) * 0.015
	return clampf(mult, 0.5, 5.0)


func _process_echo_decay(tick: int) -> void:
	var to_remove: Array[int] = []
	var veil_base: float = 1.0
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null:
		veil_base = vs.get_veil_integrity() / 100.0
	var ads := get_node_or_null("/root/AshaDrujSystem")
	var druj_mult: float = 1.0
	if ads != null:
		var druj: float = ads.get_druj()
		if druj > 60.0:
			druj_mult = 1.0 - (druj - 60.0) * 0.005
	var decay_mult: float = veil_base * druj_mult
	for i in range(_echoes.size()):
		var echo: Echo = _echoes[i]
		if echo.permanent:
			echo.residual_intensity = minf(echo.residual_intensity + 0.01, 100.0)
			continue
		var age: int = tick - echo.tick_created
		var age_days: float = float(age) * decay_mult
		var linear_decay: float = age_days * DECAY_RATE_PER_TICK
		var residual_decay: float = 0.0
		if echo.residual_intensity > 0.0:
			residual_decay = RESIDUAL_DECAY_RATE * decay_mult
		var new_intensity: float = maxf(0.0, echo.intensity - linear_decay)
		var new_residual: float = maxf(0.0, echo.residual_intensity - residual_decay)
		if new_intensity <= 0.0 and echo.residual_intensity <= RESIDUAL_THRESHOLD:
			to_remove.append(i)
			echo_faded.emit(echo.echo_id, echo.location, echo.residual_intensity)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_faded",
					"echo_id": echo.echo_id,
					"location_x": echo.location.x,
					"location_y": echo.location.y,
					"event_type": echo.event_type,
					"final_residual": echo.residual_intensity,
					"tick": tick,
				})
			if EventBus != null:
				EventBus.emit("echo_faded", {
					"echo_id": echo.echo_id,
					"location": echo.location,
					"residual": echo.residual_intensity,
				})
		else:
			if new_intensity <= 0.0:
				new_residual = maxf(new_residual, echo.residual_intensity - residual_decay)
				echo.residual_intensity = clampf(new_residual, 0.0, 100.0)
				continue
			echo.intensity = new_intensity
			echo.residual_intensity = minf(echo.residual_intensity + linear_decay * 0.1, 50.0)
			echo.radius = clampf(echo.intensity * RADIUS_PER_INTENSITY, MIN_RADIUS, MAX_RADIUS)
	for idx in range(to_remove.size() - 1, -1, -1):
		_echoes.remove_at(to_remove[idx])


func _scan_for_new_echoes(tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null:
		return
	if not wm.has_method("get_recent_events"):
		return
	var recent: Array = wm.get_recent_events(MAX_ECHO_AGE_FOR_GENERATION)
	for event in recent:
		if not (event is Dictionary):
			continue
		var ev: Dictionary = event as Dictionary
		var ev_type: String = str(ev.get("type", ""))
		var ev_tick: int = int(ev.get("tick", int(ev.get("t", 0))))
		if tick - ev_tick > MAX_ECHO_AGE_FOR_GENERATION:
			continue
		if _echo_exists_for_source(ev):
			continue
		var sig: int = int(ev.get("severity", ev.get("s", 0)))
		if sig < MIN_SIGNIFICANCE_FOR_ECHO:
			if ev_type not in [
				"heroic_death", "cataclysm_started", "miracle",
				"betrayal", "massacre", "settlement_founded"
			]:
				continue
		var echo_type: EchoType
		var intensity: float = 0.0
		var location: Vector2i = _extract_location_from_event(ev)
		var description: String = _describe_event(ev_type, ev)
		match ev_type:
			"heroic_death":
				echo_type = EchoType.INSPIRING
				intensity = 35.0 + float(int(ev.get("legacy_score", int(ev.get("ls", 0))))) * 0.5
			"cataclysm_started":
				echo_type = EchoType.CATACLYSM
				intensity = 50.0 + float(int(ev.get("severity", int(ev.get("sev", 0))))) * 5.0
			"miracle":
				echo_type = EchoType.SACRED
				intensity = 60.0
			"betrayal":
				echo_type = EchoType.MALIGNANT
				intensity = 30.0
			"massacre":
				echo_type = EchoType.TRAUMATIC
				intensity = 45.0
			"settlement_founded":
				echo_type = EchoType.SACRED
				intensity = 30.0
			"ritual_completed":
				echo_type = EchoType.PROPHETIC
				intensity = 25.0
			"romance_consummated", "romance":
				echo_type = EchoType.ROMANTIC
				intensity = 20.0
			"major_figure_death":
				echo_type = EchoType.TRAUMATIC
				intensity = 45.0
			_:
				continue
		if intensity > 0.0:
			var eid: int = _create_echo_internal(echo_type, location, intensity, ev_tick, description)
			if eid >= 0:
				var assigned: Echo = _echo_by_id(eid)
				if assigned != null:
					assigned.source_event_id = int(ev.get("eid", int(ev.get("event_id", -1))))


func _extract_location_from_event(ev: Dictionary) -> Vector2i:
	var x: int = int(ev.get("tile_x", int(ev.get("x", int(ev.get("location_x", -1))))))
	var y: int = int(ev.get("tile_y", int(ev.get("y", int(ev.get("location_y", -1))))))
	if x >= 0 and y >= 0:
		return Vector2i(x, y)
	var center: Variant = ev.get("center", null)
	if center is Vector2i:
		return center as Vector2i
	if center is Dictionary:
		var cd: Dictionary = center as Dictionary
		return Vector2i(int(cd.get("x", 0)), int(cd.get("y", 0)))
	var tile_var: Variant = ev.get("tile", null)
	if tile_var is Vector2i:
		return tile_var as Vector2i
	return Vector2i(0, 0)


func _describe_event(ev_type: String, ev: Dictionary) -> String:
	match ev_type:
		"heroic_death":
			var name_str: String = str(ev.get("pawn_name", ev.get("name", "a hero")))
			return "Heroic death of %s" % name_str
		"cataclysm_started":
			return str(ev.get("description", "A great cataclysm"))
		"miracle":
			return str(ev.get("description", "A miraculous event"))
		"betrayal":
			var traitor: String = str(ev.get("traitor", ev.get("actor", "someone")))
			var victim: String = str(ev.get("victim", "another"))
			return "Betrayal of %s by %s" % [victim, traitor]
		"massacre":
			var count: int = int(ev.get("death_count", ev.get("count", 0)))
			return "Massacre claiming %d lives" % count
		"settlement_founded":
			var s_name: String = str(ev.get("settlement_name", ev.get("name", "a new settlement")))
			return "Founding of %s" % s_name
		_:
			return str(ev.get("description", ev.get("type", "an event")))


func _echo_exists_for_source(ev: Dictionary) -> bool:
	var ev_eid: int = int(ev.get("eid", int(ev.get("event_id", -1))))
	if ev_eid >= 0:
		for e in _echoes:
			if e.source_event_id == ev_eid:
				return true
	var ev_tick: int = int(ev.get("tick", int(ev.get("t", -1))))
	var ev_type: String = str(ev.get("type", ""))
	for e in _echoes:
		if e.tick_created == ev_tick and EchoType.keys()[e.event_type] == ev_type:
			return true
	return false


func _process_pawn_effects(tick: int) -> void:
	var sensitive_pawns: Array[int] = _get_all_sensitive_pawns()
	if sensitive_pawns.is_empty():
		return
	var veil_base: float = _get_global_veil_intensity()
	for pawn_id in sensitive_pawns:
		var pawn_location: Vector2i = _get_pawn_location(pawn_id)
		if pawn_location.x < 0 and pawn_location.y < 0:
			continue
		var echoes_here: Array[Echo] = _echoes_at_location(pawn_location)
		if echoes_here.is_empty():
			continue
		var total_intensity: float = 0.0
		var dominant_echo: Echo = echoes_here[0]
		var dominant_intensity: float = 0.0
		for e in echoes_here:
			var dist: float = pawn_location.distance_to(e.location)
			if dist > e.radius:
				continue
			var effect_intensity: float = e.get_effective_intensity(veil_base)
			if effect_intensity > dominant_intensity:
				dominant_intensity = effect_intensity
				dominant_echo = e
			total_intensity += effect_intensity
			if not e.affected_pawns.has(pawn_id):
				e.affected_pawns.append(pawn_id)
		if dominant_echo == null or total_intensity <= 1.0:
			continue
		var layered_intensity: float = minf(total_intensity, LAYERING_INTENSITY_CAP)
		_apply_echo_effect_to_pawn(pawn_id, dominant_echo, layered_intensity, tick)


func _apply_echo_effect_to_pawn(pawn_id: int, echo: Echo, intensity: float, tick: int) -> void:
	var effect_type: int = _determine_effect(echo.event_type, intensity)
	match effect_type:
		PawnEffect.NIGHTMARE:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_nightmare",
					"pawn_id": pawn_id,
					"echo_id": echo.echo_id,
					"intensity": intensity,
					"description": "Pawn %d suffers nightmares from echo %d" % [pawn_id, echo.echo_id],
					"tick": tick,
				})
		PawnEffect.VISION:
			var vision_text: String = _generate_vision_text(echo)
			pawn_insight.emit(pawn_id, echo.echo_id, vision_text)
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_vision",
					"pawn_id": pawn_id,
					"echo_id": echo.echo_id,
					"vision": vision_text,
					"intensity": intensity,
					"tick": tick,
				})
		PawnEffect.SKILL_BOOST:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
		PawnEffect.SKILL_PENALTY:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
		PawnEffect.COMPULSION:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_compulsion",
					"pawn_id": pawn_id,
					"echo_id": echo.echo_id,
					"intensity": intensity,
					"description": "Pawn %d feels compelled by echo %d" % [pawn_id, echo.echo_id],
					"tick": tick,
				})
		PawnEffect.MADNESS:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_madness",
					"pawn_id": pawn_id,
					"echo_id": echo.echo_id,
					"intensity": intensity,
					"severity": "severe" if intensity > 40.0 else "moderate",
					"tick": tick,
				})
		PawnEffect.INSIGHT:
			var insight_text: String = _generate_insight_text(echo)
			pawn_insight.emit(pawn_id, echo.echo_id, insight_text)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "echo_insight",
					"pawn_id": pawn_id,
					"echo_id": echo.echo_id,
					"insight": insight_text,
					"tick": tick,
				})
		PawnEffect.EMOTIONAL:
			pawn_haunted.emit(pawn_id, effect_type, echo.echo_id, intensity)


func _determine_effect(event_type: int, intensity: float) -> int:
	var roll: float = WorldRNG.unit_for(EFFECT_RNG_STREAM, int(intensity * 1000.0))
	match event_type as EchoType:
		EchoType.TRAUMATIC:
			if intensity < 15.0:
				return PawnEffect.EMOTIONAL if roll < 0.5 else PawnEffect.NIGHTMARE
			elif intensity < 40.0:
				if roll < 0.15:
					return PawnEffect.COMPULSION
				elif roll < 0.55:
					return PawnEffect.NIGHTMARE
				elif roll < 0.85:
					return PawnEffect.SKILL_PENALTY
				else:
					return PawnEffect.MADNESS
			else:
				if roll < 0.1:
					return PawnEffect.VISION
				elif roll < 0.35:
					return PawnEffect.MADNESS
				elif roll < 0.65:
					return PawnEffect.NIGHTMARE
				elif roll < 0.85:
					return PawnEffect.COMPULSION
				else:
					return PawnEffect.SKILL_PENALTY
		EchoType.INSPIRING:
			if roll < 0.4:
				return PawnEffect.SKILL_BOOST
			elif roll < 0.7:
				return PawnEffect.INSIGHT
			elif roll < 0.9:
				return PawnEffect.EMOTIONAL
			else:
				return PawnEffect.VISION
		EchoType.PROPHETIC:
			if roll < 0.45:
				return PawnEffect.VISION
			elif roll < 0.7:
				return PawnEffect.INSIGHT
			elif roll < 0.85:
				return PawnEffect.COMPULSION
			else:
				return PawnEffect.NIGHTMARE
		EchoType.ROMANTIC:
			if roll < 0.5:
				return PawnEffect.EMOTIONAL
			elif roll < 0.8:
				return PawnEffect.COMPULSION
			elif roll < 0.95:
				return PawnEffect.INSIGHT
			else:
				return PawnEffect.NIGHTMARE
		EchoType.CATACLYSM:
			if intensity < 30.0:
				if roll < 0.4:
					return PawnEffect.NIGHTMARE
				elif roll < 0.7:
					return PawnEffect.SKILL_PENALTY
				else:
					return PawnEffect.EMOTIONAL
			else:
				if roll < 0.2:
					return PawnEffect.MADNESS
				elif roll < 0.45:
					return PawnEffect.NIGHTMARE
				elif roll < 0.65:
					return PawnEffect.SKILL_PENALTY
				elif roll < 0.85:
					return PawnEffect.COMPULSION
				else:
					return PawnEffect.VISION
		EchoType.SACRED:
			if roll < 0.35:
				return PawnEffect.SKILL_BOOST
			elif roll < 0.55:
				return PawnEffect.INSIGHT
			elif roll < 0.75:
				return PawnEffect.VISION
			elif roll < 0.9:
				return PawnEffect.EMOTIONAL
			else:
				return PawnEffect.NIGHTMARE
		EchoType.MALIGNANT:
			if intensity < 20.0:
				if roll < 0.4:
					return PawnEffect.NIGHTMARE
				elif roll < 0.7:
					return PawnEffect.SKILL_PENALTY
				else:
					return PawnEffect.COMPULSION
			else:
				if roll < 0.1:
					return PawnEffect.VISION
				elif roll < 0.35:
					return PawnEffect.MADNESS
				elif roll < 0.6:
					return PawnEffect.NIGHTMARE
				elif roll < 0.8:
					return PawnEffect.COMPULSION
				else:
					return PawnEffect.SKILL_PENALTY
	return PawnEffect.EMOTIONAL


func _generate_vision_text(echo: Echo) -> String:
	var type_name: String = EchoType.keys()[echo.event_type]
	match echo.event_type:
		EchoType.TRAUMATIC:
			return "A vision of death and suffering at (%d, %d) — the ground remembers." % [echo.location.x, echo.location.y]
		EchoType.PROPHETIC:
			return "Fragments of what may come flicker before your eyes from echo at (%d, %d)." % [echo.location.x, echo.location.y]
		EchoType.SACRED:
			return "A divine light reveals hidden truths near (%d, %d)." % [echo.location.x, echo.location.y]
		EchoType.CATACLYSM:
			return "The sky splits open! A vision of annihilation at (%d, %d)." % [echo.location.x, echo.location.y]
		EchoType.INSPIRING:
			return "You see a vision of greatness — echoes of heroism at (%d, %d)." % [echo.location.x, echo.location.y]
		_:
			return "You sense ripples of %s at (%d, %d)." % [type_name, echo.location.x, echo.location.y]


func _generate_insight_text(echo: Echo) -> String:
	match echo.event_type:
		EchoType.SACRED:
			return "You understand the sacred significance of this place more deeply."
		EchoType.INSPIRING:
			return "You feel a surge of understanding — past greatness shows you the way."
		EchoType.PROPHETIC:
			return "Patterns emerge from chaos. You glimpse causal threads."
		EchoType.TRAUMATIC:
			return "The pain of this place teaches you about suffering and survival."
		EchoType.ROMANTIC:
			return "You comprehend the depth of bonds forged here."
		_:
			return "The echoes impart fragmented knowledge of past events."


func perform_exorcism(location: Vector2i, exorcist_id: int, ritual_power: float, tick: int) -> int:
	var exorcised_count: int = 0
	var to_exorcise: Array[int] = []
	for i in range(_echoes.size()):
		var echo: Echo = _echoes[i]
		var dist: float = location.distance_to(echo.location)
		var exorcism_range: float = maxf(3.0, ritual_power * 0.5)
		if dist > exorcism_range:
			continue
		if echo.permanent:
			if ritual_power >= 80.0:
				var perm_chance: float = WorldRNG.unit_for(EXORCISM_RNG_STREAM, echo.echo_id + exorcist_id)
				if perm_chance < 0.15:
					to_exorcise.append(i)
				continue
		if echo.intensity < ritual_power:
			to_exorcise.append(i)
	for idx in to_exorcise:
		var echo: Echo = _echoes[idx]
		if echo == null:
			continue
		echo.intensity = 0.0
		echo.residual_intensity = maxf(0.0, echo.residual_intensity - ritual_power * 2.0)
		var age: int = tick - echo.tick_created
		echo.age_on_exorcism = age
		echo_exorcised.emit(echo.echo_id, echo.location, exorcist_id, age)
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "echo_exorcised",
				"echo_id": echo.echo_id,
				"location_x": echo.location.x,
				"location_y": echo.location.y,
				"exorcist_id": exorcist_id,
				"ritual_power": ritual_power,
				"age": age,
				"tick": tick,
			})
		if EventBus != null:
			EventBus.emit("echo_exorcised", {
				"echo_id": echo.echo_id,
				"location": echo.location,
				"exorcist_id": exorcist_id,
			})
		_echoes.remove_at(idx)
		exorcised_count += 1
	return exorcised_count


func clear_area(location: Vector2i, radius: float) -> int:
	var cleared: int = 0
	var to_remove: Array[int] = []
	for i in range(_echoes.size()):
		var echo: Echo = _echoes[i]
		var dist: float = location.distance_to(echo.location)
		if dist <= radius:
			to_remove.append(i)
	for idx in range(to_remove.size() - 1, -1, -1):
		_echoes.remove_at(to_remove[idx])
		cleared += 1
	return cleared


func get_echoes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _echoes:
		out.append(e.to_dict())
	return out


func get_echoes_at_location(location: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _echoes_at_location(location):
		out.append(e.to_dict())
	return out


func _echoes_at_location(location: Vector2i) -> Array[Echo]:
	var out: Array[Echo] = []
	for e in _echoes:
		var dist: float = location.distance_to(e.location)
		if dist <= e.radius:
			out.append(e)
	return out


func get_echoes_in_radius(center: Vector2i, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _echoes:
		var dist: float = center.distance_to(e.location)
		if dist <= radius:
			out.append(e.to_dict())
	return out


func get_sensitive_pawns() -> Array[int]:
	return _get_all_sensitive_pawns()


func _get_all_sensitive_pawns() -> Array[int]:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	if _sensitive_pawn_cache_tick == tick and not _sensitive_pawn_cache.is_empty():
		return _sensitive_pawn_cache.keys() as Array[int]
	_sensitive_pawn_cache.clear()
	_sensitive_pawn_cache_tick = tick
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null:
		return []
	var events: Array = wm.get_events()
	for ev in events:
		if not (ev is Dictionary):
			continue
		var ev_dict: Dictionary = ev as Dictionary
		var ev_type: String = str(ev_dict.get("type", ""))
		if ev_type == "echo_sensitivity_granted" or ev_type == "echo_sensitivity_inherited":
			var pid: int = int(ev_dict.get("pawn_id", -1))
			if pid >= 0:
				_sensitive_pawn_cache[pid] = true
	return _sensitive_pawn_cache.keys() as Array[int]


func grant_sensitivity(pawn_id: int, source: String, tick: int) -> void:
	if pawn_id < 0:
		return
	_sensitive_pawn_cache[pawn_id] = true
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "echo_sensitivity_granted",
			"pawn_id": pawn_id,
			"source": source,
			"tick": tick,
		})
	if EventBus != null:
		EventBus.emit("echo_sensitivity_granted", {
			"pawn_id": pawn_id,
			"source": source,
		})


func has_sensitivity(pawn_id: int) -> bool:
	if _sensitive_pawn_cache.has(pawn_id):
		return true
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null:
		return false
	var events: Array = wm.get_events()
	for ev in events:
		if not (ev is Dictionary):
			continue
		var ev_dict: Dictionary = ev as Dictionary
		var ev_type: String = str(ev_dict.get("type", ""))
		if ev_type in ["echo_sensitivity_granted", "echo_sensitivity_inherited"]:
			if int(ev_dict.get("pawn_id", -1)) == pawn_id:
				_sensitive_pawn_cache[pawn_id] = true
				return true
	return false


func try_grant_sensitivity_random(pawn_id: int, tick: int) -> bool:
	if pawn_id < 0:
		return false
	if has_sensitivity(pawn_id):
		return false
	var chance: float = SENSITIVITY_BASE_CHANCE
	var ads := get_node_or_null("/root/AshaDrujSystem")
	if ads != null:
		var druj: float = ads.get_druj()
		if druj > 60.0:
			chance += (druj - 60.0) * 0.002
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null:
		var veil: float = vs.get_veil_integrity()
		if veil < 30.0:
			chance += (30.0 - veil) * 0.003
	if WorldRNG.chance_for(SENSITIVITY_RNG_STREAM, chance, pawn_id):
		grant_sensitivity(pawn_id, "random", tick)
		return true
	return false


func try_grant_sensitivity_inherited(child_id: int, parent_a_id: int, parent_b_id: int, tick: int) -> bool:
	var a_sensitive: bool = parent_a_id >= 0 and has_sensitivity(parent_a_id)
	var b_sensitive: bool = parent_b_id >= 0 and has_sensitivity(parent_b_id)
	var inherit_chance: float = 0.0
	if a_sensitive and b_sensitive:
		inherit_chance = SENSITIVITY_INHERIT_CHANCE * 1.5
	elif a_sensitive or b_sensitive:
		inherit_chance = SENSITIVITY_INHERIT_CHANCE
	if inherit_chance <= 0.0:
		return false
	var salt: int = child_id + parent_a_id + parent_b_id
	if WorldRNG.chance_for(SENSITIVITY_RNG_STREAM, inherit_chance, salt):
		grant_sensitivity(child_id, "inherited", tick)
		return true
	return false


func get_echo_density_map() -> Dictionary:
	var density: Dictionary = {}
	for e in _echoes:
		var key: String = "%d,%d" % [e.location.x, e.location.y]
		density[key] = density.get(key, 0.0) + e.intensity + e.residual_intensity
	return density


func get_echo_count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for e in _echoes:
		var type_name: String = EchoType.keys()[e.event_type]
		counts[type_name] = int(counts.get(type_name, 0)) + 1
	return counts


func get_total_echoes() -> int:
	return _echoes.size()


func get_active_intensity_total() -> float:
	var total: float = 0.0
	for e in _echoes:
		total += e.intensity + e.residual_intensity * 0.5
	return total


func get_strongest_echo() -> Dictionary:
	var best: Echo = null
	var best_intensity: float = -1.0
	for e in _echoes:
		if e.intensity > best_intensity:
			best_intensity = e.intensity
			best = e
	if best != null:
		return best.to_dict()
	return {}


func get_strongest_echo_in_radius(center: Vector2i, radius: float) -> Dictionary:
	var best_intensity: float = -1.0
	var best: Echo = null
	for e in _echoes:
		var dist: float = center.distance_to(e.location)
		if dist <= radius and e.intensity > best_intensity:
			best_intensity = e.intensity
			best = e
	if best != null:
		return best.to_dict()
	return {}


func get_layering_intensity_at(location: Vector2i) -> float:
	var total: float = 0.0
	var veil_mult: float = _get_veil_multiplier(location)
	for e in _echoes:
		var dist: float = location.distance_to(e.location)
		if dist <= e.radius:
			total += e.get_effective_intensity(veil_mult)
	return minf(total, LAYERING_INTENSITY_CAP)


func get_echoes_by_type(etype: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _echoes:
		if int(e.event_type) == etype:
			out.append(e.to_dict())
	return out


func get_permanent_echo_count() -> int:
	var count: int = 0
	for e in _echoes:
		if e.permanent:
			count += 1
	return count


func get_stats() -> Dictionary:
	var type_counts: Dictionary = get_echo_count_by_type()
	return {
		"total_echoes": _echoes.size(),
		"permanent_echoes": get_permanent_echo_count(),
		"type_distribution": type_counts,
		"total_active_intensity": get_active_intensity_total(),
		"sensitive_pawn_count": _get_all_sensitive_pawns().size(),
		"next_echo_id": _next_echo_id,
	}


func to_save_dict() -> Dictionary:
	var echo_dicts: Array[Dictionary] = []
	for e in _echoes:
		echo_dicts.append(e.to_dict())
	return {
		"echoes": echo_dicts,
		"next_echo_id": _next_echo_id,
		"last_update_tick": _last_update_tick,
		"last_effect_check_tick": _last_effect_check_tick,
		"last_intensity_scan_tick": _last_intensity_scan_tick,
		"sensitive_pawn_cache_tick": _sensitive_pawn_cache_tick,
		"sensitive_pawn_ids": _sensitive_pawn_cache.keys() as Array[int],
	}


func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var data: Dictionary = d as Dictionary
	var echo_data: Array = data.get("echoes", [])
	for ed in echo_data:
		if ed is Dictionary:
			var echo: Echo = Echo.from_dict(ed as Dictionary)
			if echo != null:
				_echoes.append(echo)
	_next_echo_id = max(1, int(data.get("next_echo_id", 1)))
	_last_update_tick = int(data.get("last_update_tick", -999999))
	_last_effect_check_tick = int(data.get("last_effect_check_tick", -999999))
	_last_intensity_scan_tick = int(data.get("last_intensity_scan_tick", -999999))
	var pawn_ids: Array = data.get("sensitive_pawn_ids", [])
	for pid in pawn_ids:
		_sensitive_pawn_cache[int(pid)] = true
	if not pawn_ids.is_empty():
		_sensitive_pawn_cache_tick = int(data.get("sensitive_pawn_cache_tick", GameManager.tick_count if GameManager != null else 0))
	_reindex_echo_ids()


func _reindex_echo_ids() -> void:
	var max_id: int = 0
	for e in _echoes:
		if e.echo_id > max_id:
			max_id = e.echo_id
	_next_echo_id = maxi(_next_echo_id, max_id + 1)


func clear() -> void:
	_echoes.clear()
	_next_echo_id = 1
	_last_update_tick = -999999
	_last_effect_check_tick = -999999
	_last_intensity_scan_tick = -999999
	_sensitive_pawn_cache.clear()
	_sensitive_pawn_cache_tick = -1


func _echo_by_id(echo_id: int) -> Echo:
	for e in _echoes:
		if e.echo_id == echo_id:
			return e
	return null


func _get_global_veil_intensity() -> float:
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null:
		var integrity: float = vs.get_veil_integrity()
		if integrity < 50.0:
			return (50.0 - integrity) * 0.04 + 1.0
	return 1.0


func _get_pawn_location(pawn_id: int) -> Vector2i:
	var ps := get_node_or_null("/root/PawnSpawner")
	if ps != null and ps.has_method("pawn_data_for_id"):
		var data: Variant = ps.call("pawn_data_for_id", pawn_id)
		if data != null and (data is Object):
			var data_obj: Object = data as Object
			if "current_tile" in data_obj:
				return data_obj.get("current_tile")
	return Vector2i(-1, -1)
