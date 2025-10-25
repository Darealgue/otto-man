extends Node

# Projectile Pool System - Performance optimization for enemy projectiles
# Prevents lag when multiple enemies fire projectiles simultaneously

# Pool storage
var _pools: Dictionary = {}
var _active_projectiles: Dictionary = {}

# Pool configuration
const DEFAULT_POOL_SIZE = 10
const MAX_POOL_SIZE = 50

func _ready() -> void:
	print("[ProjectilePool] Initialized")

# Get a projectile from pool or create new one
func get_projectile(projectile_scene: PackedScene, pool_name: String = "") -> Node:
	if pool_name.is_empty():
		pool_name = projectile_scene.resource_path.get_file().get_basename()
	
	# Initialize pool if it doesn't exist
	if not _pools.has(pool_name):
		_initialize_pool(projectile_scene, pool_name)
	
	# Get projectile from pool
	var projectile: Node = null
	if _pools[pool_name].size() > 0:
		projectile = _pools[pool_name].pop_back()
		print("[ProjectilePool] Retrieved %s from pool (remaining: %d)" % [pool_name, _pools[pool_name].size()])
	else:
		# Pool is empty, create new projectile
		projectile = projectile_scene.instantiate()
		print("[ProjectilePool] Created new %s (pool empty)" % pool_name)
	
	# Track active projectile
	if not _active_projectiles.has(pool_name):
		_active_projectiles[pool_name] = []
	_active_projectiles[pool_name].append(projectile)
	
	return projectile

# Return projectile to pool
func return_projectile(projectile: Node, pool_name: String = "") -> void:
	if not is_instance_valid(projectile):
		return
	
	# Determine pool name if not provided
	if pool_name.is_empty():
		# Try to get from projectile's scene file path
		if projectile.has_method("get_scene_file_path"):
			pool_name = projectile.get_scene_file_path().get_file().get_basename()
		else:
			# Fallback to projectile name
			pool_name = projectile.name.get_basename()
	
	# Remove from active list
	if _active_projectiles.has(pool_name):
		_active_projectiles[pool_name].erase(projectile)
	
	# Reset projectile state
	_reset_projectile(projectile)
	
	# Return to pool if not at max capacity
	if _pools.has(pool_name) and _pools[pool_name].size() < MAX_POOL_SIZE:
		_pools[pool_name].append(projectile)
		print("[ProjectilePool] Returned %s to pool (pool size: %d)" % [pool_name, _pools[pool_name].size()])
	else:
		# Pool is full, free the projectile
		projectile.queue_free()
		print("[ProjectilePool] Freed %s (pool full)" % pool_name)

# Initialize pool with default size
func _initialize_pool(projectile_scene: PackedScene, pool_name: String) -> void:
	_pools[pool_name] = []
	_active_projectiles[pool_name] = []
	
	# Pre-create projectiles
	for i in range(DEFAULT_POOL_SIZE):
		var projectile = projectile_scene.instantiate()
		_reset_projectile(projectile)
		_pools[pool_name].append(projectile)
	
	print("[ProjectilePool] Initialized pool '%s' with %d projectiles" % [pool_name, DEFAULT_POOL_SIZE])

# Reset projectile to default state
func _reset_projectile(projectile: Node) -> void:
	# Reset common properties
	projectile.visible = true
	projectile.modulate = Color.WHITE
	projectile.scale = Vector2.ONE
	projectile.rotation = 0.0
	projectile.velocity = Vector2.ZERO
	
	# Reset position to off-screen
	projectile.global_position = Vector2(-10000, -10000)
	
	# Disable collision
	if projectile.has_method("set_collision_enabled"):
		projectile.set_collision_enabled(false)
	
	# Reset any timers or state
	if projectile.has_method("reset_state"):
		projectile.reset_state()
	
	# Reset sprite animation for cannonball specifically
	if projectile.name.to_lower().contains("cannon") and projectile.has_method("get") and projectile.get("sprite"):
		var sprite = projectile.get("sprite")
		if sprite and sprite.has_method("play"):
			# Try to play the correct animation (not break animation)
			if sprite.sprite_frames:
				var anim_to_play := ""
				if sprite.sprite_frames.has_animation("cannonball"):
					anim_to_play = "cannonball"
				elif sprite.sprite_frames.has_animation("cannonball_fly"):
					anim_to_play = "cannonball_fly"
				elif sprite.sprite_frames.has_animation("default"):
					anim_to_play = "default"
				else:
					# Pick the first animation that is not a break animation
					for a in sprite.sprite_frames.get_animation_names():
						if typeof(a) == TYPE_STRING and not String(a).contains("break"):
							anim_to_play = a
							break
				if anim_to_play != "":
					sprite.frame = 0
					sprite.play(anim_to_play)
	
	# Remove from scene tree if it's in one
	if projectile.is_inside_tree():
		projectile.get_parent().remove_child(projectile)

# Get pool statistics
func get_pool_stats() -> Dictionary:
	var stats = {}
	for pool_name in _pools.keys():
		stats[pool_name] = {
			"pool_size": _pools[pool_name].size(),
			"active_count": _active_projectiles[pool_name].size() if _active_projectiles.has(pool_name) else 0
		}
	return stats

# Clear all pools (for cleanup)
func clear_all_pools() -> void:
	for pool_name in _pools.keys():
		# Free all pooled projectiles
		for projectile in _pools[pool_name]:
			if is_instance_valid(projectile):
				projectile.queue_free()
		_pools[pool_name].clear()
		
		# Free all active projectiles
		if _active_projectiles.has(pool_name):
			for projectile in _active_projectiles[pool_name]:
				if is_instance_valid(projectile):
					projectile.queue_free()
			_active_projectiles[pool_name].clear()
	
	print("[ProjectilePool] Cleared all pools")
