extends RefCounted
class_name BehaviorNode

## Behavior Tree Node - Base class for AI decision making
##
## Behavior Trees provide flexible, composable AI logic that's more
## maintainable than nested if/then statements.
##
## States:
## - RUNNING: Still executing (e.g., walking to destination)
## - SUCCESS: Completed successfully (e.g., reached destination)
## - FAILURE: Failed (e.g., path blocked)

enum State { RUNNING, SUCCESS, FAILURE }

# Parent node (set by parent when adding child)
var parent: BehaviorNode = null

# Children nodes
var children: Array[BehaviorNode] = []

# Blackboard for shared data (passed from root)
var blackboard: Dictionary = {}

# Decorator data
var decorator_data: Dictionary = {}


## Execute this node - override in subclasses
func execute(delta: float, blackboard: Dictionary) -> State:
	_blackboard = blackboard
	return _execute(delta)


## Internal execute - override in subclasses
func _execute(delta: float) -> State:
	return State.SUCCESS


## Add a child node
func add_child(child: BehaviorNode) -> BehaviorNode:
	children.append(child)
	child.parent = self
	return child


## Remove a child node
func remove_child(child: BehaviorNode) -> void:
	var idx: int = children.find(child)
	if idx >= 0:
		children.remove_at(idx)
		child.parent = null


## Get node name for debugging
func get_name() -> String:
	return get_class()


## Called when node starts executing
func on_start() -> void:
	pass


## Called when node finishes (success or failure)
func on_finish(state: State) -> void:
	pass


## Reset node state (called when tree restarts)
func reset() -> void:
	for child in children:
		child.reset()


# ==================== COMPOSITE NODES ====================

class Sequence extends BehaviorNode:
	## Execute children in order. Fail if any child fails.
	var _current_index: int = 0
	
	func _execute(delta: float) -> State:
		while _current_index < children.size():
			var child: BehaviorNode = children[_current_index]
			var state: State = child.execute(delta, _blackboard)
			
			if state == State.RUNNING:
				return State.RUNNING
			elif state == State.FAILURE:
				child.on_finish(state)
				return State.FAILURE
			
			# Success, move to next child
			child.on_finish(state)
			_current_index += 1
		
		# All children succeeded
		return State.SUCCESS
	
	func reset() -> void:
		_current_index = 0
		super.reset()


class Selector extends BehaviorNode:
	## Execute children in order. Succeed if any child succeeds.
	var _current_index: int = 0
	
	func _execute(delta: float) -> State:
		while _current_index < children.size():
			var child: BehaviorNode = children[_current_index]
			var state: State = child.execute(delta, _blackboard)
			
			if state == State.RUNNING:
				return State.RUNNING
			elif state == State.SUCCESS:
				child.on_finish(state)
				return State.SUCCESS
			
			# Failure, try next child
			child.on_finish(state)
			_current_index += 1
		
		# All children failed
		return State.FAILURE
	
	func reset() -> void:
		_current_index = 0
		super.reset()


class Parallel extends BehaviorNode:
	## Execute all children simultaneously. Configurable success/failure policy.
	var success_threshold: int = 1  # Children needed to succeed
	var failure_threshold: int = -1  # Children needed to fail (-1 = all must fail)
	var _running_children: Array[BehaviorNode] = []
	
	func _execute(delta: float) -> State:
		var success_count: int = 0
		var failure_count: int = 0
		
		# Start any children that aren't running
		for child in children:
			if not _running_children.has(child):
				child.on_start()
				_running_children.append(child)
		
		# Update all running children
		for i in range(_running_children.size() - 1, -1, -1):
			var child: BehaviorNode = _running_children[i]
			var state: State = child.execute(delta, _blackboard)
			
			if state == State.SUCCESS:
				success_count += 1
				_running_children.remove_at(i)
				child.on_finish(state)
			elif state == State.FAILURE:
				failure_count += 1
				_running_children.remove_at(i)
				child.on_finish(state)
		
		# Check thresholds
		if success_count >= success_threshold:
			return State.SUCCESS
		elif failure_threshold >= 0 and failure_count >= failure_threshold:
			return State.FAILURE
		
		return State.RUNNING
	
	func reset() -> void:
		_running_children.clear()
		super.reset()


# ==================== DECORATOR NODES ====================

class Decorator extends BehaviorNode:
	## Base decorator - wraps single child
	func add_child(child: BehaviorNode) -> BehaviorNode:
		if children.size() >= 1:
			push_warning("Decorator can only have one child")
			return children[0]
		return super.add_child(child)


class Inverter extends Decorator:
	## Invert success/failure
	func _execute(delta: float) -> State:
		if children.is_empty():
			return State.FAILURE
		
		var state: State = children[0].execute(delta, _blackboard)
		
		if state == State.SUCCESS:
			return State.FAILURE
		elif state == State.FAILURE:
			return State.SUCCESS
		
		return State.RUNNING


class Repeat extends Decorator:
	## Repeat child execution N times (or forever if -1)
	var repeat_count: int = -1  # -1 = infinite
	var _current_count: int = 0
	
	func _execute(delta: float) -> State:
		if children.is_empty():
			return State.FAILURE
		
		var child: BehaviorNode = children[0]
		var state: State = child.execute(delta, _blackboard)
		
		if state == State.SUCCESS:
			_current_count += 1
			
			if repeat_count >= 0 and _current_count >= repeat_count:
				return State.SUCCESS
			else:
				child.reset()
				return State.RUNNING
		elif state == State.FAILURE:
			return State.FAILURE
		
		return State.RUNNING
	
	func reset() -> void:
		_current_count = 0
		super.reset()


class Retry extends Decorator:
	## Retry child on failure, up to N times
	var max_retries: int = 3
	var _current_retry: int = 0
	
	func _execute(delta: float) -> State:
		if children.is_empty():
			return State.FAILURE
		
		var child: BehaviorNode = children[0]
		var state: State = child.execute(delta, _blackboard)
		
		if state == State.FAILURE:
			_current_retry += 1
			
			if _current_retry >= max_retries:
				return State.FAILURE
			else:
				child.reset()
				return State.RUNNING
		
		return state
	
	func reset() -> void:
		_current_retry = 0
		super.reset()


class Cooldown extends Decorator:
	## Only execute child every N seconds
	var cooldown_time: float = 5.0
	var _last_execute_time: float = -9999.0
	var _cached_state: State = State.SUCCESS
	
	func _execute(delta: float) -> State:
		if children.is_empty():
			return State.FAILURE
		
		var current_time: float = Time.get_ticks_msec() / 1000.0
		
		if current_time - _last_execute_time >= cooldown_time:
			_last_execute_time = current_time
			var state: State = children[0].execute(delta, _blackboard)
			_cached_state = state
			return state
		
		return _cached_state
	
	func reset() -> void:
		_last_execute_time = -9999.0
		super.reset()


# ==================== LEAF NODES ====================

class Action extends BehaviorNode:
	## Base action node - override _action in subclasses
	func _execute(delta: float) -> State:
		return _action(delta)
	
	func _action(delta: float) -> State:
		return State.SUCCESS


class Condition extends BehaviorNode:
	## Base condition node - override _check in subclasses
	func _execute(delta: float) -> State:
		if _check():
			return State.SUCCESS
		else:
			return State.FAILURE
	
	func _check() -> bool:
		return true


# ==================== UTILITY ACTIONS ====================

class WaitAction extends Action:
	## Wait for specified duration
	var wait_time: float = 1.0
	var _elapsed: float = 0.0
	
	func _action(delta: float) -> State:
		_elapsed += delta
		
		if _elapsed >= wait_time:
			_elapsed = 0.0
			return State.SUCCESS
		
		return State.RUNNING
	
	func reset() -> void:
		_elapsed = 0.0
		super.reset()


class LogAction extends Action:
	## Log message for debugging
	var message: String = ""
	var level: String = "info"  # info, warning, error
	
	func _action(delta: float) -> State:
		match level:
			"warning":
				push_warning("[BehaviorTree] %s" % message)
			"error":
				push_error("[BehaviorTree] %s" % message)
			_:
				print("[BehaviorTree] %s" % message)
		
		return State.SUCCESS


class SetBlackboardAction extends Action:
	## Set a value in the blackboard
	var key: String = ""
	var value: Variant = null
	
	func _action(delta: float) -> State:
		_blackboard[key] = value
		return State.SUCCESS


class GetBlackboardAction extends Action:
	## Get a value from the blackboard (stores in output_key)
	var key: String = ""
	var output_key: String = ""
	var default_value: Variant = null
	
	func _action(delta: float) -> State:
		_blackboard[output_key] = _blackboard.get(key, default_value)
		return State.SUCCESS
