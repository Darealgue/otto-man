class_name HeavyEnemy
extends BaseEnemy

# Attack properties
var charge_speed: float = 500.0
var charge_damage: float = 25.0
var charge_duration: float = 2.0
var charge_timer: float = 0.0
var slam_damage: float = 37.0
var slam_range: float = 150.0
var charge_range: float = 400.0  # Increased from 200
var detection_range: float = 500.0  # Increased from 250
var chase_duration: float = 4.0  # How long enemy will chase before giving up
var slam_radius: float = 150.0  # Radius of slam attack damage area

# Behavior timers
var behavior_timer: float = 0.0
var hurt_duration: float = 0.5
var behavior_change_delay: float = 0.5  # Minimum time before changing behaviors
var last_behavior_change: float = 0.0

# Patrol and detection properties
var patrol_point_left: float = 0.0
var patrol_point_right: float = 0.0
var patrol_point_wait_time: float = 1.5
var alert_duration: float = 0.8
var has_seen_player: bool = false

var original_collision_shape: Shape2D

@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var slam_effect = $SlamEffect  # Reference to the visual effect node
@onready var raycast_left = $RayCastLeft
@onready var raycast_right = $RayCastRight

func _ready() -> void:
	super._ready()
	current_behavior = "patrol"
	if sprite:
		sprite.play("idle")
	# Set up patrol points relative to starting position with increased range
	patrol_point_left = global_position.x - 300  # Increased from 100
	patrol_point_right = global_position.x + 300  # Increased from 100
	# Make sure hitbox is disabled initially
	if hitbox:
		hitbox.disable()
		hitbox.damage = stats.attack_damage if stats else 25.0  # Set base damage
		# Set collision layers for hitbox
		hitbox.collision_layer = 64  # Layer 7 (Enemy hitbox)
		hitbox.collision_mask = 8    # Layer 4 (Player hurtbox)
		print("[HeavyEnemy] Setting up hitbox - Layer:", hitbox.collision_layer, " Mask:", hitbox.collision_mask)
	
	if hurtbox:
		# Set collision layers for hurtbox
		hurtbox.collision_layer = 32  # Layer 6 (Enemy hurtbox)
		hurtbox.collision_mask = 16   # Layer 5 (Player hitbox)
		print("[HeavyEnemy] Setting up hurtbox - Layer:", hurtbox.collision_layer, " Mask:", hurtbox.collision_mask)
	
	# Store the original collision shape for charge attack
	if hitbox_collision:
		original_collision_shape = hitbox_collision.shape.duplicate()

func change_behavior(new_behavior: String) -> void:
	if current_behavior == new_behavior:
		return
		
	# Don't change behaviors too quickly
	if behavior_timer < behavior_change_delay:
		return
	
	# Disable hitbox when changing behaviors (safety check)
	if hitbox and current_behavior in ["charging", "slam"]:
		hitbox.disable()
		
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	# Set appropriate animation for new behavior
	match new_behavior:
		"patrol":
			sprite.play("walk")
			has_seen_player = false
		"idle":
			sprite.play("idle")
		"alert":
			sprite.play("idle")  # You might want to create an alert animation
			if debug_enabled:
				print("[HeavyEnemy] Alert! Spotted player!")
		"chase":
			sprite.play("walk")
		"charge_prepare":
			sprite.play("charge_prepare")
			velocity.x = 0
		"charging":
			sprite.play("charge")
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

func handle_behavior(delta: float) -> void:
	behavior_timer += delta
	
	match current_behavior:
		"patrol":
			handle_patrol(delta)
		"idle":
			handle_patrol(delta)  # Will handle the waiting at patrol points
		"alert":
			handle_alert(delta)
		"chase":
			handle_chase(delta)
		"charge_prepare":
			handle_charge_prepare(delta)
		"charging":
			handle_charging(delta)
		"slam_prepare":
			handle_slam_prepare(delta)
		"slam":
			handle_slam(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return  # Do nothing when dead

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		# Check if player is in front of enemy based on direction
		var dir_to_player = sign(player.global_position.x - global_position.x)
		var is_in_front = dir_to_player == direction
		
		# Only detect if player is in front and within range
		if distance < min_distance and distance <= detection_range and is_in_front:
			min_distance = distance
			nearest = player
	
	return nearest

func handle_patrol(delta: float) -> void:
	# Check for player first
	target = get_nearest_player()
	if target and not has_seen_player:
		change_behavior("alert")
		return
		
	# Check for edges using raycasts
	var left_ray = raycast_left.is_colliding()
	var right_ray = raycast_right.is_colliding()
	
	# Turn around if about to walk off edge
	if direction < 0 and not left_ray:
		direction = 1
		sprite.flip_h = false
		behavior_timer = 0.0
		return
	elif direction > 0 and not right_ray:
		direction = -1
		sprite.flip_h = true
		behavior_timer = 0.0
		return
		
	# If at patrol point, wait
	if abs(velocity.x) < 5:
		if behavior_timer < patrol_point_wait_time:
			if sprite.animation != "idle":
				sprite.play("idle")
			return
		else:
			# After waiting, turn around and continue patrol
			direction *= -1
			sprite.flip_h = direction < 0
			sprite.play("walk")
			behavior_timer = 0.0
	
	# Move towards patrol point
	var target_x = patrol_point_right if direction > 0 else patrol_point_left
	if abs(global_position.x - target_x) < 10:
		velocity.x = 0
		behavior_timer = 0.0  # Start waiting
	else:
		velocity.x = direction * (stats.movement_speed if stats else 100.0)

func handle_alert(delta: float) -> void:
	velocity.x = 0
	if behavior_timer >= alert_duration:
		has_seen_player = true
		change_behavior("chase")
		behavior_timer = 0.0

func handle_chase(delta: float) -> void:
	# Check chase duration
	if behavior_timer >= chase_duration:
		if debug_enabled:
			print("[HeavyEnemy] Lost sight of player - returning to patrol")
		change_behavior("patrol")
		target = null
		return
	
	target = get_nearest_player()
	if not target:
		if debug_enabled:
			print("[HeavyEnemy] Lost sight of player - returning to patrol")
		change_behavior("patrol")
		return
	
	var distance = global_position.distance_to(target.global_position)
	var dir_to_player = sign(target.global_position.x - global_position.x)
	
	# Update facing direction and adjust hitbox position
	if dir_to_player != direction:
		direction = dir_to_player
		sprite.flip_h = direction < 0
		# Adjust hitbox position based on direction
		if hitbox:
			hitbox.position.x = abs(hitbox.position.x) * direction
	
	# Choose attack based on distance
	if can_attack and behavior_timer >= behavior_change_delay:
		if distance <= slam_range:
			change_behavior("slam_prepare")
			return
		elif distance <= charge_range:
			change_behavior("charge_prepare")
			return
	
	# Move towards player
	velocity.x = direction * (stats.movement_speed if stats else 100.0)

func handle_charge_prepare(delta: float) -> void:
	if behavior_timer >= 0.5:  # Charge preparation time
		change_behavior("charging")
		# Store the direction at the start of charge
		velocity.x = direction * charge_speed
		# Set up hitbox for charge attack
		if hitbox_collision:
			# Create a rectangular shape for the charge attack
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(40, 60)  # Adjust size as needed
			hitbox_collision.shape = rect_shape
			# Position hitbox in front of enemy based on direction
			hitbox.position.x = 30 * direction  # Adjust offset as needed
			hitbox.position.y = 0  # Center vertically

func handle_charging(delta: float) -> void:
	if is_on_wall():
		velocity.x = 0
		current_behavior = "chase"
		hitbox.disable()
		# Restore original collision shape
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()
		return
		
	# Only enable hitbox once at the start of charge
	if not hitbox.is_enabled():
		hitbox.damage = charge_damage
		hitbox.knockback_force = 700.0  # Increased horizontal knockback for charge
		hitbox.knockback_up_force = 0.0  # No upward force for charge
		hitbox.enable()
	
	velocity.x = charge_speed * direction
	move_and_slide()
	
	# Check if we've charged past the player
	if target and ((direction > 0 and global_position.x > target.global_position.x) or \
	   (direction < 0 and global_position.x < target.global_position.x)):
		current_behavior = "chase"
		hitbox.disable()
		# Restore original collision shape
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()
		return
	
	charge_timer += delta
	if charge_timer >= charge_duration:
		current_behavior = "chase"
		hitbox.disable()
		# Restore original collision shape
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()
		charge_timer = 0.0

func handle_slam_prepare(delta: float) -> void:
	if behavior_timer >= 0.5:  # Slam preparation time
		change_behavior("slam")

func handle_slam(delta: float) -> void:
	# Create damage area when the animation reaches the impact frame
	if sprite.frame == 2 and not hitbox.is_enabled():  # Only enable if not already enabled
		create_slam_damage()
		start_attack_cooldown()
	
	# Check if animation is finished
	if not sprite.is_playing() or sprite.frame >= sprite.sprite_frames.get_frame_count("slam") - 1:
		# Restore original collision shape
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()
		change_behavior("chase")
		if debug_enabled:
			print("[HeavyEnemy] Slam animation finished, changing to chase")

func create_slam_damage() -> void:
	# Create a circular hitbox for the slam attack
	if hitbox_collision:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = slam_radius
		hitbox_collision.shape = circle_shape
		
		# Center the hitbox on the enemy
		hitbox.position = Vector2.ZERO
	
	# Enable hitbox for slam with strong vertical knockback
	hitbox.damage = slam_damage
	hitbox.knockback_force = 200.0  # Slightly reduced horizontal knockback
	hitbox.knockback_up_force = 300.0  # Reduced upward force but still significant
	hitbox.enable()
	if debug_enabled:
		print("[HeavyEnemy] Created slam damage area with radius:", slam_radius)
	
	# Create visual effect for slam
	sprite.play("slam")
	
	# Show shockwave effect
	if slam_effect:
		# Create points for a circle
		var points = PackedVector2Array()
		var num_points = 32  # Number of points in the circle
		for i in range(num_points + 1):
			var angle = i * 2 * PI / num_points
			var point = Vector2(cos(angle), sin(angle)) * slam_radius
			points.append(point)
		
		slam_effect.points = points
		slam_effect.show()
		slam_effect.modulate = Color(1, 0.8, 0.2, 1.0)  # Start fully visible
		
		# Create expanding and fading effect
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Scale up the points
		var expanded_points = PackedVector2Array()
		for point in points:
			expanded_points.append(point * 1.5)  # Expand to 1.5x size
		
		# Animate the circle expansion
		tween.tween_property(slam_effect, "points", expanded_points, 0.3)
		
		# Fade out
		tween.tween_property(slam_effect, "modulate", Color(1, 0.8, 0.2, 0), 0.3)
		
		# Hide after animation
		await tween.finished
		slam_effect.hide()
	
	# Disable hitbox after a short duration
	await get_tree().create_timer(0.2).timeout
	hitbox.disable()

func handle_hurt_behavior(delta: float) -> void:
	if behavior_timer >= hurt_duration:
		change_behavior("chase")

func _on_hitbox_hit(area: Area2D) -> void:
	if debug_enabled:
		print("[HeavyEnemy] Hit something:", area.get_parent().name)

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if current_behavior != "dead":
		var damage = hitbox.get_damage() if hitbox.has_method("get_damage") else 10.0
		take_damage(damage)
