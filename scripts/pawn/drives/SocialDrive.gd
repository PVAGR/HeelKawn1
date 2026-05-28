## SocialDrive.gd — Social impulses.
##
## Reads KinshipSystem, GossipManager, nearby pawns, HeelKawnianManager
## (development profile), and neural network autonomy hints.
## Pushes social urges: socialize, teach, challenge, affiliate, guard.
##
## Social needs are real needs. Loneliness pushes. Belonging pushes.
## Teaching pushes when you know something others don't.
extends RefCounted
class_name SocialDrive

const BASE_INTERVAL: int = 20

var _last_pulse_tick: int = -999999


func should_pulse(current_tick: int, _game_speed: float = 1.0) -> bool:
	if current_tick - _last_pulse_tick < BASE_INTERVAL:
		return false
	_last_pulse_tick = current_tick
	return true


## Pulse: check social state and push urges.
## nearby_pawns: Array of {pawn_id, rapport, profession, distance} from caller's scan
func pulse(data: HeelKawnianData, nearby_pawns: Array, current_tick: int) -> Array[Urge]:
	var urges: Array[Urge] = []
	if data == null:
		return urges

	var pawn_id: int = int(data.id)

	# ── LONELINESS → SOCIALIZE ──
	# A pawn with no household and few social connections feels loneliness.
	var loneliness: float = _compute_loneliness(data, nearby_pawns)
	if loneliness >= 0.7:
		urges.append(Urge.new(Urge.Type.SOCIALIZE, 3.0, Urge.Source.SOCIAL, current_tick))
	elif loneliness >= 0.4:
		urges.append(Urge.new(Urge.Type.SOCIALIZE, 1.5, Urge.Source.SOCIAL, current_tick))

	# ── BELONGING → AFFILIATE ──
	# Pawns without household/clan feel the need to join one.
	if data.household_id < 0:
		urges.append(Urge.new(Urge.Type.AFFILIATE, 2.5, Urge.Source.SOCIAL, current_tick))
	elif data.clan_id < 0:
		urges.append(Urge.new(Urge.Type.AFFILIATE, 1.5, Urge.Source.SOCIAL, current_tick))

	# ── TEACHING ──
	# Pawns with knowledge (8+ items) feel the urge to teach nearby pawns
	# who know less. Only if their own needs are satisfied.
	if data.hunger > 40.0 and data.rest > 35.0:
		if KnowledgeSystem != null and KnowledgeSystem.has_method("get_pawn_knowledge"):
			var my_knowledge: Array = KnowledgeSystem.get_pawn_knowledge(pawn_id)
			var kcount: int = my_knowledge.size()
			if kcount >= 8:
				# Check if any nearby pawn knows less
				for peer in nearby_pawns:
					var peer_id: int = int(peer.get("pawn_id", -1))
					if peer_id < 0:
						continue
					var peer_knowledge: Array = KnowledgeSystem.get_pawn_knowledge(peer_id)
					if peer_knowledge.size() < kcount - 2:
						var teach_urge: Urge = Urge.new(Urge.Type.TEACH, 2.5, Urge.Source.SOCIAL, current_tick)
						teach_urge.target_pawn_id = peer_id
						urges.append(teach_urge)
						break  # One teach urge is enough

	# ── NEURAL AUTONOMY HINT ──
	# The neural network can suggest social actions.
	if data.neural_network != null:
		var hint: String = str(data.neural_network.get_autonomy_hint()) if data.neural_network.has_method("get_autonomy_hint") else ""
		if hint == "social":
			urges.append(Urge.new(Urge.Type.SOCIALIZE, 2.0, Urge.Source.SOCIAL, current_tick))
		elif hint == "ally_seek":
			urges.append(Urge.new(Urge.Type.SOCIALIZE, 2.5, Urge.Source.SOCIAL, current_tick))
		elif hint == "mentor_seek":
			urges.append(Urge.new(Urge.Type.SOCIALIZE, 2.0, Urge.Source.SOCIAL, current_tick))

	# ── CHALLENGE ──
	# Pawns with low reputation and no leadership role may challenge.
	if data.reputation_score < 40.0 and data.leadership_role == 0:
		if posmod(current_tick + pawn_id * 11, 500) < 20:
			urges.append(Urge.new(Urge.Type.CHALLENGE, 1.5, Urge.Source.SOCIAL, current_tick))

	# ── WARRIOR GUARD ──
	# Warriors in peacetime feel the urge to patrol.
	if data.current_profession == HeelKawnianData.Profession.WARRIOR:
		urges.append(Urge.new(Urge.Type.GUARD, 2.0, Urge.Source.SOCIAL, current_tick))

	# ── NEARBY PEER ATTRACTION ──
	# High-rapport nearby pawns are slightly attractive.
	for peer in nearby_pawns:
		var rapport: float = float(peer.get("rapport", 0.0))
		var dist: int = int(peer.get("distance", 999))
		if rapport > 50.0 and dist <= 20:
			var social_pri: float = 0.5 + rapport / 100.0
			urges.append(Urge.new(Urge.Type.SOCIALIZE, social_pri, Urge.Source.SOCIAL, current_tick))
			break  # One socialize urge is enough

	return urges


func _compute_loneliness(data: HeelKawnianData, nearby_pawns: Array) -> float:
	var score: float = 0.0
	# No household → lonely
	if data.household_id < 0:
		score += 0.3
	# No clan → slightly lonely
	if data.clan_id < 0:
		score += 0.2
	# Few nearby pawns → lonely
	if nearby_pawns.size() <= 1:
		score += 0.3
	elif nearby_pawns.size() <= 3:
		score += 0.1
	# Low mood → amplifies loneliness
	if data.mood < 40.0:
		score += 0.2
	return clampf(score, 0.0, 1.0)


static func posmod(a: int, b: int) -> int:
	var m: int = a % b
	if m < 0:
		m += b
	return m
