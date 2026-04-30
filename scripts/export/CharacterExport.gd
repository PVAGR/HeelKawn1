class_name HeelKawnSoulExport
extends RefCounted

## Web companion / JSON-oriented soul payload. Autoload [CharacterExport] delegates here.

static func export_character_data(pawn_id: String) -> Dictionary:
	var spawner: PawnSpawner = _resolve_spawner()
	if spawner == null:
		return {"error": "no_spawner", "pawn_id": pawn_id}
	var pd: PawnData = _resolve_pawn_data(spawner, pawn_id)
	if pd == null:
		return {"error": "pawn_not_found", "pawn_id": pawn_id}
	pd.ensure_soul_identity()
	var skills: Dictionary = {
		"foraging_level": pd.get_skill_level(PawnData.Skill.FORAGING),
		"mining_level": pd.get_skill_level(PawnData.Skill.MINING),
		"chopping_level": pd.get_skill_level(PawnData.Skill.CHOPPING),
		"building_level": pd.get_skill_level(PawnData.Skill.BUILDING),
		"hunting_level": pd.get_skill_level(PawnData.Skill.HUNTING),
		"skills": pd.skills.duplicate(true),
		"skill_xp": _skill_xp_string_keys(pd),
	}
	var current_state: Dictionary = {
		"numeric_id": pd.id,
		"display_name": pd.display_name,
		"tile": {"x": pd.tile_pos.x, "y": pd.tile_pos.y},
		"settlement_id": pd.settlement_id,
		"health": pd.health,
		"max_health": pd.max_health,
		"hunger": pd.hunger,
		"rest": pd.rest,
		"mood": pd.mood,
		"age_years": pd.age_years,
		"social_squad_anchor_id": pd.social_squad_anchor_id,
		"reputation": _string_key_dict(pd.settlement_reputation),
	}
	return {
		"soul_id": pd.unique_id,
		"biography": pd.biography.duplicate(),
		"scars": pd.physical_scars.duplicate(),
		"lineage_tree": _lineage_tree_dict(spawner, pd, 8),
		"skills": skills,
		"current_state": current_state,
	}


static func _skill_xp_string_keys(pd: PawnData) -> Dictionary:
	var out: Dictionary = {}
	for k in pd.skill_xp:
		out[str(k)] = pd.skill_xp[k]
	return out


static func _string_key_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[str(k)] = d[k]
	return out


static func _resolve_spawner() -> PawnSpawner:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var n: Node = tree.root.find_child("PawnSpawner", true, false)
	return n as PawnSpawner


static func _resolve_pawn_data(spawner: PawnSpawner, pawn_id: String) -> PawnData:
	var key: String = str(pawn_id).strip_edges()
	if key.is_valid_int():
		return spawner.pawn_data_for_id(int(key))
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and p.data.unique_id == key:
			return p.data
	return null


static func _pawn_data_by_soul_id(spawner: PawnSpawner, soul: String) -> PawnData:
	if soul.is_empty():
		return null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and p.data.unique_id == soul:
			return p.data
	return null


static func _lineage_tree_dict(spawner: PawnSpawner, pd: PawnData, depth: int) -> Dictionary:
	var node: Dictionary = {
		"soul_id": pd.unique_id,
		"lineage_id": pd.lineage_id,
		"numeric_id": pd.id,
		"display_name": pd.display_name,
		"parent": {},
	}
	if depth <= 0:
		node["truncated"] = true
		return node
	if pd.lineage_id.is_empty():
		return node
	var par: PawnData = _pawn_data_by_soul_id(spawner, pd.lineage_id)
	if par != null:
		node["parent"] = _lineage_tree_dict(spawner, par, depth - 1)
	else:
		node["parent"] = {"soul_id": pd.lineage_id, "missing": true}
	return node
