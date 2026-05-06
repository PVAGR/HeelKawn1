extends Node
## AI Stack Test Script - Verifies all 5 AI layers initialize and run correctly
##
## Usage: Attach to a node in Main scene, or run via F10 debug menu
## Automatically tests all AI layers with mock LLM responses

var _orchestrator: HeelKawnAIOrchestrator = null
var _test_results: Array[Dictionary] = []
var _test_passed: int = 0
var _test_failed: int = 0

# Test configuration
var _test_layers: Array[String] = ["memory", "pawn", "settlement", "diplomacy", "ecosystem"]
var _test_context: Dictionary = {
	"tick": 1000,
	"year": 2,
	"active_settlements": 3,
	"sample_pawns": [
		{"id": 1, "name": "TestPawn1", "hunger": 80, "mood": 60},
		{"id": 2, "name": "TestPawn2", "hunger": 40, "mood": 90}
	],
	"settlements": [
		{"name": "TestSettlement1", "population": 15, "houses": 5},
		{"name": "TestSettlement2", "population": 20, "houses": 8}
	],
	"settlement_relations": [
		{"from_id": 1, "to_id": 2, "from_name": "Oakwood", "to_name": "Riverton"}
	]
}


func _ready() -> void:
	print("\n=== HEELKAWN AI STACK TEST ===\n")
	
	# Wait for autoloads to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Get orchestrator
	_orchestrator = get_node_or_null("/root/HeelKawnAIOrchestrator")
	
	if _orchestrator == null:
		print("❌ FAIL: HeelKawnAIOrchestrator not found!")
		print("Creating test orchestrator...")
		_orchestrator = HeelKawnAIOrchestrator.new()
		add_child(_orchestrator)
	
	# Run tests
	await _run_all_tests()
	
	# Print summary
	_print_test_summary()


func _run_all_tests() -> void:
	print("Testing AI layers...\n")
	
	for layer_name in _test_layers:
		await _test_layer(layer_name)
	
	await get_tree().create_timer(0.5).timeout


func _test_layer(layer_name: String) -> void:
	print("Testing Layer: {layer}...".format({"layer": layer_name}))
	
	var layer: Object = _orchestrator.layers.get(layer_name)
	
	if layer == null:
		_record_result(layer_name, false, "Layer not initialized")
		return
	
	if not layer.has_method("evaluate"):
		_record_result(layer_name, false, "Missing evaluate() method")
		return
	
	# Test layer evaluation
	var context: Dictionary = _build_layer_context(layer_name)
	var result: Dictionary = await layer.evaluate(context)
	
	if result.has("error"):
		_record_result(layer_name, false, "Error: " + result.error)
	else:
		_record_result(layer_name, true, "OK - " + str(result))


func _build_layer_context(layer_name: String) -> Dictionary:
	var context: Dictionary = _test_context.duplicate()
	
	match layer_name:
		"memory":
			context.recent_events = [
				{"type": "pawn_birth", "pawn_name": "Baby", "tick": 900},
				{"type": "job_completed", "job_type": "build_wall", "tick": 950}
			]
		
		"pawn":
			context.sample_pawns = _test_context.sample_pawns
		
		"settlement":
			context.settlements = _test_context.settlements
		
		"diplomacy":
			context.settlement_relations = _test_context.settlement_relations
		
		"ecosystem":
			context.wildlife_pops = [{"species": "deer", "count": 50}]
			context.disaster_risk = "low"
	
	return context


func _record_result(layer_name: String, passed: bool, message: String) -> void:
	_test_results.append({
		"layer": layer_name,
		"passed": passed,
		"message": message
	})
	
	if passed:
		_test_passed += 1
		print("  ✅ PASS: {msg}\n".format({"msg": message}))
	else:
		_test_failed += 1
		print("  ❌ FAIL: {msg}\n".format({"msg": message}))


func _print_test_summary() -> void:
	print("\n=== TEST SUMMARY ===")
	print("Total Layers Tested: {total}".format({"total": _test_layers.size()}))
	print("Passed: {passed}".format({"passed": _test_passed}))
	print("Failed: {failed}".format({"failed": _test_failed}))
	
	if _test_failed == 0:
		print("\n✅ ALL TESTS PASSED - AI Stack is functional!\n")
	else:
		print("\n⚠️  {failed} test(s) failed - Review errors above\n".format({"failed": _test_failed}))
	
	# Print LLM client stats
	if _orchestrator != null and _orchestrator._llm_client != null:
		var llm_stats: Dictionary = _orchestrator._llm_client.get_stats()
		print("LLM Client Stats:")
		print("  - Total Requests: {total}".format({"total": llm_stats.get("total_requests", 0)}))
		print("  - Successful: {success}".format({"success": llm_stats.get("successful_requests", 0)}))
		print("  - Mock Fallbacks: {mock}".format({"mock": llm_stats.get("mock_fallbacks", 0)}))
		print("  - Avg Response Time: {time:.1f}ms".format({"time": llm_stats.get("average_response_time_ms", 0)}))
	
	print("\n=== END TEST ===\n")


## Manual test trigger (call from F10 menu or debug)
func run_test() -> void:
	_test_passed = 0
	_test_failed = 0
	_test_results.clear()
	await _run_all_tests()
	_print_test_summary()
