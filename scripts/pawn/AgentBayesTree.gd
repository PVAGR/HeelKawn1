extends RefCounted
class_name AgentBayesTree

## Lightweight per-agent Bayesian-style learner.
## Stores tiny counts keyed by simple tokens and exposes a record API.

var _nodes: Dictionary = {}
var events: int = 0

func record_job_outcome(job: Job, success: bool) -> void:
	if job == null:
		return
	var key: String = _key_for_job(job)
	var node: Dictionary = _nodes.get(key, {"good":0, "bad":0, "total":0})
	events += 1
	if success:
		node["good"] = int(node.get("good", 0)) + 1
	else:
		node["bad"] = int(node.get("bad", 0)) + 1
	node["total"] = int(node.get("total", 0)) + 1
	_nodes[key] = node

func get_stats_for_job(job_type: int) -> Dictionary:
	var key: String = str(job_type)
	return _nodes.get(key, {"good":0, "bad":0, "total":0})

func _key_for_job(job: Job) -> String:
	# Simple key: job type plus target tile region
	var k: String = "t:%d" % int(job.type)
	if job.tile != null:
		k += ":%d,%d" % [int(job.tile.x), int(job.tile.y)]
	return k


func to_dict() -> Dictionary:
	# Export internal nodes for persistence
	return {"events": events, "nodes": _nodes.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	if d == null:
		return
	events = int(d.get("events", events))
	var raw: Variant = d.get("nodes", {})
	if raw is Dictionary:
		_nodes = (raw as Dictionary).duplicate(true)
	else:
		_nodes = {}
