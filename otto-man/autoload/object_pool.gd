extends Node

# Dictionary to store pools of different object types
var pools: Dictionary = {}
var active_objects: Dictionary = {}
var pool_container: Node  # Add pool_container as class variable

# Maximum number of instances per object type
const MAX_POOL_SIZE = {
	"flying_enemy": 50,
	"summoner_enemy": 10,
	"heavy_enemy": 10,  # Add size for heavy enemy
	"chunk": 5,
	"effect": 30
}

func _ready() -> void:
	# Create a node to hold all pooled objects
	pool_container = Node.new()
	pool_container.name = "PoolContainer"
	add_child(pool_container)
	
	# Initialize pools
	pools = {
		"flying_enemy": [],
		"summoner_enemy": [],
		"heavy_enemy": [],
		"effect": []
	}
	
	active_objects = {
		"flying_enemy": [],
		"summoner_enemy": [],
		"heavy_enemy": [],
		"effect": []
	}
	
	# Pre-instantiate objects
	var flying_enemy_scene = load("res://enemy/flying/flying_enemy.tscn")
	var summoner_enemy_scene = load("res://enemy/summoner/summoner_enemy.tscn")
	var heavy_enemy_scene = load("res://enemy/heavy/heavy_enemy.tscn")
	
	# Initialize pools with scenes (removed the size parameter as it's in MAX_POOL_SIZE)
	_initialize_pool("flying_enemy", flying_enemy_scene)
	_initialize_pool("summoner_enemy", summoner_enemy_scene)
	_initialize_pool("heavy_enemy", heavy_enemy_scene)

func _initialize_pool(pool_name: String, scene: PackedScene) -> void:
	if not scene:
		push_error("[ObjectPool] Scene is null for pool: " + pool_name)
		return
		
	pools[pool_name] = []
	var max_size = MAX_POOL_SIZE.get(pool_name, 10)
	
	# Create a Node to hold pooled objects
	var pool_container = Node.new()
	pool_container.name = pool_name + "_pool"
	add_child(pool_container)
	
	# Pre-instantiate objects
	var instances = []
	for i in range(max_size):
		var instance = scene.instantiate()
		if instance:
			# Add to scene tree first so _ready() can be called
			pool_container.add_child(instance)
			instances.append(instance)
			pools[pool_name].append(instance)
		else:
			push_error("[ObjectPool] Failed to instantiate instance for " + pool_name)
	
	# Wait for frames to ensure all _ready() functions are called and @onready vars are initialized
	# This is critical for child nodes like Hurtbox and StateMachine to be found
	# We need to wait 2 frames because _ready() uses call_deferred("_initialize_components")
	if instances.size() > 0:
		await get_tree().process_frame  # First frame: _ready() is called
		await get_tree().process_frame  # Second frame: call_deferred functions execute
		# Now disable processing for all instances
		for instance in instances:
			instance.process_mode = Node.PROCESS_MODE_DISABLED
			instance.hide()
	

func get_object(pool_name: String) -> Node:
	if not pools.has(pool_name):
		push_error("[ObjectPool] Pool not found: " + pool_name)
		return null
		
	# Find an inactive object in the pool
	for obj in pools[pool_name]:
		if is_instance_valid(obj) and not obj.visible:
			obj.process_mode = Node.PROCESS_MODE_INHERIT
			obj.show()
			active_objects[pool_name].append(obj)
			return obj
			
	return null

func return_object(obj: Node, pool_name: String) -> void:
	if not pools.has(pool_name):
		push_error("[ObjectPool] Pool not found: " + pool_name)
		return
		
	if not is_instance_valid(obj):
		push_error("[ObjectPool] Attempted to return invalid object to pool: " + pool_name)
		return
		
	if obj in pools[pool_name]:
		# Remove from active objects list
		active_objects[pool_name].erase(obj)
		
		# Reset the object
		if obj.has_method("reset"):
			obj.reset()
			
		# Return to original parent
		var pool_container = get_node(pool_name + "_pool")
		if obj.get_parent() != pool_container:
			obj.get_parent().remove_child(obj)
			pool_container.add_child(obj)
			
		obj.process_mode = Node.PROCESS_MODE_DISABLED
		obj.hide()
	else:
		push_error("[ObjectPool] Object not found in pool: " + pool_name) 
