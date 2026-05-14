## UrgeQueue.gd — Priority resolver with commitment.
##
## Collects urges from all drives, resolves conflicts, and produces a single
## decision. The strongest urge wins. But commitment prevents oscillation —
## once a pawn acts on an urge, it has a minimum commitment window before
## weaker urges can override.
##
## The queue is the mind's arbitration layer. Drives push; the queue decides.
extends RefCounted
class_name UrgeQueue

## Minimum ticks before a non-interrupting urge can override the committed action.
const MIN_COMMITMENT_TICKS: int = 50

## Body (survival) urges commit for less time — they resolve fast, then re-evaluate.
const EMERGENCY_COMMITMENT_TICKS: int = 10

## Maximum urges kept in queue before pruning. Prevents memory bloat.
const MAX_URGES: int = 12

var _urges: Array[Urge] = []
var _committed_urge: Urge = null
var _commitment_tick: int = 0
var _commitment_duration: int = 0

## Last resolved urge (for debug/UI)
var last_resolved: Urge = null
var last_resolved_tick: int = -1


## Push an urge into the queue. If the queue is full, drop the weakest.
func push(urge: Urge) -> void:
	if _urges.size() >= MAX_URGES:
		_drop_weakest()
	_urges.append(urge)


## Clear all pending urges (not the commitment).
func clear() -> void:
	_urges.clear()


## Release the current commitment. Called when the committed action fails
## (e.g., no food available, no path to job, job cancelled).
func release_commitment() -> void:
	_committed_urge = null
	_commitment_tick = 0
	_commitment_duration = 0


## Resolve: pick the strongest urge, respecting commitment.
##
## If committed and the window hasn't expired, only interrupts can break it.
## If not committed (or commitment expired), the strongest urge wins.
## Returns null if no urges and no commitment.
func resolve(current_tick: int) -> Urge:
	# 1. If committed and not expired, check for interrupts
	if _committed_urge != null:
		var elapsed: int = current_tick - _commitment_tick
		var remaining: int = _commitment_duration - elapsed
		if remaining > 0:
			# Only interrupts can break commitment
			var interrupt: Urge = _best_interrupt(float(remaining))
			if interrupt != null:
				_commit(interrupt, current_tick)
				last_resolved = interrupt
				last_resolved_tick = current_tick
				return interrupt
			# Stay committed — clear pending urges (they're stale)
			_urges.clear()
			return _committed_urge
		else:
			# Commitment expired
			_committed_urge = null

	# 2. No commitment — pick strongest urge
	if _urges.is_empty():
		return null

	var best: Urge = _urges[0]
	for u in _urges:
		if u.priority > best.priority:
			best = u

	_commit(best, current_tick)
	last_resolved = best
	last_resolved_tick = current_tick
	return best


## Find the best interrupting urge that can break the current commitment.
func _best_interrupt(remaining_commitment: float) -> Urge:
	var best: Urge = null
	for u in _urges:
		if u.interrupt_strength > remaining_commitment:
			if best == null or u.priority > best.priority:
				best = u
	return best


## Commit to an urge. Set the commitment window based on source.
func _commit(urge: Urge, tick: int) -> void:
	_committed_urge = urge
	_commitment_tick = tick
	_commitment_duration = EMERGENCY_COMMITMENT_TICKS if urge.source == Urge.Source.BODY else MIN_COMMITMENT_TICKS
	_urges.clear()


## Drop the lowest-priority urge from the queue.
func _drop_weakest() -> void:
	if _urges.is_empty():
		return
	var weakest_idx: int = 0
	var weakest_pri: float = _urges[0].priority
	for i in range(1, _urges.size()):
		if _urges[i].priority < weakest_pri:
			weakest_pri = _urges[i].priority
			weakest_idx = i
	_urges.remove_at(weakest_idx)


## Is the queue currently committed to an action?
func is_committed() -> bool:
	return _committed_urge != null


## What type is the committed urge? Returns -1 if not committed.
func committed_type() -> int:
	return _committed_urge.type if _committed_urge != null else -1


## How many ticks until commitment expires?
func commitment_remaining(current_tick: int) -> int:
	if _committed_urge == null:
		return 0
	return maxi(0, _commitment_duration - (current_tick - _commitment_tick))


## Debug: describe the current state.
func describe(current_tick: int) -> String:
	var parts: Array[String] = []
	if _committed_urge != null:
		var rem: int = commitment_remaining(current_tick)
		parts.append("committed: %s (%d ticks left)" % [_committed_urge.describe(), rem])
	else:
		parts.append("uncommitted")
	parts.append("pending: %d" % _urges.size())
	for u in _urges:
		parts.append("  %s" % u.describe())
	return "\n".join(parts)
