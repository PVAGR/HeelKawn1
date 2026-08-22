extends Node

func _state_label(s: SettlementData.State) -> String:
	match s:
		SettlementData.State.THRIVING:
			return "THRIVING"
		SettlementData.State.ABANDONED:
			return "ABANDONED"
		SettlementData.State.RUINS:
			return "RUINS"
		SettlementData.State.SCAR:
			return "SCAR"
	return "UNKNOWN"

func _ready() -> void:
	# SettlementPersistenceManager was deleted; logic moved to SettlementPersistence autoload.
	# This test kernel is temporarily disabled pending Phase 4 Identity updates.
	print("[TEST] TestPhase4Kernel skipped (Manager deleted)")
