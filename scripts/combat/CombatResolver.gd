## CombatResolver.gd — Handles melee combat rounds between pawns and enemies
class_name CombatResolver

# Combat mechanics tuning
const BASE_HIT_CHANCE: float = 0.75  # 75% base hit probability
const BASE_DODGE_CHANCE: float = 0.2  # 20% dodge chance (enemy type dependent)
const BASE_DAMAGE: float = 10.0
const SKILL_ACCURACY_BONUS_PER_LEVEL: float = 0.02  # 2% accuracy per skill level
const SKILL_DODGE_BONUS_PER_LEVEL: float = 0.02  # 2% dodge per rest level (endurance proxy)
const KROND_PER_KILL: float = 25.0

static func _actor_seed_part(actor: Node) -> String:
	if actor is Pawn:
		var pawn: Pawn = actor as Pawn
		if pawn.data != null:
			return "pawn:%d" % int(pawn.data.id)
	if actor is Enemy:
		var enemy: Enemy = actor as Enemy
		return "enemy:%d:%d:%d" % [int(enemy.enemy_type), enemy.tile_pos.x, enemy.tile_pos.y]
	return str(actor.name) if actor != null else "none"


static func _combat_stream(label: String, attacker: Node, defender: Node) -> StringName:
	return StringName("combat:%s:%s:%s" % [label, _actor_seed_part(attacker), _actor_seed_part(defender)])


static func _combat_salt(extra: int = 0) -> int:
	return GameManager.tick_count + extra

## Execute one attack from attacker to defender. Returns true if hit landed.
## Defender takes damage, loses health, may be injured.
static func resolve_attack(attacker: Node, defender: Node) -> bool:
	if attacker == null or defender == null:
		return false
	if _is_anarchy_combat(attacker, defender):
		_apply_anarchy_behavior(attacker, defender)
		if GameManager.tick_count % 100 == 0:
			print("[War] The field of battle is for the soldiers who spill their blood.")
	else:
		_maybe_issue_attack_move(attacker, defender)
	
	# Determine if attack hits
	var hit_chance: float = BASE_HIT_CHANCE
	
	# Apply attacker accuracy (for pawns, use skill levels)
	if attacker is Pawn:
		var pawn_attacker: Pawn = attacker as Pawn
		var avg_skill: float = _get_average_skill(pawn_attacker.data) / 100.0
		hit_chance += SKILL_ACCURACY_BONUS_PER_LEVEL * avg_skill
	
	# Apply defender dodge (for pawns, use rest as endurance proxy)
	if defender is Pawn:
		var pawn_defender: Pawn = defender as Pawn
		var dodge_chance: float = pawn_defender.data.rest * 0.002 + 0.1  # 10% base + 0.2% per rest
		hit_chance = hit_chance * (1.0 - dodge_chance)
	elif defender is Enemy:
		var enemy: Enemy = defender as Enemy
		var _spec = Enemy.SPECIES_DATA.get(enemy.enemy_type, {})
		var dodge_chance: float = BASE_DODGE_CHANCE
		hit_chance *= (1.0 - dodge_chance)

	hit_chance = clamp(hit_chance, 0.2, 0.95)

	# Roll to hit
	if not WorldRNG.chance_for(_combat_stream("hit", attacker, defender), hit_chance, _combat_salt(3)):
		return false

	# Calculate damage
	var damage: float = _calculate_damage(attacker, defender)

	# Apply damage
	if defender is Pawn:
		var pawn_defender: Pawn = defender as Pawn
		pawn_defender.data.health = max(0.0, pawn_defender.data.health - damage)
		pawn_defender.on_hit_feedback(damage)
		pawn_defender.data.add_mood_event(MoodEvent.Type.STRESS, 60.0, 300)
		
		# Injury check: small chance to get injured
		if WorldRNG.chance_for(_combat_stream("injury", attacker, defender), 0.15, _combat_salt(5)):
			pawn_defender.data.add_mood_event(MoodEvent.Type.STRESS, 40.0, 200)
		
		if pawn_defender.data.health <= 0:
			pawn_defender._check_death_conditions()
		
		if GameManager.tick_count % 100 == 0:
			print("[Combat] Pawn %s took %.1f damage (health %.1f)" %
				[pawn_defender.data.display_name, damage, pawn_defender.data.health])
	
	elif defender is Enemy:
		var enemy_defender: Enemy = defender as Enemy
		var before_hp: float = enemy_defender.health
		enemy_defender.take_damage(damage)
		if GameManager.tick_count % 100 == 0:
			print("[Combat] Enemy %s took %.1f damage (health %.1f)" %
				[enemy_defender.get_species_name(), damage, enemy_defender.health])
		if before_hp > 0.0 and enemy_defender.health <= 0.0:
			var attacker_name: String = _combat_name(attacker)
			var enemy_name: String = enemy_defender.get_species_name()
			print("[Combat] Enemy %s killed by %s" % [enemy_name, attacker_name])
			
			# PAWN-ACTIVATED EVENT: Record combat kill for event system
			if attacker is Pawn and WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
				var pawn_attacker: Pawn = attacker as Pawn
				WorldEvents.record_pawn_action("combat_kill", int(pawn_attacker.data.id))
			
			# Award krond to the pawn attacker (deterministic, fixed amount)
			if attacker is Pawn:
				var pawn_attacker: Pawn = attacker as Pawn
				if pawn_attacker.data != null and pawn_attacker.data.has_method("grant_krond"):
					pawn_attacker.data.grant_krond(KROND_PER_KILL)
			var main_node: Node = attacker.get_tree().get_root().get_node_or_null("Main") if attacker != null else null
			if main_node != null and main_node.has_method("register_enemy_kill"):
				main_node.call("register_enemy_kill", enemy_name, attacker_name, enemy_defender.tile_pos)
	
	return true


## Calculate damage from attacker to defender
static func _calculate_damage(attacker: Node, defender: Node) -> float:
	var damage: float = BASE_DAMAGE
	
	# Attacker modifiers
	if attacker is Pawn:
		var pawn_attacker: Pawn = attacker as Pawn
		# Skill-based damage: mining/hunting skills translate to combat
		var combat_skill: float = (pawn_attacker.data.skill_xp.get(PawnData.Skill.HUNTING, 0.0) +
									pawn_attacker.data.skill_xp.get(PawnData.Skill.MINING, 0.0)) / 200.0
		damage *= (1.0 + combat_skill * 0.5)  # Up to 50% damage increase from skills
		
		# Health/rest affects damage
		damage *= pawn_attacker.data.effective_labor_mult()
		
		# Trait multipliers
		damage *= pawn_attacker.data.get_trait_mult("work_speed_mult")
	
	elif attacker is Enemy:
		var enemy: Enemy = attacker as Enemy
		var spec = Enemy.SPECIES_DATA.get(enemy.enemy_type, {})
		damage = spec.get("melee_damage", BASE_DAMAGE)
	
	# Defender reduction
	if defender is Pawn:
		var pawn_defender: Pawn = defender as Pawn
		# Armor concept: health affects damage reduction
		var armor_factor: float = 1.0 - (pawn_defender.data.get_trait_mult("damage_taken_mult") - 1.0)
		armor_factor = clamp(armor_factor, 0.0, 0.95)
		damage *= (1.0 - armor_factor)
	
	return max(1.0, damage)


## Get average of all skill levels (for accuracy calculation)
static func _get_average_skill(pawn_data: PawnData) -> float:
	var total: float = 0.0
	var count: int = 0
	for skill_xp in pawn_data.skill_xp.values():
		total += skill_xp
		count += 1
	return total / max(1, count)


static func _combat_name(actor: Node) -> String:
	if actor == null:
		return "Unknown"
	if actor is Pawn:
		var p: Pawn = actor as Pawn
		if p.data != null:
			return p.data.display_name
		return "Pawn"
	if actor is Enemy:
		var e: Enemy = actor as Enemy
		return e.get_species_name()
	return actor.name


static func _rank_value(rank_name: String) -> int:
	match rank_name:
		"battlemaster":
			return 5
		"commander":
			return 4
		"captain":
			return 3
		"sarj":
			return 2
		_:
			return 1


static func _is_anarchy_combat(attacker: Node, defender: Node) -> bool:
	var attacker_low: bool = _pawn_below_anarchy_threshold(attacker)
	var defender_low: bool = _pawn_below_anarchy_threshold(defender)
	return attacker_low or defender_low


static func _maybe_issue_attack_move(attacker: Node, defender: Node) -> void:
	if not (attacker is Pawn):
		return
	var leader: Pawn = attacker as Pawn
	if leader.data == null:
		return
	if _is_anarchy_combat(attacker, defender):
		return
	var leader_rank: String = str(leader.data.military_rank_legacy).to_lower()
	if leader_rank == "grunt":
		return
	var target_pos: Vector2i = leader.data.tile_pos
	if defender is Pawn and (defender as Pawn).data != null:
		target_pos = (defender as Pawn).data.tile_pos
	elif defender is Enemy:
		target_pos = (defender as Enemy).tile_pos
	var leader_score: int = _rank_value(leader_rank)
	for ally in PawnSpawner.find_pawns():
		if ally == leader or ally.data == null:
			continue
		if ally.position.distance_squared_to(leader.position) > 22.0 * 22.0:
			continue
		var ally_rank: String = str(ally.data.military_rank_legacy).to_lower()
		if _rank_value(ally_rank) >= leader_score:
			continue
		if ally.has_method("draft_goto"):
			ally.call("draft_goto", target_pos)


static func _pawn_below_anarchy_threshold(actor: Node) -> bool:
	if not (actor is Pawn):
		return false
	var p: Pawn = actor as Pawn
	if p.data == null:
		return false
	if p.data.has_method("get_health_percentage"):
		return float(p.data.get_health_percentage()) < 0.5
	return false


static func _apply_anarchy_behavior(attacker: Node, defender: Node) -> void:
	var attacker_pawn: Pawn = attacker as Pawn if attacker is Pawn else null
	if attacker_pawn == null or attacker_pawn.data == null:
		return
	var attacker_tile: Vector2i = attacker_pawn.data.tile_pos
	var defender_tile: Vector2i = attacker_tile
	if defender is Pawn and (defender as Pawn).data != null:
		defender_tile = (defender as Pawn).data.tile_pos
	elif defender is Enemy:
		defender_tile = (defender as Enemy).tile_pos
	var retreat: bool = _pawn_below_anarchy_threshold(attacker_pawn)
	var target_tile: Vector2i = defender_tile
	if retreat:
		var delta: Vector2i = attacker_tile - defender_tile
		if delta == Vector2i.ZERO:
			delta = Vector2i(1, 0)
		target_tile = attacker_tile + Vector2i(signi(delta.x), signi(delta.y))
	else:
		target_tile = defender_tile
	if attacker_pawn.has_method("draft_goto"):
		attacker_pawn.call("draft_goto", target_tile)
