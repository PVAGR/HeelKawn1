## BodyDrive.gd — Survival impulses.
##
## Reads body needs (hunger, rest, temperature, thirst, health, danger)
## and pushes survival urges. This is the most urgent drive — it runs
## every tick and its urges can interrupt any committed action.
##
## The body doesn't ask permission. Hunger pushes. Cold pushes. Danger pushes.
## These are the urges that keep HeelKawnians alive.
extends RefCounted
class_name BodyDrive

## Thresholds — mirrored from HeelKawnian.gd constants for self-containment.
const HUNGER_EMERGENCY: float = 20.0
const HUNGER_EAT_THRESHOLD: float = 30.0
const HUNGER_MILD: float = 50.0
const REST_PANIC_THRESHOLD: float = 12.0
const REST_SLEEP_THRESHOLD: float = 25.0
const REST_MILD: float = 50.0
const THIRST_DRINK_THRESHOLD: float = 35.0
const THIRST_EMERGENCY: float = 15.0
const COLD_THRESHOLD: float = 36.5
const COLD_SEVERE: float = 35.0
const HEALTH_LOW: float = 30.0
const HEALTH_CRITICAL: float = 15.0

var _last_awareness: Dictionary = {}
var _last_awareness_tick: int = -999999


## Pulse: check all body needs and push urges.
## Runs every tick. Returns array of Urge objects.
func pulse(data: HeelKawnianData, awareness: Dictionary, current_tick: int) -> Array[Urge]:
	var urges: Array[Urge] = []
	if data == null:
		return urges

	# Cache awareness for this pulse
	_last_awareness = awareness
	_last_awareness_tick = current_tick

	# ── HUNGER ──
	# Emergency: starving — eat anything, anywhere, immediately
	if data.hunger <= HUNGER_EMERGENCY:
		# If carrying food, eat from hand first
		if data.is_carrying() and Item.is_food(data.carrying):
			urges.append(Urge.new(Urge.Type.EAT_FROM_HAND, 10.0, Urge.Source.BODY, current_tick))
		else:
			# Try stockpile first, then direct forage
			urges.append(Urge.new(Urge.Type.EAT, 10.0, Urge.Source.BODY, current_tick))
			# If no stockpile food, also push FORAGE
			if StockpileManager != null and StockpileManager.total_food() <= 0:
				urges.append(Urge.new(Urge.Type.FORAGE, 9.5, Urge.Source.BODY, current_tick))
	elif data.hunger <= HUNGER_EAT_THRESHOLD:
		urges.append(Urge.new(Urge.Type.EAT, 7.0, Urge.Source.BODY, current_tick))
		if StockpileManager != null and StockpileManager.total_food() <= 0:
			urges.append(Urge.new(Urge.Type.FORAGE, 6.5, Urge.Source.BODY, current_tick))
	elif data.hunger <= HUNGER_MILD:
		urges.append(Urge.new(Urge.Type.EAT, 3.0, Urge.Source.BODY, current_tick))

	# ── THIRST ──
	if data.thirst <= THIRST_EMERGENCY:
		urges.append(Urge.new(Urge.Type.DRINK, 9.0, Urge.Source.BODY, current_tick))
	elif data.thirst <= THIRST_DRINK_THRESHOLD:
		urges.append(Urge.new(Urge.Type.DRINK, 6.0, Urge.Source.BODY, current_tick))

	# ── REST ──
	if data.rest <= REST_PANIC_THRESHOLD:
		urges.append(Urge.new(Urge.Type.SLEEP, 9.0, Urge.Source.BODY, current_tick))
	elif data.rest <= REST_SLEEP_THRESHOLD:
		urges.append(Urge.new(Urge.Type.SLEEP, 5.0, Urge.Source.BODY, current_tick))
	elif data.rest <= REST_MILD:
		urges.append(Urge.new(Urge.Type.SLEEP, 2.0, Urge.Source.BODY, current_tick))

	# ── COLD ──
	if data.body_temperature <= COLD_SEVERE:
		var warm_urge: Urge = Urge.new(Urge.Type.WARM, 8.0, Urge.Source.BODY, current_tick)
		var fire: Vector2i = awareness.get("nearest_fire", Vector2i(-9999, -9999))
		if fire.x >= 0:
			warm_urge.target_tile = fire
		urges.append(warm_urge)
	elif data.body_temperature <= COLD_THRESHOLD:
		var warm_urge: Urge = Urge.new(Urge.Type.WARM, 4.0, Urge.Source.BODY, current_tick)
		var fire: Vector2i = awareness.get("nearest_fire", Vector2i(-9999, -9999))
		if fire.x >= 0:
			warm_urge.target_tile = fire
		urges.append(warm_urge)

	# ── HEALTH ──
	if data.health <= HEALTH_CRITICAL:
		urges.append(Urge.new(Urge.Type.HEAL, 8.0, Urge.Source.BODY, current_tick))
	elif data.health <= HEALTH_LOW:
		urges.append(Urge.new(Urge.Type.HEAL, 4.0, Urge.Source.BODY, current_tick))

	# ── DANGER / FLEE ──
	if awareness.get("is_in_danger_zone", false):
		# Warriors don't flee — they guard
		if data.current_profession != HeelKawnianData.Profession.WARRIOR:
			var flee_urge: Urge = Urge.new(Urge.Type.FLEE, 8.0, Urge.Source.BODY, current_tick)
			var shelter: Vector2i = awareness.get("nearest_shelter", Vector2i(-9999, -9999))
			var fire: Vector2i = awareness.get("nearest_fire", Vector2i(-9999, -9999))
			if shelter.x >= 0:
				flee_urge.target_tile = shelter
			elif fire.x >= 0:
				flee_urge.target_tile = fire
			urges.append(flee_urge)
		else:
			# Warriors push GUARD instead of FLEE
			urges.append(Urge.new(Urge.Type.GUARD, 5.0, Urge.Source.BODY, current_tick))

	# ── THREAT NEARBY ──
	var threat: Vector2i = awareness.get("nearest_threat", Vector2i(-9999, -9999))
	if threat.x >= 0:
		var threat_dist: int = absi(threat.x - data.tile_pos.x) + absi(threat.y - data.tile_pos.y)
		if threat_dist <= 3:
			if data.current_profession != HeelKawnianData.Profession.WARRIOR:
				var flee_urge: Urge = Urge.new(Urge.Type.FLEE, 7.0, Urge.Source.BODY, current_tick)
				flee_urge.target_tile = threat  # Flee AWAY from threat (body will calculate)
				urges.append(flee_urge)

	return urges
