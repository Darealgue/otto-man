class_name HeavyEnemy
extends "res://enemy/base_enemy.gd"

# Enemy-specific stats
var patrol_point_left: float
var patrol_point_right: float
var original_collision_shape: Shape2D

# Attack properties
const slam_radius := 150.0
const slam_damage := 37.0
const charge_damage := 25.0
const hurt_duration := 0.5

# Combat ranges and durations
const detection_range := 500.0  # How far the enemy can see
const slam_range := 150.0      # Maximum distance for slam attack
const charge_range := 400.0    # Maximum distance for charge attack
const chase_duration := 1.5    # How long to chase before trying an attack (çok agresif)
const attack_cooldown := 0.8   # Time between attacks (çok daha hızlı saldırı)

# Charge attack properties
const charge_speed := 400.0    # Speed during charge attack
const charge_duration := 0.8   # How long the charge lasts
var charge_timer: float = 0.0  # Current charge time

# Behavior timers
var behavior_change_delay: float = 0.5
var last_behavior_change: float = 0.0
var direction_change_cooldown: float = 0.5
var last_direction_change: float = 0.0
var vertical_tolerance: float = 200.0

# Patrol and detection properties
var patrol_point_wait_time: float = 1.5
var alert_duration: float = 0.8
var has_seen_player: bool = false

var memory_duration: float = 1.5
var memory_timer: float = 0.0
var last_known_player_pos: Vector2 = Vector2.ZERO

const CHARGE_DECELERATION := 4000.0
const CHARGE_END_THRESHOLD := 0.8

@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var slam_effect = $SlamEffect
@onready var raycast_left = $RayCastLeft
@onready var raycast_right = $RayCastRight

func _is_position_safe(pos: Vector2) -> bool:
	# Check if position is safe (not inside walls/ground)
	var space_state = get_world_2d().direct_space_state
	
	# Check multiple points around the enemy
	var check_points = [
		pos,  # Center
		pos + Vector2(-20, -20),  # Top-left
		pos + Vector2(20, -20),   # Top-right
		pos + Vector2(-20, 20),   # Bottom-left
		pos + Vector2(20, 20)     # Bottom-right
	]
	
	for point in check_points:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = point
		query.collision_mask = CollisionLayers.WORLD  # Only check world collision
		var result = space_state.intersect_point(query)
		if result:
			return false  # Position is inside world geometry
	
	return true  # Position is safe

func _ready() -> void:
	super._ready()
	
	# Initialize attack variables
	can_attack = true
	
	
	# Add platform layer to collision mask
	collision_mask |= 10  # Add platform layer (10) to existing collision mask
	set_collision_mask_value(10, true)  # Ensure platform collision is enabled
	
	sleep_distance = 2000.0  # Increased from 1200
	wake_distance = 1800.0   # Increased from 1000
	is_sleeping = false  # Start awake
	vertical_tolerance = 200.0  # Increased from 100
	can_attack = true  # Ensure can_attack starts true
	
	# Set initial direction
	direction = 1  # Start moving right
	
	# Configure raycasts with proper offset and length
	if raycast_left and raycast_right:
		raycast_left.enabled = true
		raycast_right.enabled = true
		raycast_left.collision_mask = CollisionLayers.WORLD  # Environment
		raycast_right.collision_mask = CollisionLayers.WORLD
		raycast_left.position = Vector2(-20, 0)  # Offset from center
		
	
	raycast_right.position = Vector2(20, 0)
	
	raycast_left.target_position = Vector2(0, 100)  # Longer raycast
	raycast_right.target_position = Vector2(0, 100)
	
	# Setup normal map synchronization
	_setup_normal_map_sync()
	
	# Manually connect hurtbox signal to ensure it works
	call_deferred("_connect_hurtbox_signal")
	
	# Store initial position for patrol points
	var initial_pos = global_position
	if initial_pos != Vector2.ZERO:
		patrol_point_left = initial_pos.x - 200
		patrol_point_right = initial_pos.x + 200
	
	# Ensure hitbox is disabled on initialization
	if hitbox:
		hitbox.disable()
		if hitbox.is_connected("area_entered", _on_slam_hitbox_hit):
			hitbox.area_entered.disconnect(_on_slam_hitbox_hit)
	
	# Start with patrol behavior
	current_behavior = "patrol"
	sprite.play("walk")
	behavior_timer = 0.0
	
	# Ensure physics are properly set up
	collision_layer = 4  # Enemy layer
	collision_mask = CollisionLayers.WORLD   # Collide with environment
	floor_snap_length = 32.0  # Snap to floor
	up_direction = Vector2.UP
	
	# Wait for physics to be ready and ensure proper floor detection
	await get_tree().physics_frame
	
	# Force an initial move_and_slide to ensure proper floor contact
	velocity = Vector2.ZERO
	move_and_slide()
	
	# If we're not on floor after initial move, try to snap to ground
	if not is_on_floor():
		position.y += floor_snap_length
		move_and_slide()
		
		# If still not on floor, try raycasting down
		if not is_on_floor():
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * 500.0)
			query.collision_mask = CollisionLayers.WORLD  # Environment layer
			var result = space_state.intersect_ray(query)
			
			if result:
				global_position = result.position - Vector2(0, 32)  # Offset up by 32 pixels
				move_and_slide()


func find_ground_below(start_pos: Vector2) -> Vector2:
	if start_pos == Vector2.ZERO:
		return Vector2.ZERO
		
	
	# Create temporary raycast for ground detection
	var ground_check = RayCast2D.new()
	add_child(ground_check)
	ground_check.enabled = true
	ground_check.position = Vector2(0, 0)
	ground_check.target_position = Vector2(0, 500)  # Check up to 500 pixels down
	ground_check.collision_mask = CollisionLayers.WORLD
	
	# Store current position
	var current_pos = position
	
	# Move to start position and check for ground
	position = start_pos
	ground_check.force_raycast_update()
	
	var result = Vector2.ZERO
	if ground_check.is_colliding():
		result = ground_check.get_collision_point()
		result.y -= 32  # Offset to place enemy on top of ground
	else:
		position = current_pos
	
	# Clean up
	ground_check.queue_free()
	
	return result

func _handle_child_behavior(delta: float) -> void:
	if is_sleeping:
		return
		
	match current_behavior:
		"patrol":
			handle_patrol(delta)
		"idle":
			handle_idle(delta)
		"chase":
			handle_chase(delta)
		"alert":
			handle_alert(delta)
		"charge_prepare":
			handle_charge_prepare(delta)
		"charge_start":
			handle_charge_start(delta)
		"charging":
			handle_charging(delta)
		"charge_end":
			handle_charge_end(delta)
		"slam_prepare":
			handle_slam_prepare(delta)
		"slam":
			handle_slam(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior:
		return
		
	
	
	if hitbox and current_behavior in ["charging", "slam"]:
		hitbox.disable()
		
	# Reset velocity when changing from charge to any other state
	if current_behavior == "charging":
		velocity.x = 0
	
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	match new_behavior:
		"patrol":
			sprite.play("walk")
			has_seen_player = false
		"idle":
			sprite.play("idle")
		"alert":
			sprite.play("idle")
		"chase":
			sprite.play("walk")
		"charge_prepare":
			sprite.play("charge_prepare")
			velocity.x = 0
		"charge_start":
			sprite.play("charge_start")
			# Only disable enemy collision if position is safe
			if _is_position_safe(global_position):
				set_collision_mask_value(3, false)
			else:
				print("[Heavy] Position not safe, keeping enemy collision during charge")
		"charging":
			sprite.play("charging")
		"charge_end":
			if sprite.animation != "charge_end":
				sprite.play("charge_end")
			velocity.x = 0
			# Restore collision with enemies after charge
			set_collision_mask_value(3, true)
		"slam_prepare":
			sprite.play("slam_prepare")
			velocity.x = 0
		"slam":
			sprite.play("slam")
			velocity.x = 0
		"hurt":
			sprite.play("hurt")
			velocity.x = 0
		"dead":
			sprite.play("dead")
			velocity.x = 0

func handle_patrol(delta: float) -> void:
	behavior_timer += delta
	
	# Update sprite direction
	update_sprite_direction()
	
	# First check for player
	var had_target = target != null
	target = get_nearest_player_in_range()  # Use the range-limited check
	

	if target:
		change_behavior("alert")
		return
	
	# Only handle movement if we're on the floor
	if is_on_floor():
		# Check if we're at a patrol point
		var target_x = patrol_point_right if direction > 0 else patrol_point_left
		var at_patrol_point = abs(position.x - target_x) < 10
		
		if at_patrol_point:
			# At patrol point, transition to idle state
			change_behavior("idle")
			return
		
		# Check floor before moving
		var has_floor = check_floor()
		
		# Check for walls/obstacles in front
		var has_wall = check_wall()
		
		# Check if player is too close in front
		var player_too_close = check_player_in_front()
		
		# Add a small delay before turning around to prevent rapid flipping
		if (not has_floor or has_wall or player_too_close) and behavior_timer >= 0.5:
			velocity.x = 0
			direction *= -1
			sprite.flip_h = direction < 0
			behavior_timer = 0.0  # Reset timer after turning
		else:
			# Move in current direction
			if sprite.animation != "walk":
				sprite.play("walk")
			velocity.x = direction * (stats.movement_speed if stats else 100.0) * 0.7
		
		# Stop animation if not moving
		if velocity.x == 0 and sprite.animation == "walk":
			sprite.play("idle")
	else:
		# In air, try to recover
		velocity.x = move_toward(velocity.x, 0, (stats.movement_speed if stats else 100.0) * delta)

func handle_idle(delta: float) -> void:
	behavior_timer += delta
	
	# Stop movement and play idle animation
	velocity.x = 0
	if sprite and sprite.animation != "idle":
		sprite.play("idle")
	
	# Check for player first
	target = get_nearest_player_in_range()
	if target:
		change_behavior("alert")
		return
	
	# Stay in idle for patrol_point_wait_time before returning to patrol
	if behavior_timer >= patrol_point_wait_time:
		direction *= -1  # Change direction before returning to patrol
		sprite.flip_h = direction < 0
		change_behavior("patrol")

func handle_alert(delta: float) -> void:
	behavior_timer += delta
	
	# Stop movement during alert
	velocity.x = 0
	
	# Play alert animation
	if sprite.animation != "alert":
		sprite.play("alert")
	
	# After alert duration, transition to chase
	if behavior_timer >= alert_duration:
		has_seen_player = true
		target = get_nearest_player()  # Update target before chase
		if target:
			# Update direction before chase
			direction = sign(target.global_position.x - global_position.x)
			sprite.flip_h = direction < 0
			change_behavior("chase")
		else:
			change_behavior("patrol")

func handle_chase(delta: float) -> void:
	# Return to patrol if we've been chasing too long
	if behavior_timer >= chase_duration:
		change_behavior("patrol")
		target = null
		memory_timer = 0.0
		return
	
	# Get current target
	target = get_nearest_player()
	
	if target:
		last_known_player_pos = target.global_position
		memory_timer = memory_duration
		
		# Calculate distances using global positions
		var distance = global_position.distance_to(target.global_position)
		var height_diff = abs(global_position.y - target.global_position.y)
		var dir_to_player = sign(target.global_position.x - global_position.x)
		
		# Update direction if enough time has passed
		if height_diff <= vertical_tolerance and last_direction_change >= direction_change_cooldown:
			if dir_to_player != direction:
				direction = dir_to_player
				sprite.flip_h = direction < 0
				if hitbox:
					hitbox.position.x = abs(hitbox.position.x) * direction
				last_direction_change = 0.0
		
		last_direction_change += delta
		
		# Check for obstacles before moving
		var has_wall = check_wall()
		var player_too_close = check_player_in_front()
		
		# If there's a wall or player is too close, stop moving
		if has_wall or player_too_close:
			velocity.x = 0
			if sprite.animation == "walk":
				sprite.play("idle")
			# Reduced debug noise: comment out frequent prints
			# print("[HeavyEnemy] Stopped due to obstacle or player too close")
		else:
			# Move towards player
			if sprite.animation != "walk":
				sprite.play("walk")
			velocity.x = direction * (stats.movement_speed if stats else 100.0)
		
		
		if can_attack and behavior_timer >= behavior_change_delay:
			# Check if we're in range for either attack
			var can_slam = distance <= slam_range and height_diff <= vertical_tolerance
			var can_charge = distance <= charge_range and height_diff <= vertical_tolerance
			
			if can_slam:
				change_behavior("slam_prepare")
				return
			elif can_charge:
				change_behavior("charge_prepare")
				return
	else:
		# If no target, return to patrol
		change_behavior("patrol")

func handle_charge_prepare(delta: float) -> void:
	if behavior_timer >= 0.5 and sprite.frame >= sprite.sprite_frames.get_frame_count("charge_prepare") - 1:
		# Set up hitbox before transitioning to charge_start
		if hitbox_collision:
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(40, 60)
			hitbox_collision.shape = rect_shape
			hitbox.position.x = 30 * direction
			hitbox.position.y = 0
			
			# Store original shape if not already stored
			if not original_collision_shape:
				original_collision_shape = hitbox_collision.shape.duplicate()
			
			# Set up hitbox for charge attack
			hitbox.damage = charge_damage
			hitbox.knockback_force = 700.0  # Strong horizontal force for charge
			hitbox.knockback_up_force = 0.0  # No upward force for pure horizontal knockback
			hitbox.enable()
		
		change_behavior("charge_start")

func handle_charge_start(delta: float) -> void:
	# Use full charge speed immediately
	velocity.x = direction * charge_speed
	
	if not sprite.is_playing() or sprite.frame >= sprite.sprite_frames.get_frame_count("charge_start") - 1:
		charge_timer = 0.0  # Reset charge timer when transitioning to charge loop
		change_behavior("charging")

func handle_charging(delta: float) -> void:
	charge_timer += delta
	
	
	# Calculate remaining charge time
	var time_remaining = charge_duration - charge_timer
	
	# Debug velocity and timing every few frames

	
	# Check if we should start decelerating
	if charge_timer >= charge_duration * CHARGE_END_THRESHOLD:
		var decel_factor = (charge_duration - charge_timer) / (charge_duration * (1.0 - CHARGE_END_THRESHOLD))
		decel_factor = clamp(decel_factor, 0.0, 1.0)
		var target_speed = charge_speed * decel_factor * direction

		
		# Apply deceleration smoothly
		velocity.x = move_toward(velocity.x, target_speed, CHARGE_DECELERATION * delta)
	else:
		velocity.x = direction * charge_speed
	
	if charge_timer >= charge_duration:
		change_behavior("charge_end")
		disable_all_hitboxes()
		
		# Force velocity to zero when ending charge
		velocity.x = 0
		return

func handle_charge_end(delta: float) -> void:
	if not sprite.is_playing() or sprite.frame >= sprite.sprite_frames.get_frame_count("charge_end") - 1:
		if current_behavior == "charge_end":  # Only transition if we haven't already
			change_behavior("chase")
			start_attack_cooldown()

func handle_slam_prepare(delta: float) -> void:
	if behavior_timer >= 0.5 and sprite.frame >= sprite.sprite_frames.get_frame_count("slam_prepare") - 1:
		change_behavior("slam")

func handle_slam(delta: float) -> void:
	if not is_instance_valid(self):
		return
		
	if sprite.frame == 2 and not hitbox.is_enabled():
		create_slam_damage()
	
	if sprite.frame >= sprite.sprite_frames.get_frame_count("slam") - 1:
		if current_behavior == "slam":  # Only transition if we haven't already
			disable_all_hitboxes()
			change_behavior("chase", true)
			start_attack_cooldown()  # Start cooldown after attack ends

func create_slam_damage() -> void:
	if not is_instance_valid(self) or not hitbox or not hitbox_collision:
		return
		
	# Store original collision shape if not already stored
	if not original_collision_shape and hitbox_collision.shape:
		original_collision_shape = hitbox_collision.shape.duplicate()
	
	# Create and set up circle shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = slam_radius
	hitbox_collision.shape = circle_shape
	hitbox.position = Vector2.ZERO
	
	# Set up hitbox properties
	hitbox.damage = slam_damage
	hitbox.knockback_force = 400.0
	hitbox.knockback_up_force = 500.0
	
	# Clean up old slam connections and set up new one
	var connections = hitbox.get_signal_connection_list("area_entered")
	for connection in connections:
		if connection.callable == _on_slam_hitbox_hit:
			hitbox.area_entered.disconnect(connection.callable)
	
	hitbox.area_entered.connect(_on_slam_hitbox_hit)
	hitbox.enable()
	
	# Play animation
	sprite.play("slam")
	
	# Handle visual effect
	if slam_effect:
		var points = PackedVector2Array()
		var num_points = 32
		for i in range(num_points + 1):
			var angle = i * 2 * PI / num_points
			var point = Vector2(cos(angle), sin(angle)) * slam_radius
			points.append(point)
		
		slam_effect.points = points
		slam_effect.show()
		slam_effect.modulate = Color(1, 0.8, 0.2, 1.0)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		var expanded_points = PackedVector2Array()
		for point in points:
			expanded_points.append(point * 1.5)
		
		tween.tween_property(slam_effect, "points", expanded_points, 0.3)
		tween.tween_property(slam_effect, "modulate", Color(1, 0.8, 0.2, 0), 0.3)
		
		await tween.finished
		slam_effect.hide()
	
	# Ensure hitbox is disabled after a short duration
	if is_instance_valid(self):
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): 
			if is_instance_valid(self):
				disable_all_hitboxes()
		)

func disable_all_hitboxes() -> void:
	if not is_instance_valid(self):
		return
		
	if hitbox:
		hitbox.disable()
		
		# Only disconnect slam attack signals
		var connections = hitbox.get_signal_connection_list("area_entered")
		for connection in connections:
			if connection.callable == _on_slam_hitbox_hit:
				hitbox.area_entered.disconnect(connection.callable)
		
		# Reset position but keep other properties for next attack
		hitbox.position = Vector2.ZERO
		
		# Only reset collision shape if we have the original
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()

func _on_slam_hitbox_hit(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		hitbox.disable()
		if hitbox.is_connected("area_entered", _on_slam_hitbox_hit):
			hitbox.area_entered.disconnect(_on_slam_hitbox_hit)

func handle_hurt_behavior(delta: float) -> void:
	behavior_timer += delta
	
	# Apply friction to slow down the knockback
	velocity.x = move_toward(velocity.x, 0, 1000.0 * delta)
	
	# Only exit hurt state if timer is up AND mostly stopped
	if behavior_timer >= hurt_duration and abs(velocity.x) <= 25:
		velocity.x = 0  # Ensure velocity is completely zeroed
		if target:
			change_behavior("chase")
		else:
			change_behavior("patrol")

func _on_hitbox_hit(area: Area2D) -> void:
	pass

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if current_behavior != "dead":
		var damage = hitbox.get_damage() if hitbox.has_method("get_damage") else 10.0
		var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0, "up_force": 100.0}
		take_damage(damage, knockback_data.get("force", 200.0), knockback_data.get("up_force", -1.0))

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	# Don't take damage if already dead
	if current_behavior == "dead":
		return
		
	# List of states where enemy should be uninterruptible
	var uninterruptible_states = ["charge_prepare", "charging", "slam_prepare", "slam"]
	
	# Track if this hit kills the enemy (always define var)
	var was_lethal = false
	# Apply damage and effects
	if stats:
		health -= amount
		
		# Update health bar
		if health_bar:
			health_bar.update_health(health)
		
		# Spawn damage number
		var damage_number = preload("res://effects/damage_number.tscn").instantiate()
		add_child(damage_number)
		damage_number.global_position = position + Vector2(0, -50)
		damage_number.setup(int(amount))
		
		# Flash red
		_flash_hurt()
		
		# Spawn blood particles (call base class function)
		if _should_spawn_blood():
			_spawn_blood_particles(amount)
		
		# Don't exit early; we want to apply on-hit knockback even on lethal
		was_lethal = health <= 0
	
	# Handle knockback and state changes (apply knockback even on lethal)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (position - player.global_position).normalized()
		var up = -knockback_force * 0.5
		if knockback_up_force >= 0.0:
			up = -knockback_up_force
		velocity = Vector2(dir.x * knockback_force, up)
		# If launched upward, ensure we are not clamped by floor snap immediately
		if up < 0.0:
			# Temporarily clear floor snap so launch takes effect
			floor_snap_length = 0.0
			air_float_timer = air_float_duration

	if was_lethal:
		# Can barını hemen gizle (die() fonksiyonundan önce)
		if health_bar:
			health_bar.hide_bar()
		# Go straight to death after applying launch; keep vertical velocity so the corpse falls
		die()
	else:
		if not uninterruptible_states.has(current_behavior):
			# Change to hurt state and restore floor snap shortly after
			change_behavior("hurt", true)
			var t := get_tree().create_timer(0.1)
			t.timeout.connect(func():
				if is_instance_valid(self):
					floor_snap_length = 32.0
			)

func reset() -> void:
	super.reset()
	charge_timer = 0.0
	has_seen_player = false
	memory_timer = 0.0
	modulate.a = 1.0  # Reset opacity
	
	# Reset collision states
	set_collision_layer_value(3, true)  # Enemy collision
	set_collision_mask_value(1, true)   # Environment collision
	set_collision_mask_value(2, true)   # Other necessary collisions
	
	if hitbox:
		hitbox.disable()
		hitbox.is_parried = false
	
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true

func die() -> void:
	if current_behavior == "dead":
		return
		
	current_behavior = "dead"
	
	# Can barını hemen gizle
	if health_bar:
		health_bar.hide_bar()
	
	enemy_defeated.emit()
	
	PowerupManager.on_enemy_killed()
	
	if sprite:
		sprite.play("dead")
	
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
	
	# Set z_index above player (player z_index = 5)
	if sprite:
		sprite.z_index = 6
		sprite.modulate = Color(1, 1, 1, 1)
	fade_out = true
	
	# Don't return to pool - let corpses persist
	# await get_tree().create_timer(2.0).timeout
	# var scene_path = scene_file_path
	# var pool_name = scene_path.get_file().get_basename()
	# object_pool.return_object(self, pool_name)

func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if not is_instance_valid(self) or global_position == Vector2.ZERO:
		return
	
	# Apply gravity; only use juggle float during hurt state
	if not is_on_floor():
		var g_scale := 1.0
		if current_behavior == "hurt" and air_float_timer > 0.0:
			g_scale = air_float_gravity_scale
			air_float_timer = max(0.0, air_float_timer - delta)
		velocity.y += GRAVITY * g_scale * delta
		# Cap falling speed only while float active in hurt
		if current_behavior == "hurt" and air_float_timer > 0.0:
			velocity.y = minf(velocity.y, air_float_max_fall_speed)
	elif is_on_floor():
		# Do not zero out upward knockback during hurt; allow takeoff
		if not (current_behavior == "hurt" and velocity.y < 0.0):
			velocity.y = 0
	
	
	# Check if we should wake up
	if is_sleeping:
		var nearest_player = get_nearest_player()
		if nearest_player:
			var distance = global_position.distance_to(nearest_player.global_position)
			if distance <= wake_distance:
				wake_up()
		return
	
	# Check if we should go to sleep
	var nearest_player = get_nearest_player()
	if nearest_player:
		var distance = global_position.distance_to(nearest_player.global_position)
		if distance >= sleep_distance and current_behavior != "hurt" and current_behavior != "dead":
			go_to_sleep()
			return
	
	# Only proceed with normal processing if we're awake
	if not is_sleeping:
		# Update behavior timer
		behavior_timer += delta
		
		# Handle behavior and movement
		_handle_child_behavior(delta)
		
		# Apply movement
		move_and_slide()
		
		# Check if we're stuck in the air
		if not is_on_floor() and current_behavior != "dead":
			# Try to detect ground below
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.DOWN * floor_snap_length)
			query.collision_mask = CollisionLayers.WORLD  # Environment layer
			var result = space_state.intersect_ray(query)
			
			if result:
				# If ground is detected within snap distance, move to it
				global_position = result.position
				velocity.y = 0
				move_and_slide()

func get_behavior() -> String:
	return current_behavior

func wake_up() -> void:
	
	is_sleeping = false
	set_physics_process(true)
	disable_all_hitboxes()
	
	# Ensure we're in patrol state when waking up
	change_behavior("patrol", true)  # Force the behavior change
	sprite.play("walk")
	

func go_to_sleep() -> void:
	if not is_sleeping:
		is_sleeping = true
		disable_all_hitboxes()
		velocity = Vector2.ZERO
		sprite.play("idle")

func _exit_tree() -> void:
	# Just do our own cleanup without trying to call parent
	disable_all_hitboxes()
	
	# Clear any remaining signals or references
	if hitbox:
		hitbox.queue_free()
	if slam_effect:
		slam_effect.queue_free()
	if hitbox_collision:
		hitbox_collision.queue_free()
		
	# Clear stored references
	target = null
	original_collision_shape = null

func start_attack_cooldown() -> void:
	can_attack = false
	var timer = get_tree().create_timer(attack_cooldown)
	timer.timeout.connect(func(): 
		if is_instance_valid(self):
			can_attack = true
			behavior_timer = behavior_change_delay
	)

func check_floor() -> bool:
	if not raycast_left or not raycast_right:
		return true  # If no raycasts, assume floor exists
	
	# Check which raycast to use based on direction
	var check_ray = raycast_right if direction > 0 else raycast_left
	
	# Force raycast to update
	check_ray.force_raycast_update()
	
	# Get the collision result
	var has_floor = check_ray.is_colliding()
	
	if has_floor:
		var collision_point = check_ray.get_collision_point()
		var local_collision = to_local(collision_point)
		
		
		# More lenient floor level check
		if abs(local_collision.y) <= 100:  # Increased tolerance
			return true
		
		return true  # If we hit something within reasonable range, consider it floor
	
	return false

func check_wall() -> bool:
	# Create a raycast to check for walls/obstacles in front
	var space_state = get_world_2d().direct_space_state
	var ray_start = global_position
	var ray_end = ray_start + Vector2(direction * 30, 0)  # Check 30 pixels ahead (reduced from 50)
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Check both world and platform layers
	var result = space_state.intersect_ray(query)
	
	if result:
		# Check if the obstacle is close enough to be a problem
		var distance = global_position.distance_to(result.position)
		if distance < 35:  # If obstacle is within 35 pixels (reduced from 60)
			return true
	
	return false

func _initialize_components() -> void:
	super._initialize_components()
	
	if hurtbox:
		# Disconnect base class signal first to avoid duplicates
		if hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.disconnect(_on_hurtbox_hurt)
		# Connect our custom signal
		if not hurtbox.hurt.is_connected(_on_heavy_hurtbox_hurt):
			hurtbox.hurt.connect(_on_heavy_hurtbox_hurt)

func _connect_hurtbox_signal() -> void:
	if hurtbox:
		# Disconnect first to avoid duplicates
		if hurtbox.hurt.is_connected(_on_heavy_hurtbox_hurt):
			hurtbox.hurt.disconnect(_on_heavy_hurtbox_hurt)
		# Connect the signal
		hurtbox.hurt.connect(_on_heavy_hurtbox_hurt)

func _on_heavy_hurtbox_hurt(hitbox: Area2D) -> void:
	# Call base class function directly
	super._on_hurtbox_hurt(hitbox)


func check_player_in_front() -> bool:
	# Check if player is directly in front and too close
	if not target:
		return false
	
	var player_pos = target.global_position
	var enemy_pos = global_position
	
	# Check if player is in front of enemy (same direction as enemy is facing)
	var direction_to_player = (player_pos - enemy_pos).normalized()
	var dot_product = direction_to_player.x * direction
	
	if dot_product > 0:  # Player is in front
		var distance = enemy_pos.distance_to(player_pos)
		if distance < 80:  # If player is very close in front
			# Reduced debug noise
			# print("[HeavyEnemy] Player too close in front, distance: " + str(distance))
			return true
	
	return false



func _setup_normal_map_sync():
	"""Setup normal map synchronization between main sprite and normal sprite"""
	
	# Find the normal sprite (it's a child of the main AnimatedSprite2D)
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		# Try to find it by name
		normal_sprite = sprite.get_node("AnimatedSprite2D")
		if not normal_sprite:
			return
	
	# Set up normal mapping on main sprite using ShaderMaterial
	if sprite and not sprite.material:
		var shader = load("res://enemy/normal_shader.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material
	
	# Connect to frame changed signal to sync normal map
	if not sprite.frame_changed.is_connected(_sync_normal_map):
		sprite.frame_changed.connect(_sync_normal_map)
	
	# Initial sync
	_sync_normal_map()

func _sync_normal_map():
	"""Sync normal map texture with main sprite animation"""
	# Find the normal sprite
	var normal_sprite = sprite.get_node("AnimatedSprite2D_normal")
	if not normal_sprite:
		normal_sprite = sprite.get_node("AnimatedSprite2D")
		if not normal_sprite:
			return
	
	# Sync animation and frame with main sprite
	normal_sprite.animation = sprite.animation
	normal_sprite.frame = sprite.frame
	
	# Keep normal sprite invisible but ensure it's properly set up for normal mapping
	normal_sprite.visible = false
	
	# Set up normal mapping on main sprite using ShaderMaterial
	if sprite and not sprite.material:
		var shader = load("res://enemy/normal_shader.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material
			
			# Debug: Check if normal texture is properly set
			if normal_sprite.sprite_frames:
				var test_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
				if test_texture:
					print("[HeavyEnemy] Normal texture loaded successfully: ", test_texture.get_class())
					print("[HeavyEnemy] Normal texture size: ", test_texture.get_size())
				else:
					print("[HeavyEnemy] ERROR: Normal texture is null!")
			else:
				print("[HeavyEnemy] ERROR: Normal sprite has no sprite_frames!")
	
	# Update normal texture from normal sprite
	if sprite and sprite.material and normal_sprite.sprite_frames:
		var material = sprite.material as ShaderMaterial
		if material:
			var current_texture = normal_sprite.sprite_frames.get_frame_texture(normal_sprite.animation, normal_sprite.frame)
			if current_texture:
				material.set_shader_parameter("normal_texture", current_texture)
			else:
				print("[HeavyEnemy] ERROR: Normal texture is null for animation: ", normal_sprite.animation, " frame: ", normal_sprite.frame)
	

func update_sprite_direction() -> void:
	"""Update sprite direction based on movement and target position"""
	if target:
		var target_direction = sign(target.global_position.x - global_position.x)
		if target_direction != 0:
			direction = target_direction
	elif velocity.x != 0:
		direction = sign(velocity.x)
	
	# Flip sprite based on direction
	if sprite:
		sprite.flip_h = direction < 0
		# Don't flip normal sprite - this breaks normal mapping
		# Normal map direction will be handled in shader
		
		# Update shader with flip state
		if sprite.material:
			var material = sprite.material as ShaderMaterial
			if material:
				material.set_shader_parameter("sprite_flipped", direction < 0)
