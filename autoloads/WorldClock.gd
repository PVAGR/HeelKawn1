extends Node
## Keyboard speed / pause. Forwards to [GameManager] (sim does not use [Engine.time_scale]).


func _closest_speed_index() -> int:
	var g: float = GameManager.game_speed
	var best: int = 0
	var dmin: float = 1.0e9
	for i in range(GameManager.SPEED_STEPS.size()):
		var d: float = absf(GameManager.SPEED_STEPS[i] - g)
		if d < dmin:
			dmin = d
			best = i
	return best


func step_speed_up() -> void:
	var b: int = _closest_speed_index()
	if b < GameManager.SPEED_STEPS.size() - 1:
		GameManager.set_speed_index(b + 1)
	else:
		GameManager.set_speed_index(0)


func step_speed_down() -> void:
	var b: int = _closest_speed_index()
	if b > 0:
		GameManager.set_speed_index(b - 1)
	else:
		GameManager.set_speed_index(GameManager.SPEED_STEPS.size() - 1)


func toggle_pause() -> void:
	GameManager.toggle_pause()
