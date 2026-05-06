## Core Interfaces for HeelKawn
##
## Interfaces define contracts that classes must implement.
## This enables loose coupling and clean architecture.
##
## Usage:
##   func _ready() -> void:
##       # Check if object implements interface
##       if my_object.has_method("interact"):
##           my_object.interact(player)

# ==================== I_INTERACTABLE ====================
## Objects that can be interacted with (doors, chests, NPCs, etc.)
##
## Interface Methods:
##   interact(interactor: Node) -> void
##   can_interact(interactor: Node) -> bool
##   get_interaction_prompt() -> String

const I_INTERACTABLE_METHODS: Array[String] = [
	"interact",
	"can_interact",
	"get_interaction_prompt"
]


static func is_interactable(obj: Object) -> bool:
	if obj == null:
		return false
	
	for method in I_INTERACTABLE_METHODS:
		if not obj.has_method(method):
			return false
	
	return true


static func interact(obj: Object, interactor: Node) -> void:
	if is_interactable(obj):
		obj.interact(interactor)


static func can_interact(obj: Object, interactor: Node) -> bool:
	if is_interactable(obj):
		return obj.can_interact(interactor)
	return false


static func get_interaction_prompt(obj: Object) -> String:
	if is_interactable(obj):
		return obj.get_interaction_prompt()
	return ""


# ==================== I_DAMAGEABLE ====================
## Objects that can take damage (pawns, buildings, etc.)
##
## Interface Methods:
##   take_damage(amount: float, source: Node, damage_type: String) -> void
##   heal(amount: float) -> void
##   get_health() -> float
##   get_max_health() -> float
##   is_alive() -> bool
##   die() -> void

const I_DAMAGEABLE_METHODS: Array[String] = [
	"take_damage",
	"heal",
	"get_health",
	"get_max_health",
	"is_alive",
	"die"
]


static func is_damageable(obj: Object) -> bool:
	if obj == null:
		return false
	
	for method in I_DAMAGEABLE_METHODS:
		if not obj.has_method(method):
			return false
	
	return true


static func take_damage(obj: Object, amount: float, source: Node = null, damage_type: String = "normal") -> void:
	if is_damageable(obj):
		obj.take_damage(amount, source, damage_type)


static func heal(obj: Object, amount: float) -> void:
	if is_damageable(obj):
		obj.heal(amount)


static func get_health(obj: Object) -> float:
	if is_damageable(obj):
		return obj.get_health()
	return 0.0


static func get_max_health(obj: Object) -> float:
	if is_damageable(obj):
		return obj.get_max_health()
	return 100.0


static func is_alive(obj: Object) -> bool:
	if is_damageable(obj):
		return obj.is_alive()
	return false


static func die(obj: Object) -> void:
	if is_damageable(obj):
		obj.die()


# ==================== I_CARRYABLE ====================
## Objects that can be picked up and carried (items, resources, etc.)
##
## Interface Methods:
##   pick_up(carrier: Node) -> bool
##   drop() -> void
##   get_item_type() -> int
##   get_item_quantity() -> int
##   get_item_weight() -> float

const I_CARRYABLE_METHODS: Array[String] = [
	"pick_up",
	"drop",
	"get_item_type",
	"get_item_quantity",
	"get_item_weight"
]


static func is_carryable(obj: Object) -> bool:
	if obj == null:
		return false
	
	for method in I_CARRYABLE_METHODS:
		if not obj.has_method(method):
			return false
	
	return true


static func pick_up(obj: Object, carrier: Node) -> bool:
	if is_carryable(obj):
		return obj.pick_up(carrier)
	return false


static func drop(obj: Object) -> void:
	if is_carryable(obj):
		obj.drop()


static func get_item_type(obj: Object) -> int:
	if is_carryable(obj):
		return obj.get_item_type()
	return -1


static func get_item_quantity(obj: Object) -> int:
	if is_carryable(obj):
		return obj.get_item_quantity()
	return 0


static func get_item_weight(obj: Object) -> float:
	if is_carryable(obj):
		return obj.get_item_weight()
	return 0.0


# ==================== I_WORKER ====================
## Objects that can perform work (pawns, automated machines, etc.)
##
## Interface Methods:
##   start_work(job: Node) -> bool
##   stop_work() -> void
##   is_working() -> bool
##   get_current_job() -> Node
##   get_work_progress() -> float
##   get_work_speed() -> float

const I_WORKER_METHODS: Array[String] = [
	"start_work",
	"stop_work",
	"is_working",
	"get_current_job",
	"get_work_progress",
	"get_work_speed"
]


static func is_worker(obj: Object) -> bool:
	if obj == null:
		return false
	
	for method in I_WORKER_METHODS:
		if not obj.has_method(method):
			return false
	
	return true


static func start_work(obj: Object, job: Node) -> bool:
	if is_worker(obj):
		return obj.start_work(job)
	return false


static func stop_work(obj: Object) -> void:
	if is_worker(obj):
		obj.stop_work()


static func is_working(obj: Object) -> bool:
	if is_worker(obj):
		return obj.is_working()
	return false


static func get_current_job(obj: Object) -> Node:
	if is_worker(obj):
		return obj.get_current_job()
	return null


static func get_work_progress(obj: Object) -> float:
	if is_worker(obj):
		return obj.get_work_progress()
	return 0.0


static func get_work_speed(obj: Object) -> float:
	if is_worker(obj):
		return obj.get_work_speed()
	return 1.0


# ==================== I_PATHFINDER ====================
## Objects that can navigate the world (pawns, enemies, etc.)
##
## Interface Methods:
##   move_to(target: Vector2) -> bool
##   stop_moving() -> void
##   is_moving() -> bool
##   get_position() -> Vector2
##   get_speed() -> float
##   set_speed(speed: float) -> void

const I_PATHFINDER_METHODS: Array[String] = [
	"move_to",
	"stop_moving",
	"is_moving",
	"get_position",
	"get_speed",
	"set_speed"
]


static func is_pathfinder(obj: Object) -> bool:
	if obj == null:
		return false
	
	for method in I_PATHFINDER_METHODS:
		if not obj.has_method(method):
			return false
	
	return true


static func move_to(obj: Object, target: Vector2) -> bool:
	if is_pathfinder(obj):
		return obj.move_to(target)
	return false


static func stop_moving(obj: Object) -> void:
	if is_pathfinder(obj):
		obj.stop_moving()


static func is_moving(obj: Object) -> bool:
	if is_pathfinder(obj):
		return obj.is_moving()
	return false


static func get_position(obj: Object) -> Vector2:
	if is_pathfinder(obj):
		return obj.get_position()
	return Vector2.ZERO


static func get_speed(obj: Object) -> float:
	if is_pathfinder(obj):
		return obj.get_speed()
	return 0.0


static func set_speed(obj: Object, speed: float) -> void:
	if is_pathfinder(obj):
		obj.set_speed(speed)


# ==================== INTERFACE REGISTRY ====================
## Register custom interfaces at runtime

var custom_interfaces: Dictionary = {}


func register_interface(interface_name: String, required_methods: Array[String]) -> void:
	custom_interfaces[interface_name] = required_methods


func implements_interface(obj: Object, interface_name: String) -> bool:
	if not custom_interfaces.has(interface_name):
		return false
	
	var required_methods: Array[String] = custom_interfaces[interface_name]
	
	for method in required_methods:
		if not obj.has_method(method):
			return false
	
	return true


# ==================== UTILITY FUNCTIONS ====================

## Find all objects of a type in a scene tree
static func find_all_of_type(root: Node, interface_type: String) -> Array:
	var results: Array = []
	
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		
		if interface_type == "I_INTERACTABLE" and is_interactable(node):
			results.append(node)
		elif interface_type == "I_DAMAGEABLE" and is_damageable(node):
			results.append(node)
		elif interface_type == "I_CARRYABLE" and is_carryable(node):
			results.append(node)
		elif interface_type == "I_WORKER" and is_worker(node):
			results.append(node)
		elif interface_type == "I_PATHFINDER" and is_pathfinder(node):
			results.append(node)
		
		for child in node.get_children():
			queue.append(child)
	
	return results


## Get nearest object of a type
static func find_nearest(position: Vector2, root: Node, interface_type: String, max_distance: float = 100.0) -> Object:
	var objects: Array = find_all_of_type(root, interface_type)
	
	var nearest: Object = null
	var nearest_dist: float = max_distance
	
	for obj in objects:
		if obj is Node2D:
			var dist: float = position.distance_to(obj.global_position)
			if dist < nearest_dist:
				nearest = obj
				nearest_dist = dist
	
	return nearest


## Get all objects in radius
static func find_in_radius(position: Vector2, root: Node, interface_type: String, radius: float) -> Array:
	var objects: Array = find_all_of_type(root, interface_type)
	var in_radius: Array = []
	
	for obj in objects:
		if obj is Node2D:
			var dist: float = position.distance_to(obj.global_position)
			if dist <= radius:
				in_radius.append(obj)
	
	return in_radius
