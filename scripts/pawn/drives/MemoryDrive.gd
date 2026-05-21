## MemoryDrive.gd — Emotional impulses.
##
## Reads PawnConsciousness (trauma, dreams, beliefs), GrudgeManager,
## WorldMemory (deaths, injuries witnessed), and MemorialSystem.
## Pushes emotional urges: mourn, confront, avoid, pilgrimage, remember.
##
## Memory is not a lookup — it's a push. A HeelKawnian doesn't "decide" to
## visit a grave. Grief pushes them there. They don't "decide" to confront
## a rival. A grudge pushes them. The memory IS the action.
extends RefCounted
class_name MemoryDrive

## How often this drive pulses (in ticks). Throttled for performance.
const BASE_INTERVAL: int = 15

var _last_pulse_tick: int = -999999


## Should this drive pulse now? Throttled by game speed.
func should_pulse(current_tick: int, game_speed: float) -> bool:
	var interval: int = BASE_INTERVAL
	if game_speed >= 100.0:
		interval = 40
	elif game_speed >= 50.0:
		interval = 30
	elif game_speed >= 26.0:
		interval = 20
	if current_tick - _last_pulse_tick < interval:
		return false
	_last_pulse_tick = current_tick
	return true


## Pulse: check emotional state and push urges.
## consciousness: PawnConsciousness autoload (passed in because RefCounted can't access scene tree)
func pulse(data: HeelKawnianData, current_tick: int, consciousness: Node = null) -> Array[Urge]:
	var urges: Array[Urge] = []
	if data == null:
		return urges

	var pawn_id: int = int(data.id)

	# ── TRAUMA → AVOID ──
	# High trauma makes a pawn avoid the source of trauma.
	# PawnConsciousness tracks trauma_level (0-100).
	if consciousness != null:
		var trauma: float = consciousness.get_trauma_level(pawn_id)
		if trauma >= 75.0:
			# Severe trauma → strong avoidance urge
			var avoid_urge: Urge = Urge.new(Urge.Type.AVOID, 7.0, Urge.Source.MEMORY, current_tick)
			# Find the most traumatic memory's location
			var traumatic_memories: Array = consciousness.get_traumatic_memories(pawn_id)
			if not traumatic_memories.is_empty():
				var worst: Dictionary = traumatic_memories[0]
				var loc: Vector2i = worst.get("location", Vector2i(-999999, -999999))
				if loc.x >= 0:
					avoid_urge.target_tile = loc
					avoid_urge.context["reason"] = "trauma"
			urges.append(avoid_urge)
		elif trauma >= 50.0:
			# Moderate trauma → mild avoidance
			var avoid_urge: Urge = Urge.new(Urge.Type.AVOID, 3.5, Urge.Source.MEMORY, current_tick)
			urges.append(avoid_urge)

	# ── GRUDGE → CONFRONT ──
	# GrudgeManager tracks grudges between pawns.
	# Neural network also stores grudge weights.
	if data.neural_network != null and data.neural_network.has_method("get_strongest_grudge_target_id"):
		var gid: int = int(data.neural_network.get_strongest_grudge_target_id())
		if gid >= 0:
			var gmag: float = absf(float(data.neural_network.grudge_toward(gid)))
			if gmag >= 0.3:
				var confront_pri: float = 2.0 + gmag * 4.0  # 2.0–6.0
				var confront_urge: Urge = Urge.new(Urge.Type.CONFRONT, confront_pri, Urge.Source.MEMORY, current_tick)
				confront_urge.target_pawn_id = gid
				confront_urge.context["grudge_magnitude"] = gmag
				urges.append(confront_urge)

	# ── GRIEF → MOURN ──
	# If this pawn recently witnessed a death, push a mourn urge.
	# WorldMemory tracks death events; get_recent_events_for_pawn returns recent ones.
	if WorldMemory != null and WorldMemory.has_method("get_recent_events_for_pawn"):
		var recent_events: Array = WorldMemory.get_recent_events_for_pawn(pawn_id, 10)
		for evt in recent_events:
			if int(evt.get("kind", -1)) == WorldMemory.Kind.PAWN_DEATH:
				var mourn_urge: Urge = Urge.new(Urge.Type.MOURN, 4.0, Urge.Source.MEMORY, current_tick)
				var grave_loc: Vector2i = Vector2i(int(evt.get("x", -999999)), int(evt.get("y", -999999)))
				if grave_loc.x >= 0:
					mourn_urge.target_tile = grave_loc
				urges.append(mourn_urge)
				break  # One mourn urge is enough

	# ── DREAM NUDGE ──
	# Dreams can push a pawn toward rest, wander, or socialize.
	if consciousness != null:
		var nudge: Dictionary = consciousness.get_dream_nudge(pawn_id)
		if not nudge.is_empty():
			var nudge_action: String = str(nudge.get("action", ""))
			if nudge_action == "rest":
				urges.append(Urge.new(Urge.Type.DREAM_NUDGE, 2.5, Urge.Source.MEMORY, current_tick))
			elif nudge_type == "wander":
				var dream_urge: Urge = Urge.new(Urge.Type.DREAM_NUDGE, 1.5, Urge.Source.MEMORY, current_tick)
				dream_urge.context["dream_theme"] = str(nudge.get("theme", ""))
				urges.append(dream_urge)
			elif nudge_type == "social":
				var social_urge: Urge = Urge.new(Urge.Type.SOCIALIZE, 1.5, Urge.Source.MEMORY, current_tick)
				social_urge.context["from_dream"] = true
				urges.append(social_urge)

	# ── PILGRIMAGE ──
	# Pawns with core beliefs about honoring the dead occasionally
	# feel the urge to visit memorials.
	if consciousness != null:
		var beliefs: Array = consciousness.get_core_beliefs(pawn_id)
		for belief in beliefs:
			if belief == "honor_dead" or belief == "revere_ancestors":
				# Only push pilgrimage occasionally (every ~3000 ticks)
				if posmod(current_tick + pawn_id * 7, 3000) < 50:
					urges.append(Urge.new(Urge.Type.PILGRIMAGE, 2.0, Urge.Source.MEMORY, current_tick))
				break

	# ── DIASPORA HOMESICKNESS ──
	# Exiled pawns feel the urge to visit their origin settlement.
	if data._diaspora_origin >= 0:
		if posmod(current_tick + pawn_id * 13, 2000) < 30:
			var remember_urge: Urge = Urge.new(Urge.Type.REMEMBER, 2.5, Urge.Source.MEMORY, current_tick)
			remember_urge.context["origin_settlement"] = data._diaspora_origin
			urges.append(remember_urge)

	return urges


static func posmod(a: int, b: int) -> int:
	var m: int = a % b
	if m < 0:
		m += b
	return m
