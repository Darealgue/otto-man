class_name BasicEnemy
extends "res://enemy/base_enemy.gd"

# Basic enemy - simple AI, low HP, optimized for juggling/combos
# Designed to be spawned in large numbers in dungeons

# Patrol properties
var patrol_point_left: float
var patrol_point_right: float
var patrol_range: float = 150.0  # How far to patrol from spawn point

# Behavior timers
var patrol_wait_time: float = 1.0  # Wait time at patrol points
var chase_speed_multiplier: float = 1.8  # Chase significantly faster than patrol

# Attack properties
var attack_range: float = 40.0  # Distance to start attack
var attack_cooldown_timer: float = 0.0
var attack_cooldown: float = 1.5  # Time between attacks
var is_attacking: bool = false

# Air juggle optimization
@export var extended_air_float: bool = true  # Extended air float for combos
@export var air_float_duration_override: float = 0.5  # Longer float window
@export var air_float_gravity_override: float = 0.25  # Slower fall during juggle

# Store original collision layer for dynamic adjustment
var _original_collision_layer: int = 4

# Track previous frame's floor state to detect ground impact
var _was_in_air: bool = false
var _previous_velocity_y: float = 0.0  # Track velocity before landing to calculate bounce

# Bounce system for hurt enemies
var _bounce_count: int = 0  # How many times enemy has bounced
var _max_bounces: int = 1  # Maximum bounces (calculated based on fall velocity)
const MIN_BOUNCE_VELOCITY: float = 250.0  # Minimum fall velocity to trigger bounce
const HIGH_FALL_VELOCITY: float = 500.0  # Velocity threshold for 2 bounces
const BOUNCE_FORCE_MULTIPLIER: float = 0.5  # How much velocity is converted to upward bounce
var _is_bouncing: bool = false  # Track if currently bouncing
var _just_bounced: bool = false  # Prevent multiple bounces in same landing frame
var _bounce_cooldown: float = 0.0  # Cooldown to prevent rapid bounce loops
const BOUNCE_COOLDOWN_DURATION: float = 0.1  # Minimum time between bounces

# Direction change throttle to prevent flip-flopping
var _direction_change_cooldown_timer: float = 0.0
const DIRECTION_CHANGE_COOLDOWN: float = 0.2  # Minimum time between direction changes
var _last_direction: int = 1  # Track last direction

# Wall hit detection debounce to prevent animation flickering
var _wall_hit_timer: float = 0.0
const WALL_HIT_DURATION: float = 0.5  # How long to stay in "wall hit" state
var _is_wall_hit: bool = false  # Track if we're currently in wall hit state
var _backing_off_timer: float = 0.0  # Timer for backing off from wall
const BACK_OFF_DURATION: float = 0.2  # How long to back off from wall after turning

# Spawn state tracking
var _should_transition_to_patrol: bool = false  # Flag to transition to patrol after landing

func _ready() -> void:
	super._ready()
	# Initialize bounce variables
	_bounce_count = 0
	_max_bounces = 1
	_is_bouncing = false
	_just_bounced = false
	_bounce_cooldown = 0.0
	# Initialize wall hit variables
	_backing_off_timer = 0.0
	
	# CRITICAL: Force floor detection on spawn - ensure we're on floor before initializing
	# This prevents fall animation from playing when spawning in air (level 2+ issue)
	if not is_on_floor():
		# Try to detect floor below us
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * 500.0)
		query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
		var result = space_state.intersect_ray(query)
		
		if result:
			# Place on floor
			global_position = result.position - Vector2(0, 32)
			# Force physics update
			move_and_slide()
	
	# Initialize floor tracking AFTER ensuring we're on floor
	_was_in_air = not is_on_floor()
	
	# Initialize direction tracking
	_last_direction = direction
	_direction_change_cooldown_timer = 0.0
	
	# Initialize wall hit tracking
	_is_wall_hit = false
	_wall_hit_timer = 0.0
	
	# IMPORTANT: Ensure hurtbox signal connects to our override (not base class)
	# In Godot, virtual functions are automatically overridden, but we need to ensure
	# the signal connection uses our version. BaseEnemy connects in its _ready,
	# so we reconnect after super._ready() to ensure our override is used.
	if hurtbox and hurtbox.has_signal("hurt"):
		# Disconnect any existing connections
		if hurtbox.hurt.get_connections().size() > 0:
			for connection in hurtbox.hurt.get_connections():
				hurtbox.hurt.disconnect(connection.callable)
		# Connect to our override function
		if not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.connect(_on_hurtbox_hurt)
	
	# Override air float settings for better juggling
	if extended_air_float:
		air_float_duration = air_float_duration_override
		air_float_gravity_scale = air_float_gravity_override
	
	# CRITICAL: Connect to animation signals to prevent fall animation from playing
	# when hurt animations finish or change
	if sprite:
		if sprite.has_signal("animation_finished"):
			if not sprite.animation_finished.is_connected(_on_animation_finished):
				sprite.animation_finished.connect(_on_animation_finished)
		# Also connect to animation_changed to catch when BaseEnemy tries to play "hurt"
		if sprite.has_signal("animation_changed"):
			if not sprite.animation_changed.is_connected(_on_animation_changed):
				sprite.animation_changed.connect(_on_animation_changed)
		air_float_max_fall_speed = 200.0  # Slower max fall speed
	
	# Ensure collision mask includes WORLD and PLATFORM layers
	# collision_mask should be: WORLD (1) + PLATFORM (512) = 513
	# Make sure we collide with tiles/platforms
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	set_collision_mask_value(1, true)  # WORLD layer
	set_collision_mask_value(10, true)  # PLATFORM layer (bit 10)
	
	# Store original collision layer for dynamic adjustment
	_original_collision_layer = collision_layer
	
	# Set up patrol points around spawn position
	var initial_pos = global_position
	if initial_pos != Vector2.ZERO:
		patrol_point_left = initial_pos.x - patrol_range
		patrol_point_right = initial_pos.x + patrol_range
	
	# CRITICAL: Ensure we're on floor before setting behavior
	# Wait a frame for physics to settle, then check floor
	await get_tree().process_frame
	if not is_on_floor():
		# Still in air - wait for landing before setting behavior
		# This prevents fall animation from playing on spawn
		current_behavior = "idle"  # Use idle instead of patrol to prevent BaseEnemy from playing fall
		if sprite:
			sprite.play("idle")
		behavior_timer = 0.0
		# Set a flag to transition to patrol once we land
		_should_transition_to_patrol = true
	else:
		# On floor - set patrol behavior normally
		current_behavior = "patrol"
		if sprite:
			sprite.play("idle")
		behavior_timer = 0.0
		_should_transition_to_patrol = false
	
	# Basic enemy has simple collision - smaller than heavy enemy
	# Collision shape is set in scene file

func handle_behavior(delta: float) -> void:
	"""Override BaseEnemy's handle_behavior to prevent fall animation in hurt state."""
	# Skip if sleeping
	if is_sleeping:
		return
	
	# CRITICAL: If in hurt state or dead, handle it ourselves
	# Don't let BaseEnemy's handle_behavior call change_behavior("chase") which triggers fall animation
	if current_behavior == "hurt" or health <= 0:
		handle_hurt_behavior(delta)
		return
	
	# For other behaviors, use our own implementation
	_handle_child_behavior(delta)

func _handle_child_behavior(delta: float) -> void:
	if is_sleeping:
		return
	
	# IMPORTANT: Don't process patrol/chase/attack if dead or dying
	# Dead enemies should stay in hurt state until they hit ground
	if health <= 0 and current_behavior != "hurt" and current_behavior != "dead":
		# Force hurt state for dead enemies
		current_behavior = "hurt"
		behavior_timer = 0.0
		
	match current_behavior:
		"patrol":
			# Don't patrol if dead
			if health <= 0:
				return
			handle_patrol(delta)
		"idle":
			# Idle state - check if we should transition to patrol (spawn landing)
			if _should_transition_to_patrol and is_on_floor():
				_should_transition_to_patrol = false
				current_behavior = "patrol"
				if sprite:
					sprite.play("idle")
				behavior_timer = 0.0
			elif not _should_transition_to_patrol:
				# Normal idle - transition to patrol
				current_behavior = "patrol"
				if sprite:
					sprite.play("idle")
				behavior_timer = 0.0
		"chase":
			# Don't chase if dead
			if health <= 0:
				return
			handle_chase(delta)
		"attack":
			# Don't attack if dead
			if health <= 0:
				return
			handle_attack(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return

func handle_patrol(delta: float) -> void:
	# Don't patrol if dead
	if health <= 0:
		return
	
	# Check if we should transition to patrol (after landing from spawn)
	if _should_transition_to_patrol and is_on_floor():
		_should_transition_to_patrol = false
		current_behavior = "patrol"
		if sprite:
			sprite.play("idle")
		behavior_timer = 0.0
		return
	
	# If still in air and should transition, wait
	if _should_transition_to_patrol:
		return
		
	behavior_timer += delta
	
	# Update sprite direction
	update_sprite_direction()
	
	# Check for player first
	target = get_nearest_player_in_range()
	if target:
		change_behavior("chase")
		return
	
	# Only patrol if on floor
	if not is_on_floor():
		velocity.x = move_toward(velocity.x, 0, (stats.movement_speed if stats else 80.0) * delta)
		return
	
	# Determine target patrol point
	var target_x = patrol_point_right if direction > 0 else patrol_point_left
	var at_patrol_point = abs(global_position.x - target_x) < 15
	
	if at_patrol_point:
		# At patrol point, wait a bit
		velocity.x = 0
		if sprite and sprite.animation != "idle":
			sprite.play("idle")
		
		# After waiting, turn around
		if behavior_timer >= patrol_wait_time:
			direction *= -1
			if sprite:
				sprite.flip_h = direction < 0
			behavior_timer = 0.0
	else:
		# Move towards patrol point
		# Update timers
		_wall_hit_timer = max(0.0, _wall_hit_timer - delta)
		_backing_off_timer = max(0.0, _backing_off_timer - delta)
		
		# Check if we hit a wall - use debounce to prevent flickering
		var currently_on_wall = is_on_wall()
		
		# DEBUG: Wall stuck detection
		if currently_on_wall and _backing_off_timer <= 0.0 and _wall_hit_timer <= 0.0:
			print("[BasicEnemy] WALL STUCK DEBUG (patrol):")
			print("  pos: ", global_position)
			print("  direction: ", direction)
			print("  velocity.x: ", velocity.x)
			print("  is_on_wall(): ", currently_on_wall)
			print("  _is_wall_hit: ", _is_wall_hit)
			print("  _wall_hit_timer: ", _wall_hit_timer)
			print("  _backing_off_timer: ", _backing_off_timer)
			print("  behavior_timer: ", behavior_timer)
		
		# If we're backing off from wall, don't check for new wall hits
		if _backing_off_timer > 0.0:
			# Backing off - move away from wall
			var move_speed = (stats.movement_speed if stats else 80.0) * 0.7
			velocity.x = direction * move_speed
			if sprite and sprite.animation != "walk":
				sprite.play("walk")
			# Once we're no longer on wall, exit backing off state
			if not currently_on_wall:
				print("[BasicEnemy] Backing off SUCCESS - no longer on wall (patrol)")
				_backing_off_timer = 0.0
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				# Note: In patrol, direction will naturally update when we reach patrol point
		elif currently_on_wall:
			# Just hit wall - start wall hit state
			if not _is_wall_hit:
				print("[BasicEnemy] Wall hit detected (patrol) - starting wall hit state")
				_is_wall_hit = true
				_wall_hit_timer = WALL_HIT_DURATION
				behavior_timer = 0.0  # Reset behavior timer
			
			# Stay in wall hit state for the duration
			if _is_wall_hit:
				if _wall_hit_timer > 0.0:
					velocity.x = 0
					if sprite and sprite.animation != "idle":
						sprite.play("idle")
					# Turn around after wall hit duration
					if behavior_timer >= 0.3:  # Wait 0.3s before turning
						print("[BasicEnemy] Turning around (patrol) - starting back off")
						direction *= -1
						if sprite:
							sprite.flip_h = direction < 0
						behavior_timer = 0.0
						# Start backing off from wall
						_backing_off_timer = BACK_OFF_DURATION
						_is_wall_hit = false  # Exit wall hit state, enter backing off state
				else:
					# Timer expired but still on wall - force turn around
					print("[BasicEnemy] Timer expired but still on wall (patrol) - forcing turn")
					direction *= -1
					if sprite:
						sprite.flip_h = direction < 0
					behavior_timer = 0.0
					_backing_off_timer = BACK_OFF_DURATION
					_is_wall_hit = false
		else:
			# Not blocked - exit wall hit state and move normally
			_is_wall_hit = false
			_wall_hit_timer = 0.0
			_backing_off_timer = 0.0
			if sprite and sprite.animation != "walk":
				sprite.play("walk")
			var move_speed = (stats.movement_speed if stats else 80.0) * 0.7  # Slower patrol speed
			velocity.x = direction * move_speed

func handle_chase(delta: float) -> void:
	# Don't chase if dead
	if health <= 0:
		return
		
	# Update attack cooldown
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	# Get current target
	target = get_nearest_player_in_range()
	
	if not target:
		# Lost target, return to patrol
		change_behavior("patrol")
		return
	
	# Check if we're in attack range (with buffer distance for better feel)
	var distance_to_target = global_position.distance_to(target.global_position)
	var attack_range_with_buffer = attack_range + 30.0  # Add 30px buffer for better attack start
	if distance_to_target <= attack_range_with_buffer and attack_cooldown_timer <= 0.0 and is_on_floor():
		change_behavior("attack")
		return
	
	# Update direction cooldown timer
	_direction_change_cooldown_timer = max(0.0, _direction_change_cooldown_timer - delta)
	
	# Calculate direction to player (needed for both direction update and backing off)
	var dir_to_player = sign(target.global_position.x - global_position.x)
	
	# Check if we're on wall - if so, don't update direction (prevent flickering)
	var is_in_wall_hit_state = _is_wall_hit or _backing_off_timer > 0.0
	
	# Only update direction if not stuck on wall
	if not is_in_wall_hit_state:
		# Update direction towards player with throttle to prevent flip-flopping
		
		# Only change direction if:
		# 1. Player is not directly above/below (horizontal distance > threshold)
		# 2. Enough time has passed since last direction change
		# 3. Direction actually changed
		var horizontal_distance = abs(target.global_position.x - global_position.x)
		
		# If player is directly above/below (horizontal distance < 30px), don't change direction
		if horizontal_distance > 30.0 and dir_to_player != 0:
			# Check if direction actually changed and cooldown passed
			if dir_to_player != _last_direction and _direction_change_cooldown_timer <= 0.0:
				direction = dir_to_player
				_last_direction = direction
				_direction_change_cooldown_timer = DIRECTION_CHANGE_COOLDOWN  # Reset cooldown
				if sprite:
					sprite.flip_h = direction < 0
			elif dir_to_player == _last_direction:
				# Same direction, just update sprite flip (only if not already correct)
				if sprite and sprite.flip_h != (direction < 0):
					sprite.flip_h = direction < 0
	
	# Move towards player (only if on floor)
	if is_on_floor():
		# Update timers
		_wall_hit_timer = max(0.0, _wall_hit_timer - delta)
		_backing_off_timer = max(0.0, _backing_off_timer - delta)
		
		# Check if we hit a wall - use debounce to prevent flickering
		var currently_on_wall = is_on_wall()
		
		# DEBUG: Wall stuck detection
		if currently_on_wall and _backing_off_timer <= 0.0 and _wall_hit_timer <= 0.0:
			print("[BasicEnemy] WALL STUCK DEBUG (chase):")
			print("  pos: ", global_position)
			print("  direction: ", direction)
			print("  velocity.x: ", velocity.x)
			print("  is_on_wall(): ", currently_on_wall)
			print("  _is_wall_hit: ", _is_wall_hit)
			print("  _wall_hit_timer: ", _wall_hit_timer)
			print("  _backing_off_timer: ", _backing_off_timer)
			print("  behavior_timer: ", behavior_timer)
		
		# If we're backing off from wall, don't check for new wall hits
		if _backing_off_timer > 0.0:
			# Backing off - move away from wall
			var chase_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
			velocity.x = direction * chase_speed * 0.5  # Slower when backing off
			if sprite:
				if sprite.sprite_frames.has_animation("chase"):
					sprite.play("chase")
				else:
					sprite.play("walk")
			# Once we're no longer on wall, exit backing off state and update direction to player
			if not currently_on_wall:
				print("[BasicEnemy] Backing off SUCCESS - no longer on wall")
				_backing_off_timer = 0.0
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				# Reset direction cooldown and update direction to player immediately
				_direction_change_cooldown_timer = 0.0
				_last_direction = 0  # Reset to force direction update
				# Update direction to face player (use existing dir_to_player from above)
				if dir_to_player != 0:
					direction = dir_to_player
					_last_direction = direction
					if sprite:
						sprite.flip_h = direction < 0
		elif currently_on_wall:
			# Just hit wall - start wall hit state
			if not _is_wall_hit:
				print("[BasicEnemy] Wall hit detected (chase) - starting wall hit state")
				_is_wall_hit = true
				_wall_hit_timer = WALL_HIT_DURATION
				behavior_timer = 0.0  # Reset behavior timer
			
			# Stay in wall hit state for the duration
			if _is_wall_hit:
				if _wall_hit_timer > 0.0:
					velocity.x = 0
					# Keep idle animation - don't flicker between animations
					if sprite:
						if sprite.animation != "idle":
							sprite.play("idle")
						# Lock sprite direction to prevent flickering
						if sprite.flip_h != (direction < 0):
							sprite.flip_h = direction < 0
					# After wall hit duration, try to move away from wall
					if behavior_timer >= 0.5:  # Wait 0.5s then try to unstick
						print("[BasicEnemy] Turning around (chase) - starting back off")
						# Try moving away from wall
						direction *= -1
						if sprite:
							sprite.flip_h = direction < 0
						behavior_timer = 0.0
						# Start backing off from wall
						_backing_off_timer = BACK_OFF_DURATION
						_is_wall_hit = false  # Exit wall hit state, enter backing off state
				else:
					# Timer expired but still on wall - force turn around
					print("[BasicEnemy] Timer expired but still on wall (chase) - forcing turn")
					direction *= -1
					if sprite:
						sprite.flip_h = direction < 0
					behavior_timer = 0.0
					_backing_off_timer = BACK_OFF_DURATION
					_is_wall_hit = false
		else:
			# Not blocked - exit wall hit state and move normally
			_is_wall_hit = false
			_wall_hit_timer = 0.0
			_backing_off_timer = 0.0
			if sprite and sprite.animation != "chase":
				# Use chase animation if available, otherwise walk
				if sprite.sprite_frames.has_animation("chase"):
					sprite.play("chase")
				else:
					sprite.play("walk")
			
			var chase_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
			velocity.x = direction * chase_speed
	else:
		# In air, slow down horizontal movement
		# CRITICAL: Don't play fall animation here - it will be handled by hurt state if needed
		velocity.x = move_toward(velocity.x, 0, (stats.movement_speed if stats else 80.0) * delta)
		# Ensure fall animation is NOT playing when in chase state and in air
		if sprite and sprite.animation == "fall":
			sprite.stop()

func handle_attack(delta: float) -> void:
	behavior_timer += delta
	
	# CRITICAL: Don't attack if in air or hurt state - enemy can't attack while being juggled
	if not is_on_floor() or current_behavior == "hurt" or health <= 0:
		# Disable hitbox immediately if we're in air or hurt
		if hitbox:
			hitbox.disable()
		is_attacking = false
		# Return to appropriate state
		if health <= 0:
			change_behavior("hurt")
		elif not is_on_floor():
			change_behavior("hurt")
		else:
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")
		return
	
	# Apply forward momentum during attack (lunge forward)
	var attack_lunge_speed = 120.0  # Forward lunge speed
	velocity.x = direction * attack_lunge_speed
	
	# Play attack animation if available
	if sprite:
		if sprite.sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				sprite.play("attack")
				is_attacking = true
		else:
			# No attack animation, just use idle
			if sprite.animation != "idle":
				sprite.play("idle")
			is_attacking = true  # Set attacking flag even without animation
	
	# Enable hitbox during attack (only if on floor and not hurt)
	if hitbox and is_on_floor() and current_behavior != "hurt" and health > 0:
		# Position hitbox in front of enemy
		hitbox.position.x = 20 * direction  # 20 pixels in front
		hitbox.position.y = 0
		
		if sprite and sprite.sprite_frames.has_animation("attack"):
			# Attack animation exists - enable hitbox at the right frame
			var frame_count = sprite.sprite_frames.get_frame_count("attack")
			var current_frame = sprite.frame
			if current_frame >= 1 and current_frame <= frame_count - 1:
				if not hitbox.is_enabled():
					hitbox.damage = stats.attack_damage if stats else 5.0
					hitbox.knockback_force = 150.0
					hitbox.knockback_up_force = 50.0
					hitbox.enable()
			else:
				if hitbox.is_enabled():
					hitbox.disable()
		else:
			# No attack animation, enable hitbox briefly (0.1s to 0.3s)
			if behavior_timer >= 0.1 and behavior_timer <= 0.3:
				if not hitbox.is_enabled():
					hitbox.damage = stats.attack_damage if stats else 5.0
					hitbox.knockback_force = 150.0
					hitbox.knockback_up_force = 50.0
					hitbox.enable()
			elif hitbox.is_enabled() and behavior_timer > 0.3:
				hitbox.disable()
	
	# Check if attack animation finished
	if sprite and sprite.sprite_frames.has_animation("attack"):
		if not sprite.is_playing() or sprite.frame >= sprite.sprite_frames.get_frame_count("attack") - 1:
			# Attack finished
			is_attacking = false
			if hitbox:
				hitbox.disable()
			attack_cooldown_timer = attack_cooldown
			
			# Return to chase or patrol
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")
	else:
		# No attack animation, just wait a bit
		if behavior_timer >= 0.5:  # Short attack duration
			is_attacking = false
			if hitbox:
				hitbox.disable()
			attack_cooldown_timer = attack_cooldown
			
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")

func handle_hurt_behavior(delta: float) -> void:
	behavior_timer += delta
	
	# Update bounce cooldown
	_bounce_cooldown = max(0.0, _bounce_cooldown - delta)
	
	# CRITICAL: Always ensure fall animation is NOT playing when in hurt state
	# Check every frame and aggressively stop it
	if sprite:
		if sprite.animation == "fall":
			sprite.stop()
	
	# Check if we're dead but still in air - wait for ground impact
	if health <= 0 and not is_on_floor():
		# Keep playing hurt animations until we hit ground
		# Keep hurtbox enabled so player can keep hitting (punching bag)
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true
		
		# Check for wall bounce (dead enemies can bounce off walls)
		if is_on_wall():
			# Bounce off wall - reverse horizontal velocity
			var wall_bounce_force = abs(velocity.x) * 0.6  # 60% of horizontal velocity
			velocity.x = -velocity.x * 0.6  # Reverse and reduce
			# Small upward component for visual interest
			if velocity.y > -50.0:  # Only if not already rising fast
				velocity.y = min(velocity.y, -100.0)  # Small upward boost
		
		if not is_on_floor():
			# CRITICAL: Stop fall animation immediately if it's playing
			if sprite and sprite.animation == "fall":
				sprite.stop()
			# In air - check if rising or falling
			# Use a smaller threshold to detect falling more accurately
			# IMPORTANT: Always play hurt animations when dead in air, never fall animation
			if velocity.y < -10.0:
				# Rising - play hurt_rise
				if sprite and sprite.sprite_frames.has_animation("hurt_rise"):
					# Force hurt_rise animation - don't let fall animation override
					if sprite.animation != "hurt_rise":
						sprite.play("hurt_rise")
			else:
				# Falling (or very slow upward) - play hurt_fall
				if sprite and sprite.sprite_frames.has_animation("hurt_fall"):
					# Force hurt_fall animation - don't let fall animation override
					if sprite.animation != "hurt_fall":
						sprite.play("hurt_fall")
		
		# Apply gravity and wait for ground impact
		# Don't exit hurt state until we hit ground
		# Don't apply horizontal damping when dead in air - let player juggle freely
		_was_in_air = true  # Track that we were in air
		return
	
	# Check if we just hit ground (was in air, now on ground)
	# IMPORTANT: Only check bounce if we weren't just bouncing and cooldown expired
	if _was_in_air and is_on_floor() and not _just_bounced and _bounce_cooldown <= 0.0:
		# Just landed - check fall velocity for bounce
		var fall_velocity = abs(_previous_velocity_y)
		
		# Determine max bounces based on fall velocity
		if fall_velocity >= HIGH_FALL_VELOCITY:
			_max_bounces = 2  # High fall = 2 bounces
		elif fall_velocity >= MIN_BOUNCE_VELOCITY:
			_max_bounces = 1  # Medium fall = 1 bounce
		else:
			_max_bounces = 0  # Low fall = no bounce
		
		# Check if we should bounce
		if health <= 0 and fall_velocity >= MIN_BOUNCE_VELOCITY and _bounce_count < _max_bounces:
			# Dead but should bounce - play ground hurt and bounce
			_bounce_count += 1
			_is_bouncing = true
			_just_bounced = true  # Set flag to prevent immediate re-trigger
			_bounce_cooldown = BOUNCE_COOLDOWN_DURATION  # Set cooldown
			behavior_timer = 0.0
			
			# Play ground hurt animation
			if sprite and sprite.sprite_frames.has_animation("hurt_ground"):
				sprite.play("hurt_ground")
			
			# Calculate bounce force based on fall velocity
			var bounce_force = fall_velocity * BOUNCE_FORCE_MULTIPLIER
			# Cap bounce force for gameplay feel
			bounce_force = min(bounce_force, 400.0)
			velocity.y = -bounce_force  # Apply upward bounce
			
			# Small horizontal bounce variation for visual interest
			velocity.x *= 0.5  # Reduce horizontal velocity on bounce
			
			_was_in_air = true  # Still in air after bounce
			return
		elif health <= 0:
			# Dead and no more bounces - play death animation
			_just_bounced = false  # Reset flag
			die()
			return
		else:
			# Alive - play ground impact animation
			if sprite:
				if sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
					behavior_timer = 0.0  # Reset timer for ground animation
				elif sprite.sprite_frames.has_animation("get_up"):
					sprite.play("get_up")
					behavior_timer = 0.0  # Reset timer for get_up animation
			_was_in_air = false
			_is_bouncing = false
			_just_bounced = false  # Reset flag
	
	# Normal hurt behavior (not dead)
	# Determine which hurt animation to play based on velocity
	# IMPORTANT: Always play hurt animations when in hurt state, never fall animation
	if not is_on_floor():
		# Check for wall bounce (hurt enemies can bounce off walls)
		if is_on_wall():
			# Bounce off wall - reverse horizontal velocity
			var wall_bounce_force = abs(velocity.x) * 0.6  # 60% of horizontal velocity
			velocity.x = -velocity.x * 0.6  # Reverse and reduce
			# Small upward component for visual interest
			if velocity.y > -50.0:  # Only if not already rising fast
				velocity.y = min(velocity.y, -100.0)  # Small upward boost
		
		# CRITICAL: Stop fall animation immediately if playing (check every frame)
		if sprite:
			if sprite.animation == "fall":
				sprite.stop()
			# In air - check if rising or falling
			# Use a smaller threshold to detect falling more accurately
			if velocity.y < -10.0:
				# Rising - play hurt_rise
				if sprite.sprite_frames.has_animation("hurt_rise"):
					if sprite.animation != "hurt_rise":
						sprite.play("hurt_rise")
			else:
				# Falling (or very slow upward) - play hurt_fall
				if sprite.sprite_frames.has_animation("hurt_fall"):
					if sprite.animation != "hurt_fall":
						sprite.play("hurt_fall")
		_was_in_air = true  # Track that we're in air
	else:
		# On ground - check if we just landed (was in air, now on ground)
		# IMPORTANT: Only check bounce if we weren't just bouncing and cooldown expired
		if _was_in_air and not _just_bounced and _bounce_cooldown <= 0.0:
			# Just hit ground - check fall velocity for bounce
			var fall_velocity = abs(_previous_velocity_y)
			
			# Determine max bounces based on fall velocity
			if fall_velocity >= HIGH_FALL_VELOCITY:
				_max_bounces = 2  # High fall = 2 bounces
			elif fall_velocity >= MIN_BOUNCE_VELOCITY:
				_max_bounces = 1  # Medium fall = 1 bounce
			else:
				_max_bounces = 0  # Low fall = no bounce
			
			# Check if we should bounce
			if health <= 0 and fall_velocity >= MIN_BOUNCE_VELOCITY and _bounce_count < _max_bounces:
				# Dead but should bounce - play ground hurt and bounce
				_bounce_count += 1
				_is_bouncing = true
				_just_bounced = true  # Set flag to prevent immediate re-trigger
				_bounce_cooldown = BOUNCE_COOLDOWN_DURATION  # Set cooldown
				behavior_timer = 0.0
				
				# Play ground hurt animation
				if sprite and sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
				
				# Calculate bounce force based on fall velocity
				var bounce_force = fall_velocity * BOUNCE_FORCE_MULTIPLIER
				# Cap bounce force for gameplay feel
				bounce_force = min(bounce_force, 400.0)
				velocity.y = -bounce_force  # Apply upward bounce
				
				# Small horizontal bounce variation for visual interest
				velocity.x *= 0.5  # Reduce horizontal velocity on bounce
				
				_was_in_air = true  # Still in air after bounce
				return
			elif health <= 0:
				# Dead and no more bounces - play death animation
				_just_bounced = false  # Reset flag
				die()
				return
			else:
				# Alive - play ground impact animation first
				if sprite:
					if sprite.sprite_frames.has_animation("hurt_ground"):
						sprite.play("hurt_ground")
						behavior_timer = 0.0  # Reset timer for ground animation
					elif sprite.sprite_frames.has_animation("get_up"):
						sprite.play("get_up")
						behavior_timer = 0.0  # Reset timer for get_up animation
			_was_in_air = false
			_just_bounced = false  # Reset flag
		
		# On ground - check if we're dead (double check)
		# BUT: Only call die() if we're actually on ground AND not going upward
		# If velocity.y < 0, we're still going up, so don't die yet
		if health <= 0:
			# Check if we're actually on ground and not being launched upward
			if velocity.y >= 0.0:  # Not going up (0 or positive = falling or on ground)
				# We hit ground while dead - now play death animation
				die()
				return
		
		# On ground and alive - play hurt_ground or get_up (if not already playing)
		if sprite:
			# Only play if we're not already playing these animations
			if sprite.animation != "hurt_ground" and sprite.animation != "get_up":
				if sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
				elif sprite.sprite_frames.has_animation("get_up"):
					sprite.play("get_up")
	
	# Apply horizontal damping while hurt (but less if dead in air - allow juggling)
	if health <= 0 and not is_on_floor():
		# Dead in air - minimal damping for punching bag effect
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		# Normal hurt - strong damping
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	
	# Exit hurt state when timer is up and mostly stopped (only if alive)
	if health > 0 and behavior_timer >= 0.3 and abs(velocity.x) <= 25 and is_on_floor():
		# Wait for hurt_ground animation to finish first (if playing)
		if sprite:
			if sprite.animation == "hurt_ground" and sprite.is_playing():
				return
			# Then wait for get_up animation to finish
			if sprite.sprite_frames.has_animation("get_up"):
				if sprite.animation == "get_up" and sprite.is_playing():
					return
				# If hurt_ground finished but get_up hasn't started, start it
				elif sprite.animation == "hurt_ground" and not sprite.is_playing():
					if sprite.sprite_frames.has_animation("get_up"):
						sprite.play("get_up")
						behavior_timer = 0.0  # Reset timer for get_up
						return
		
		# Return to appropriate behavior (both animations finished)
		if target:
			change_behavior("chase")
		else:
			change_behavior("patrol")
		
		# Re-enable hurtbox
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior and not force:
		return
	
	# IMPORTANT: Don't allow changing to patrol/chase/attack if dead or dying
	# Dead enemies should stay in hurt state until they hit ground
	if health <= 0 and new_behavior in ["patrol", "chase", "attack"] and not force:
		# Force hurt state instead
		if current_behavior != "hurt":
			current_behavior = "hurt"
			behavior_timer = 0.0
		return
	
	if current_behavior == "dead" and not force:
		return
		
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	# IMPORTANT: Override BaseEnemy's automatic animation playing for hurt state
	# BaseEnemy tries to play "hurt" animation which doesn't exist, causing fall animation
	# We handle hurt animations manually in handle_hurt_behavior()
	if new_behavior == "hurt":
		# Don't play animation here - let handle_hurt_behavior() handle it
		# This prevents fall animation from playing
		return
	
	# Play appropriate animation for non-hurt behaviors
	# Hurt animations are handled in handle_hurt_behavior()
	if sprite:
		match new_behavior:
			"patrol":
				sprite.play("idle")
			"chase":
				if sprite.sprite_frames.has_animation("chase"):
					sprite.play("chase")
				else:
					sprite.play("walk")
			"attack":
				if sprite.sprite_frames.has_animation("attack"):
					sprite.play("attack")
				else:
					sprite.play("idle")
				is_attacking = false
			"hurt":
				# Animation will be determined in handle_hurt_behavior()
				# Don't play anything here to prevent fall animation from playing
				pass
			"dead":
				# Only play death animation if on ground
				# If in air, wait until we hit ground (handled in handle_hurt_behavior)
				if is_on_floor():
					sprite.play("death")
				# If in air, don't play death animation yet - let hurt animations play
			_:
				sprite.play("idle")

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0, source_hitbox: Area2D = null) -> void:
	# Reset bounce count when taking new damage (new hit = new bounce opportunity)
	_bounce_count = 0
	_max_bounces = 1
	_just_bounced = false  # Reset bounce flag on new damage
	_bounce_cooldown = 0.0  # Reset cooldown
	# Store if we're in air before taking damage
	var was_in_air = not is_on_floor()
	
	# Apply damage manually (override base class to prevent immediate death in air)
	if current_behavior == "dead":
		return
		
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	# Emit health changed for external listeners
	_health_emit_changed()
	
	# Spawn damage number
	var damage_number = preload("res://effects/damage_number.tscn").instantiate()
	add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.setup(int(amount))
	
	# Apply knockback - BasicEnemy is a punching bag, so stronger knockback
	# Start with base knockback values
	var final_knockback_force = knockback_force
	var final_up_force = knockback_up_force if knockback_up_force >= 0.0 else knockback_force * 0.5
	
	# Check if this is an upward attack by checking attack name from hitbox
	var is_up_attack = false
	var attack_name = ""
	if source_hitbox is PlayerHitbox:
		var player_hitbox = source_hitbox as PlayerHitbox
		# Safely get attack name - property always exists in PlayerHitbox
		attack_name = player_hitbox.current_attack_name if player_hitbox else ""
		
		
		# Check for up attacks - prioritize attack name check
		if attack_name != "":
			# Check for up attack patterns (ground and air)
			var has_up_pattern = attack_name.begins_with("up_") or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up") or attack_name.contains("_up") or attack_name.contains("up_")
			
			if has_up_pattern:
				is_up_attack = true
				# Boost upward force significantly for up attacks
				final_up_force *= 2.5  # 150% boost for up attacks on BasicEnemy
		# Fallback: check up_force value (up attacks have high up_force)
		if not is_up_attack and knockback_up_force > 150.0:
			is_up_attack = true
			final_up_force *= 2.0  # 100% boost if up_force is high
	
	# If we're already in air (being juggled), boost upward force significantly
	if was_in_air or not is_on_floor():
		# Boost upward force for better juggling - BasicEnemy is designed for air combos
		if final_up_force > 0:
			final_up_force *= 1.3  # 30% boost for air juggling
		else:
			final_up_force = knockback_force * 1.0  # Strong upward force even if no up_force
	
	# If dead but still in air, allow even more knockback (punching bag mode)
	# But cap upward force to prevent infinite flight
	# IMPORTANT: When death is deferred, we need stronger knockback to match normal death behavior
	if health <= 0:
		# Boost upward force significantly for death - this compensates for not calling die()
		# Normal death would apply DEATH_UP_FORCE (100.0), but we're using attack knockback
		# So boost it to match or exceed normal death knockback
		if is_up_attack:
			final_up_force *= 1.5  # Extra boost for up attacks on death
		else:
			final_up_force *= 1.4  # Extra boost for other attacks on death
		# Higher cap for dead enemies - they should fly higher for combos
		final_up_force = min(final_up_force, 600.0)  # Cap at 600 for dead enemies (higher)
	
	# Ensure minimum upward force for BasicEnemy (they should always launch)
	if final_up_force < 100.0 and knockback_up_force < 0.0:
		# If no explicit up_force and result is too low, apply minimum
		final_up_force = max(final_up_force, 150.0)
	
	velocity.x = -direction * final_knockback_force
	velocity.y = -final_up_force  # Direct assignment - don't let anything override
	
	# Basic enemy has extended air float for juggling
	# IMPORTANT: Also apply air float for dead enemies being launched upward
	# This prevents them from falling too fast and allows proper juggling
	if velocity.y < 0.0:
		if health > 0:
			air_float_timer = air_float_duration_override
		elif health <= 0:
			# Dead enemies also get air float when launched upward
			# This helps them fly higher and allows for air combos
			air_float_timer = air_float_duration_override * 0.7  # 70% of normal float time
	
	# Check for death BEFORE entering hurt state
	# If we're being launched upward, don't die immediately
	var should_defer_death = false
	if health <= 0:
		# Can barını hemen gizle
		if health_bar:
			health_bar.hide_bar()
		
		# IMPORTANT: If we're being launched upward (up attack), don't die immediately
		# Check if velocity indicates upward movement (negative y means upward)
		# OR if this is an up attack with significant force
		# Use velocity.y as the primary check - if it's negative, we're going up
		var is_being_launched_upward = velocity.y < 0.0  # Any upward velocity (negative y = up)
		var will_be_launched_upward = is_up_attack or (knockback_up_force > 50.0) or (final_up_force > 50.0)
		
		# ALWAYS defer death if we're in air OR being launched upward OR will be launched upward
		# Primary check: velocity.y < 0 means we're going up, so defer death
		should_defer_death = not is_on_floor() or is_being_launched_upward or will_be_launched_upward
		
		# If we should defer death, don't call die() at all - just stay in hurt state
		if should_defer_death:
			# Enter hurt state but don't die yet
			change_behavior("hurt")
			behavior_timer = 0.0
			
			# Flash red
			if sprite:
				sprite.modulate = Color(1, 0, 0, 1)
				create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
			
			# Spawn blood particles
			if _should_spawn_blood():
				_spawn_blood_particles(amount)
			
			# Keep hurtbox enabled so player can keep hitting in air (punching bag effect)
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
			
			# IMPORTANT: Disable air float timer for dead enemies
			# Dead enemies should fall naturally, not float
			air_float_timer = 0.0
			
			# Play correct hurt animation based on velocity (hurt_rise or hurt_fall)
			if sprite:
				if velocity.y < -10.0:
					# Rising - play hurt_rise
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					# Falling or slow upward - play hurt_fall
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
			
			# Don't call die() - stay in hurt state until we hit ground
			# This allows player to continue juggling dead enemies
			return
	
	# Enter hurt state
	change_behavior("hurt")
	behavior_timer = 0.0
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	
	# Spawn blood particles
	if _should_spawn_blood():
		_spawn_blood_particles(amount)
	
	# Check for death - but don't die immediately if in air OR if being launched upward
	if health <= 0:
		# On ground and not being launched upward, die immediately
		die()

func _physics_process(delta: float) -> void:
	# Skip if sleeping or invalid position
	if global_position == Vector2.ZERO:
		return
	
	# CRITICAL: Prevent fade_out for BasicEnemy corpses - they should never disappear
	if fade_out:
		fade_out = false
		death_fade_timer = 0.0
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)  # Keep full opacity
	
	# CRITICAL: Check animation FIRST, before any other processing
	# This ensures fall animation is stopped immediately if it starts playing
	if sprite:
		# If we're in hurt state or dead, NEVER allow fall animation
		if current_behavior == "hurt" or health <= 0:
			if sprite.animation == "fall":
				sprite.stop()
				# Immediately play correct hurt animation
				if not is_on_floor():
					if velocity.y < -10.0:
						if sprite.sprite_frames.has_animation("hurt_rise"):
							sprite.play("hurt_rise")
					else:
						if sprite.sprite_frames.has_animation("hurt_fall"):
							sprite.play("hurt_fall")
	
	# Check sleep state
	check_sleep_state()
	
	# CRITICAL: Disable hitbox if in air or hurt state - enemy can't attack while being juggled
	if hitbox:
		if not is_on_floor() or current_behavior == "hurt" or health <= 0:
			if hitbox.is_enabled():
				hitbox.disable()
			is_attacking = false
	
	# Only process if awake
	if not is_sleeping:
		# Handle behavior
		handle_behavior(delta)
		
		# CRITICAL: Check animation AGAIN after handle_behavior
		# handle_behavior might trigger animations that we need to override
		if sprite:
			if current_behavior == "hurt" or health <= 0:
				if sprite.animation == "fall":
					sprite.stop()
					# Immediately play correct hurt animation
					if not is_on_floor():
						if velocity.y < -10.0:
							if sprite.sprite_frames.has_animation("hurt_rise"):
								sprite.play("hurt_rise")
						else:
							if sprite.sprite_frames.has_animation("hurt_fall"):
								sprite.play("hurt_fall")
		
		# Track velocity before applying gravity (for bounce calculation)
		_previous_velocity_y = velocity.y
		
		# Reset _just_bounced flag when we're actually in air (not on floor)
		# This allows bounce to trigger again on next landing
		if not is_on_floor() and _just_bounced:
			# We're in air now, so reset the flag to allow next bounce check
			_just_bounced = false
		
		# Apply gravity with air float for juggling
		# Check both current_behavior and health to determine if dead
		var is_dead = current_behavior == "dead" or health <= 0
		
		if not is_on_floor() and not is_dead:
			var g_scale := 1.0
			# Extended air float during hurt state for combos (ONLY if alive)
			# Dead enemies always use normal gravity - no float
			if current_behavior == "hurt" and air_float_timer > 0.0 and health > 0:
				g_scale = air_float_gravity_scale
				air_float_timer = max(0.0, air_float_timer - delta)
			# Always apply gravity
			velocity.y += GRAVITY * g_scale * delta
			
			# Cap fall speed during air float (only if alive and float active)
			if current_behavior == "hurt" and air_float_timer > 0.0 and health > 0:
				velocity.y = min(velocity.y, air_float_max_fall_speed)
		elif not is_on_floor() and is_dead:
			# Dead in air - ALWAYS use normal gravity, no float
			# Apply normal gravity to dead enemies (they should fall naturally)
			# BUT preserve upward velocity from hits (don't override it)
			velocity.y += GRAVITY * delta
			
			# Don't apply extra gravity too aggressively - let them fly high for combos
			# Only apply extra gravity if velocity is extremely high (prevent infinite flight)
			if velocity.y < -800.0:  # Increased threshold to allow higher flight
				# Extremely high upward velocity - apply extra gravity to bring it down
				velocity.y += GRAVITY * 0.3 * delta  # Reduced extra gravity
		
		# Stop all movement when dead and on ground ONLY
		# Don't stop movement if dead in air - allow juggling
		if current_behavior == "dead" and is_on_floor():
			velocity = Vector2.ZERO
		
		
		# IMPORTANT: BasicEnemy should NEVER collide with player
		# Always use ENEMY_HURTBOX layer so player can pass through (prevents pushing player into tiles/walls)
		# This allows player to move freely even when enemies are running at them
		# This applies to both ground and air - BasicEnemy is a "punching bag" enemy
		if collision_layer != CollisionLayers.ENEMY_HURTBOX:
			collision_layer = CollisionLayers.ENEMY_HURTBOX
		
		# CRITICAL: Prevent fall animation when in hurt state or dead
		# Fall animation should ONLY play when NOT hurt and NOT dead
		# This check runs EVERY frame to aggressively prevent fall animation
		# (Note: First check is at the top of _physics_process for immediate response)
		if sprite:
			# If we're in hurt state or dead, NEVER play fall animation
			if current_behavior == "hurt" or health <= 0:
				# Force stop fall animation if playing (check every frame)
				if sprite.animation == "fall":
					sprite.stop()
					# Immediately play correct hurt animation
					if not is_on_floor():
						if velocity.y < -10.0:
							if sprite.sprite_frames.has_animation("hurt_rise"):
								sprite.play("hurt_rise")
						else:
							if sprite.sprite_frames.has_animation("hurt_fall"):
								sprite.play("hurt_fall")
				# Always ensure correct hurt animation is playing when in air
				elif not is_on_floor():
					if velocity.y < -10.0:
						# Rising - play hurt_rise
						if sprite.sprite_frames.has_animation("hurt_rise"):
							if sprite.animation != "hurt_rise":
								sprite.play("hurt_rise")
					else:
						# Falling - play hurt_fall
						if sprite.sprite_frames.has_animation("hurt_fall"):
							if sprite.animation != "hurt_fall":
								sprite.play("hurt_fall")
			# Only play fall animation if NOT hurt and NOT dead
			elif not is_on_floor() and current_behavior != "hurt" and current_behavior != "dead" and health > 0:
				if sprite.sprite_frames.has_animation("fall"):
					# Only play fall if not already playing hurt animations
					if sprite.animation != "fall" and sprite.animation != "hurt_fall" and sprite.animation != "hurt_rise":
						sprite.play("fall")
		
		move_and_slide()

func update_sprite_direction() -> void:
	"""Update sprite direction based on movement and target"""
	# Don't update direction if in wall hit state (prevents flickering)
	if _is_wall_hit or _backing_off_timer > 0.0:
		return
	
	if target:
		var target_direction = sign(target.global_position.x - global_position.x)
		if target_direction != 0:
			# Only update direction if it actually changed
			if direction != target_direction:
				direction = target_direction
				if sprite:
					sprite.flip_h = direction < 0
	elif velocity.x != 0:
		var vel_direction = sign(velocity.x)
		# Only update direction if it actually changed
		if direction != vel_direction:
			direction = vel_direction
			if sprite:
				sprite.flip_h = direction < 0
	else:
		# No movement and no target - keep current direction, just update sprite if needed
		if sprite and sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0

func die() -> void:
	# Reset bounce state on death
	_bounce_count = 0
	_max_bounces = 0
	_is_bouncing = false
	_just_bounced = false
	_bounce_cooldown = 0.0
	# Override die to stop velocity immediately
	if current_behavior == "dead":
		return
	
	# IMPORTANT: Completely remove hitbox to prevent blocking player movement
	# Hitbox should not block player movement after death
	if hitbox:
		# Disable the hitbox component first
		hitbox.disable()
		
		# Remove hitbox from collision layers IMMEDIATELY
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0
		
		# Disable monitoring IMMEDIATELY
		hitbox.monitoring = false
		hitbox.monitorable = false
		
		# Disable collision shape IMMEDIATELY
		var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_shape:
			hitbox_shape.disabled = true
			# Remove shape reference to prevent any collision
			hitbox_shape.shape = null
		
		# Remove hitbox from scene tree completely
		hitbox.queue_free()
		hitbox = null
	
	# IMPORTANT: Play death animation BEFORE calling super.die()
	# super.die() sets fade_out = true which might hide sprite immediately
	# BUT: Only play death animation if on ground - if in air, keep playing hurt animations
	if sprite:
		# Ensure sprite is visible
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)  # Reset modulate
		# Play death animation only if on ground
		# If in air, don't play death animation - let handle_hurt_behavior() handle it when we land
		if is_on_floor():
			# Play death animation if available
			if sprite.sprite_frames.has_animation("death"):
				sprite.play("death")
			elif sprite.sprite_frames.has_animation("hurt_fall"):
				# Fallback to hurt_fall if death animation doesn't exist
				sprite.play("hurt_fall")
		# If in air, don't change animation - keep playing hurt_rise or hurt_fall
	
	# Stop all movement before calling super - BUT only if on ground
	# If in air, keep velocity so enemy can fall naturally
	# IMPORTANT: Check velocity.y instead of is_on_floor() because velocity might be set but not applied yet
	if is_on_floor() and velocity.y >= 0.0:
		velocity = Vector2.ZERO
	# If in air or going up, don't zero velocity - let enemy fall naturally
	
	# IMPORTANT: Prevent fade_out from hiding sprite immediately
	# BasicEnemy corpses should remain visible - NEVER fade out or disappear
	fade_out = false
	
	# IMPORTANT: Dead enemies should stay on tiles but NOT block player
	# Set collision_layer to a layer player doesn't detect (ENEMY_HURTBOX = 32)
	# Keep collision_mask to WORLD | PLATFORM so corpses still collide with tiles
	collision_layer = CollisionLayers.ENEMY_HURTBOX  # Layer player doesn't detect
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Collide with tiles/platforms
	
	# IMPORTANT: Save velocity BEFORE calling super.die() because it calls _apply_death_knockback()
	# which will override our velocity. We want to keep the velocity from the attack.
	var saved_velocity = velocity
	
	# Call base class die AFTER setting collision (base class sets collision_layer = 0)
	super.die()
	
	# IMPORTANT: Restore velocity if we're in air (being launched upward)
	# Don't let super.die() override our attack velocity
	if not is_on_floor() or saved_velocity.y < -50.0:
		velocity = saved_velocity
	
	# IMPORTANT: Re-apply collision settings after super.die() (it sets collision_layer = 0)
	collision_layer = CollisionLayers.ENEMY_HURTBOX  # Layer player doesn't detect
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Collide with tiles/platforms
	fade_out = false  # CRITICAL: Prevent fade out - corpses stay forever
	
	# CRITICAL: Ensure sprite stays visible and never fades
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)  # Full opacity, no fade
		death_fade_timer = 0.0  # Reset fade timer to prevent any fading
	
	# Keep CollisionShape2D enabled so corpses can collide with tiles
	# Player won't collide because collision_layer is ENEMY_HURTBOX which player doesn't detect
	
	# Hitbox should already be removed, but double-check
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()
		hitbox = null
	
	# Ensure velocity stays zero after death (override death knockback) - BUT only if on ground
	# If in air, keep velocity so enemy can fall naturally
	if is_on_floor() and saved_velocity.y >= -50.0:
		velocity = Vector2.ZERO
	# If in air or being launched upward, keep saved velocity

func _apply_death_knockback() -> void:
	# Override to prevent upward flight - basic enemies just fall down
	# BUT: If we're being launched upward (from up attack), keep that velocity
	# Only zero velocity if we're on ground and not being launched upward
	if is_on_floor() and velocity.y >= -50.0:
		velocity = Vector2.ZERO
	# If in air or being launched upward, keep current velocity (don't override)
	
	# CRITICAL: Don't start fall delete timer - BasicEnemy corpses should NEVER disappear
	# Do NOT call _on_fall_timer_timeout - corpses stay forever
	pass

func _on_fall_timer_timeout() -> void:
	# Override BaseEnemy's fall timer - BasicEnemy corpses NEVER disappear
	# Do nothing - corpses stay forever
	pass

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Override to allow taking damage even when dead in air (punching bag mode)
	# IMPORTANT: Don't call super - we handle everything here
	
	# Safety: enemies only take damage from PlayerHitbox
	if not (hitbox is PlayerHitbox):
		return
	
	# If dead and on ground, don't take damage
	if current_behavior == "dead" and is_on_floor():
		return
	
	# Get knockback data
	var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0, "up_force": 100.0}
	var damage = hitbox.get_damage() if hitbox.has_method("get_damage") else 10.0
	
	# If dead in air, allow damage but don't reduce health further
	if health <= 0 and not is_on_floor():
		# Dead but in air - allow knockback for punching bag effect
		# Apply knockback without reducing health
		var final_knockback_force = knockback_data.get("force", 200.0)
		var final_up_force = knockback_data.get("up_force", 100.0)
		
		# Check if this is an upward attack by checking attack name from hitbox
		var is_up_attack = false
		var attack_name = ""
		if hitbox is PlayerHitbox:
			var player_hitbox = hitbox as PlayerHitbox
			attack_name = player_hitbox.current_attack_name if player_hitbox else ""
			
			# Check for up attack patterns (ground and air)
			if attack_name != "":
				var has_up_pattern = attack_name.begins_with("up_") or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up") or attack_name.contains("_up") or attack_name.contains("up_")
				if has_up_pattern:
					is_up_attack = true
		# Fallback: check up_force value
		if not is_up_attack and final_up_force > 150.0:
			is_up_attack = true
		
		if is_up_attack:
			# Up attacks get even more boost for dead enemies
			final_up_force *= 3.0  # 200% boost for up attacks on dead enemies
		else:
			final_up_force *= 2.0  # 100% boost for other attacks
		
		# Higher cap for dead enemies - they should fly higher for combos
		final_up_force = min(final_up_force, 700.0)  # Cap at 700 for dead enemies
		final_knockback_force *= 1.3
		
		# Apply velocity DIRECTLY - don't let anything override this
		velocity.x = -direction * final_knockback_force
		velocity.y = -final_up_force  # Direct assignment for upward force
		
		# IMPORTANT: Ensure air float timer is disabled for dead enemies
		air_float_timer = 0.0
		
		# Play hurt animation based on velocity
		if sprite:
			if velocity.y < -10.0:
				if sprite.sprite_frames.has_animation("hurt_rise"):
					sprite.play("hurt_rise")
			else:
				if sprite.sprite_frames.has_animation("hurt_fall"):
					sprite.play("hurt_fall")
		
		# Flash red briefly
		if sprite:
			sprite.modulate = Color(1, 0, 0, 1)
			create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
		
		return
	
	# Normal damage handling - pass hitbox to take_damage
	take_damage(damage, knockback_data.get("force", 200.0), knockback_data.get("up_force", -1.0), hitbox)

func reset() -> void:
	super.reset()
	patrol_point_left = global_position.x - patrol_range
	patrol_point_right = global_position.x + patrol_range
	behavior_timer = 0.0
	attack_cooldown_timer = 0.0
	is_attacking = false

func _on_animation_finished() -> void:
	"""Called when an animation finishes. Prevents fall animation from playing when hurt."""
	if not sprite:
		return
	
	# CRITICAL: If we're in hurt state or dead, NEVER let fall animation play
	# If fall animation just finished, immediately play correct hurt animation
	if current_behavior == "hurt" or health <= 0:
		if sprite.animation == "fall":
			sprite.stop()
			# Play correct hurt animation based on velocity
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
		# If hurt animations finished, loop them (don't let fall play)
		elif sprite.animation == "hurt_rise" or sprite.animation == "hurt_fall":
			# Loop the hurt animation if still in air
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")

func _on_animation_changed() -> void:
	"""Called when animation changes. Prevents fall animation from playing when hurt."""
	if not sprite:
		return
	
	# CRITICAL: If BaseEnemy's change_behavior tries to play "hurt" (which doesn't exist),
	# AnimatedSprite2D might default to "fall". Intercept this immediately.
	if current_behavior == "hurt" or health <= 0:
		# Block ANY attempt to play fall animation
		if sprite.animation == "fall" or sprite.animation == "hurt":
			sprite.stop()
			# Play correct hurt animation based on velocity
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
			else:
				# On ground - play hurt_ground or death
				# IMPORTANT: Only play death animation if we're actually dead AND on ground
				# Don't play death animation if we're still in air (handled in handle_hurt_behavior)
				if health <= 0 and is_on_floor():
					if sprite.sprite_frames.has_animation("death"):
						sprite.play("death")
				elif sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
	
	# Reset air float settings
	if extended_air_float:
		air_float_duration = air_float_duration_override
		air_float_gravity_scale = air_float_gravity_override
		air_float_max_fall_speed = 200.0
