extends Node
## ArtSystem — Carvings, paintings, songs, and stories.
## Pawns create art when inspired (high mood + skill).
## Art is stored in WorldMemory. Art affects settlement culture.
## Masterwork art becomes legendary and persists across generations.
## All deterministic: art quality uses skill, mood, and WorldRNG.

enum ArtType {
	CARVING,      # stone/wood carving (permanent)
	PAINTING,     # pigment on surface (fades over time)
	SONG,         # oral tradition (passed between pawns)
	STORY,        # narrative about events (recorded in WorldMemory)
}

const ART_TYPE_NAMES: Dictionary = {
	ArtType.CARVING: "Carving",
	ArtType.PAINTING: "Painting",
	ArtType.SONG: "Song",
	ArtType.STORY: "Story",
}

const ART_MATERIAL_COST: Dictionary = {
	ArtType.CARVING: {"stone": 3},
	ArtType.PAINTING: {"pigment": 2, "stone": 1},
	ArtType.SONG: {},
	ArtType.STORY: {},
}

var artworks: Dictionary = {}
var _next_art_id: int = 1

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func create_art(art_type: int, creator_id: int, subject: String = "", settlement_id: int = -1, quality_mod: float = 1.0) -> int:
	var art_id: int = _next_art_id
	_next_art_id += 1
	var skill: int = 1
	if HeelKawnianManager != null:
		skill = HeelKawnianManager.get_skill(creator_id, "art") if HeelKawnianManager.has_method("get_skill") else 1
	var base_quality: float = float(skill) * 0.2 + quality_mod * 0.3
	var quality_roll: float = float(WorldRNG.rangei(0, 100, art_id, &"art_quality")) / 100.0
	var quality: float = clampf(base_quality + quality_roll * 0.5, 0.0, 1.0)
	var quality_label: String = "crude"
	if quality >= 0.9: quality_label = "masterwork"
	elif quality >= 0.7: quality_label = "fine"
	elif quality >= 0.4: quality_label = "average"
	artworks[art_id] = {
		"id": art_id,
		"type": art_type,
		"type_name": ART_TYPE_NAMES.get(art_type, "Art"),
		"creator_id": creator_id,
		"subject": subject,
		"quality": quality,
		"quality_label": quality_label,
		"settlement_id": settlement_id,
		"tick_created": GameManager.tick_count if GameManager != null else 0,
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"art_created": true,
		"art_type": art_type,
		"creator_id": creator_id,
		"subject": subject,
		"quality_label": quality_label,
	})
	return art_id
}

func get_art_for_settlement(settlement_id: int) -> Array {
	var result: Array = []
	for aid in artworks:
		var a: Dictionary = artworks[aid]
		if int(a.get("settlement_id", -1)) == settlement_id:
			result.append(a)
	return result
}

func get_masterworks() -> Array {
	var result: Array = []
	for aid in artworks:
		var a: Dictionary = artworks[aid]
		if a.get("quality_label") == "masterwork":
			result.append(a)
	return result
}

func _on_game_tick(tick: int) -> void:
	_ = tick
