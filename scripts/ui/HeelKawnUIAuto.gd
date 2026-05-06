extends Node
## HeelKawnUIAuto - ZERO SETUP UI INSTALLER
##
## Attach this to Main scene and it automatically:
## 1. Creates HeelKawnUI
## 2. Adds all UI panels
## 3. Connects camera controls
## 4. Shows help on first run
##
## NO CONFIGURATION NEEDED - JUST ADD AND PLAY!

@export var auto_enable: bool = true


func _ready() -> void:
	if not auto_enable:
		return
	
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Find Main node
	var main: Node = _find_main_node()
	
	if main == null:
		print("❗ HeelKawnUIAuto: Could not find main node")
		return
	
	# Check if UI already exists
	if main.has_node("HeelKawnUI"):
		print("✅ HeelKawnUIAuto: UI already loaded!")
		return
	
	# Create and add UI
	var ui: Node = load("res://scripts/ui/HeelKawnUI.gd").new()
	ui.name = "HeelKawnUI"
	main.add_child(ui)
	
	print("✅ HeelKawnUIAuto: Professional UI loaded!")
	print("✅ Mouse wheel: Zoom in/out")
	print("✅ Right-click drag: Move camera")
	print("✅ Bottom buttons: All actions")
	print("✅ Press H for help")


func _find_main_node() -> Node:
	# Try common names
	var root: Node = get_tree().get_root()
	
	for child in root.get_children():
		if child.name.to_lower() in ["main", "game", "world", "root"]:
			return child
	
	# Fallback to first child
	if root.get_child_count() > 0:
		return root.get_child(0)
	
	return null
