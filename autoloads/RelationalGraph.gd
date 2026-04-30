extends Node
## RelationalGraph.gd — Core relational ontology for HeelKawn
# Nodes: people, households, settlements, regions, items, beliefs, treaties, etc.
# Edges: kinship, trade, hostility, teaching, migration, loyalty, trauma, memory, etc.
#
# - Deterministic, append-only (for canonical history)
# - Supports querying, adding, and traversing relationships
# - No direct world mutation; only records and queries relations
# - Designed for extension by other systems (AI, memory, authority, etc.)

class_name RelationalGraph

# Node and edge storage
var nodes := {} # id -> {"type": String, "data": Dictionary}
var edges := [] # [{"from": id, "to": id, "type": String, "data": Dictionary}]

# Add a node (returns node id)
func add_node(node_type: String, data: Dictionary = {}):
	var node_id = data.get("id", hash(node_type + str(OS.get_ticks_usec()) + str(randi())))
	nodes[node_id] = {"type": node_type, "data": data.duplicate(true)}
	return node_id

# Add an edge between nodes
func add_edge(from_id, to_id, edge_type: String, data: Dictionary = {}):
	edges.append({"from": from_id, "to": to_id, "type": edge_type, "data": data.duplicate(true)})

# Query all edges of a given type for a node
func get_edges(node_id, edge_type: String = "") -> Array:
	var out = []
	for e in edges:
		if (e["from"] == node_id or e["to"] == node_id) and (edge_type == "" or e["type"] == edge_type):
			out.append(e)
	return out

# Query all nodes of a given type
func get_nodes_by_type(node_type: String) -> Array:
	var out = []
	for id in nodes:
		if nodes[id]["type"] == node_type:
			out.append({"id": id, "data": nodes[id]["data"]})
	return out

# Find all neighbors of a node (optionally by edge type)
func get_neighbors(node_id, edge_type: String = "") -> Array:
	var out = []
	for e in edges:
		if (e["from"] == node_id or e["to"] == node_id) and (edge_type == "" or e["type"] == edge_type):
			var neighbor = e["to"] if e["from"] == node_id else e["from"]
			out.append(neighbor)
	return out

# Deterministic serialization for append-only history
func to_save_dict() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true)
	}

# Load from saved state
func from_save_dict(d: Dictionary) -> void:
	nodes = d.get("nodes", {}).duplicate(true)
	edges = d.get("edges", []).duplicate(true)

# Clear all data (for tests or resets)
func clear() -> void:
	nodes.clear()
	edges.clear()
