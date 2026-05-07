extends Node
## TutorialHints.gd — First-body orientation hints
##
## Shows contextual hints for new players:
## - First gather (click tree → "Press E to gather wood")
## - First build (press B → "Click to place foundation")
## - First craft (press C → "Craft a Flint Knife")
## - First memorial (pawn dies → "Click grave to read inscription")
## - First pilgrimage (pawn visits memorial → "Pawns find closure at memorials")
##
## Hints are dismissable and can be re-enabled in settings.

const HINT_DELAY_SEC: float = 2.0  # Show hint after 2 seconds of inaction
const HINT_DURATION_SEC: float = 8.0  # Hint stays on screen for 8 seconds

# Hint definitions
const HINTS: Dictionary = {
	"first_gather": {
		"trigger": "player_near_resource",
		"text": "🪵 [b]Gathering:[/b] Click on trees, rocks, or bushes to gather resources.",
		"once": true
	},
	"first_build": {
		"trigger": "pressed_b_key",
		"text": "🔨 [b]Building:[/b] Select a building type, then click on the map to place. Resources are auto-deducted.",
		"once": true
	},
	"first_craft": {
		"trigger": "pressed_c_key",
		"text": "🔪 [b]Crafting:[/b] Craft tools to improve gathering efficiency. Flint Pickaxe gives +50% stone!",
		"once": true
	},
	"first_memorial": {
		"trigger": "pawn_death_memorial_created",
		"text": "🏛️ [b]Memorials:[/b] Pawns are remembered after death. Click on grave markers to read their story.",
		"once": true
	},
	"first_pilgrimage": {
		"trigger": "pawn_visits_memorial",
		"text": "🙏 [b]Pilgrimage:[/b] Pawns visit memorials of family and enemies. Some find closure and let go of grudges.",
		"once": true
	},
	"first_knowledge": {
		"trigger": "knowledge_carrier_at_risk",
		"text": "📚 [b]Knowledge is Fragile:[/b] When only one pawn knows a skill, it's at risk. If they die untaught, it's lost forever.",
		"once": true
	},
	"first_grudge_closure": {
		"trigger": "grudge_closure_at_memorial",
		"text": "💝 [b]Closure:[/b] Visiting memorials can help pawns let go of old grudges. Healing takes time.",
		"once": true
	},
	"survival_tip": {
		"trigger": "pawn_hunger_low",
		"text": "🍖 [b]Survival Tip:[/b] Keep your pawns fed! Berries can be gathered from bushes. Cooked food lasts longer.",
		"once": false  # Shows every time hunger is critical
	},
	"save_reminder": {
		"trigger": "every_5_minutes",
		"text": "💾 [b]Remember to Save![/b] Press F5 to save your progress. F9 to reload.",
		"once": false
	},
}

var _shown_hints: Array = []  # Hints already shown this session
var _current_hint: String = ""
var _hint_timer: float = 0.0
var _hint_display_timer: float = 0.0
var _hints_enabled: bool = true

@onready var _hint_label: Label = null  # Created in _ready


func _ready() -> void:
	# Create hint label (top center of screen)
	_create_hint_label()
	
	# Load shown hints from settings (persist across sessions)
	_load_shown_hints()
	
	# Connect to game events
	_connect_game_events()


func _create_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.name = "TutorialHintLabel"
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_top = 0.0
	_hint_label.anchor_right = 0.5
	_hint_label.anchor_bottom = 0.0
	_hint_label.offset_left = -300.0
	_hint_label.offset_top = 20.0
	_hint_label.offset_right = 300.0
	_hint_label.offset_bottom = 60.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("outline_size", 2)
	_hint_label.visible = false
	
	# Add to canvas layer
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100  # Top layer
	canvas.add_child(_hint_label)
	add_child(canvas)


func _connect_game_events() -> void:
	# Connect to GameManager for key presses
	if GameManager != null:
		pass  # Will connect in _process
	
	# Connect to MemorialSystem for memorial events
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms != null:
		pass  # Will check in _process
	
	# Connect to KnowledgeSystem for at-risk knowledge
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks != null:
		pass  # Will check in _process


func _process(delta: float) -> void:
	if not _hints_enabled:
		return
	
	# Update timers
	if _current_hint != "":
		_hint_display_timer += delta
		if _hint_display_timer >= HINT_DURATION_SEC:
			_hide_hint()
	else:
		_hint_timer += delta
		if _hint_timer >= HINT_DELAY_SEC:
			_check_for_hints()
			_hint_timer = 0.0


func _check_for_hints() -> void:
	# Check each hint trigger
	for hint_key in HINTS:
		if _shown_hints.has(hint_key) and HINTS[hint_key].get("once", false):
			continue  # Already shown, and once-only
		
		if _check_trigger(HINTS[hint_key].trigger):
			_show_hint(hint_key)
			break


func _check_trigger(trigger: String) -> bool:
	match trigger:
		"player_near_resource":
			return _check_player_near_resource()
		"pressed_b_key":
			return Input.is_key_pressed(KEY_B)
		"pressed_c_key":
			return Input.is_key_pressed(KEY_C)
		"pawn_death_memorial_created":
			return _check_memorial_created()
		"pawn_visits_memorial":
			return _check_pawn_at_memorial()
		"knowledge_carrier_at_risk":
			return _check_at_risk_knowledge()
		"grudge_closure_at_memorial":
			return _check_grudge_closure()
		"pawn_hunger_low":
			return _check_pawn_hunger_low()
		"every_5_minutes":
			return Engine.get_frames_drawn() % (60 * 5 * 60) == 0  # Every 5 minutes
	
	return false


func _check_player_near_resource() -> bool:
	# Check if player pawn is near a gatherable resource
	var pg: Node = get_node_or_null("/root/PlayerGathering")
	if pg == null:
		return false

	# Simplified: just check if player has no resources
	var inventory: Dictionary = {}
	if pg.has_method("get"):
		var inv_variant = pg.get("player_inventory")
		if inv_variant != null and inv_variant is Dictionary:
			inventory = inv_variant
	
	var wood_count: int = inventory.get("wood", 0)
	var stone_count: int = inventory.get("stone", 0)
	return wood_count == 0 and stone_count == 0


func _check_memorial_created() -> bool:
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms == null:
		return false
	
	# Check if any memorials were created in last 100 ticks
	var memorials: Array[Dictionary] = ms.get_memorials() if ms.has_method("get_memorials") else []
	for memorial in memorials:
		var created_tick: int = memorial.get("created_tick", 0)
		if GameManager.tick_count - created_tick < 100:
			return true
	return false


func _check_pawn_at_memorial() -> bool:
	# Check if any pawn is at a memorial tile
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	var ps: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ms == null or ps == null:
		return false
	
	var memorials: Array[Dictionary] = ms.get_memorials() if ms.has_method("get_memorials") else []
	for memorial in memorials:
		var memorial_tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
		for pawn in ps.pawns:
			if pawn != null and pawn.data != null and pawn.data.tile_pos == memorial_tile:
				return true
	return false


func _check_at_risk_knowledge() -> bool:
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return false
	
	# Check if any knowledge has only 1 carrier
	if ks.has_method("get_knowledge_status"):
		var status: Dictionary = ks.call("get_knowledge_status")
		return status.get("at_risk", 0) > 0
	return false


func _check_grudge_closure() -> bool:
	var gm: Node = get_node_or_null("/root/GrudgeManager")
	if gm == null:
		return false
	
	# Check if any grudge was recently closed
	# (Would need GrudgeManager to track this — TODO)
	return false


func _check_pawn_hunger_low() -> bool:
	var ps: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null:
		return false

	for pawn in ps.pawns:
		if pawn != null and pawn.data != null:
			var hunger: float = pawn.data.hunger if pawn.data.hunger != null else 100.0
			if hunger < 30.0:
				return true
	return false


func _show_hint(hint_key: String) -> void:
	_current_hint = hint_key
	_hint_label.text = HINTS[hint_key].text
	_hint_label.visible = true
	_hint_display_timer = 0.0
	
	if not _shown_hints.has(hint_key):
		_shown_hints.append(hint_key)
		_save_shown_hints()


func _hide_hint() -> void:
	_current_hint = ""
	_hint_label.visible = false
	_hint_label.text = ""


func _load_shown_hints() -> void:
	# Load from user:// settings file
	var save_path: String = "user://tutorial_hints_shown.json"
	if FileAccess.file_exists(save_path):
		var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		var json: JSON = JSON.new()
		var error: Error = json.parse(file.get_as_text())
		if error == OK:
			_shown_hints = json.data
		file.close()


func _save_shown_hints() -> void:
	# Save to user:// settings file
	var save_path: String = "user://tutorial_hints_shown.json"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	var json: JSON = JSON.new()
	file.store_string(json.stringify(_shown_hints))
	file.close()


## Reset all hints (for settings menu)
func reset_hints() -> void:
	_shown_hints.clear()
	_save_shown_hints()
	print("[OrientationHints] All hints reset - will show again")


## Toggle hints on/off (for settings menu)
func toggle_hints(enabled: bool) -> void:
	_hints_enabled = enabled
	print("[OrientationHints] Hints %s" % ("enabled" if enabled else "disabled"))
