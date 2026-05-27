extends Node
## NationBorderSystem — CK-style dynamic nation formation and border tracking.
##
## Nations emerge organically from settlements through:
## - Alliances merging into unified polities
## - Conquest and vassalage
## - Cultural/linguistic cohesion
## - Geographic proximity + shared trade
##
## Borders are computed from:
## - Settlement influence radius (population-based)
## - Patrol/defense presence
## - Road connectivity
## - Loyalty of border regions
##
## Design principles:
## - Nations form/dissolve/split/merge dynamically
## - Borders shift gradually, not instantly
## - Every border tile has a loyalty score
## - Wars redraw borders through contested zones
## - The map visually shows nation colors

# ============================================================
# CONSTANTS
# ============================================================

## How often to recompute nation borders (ticks)
const BORDER_RECOMPUTE_INTERVAL: int = 2000

## How often to check for nation formation/merger/split (ticks)
const NATION_STATE_INTERVAL: int = 5000

## Base influence radius per settlement (in tiles)
const BASE_INFLUENCE_RADIUS: int = 16

## Influence radius added per population point
const INFLUENCE_PER_POP: int = 2

## Max influence radius (prevents runaway expansion)
const MAX_INFLUENCE_RADIUS: int = 64

## Minimum population to form a nation
const NATION_MIN_POPULATION: int = 10

## Minimum settlements to form a multi-settlement nation
const NATION_MIN_SETTLEMENTS: int = 2

## Border loyalty decay rate (tiles far from center lose loyalty)
const BORDER_LOYALTY_DECAY: float = 0.02

## Border loyalty gain from settlement presence
const BORDER_LOYALTY_GAIN: float = 0.05

## Contested border threshold (loyalty difference < this = contested)
const CONTESTED_THRESHOLD: float = 0.15

## War border shift rate (tiles per recomputation during war)
const WAR_BORDER_SHIFT_RATE: float = 0.03

## Nation color palette (deterministic assignment)
const NATION_COLORS: PackedStringArray = [
	"#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400",
	"#16a085", "#c0392b", "#2c3e50", "#f39c12", "#1abc9c",
	"#e74c3c", "#3498db", "#2ecc71", "#9b59b6", "#e67e22",
	"#1abc9c", "#34495e", "#f1c40f", "#e74c3c", "#2980b9",
]

# ============================================================
# NATION DATA STRUCTURE
# ============================================================

## nations: nation_id -> Dictionary
## {
##   "id": int,
##   "name": String,
##   "color": String,  # hex color for map rendering
##   "capital_region": int,  # center_region of capital settlement
##   "settlements": Array[int],  # center_regions of member settlements
##   "population": int,
##   "territory": Dictionary,  # region_key -> loyalty (0.0-1.0)
##   "government_type": String,  # "tribal", "chiefdom", "kingdom", "republic", "empire"
##   "leader_id": int,  # pawn_id of nation leader
##   "formed_tick": int,
##   "relations": Dictionary,  # nation_id -> relation_score (-100 to 100)
##   "at_war_with": Array[int],  # nation_ids
##   "allied_with": Array[int],  # nation_ids
##   "culture": String,
##   "prestige": float,
##   "stability": float,  # 0.0-1.0
## }
var nations: Dictionary = {}
var _next_nation_id: int = 1

# ============================================================
# BORDER/INFLUENCE MAP
# ============================================================

## Per-region nation ownership: region_key -> nation_id (or -1 for unclaimed)
var _region_ownership: Dictionary = {}

## Per-region loyalty to owning nation: region_key -> float (0.0-1.0)
var _region_loyalty: Dictionary = {}

## Contested regions: region_key -> {"nation_a": int, "nation_b": int, "contest_intensity": float}
var _contested_regions: Dictionary = {}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Recompute borders periodically
	if tick % BORDER_RECOMPUTE_INTERVAL == 0:
		_recompute_borders(tick)
	# Check for nation state changes
	if tick % NATION_STATE_INTERVAL == 0:
		_check_nation_state_changes(tick)


# ============================================================
# NATION FORMATION
# ============================================================

func _check_nation_state_changes(tick: int) -> void:
	"""Check if settlements should form nations, merge, or split."""
	if SettlementMemory == null:
		return
	# Try forming new nations from qualifying settlements
	_try_form_nations(tick)
	# Try merging allied nations
	_try_merge_nations(tick)
	# Check for nation splits (low stability regions)
	_try_split_nations(tick)
	# Update nation governments based on progression
	_update_nation_governments(tick)


func _try_form_nations(tick: int) -> void:
	"""Form nations from settlements that meet criteria."""
	var settlements: Array = SettlementMemory.settlements
	if settlements.is_empty():
		return
	# Group settlements by cultural proximity and alliance status
	var groups: Array = _group_settlements_for_nation(settlements)
	for group in groups:
		if group.size() < NATION_MIN_SETTLEMENTS:
			continue
		var total_pop: int = 0
		for s in group:
			if s is Dictionary:
				total_pop += int(s.get("population", 0))
		if total_pop < NATION_MIN_POPULATION:
			continue
		# Check if these settlements already belong to a nation
		var already_nation: bool = false
		for s in group:
			if s is Dictionary:
				var srk: int = int(s.get("center_region", -1))
				if _get_nation_for_settlement(srk) >= 0:
					already_nation = true
					break
		if already_nation:
			continue
		# Form a new nation
		_form_nation_from_group(group, tick)


func _group_settlements_for_nation(settlements: Array) -> Array:
	"""Group settlements by cultural proximity and diplomatic relations."""
	var groups: Array = []
	var assigned: Dictionary = {}
	for s in settlements:
		if not (s is Dictionary):
			continue
		var srk: int = int(s.get("center_region", -1))
		if assigned.has(srk):
			continue
		var group: Array = [s]
		assigned[srk] = true
		# Find allied/culturally similar settlements
		for other in settlements:
			if not (other is Dictionary):
				continue
			var ork: int = int(other.get("center_region", -1))
			if assigned.has(ork):
				continue
			if _are_settlements_aligned(s, other):
				group.append(other)
				assigned[ork] = true
		if group.size() >= NATION_MIN_SETTLEMENTS:
			groups.append(group)
	return groups


func _are_settlements_aligned(a: Dictionary, b: Dictionary) -> bool:
	"""Check if two settlements are aligned (allied, same culture, close)."""
	var ar: int = int(a.get("center_region", -1))
	var br: int = int(b.get("center_region", -1))
	if ar < 0 or br < 0:
		return false
	# Check diplomatic relations
	if FactionManager != null and FactionManager.has_method("get_relation"):
		var relation: int = FactionManager.get_relation(ar, br)
		if relation >= 50:  # Allied or very friendly
			return true
	# Check cultural similarity
	var a_culture: String = str(a.get("culture", ""))
	var b_culture: String = str(b.get("culture", ""))
	if a_culture != "" and a_culture == b_culture:
		return true
	# Check geographic proximity
	var adist: int = _region_distance(ar, br)
	if adist <= 3:
		return true
	return false


func _region_distance(ra: int, rb: int) -> int:
	"""Chebyshev distance between two regions."""
	var ax: int = ra & 0xFFFF
	var ay: int = (ra >> 16) & 0xFFFF
	var bx: int = rb & 0xFFFF
	var by: int = (rb >> 16) & 0xFFFF
	return maxi(abs(ax - bx), abs(ay - by))


func _form_nation_from_group(settlements: Array, tick: int) -> void:
	"""Form a new nation from a group of aligned settlements."""
	var nid: int = _next_nation_id
	_next_nation_id += 1
	var capital: Dictionary = settlements[0] as Dictionary
	var capital_rk: int = int(capital.get("center_region", -1))
	var total_pop: int = 0
	var member_regions: Array[int] = []
	var culture: String = str(capital.get("culture", "unknown"))
	for s in settlements:
		if s is Dictionary:
			total_pop += int(s.get("population", 0))
			member_regions.append(int(s.get("center_region", -1)))
			var sc: String = str(s.get("culture", ""))
			if sc != "":
				culture = sc
	var nation_name: String = _generate_nation_name(culture, capital, settlements)
	var color: String = _assign_nation_color(nid)
	var government: String = _determine_government(total_pop, settlements.size())
	nations[nid] = {
		"id": nid,
		"name": nation_name,
		"color": color,
		"capital_region": capital_rk,
		"settlements": member_regions,
		"population": total_pop,
		"territory": {},
		"government_type": government,
		"leader_id": _find_nation_leader(settlements),
		"formed_tick": tick,
		"relations": {},
		"at_war_with": [],
		"allied_with": [],
		"culture": culture,
		"prestige": float(total_pop) / 10.0,
		"stability": 0.8,
	}
	# Claim initial territory
	_claim_territory_for_nation(nid, tick)
	# Log nation formation
	if ChronicleNarrativeSystem != null:
		ChronicleNarrativeSystem._add_narrative(tick, "immediate", "nation",
			ChronicleNarrativeSystem._narrate_nation_formed({
				"name": nation_name,
				"founder": str(capital.get("name", "unknown settlements")),
				"territory": "the surrounding lands",
			}, ChronicleNarrativeSystem._tick_to_year(tick), ChronicleNarrativeSystem._tick_to_season_name(tick)),
			["nation_formed", nation_name])
	elif ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "The nation of %s was formed with %d settlements and %d people." % [nation_name, settlements.size(), total_pop],
			PackedStringArray(["nation", nation_name]))


# ============================================================
# TERRITORY CLAIMING
# ============================================================

func _claim_territory_for_nation(nation_id: int, tick: int) -> void:
	"""Claim territory around a nation's settlements based on influence."""
	var nation: Dictionary = nations.get(nation_id, {})
	if nation.is_empty():
		return
	var influence_radius: int = _compute_influence_radius(nation)
	# For each settlement, claim surrounding regions
	for srk in nation.get("settlements", []):
		var sx: int = srk & 0xFFFF
		var sy: int = (srk >> 16) & 0xFFFF
		for dx in range(-influence_radius / 16, influence_radius / 16 + 1):
			for dy in range(-influence_radius / 16, influence_radius / 16 + 1):
				var rx: int = sx + dx
				var ry: int = sy + dy
				var rk: int = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
				var dist: float = sqrt(float(dx * dx + dy * dy))
				var max_dist: float = float(influence_radius) / 16.0
				if dist > max_dist:
					continue
				# Loyalty decreases with distance from settlement
				var loyalty: float = 1.0 - (dist / max_dist) * 0.5
				# Check if already claimed by another nation
				var current_owner: int = _region_ownership.get(rk, -1)
				if current_owner == -1:
					_region_ownership[rk] = nation_id
					_region_loyalty[rk] = loyalty
					nation["territory"][rk] = loyalty
				elif current_owner == nation_id:
					# Update loyalty if higher
					_region_loyalty[rk] = maxf(float(_region_loyalty.get(rk, 0.0)), loyalty)
					nation["territory"][rk] = _region_loyalty[rk]
				else:
					# Contested! Check if this nation has stronger claim
					var other_loyalty: float = float(_region_loyalty.get(rk, 0.0))
					if loyalty > other_loyalty + CONTESTED_THRESHOLD:
						# Take over the region
						_region_ownership[rk] = nation_id
						_region_loyalty[rk] = loyalty
						nation["territory"][rk] = loyalty
						var other_nation: Dictionary = nations.get(current_owner, {})
						if other_nation.has("territory"):
							other_nation["territory"].erase(rk)
						# Mark as contested temporarily
						_contested_regions[rk] = {
							"nation_a": nation_id,
							"nation_b": current_owner,
							"contest_intensity": abs(loyalty - other_loyalty),
						}


func _compute_influence_radius(nation: Dictionary) -> int:
	"""Compute total influence radius for a nation."""
	var pop: int = int(nation.get("population", 0))
	var radius: int = BASE_INFLUENCE_RADIUS + (pop * INFLUENCE_PER_POP)
	return mini(radius, MAX_INFLUENCE_RADIUS)


# ============================================================
# BORDER RECOMPUTATION
# ============================================================

func _recompute_borders(tick: int) -> void:
	"""Recompute all nation borders, handling wars, loyalty decay, contested zones."""
	# Decay loyalty in border regions
	for rk in _region_loyalty.keys():
		var nation_id: int = _region_ownership.get(rk, -1)
		if nation_id < 0:
			continue
		var nation: Dictionary = nations.get(nation_id, {})
		if nation.is_empty():
			continue
		# Distance from capital affects loyalty
		var dist: int = _region_distance(rk, int(nation.get("capital_region", -1)))
		var decay: float = BORDER_LOYALTY_DECAY * float(dist) / 10.0
		_region_loyalty[rk] = maxf(0.0, float(_region_loyalty[rk]) - decay)
		# Update nation territory
		if nation.has("territory"):
			nation["territory"][rk] = _region_loyalty[rk]
	# Process contested regions
	var resolved: Array[int] = []
	for rk in _contested_regions.keys():
		var contest: Dictionary = _contested_regions[rk]
		var na: int = int(contest.get("nation_a", -1))
		var nb: int = int(contest.get("nation_b", -1))
		if na < 0 or nb < 0:
			resolved.append(rk)
			continue
		# Check if at war
		var na_nation: Dictionary = nations.get(na, {})
		var at_war: bool = na_nation.has("at_war_with") and nb in na_nation.get("at_war_with", [])
		if at_war:
			# War border shift: stronger nation gains ground
			var na_prestige: float = float(na_nation.get("prestige", 0.0))
			var nb_nation: Dictionary = nations.get(nb, {})
			var nb_prestige: float = float(nb_nation.get("prestige", 0.0))
			if na_prestige > nb_prestige:
				_region_loyalty[rk] = minf(1.0, float(_region_loyalty.get(rk, 0.0)) + WAR_BORDER_SHIFT_RATE)
				_region_ownership[rk] = na
			else:
				_region_loyalty[rk] = maxf(0.0, float(_region_loyalty.get(rk, 0.0)) - WAR_BORDER_SHIFT_RATE)
				if _region_loyalty[rk] <= 0.0:
					_region_ownership[rk] = nb
					if nb_nation.has("territory"):
						nb_nation["territory"][rk] = _region_loyalty[rk]
					resolved.append(rk)
			contest["contest_intensity"] = abs(float(_region_loyalty.get(rk, 0.5)) - 0.5) * 2.0
			if contest["contest_intensity"] < 0.1:
				resolved.append(rk)
		else:
			# Not at war: negotiate border
			var na_loyalty: float = float(_region_loyalty.get(rk, 0.0))
			if na_loyalty > 0.6:
				resolved.append(rk)  # Nation A keeps it
			elif na_loyalty < 0.4:
				_region_ownership[rk] = nb
				resolved.append(rk)
	# Remove resolved contested regions
	for rk in resolved:
		_contested_regions.erase(rk)
	# Update nation populations and prestige
	for nid in nations.keys():
		_update_nation_stats(nid)


func _update_nation_stats(nation_id: int) -> void:
	"""Update a nation's population, prestige, and stability."""
	var nation: Dictionary = nations.get(nation_id, {})
	if nation.is_empty():
		return
	# Recalculate population from settlements
	var total_pop: int = 0
	if SettlementMemory != null:
		for srk in nation.get("settlements", []):
			var st: Variant = SettlementMemory.get_settlement_at_region(srk)
			if st is Dictionary:
				total_pop += int(st.get("population", 0))
	nation["population"] = total_pop
	# Prestige based on population, territory, and stability
	var territory_size: int = nation.get("territory", {}).size()
	nation["prestige"] = float(total_pop) / 10.0 + float(territory_size) / 20.0
	# Stability decreases with contested regions and wars
	var contested_count: int = 0
	for rk in _contested_regions.keys():
		var contest: Dictionary = _contested_regions[rk]
		if int(contest.get("nation_a", -1)) == nation_id or int(contest.get("nation_b", -1)) == nation_id:
			contested_count += 1
	var war_penalty: float = float(nation.get("at_war_with", []).size()) * 0.1
	nation["stability"] = clampf(0.8 - float(contested_count) * 0.05 - war_penalty, 0.1, 1.0)


# ============================================================
# NATION MERGING AND SPLITTING
# ============================================================

func _try_merge_nations(tick: int) -> void:
	"""Merge nations that are highly allied and culturally similar."""
	var nation_ids: Array = nations.keys()
	for i in range(nation_ids.size()):
		for j in range(i + 1, nation_ids.size()):
			var na: Dictionary = nations.get(nation_ids[i], {})
			var nb: Dictionary = nations.get(nation_ids[j], {})
			if na.is_empty() or nb.is_empty():
				continue
			# Check if allied
			if not (int(nation_ids[j]) in na.get("allied_with", [])):
				continue
			# Check cultural similarity
			if str(na.get("culture", "")) != str(nb.get("culture", "")):
				continue
			# Check relation score
			var relation: int = int(na.get("relations", {}).get(nation_ids[j], 0))
			if relation < 80:
				continue
			# Merge nb into na
			_merge_nations(int(nation_ids[i]), int(nation_ids[j]), tick)


func _merge_nations(into_id: int, from_id: int, tick: int) -> void:
	"""Merge one nation into another."""
	var into: Dictionary = nations.get(into_id, {})
	var from: Dictionary = nations.get(from_id, {})
	if into.is_empty() or from.is_empty():
		return
	# Transfer settlements
	for srk in from.get("settlements", []):
		if not srk in into.get("settlements", []):
			into["settlements"].append(srk)
	# Transfer territory
	for rk in from.get("territory", {}).keys():
		_region_ownership[rk] = into_id
		_region_loyalty[rk] = float(from["territory"][rk])
		into["territory"][rk] = _region_loyalty[rk]
	# Transfer alliances
	for ally_id in from.get("allied_with", []):
		if ally_id != into_id and not ally_id in into.get("allied_with", []):
			into["allied_with"].append(ally_id)
	# Transfer wars
	for war_id in from.get("at_war_with", []):
		if not war_id in into.get("at_war_with", []):
			into["at_war_with"].append(war_id)
	# Remove merged nation
	nations.erase(from_id)
	# Log merger
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "The nation of %s was absorbed into %s." % [from.get("name", "Unknown"), into.get("name", "Unknown")],
			PackedStringArray(["nation_merged", into.get("name", "")]))


func _try_split_nations(tick: int) -> void:
	"""Split nations with low stability in distant regions."""
	for nid in nations.keys():
		var nation: Dictionary = nations.get(nid, {})
		if nation.is_empty():
			continue
		if float(nation.get("stability", 1.0)) > 0.5:
			continue
		# Find distant regions with low loyalty
		var low_loyalty_regions: Array[int] = []
		var capital_rk: int = int(nation.get("capital_region", -1))
		for rk in nation.get("territory", {}).keys():
			var loyalty: float = float(nation["territory"].get(rk, 0.0))
			var dist: int = _region_distance(rk, capital_rk)
			if loyalty < 0.3 and dist > 5:
				low_loyalty_regions.append(rk)
		if low_loyalty_regions.size() >= 3:
			# Split: these regions form a new nation
			_split_nation(nid, low_loyalty_regions, tick)


func _split_nation(parent_id: int, breakaway_regions: Array[int], tick: int) -> void:
	"""Split a nation, creating a new breakaway nation."""
	var parent: Dictionary = nations.get(parent_id, {})
	if parent.is_empty():
		return
	var new_nid: int = _next_nation_id
	_next_nation_id += 1
	var culture: String = str(parent.get("culture", "unknown"))
	var new_name: String = _generate_nation_name(culture, {}, []) + " (Breakaway)"
	var color: String = _assign_nation_color(new_nid)
	# Find settlements in breakaway regions
	var breakaway_settlements: Array[int] = []
	for srk in parent.get("settlements", []):
		if srk in breakaway_regions:
			breakaway_settlements.append(srk)
	# Create new nation
	nations[new_nid] = {
		"id": new_nid,
		"name": new_name,
		"color": color,
		"capital_region": breakaway_regions[0] if breakaway_regions.size() > 0 else -1,
		"settlements": breakaway_settlements,
		"population": 0,
		"territory": {},
		"government_type": "tribal",
		"leader_id": -1,
		"formed_tick": tick,
		"relations": {},
		"at_war_with": [parent_id],  # Starts at war with parent
		"allied_with": [],
		"culture": culture,
		"prestige": 1.0,
		"stability": 0.6,
	}
	# Transfer territory
	for rk in breakaway_regions:
		_region_ownership[rk] = new_nid
		_region_loyalty[rk] = 0.5
		nations[new_nid]["territory"][rk] = 0.5
		parent["territory"].erase(rk)
	# Add to parent's war list
	if not new_nid in parent.get("at_war_with", []):
		parent["at_war_with"].append(new_nid)
	# Log split
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "%s broke away from %s, sparking conflict." % [new_name, parent.get("name", "Unknown")],
			PackedStringArray(["nation_split", new_name]))


# ============================================================
# NATION GOVERNMENT EVOLUTION
# ============================================================

func _update_nation_governments(tick: int) -> void:
	"""Update nation government types based on population and development."""
	for nid in nations.keys():
		var nation: Dictionary = nations.get(nid, {})
		if nation.is_empty():
			continue
		var pop: int = int(nation.get("population", 0))
		var settlements: int = nation.get("settlements", []).size()
		var current_gov: String = str(nation.get("government_type", "tribal"))
		var new_gov: String = current_gov
		if pop >= 100 and settlements >= 5 and current_gov in ["tribal", "chiefdom"]:
			new_gov = "kingdom"
		elif pop >= 500 and settlements >= 10 and current_gov in ["tribal", "chiefdom", "kingdom"]:
			new_gov = "empire"
		elif pop >= 50 and settlements >= 3 and current_gov == "tribal":
			new_gov = "chiefdom"
		if new_gov != current_gov:
			nation["government_type"] = new_gov
			if ChronicleLog != null:
				ChronicleLog.append_entry(tick, "world", "%s evolved from %s to %s." % [nation.get("name", "Unknown"), current_gov, new_gov],
					PackedStringArray(["government_change", nation.get("name", "")]))


# ============================================================
# DIPLOMACY HELPERS
# ============================================================

func declare_war(attacker_id: int, defender_id: int) -> void:
	"""Declare war between two nations."""
	var attacker: Dictionary = nations.get(attacker_id, {})
	var defender: Dictionary = nations.get(defender_id, {})
	if attacker.is_empty() or defender.is_empty():
		return
	if not defender_id in attacker.get("at_war_with", []):
		attacker["at_war_with"].append(defender_id)
	if not attacker_id in defender.get("at_war_with", []):
		defender["at_war_with"].append(attacker_id)
	# Remove from allies
	attacker["allied_with"].erase(defender_id)
	defender["allied_with"].erase(attacker_id)
	# Update relations
	attacker["relations"][defender_id] = -100
	defender["relations"][attacker_id] = -100
	# Log
	if ChronicleLog != null:
		ChronicleLog.append_entry(GameManager.tick_count if GameManager != null else 0, "world",
			"%s declared war on %s!" % [attacker.get("name", "Unknown"), defender.get("name", "Unknown")],
			PackedStringArray(["war_declared", attacker.get("name", "")]))


func form_alliance(nation_a_id: int, nation_b_id: int) -> void:
	"""Form an alliance between two nations."""
	var na: Dictionary = nations.get(nation_a_id, {})
	var nb: Dictionary = nations.get(nation_b_id, {})
	if na.is_empty() or nb.is_empty():
		return
	if not nation_b_id in na.get("allied_with", []):
		na["allied_with"].append(nation_b_id)
	if not nation_a_id in nb.get("allied_with", []):
		nb["allied_with"].append(nation_a_id)
	na["relations"][nation_b_id] = maxi(int(na["relations"].get(nation_b_id, 0)), 80)
	nb["relations"][nation_a_id] = maxi(int(nb["relations"].get(nation_a_id, 0)), 80)
	# Remove from enemies
	na["at_war_with"].erase(nation_b_id)
	nb["at_war_with"].erase(nation_a_id)


# ============================================================
# QUERY API
# ============================================================

func are_nations_at_war(nation_a_id: int, nation_b_id: int) -> bool:
	"""Check if two nations are at war. War state is stored in nations[nid].at_war_with."""
	var na: Dictionary = nations.get(nation_a_id, {})
	if na.is_empty() or nation_b_id < 0:
		return false
	return na.has("at_war_with") and nation_b_id in na.get("at_war_with", [])


func get_nation_at_region(region_key: int) -> int:
	"""Get the nation ID that owns this region, or -1 if unclaimed."""
	return _region_ownership.get(region_key, -1)


func get_nation_for_settlement(settlement_region: int) -> int:
	"""Get the nation ID that a settlement belongs to."""
	return _get_nation_for_settlement(settlement_region)


func _get_nation_for_settlement(srk: int) -> int:
	for nid in nations.keys():
		var nation: Dictionary = nations.get(nid, {})
		if srk in nation.get("settlements", []):
			return nid
	return -1


func get_nation_by_id(nation_id: int) -> Dictionary:
	return nations.get(nation_id, {})


func get_all_nations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for nid in nations.keys():
		result.append(nations[nid])
	return result


func get_contested_regions() -> Dictionary:
	return _contested_regions.duplicate()


func get_region_color(region_key: int) -> Color:
	"""Get the display color for a region on the map."""
	var nation_id: int = _region_ownership.get(region_key, -1)
	if nation_id < 0:
		return Color(0.3, 0.3, 0.3, 0.5)  # Gray for unclaimed
	var nation: Dictionary = nations.get(nation_id, {})
	if nation.is_empty():
		return Color(0.3, 0.3, 0.3, 0.5)
	var hex_color: String = str(nation.get("color", "#888888"))
	return _hex_to_color(hex_color)


func is_region_contested(region_key: int) -> bool:
	return _contested_regions.has(region_key)


func get_nation_count() -> int:
	return nations.size()


func get_total_claimed_regions() -> int:
	var count: int = 0
	for v in _region_ownership.values():
		if int(v) >= 0:
			count += 1
	return count


# ============================================================
# NAME GENERATION
# ============================================================

func _generate_nation_name(culture: String, capital: Dictionary, settlements: Array) -> String:
	"""Generate a deterministic nation name based on culture and geography."""
	var prefixes: Dictionary = {
		"unknown": ["Greater", "United", "Free", "Ancient", "New"],
		"northern": ["Frost", "Iron", "Stone", "Winter", "North"],
		"southern": ["Sun", "Gold", "Sand", "Summer", "South"],
		"eastern": ["Dawn", "River", "Forest", "East", "Green"],
		"western": ["Dusk", "Sea", "Hill", "West", "Blue"],
	}
	var suffixes: PackedStringArray = [
		"Realm", "Dominion", "Kingdom", "Lands", "Territory",
		"Confederacy", "Union", "Empire", "Hold", "March",
	]
	var prefix_list: Array = prefixes.get(culture, prefixes["unknown"])
	var prefix: String = prefix_list[settlements.size() % prefix_list.size()]
	var suffix: String = suffixes[settlements.size() % suffixes.size()]
	if capital.has("name"):
		var cap_name: String = str(capital.get("name", ""))
		if cap_name != "":
			return "%s %s of %s" % [prefix, suffix, cap_name]
	return "%s %s" % [prefix, suffix]


func _assign_nation_color(nation_id: int) -> String:
	return NATION_COLORS[nation_id % NATION_COLORS.size()]


func _determine_government(population: int, settlement_count: int) -> String:
	if population >= 100 and settlement_count >= 5:
		return "kingdom"
	elif population >= 50 and settlement_count >= 3:
		return "chiefdom"
	elif population >= 200 and settlement_count >= 8:
		return "empire"
	return "tribal"


func _find_nation_leader(settlements: Array) -> int:
	"""Find the leader pawn for a nation (highest authority in capital)."""
	if settlements.is_empty():
		return -1
	var capital: Dictionary = settlements[0] as Dictionary
	var srk: int = int(capital.get("center_region", -1))
	if srk < 0:
		return -1
	# Try to find the settlement leader
	if SettlementMemory != null:
		var st: Variant = SettlementMemory.get_settlement_at_region(srk)
		if st is Dictionary:
			return int(st.get("leader_id", -1))
	return -1


# ============================================================
# COLOR UTILITIES
# ============================================================

func _hex_to_color(hex: String) -> Color:
	if hex.begins_with("#"):
		return Color(hex)
	if hex.length() != 6:
		return Color(0.5, 0.5, 0.5, 0.5)
	return Color("#" + hex)
