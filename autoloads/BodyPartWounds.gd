extends Node
## BodyPartWounds — Kenshi-style body-part wound system.
##
## Every HeelKawnian has 7 body parts, each with its own health pool.
## Wounds to specific parts affect specific actions:
##   - Head: vision, accuracy, consciousness
##   - Torso: breathing, stamina, vital organs
##   - Left Arm: building speed, tool use
##   - Right Arm: combat damage, crafting
##   - Left Leg: movement speed
##   - Right Leg: movement speed
##   - Back: carrying capacity, pain tolerance
##
## Wounds are tracked per body part. Each wound has:
##   - type (cut, blunt, burn, frostbite, etc.)
##   - severity (0-100)
##   - bleed_rate (HP loss per tick from bleeding)
##   - is_treated (healer applied bandage/herbs)
##
## Scars form from severe untreated wounds. Scars are permanent.

enum BodyPart {
	HEAD,
	TORSO,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG,
	BACK,
}

const BODY_PART_NAMES: Dictionary = {
	BodyPart.HEAD: "head",
	BodyPart.TORSO: "torso",
	BodyPart.LEFT_ARM: "left arm",
	BodyPart.RIGHT_ARM: "right arm",
	BodyPart.LEFT_LEG: "left leg",
	BodyPart.RIGHT_LEG: "right leg",
	BodyPart.BACK: "back",
}

enum WoundType {
	CUT,        # Sharp weapon (sword, knife)
	LACERATION, # Deep cut (axe, heavy blade)
	PUNCTURE,   # Piercing (spear, arrow)
	BLUNT,      # Blunt force (club, fist, fall)
	BURN,       # Fire, heat
	FROSTBITE,  # Cold damage
	INFECTION,  # Wound got infected
}

const WOUND_TYPE_NAMES: Dictionary = {
	WoundType.CUT: "cut",
	WoundType.LACERATION: "laceration",
	WoundType.PUNCTURE: "puncture",
	WoundType.BLUNT: "bruise",
	WoundType.BURN: "burn",
	WoundType.FROSTBITE: "frostbite",
	WoundType.INFECTION: "infection",
}

# Per-body-part health (each part has 100 HP)
const PART_MAX_HEALTH: float = 100.0

# Bleed rates per wound type (HP per tick)
const BLEED_RATE_CUT: float = 0.02
const BLEED_RATE_LACERATION: float = 0.05
const BLEED_RATE_PUNCTURE: float = 0.03
const BLEED_RATE_BLUNT: float = 0.0
const BLEED_RATE_BURN: float = 0.01
const BLEED_RATE_FROSTBITE: float = 0.0
const BLEED_RATE_INFECTION: float = 0.04

# Infection chance per tick for untreated wounds
const INFECTION_CHANCE_PER_TICK: float = 0.0005  # ~0.05% per tick

# Scar threshold: wounds above this severity leave scars
const SCAR_SEVERITY_THRESHOLD: float = 40.0

# Healing rates (HP per tick)
const HEAL_RATE_RESTING: float = 0.1
const HEAL_RATE_TREATED: float = 0.3
const HEAL_RATE_UNTREATED: float = 0.02

# Body part hit weights (how likely each part is hit)
const HIT_WEIGHTS: Dictionary = {
	BodyPart.HEAD: 5,      # 5% head
	BodyPart.TORSO: 35,    # 35% torso (largest target)
	BodyPart.LEFT_ARM: 12, # 12% each arm
	BodyPart.RIGHT_ARM: 12,
	BodyPart.LEFT_LEG: 15, # 15% each leg
	BodyPart.RIGHT_LEG: 15,
	BodyPart.BACK: 6,      # 6% back (flanking)
}

var _total_weight: int = 0

func _ready() -> void:
	for w in HIT_WEIGHTS.values():
		_total_weight += int(w)
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


## Select a random body part weighted by hit probability.
func select_body_part(seed_name: StringName, salt: int) -> int:
	var roll: int = WorldRNG.rangei(0, _total_weight - 1, salt, seed_name)
	var cumulative: int = 0
	for part in HIT_WEIGHTS.keys():
		cumulative += int(HIT_WEIGHTS[part])
		if roll < cumulative:
			return int(part)
	return BodyPart.TORSO  # fallback


## Determine wound type from damage source.
func wound_type_for_damage(damage_type: String) -> int:
	match damage_type:
		"cut", "slash": return WoundType.CUT
		"laceration", "chop": return WoundType.LACERATION
		"puncture", "pierce", "stab": return WoundType.PUNCTURE
		"blunt", "crush", "fall": return WoundType.BLUNT
		"burn", "fire": return WoundType.BURN
		"frostbite", "cold": return WoundType.FROSTBITE
		_: return WoundType.BLUNT  # default


## Apply a wound to a pawn's body part.
## Returns the wound dictionary for recording.
func apply_wound(pawn_data: RefCounted, body_part: int, wound_type: int, severity: float, source: String = "combat") -> Dictionary:
	if pawn_data == null:
		return {}
	# Initialize wound tracking if not present
	if not pawn_data.get("body_wounds"):
		pawn_data.set("body_wounds", {})
	var wounds: Dictionary = pawn_data.body_wounds
	var part_key: String = str(body_part)
	if not wounds.has(part_key):
		wounds[part_key] = []
	# Create wound entry
	var wound: Dictionary = {
		"type": wound_type,
		"severity": severity,
		"bleed_rate": _bleed_rate_for_type(wound_type),
		"is_treated": false,
		"tick_applied": GameManager.tick_count if GameManager != null else 0,
		"source": source,
	}
	wounds[part_key].append(wound)
	# Reduce body part health
	var part_health_key: String = "part_health_%d" % body_part
	var _ch_val = pawn_data.get(part_health_key)
	var current_health: float = PART_MAX_HEALTH if _ch_val == null else float(_ch_val)
	pawn_data.set(part_health_key, maxf(0.0, current_health - severity))
	# Pain from wound
	var pain: float = severity * 0.5
	if pawn_data.get("pain") != null:
		pawn_data.pain = minf(100.0, float(pawn_data.pain) + pain)
	# Mood event
	if pawn_data.has_method("add_mood_event"):
		pawn_data.add_mood_event(MoodEvent.Type.STRESS, severity * 0.6, 300)
	# Record to WorldMemory
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.INJURY,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": int(pawn_data.id),
		"pawn_name": str(pawn_data.display_name),
		"body_part": BODY_PART_NAMES.get(body_part, "unknown"),
		"wound_type": WOUND_TYPE_NAMES.get(wound_type, "unknown"),
		"severity": severity,
		"source": source,
	})
	return wound


## Get all wounds for a pawn's body part.
func get_wounds_for_part(pawn_data: RefCounted, body_part: int) -> Array:
	if pawn_data == null:
		return []
	var _bw_val = pawn_data.get("body_wounds")
	var wounds: Dictionary = {} if _bw_val == null else _bw_val
	var part_key: String = str(body_part)
	if not wounds.has(part_key):
		return []
	return wounds[part_key]


## Get total severity of all wounds on a body part.
func total_severity_on_part(pawn_data: RefCounted, body_part: int) -> float:
	var wounds: Array = get_wounds_for_part(pawn_data, body_part)
	var total: float = 0.0
	for w in wounds:
		total += float(w.get("severity", 0.0))
	return total


## Get body part health (0-100).
func get_part_health(pawn_data: RefCounted, body_part: int) -> float:
	if pawn_data == null:
		return PART_MAX_HEALTH
	var key: String = "part_health_%d" % body_part
	var _ph_val = pawn_data.get(key)
	return PART_MAX_HEALTH if _ph_val == null else float(_ph_val)


## Is a body part crippled (health <= 0)?
func is_part_crippled(pawn_data: RefCounted, body_part: int) -> bool:
	return get_part_health(pawn_data, body_part) <= 0.0


## Get movement speed penalty from leg wounds.
func get_movement_penalty(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var penalty: float = 0.0
	# Each leg contributes to movement
	var left_leg_severity: float = total_severity_on_part(pawn_data, BodyPart.LEFT_LEG)
	var right_leg_severity: float = total_severity_on_part(pawn_data, BodyPart.RIGHT_LEG)
	# Crippled leg = 50% movement penalty for that leg
	if is_part_crippled(pawn_data, BodyPart.LEFT_LEG):
		penalty += 0.5
	else:
		penalty += left_leg_severity / PART_MAX_HEALTH * 0.25
	if is_part_crippled(pawn_data, BodyPart.RIGHT_LEG):
		penalty += 0.5
	else:
		penalty += right_leg_severity / PART_MAX_HEALTH * 0.25
	return clampf(penalty, 0.0, 0.9)


## Get work speed penalty from arm wounds.
func get_work_penalty(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var penalty: float = 0.0
	# Arms affect work speed
	var left_arm_severity: float = total_severity_on_part(pawn_data, BodyPart.LEFT_ARM)
	var right_arm_severity: float = total_severity_on_part(pawn_data, BodyPart.RIGHT_ARM)
	if is_part_crippled(pawn_data, BodyPart.LEFT_ARM):
		penalty += 0.4
	else:
		penalty += left_arm_severity / PART_MAX_HEALTH * 0.2
	if is_part_crippled(pawn_data, BodyPart.RIGHT_ARM):
		penalty += 0.4
	else:
		penalty += right_arm_severity / PART_MAX_HEALTH * 0.2
	return clampf(penalty, 0.0, 0.8)


## Get combat accuracy penalty from head wounds.
func get_accuracy_penalty(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var head_severity: float = total_severity_on_part(pawn_data, BodyPart.HEAD)
	if is_part_crippled(pawn_data, BodyPart.HEAD):
		return 0.6  # Head crippled = 60% accuracy loss
	return head_severity / PART_MAX_HEALTH * 0.3


## Get carrying capacity penalty from back wounds.
func get_carry_penalty(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var back_severity: float = total_severity_on_part(pawn_data, BodyPart.BACK)
	if is_part_crippled(pawn_data, BodyPart.BACK):
		return 0.7  # Back crippled = 70% carry loss
	return back_severity / PART_MAX_HEALTH * 0.35


## Get total bleed rate from all wounds.
func get_total_bleed_rate(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var _bw2_val = pawn_data.get("body_wounds")
	var wounds: Dictionary = {} if _bw2_val == null else _bw2_val
	var total: float = 0.0
	for part_key in wounds:
		var part_wounds: Array = wounds[part_key]
		for w in part_wounds:
			if not bool(w.get("is_treated", false)):
				total += float(w.get("bleed_rate", 0.0))
	return total


## Treat a wound (healer applies bandage/herbs).
func treat_wound(pawn_data: RefCounted, body_part: int, wound_index: int) -> bool:
	var wounds: Array = get_wounds_for_part(pawn_data, body_part)
	if wound_index < 0 or wound_index >= wounds.size():
		return false
	var wound: Dictionary = wounds[wound_index]
	wound["is_treated"] = true
	wound["bleed_rate"] = 0.0  # Treated wounds stop bleeding
	return true


## Process wound healing and bleeding for all pawns.
func _on_game_tick(tick: int) -> void:
	if tick % 10 != 0:  # Process every 10 ticks
		return
	var pawns: Array = PawnSpawner.find_alive_pawns()
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		_process_pawn_wounds(pawn.data, tick)


func _process_pawn_wounds(pawn_data: RefCounted, tick: int) -> void:
	var _bw3_val = pawn_data.get("body_wounds")
	var wounds: Dictionary = {} if _bw3_val == null else _bw3_val
	if wounds.is_empty():
		return
	# Process bleeding
	var bleed_rate: float = get_total_bleed_rate(pawn_data)
	if bleed_rate > 0.0:
		pawn_data.health = maxf(0.0, float(pawn_data.health) - bleed_rate * 10.0)
		if pawn_data.health <= 0.0:
			# Bled out
			pawn_data.set("cause_of_death", "bled_out")
			return
	# Process each wound
	var parts_to_clean: Array = []
	for part_key in wounds:
		var part_wounds: Array = wounds[part_key]
		var wounds_to_remove: Array = []
		for i in range(part_wounds.size()):
			var wound: Dictionary = part_wounds[i]
			var severity: float = float(wound.get("severity", 0.0))
			var is_treated: bool = bool(wound.get("is_treated", false))
			# Heal wound
			var heal_rate: float = HEAL_RATE_TREATED if is_treated else HEAL_RATE_UNTREATED
			# Resting pawns heal faster
			if pawn_data.get("rest") != null and float(pawn_data.rest) > 70.0:
				heal_rate *= 2.0
			severity = maxf(0.0, severity - heal_rate * 10.0)
			wound["severity"] = severity
			# Check for infection (untreated wounds)
			if not is_treated and WorldRNG.chance_for("wound_infection", INFECTION_CHANCE_PER_TICK * 10.0, tick + int(part_key.hash())):
				wound["type"] = WoundType.INFECTION
				wound["bleed_rate"] = BLEED_RATE_INFECTION
				wound["severity"] = minf(100.0, severity + 10.0)
			# Wound healed completely
			if severity <= 0.0:
				wounds_to_remove.append(i)
				# Check for scar
				var original_severity: float = float(wound.get("original_severity", severity))
				if original_severity >= SCAR_SEVERITY_THRESHOLD:
					_add_scar(pawn_data, int(part_key), wound)
		# Remove healed wounds (reverse order to preserve indices)
		for i in range(wounds_to_remove.size() - 1, -1, -1):
			part_wounds.remove_at(wounds_to_remove[i])
		if part_wounds.is_empty():
			parts_to_clean.append(part_key)
	# Heal body part health
	for part_int in range(BodyPart.BACK + 1):
		var key: String = "part_health_%d" % part_int
		var _ph2_val = pawn_data.get(key)
		var current: float = PART_MAX_HEALTH if _ph2_val == null else float(_ph2_val)
		if current < PART_MAX_HEALTH:
			var part_wounds_arr: Array = wounds.get(str(part_int), [])
			var has_active_wounds: bool = part_wounds_arr.size() > 0
			if not has_active_wounds:
				pawn_data.set(key, minf(PART_MAX_HEALTH, current + 0.5 * 10.0))
	# Clean empty body part entries
	for part_key in parts_to_clean:
		wounds.erase(part_key)


func _add_scar(pawn_data: RefCounted, body_part: int, wound: Dictionary) -> void:
	if pawn_data == null:
		return
	var scar_type: String = WOUND_TYPE_NAMES.get(int(wound.get("type", 0)), "scar")
	var part_name: String = BODY_PART_NAMES.get(body_part, "unknown")
	var scar_name: String = "%s %s scar" % [scar_type, part_name]
	# Add to physical scars list
	if pawn_data.has_method("append_physical_scar"):
		pawn_data.append_physical_scar(scar_name)
	# Record scar in WorldMemory
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.INJURY,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": int(pawn_data.id),
		"pawn_name": str(pawn_data.display_name),
		"body_part": part_name,
		"scar": true,
		"scar_name": scar_name,
		"source": str(wound.get("source", "unknown")),
	})


func _bleed_rate_for_type(wound_type: int) -> float:
	match wound_type:
		WoundType.CUT: return BLEED_RATE_CUT
		WoundType.LACERATION: return BLEED_RATE_LACERATION
		WoundType.PUNCTURE: return BLEED_RATE_PUNCTURE
		WoundType.BLUNT: return BLEED_RATE_BLUNT
		WoundType.BURN: return BLEED_RATE_BURN
		WoundType.FROSTBITE: return BLEED_RATE_FROSTBITE
		WoundType.INFECTION: return BLEED_RATE_INFECTION
		_: return 0.0


## Get a summary of all wounds for a pawn (for UI display).
func get_wound_summary(pawn_data: RefCounted) -> Dictionary:
	if pawn_data == null:
		return {}
	var result: Dictionary = {}
	var _bw4_val = pawn_data.get("body_wounds")
	var wounds: Dictionary = {} if _bw4_val == null else _bw4_val
	for part_key in wounds:
		var part_int: int = int(part_key)
		var part_name: String = BODY_PART_NAMES.get(part_int, "unknown")
		var part_health: float = get_part_health(pawn_data, part_int)
		var part_wounds: Array = wounds[part_key]
		var wound_list: Array = []
		for w in part_wounds:
			wound_list.append({
				"type": WOUND_TYPE_NAMES.get(int(w.get("type", 0)), "unknown"),
				"severity": float(w.get("severity", 0.0)),
				"treated": bool(w.get("is_treated", false)),
				"bleeding": float(w.get("bleed_rate", 0.0)) > 0.0,
			})
		result[part_name] = {
			"health": part_health,
			"crippled": is_part_crippled(pawn_data, part_int),
			"wounds": wound_list,
		}
	return result
