extends Node
## KinshipSystem.gd — Handles kinship, household, and family relationships using RelationalGraph
# Nodes: people, households
# Edges: parent, child, sibling, spouse, household_member, etc.
# All relationships are written to and queried from RelationalGraph

class_name KinshipSystem

@onready var RelationalGraph = get_node_or_null("/root/RelationalGraph")

# Add a person node (if not already present)
func add_person(person_id: int, data: Dictionary = {}):
	if RelationalGraph:
		if not RelationalGraph.nodes.has(person_id):
			RelationalGraph.add_node("person", {"id": person_id, **data})

# Add a household node (if not already present)
func add_household(household_id: int, data: Dictionary = {}):
	if RelationalGraph:
		if not RelationalGraph.nodes.has(household_id):
			RelationalGraph.add_node("household", {"id": household_id, **data})

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
	# This only clears nodes/edges of type person/household/kinship
	# For now, just a placeholder; full selective clear can be added as needed
	pass
