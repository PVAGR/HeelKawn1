class_name PawnData
extends RefCounted

## Static helper for pawn data lookup by ID.
## Queries the active PawnSpawner so that parent data is retrievable
## regardless of whether the HeelKawnianData static registry is populated.


static func get_pawn_data(pawn_id: int) -> HeelKawnianData:
	if pawn_id < 0:
		return null
	var spawner: Node = _get_pawn_spawner()
	if spawner != null and spawner.has_method("pawn_data_for_id"):
		return spawner.call("pawn_data_for_id", pawn_id) as HeelKawnianData
	return null


static func _get_pawn_spawner() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var n: Node = tree.root.find_child("PawnSpawner", true, false)
	return n
