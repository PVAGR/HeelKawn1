extends Node
## ObjectPoolSystem - Generic object pooling for performance optimization
##
## Prevents garbage collection stutter by reusing objects instead of
## destroying/recreating them. Use for: projectiles, particles, effects,
## temporary UI elements, pawns, enemies, etc.
##
## Usage:
##   ObjectPoolSystem.get_pool("Enemy").get_object()  # Get pooled object
##   ObjectPoolSystem.get_pool("Enemy").return_object(enemy)  # Return when done

# Pool data structure
class PoolData:
	var available: Array[Node] = []
	var in_use: Array[Node] = []
	var scene: PackedScene
	var parent: Node
	var max_size: int = 100
	
	func _init(p_scene: PackedScene, p_parent: Node, p_max_size: int = 100) -> void:
		scene = p_scene
		parent = p_parent
		max_size = p_max_size
	
	## Get an object from the pool (or create new if empty)
	func get_object() -> Node:
		var obj: Node
		
		if available.size() > 0:
			obj = available.pop_back()
		else:
			# Create new instance
			obj = scene.instantiate()
			parent.add_child(obj)
		
		obj.set_process(true)
		obj.set_physics_process(true)
		obj.visible = true
		in_use.append(obj)
		
		return obj
	
	## Return an object to the pool
	func return_object(obj: Node) -> void:
		if not in_use.has(obj):
			return  # Already returned
		
		in_use.erase(obj)
		
		if available.size() < max_size:
			obj.set_process(false)
			obj.set_physics_process(false)
			obj.visible = false
			available.append(obj)
		else:
			# Pool is full, destroy the object
			obj.queue_free()
	
	## Return all objects to the pool
	func return_all() -> void:
		for obj in in_use.duplicate():
			return_object(obj)
	
	## Get statistics
	func get_stats() -> Dictionary:
		return {
			"available": available.size(),
			"in_use": in_use.size(),
			"total": available.size() + in_use.size(),
			"max": max_size
		}

# Registered pools
var pools: Dictionary = {}

# Performance tracking
var stats: Dictionary = {
	"total_pools": 0,
	"total_objects": 0,
	"objects_created": 0,
	"objects_reused": 0
}


func _ready() -> void:
	# Auto-register common pools
	_register_default_pools()


func _register_default_pools() -> void:
	# These will be registered when their scenes are loaded
	# Call register_pool() manually for each type
	pass


## Register a new object pool
func register_pool(pool_name: String, scene: PackedScene, parent: Node = null, max_size: int = 100) -> void:
	if pools.has(pool_name):
		push_warning("ObjectPool: Pool '%s' already registered" % pool_name)
		return
	
	if parent == null:
		parent = self
	
	pools[pool_name] = ObjectPool.new(scene, parent, max_size)
	stats.total_pools += 1
	
	if OS.is_debug_build():
		print("[ObjectPool] Registered pool: %s (max: %d)" % [pool_name, max_size])


## Get a pool by name (creates if doesn't exist)
func get_pool(pool_name: String) -> ObjectPool:
	if not pools.has(pool_name):
		push_error("ObjectPool: Pool '%s' not registered! Call register_pool() first." % pool_name)
		return null
	
	return pools[pool_name]


## Get an object from a pool
func get_object(pool_name: String) -> Node:
	var pool = get_pool(pool_name)
	if pool == null:
		return null

	var obj: Node = pool.get_object()

	# Track stats
	if obj in pool.available:
		stats.objects_reused += 1
	else:
		stats.objects_created += 1

	stats.total_objects = _count_total_objects()

	return obj


## Return an object to its pool
func return_object(pool_name: String, obj: Node) -> void:
	var pool = get_pool(pool_name)
	if pool == null:
		return

	pool.return_object(obj)


## Return all objects to their pools
func return_all(pool_name: String) -> void:
	var pool = get_pool(pool_name)
	if pool == null:
		return

	pool.return_all()


## Clear all pools (free all objects)
func clear_all() -> void:
	for pool_name_iter in pools:
		var pool = pools[pool_name_iter]
		for obj in pool.available:
			obj.queue_free()
		for obj in pool.in_use:
			obj.queue_free()
		pool.available.clear()
		pool.in_use.clear()

	pools.clear()
	stats = {
		"total_pools": 0,
		"total_objects": 0,
		"objects_created": 0,
		"objects_reused": 0
	}


func _count_total_objects() -> int:
	var total: int = 0
	for pool_name in pools:
		var pool: ObjectPool = pools[pool_name]
		total += pool.available.size() + pool.in_use.size()
	return total


## Get global statistics
func get_stats() -> Dictionary:
	var pool_stats: Dictionary = {}
	for pool_name in pools:
		pool_stats[pool_name] = pools[pool_name].get_stats()
	
	return {
		"global": stats.duplicate(),
		"pools": pool_stats
	}


## Debug: Print all pool statistics
func debug_print_stats() -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== OBJECT POOL STATISTICS ===")
	var global_stats: Dictionary = get_stats()
	print("Total Pools: %d" % global_stats.global.total_pools)
	print("Total Objects: %d" % global_stats.global.total_objects)
	print("Objects Created: %d" % global_stats.global.objects_created)
	print("Objects Reused: %d" % global_stats.global.objects_reused)
	
	if global_stats.global.total_objects > 0:
		var reuse_rate: float = float(global_stats.global.objects_reused) / float(global_stats.global.objects_created + global_stats.global.objects_reused) * 100.0
		print("Reuse Rate: %.1f%%" % reuse_rate)
	
	print("\nPer-Pool Breakdown:")
	for pool_name in global_stats.pools:
		var ps: Dictionary = global_stats.pools[pool_name]
		print("  %s: %d/%d in use (%.1f%%)" % [
			pool_name,
			ps.in_use,
			ps.total,
			float(ps.in_use) / float(ps.total) * 100.0 if ps.total > 0 else 0.0
		])
	print("=== END STATISTICS ===\n")
