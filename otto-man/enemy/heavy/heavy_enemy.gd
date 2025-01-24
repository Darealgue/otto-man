class_name HeavyEnemy
extends BaseEnemy

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
const chase_duration := 4.0    # How long to chase before trying an attack

# Charge attack properties
const charge_speed := 500.0    # Speed during charge attack
const charge_duration := 2.0   # How long the charge lasts
var charge_timer: float = 0.0  # Current charge time

# Behavior timers
var behavior_change_delay: float = 0.5
var last_behavior_change: float = 0.0
var direction_change_cooldown: float = 0.5
var last_direction_change: float = 0.0
var vertical_tolerance: float = 100.0

# Patrol and detection properties
var patrol_point_wait_time: float = 1.5
var alert_duration: float = 0.8
var has_seen_player: bool = false

var memory_duration: float = 1.5
var memory_timer: float = 0.0
var last_known_player_pos: Vector2 = Vector2.ZERO

const CHARGE_DECELERATION := 4000.0  # Increased from 2000 to 4000
const CHARGE_END_THRESHOLD := 0.8  # Start slowing down at 80% of charge duration

@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var slam_effect = $SlamEffect
@onready var raycast_left = $RayCastLeft
@onready var raycast_right = $RayCastRight

func _ready() -> void:
	super._ready()
	current_behavior = "patrol"
	if sprite:
		sprite.play("idle")
	patrol_point_left = global_position.x - 300
	patrol_point_right = global_position.x + 300
	
	if hitbox:
		hitbox.disable()
		hitbox.damage = stats.attack_damage if stats else 25.0
		hitbox.collision_layer = 64
		hitbox.collision_mask = 8
	
	if hurtbox:
		hurtbox.collision_layer = 32
		hurtbox.collision_mask = 16
	
	if hitbox_collision:
		original_collision_shape = hitbox_collision.shape.duplicate()

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior:
		return
		
	if not force and behavior_timer < behavior_change_delay:
		return
	
	
	if hitbox and current_behavior in ["charging", "slam"]:
		hitbox.disable()
		
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
			handle_patrol(delta)
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
			return

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		var dir_to_player = sign(player.global_position.x - global_position.x)
		
		if distance <= detection_range:
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				global_position,
				player.global_position,
				1
			)
			query.exclude = [self, player]
			var result = space_state.intersect_ray(query)
			
			if not result and distance < min_distance:
				min_distance = distance
				nearest = player
	
	return nearest

func handle_patrol(delta: float) -> void:
	target = get_nearest_player()
	if target and not has_seen_player:
		change_behavior("alert")
		return
		
	var left_ray = raycast_left.is_colliding()
	var right_ray = raycast_right.is_colliding()
	
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
		
	if abs(velocity.x) < 5:
		if behavior_timer < patrol_point_wait_time:
			if sprite.animation != "idle":
				sprite.play("idle")
			return
		else:
			direction *= -1
			sprite.flip_h = direction < 0
			sprite.play("walk")
			behavior_timer = 0.0
	
	var target_x = patrol_point_right if direction > 0 else patrol_point_left
	if abs(global_position.x - target_x) < 10:
		velocity.x = 0
		behavior_timer = 0.0
	else:
		velocity.x = direction * (stats.movement_speed if stats else 100.0)

func handle_alert(delta: float) -> void:
	velocity.x = 0
	if behavior_timer >= alert_duration:
		has_seen_player = true
		change_behavior("chase")
		behavior_timer = 0.0

func handle_chase(delta: float) -> void:
	if behavior_timer >= chase_duration:
		change_behavior("patrol")
		target = null
		memory_timer = 0.0
		return
	
	target = get_nearest_player()
	
	if target:
		last_known_player_pos = target.global_position
		memory_timer = memory_duration
		
		var distance = global_position.distance_to(target.global_position)
		var height_diff = target.global_position.y - global_position.y
		var dir_to_player = sign(target.global_position.x - global_position.x)
		
		if abs(height_diff) <= vertical_tolerance and last_direction_change >= direction_change_cooldown:
			if dir_to_player != direction:
				direction = dir_to_player
				sprite.flip_h = direction < 0
				if hitbox:
					hitbox.position.x = abs(hitbox.position.x) * direction
				last_direction_change = 0.0
		
		last_direction_change += delta
		
		if can_attack and behavior_timer >= behavior_change_delay:
			if distance <= slam_range:
				change_behavior("slam_prepare")
				return
			elif distance <= charge_range and abs(height_diff) <= vertical_tolerance:
				change_behavior("charge_prepare")
				return
		
		velocity.x = direction * (stats.movement_speed if stats else 100.0)
	else:
		memory_timer -= delta
		
		if memory_timer > 0:
			var dir_to_last_pos = sign(last_known_player_pos.x - global_position.x)
			var distance_to_last_pos = global_position.distance_to(last_known_player_pos)
			
			if dir_to_last_pos != direction and last_direction_change >= direction_change_cooldown:
				direction = dir_to_last_pos
				sprite.flip_h = direction < 0
				last_direction_change = 0.0
			
			last_direction_change += delta
			
			if distance_to_last_pos > 20:
				velocity.x = direction * (stats.movement_speed if stats else 100.0)
			else:
				velocity.x = 0
		else:
			change_behavior("patrol")
			target = null

func handle_charge_prepare(delta: float) -> void:
	if behavior_timer >= 0.5:
		charge_timer = 0.0  # Reset charge timer when starting charge
		change_behavior("charging")
		velocity.x = direction * charge_speed
		if hitbox_collision:
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(40, 60)
			hitbox_collision.shape = rect_shape
			hitbox.position.x = 30 * direction
			hitbox.position.y = 0
			
			# Set up and enable hitbox for charge attack
			hitbox.damage = charge_damage
			hitbox.knockback_force = 700.0  # Strong horizontal force for charge
			hitbox.knockback_up_force = 0.0  # No upward force for pure horizontal knockback
			hitbox.enable()

func handle_charging(delta: float) -> void:
	charge_timer += delta
	
	if charge_timer >= charge_duration:
		change_behavior("chase")
		if hitbox:
			hitbox.disable()
		return
	
	# Apply charge movement
	velocity.x = direction * charge_speed
	
	# Check for parry
	if hitbox and hitbox.is_parried:
		hitbox.disable()
		hitbox.is_parried = false  # Reset parry state
		
		# Re-enable hurtbox
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true
		
		# Take damage and enter hurt state
		take_damage(25.0, 400.0)  # Higher knockback when parried
		return

func handle_slam_prepare(delta: float) -> void:
	if behavior_timer >= 0.5:
		change_behavior("slam")

func handle_slam(delta: float) -> void:
	if sprite.frame == 2 and not hitbox.is_enabled():
		create_slam_damage()
		start_attack_cooldown()
	
	if sprite.frame >= sprite.sprite_frames.get_frame_count("slam") - 1:
		if hitbox_collision and original_collision_shape:
			hitbox_collision.shape = original_collision_shape.duplicate()
		change_behavior("chase", true)

func create_slam_damage() -> void:
	if hitbox_collision:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = slam_radius
		hitbox_collision.shape = circle_shape
		hitbox.position = Vector2.ZERO
	
	hitbox.damage = slam_damage
	hitbox.knockback_force = 400.0  # Strong outward force
	hitbox.knockback_up_force = 500.0  # Strong upward force for slam
	
	# Connect to hit signal if not already connected
	if not hitbox.is_connected("area_entered", _on_slam_hitbox_hit):
		hitbox.area_entered.connect(_on_slam_hitbox_hit)
	
	hitbox.enable()
	sprite.play("slam")
	
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
	
	await get_tree().create_timer(0.2).timeout
	hitbox.disable()
	if hitbox.is_connected("area_entered", _on_slam_hitbox_hit):
		hitbox.area_entered.disconnect(_on_slam_hitbox_hit)

func _on_slam_hitbox_hit(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		hitbox.disable()
		if hitbox.is_connected("area_entered", _on_slam_hitbox_hit):
			hitbox.area_entered.disconnect(_on_slam_hitbox_hit)

func handle_hurt_behavior(delta: float) -> void:
	behavior_timer += delta
	
	# Ensure hurt animation is playing
	if sprite and sprite.sprite_frames.has_animation("hurt") and sprite.animation != "hurt":
		sprite.play("hurt")
	
	# Only exit hurt state if both timer is up AND knockback has slowed down significantly
	# Increased thresholds to allow for stronger knockback
	if behavior_timer >= hurt_duration and abs(velocity.x) <= 100 and abs(velocity.y) <= 100:
		change_behavior("chase")

func _on_hitbox_hit(area: Area2D) -> void:
	pass

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if current_behavior != "dead":
		var damage = hitbox.get_damage() if hitbox.has_method("get_damage") else 10.0
		var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0}
		take_damage(damage, knockback_data.get("force", 200.0))

func take_damage(amount: float, knockback_force: float = 200.0) -> void:
	# Don't take damage if already dead
	if current_behavior == "dead":
		return
		
	# List of states where enemy should be uninterruptible
	var uninterruptible_states = ["charge_prepare", "charging", "slam_prepare", "slam"]
	
	# Apply damage and effects
	if stats:
		health -= amount
		
		# Update health bar
		if health_bar:
			health_bar.update_health(health)
		
		# Spawn damage number
		var damage_number = preload("res://effects/damage_number.tscn").instantiate()
		add_child(damage_number)
		damage_number.global_position = global_position + Vector2(0, -50)
		damage_number.setup(int(amount))
		
		# Flash red
		_flash_hurt()
		
		# Check for death
		if health <= 0:
			die()
			return
	
	# Handle knockback and state changes
	if not uninterruptible_states.has(current_behavior):
		# Apply knockback
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var dir = (global_position - player.global_position).normalized()
			velocity = Vector2(
				dir.x * knockback_force,
				-knockback_force * 0.5  # Reduced vertical knockback
			)
		
		# Change to hurt state
		change_behavior("hurt", true)

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
	
	# Play death animation
	if sprite:
		sprite.play("dead")
	
	# Set initial death velocity with reduced knockback
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		velocity = Vector2(
			dir.x * DEATH_KNOCKBACK_FORCE * 0.3,  # Reduced horizontal knockback
			-DEATH_UP_FORCE * 1.2  # Increased upward force
		)
	# Disable ALL collision except with ground
	collision_layer = 0  # No collision with anything
	collision_mask = 1   # Only collide with environment
	set_collision_layer_value(1, false)  # Ensure no world collision
	set_collision_layer_value(2, false)  # Ensure no player collision
	set_collision_layer_value(3, false)  # Ensure no enemy collision
	set_collision_mask_value(2, false)   # Don't collide with player
	
	# Disable combat components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Emit signals and notify systems
	enemy_defeated.emit()
	PowerupManager.on_enemy_killed()
	
	# Start fade out after a longer delay
	await get_tree().create_timer(4.0).timeout  # Increased from 2.0 to 4.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2.0)  # Increased fade duration from 1.0 to 2.0
	await tween.finished
	
	# Return to object pool
	var pool_name = scene_file_path.get_file().get_basename()
	object_pool.return_object(self, pool_name)

func _physics_process(delta: float) -> void:
	# Apply gravity regardless of state
	velocity.y += GRAVITY * delta
	
	match current_behavior:
		"dead":
			
			# Slow down horizontal movement during death
			velocity.x = move_toward(velocity.x, 0, GRAVITY * delta * 2.0)
			if velocity.y > 0:  # If falling
				velocity.x = 0  # Stop horizontal movement completely
			
			# Only move vertically in death state
			var saved_x = global_position.x
			move_and_slide()
			global_position.x = saved_x  # Force X position to stay the same
			return
		_:  # For all other states
			handle_behavior(delta)
			move_and_slide()

func get_behavior() -> String:
	return current_behavior
