## CuriosityDrive.gd — Discovery impulses.
##
## Reads KnowledgeSystem, WorldData (unexplored tiles), FarmingSystem,
## CraftingSystem, and the pawn's own location memory.
## Pushes discovery urges: explore, rediscover, forge, innovate, wander.
##
## Curiosity is a drive. A pawn doesn't "randomly" explore — it feels
## the urge to visit unexplored places. A scholar doesn't "randomly"
## rediscover — it feels the pull of dormant knowledge.
extends RefCounted
class_name CuriosityDrive

const BASE_INTERVAL: int = 35

var _last_pulse_tick: int = -999999


func should_pulse(current_tick: int, game_speed: float) -> bool:
	var interval: int = BASE_INTERVAL
	if game_speed >= 100.0:
		interval = 80
	elif game_speed >= 50.0:
		interval = 60
	elif game_speed >= 26.0:
		interval = 45
	if current_tick - _last_pulse_tick < interval:
		return false
	_last_pulse_tick = current_tick
	return true


## Pulse: check curiosity state and push urges.
## unexplored_tiles: Array of Vector2i near the pawn that it hasn't visited
func pulse(data: HeelKawnianData, unexplored_tiles: Array, current_tick: int) -> Array[Urge]:
	var urges: Array[Urge] = []
	if data == null:
		return urges

	var pawn_id: int = int(data.id)

	# Curiosity only fires when basic needs are met.
	# You don't explore when you're starving.
	if data.hunger < 40.0 or data.rest < 30.0:
		return urges

	# ── EXPLORE ──
	# Unexplored tiles pull at curious pawns.
	# Scholars and young pawns are more curious.
	var curiosity_base: float = 1.0
	if data.current_profession == HeelKawnianData.Profession.SCHOLAR:
		curiosity_base = 2.0
	if data.life_stage == HeelKawnianData.LifeStage.CHILD or data.life_stage == HeelKawnianData.LifeStage.YOUTH:
		curiosity_base *= 1.5

	if not unexplored_tiles.is_empty():
		var explore_urge: Urge = Urge.new(Urge.Type.EXPLORE, curiosity_base, Urge.Source.CURIOSITY, current_tick)
		# Pick the nearest unexplored tile
		var best_tile: Vector2i = unexplored_tiles[0]
		var best_dist: int = absi(best_tile.x - data.tile_pos.x) + absi(best_tile.y - data.tile_pos.y)
		for t in unexplored_tiles:
			var d: int = absi(t.x - data.tile_pos.x) + absi(t.y - data.tile_pos.y)
			if d < best_dist:
				best_dist = d
				best_tile = t
		explore_urge.target_tile = best_tile
		urges.append(explore_urge)

	# ── REDISCOVER ──
	# Scholars near dormant knowledge sites feel the pull.
	if data.current_profession == HeelKawnianData.Profession.SCHOLAR:
		if KnowledgeSystem != null and KnowledgeSystem.has_method("get_dormant_knowledge_types"):
			var dormant: Array = KnowledgeSystem.get_dormant_knowledge_types()
			if not dormant.is_empty():
				urges.append(Urge.new(Urge.Type.REDISCOVER, 2.5, Urge.Source.CURIOSITY, current_tick))

	# ── FORGE ──
	# Pawns with crafting skill and available materials feel the urge to craft.
	if CraftingSystem != null and CraftingSystem.has_method("get_available_recipes"):
		# Build a simple inventory dict from what the pawn is carrying
		var inventory: Dictionary = {}
		if data.is_carrying():
			inventory[data.carrying] = 1
		var available: Array = CraftingSystem.get_available_recipes(inventory)
		if not available.is_empty():
			urges.append(Urge.new(Urge.Type.FORGE, 1.5, Urge.Source.CURIOSITY, current_tick))

	# ── INNOVATE ──
	# Innovation is handled internally by KnowledgeSystem._check_innovation_opportunities.
	# The urge here is a nudge: if a pawn has many knowledge items, it might
	# be close to an innovation breakthrough.
	if KnowledgeSystem != null and KnowledgeSystem.has_method("get_pawn_knowledge"):
		var my_knowledge: Array = KnowledgeSystem.get_pawn_knowledge(pawn_id)
		if my_knowledge.size() >= 6:
			# Scholar profession gets higher innovation urge
			var innov_pri: float = 1.5
			if data.current_profession == HeelKawnianData.Profession.SCHOLAR:
				innov_pri = 2.5
			urges.append(Urge.new(Urge.Type.INNOVATE, innov_pri, Urge.Source.CURIOSITY, current_tick))

	# ── WANDER ──
	# When no other urge is strong, restlessness pushes a wander.
	# This is the lowest-priority urge — it only fires when nothing else matters.
	# Wanderlust is personality-dependent.
	var wanderlust: float = 0.5  # Default
	if data.neural_network != null and data.neural_network.has_method("get_wanderlust"):
		wanderlust = float(data.neural_network.get_wanderlust())
	var wander_pri: float = 0.3 + wanderlust * 0.5
	urges.append(Urge.new(Urge.Type.WANDER, wander_pri, Urge.Source.CURIOSITY, current_tick))

	return urges
