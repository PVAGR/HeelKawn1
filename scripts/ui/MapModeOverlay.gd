extends Node
class_name MapModeOverlay
## Phase 5: Map Mode overlay system - CK3-style regional visualization
## Provides grand-strategy map view with region polygons and settlement overlays

enum DisplayMode {
	REGIONS = 0,
	SETTLEMENTS = 1,
	CULTURE = 2,
	SCAR_LEVEL = 3,
	GOVERNANCE = 4,
	NATIONS = 5,
}

const _WM = preload("res://autoloads/WorldMemory.gd")

var current_mode: DisplayMode = DisplayMode.REGIONS
var overlay_visible: bool = false
var world: World = null
var camera: Camera2D = null
var canvas_layer: CanvasLayer = null

# UI elements
@onready var mode_button: Button = $VBoxContainer/ModeButton
@onready var toggle_button: Button = $VBoxContainer/ToggleButton
@onready var info_label: Label = $VBoxContainer/InfoLabel

# Overlay rendering
var overlay_texture: ImageTexture
var overlay_image: Image
var region_colors: Dictionary = {}

func _ready() -> void:
	overlay_image = Image.create(WorldData.WIDTH, WorldData.HEIGHT, false, Image.FORMAT_RGBA8)
	overlay_texture = ImageTexture.new()
	overlay_texture.set_image(overlay_image)
	
	# Create CanvasLayer for overlay rendering
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Connect button signals
	if mode_button:
		mode_button.pressed.connect(_cycle_mode)
	if toggle_button:
		toggle_button.pressed.connect(_toggle_overlay)
	
	# Hide initially
	canvas_layer.visible = false
	overlay_visible = false

func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	world = world_ref
	camera = camera_ref
	_update_region_colors()

var _overlay_throttle_frames: int = 0

func _process(_delta: float) -> void:
	if overlay_visible and world != null:
		_overlay_throttle_frames += 1
		if _overlay_throttle_frames >= 30:  # Rebuild every 30 frames instead of every frame
			_overlay_throttle_frames = 0
			_update_overlay()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == Key.KEY_M:
			_toggle_overlay()
		elif event.keycode == Key.KEY_TAB and overlay_visible:
			_cycle_mode()

func _toggle_overlay() -> void:
	overlay_visible = not overlay_visible
	canvas_layer.visible = overlay_visible
	
	if toggle_button:
		toggle_button.text = "Hide Map (M)" if overlay_visible else "Show Map (M)"
	
	if overlay_visible and world != null:
		_update_overlay()
		_update_info_label()

func _cycle_mode() -> void:
	current_mode = (current_mode + 1) % DisplayMode.size()
	_update_region_colors()
	_update_info_label()
	
	if mode_button:
		var mode_names = ["Regions", "Settlements", "Culture", "Scar Level", "Governance", "Nations"]
		mode_button.text = "Mode: %s (TAB)" % mode_names[current_mode]

func _update_region_colors() -> void:
	region_colors.clear()
	
	match current_mode:
		DisplayMode.REGIONS:
			_generate_region_colors()
		DisplayMode.SETTLEMENTS:
			_generate_settlement_colors()
		DisplayMode.CULTURE:
			_generate_culture_colors()
		DisplayMode.SCAR_LEVEL:
			_generate_scar_colors()
		DisplayMode.GOVERNANCE:
			_generate_governance_colors()
		DisplayMode.NATIONS:
			_generate_nation_colors()

func _generate_region_colors() -> void:
	# Generate distinct colors for each 16x16 region
	var nrx: int = int((WorldData.WIDTH + 15) / 16)
	var nry: int = int((WorldData.HEIGHT + 15) / 16)
	
	for ry in range(nry):
		for rx in range(nrx):
			var region_key: int = rx | (ry << 16)
			# Use deterministic color based on region key
			var hue: float = float(region_key % 360) / 360.0
			var color: Color = Color.from_hsv(hue, 0.7, 0.8, 0.6)
			region_colors[region_key] = color

func _generate_settlement_colors() -> void:
	# Color based on settlement presence and state
	for settlement in SettlementMemory.settlements:
		if not (settlement is Dictionary):
			continue
		
		var st: Dictionary = settlement as Dictionary
		var regions: PackedInt32Array = st.get("regions", PackedInt32Array())
		var state: String = str(st.get("state", "unknown"))
		
		var color: Color
		match state:
			"active":
				color = Color(0.2, 0.8, 0.2, 0.7)  # Green
			"recovering":
				color = Color(0.8, 0.8, 0.2, 0.7)  # Yellow
			"abandoned":
				color = Color(0.8, 0.4, 0.2, 0.7)  # Orange
			"permanently_abandoned":
				color = Color(0.8, 0.2, 0.2, 0.7)  # Red
			_:
				color = Color(0.5, 0.5, 0.5, 0.5)  # Gray
		
		for rk in regions:
			region_colors[int(rk)] = color

func _generate_culture_colors() -> void:
	# Color based on settlement culture types
	for settlement in SettlementMemory.settlements:
		if not (settlement is Dictionary):
			continue
		
		var st: Dictionary = settlement as Dictionary
		var regions: PackedInt32Array = st.get("regions", PackedInt32Array())
		var culture_type: int = int(st.get("culture_type", 0))
		
		var color: Color
		match culture_type:
			SettlementManager.CULTURE_OPEN:
				color = Color(0.2, 0.6, 0.9, 0.7)  # Blue
			SettlementManager.CULTURE_CAUTIOUS:
				color = Color(0.6, 0.6, 0.6, 0.7)  # Gray
			SettlementManager.CULTURE_DEFENSIVE:
				color = Color(0.9, 0.3, 0.3, 0.7)  # Red
			_:
				color = Color(0.5, 0.5, 0.5, 0.5)  # Gray
		
		for rk in regions:
			region_colors[int(rk)] = color

func _generate_scar_colors() -> void:
	# Color based on scar levels
	var nrx: int = int((WorldData.WIDTH + 15) / 16)
	var nry: int = int((WorldData.HEIGHT + 15) / 16)
	
	for ry in range(nry):
		for rx in range(nrx):
			var region_key: int = rx | (ry << 16)
			var scar_level: int = int(WorldPersistence.get_region_persistence(region_key).get("scar_level", 0))
			
			var color: Color
			match scar_level:
				0:
					color = Color(0.9, 0.9, 0.9, 0.3)  # Light gray
				1:
					color = Color(0.8, 0.7, 0.5, 0.5)  # Light brown
				2:
					color = Color(0.7, 0.5, 0.3, 0.6)  # Brown
				3:
					color = Color(0.5, 0.3, 0.1, 0.7)  # Dark brown
				_:
					color = Color(0.3, 0.1, 0.0, 0.8)  # Very dark brown
			
			region_colors[region_key] = color

func _generate_governance_colors() -> void:
	# Color based on governance types
	for settlement in SettlementMemory.settlements:
		if not (settlement is Dictionary):
			continue
		
		var st: Dictionary = settlement as Dictionary
		var center_region: int = int(st.get("center_region", -1))
		if center_region < 0:
			continue
		
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center_region)
		var gov_type: String = str(gov.get("type", "anarchy"))
		
		var color: Color
		match gov_type:
			"monarchy":
				color = Color(0.6, 0.2, 0.8, 0.7)  # Purple
			"council":
				color = Color(0.2, 0.4, 0.8, 0.7)  # Blue
			"anarchy":
				color = Color(0.7, 0.7, 0.7, 0.5)  # Light gray
			_:
				color = Color(0.5, 0.5, 0.5, 0.5)  # Gray
		
		region_colors[center_region] = color


## NATIONS mode: color every region by its nation owner (CK-style).
## Uses NationBorderSystem.get_nation_at_region() to map region_key -> nation_id,
## then NationBorderSystem's 20-color palette for consistent nation colors.
## Unclaimed regions stay transparent (no overlay tint).
## Contested regions get a pulsing red tint when NationBorderSystem tracks them.
func _generate_nation_colors() -> void:
	if NationBorderSystem == null:
		return
	
	var nrx: int = int((WorldData.WIDTH + 15) / 16)
	var nry: int = int((WorldData.HEIGHT + 15) / 16)
	
	for ry in range(nry):
		for rx in range(nrx):
			var region_key: int = rx | (ry << 16)
			var nation_id: int = NationBorderSystem.get_nation_at_region(region_key)
			if nation_id < 0:
				continue  # Unclaimed — leave transparent
			
			var nation: Dictionary = NationBorderSystem.get_nation_by_id(nation_id)
			if nation.is_empty():
				continue
			
			var hex_color: String = str(nation.get("color", "#888888"))
			var nation_color: Color = NationBorderSystem._hex_to_color(hex_color)
			
			# Contested regions: pulse red over nation color
			if NationBorderSystem.is_region_contested(region_key):
				var pulse: float = 0.3 + 0.4 * (sin(float(region_key + ry * 7 + rx * 13) * 0.5 + 1.0))
				nation_color = nation_color.lerp(Color(1.0, 0.2, 0.1, 1.0), pulse * 0.5)
				nation_color.a = 0.85
			else:
				nation_color.a = 0.65
			
			region_colors[region_key] = nation_color

func _update_overlay() -> void:
	if overlay_image == null or world == null or canvas_layer == null:
		return
	
	overlay_image.fill(Color.TRANSPARENT)
	
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var region_key: int = _WM._region_key(x, y)
			if region_colors.has(region_key):
				overlay_image.set_pixel(x, y, region_colors[region_key])
	
	overlay_texture.set_image(overlay_image)
	
	for child in canvas_layer.get_children():
		child.queue_free()
	
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = overlay_texture
	sprite.position = Vector2(WorldData.WIDTH * 5, WorldData.HEIGHT * 5)
	sprite.scale = Vector2(10, 10)
	canvas_layer.add_child(sprite)

func _update_info_label() -> void:
	if info_label == null:
		return
	
	var mode_names = ["Regions", "Settlements", "Culture", "Scar Level", "Governance", "Nations"]
	var mode_descriptions = [
		"Shows 16x16 region boundaries",
		"Shows settlement states (active/recovering/abandoned)",
		"Shows cultural types (open/cautious/defensive)",
		"Shows scar levels (0-3+)",
		"Shows governance types (monarchy/council/anarchy)",
		"Shows nation territories and contested borders (CK-style)",
	]
	
	var mode_index: int = current_mode as int
	info_label.text = "%s: %s" % [mode_names[mode_index], mode_descriptions[mode_index]]

func draw_overlay(canvas_item: CanvasItem) -> void:
	if not overlay_visible or overlay_texture == null:
		return
	
	canvas_item.draw_texture(overlay_texture, Vector2.ZERO)

func get_overlay_texture() -> ImageTexture:
	return overlay_texture

func set_mode(mode: DisplayMode) -> void:
	current_mode = mode
	_update_region_colors()
	_update_info_label()

func is_overlay_visible() -> bool:
	return overlay_visible