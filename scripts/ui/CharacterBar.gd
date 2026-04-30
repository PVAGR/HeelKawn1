extends Control
class_name CharacterBar
## Phase 5: Character Bar - Pinned rulers per settlement
## Shows settlement rulers with click-to-jump camera functionality

var world: World = null
var camera: Camera2D = null
var ruler_buttons: Array[Button] = []
var pinned_settlements: Array[int] = []

# UI elements
@onready var ruler_container: HBoxContainer = $HBoxContainer
@onready var add_button: Button = $AddButton
@onready var clear_button: Button = $ClearButton

const MAX_PINNED: int = 8

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_add_current_settlement)
	if clear_button:
		clear_button.pressed.connect(_clear_all)
	
	_refresh_ruler_buttons()

func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	world = world_ref
	camera = camera_ref
	_refresh_ruler_buttons()

func _add_current_settlement() -> void:
	if world == null or camera == null:
		return
	
	var cam_tile: Vector2i = world.world_to_tile(camera.global_position)
	if cam_tile.x < 0:
		return
	
	var region_key: int = WorldMemory._region_key(cam_tile.x, cam_tile.y)
	var settlement: Variant = SettlementMemory.get_settlement_at_region(region_key)
	
	if not (settlement is Dictionary):
		return
	
	var st: Dictionary = settlement as Dictionary
	var center_region: int = int(st.get("center_region", -1))
	
	if center_region < 0:
		return
	
	# Check if already pinned
	if pinned_settlements.has(center_region):
		return
	
	# Add to pinned list
	if pinned_settlements.size() >= MAX_PINNED:
		pinned_settlements.pop_front()
	
	pinned_settlements.append(center_region)
	_refresh_ruler_buttons()

func _clear_all() -> void:
	pinned_settlements.clear()
	_refresh_ruler_buttons()

func _refresh_ruler_buttons() -> void:
	# Clear existing buttons
	for btn in ruler_buttons:
		btn.queue_free()
	ruler_buttons.clear()
	
	if ruler_container == null:
		return
	
	# Create buttons for each pinned settlement
	for center_region in pinned_settlements:
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center_region)
		var ruler_id: int = int(gov.get("ruler_id", -1))
		var gov_type: String = str(gov.get("type", "anarchy"))
		
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(120, 40)
		
		# Get ruler name
		var ruler_name: String = _get_pawn_name(ruler_id)
		if ruler_name == "Unknown":
			ruler_name = "No Ruler"
		
		var gov_label: String = _pretty_governance_name(gov_type)
		btn.text = "%s\n%s" % [ruler_name, gov_label]
		
		# Connect click to jump camera
		btn.pressed.connect(_jump_to_settlement.bind(center_region))
		
		ruler_container.add_child(btn)
		ruler_buttons.append(btn)

func _jump_to_settlement(center_region: int) -> void:
	if world == null or camera == null:
		return
	
	var settlement: Variant = SettlementMemory.get_settlement_at_region(center_region)
	if not (settlement is Dictionary):
		return
	
	var st: Dictionary = settlement as Dictionary
	var regions: PackedInt32Array = st.get("regions", PackedInt32Array())
	
	if regions.is_empty():
		return
	
	# Jump to center region tile
	var center_x: int = (center_region & 0xFFFF) * 16 + 8
	var center_y: int = (center_region >> 16) * 16 + 8
	var target_pos: Vector2 = world.tile_to_world(Vector2i(center_x, center_y))
	
	camera.global_position = target_pos

func _get_pawn_name(pawn_id: int) -> String:
	if pawn_id < 0:
		return "None"
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return "Unknown"
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return "Unknown"
	
	for p in spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if int(p.data.id) == pawn_id:
			return str(p.data.display_name)
	
	return "Unknown"

func _pretty_governance_name(raw: String) -> String:
	match raw.to_lower():
		"monarchy":
			return "Monarchy"
		"council":
			return "Council"
		"chieftain":
			return "Chieftain"
		"tribal":
			return "Tribal"
		_:
			return "Anarchy"

func add_pinned_settlement(center_region: int) -> void:
	if pinned_settlements.has(center_region):
		return
	
	if pinned_settlements.size() >= MAX_PINNED:
		pinned_settlements.pop_front()
	
	pinned_settlements.append(center_region)
	_refresh_ruler_buttons()

func remove_pinned_settlement(center_region: int) -> void:
	var idx: int = pinned_settlements.find(center_region)
	if idx >= 0:
		pinned_settlements.remove_at(idx)
		_refresh_ruler_buttons()

func get_pinned_settlements() -> Array[int]:
	return pinned_settlements.duplicate()
