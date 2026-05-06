extends Node
## UIAutoSetup - Automatically adds UIManager to Main scene
##
## Just attach this to Main scene and it will:
## 1. Create UIManager
## 2. Add all UI panels
## 3. Connect hotkeys
## 4. Show help on first run
##
## NO MANUAL SETUP REQUIRED!

@export var auto_add_to_main: bool = true


func _ready() -> void:
	if not auto_add_to_main:
		return
	
	# Find Main node
	var main: Node = get_node_or_null("/root/Main")
	if main == null:
		print("UIAutoSetup: Main node not found, looking for alternative...")
		# Try to find any node that could be the main game node
		var root: Node = get_tree().get_root()
		for child in root.get_children():
			if child.name.contains("Main") or child.name.contains("Game"):
				main = child
				break
	
	if main == null:
		print("UIAutoSetup: Could not find main node, adding to root")
		main = get_tree().get_root()
	
	# Check if UIManager already exists
	if main.has_node("UIManager"):
		print("UIAutoSetup: UIManager already exists!")
		return
	
	# Create UIManager
	var ui_manager: Node = load("res://scripts/ui/UIManager.gd").new()
	ui_manager.name = "UIManager"
	main.add_child(ui_manager)
	
	print("UIAutoSetup: UIManager added successfully!")
	print("UIAutoSetup: Press H or F1 for help menu")
	print("UIAutoSetup: Press I for inventory, C for chronicles, K for character")
