extends Node
class_name UI_TestHarness

## Lightweight Godot UI test harness (skeleton)
## Intended to be triggered by the build flow in headless or GUI mode.

func run_all_tests() -> void:
	print("UI Test Harness: starting tests...")
	_test_survivalhud()
	_test_inventoryui()
	_test_pawnmoodui()
	print("UI Test Harness: tests complete.")

func _test_survivalhud() -> void:
	var node = get_node_or_null("/root/Scene/scenes/ui/SurvivalHUD.tscn")
	if node:
		print("SurvivalHUD node found: ok")
	else:
		push_error("SurvivalHUD node not found in scene tree")

func _test_inventoryui() -> void:
	var node = get_node_or_null("/root/Scene/scenes/ui/PlayerInventoryUI.tscn")
	if node:
		print("PlayerInventoryUI node found: ok")
	else:
		push_error("PlayerInventoryUI node not found in scene tree")

func _test_pawnmoodui() -> void:
	var node = get_node_or_null("/root/Scene/scenes/ui/PawnMoodUI.tscn")
	if node:
		print("PawnMoodUI node found: ok")
	else:
		push_error("PawnMoodUI node not found in scene tree")
