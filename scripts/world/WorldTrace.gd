extends Node2D
class_name WorldTrace

@export var max_traces := 200

var traces: Array = []


func _ready() -> void:
	# Draw above the world map sprite so death/build marks stay visible.
	z_index = 1
	set_process(true)


func record_trace(world_pos: Vector2, kind: String) -> void:
	if traces.size() >= max_traces:
		traces.pop_front()

	traces.append({
		"pos": world_pos,
		"kind": kind,
		"age": 0.0
	})
	queue_redraw()


func _process(delta: float) -> void:
	for t in traces:
		if t is Dictionary and t.has("age"):
			t["age"] = float(t["age"]) + delta


func _draw() -> void:
	draw_traces(self)


func get_local_fatigue(pos: Vector2, radius: float = 64.0) -> float:
	var fatigue: float = 0.0
	for t in traces:
		if not t is Dictionary:
			continue
		var tp: Vector2 = t["pos"] as Vector2
		var d: float = tp.distance_to(pos)
		if d > radius:
			continue
		var k: String = str(t.get("kind", ""))
		if k == "death":
			fatigue += 1.0
		elif k == "build":
			fatigue += 0.5
	return fatigue


func draw_traces(draw_node: Node2D) -> void:
	for t in traces:
		if not t is Dictionary:
			continue
		var p: Vector2 = draw_node.to_local(t["pos"] as Vector2)
		var kind: String = str(t["kind"])
		match kind:
			"death":
				draw_node.draw_circle(p, 3.0, Color(0.6, 0.1, 0.1, 0.8))
			"build":
				draw_node.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.2, 0.6, 0.2, 0.8))
