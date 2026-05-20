extends Node
## Manages persistent physical artifacts (books, maps, tools, heirlooms).
## Artifacts are deterministic, saveable, and recorded in WorldMemory.

class_name ArtifactSystem

signal artifact_changed(artifact_id: String, change_type: String)

var _artifacts: Dictionary = {}

class ArtifactData:
	var id: String
	var type: String
	var creator_id: int
	var created_tick: int
	var last_modified_tick: int
	var durability: float
	var content: String
	var location_tile: Vector2i
	var is_destroyed: bool

	func _to_string() -> String:
		return "%s [%s] by %d at %d" % [id, type, creator_id, created_tick]

func _ready() -> void:
	if has_node("/root/TickManager"):
		get_node("/root/TickManager").tick_processed.connect(_on_tick)

func _on_tick(tick_count: int) -> void:
	for art_id in _artifacts.keys():
		var art: ArtifactData = _artifacts[art_id]
		if not art.is_destroyed and tick_count % 500 == 0:
			art.durability -= 0.01
			if art.durability <= 0:
				_destroy_artifact(art_id, "decay")

func generate_artifact_id() -> String:
	var tick: int = 0
	if has_node("/root/TickManager"):
		tick = get_node("/root/TickManager").tick_count
	var seed_str: String = "art_%d_%d" % [tick, _artifacts.size()]
	return seed_str.md5_text().substr(0, 8)

func create_artifact(p_type: String, p_creator_id: int, p_location: Vector2i, p_content: String = "") -> ArtifactData:
	var id: String = generate_artifact_id()
	var art := ArtifactData.new()
	art.id = id
	art.type = p_type
	art.creator_id = p_creator_id
	art.created_tick = 0
	if has_node("/root/TickManager"):
		art.created_tick = get_node("/root/TickManager").tick_count
	art.last_modified_tick = art.created_tick
	art.durability = 1.0
	art.content = p_content
	art.location_tile = p_location
	art.is_destroyed = false
	_artifacts[id] = art
	if has_node("/root/WorldMemory"):
		get_node("/root/WorldMemory").record_event({
			"type": "artifact_created",
			"id": id,
			"type_name": p_type,
			"creator_id": p_creator_id,
			"tile": p_location,
			"tick": art.created_tick
		})
	artifact_changed.emit(id, "created")
	return art

func get_artifact(id: String) -> ArtifactData:
	return _artifacts.get(id, null)

func write_in_artifact(artifact_id: String, text: String) -> bool:
	var art: ArtifactData = _artifacts.get(artifact_id, null)
	if not art or art.is_destroyed:
		return false
	art.content += text
	art.last_modified_tick = 0
	if has_node("/root/TickManager"):
		art.last_modified_tick = get_node("/root/TickManager").tick_count
	_artifacts[artifact_id] = art
	artifact_changed.emit(artifact_id, "written")
	return true

func destroy_artifact(artifact_id: String, reason: String = "manual") -> void:
	_destroy_artifact(artifact_id, reason)

func _destroy_artifact(artifact_id: String, reason: String) -> void:
	var art: ArtifactData = _artifacts.get(artifact_id, null)
	if not art or art.is_destroyed:
		return
	art.is_destroyed = true
	art.durability = 0
	artifact_changed.emit(artifact_id, "destroyed")
	if has_node("/root/WorldMemory"):
		get_node("/root/WorldMemory").record_event({
			"type": "artifact_destroyed",
			"id": artifact_id,
			"type_name": art.type,
			"reason": reason,
			"tick": 0 if not has_node("/root/TickManager") else get_node("/root/TickManager").tick_count
		})

func save_data() -> Dictionary:
	var data: Array = []
	for art in _artifacts.values():
		if not art.is_destroyed:
			data.append({
				"id": art.id,
				"type": art.type,
				"creator_id": art.creator_id,
				"created_tick": art.created_tick,
				"last_modified_tick": art.last_modified_tick,
				"durability": art.durability,
				"content": art.content,
				"location_tile": {"x": art.location_tile.x, "y": art.location_tile.y}
			})
	return {"artifacts": data}

func load_data(data: Dictionary) -> void:
	_artifacts.clear()
	for d in data.get("artifacts", []):
		var art := ArtifactData.new()
		art.id = d.id
		art.type = d.type
		art.creator_id = d.creator_id
		art.created_tick = d.created_tick
		art.last_modified_tick = d.last_modified_tick
		art.durability = d.durability
		art.content = d.content
		art.location_tile = Vector2i(d.location_tile.x, d.location_tile.y)
		art.is_destroyed = false
		_artifacts[art.id] = art
