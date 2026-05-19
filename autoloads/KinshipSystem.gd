extends Node
## KinshipSystem.gd — Handles kinship, household, and family relationships using RelationalGraph
## Extended to include food storage, labor contribution, obligation tracking, and inheritance
# Nodes: people, households
# Edges: parent, child, sibling, spouse, household_member, obligation, inheritance
# All relationships are written to and queried from RelationalGraph

@onready var RelationalGraph = get_node_or_null("/root/RelationalGraph")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")

# Household data: household_id -> household info
var household_data: Dictionary = {}
var _households: Dictionary = {}
var _next_household_id: int = 1

# Obligation tracking: obligation_id -> obligation data
var obligations: Dictionary = {}

# Inheritance records: inheritance_id -> inheritance data
var inheritance_records: Dictionary = {}

# Tick connected flag
var _tick_connected: bool = false


func _with_person_id(person_id: int, data: Dictionary) -> Dictionary:
	var merged: Dictionary = data.duplicate(true)
	merged["id"] = person_id
	return merged


func _household_node_id(household_id: int) -> String:
	return "household:%d" % household_id


func _current_tick() -> int:
	if GameManager != null:
		return int(GameManager.tick_count)
	return 0


func _append_unique_id(out: Array, value: Variant) -> void:
	var id: int = int(value)
	if id < 0:
		return
	if not out.has(id):
		out.append(id)


func _same_id(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	return left == right


func _is_household_ref(value: Variant, household_id: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) == household_id
	if typeof(value) == TYPE_STRING:
		return str(value) == _household_node_id(household_id)
	return false


func _sorted_ids(ids: Array) -> Array:
	ids.sort()
	return ids


func _ensure_household_record(household_id: int, leader_pawn_id: int = -1) -> Dictionary:
	if not _households.has(household_id):
		_households[household_id] = {
			"leader_id": leader_pawn_id,
			"members": [],
			"created_tick": _current_tick(),
		}
	elif leader_pawn_id >= 0 and int(_households[household_id].get("leader_id", -1)) < 0:
		_households[household_id]["leader_id"] = leader_pawn_id
	if not household_data.has(household_id):
		household_data[household_id] = {
			"food": 0.0, 
			"labor_contribution": 0.0,
			"name": "Unnamed Household",
			"stability": 100.0,
			"reputation": 50.0,
			"wealth": 0.0,
			"active_plan": null
		}
	return _households.get(household_id, {})


func _add_household_member_record(household_id: int, pawn_id: int) -> bool:
	if not _households.has(household_id):
		return false
	var members: Array = _households[household_id].get("members", [])
	_append_unique_id(members, pawn_id)
	_households[household_id]["members"] = members
	return true


func _has_relation(from_id, to_id, relation: String) -> bool:
	if RelationalGraph == null:
		return false
	for e in RelationalGraph.edges:
		if e.get("type", "") == relation and _same_id(e.get("from"), from_id) and _same_id(e.get("to"), to_id):
			return true
	return false


func _parent_ids(person_id: int) -> Array:
	var parents: Array = []
	if RelationalGraph == null:
		return parents
	for e in RelationalGraph.edges:
		if e.get("type", "") == "parent" and e.get("to") == person_id:
			_append_unique_id(parents, e.get("from"))
		elif e.get("type", "") == "child" and e.get("from") == person_id:
			_append_unique_id(parents, e.get("to"))
	return _sorted_ids(parents)


func _child_ids(person_id: int) -> Array:
	var children: Array = []
	if RelationalGraph == null:
		return children
	for e in RelationalGraph.edges:
		if e.get("type", "") == "parent" and e.get("from") == person_id:
			_append_unique_id(children, e.get("to"))
		elif e.get("type", "") == "child" and e.get("to") == person_id:
			_append_unique_id(children, e.get("from"))
	return _sorted_ids(children)


func _spouse_ids(person_id: int) -> Array:
	var spouses: Array = []
	if RelationalGraph == null:
		return spouses
	for e in RelationalGraph.edges:
		if e.get("type", "") == "spouse":
			if e.get("from") == person_id:
				_append_unique_id(spouses, e.get("to"))
			elif e.get("to") == person_id:
				_append_unique_id(spouses, e.get("from"))
	return _sorted_ids(spouses)


func _bump_next_household_id() -> void:
	for household_id in _households.keys():
		_next_household_id = max(_next_household_id, int(household_id) + 1)

# Add a person node (if not already present)
func add_person(person_id: int, data: Dictionary = {}):
	if RelationalGraph:
		if not RelationalGraph.nodes.has(person_id):
			RelationalGraph.add_node("person", _with_person_id(person_id, data))

# Add a household node (if not already present)
func add_household(household_id: int, data: Dictionary = {}):
	_ensure_household_record(household_id, int(data.get("leader_id", -1)))
	_bump_next_household_id()
	if RelationalGraph:
		var graph_id: String = _household_node_id(household_id)
		if not RelationalGraph.nodes.has(graph_id):
			var node_data: Dictionary = data.duplicate(true)
			node_data["id"] = graph_id
			node_data["household_id"] = household_id
			RelationalGraph.add_node("household", node_data)

# Add a kinship edge (parent, child, sibling, spouse, etc.)
func add_kinship(from_id, to_id, relation: String, data: Dictionary = {}):
	if RelationalGraph:
		RelationalGraph.add_edge(from_id, to_id, relation, data)

# Query all kinship edges for a person
func get_kinship(person_id: int, relation: String = "") -> Array:
	if RelationalGraph:
		return RelationalGraph.get_edges(person_id, relation)
	return []


func create_household(leader_pawn_id: int) -> int:
	while _households.has(_next_household_id):
		_next_household_id += 1
	var hhid: int = _next_household_id
	_next_household_id += 1
	var created_tick: int = _current_tick()
	_households[hhid] = {
		"leader_id": leader_pawn_id,
		"members": [leader_pawn_id],
		"created_tick": created_tick,
	}
	if not household_data.has(hhid):
		household_data[hhid] = {"food": 0.0, "labor_contribution": 0.0}
	add_household(hhid, {"leader_id": leader_pawn_id, "created_tick": created_tick})
	add_household_member(leader_pawn_id, hhid)
	return hhid


func add_to_household(hhid: int, pawn_id: int) -> bool:
	if not _households.has(hhid):
		return false
	_add_household_member_record(hhid, pawn_id)
	add_household_member(pawn_id, hhid)
	return true


# Query all household members
func get_household_members(household_id: int) -> Array:
	var members: Array = []
	if _households.has(household_id):
		for member_id in _households[household_id].get("members", []):
			_append_unique_id(members, member_id)
	if RelationalGraph:
		for e in RelationalGraph.edges:
			if e["type"] == "household_member" and _is_household_ref(e["to"], household_id):
				_append_unique_id(members, e["from"])
			elif e["type"] == "household_member" and _is_household_ref(e["from"], household_id):
				_append_unique_id(members, e["to"])
			# (bidirectional for robustness)
	return _sorted_ids(members)


func set_household_name(hhid: int, name: String) -> void:
	if household_data.has(hhid):
		household_data[hhid]["name"] = name


func get_household_info(hhid: int) -> Dictionary:
	if household_data.has(hhid):
		return household_data[hhid].duplicate(true)
	return {}



func get_siblings(person_id: int) -> Array:
	var siblings: Array = []
	if RelationalGraph == null:
		return siblings
	for e in RelationalGraph.edges:
		if e.get("type", "") == "sibling":
			if e.get("from") == person_id:
				_append_unique_id(siblings, e.get("to"))
			elif e.get("to") == person_id:
				_append_unique_id(siblings, e.get("from"))
	for parent_id in _parent_ids(person_id):
		for child_id in _child_ids(parent_id):
			if int(child_id) != person_id:
				_append_unique_id(siblings, child_id)
	return _sorted_ids(siblings)


func get_cousins(person_id: int) -> Array:
	var cousins: Array = []
	var siblings: Array = get_siblings(person_id)
	for parent_id in _parent_ids(person_id):
		for aunt_uncle_id in get_siblings(parent_id):
			for child_id in _child_ids(aunt_uncle_id):
				if int(child_id) != person_id and not siblings.has(int(child_id)):
					_append_unique_id(cousins, child_id)
	return _sorted_ids(cousins)


func get_extended_family(person_id: int) -> Array:
	var family: Array = []
	for parent_id in _parent_ids(person_id):
		_append_unique_id(family, parent_id)
		for grandparent_id in _parent_ids(parent_id):
			_append_unique_id(family, grandparent_id)
		for aunt_uncle_id in get_siblings(parent_id):
			_append_unique_id(family, aunt_uncle_id)
	for child_id in _child_ids(person_id):
		_append_unique_id(family, child_id)
		for grandchild_id in _child_ids(child_id):
			_append_unique_id(family, grandchild_id)
	for sibling_id in get_siblings(person_id):
		_append_unique_id(family, sibling_id)
	for spouse_id in _spouse_ids(person_id):
		_append_unique_id(family, spouse_id)
	for cousin_id in get_cousins(person_id):
		_append_unique_id(family, cousin_id)
	if family.has(person_id):
		family.erase(person_id)
	return _sorted_ids(family)

# Example: add parent-child relationship
func add_parent_child(parent_id: int, child_id: int):
	add_kinship(parent_id, child_id, "parent")
	add_kinship(child_id, parent_id, "child")

# Example: add sibling relationship
func add_siblings(person_a: int, person_b: int):
	add_kinship(person_a, person_b, "sibling")
	add_kinship(person_b, person_a, "sibling")

# Example: add spouse relationship
func add_spouses(person_a: int, person_b: int):
	add_kinship(person_a, person_b, "spouse")
	add_kinship(person_b, person_a, "spouse")

# Example: add household membership
func add_household_member(person_id: int, household_id: int):
	_ensure_household_record(household_id)
	_add_household_member_record(household_id, person_id)
	add_household(household_id)
	var graph_id: String = _household_node_id(household_id)
	if not _has_relation(person_id, graph_id, "household_member"):
		add_kinship(person_id, graph_id, "household_member")
	
	# UPDATE: Calculate stability and reputation impact
	_update_household_stats(household_id)

func _update_household_stats(hhid: int) -> void:
	if not household_data.has(hhid): return
	
	var members = get_household_members(hhid)
	if members.is_empty(): return
	
	var total_rep = 0.0
	var total_stability = 0.0
	var member_count = 0
	
	for mid in members:
		# We access pawn data via PawnData (the canon registry)
		var d: HeelKawnianData = PawnData.get_pawn_data(mid)
		if d:
			total_rep += float(d.reputation_score)
			# Stability increases if they have high rapport with other members
			for other_id in members:
				if mid == other_id: continue
				var peer_trust: float = 50.0
				if d.trust.has(other_id):
					peer_trust = float(d.trust[other_id])
				total_stability += peer_trust * 0.1
			member_count += 1
	
	if member_count > 0:
		household_data[hhid]["reputation"] = total_rep / member_count
		household_data[hhid]["stability"] = clamp(total_stability / member_count, 0.0, 100.0)



func rebuild_from_pawn_spawner(spawner) -> void:
	clear()
	if spawner == null:
		return
	for pawn in spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var data = pawn.data
		add_person(int(data.id), {"display_name": data.display_name, "age": data.age, "gender": data.gender})
		if data.parent_a_id >= 0:
			add_parent_child(int(data.parent_a_id), int(data.id))
		if data.parent_b_id >= 0:
			add_parent_child(int(data.parent_b_id), int(data.id))
		if data.spouse_id >= 0:
			add_spouses(int(data.id), int(data.spouse_id))
		if data.household_id >= 0:
			add_household_member(int(data.id), int(data.household_id))
		for child_id in data.children_ids:
			if int(child_id) >= 0:
				add_parent_child(int(data.id), int(child_id))

# Clear all kinship data (for tests or resets)
func clear() -> void:
	household_data.clear()
	_households.clear()
	_next_household_id = 1
	obligations.clear()
	inheritance_records.clear()
	if RelationalGraph:
		var removed_node_ids: Array = []
		for node_id in RelationalGraph.nodes.keys():
			var node_data: Dictionary = RelationalGraph.nodes[node_id]
			if node_data.get("type", "") in ["person", "household"]:
				removed_node_ids.append(node_id)
		for node_id in removed_node_ids:
			RelationalGraph.nodes.erase(node_id)
		var relation_types: Array = [
			"parent", "child", "sibling", "spouse", "household_member",
			"obligation", "inheritance",
		]
		for i in range(RelationalGraph.edges.size() - 1, -1, -1):
			var edge: Dictionary = RelationalGraph.edges[i]
			var should_remove: bool = (
				relation_types.has(edge.get("type", ""))
				or removed_node_ids.has(edge.get("from"))
				or removed_node_ids.has(edge.get("to"))
			)
			if should_remove:
				RelationalGraph.edges.remove_at(i)

# === Household Food Storage ===

func set_household_food(household_id: int, food_amount: float) -> void:
	if not household_data.has(household_id):
		household_data[household_id] = {"food": 0.0, "labor_contribution": 0.0}
	household_data[household_id]["food"] = max(0.0, food_amount)

func get_household_food(household_id: int) -> float:
	if household_data.has(household_id):
		return float(household_data[household_id].get("food", 0.0))
	return 0.0

func add_household_food(household_id: int, amount: float) -> void:
	var current: float = get_household_food(household_id)
	set_household_food(household_id, current + amount)

func consume_household_food(household_id: int, amount: float) -> bool:
	var current: float = get_household_food(household_id)
	if current >= amount:
		set_household_food(household_id, current - amount)
		return true
	return false

# === Household Labor Contribution ===

func add_labor_contribution(household_id: int, contribution: float) -> void:
	if not household_data.has(household_id):
		household_data[household_id] = {"food": 0.0, "labor_contribution": 0.0}
	household_data[household_id]["labor_contribution"] = float(household_data[household_id].get("labor_contribution", 0.0)) + contribution

func get_household_labor(household_id: int) -> float:
	if household_data.has(household_id):
		return float(household_data[household_id].get("labor_contribution", 0.0))
	return 0.0

# === Obligation Tracking ===

func create_obligation(from_id: int, to_id: int, obligation_type: String, amount: float, description: String = "") -> int:
	var obligation_id: int = GameManager.tick_count * 1000 + obligations.size()
	obligations[obligation_id] = {
		"from_id": from_id,
		"to_id": to_id,
		"type": obligation_type,
		"amount": amount,
		"description": description,
		"created_tick": GameManager.tick_count,
		"fulfilled": false,
	}
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "obligation_created",
		"obligation_id": obligation_id,
		"from_id": from_id,
		"to_id": to_id,
		"obligation_type": obligation_type,
		"amount": amount,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	return obligation_id

func fulfill_obligation(obligation_id: int) -> bool:
	if not obligations.has(obligation_id):
		return false
	
	var obligation: Dictionary = obligations[obligation_id]
	if obligation.get("fulfilled", false):
		return false
	
	obligation["fulfilled"] = true
	obligation["fulfilled_tick"] = GameManager.tick_count
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "obligation_fulfilled",
		"obligation_id": obligation_id,
		"from_id": obligation.get("from_id"),
		"to_id": obligation.get("to_id"),
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	return true

func get_obligations_for_person(person_id: int) -> Array:
	var result: Array = []
	for obligation_id in obligations.keys():
		var obligation: Dictionary = obligations[obligation_id]
		if obligation.get("from_id") == person_id or obligation.get("to_id") == person_id:
			result.append(obligation.duplicate(true))
	return result

# === Inheritance System ===

func create_inheritance(from_id: int, to_id: int, asset_type: String, asset_data: Dictionary) -> int:
	var inheritance_id: int = GameManager.tick_count * 1000 + inheritance_records.size()
	inheritance_records[inheritance_id] = {
		"from_id": from_id,
		"to_id": to_id,
		"asset_type": asset_type,
		"asset_data": asset_data,
		"created_tick": GameManager.tick_count,
		"claimed": false,
	}
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "inheritance_created",
		"inheritance_id": inheritance_id,
		"from_id": from_id,
		"to_id": to_id,
		"asset_type": asset_type,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	return inheritance_id

func claim_inheritance(inheritance_id: int) -> bool:
	if not inheritance_records.has(inheritance_id):
		return false
	
	var inheritance: Dictionary = inheritance_records[inheritance_id]
	if inheritance.get("claimed", false):
		return false
	
	inheritance["claimed"] = true
	inheritance["claimed_tick"] = GameManager.tick_count
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "inheritance_claimed",
		"inheritance_id": inheritance_id,
		"to_id": inheritance.get("to_id"),
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	return true

func get_inheritances_for_person(person_id: int) -> Array:
	var result: Array = []
	for inheritance_id in inheritance_records.keys():
		var inheritance: Dictionary = inheritance_records[inheritance_id]
		if inheritance.get("to_id") == person_id:
			result.append(inheritance.duplicate(true))
	return result

# === Save/Load ===

func to_save_dict() -> Dictionary:
	return {
		"household_data": household_data.duplicate(true),
		"households": _households.duplicate(true),
		"next_household_id": _next_household_id,
		"obligations": obligations.duplicate(true),
		"inheritance_records": inheritance_records.duplicate(true),
	}

func from_save_dict(d: Dictionary) -> void:
	household_data.clear()
	_households.clear()
	_next_household_id = 1
	obligations.clear()
	inheritance_records.clear()
	
	if d.has("household_data"):
		household_data = d["household_data"].duplicate(true)
	if d.has("households"):
		_households = d["households"].duplicate(true)
	if d.has("next_household_id"):
		_next_household_id = int(d["next_household_id"])
	_bump_next_household_id()
	if d.has("obligations"):
		obligations = d["obligations"].duplicate(true)
	if d.has("inheritance_records"):
		inheritance_records = d["inheritance_records"].duplicate(true)


# ============================================================================
# LINEAGE KEEPER - Kin APIs (deterministic, tick-based mutations)
# ============================================================================

signal kinship_updated(pawn_id: int)

## parent_id -> [child_ids]
var _parent_to_children: Dictionary = {}

## child_id -> [parent_ids]
var _child_to_parents: Dictionary = {}

## Pending births: child_id -> {child_id, mother_id, father_id}
var _pending_births: Dictionary = {}


func _ready() -> void:
	# Connect to GameManager tick if available
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("game_tick"):
		if not gm.game_tick.is_connected(_on_game_tick):
			gm.game_tick.connect(_on_game_tick)


## Internal tick handler - flushes pending births
func _on_game_tick(tick: int) -> void:
	_flush_pending_births(tick)


## Queue a birth for processing on next game_tick
func register_birth(child_id: int, mother_id: int, father_id: int) -> void:
	# Invalid child_id check
	if child_id <= 0:
		return
	
	# Idempotent: already registered in graph
	if _child_to_parents.has(child_id):
		return
	
	# Idempotent: already pending
	if _pending_births.has(child_id):
		return
	
	# Queue the birth (do not mutate graph immediately)
	_pending_births[child_id] = {
		"child_id": child_id,
		"mother_id": mother_id,
		"father_id": father_id,
	}


## Get direct children of a pawn (lineage)
func get_lineage_children(pawn_id: int) -> Array[int]:
	if pawn_id <= 0:
		return []
	
	var result: Array[int] = []
	if _parent_to_children.has(pawn_id):
		for child_id in _parent_to_children[pawn_id]:
			result.append(int(child_id))
	
	# Also check graph if available
	if RelationalGraph:
		for e in RelationalGraph.edges:
			if e.get("type", "") == "parent" and e.get("from") == pawn_id:
				var cid = int(e.get("to", -1))
				if cid > 0 and not result.has(cid):
					result.append(cid)
			elif e.get("type", "") == "child" and e.get("to") == pawn_id:
				var cid = int(e.get("from", -1))
				if cid > 0 and not result.has(cid):
					result.append(cid)
	
	result.sort()
	return result


## Get direct parents of a pawn (lineage)
func get_lineage_parents(pawn_id: int) -> Array[int]:
	if pawn_id <= 0:
		return []
	
	var result: Array[int] = []
	if _child_to_parents.has(pawn_id):
		for parent_id in _child_to_parents[pawn_id]:
			result.append(int(parent_id))
	
	# Also check graph if available
	if RelationalGraph:
		for e in RelationalGraph.edges:
			if e.get("type", "") == "parent" and e.get("to") == pawn_id:
				var pid = int(e.get("from", -1))
				if pid > 0 and not result.has(pid):
					result.append(pid)
			elif e.get("type", "") == "child" and e.get("from") == pawn_id:
				var pid = int(e.get("to", -1))
				if pid > 0 and not result.has(pid):
					result.append(pid)
	
	result.sort()
	return result


## Get siblings of a pawn (lineage, shares at least one parent, excludes self)
func get_lineage_siblings(pawn_id: int) -> Array[int]:
	if pawn_id <= 0:
		return []
	
	var result: Array[int] = []
	var parents = get_lineage_parents(pawn_id)
	
	# Union all children of all parents
	for parent_id in parents:
		for child_id in get_lineage_children(parent_id):
			if int(child_id) != pawn_id and not result.has(int(child_id)):
				result.append(int(child_id))
	
	result.sort()
	return result


## Get ancestors up to specified depth (cap at 10)
func get_lineage_ancestors(pawn_id: int, depth: int) -> Array[int]:
	if pawn_id <= 0 or depth <= 0:
		return []
	
	var max_depth = mini(depth, 10)
	var result: Array[int] = []
	var visited: Dictionary = {}
	
	# BFS by generation
	var current_gen: Array[int] = [pawn_id]
	for gen in range(max_depth):
		var next_gen: Array[int] = []
		for pid in current_gen:
			if visited.has(pid):
				continue
			visited[pid] = true
			
			# Get parents (grandparents at next level)
			var parents = get_lineage_parents(pid)
			for parent_id in parents:
				if not visited.has(parent_id):
					result.append(parent_id)
					next_gen.append(parent_id)
		
		current_gen = next_gen
		if current_gen.is_empty():
			break
	
	result.sort()
	return result


## Flush pending births - applies queued births to graph
func _flush_pending_births(tick: int) -> void:
	if _pending_births.is_empty():
		return

	# Sort by child_id for deterministic order
	var sorted_children = _pending_births.keys()
	sorted_children.sort()

	var processed: Array[int] = []
	for child_id in sorted_children:
		var birth = _pending_births[child_id]
		var cid = int(birth["child_id"])
		var mother = int(birth["mother_id"])
		var father = int(birth["father_id"])

		# Skip if already registered
		if _child_to_parents.has(cid):
			continue

		# Build valid parents array
		var valid_parents: Array[int] = []
		if mother > 0:
			valid_parents.append(mother)
		if father > 0:
			valid_parents.append(father)

		# Insert into child_to_parents
		_child_to_parents[cid] = valid_parents.duplicate()

		# Insert into parent_to_children for each valid parent
		for parent_id in valid_parents:
			if not _parent_to_children.has(parent_id):
				_parent_to_children[parent_id] = []
			var children = _parent_to_children[parent_id]
			if not children.has(cid):
				children.append(cid)
			_parent_to_children[parent_id] = children

		# Record to WorldMemory
		var world_mem = get_node_or_null("/root/WorldMemory")
		if world_mem:
			world_mem.record_event({
				"type": "birth",
				"child_id": cid,
				"mother_id": mother,
				"father_id": father,
				"tick": tick,
			})

		# Phase 5: Inherit grudges from parents
		var grudge_mgr = get_node_or_null("/root/GrudgeManager")
		if grudge_mgr and grudge_mgr.has_method("inherit_grudges"):
			for parent_id in valid_parents:
				grudge_mgr.inherit_grudges(parent_id, cid, tick)

		# Emit signals
		kinship_updated.emit(cid)
		for parent_id in valid_parents:
			kinship_updated.emit(parent_id)

		processed.append(cid)

	# Clear processed births
	for cid in processed:
		_pending_births.erase(cid)


## Test helper - flush pending births without game_tick
func _test_flush_pending_births(tick: int = 0) -> void:
	_flush_pending_births(tick)


# === Territory Color Mapping ===

## Deterministic color for a clan. Uses golden ratio hue spacing for
## visually distinct colors across clans.
static func get_color_for_clan(clan_id: int) -> Color:
	if clan_id < 0:
		return Color(0.5, 0.5, 0.5, 1.0)
	var hue: float = fmod(float(abs(clan_id * 2654435761)) * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.6, 0.85, 1.0)


## Deterministic color for a nation/kingdom. Uses a different hash seed
## than clan so nations and clans don't collide visually.
static func get_color_for_nation(nation_id: int) -> Color:
	if nation_id < 0:
		return Color(0.5, 0.5, 0.5, 1.0)
	var hue: float = fmod(float(abs(nation_id * 2246822519)) * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.5, 0.9, 1.0)
