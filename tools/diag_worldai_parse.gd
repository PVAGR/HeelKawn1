extends SceneTree

var _frames := 0

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var sa: Node = root.get_node_or_null("/root/WorldAI")
	if sa == null:
		print("PARSE_PROBE: autoload not ready yet, retrying in 2 frames")
		return
	print("PARSE_PROBE WorldAI autoload ttl=%d entries=%d" % [int(sa.get("NEURAL_STATE_CACHE_TTL_TICKS")), int(sa.get("_pawn_neural_cache").size())])
	quit(0)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_probe()
	if _frames > 10:
		quit(1)
	return false