extends Node


func _ready() -> void:
	if WorldMemory == null:
		push_error("WorldMemory autoload is not available.")
		return

	var pawns: Array[Node2D] = []
	for i in range(3):
		var pawn := Node2D.new()
		pawn.name = "TestPawn_%d" % (i + 1)
		pawn.position = Vector2(float(i * 16), 0.0)
		add_child(pawn)
		pawns.append(pawn)

	WorldMemory.clear()
	WorldMemory.record_event(WorldMemoryTypes.EventType.PAWN_DIED, "pawn_001", Vector2i(8, 8), {"killer_id": "wolf_001"})
	WorldMemory.record_event(WorldMemoryTypes.EventType.PAWN_DIED, "pawn_002", Vector2i(8, 8), {"killer_id": "wolf_001"})

	var events: Array[Dictionary] = WorldMemory.get_events_since(0, 999999)
	var export_a: String = WorldMemory.get_history_export_string(false)
	var export_b: String = WorldMemory.get_history_export_string(false)
	var export_c: String = WorldMemory.get_history_export_string(false)
	var stable_export: bool = export_a == export_b and export_b == export_c
	var summary: Dictionary = WorldMemory.compute_meaning(Vector2i(8, 8))

	print("[WorldMemoryTest] pawns=%d events=%d stable_export=%s meaning=%s" % [pawns.size(), events.size(), str(stable_export), str(summary)])
	if events.size() != 2 or not stable_export or not summary.is_empty():
		push_error("WorldMemory test scene failed: events=%d stable_export=%s meaning_empty=%s" % [events.size(), str(stable_export), str(summary.is_empty())])
	else:
		print("[WorldMemoryTest] PASS")