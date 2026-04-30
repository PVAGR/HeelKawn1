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

# Household data: household_id -> household info
var household_data: Dictionary = {}

# Obligation tracking: obligation_id -> obligation data
var obligations: Dictionary = {}

# Inheritance records: inheritance_id -> inheritance data
var inheritance_records: Dictionary = {}


func _with_person_id(person_id: int, data: Dictionary) -> Dictionary:
	var merged: Dictionary = data.duplicate(true)
	merged["id"] = person_id
	return merged

# Add a person node (if not already present)
func add_person(person_id: int, data: Dictionary = {}):
	if RelationalGraph:
		if not RelationalGraph.nodes.has(person_id):
			RelationalGraph.add_node("person", _with_person_id(person_id, data))

# Add a household node (if not already present)
func add_household(household_id: int, data: Dictionary = {}):
	if RelationalGraph:
		if not RelationalGraph.nodes.has(household_id):
			RelationalGraph.add_node("household", _with_person_id(household_id, data))

# Add a kinship edge (parent, child, sibling, spouse, etc.)
func add_kinship(from_id: int, to_id: int, relation: String, data: Dictionary = {}):
	if RelationalGraph:
		RelationalGraph.add_edge(from_id, to_id, relation, data)

# Query all kinship edges for a person
func get_kinship(person_id: int, relation: String = "") -> Array:
	if RelationalGraph:
		return RelationalGraph.get_edges(person_id, relation)
	return []

# Query all household members
func get_household_members(household_id: int) -> Array:
	if RelationalGraph:
		var members = []
		for e in RelationalGraph.edges:
			if e["type"] == "household_member" and e["to"] == household_id:
				members.append(e["from"])
			elif e["type"] == "household_member" and e["from"] == household_id:
				members.append(e["to"])
			# (bidirectional for robustness)
		return members
	return []

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
	add_kinship(person_id, household_id, "household_member")

# Clear all kinship data (for tests or resets)
func clear() -> void:
	household_data.clear()
	obligations.clear()
	inheritance_records.clear()
	if RelationalGraph:
		# Clear kinship-related nodes and edges
		for node_id in RelationalGraph.nodes.keys():
			var node_data: Dictionary = RelationalGraph.nodes[node_id]
			if node_data.get("type", "") in ["person", "household"]:
				RelationalGraph.remove_node(node_id)

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
		"obligations": obligations.duplicate(true),
		"inheritance_records": inheritance_records.duplicate(true),
	}

func from_save_dict(d: Dictionary) -> void:
	household_data.clear()
	obligations.clear()
	inheritance_records.clear()
	
	if d.has("household_data"):
		household_data = d["household_data"].duplicate(true)
	if d.has("obligations"):
		obligations = d["obligations"].duplicate(true)
	if d.has("inheritance_records"):
		inheritance_records = d["inheritance_records"].duplicate(true)
