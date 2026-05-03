extends Node

## Headless test for KinshipSystem LINEAGE KEEPER Kin APIs
## Run with: godot --headless --script scripts/tests/test_kinship_api.gd

func _ready() -> void:
	print("[test_kinship_api] Starting...")
	var passed = 0
	var failed = 0
	
	# Get or create KinshipSystem
	var ks = get_node_or_null("/root/KinshipSystem")
	if ks == null:
		# Create if not present
		ks = load("res://autoloads/KinshipSystem.gd").new()
		add_child(ks)
	
	# Clear any existing data
	if ks.has_method("clear"):
		ks.clear()
	
	# Clear lineage-specific data
	if ks.has("_child_to_parents"):
		ks._child_to_parents = {}
	if ks.has("_parent_to_children"):
		ks._parent_to_children = {}
	if ks.has("_pending_births"):
		ks._pending_births = {}
	
	# Test 1: Grandparent -> parent -> child
	print("[test_kinship_api] Test 1: Grandparent lineage...")
	ks.register_birth(2, 1, -1)  # parent(2) born from grandparent(1)
	ks._test_flush_pending_births(10)
	
	var ancestors = ks.get_ancestors(2, 1)
	if ancestors == [1]:
		passed += 1
		print("[test_kinship_api]   PASS: get_ancestors(depth=1)")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: expected [1], got %s" % str(ancestors))
	
	# Register child
	ks.register_birth(3, 2, -1)  # child(3) born from parent(2)
	ks._test_flush_pending_births(20)
	
	ancestors = ks.get_ancestors(3, 2)
	if ancestors == [2, 1]:
		passed += 1
		print("[test_kinship_api]   PASS: get_ancestors(depth=2)")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: expected [2, 1], got %s" % str(ancestors))
	
	# Test 2: Siblings
	print("[test_kinship_api] Test 2: Siblings...")
	# Already have parent(2) with child(3), add sibling for child(3)
	ks.register_birth(4, 2, -1)  # sibling(4) shares parent(2)
	ks._test_flush_pending_births(30)
	
	var siblings = ks.get_siblings(3)
	if siblings.has(4):
		passed += 1
		print("[test_kinship_api]   PASS: get_siblings includes sibling")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: sibling not found in get_siblings")
	
	# Verify self excluded
	if not siblings.has(3):
		passed += 1
		print("[test_kinship_api]   PASS: self excluded from siblings")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: self included in siblings")
	
	# Test 3: Orphan pawn
	print("[test_kinship_api] Test 3: Orphan...")
	var orphan_parents = ks.get_parents(999)
	if orphan_parents.is_empty():
		passed += 1
		print("[test_kinship_api]   PASS: orphan has no parents")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: orphan has parents: %s" % str(orphan_parents))
	
	var orphan_children = ks.get_children(999)
	if orphan_children.is_empty():
		passed += 1
		print("[test_kinship_api]   PASS: orphan has no children")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: orphan has children: %s" % str(orphan_children))
	
	var orphan_siblings = ks.get_siblings(999)
	if orphan_siblings.is_empty():
		passed += 1
		print("[test_kinship_api]   PASS: orphan has no siblings")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: orphan has siblings: %s" % str(orphan_siblings))
	
	var orphan_ancestors = ks.get_ancestors(999, 2)
	if orphan_ancestors.is_empty():
		passed += 1
		print("[test_kinship_api]   PASS: orphan has no ancestors")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: orphan has ancestors: %s" % str(orphan_ancestors))
	
	# Test 4: Idempotent register_birth
	print("[test_kinship_api] Test 4: Idempotent...")
	ks.register_birth(3, 2, -1)  # Duplicate call
	ks.register_birth(3, 2, -1)  # Another duplicate
	ks._test_flush_pending_births(40)
	
	var child_parents = ks.get_parents(3)
	var unique_parents = {}
	var has_duplicates = false
	for p in child_parents:
		if unique_parents.has(p):
			has_duplicates = true
			break
		unique_parents[p] = true
	
	if not has_duplicates:
		passed += 1
		print("[test_kinship_api]   PASS: no duplicate parents")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: duplicate parents found")
	
	# Verify child appears only once under each parent
	var parent2_children = ks.get_children(2)
	if parent2_children.count(3) == 1:
		passed += 1
		print("[test_kinship_api]   PASS: child registered once under parent")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: child registered %d times" % parent2_children.count(3))
	
	# Test 5: Invalid inputs
	print("[test_kinship_api] Test 5: Invalid inputs...")
	ks.register_birth(0, 1, 2)  # Invalid child_id
	ks.register_birth(-1, 1, 2)  # Negative child_id
	ks._test_flush_pending_births(50)
	
	var invalid_parents = ks.get_parents(0)
	if invalid_parents.is_empty():
		passed += 1
		print("[test_kinship_api]   PASS: child_id=0 returns empty")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: child_id=0 should be empty")
	
	# Test 6: Loop protection
	print("[test_kinship_api] Test 6: Loop protection...")
	# Create circular: A -> B -> C -> A
	ks.register_birth(101, 103, -1)  # 101 child of 103
	ks.register_birth(102, 101, -1)  # 102 child of 101
	ks.register_birth(103, 102, -1)  # 103 child of 102 (circular!)
	ks._test_flush_pending_births(60)
	
	# Should not infinite loop
	var loop_ancestors_101 = ks.get_ancestors(101, 10)
	if loop_ancestors_101.size() < 10:
		passed += 1
		print("[test_kinship_api]   PASS: loop protection works, got %d ancestors" % loop_ancestors_101.size())
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: possible infinite loop, got %d ancestors" % loop_ancestors_101.size())
	
	# Verify depth cap
	if loop_ancestors_101.size() <= 10:
		passed += 1
		print("[test_kinship_api]   PASS: depth cap respected")
	else:
		failed += 1
		print("[test_kinship_api]   FAIL: depth %d exceeds cap" % loop_ancestors_101.size())
	
	# Summary
	print("\n[test_kinship_api] ====================")
	print("[test_kinship_api] PASSED: %d" % passed)
	print("[test_kinship_api] FAILED: %d" % failed)
	print("[test_kinship_api] ====================")
	
	if failed > 0:
		print("[test_kinship_api] TESTS FAILED")
		get_tree().quit(1)
	else:
		print("[test_kinship_api] ALL TESTS PASSED")
		get_tree().quit(0)