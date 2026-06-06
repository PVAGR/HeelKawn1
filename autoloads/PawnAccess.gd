extends Node

## Global autoload providing pawn access to all other autoloads.
## PawnSpawner is a scene node (not an autoload), so this singleton
## bridges the gap by looking up the spawner via the pawn_spawner group.
##
## Usage: PawnAccess.find_pawns(), PawnAccess.find_alive_pawns()

var _cached_spawner: Node = null


func _get_spawner() -> Node:
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		return _cached_spawner
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("pawn_spawner")
	if node == null:
		return null
	_cached_spawner = node
	return node


## Return all pawns (including dead ones that haven't been pruned yet).
func find_pawns() -> Array[HeelKawnian]:
	var sp: Node = _get_spawner()
	if sp == null:
		return []
	if sp.has_method("get_all_pawns"):
		return sp.call("get_all_pawns")
	return []


## Return only living pawns.
func find_alive_pawns() -> Array[HeelKawnian]:
	var sp: Node = _get_spawner()
	if sp == null:
		return []
	if sp.has_method("get_alive_pawns"):
		return sp.call("get_alive_pawns")
	return []


## Return pawn by ID, or null if not found.
func find_pawn_by_id(pawn_id: int) -> HeelKawnian:
	var sp: Node = _get_spawner()
	if sp == null:
		return null
	if sp.has_method("get_pawn_by_id"):
		return sp.call("get_pawn_by_id", pawn_id)
	return null


## Return pawn count (alive).
func count_alive() -> int:
	return find_alive_pawns().size()


## Return total pawn count (including dead/unpruned).
func count_total() -> int:
	return find_pawns().size()
