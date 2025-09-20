class_name TurtleEnemy
extends BaseEnemy

# Turtle-specific behavior
var patrol_direction: int = 1
var wall_detection_distance: float = 20.0
var platform_detection_distance: float = 50.0  # Increased from 30.0

func _ready() -> void:
	super._ready()
	
	# Reset animation to start from beginning
	if sprite:
		sprite.frame = 0
		sprite.frame_progress = 0.0
	
	# Start with patrol behavior
	change_behavior("patrol")

	# Enable hitbox for continuous contact damage
	if hitbox:
		hitbox.enable()
		# Set damage value
		var damage = stats.attack_damage if stats else 15.0
		hitbox.damage = damage
	
	# Add hurtbox to hurtbox group for fall attack bounce
	if hurtbox:
		hurtbox.add_to_group("hurtbox")

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"patrol":
			handle_patrol(delta)
		"chase":
			handle_chase(delta)
		"hurt":
			# Use base enemy hurt behavior
			super.handle_hurt_behavior(delta)
		"dead":
			return

func handle_patrol(delta: float) -> void:
	# Simple patrol: move in one direction until hitting wall or edge
	var movement_speed = stats.movement_speed if stats else 50.0
	
	# Check for walls and platform edges
	var should_turn = _should_turn_around()
	if should_turn:
		patrol_direction *= -1
		direction = patrol_direction
		if sprite:
			sprite.flip_h = direction < 0
	
	# Move in patrol direction
	velocity.x = patrol_direction * movement_speed
	
	# Play walk animation
	if sprite:
		if sprite.animation != "walk":
			sprite.play("walk")
			sprite.frame = 0
			sprite.frame_progress = 0.0
		else:
			# Check if animation is stuck
			if sprite.frame_progress == 0.0 and sprite.frame == 0:
				sprite.play("walk")
				sprite.frame = 0
				sprite.frame_progress = 0.0

func handle_chase(delta: float) -> void:
	# When player is detected, move towards player but still respect walls/platforms
	# First, try to get the target from BaseEnemy's detection system
	if not target:
		target = get_nearest_player_in_range()
	
	# If still no target, return to patrol
	if not target:
		change_behavior("patrol")
		return
	
	var chase_speed = stats.chase_speed if stats else 80.0
	var player_direction = sign(target.global_position.x - global_position.x)
	
	# Check for walls and platform edges even when chasing
	var should_turn = _should_turn_around()
	if should_turn:
		# If we hit a wall while chasing, return to patrol behavior
		change_behavior("patrol")
		return
	
	# Move towards player
	velocity.x = player_direction * chase_speed
	direction = player_direction
	
	# Update sprite direction
	if sprite:
		sprite.flip_h = direction < 0
	
	# Play walk animation
	if sprite and sprite.animation != "walk":
		sprite.play("walk")

func _should_turn_around() -> bool:
	# Use current direction (patrol_direction for patrol, direction for chase)
	var current_direction = patrol_direction if current_behavior == "patrol" else direction
	
	# Check for wall ahead
	var space_state = get_world_2d().direct_space_state
	var wall_query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(current_direction * wall_detection_distance, 0)
	)
	wall_query.collision_mask = 1  # World layer
	wall_query.exclude = [self]
	
	var wall_result = space_state.intersect_ray(wall_query)
	if wall_result:
		return true
	
	# Check for platform edge ahead
	var platform_query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(current_direction * 10, 0),
		global_position + Vector2(current_direction * platform_detection_distance, platform_detection_distance)
	)
	platform_query.collision_mask = 1  # World layer
	platform_query.exclude = [self]
	
	var platform_result = space_state.intersect_ray(platform_query)
	if not platform_result:
		return true  # No platform ahead, turn around
	
	return false

func _on_player_entered_range() -> void:
	# When player enters detection range, switch to chase
	change_behavior("chase")

func _on_player_exited_range() -> void:
	# When player exits detection range, return to patrol
	change_behavior("patrol")

# Turtle uses BaseEnemy's hitbox system for touch damage
# No need to override _on_hitbox_hit

# Override die function to prevent flying away
func die() -> void:
	if current_behavior == "dead":
		return
		
	current_behavior = "dead"
	
	enemy_defeated.emit()
	
	PowerupManager.on_enemy_killed()
	
	if sprite:
		sprite.play("death")
		# Set z_index above player (player z_index = 5)
		sprite.z_index = 6
	
	# Stop horizontal movement, keep vertical so corpse falls
	velocity.x = 0
	
	# Collide only with environment so the body lands on ground
	collision_layer = CollisionLayers.NONE
	collision_mask = CollisionLayers.WORLD
	
	# Disable components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Start fade out
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	fade_out = true
	
	# Don't return to pool - let corpses persist
	# await get_tree().create_timer(2.0).timeout
	# var scene_path = scene_file_path
	# var pool_name = scene_path.get_file().get_basename()
	# object_pool.return_object(self, pool_name)

# Override _physics_process to ensure gravity is applied even when dead
func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if not is_instance_valid(self) or global_position == Vector2.ZERO:
		return
	
	# Always apply gravity (even when dead so corpse falls)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif is_on_floor():
		# Do not zero out upward knockback during hurt; allow takeoff
		if not (current_behavior == "hurt" and velocity.y < 0.0):
			velocity.y = 0
	
	# Only process behavior if not dead
	if current_behavior != "dead":
		# Handle invulnerability timer
		if invulnerable:
			invulnerability_timer -= delta
			if invulnerability_timer <= 0:
				invulnerable = false
				# Make sure hurtbox is re-enabled
				if hurtbox:
					hurtbox.monitoring = true
					hurtbox.monitorable = true
		
		# Handle behavior and movement
		_handle_child_behavior(delta)
	
	# Apply movement
	move_and_slide()
