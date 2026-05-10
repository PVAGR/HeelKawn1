## CombatResolver.gd — Handles melee combat rounds between pawns and enemies
class_name CombatResolver

# Combat mechanics tuning
const BASE_HIT_CHANCE: float = 0.75  # 75% base hit probability
const BASE_DODGE_CHANCE: float = 0.2  # 20% dodge chance (enemy type dependent)
const BASE_DAMAGE: float = 10.0
const SKILL_ACCURACY_BONUS_PER_LEVEL: float = 0.02  # 2% accuracy per skill level
const SKILL_DODGE_BONUS_PER_LEVEL: float = 0.02  # 2% dodge per rest level (endurance proxy)
const KROND_PER_KILL: float = 25.0

# Ranged combat constants
const RANGED_BASE_HIT_CHANCE: float = 0.5
const RANGED_MAX_RANGE: float = 12.0  # tiles
const RANGED_MIN_RANGE: float = 2.0   # minimum range (can't shoot adjacent)
const RANGED_DAMAGE_FALLOFF: float = 0.08  # -8% damage per tile beyond optimal
const RANGED_OPTIMAL_RANGE: float = 5.0
const RANGED_AMMO_PER_SHOT: int = 1

# Armor DR constants
const ARMOR_DR_PER_POINT: float = 0.06  # 6% DR per defense point
const ARMOR_DR_CAP: float = 0.80       # 80% max DR
const ARMOR_PIERCE_PER_SKILL: float = 0.005  # 0.5% armor pierce per skill level

static func _actor_seed_part(actor: Node) -> String:
	if actor is HeelKawnian:
		var pawn: HeelKawnian = actor as HeelKawnian
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
	if attacker is HeelKawnian:
		var pawn_attacker: HeelKawnian = attacker as HeelKawnian
		var avg_skill: float = _get_average_skill(pawn_attacker.data) / 100.0
		hit_chance += SKILL_ACCURACY_BONUS_PER_LEVEL * avg_skill
	
	# Apply defender dodge (for pawns, use rest as endurance proxy)
	if defender is HeelKawnian:
		var pawn_defender: HeelKawnian = defender as HeelKawnian
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
	if defender is HeelKawnian:
		var pawn_defender: HeelKawnian = defender as HeelKawnian
		pawn_defender.data.health = max(0.0, pawn_defender.data.health - damage)
		pawn_defender.on_hit_feedback(damage)
		pawn_defender.data.add_mood_event(MoodEvent.Type.STRESS, 60.0, 300)
		
		# DEAD BRAIN REVIVED: CombatNarrative generates Kenshi-style combat text
		if CombatNarrative != null:
			var attacker_name: String = _combat_name(attacker)
			var defender_name: String = pawn_defender.data.display_name
			var weapon_name: String = _weapon_name(attacker)
			var damage_int: int = int(damage)
			var is_critical: bool = damage > 20.0
			var narrative: String = CombatNarrative.generate_attack_narrative(attacker_name, defender_name, weapon_name, damage_int, true, is_critical)
			if not narrative.is_empty() and WorldMemory != null:
				WorldMemory.record_event({
					"type": "combat_narrative",
					"category": "combat",
					"severity": 2,
					"narrative": narrative,
					"tick": GameManager.tick_count,
					"tile": {"x": int(pawn_defender.data.tile_pos.x), "y": int(pawn_defender.data.tile_pos.y)},
				})
		
		# Injury check: small chance to get injured
		if WorldRNG.chance_for(_combat_stream("injury", attacker, defender), 0.15, _combat_salt(5)):
			pawn_defender.data.add_mood_event(MoodEvent.Type.STRESS, 40.0, 200)
		
		if pawn_defender.data.health <= 0:
			pawn_defender._check_death_conditions()
			# DEAD BRAIN REVIVED: BattleReporter records HeelKawnian death in combat
			if BattleReporter != null:
				BattleReporter.record_combat_death(int(pawn_defender.data.id), int(_combat_id(attacker)), pawn_defender.data.tile_pos)
		
		if GameManager.tick_count % 100 == 0:
			print("[Combat] HeelKawnian %s took %.1f damage (health %.1f)" %
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
			if attacker is HeelKawnian and WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
				var pawn_attacker: HeelKawnian = attacker as HeelKawnian
				WorldEvents.record_pawn_action("combat_kill", int(pawn_attacker.data.id))
			
			# Award krond to the pawn attacker (deterministic, fixed amount)
			if attacker is HeelKawnian:
				var pawn_attacker: HeelKawnian = attacker as HeelKawnian
				if pawn_attacker.data != null and pawn_attacker.data.has_method("grant_krond"):
					pawn_attacker.data.grant_krond(KROND_PER_KILL)
			var main_node: Node = attacker.get_tree().get_root().get_node_or_null("Main") if attacker != null else null
			if main_node != null and main_node.has_method("register_enemy_kill"):
				main_node.call("register_enemy_kill", enemy_name, attacker_name, enemy_defender.tile_pos)
	
	return true


## Execute one ranged attack from attacker to defender at given tile distance
static func resolve_ranged_attack(attacker: Node, defender: Node, distance_tiles: float) -> bool:
	if attacker == null or defender == null:
		return false
	if distance_tiles < RANGED_MIN_RANGE or distance_tiles > RANGED_MAX_RANGE:
		return false
	
	# Check ammo if attacker is a pawn
	if attacker is HeelKawnian:
		var pawn: HeelKawnian = attacker as HeelKawnian
		if not _has_ranged_ammo(pawn):
			return false
		_consume_ranged_ammo(pawn)
	
	# Hit chance based on distance (optimal range = best chance)
	var range_factor: float = 1.0 - abs(distance_tiles - RANGED_OPTIMAL_RANGE) * 0.05
	range_factor = clampf(range_factor, 0.3, 1.0)
	var hit_chance: float = RANGED_BASE_HIT_CHANCE * range_factor
	
	# Attacker skill bonus
	if attacker is HeelKawnian:
		var pawn_a: HeelKawnian = attacker as HeelKawnian
		var hunting_skill: float = pawn_a.data.skill_xp.get(HeelKawnianData.Skill.HUNTING, 0.0) / 100.0
		hit_chance += hunting_skill * 0.15
	
	# Defender dodge
	if defender is HeelKawnian:
		var pawn_d: HeelKawnian = defender as HeelKawnian
		hit_chance *= (1.0 - pawn_d.data.rest * 0.001)
	
	hit_chance = clampf(hit_chance, 0.1, 0.9)
	
	if not WorldRNG.chance_for(_combat_stream("ranged_hit", attacker, defender), hit_chance, _combat_salt(7)):
		return false
	
	# Damage with distance falloff
	var damage: float = BASE_DAMAGE * 0.7  # Ranged base is lower
	if distance_tiles > RANGED_OPTIMAL_RANGE:
		damage *= (1.0 - (distance_tiles - RANGED_OPTIMAL_RANGE) * RANGED_DAMAGE_FALLOFF)
	damage = max(3.0, damage)
	
	# Apply damage (same as melee but without armor pierce from skills)
	return _apply_damage(attacker, defender, damage)


## Check if attacker has ranged ammo (carrying ammo-type items)
	static func _has_ranged_ammo(pawn_node: Node) -> bool:
	if not (pawn_node is HeelKawnian):
		return true  # Enemies always have ammo
	var p: HeelKawnian = pawn_node as HeelKawnian
	if p.data == null:
		return false
	# Check if pawn is carrying a throwable/ammo item, or has nearby stockpile with ammo
	var carry: int = int(p.data.carrying)
	if carry == Item.Type.STONE or carry == Item.Type.STICK \
			or carry == Item.Type.STONE_ARROW or carry == Item.Type.BONE_ARROW:
		return true
	return false


## Consume one unit of ammo from the pawn's carry slot
static func _consume_ranged_ammo(pawn_node: Node) -> void:
	if not (pawn_node is HeelKawnian):
		return
	var p: HeelKawnian = pawn_node as HeelKawnian
	if p.data == null:
		return
	var carry: int = int(p.data.carrying)
	if carry == Item.Type.STONE or carry == Item.Type.STICK \
			or carry == Item.Type.STONE_ARROW or carry == Item.Type.BONE_ARROW:
		p.data.carrying = Item.Type.NONE


## Apply damage to defender and return true if hit landed
static func _apply_damage(attacker: Node, defender: Node, damage: float) -> bool:
	if defender is HeelKawnian:
		var pawn_defender: HeelKawnian = defender as HeelKawnian
		pawn_defender.data.health = max(0.0, pawn_defender.data.health - damage)
		pawn_defender.on_hit_feedback(damage)
		pawn_defender.data.add_mood_event(MoodEvent.Type.STRESS, 60.0, 300)
		if pawn_defender.data.health <= 0:
			pawn_defender._check_death_conditions()
		return true
	elif defender is Enemy:
		var enemy_defender: Enemy = defender as Enemy
		enemy_defender.take_damage(damage)
		return enemy_defender.health <= 0
	return false


## Calculate effective armor damage reduction for a pawn
static func _calculate_armor_dr(defender: HeelKawnian) -> float:
	if defender == null or defender.data == null:
		return 0.0
	var gear_stats: Dictionary = defender.data.get_gear_stats()
	var defense: float = float(gear_stats.get("defense", 0.0))
	# Quality multiplier from equipped gear
	var gear: Dictionary = defender.data.get("equipped_gear", {})
	var equipped_weapon = gear.get(0, null)
	if equipped_weapon != null and equipped_weapon is Dictionary:
		defense += float(equipped_weapon.get("quality_mult", 1.0)) * 2.0
	var armor_dr: float = defense * ARMOR_DR_PER_POINT
	# Trait-based reduction
	var trait_mult: float = 1.0
	if defender.data.has_method("get_trait_mult"):
		trait_mult = defender.data.get_trait_mult("damage_taken_mult")
	armor_dr += (trait_mult - 1.0) * 0.3
	return clampf(armor_dr, 0.0, ARMOR_DR_CAP)


## Calculate damage from attacker to defender (melee)
static func _calculate_damage(attacker: Node, defender: Node) -> float:
	var damage: float = BASE_DAMAGE

	# Attacker modifiers
	if attacker is HeelKawnian:
		var pawn_attacker: HeelKawnian = attacker as HeelKawnian
		# Skill-based damage: mining/hunting skills translate to combat
		var combat_skill: float = (pawn_attacker.data.skill_xp.get(HeelKawnianData.Skill.HUNTING, 0.0) +
									pawn_attacker.data.skill_xp.get(HeelKawnianData.Skill.MINING, 0.0)) / 200.0
		damage *= (1.0 + combat_skill * 0.5)  # Up to 50% damage increase from skills

		# Gear-based attack bonus (weapon + quality)
		var gear_stats: Dictionary = pawn_attacker.data.get_gear_stats()
		damage *= (float(gear_stats.get("attack", 1.0)) / 1.0)

		# Health/rest affects damage
		damage *= pawn_attacker.data.effective_labor_mult()

		# Trait multipliers
		damage *= pawn_attacker.data.get_trait_mult("work_speed_mult")

	elif attacker is Enemy:
		var enemy: Enemy = attacker as Enemy
		var spec = Enemy.SPECIES_DATA.get(enemy.enemy_type, {})
		damage = spec.get("melee_damage", BASE_DAMAGE)

	# Defender armor reduction (only for pawn defenders)
	if defender is HeelKawnian:
		var pawn_defender: HeelKawnian = defender as HeelKawnian
		var armor_dr: float = _calculate_armor_dr(pawn_defender)
		# Attacker skill pierces armor
		if attacker is HeelKawnian:
			var a_pawn: HeelKawnian = attacker as HeelKawnian
			var avg_skill: float = _get_average_skill(a_pawn.data) / 100.0
			var pierce: float = avg_skill * ARMOR_PIERCE_PER_SKILL
			armor_dr = max(0.0, armor_dr - pierce)
		damage *= (1.0 - armor_dr)

	return max(1.0, damage)


## Get average of all skill levels (for accuracy calculation)
static func _get_average_skill(pawn_data: HeelKawnianData) -> float:
	var total: float = 0.0
	var count: int = 0
	for skill_xp in pawn_data.skill_xp.values():
		total += skill_xp
		count += 1
	return total / max(1, count)


static func _combat_name(actor: Node) -> String:
	if actor == null:
		return "Unknown"
	if actor is HeelKawnian:
		var p: HeelKawnian = actor as HeelKawnian
		if p.data != null:
			return p.data.display_name
		return "HeelKawnian"
	if actor is Enemy:
		var e: Enemy = actor as Enemy
		return e.get_species_name()
	return actor.name


static func _weapon_name(actor: Node) -> String:
	if actor == null:
		return "fists"
	if actor is HeelKawnian:
		var p: HeelKawnian = actor as HeelKawnian
		if p.data != null and p.data.is_carrying():
			var carry: int = int(p.data.carrying)
			match carry:
				Item.Type.FLINT_KNIFE: return "flint knife"
				Item.Type.WOODEN_SPEAR: return "wooden spear"
				Item.Type.FLINT_PICK: return "flint pick"
				Item.Type.TORCH: return "torch"
				Item.Type.STONE: return "stone"
				Item.Type.STICK: return "stick"
				_: return "a weapon"
	return "claws"


static func _combat_id(actor: Node) -> int:
	if actor == null:
		return -1
	if actor is HeelKawnian:
		var p: HeelKawnian = actor as HeelKawnian
		if p.data != null:
			return int(p.data.id)
	if actor is Enemy:
		var e: Enemy = actor as Enemy
		return e.get_instance_id()
	return -1


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
	if not (attacker is HeelKawnian):
		return
	var leader: HeelKawnian = attacker as HeelKawnian
	if leader.data == null:
		return
	if _is_anarchy_combat(attacker, defender):
		return
	var leader_rank: String = str(leader.data.military_rank_legacy).to_lower()
	if leader_rank == "grunt":
		return
	var target_pos: Vector2i = leader.data.tile_pos
	if defender is HeelKawnian and (defender as HeelKawnian).data != null:
		target_pos = (defender as HeelKawnian).data.tile_pos
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
	if not (actor is HeelKawnian):
		return false
	var p: HeelKawnian = actor as HeelKawnian
	if p.data == null:
		return false
	if p.data.has_method("get_health_percentage"):
		return float(p.data.get_health_percentage()) < 0.5
	return false


static func _apply_anarchy_behavior(attacker: Node, defender: Node) -> void:
	var attacker_pawn: HeelKawnian = attacker as HeelKawnian if attacker is HeelKawnian else null
	if attacker_pawn == null or attacker_pawn.data == null:
		return
	var attacker_tile: Vector2i = attacker_pawn.data.tile_pos
	var defender_tile: Vector2i = attacker_tile
	if defender is HeelKawnian and (defender as HeelKawnian).data != null:
		defender_tile = (defender as HeelKawnian).data.tile_pos
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
