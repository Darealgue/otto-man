extends CharacterBody2D

signal health_changed(new_health: int)
signal died

@export var speed = 150.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox_collision = $Hurtbox/CollisionShape2D
@onready var hitbox_position = $Hitbox.position
@onready var player_detection_area = $PlayerDetectionArea
@onready var charge_detection_area = $ChargeDetectionArea
@onready var raycast_left = $RaycastLeft
@onready var raycast_right = $RaycastRight

const MAX_HEALTH = 50
const INVINCIBILITY_TIME = 0.01
const KNOCKBACK_FORCE = 300
const MIN_PATROL_TIME = 10.0
const MAX_PATROL_TIME = 15.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.0
const HURT_STATE_TIME = 0.5  # Slightly shorter stun
const KNOCKBACK_FRICTION = 300  # Slightly faster recovery
const KNOCKBACK_FORCE_X = 350  # Slightly less horizontal knockback
const KNOCKBACK_FORCE_Y = -250  # Slightly more vertical knockback

# Constants for behavior variety
const MIN_IDLE_TIME = 3.0
const MAX_IDLE_TIME = 7.0
const MIN_SPEED = 60.0
const MAX_SPEED = 100.0
const DIRECTION_CHANGE_CHANCE = 0.01  # 1% chance per frame to change direction during patrol

# Add these constants with the other behavior constants
const MIN_DIRECTION_CHANGE_TIME = 3.0  # Minimum seconds between direction changes

# Add these constants at the top with your other constants
const SLAM_DAMAGE = 25
const SLAM_CHARGE_TIME = 1.0
const SLAM_COOLDOWN = 3.0
const SHOCKWAVE_SPEED = 400
const SHOCKWAVE_RANGE = 600
const DETECTION_RANGE = 800.0  # How far enemy can see player
const SLAM_RANGE = 150.0       # Increased slam range
const CHARGE_MIN_RANGE = 1.0  # Increased to be outside slam range
const CHARGE_MAX_RANGE = 1000.0  # Keep max range
const CHARGE_DETECT_RANGE = 1000.0  # How far the charge detection reaches

# Add this constant for screen shake
const SLAM_SHAKE_STRENGTH = 4.0
const SLAM_SHAKE_DURATION = 0.3

# Add this at the top with other constants
# const DEBUG_STATE = true  # Toggle debug printing

# Add these after the constants and before _ready()
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction = -1
var is_idle = false
var timer = 0.0
var health: int = MAX_HEALTH
var is_invincible: bool = false
var invincibility_timer: float = 0
var is_attacking: bool = false
var can_move = true
var attack_timer: float = 0.0
var last_hit_direction: float = 1.0
var hurt_timer: float = 0
var current_patrol_time: float = MIN_PATROL_TIME
var rng = RandomNumberGenerator.new()

# Keep the existing State enum and other variables
enum State { IDLE, PATROL, ATTACK, HURT, DEAD, SLAM_CHARGE, SLAM_ATTACK, CHARGE_PREPARE, CHARGING }

var current_state: State = State.PATROL
var last_state: State = State.PATROL
var current_idle_time: float = MIN_IDLE_TIME
var base_speed: float = speed
var direction_change_timer: float = 0.0
var slam_timer = 0.0
var can_slam = true

# Keep the charge attack variables
var can_charge = true
var charge_cooldown_timer = 0.0
var charge_start_position = Vector2.ZERO

# Add these with your other constants
const CHARGE_PREPARE_TIME = 0.3  # Reduced from 0.5
const CHARGE_SPEED = 1000.0     # Increased from 800
const CHARGE_COOLDOWN = 2.0     # Reduced from 4.0
const CHARGE_DAMAGE = 20        # Damage dealt by charge

# Add this with other constants
const DIRECTION_CHANGE_COOLDOWN = 1.0  # Seconds between direction changes

# Add this near the top with other constants/preloads
const ShockwaveScene = preload("res://enemy/heavy/shockwave.tscn")

# Add these constants at the top with other constants
const GHOST_SPAWN_INTERVAL = 0.05  # How often to spawn ghosts during charge
const GHOST_DURATION = 0.3        # How long each ghost lasts
const GHOST_OPACITY = 0.3         # Starting opacity of ghosts

# Add this variable with other variables
var ghost_timer: float = 0

const DEATH_BOUNCE_FORCE_Y = -400  # Stronger upward bounce
const DEATH_BOUNCE_FORCE_X = 300   # Stronger horizontal bounce
const DEATH_FADE_DELAY = 0.6       # Total time (0.5s bounce + 0.1s fall)

const HealthBar = preload("res://ui/enemy_health_bar.tscn")

@onready var health_bar = null

# Add this with other preloads at the top
const DamageNumber = preload("res://ui/damage_number.tscn")

const BASE_ATTACK_DAMAGE = 15  # Add this with other constants

func _ready() -> void:
	if !animated_sprite:
		push_error("AnimatedSprite2D node not found!")
		queue_free()
		return
		
	add_to_group("enemy")
	_init_components()
	_connect_signals()
	rng.randomize()  # Initialize the random number generator
	
	# Setup health bar
	health_bar = HealthBar.instantiate()
	add_child(health_bar)
	health_bar.position = Vector2(-25, -30)  # Position above enemy, centered
	health_bar.setup(MAX_HEALTH)
	
	# Set up raycasts with proper collision detection
	if raycast_left and raycast_right:
		# Set collision properties
		raycast_left.collision_mask = 32  # Player hurtbox layer
		raycast_right.collision_mask = 32  # Player hurtbox layer
		raycast_left.collide_with_areas = true  # Detect hurtbox areas
		raycast_right.collide_with_areas = true
		raycast_left.collide_with_bodies = false
		raycast_right.collide_with_bodies = false
		
		raycast_left.target_position = Vector2(-CHARGE_MAX_RANGE, 0)
		raycast_right.target_position = Vector2(CHARGE_MAX_RANGE, 0)
		
		raycast_left.enabled = true
		raycast_right.enabled = true
		raycast_left.exclude_parent = true
		raycast_right.exclude_parent = true
		
	else:
		push_error("Raycasts not found! Check node names in scene.")

func _init_components() -> void:
	current_state = State.PATROL
	health = MAX_HEALTH
	
	# Randomize initial values
	current_patrol_time = rng.randf_range(MIN_PATROL_TIME, MAX_PATROL_TIME)
	current_idle_time = rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
	speed = rng.randf_range(MIN_SPEED, MAX_SPEED)
	
	if hitbox_collision:
		hitbox_collision.disabled = true

	if hitbox:
		if !hitbox.hit.is_connected(_on_hitbox_hit):
			hitbox.hit.connect(_on_hitbox_hit)
	else:
		push_error("No hitbox found in _init_components!")

func _connect_signals() -> void:
	if hitbox:
		# Disconnect existing connections first
		if hitbox.hit.is_connected(_on_hitbox_hit):
			hitbox.hit.disconnect(_on_hitbox_hit)
		
		# Now connect the signal
		hitbox.hit.connect(_on_hitbox_hit)
		hitbox.add_to_group("hitbox")
		
	if hurtbox:
		# Disconnect existing connections first
		if hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.disconnect(_on_hurtbox_hurt)
			
		# Now connect the signal
		hurtbox.hurt.connect(_on_hurtbox_hurt)
		hurtbox.add_to_group("hurtbox")
		
	if animated_sprite:
		# Disconnect existing connections first
		if animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_animation_finished)
			
		# Now connect the signal
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		# Keep applying gravity during death
		velocity.y += gravity * delta
		move_and_slide()
		return
		
	if current_state == State.HURT:
		pass
	
	if charge_cooldown_timer > 0:
		charge_cooldown_timer -= delta

	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		
		State.PATROL:
			
			handle_patrol_state(delta)
		
		State.ATTACK:
			handle_attack_state(delta)
		
		State.HURT:
			handle_hurt_state(delta)
		
		State.DEAD:
			handle_dead_state(delta)
		
		State.SLAM_CHARGE:
			handle_slam_charge_state(delta)
		
		State.SLAM_ATTACK:
			handle_slam_attack_state(delta)
		State.CHARGE_PREPARE:
			handle_charge_prepare_state(delta)
		State.CHARGING:
			handle_charging_state(delta)
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			if hurtbox_collision:
				hurtbox_collision.disabled = false
	
	if attack_timer > 0:
		attack_timer -= delta
	
	if can_move and !is_attacking:
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
		if can_attack() and player_in_range():
			choose_attack()
	
	move_and_slide()

func handle_idle_state(delta: float) -> void:
	velocity.x = 0
	animated_sprite.play("idle")
	
	timer += delta
	if timer >= current_idle_time:
		current_state = State.PATROL
		timer = 0
		# Set new random values for next cycle
		current_idle_time = rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
		speed = rng.randf_range(MIN_SPEED, MAX_SPEED)

func handle_patrol_state(delta: float) -> void:
	timer += delta
	direction_change_timer += delta
	
	# Only allow direction change after cooldown
	if direction_change_timer > 0:
		direction_change_timer -= delta
		
	if direction_change_timer <= 0 and rng.randf() < DIRECTION_CHANGE_CHANCE:
		direction *= -1
		animated_sprite.flip_h = direction < 0
		update_charge_detection()
	
	if timer >= current_patrol_time:
		current_state = State.IDLE
		timer = 0
		velocity.x = 0
		animated_sprite.play("idle")
		current_patrol_time = rng.randf_range(MIN_PATROL_TIME, MAX_PATROL_TIME)
		direction_change_timer = 0  # Reset direction timer when entering idle
		return
		
	if is_on_wall() or !check_floor_ahead():
		direction *= -1
		animated_sprite.flip_h = direction < 0
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
	velocity.x = direction * speed
	if !is_attacking:
		animated_sprite.play("walk")

func check_floor_ahead() -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(direction * 30, 50),
		collision_mask
	)
	var result = space.intersect_ray(query)
	return !result.is_empty()

func perform_attack() -> void:
	if is_attacking or !can_attack():
		return

	var player = get_nearest_player()
	if !player:
		return

	var distance = global_position.distance_to(player.global_position)

	# Face the player
	var to_player = player.global_position - global_position
	direction = sign(to_player.x)
	animated_sprite.flip_h = direction < 0

	# Check slam attack first (close range)
	if distance <= SLAM_RANGE:
		start_slam_attack()
		return

	# Then try charge attack (medium to long range)
	if distance >= CHARGE_MIN_RANGE and distance <= CHARGE_MAX_RANGE:
		if can_charge and charge_cooldown_timer <= 0:
			if player_in_charge_range():
				start_charge_attack()
				return

func enable_hitbox() -> void:
	if hitbox and hitbox_collision:
		hitbox_collision.set_deferred("disabled", false)
		hitbox.set_deferred("monitoring", true)
		await get_tree().create_timer(0.2).timeout
		hitbox_collision.set_deferred("disabled", true)
		hitbox.set_deferred("monitoring", false)
		is_attacking = false

func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	# Don't take damage if invincible or dead
	if is_invincible or current_state == State.DEAD:
		print("[DAMAGE DEBUG] Enemy damage ignored - Invincible: ", is_invincible, ", Dead: ", current_state == State.DEAD)
		return
		
	print("[DAMAGE DEBUG] Enemy taking damage:")
	print("- Amount: ", damage)
	print("- Current health: ", health)
	print("- Knockback direction: ", knockback_dir)
	print("- Current state: ", current_state)
	
	# Spawn damage number
	spawn_damage_number(damage)
	
	health = max(0, health - damage)
	health_changed.emit(health)
	
	print("[DAMAGE DEBUG] - New health: ", health)
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	
	if health <= 0:
		print("[DAMAGE DEBUG] Enemy health reached 0, initiating death")
		die(knockback_dir)  # Pass the knockback direction to die()
		return
	
	# Always become briefly invincible
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	
	# Show hit feedback during charge-up animations but don't interrupt them
	if current_state == State.SLAM_CHARGE or current_state == State.CHARGE_PREPARE:
		modulate = Color(1, 0.5, 0.5, 1)  # Red flash
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)
		print("[DAMAGE DEBUG] Hit during charge animation")
		return
		
	# Enter hurt state only if not in charge-up animations
	current_state = State.HURT
	hurt_timer = HURT_STATE_TIME
	can_move = false
	
	# Apply knockback
	velocity.x = KNOCKBACK_FORCE_X * sign(knockback_dir.x)
	velocity.y = KNOCKBACK_FORCE_Y
	last_hit_direction = sign(knockback_dir.x)
	
	# Cancel any ongoing attacks
	is_attacking = false
	can_slam = true
	can_charge = true
	
	# Play hurt animation
	animated_sprite.play("hurt")
	print("[DAMAGE DEBUG] Entered hurt state")

func die(knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return
		
	current_state = State.DEAD
	
	# Notify PowerupManager about the kill
	PowerupManager.enemy_killed(self)
	
	# Disable collisions
	if hitbox_collision:
		hitbox_collision.set_deferred("disabled", true)
	if hurtbox_collision:
		hurtbox_collision.set_deferred("disabled", true)
	
	# Apply death bounce
	velocity.y = DEATH_BOUNCE_FORCE_Y
	velocity.x = DEATH_BOUNCE_FORCE_X * last_hit_direction
	
	# Play death animation
	if animated_sprite:
		animated_sprite.play("death")
	
	# Emit died signal
	died.emit()
	
	# Start fade out timer
	await get_tree().create_timer(DEATH_FADE_DELAY).timeout
	queue_free()

func _on_hitbox_hit(area: Area2D) -> void:
	if area.is_in_group("hurtbox") and area.get_parent().is_in_group("player"):
		var damage = BASE_ATTACK_DAMAGE
		if hitbox and hitbox.has_method("get_damage"):
			damage = hitbox.get_damage()
		area.get_parent().take_damage(damage)  # Only pass the damage amount

func _on_hurtbox_hurt(area: Area2D) -> void:
	# Skip if area is not a hitbox
	if !area.is_in_group("hitbox"):
		return
		
	# Skip if we're already dead
	if current_state == State.DEAD:
		return
		
	# Only process player hitboxes
	if !area.get_parent().is_in_group("player"):
		return
		
	if area.has_method("get_damage"):
		var damage = area.get_damage()
		var knockback_dir = (global_position - area.global_position).normalized()
		take_damage(damage, knockback_dir)
		
		# Emit signal for hit registration
		if area.get_parent().has_signal("hit_landed"):
			area.get_parent().hit_landed.emit("Enemy hit for " + str(damage) + " damage")

func _on_animation_finished():
	match animated_sprite.animation:
		"slam_attack":
			current_state = State.PATROL
			is_attacking = false
			animated_sprite.play("idle")
			
		"slam_charge":
			perform_slam_attack()
			
		"charge_prepare":
			if current_state == State.CHARGE_PREPARE:
				current_state = State.CHARGING
				animated_sprite.play("charge_attack")
				velocity.x = direction * CHARGE_SPEED
			
		"charge_attack":
			if current_state == State.CHARGING:
				end_charge()

func can_attack() -> bool:
	return !is_attacking and attack_timer <= 0 and current_state != State.HURT

func choose_attack() -> void:
	var player = get_nearest_player()
	if !player:
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	# Check if player is in front of enemy
	var to_player = player.global_position - global_position
	var facing_player = sign(to_player.x) == direction
	
	if !facing_player:
		# Turn to face player
		direction *= -1
		animated_sprite.flip_h = direction < 0
		update_charge_detection()
		return
	
	if distance <= SLAM_RANGE:
		# Player is close enough for both attacks
		if randf() > 0.5 and can_slam:
			start_slam_attack()
		elif can_charge:
			start_charge_attack()
	elif distance <= CHARGE_MAX_RANGE and distance >= CHARGE_MIN_RANGE:
		# Player too far for slam, but in charge range
		if can_charge:
			start_charge_attack()

func player_in_range() -> bool:
	var player = get_nearest_player()
	if player:
		var distance = global_position.distance_to(player.global_position)
		# Player is in range if they're within either attack's range
		return (distance <= SLAM_RANGE) or (distance <= CHARGE_MAX_RANGE and distance >= CHARGE_MIN_RANGE)
	return false

func handle_attack_state(delta: float) -> void:
	velocity.x = 0
	if !is_attacking:
		current_state = State.PATROL

func handle_hurt_state(delta: float) -> void:
	# Apply friction to slow down knockback
	velocity.x = move_toward(velocity.x, 0, KNOCKBACK_FRICTION * delta)
	
	# Make sure hurt animation is playing
	if animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")
	
	# Update hurt timer
	hurt_timer -= delta
	
	# Check if we should exit hurt state
	if hurt_timer <= 0 and is_on_floor():
		velocity = Vector2.ZERO
		current_state = State.PATROL
		can_move = true
		direction = -last_hit_direction
		animated_sprite.flip_h = direction < 0
		hurt_timer = 0
		# Play idle animation when exiting hurt state
		animated_sprite.play("idle")

func handle_dead_state(delta: float) -> void:
	# Do nothing in dead state
	pass

func _on_damaged(amount: int) -> void:
	pass

func _process(delta: float) -> void:
	# Flash during death animation
	if current_state == State.DEAD and is_invincible:
		modulate.a = 0.5 + (sin(Time.get_ticks_msec() * 0.03) * 0.5)

func is_dead() -> bool:
	return current_state == State.DEAD

func handle_slam_charge_state(delta: float) -> void:
	velocity.x = 0
	slam_timer += delta
	
	if slam_timer >= SLAM_CHARGE_TIME:
		perform_slam_attack()

func handle_slam_attack_state(delta: float) -> void:
	velocity = Vector2.ZERO

func start_slam_attack() -> void:
	if current_state == State.SLAM_CHARGE:
		return  # Don't start another slam if we're already charging
		
	current_state = State.SLAM_CHARGE
	is_attacking = true
	slam_timer = 0
	animated_sprite.play("slam_charge")
	velocity = Vector2.ZERO

func perform_slam_attack() -> void:
	current_state = State.SLAM_ATTACK
	animated_sprite.play("slam_attack")
	
	# Spawn shockwaves immediately with the slam
	spawn_shockwaves()
	
	# Enable hitbox during slam attack
	if hitbox:
		hitbox.position = Vector2(0, 30)
		hitbox.damage = SLAM_DAMAGE
		hitbox.enable(0.3)
		
		await get_tree().create_timer(0.3).timeout
		hitbox.disable()
	else:
		push_error("No hitbox found for slam attack!")
	
	# Add screen shake
	shake_screen(SLAM_SHAKE_STRENGTH, SLAM_SHAKE_DURATION)
	
	# Start cooldown
	can_slam = false
	slam_timer = SLAM_COOLDOWN
	
	# Reset state after attack
	await get_tree().create_timer(0.5).timeout
	current_state = State.PATROL
	is_attacking = false
	
	# Start a timer to reset can_slam
	await get_tree().create_timer(SLAM_COOLDOWN).timeout
	can_slam = true

func spawn_shockwaves() -> void:
	# Create shockwaves going both left and right
	spawn_shockwave(1)  # Right
	spawn_shockwave(-1) # Left

func spawn_shockwave(direction: int) -> void:
	if !ShockwaveScene:
		return
		
	var shockwave = ShockwaveScene.instantiate()
	if !shockwave:
		return
		
	get_parent().add_child(shockwave)
	var feet_position = global_position + Vector2(0, 48)
	shockwave.global_position = feet_position
	
	if !shockwave.has_method("initialize"):
		return
		
	shockwave.initialize(direction, SHOCKWAVE_SPEED, SHOCKWAVE_RANGE, SLAM_DAMAGE)

func create_slam_effect() -> Node2D:
	# Create a simple visual effect for the slam
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.amount = 20
	effect.lifetime = 0.5
	effect.direction = Vector2.UP
	effect.gravity = Vector2(0, 980)
	effect.initial_velocity_min = 200.0
	effect.initial_velocity_max = 300.0
	
	# Auto-free when done
	var timer = Timer.new()
	effect.add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(effect.queue_free)
	timer.start()
	
	return effect

func get_nearest_player():
	if !player_detection_area:
		return null
		
	var shortest_distance = DETECTION_RANGE  # Changed back to DETECTION_RANGE
	var nearest_player = null
	
	var overlapping = player_detection_area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player"):
			var distance = global_position.distance_to(body.global_position)
			if distance < shortest_distance:
				shortest_distance = distance
				nearest_player = body
	
	return nearest_player

func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		print("Player entered detection range")

func _on_detection_area_body_exited(body: Node2D):
	print("Body exited detection area: ", body.name)

func shake_screen(strength: float, duration: float) -> void:
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		var tween = create_tween()
		for i in range(int(duration / 0.05)):
			var offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
			tween.tween_property(camera, "offset", offset, 0.05)
		
		# Reset camera position
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func start_charge_attack() -> void:
	current_state = State.CHARGE_PREPARE
	is_attacking = true
	can_charge = false
	charge_start_position = global_position
	velocity.x = 0  # Stop movement
	ghost_timer = 0  # Reset ghost timer
	
	animated_sprite.play("charge_prepare")

func handle_charge_prepare_state(delta: float) -> void:
	velocity.x = 0  # Stand still while preparing

func handle_charging_state(delta: float) -> void:
	# Keep charging until we hit something or travel max distance
	var distance_charged = abs(global_position.x - charge_start_position.x)
	
	# Handle ghost effect
	ghost_timer -= delta
	if ghost_timer <= 0:
		ghost_timer = GHOST_SPAWN_INTERVAL
		spawn_ghost()
	
	if is_on_wall() or distance_charged > CHARGE_MAX_RANGE:
		end_charge()
		return
		
	# Enable hitbox during charge
	if hitbox:
		hitbox.damage = CHARGE_DAMAGE  # Set the damage amount
		hitbox.get_node("CollisionShape2D").set_deferred("disabled", false)
		hitbox.set_deferred("monitoring", true)
	else:
		push_error("No hitbox found for charge attack!")

func end_charge() -> void:
	current_state = State.PATROL
	is_attacking = false
	velocity.x = 0
	animated_sprite.play("idle")
	
	# Disable hitbox
	if hitbox and hitbox.get_node("CollisionShape2D"):
		hitbox.get_node("CollisionShape2D").set_deferred("disabled", true)
		hitbox.set_deferred("monitoring", false)
	
	# Start cooldown
	charge_cooldown_timer = CHARGE_COOLDOWN
	await get_tree().create_timer(CHARGE_COOLDOWN).timeout
	can_charge = true

func player_in_charge_range() -> bool:
	var raycast = raycast_right if direction > 0 else raycast_left
	if !raycast:
		return false
		
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.is_in_group("player"):
			var distance = global_position.distance_to(collider.global_position)
			return distance >= CHARGE_MIN_RANGE and distance <= CHARGE_MAX_RANGE
	
	return false

func update_charge_detection() -> void:
	if charge_detection_area:
		# Position the detection area in front of the enemy based on direction
		charge_detection_area.position.x = abs(charge_detection_area.position.x) * direction
		
		# Also update the collision shape's rotation
		var shape = charge_detection_area.get_node("CollisionShape2D")
		if shape:
			shape.rotation = 0 if direction > 0 else PI  # Rotate 180 degrees when facing left
		
		# Force redraw to update visualization
		queue_redraw()

func get_charge_target():
	if !charge_detection_area:
		return null
		
	var shortest_distance = CHARGE_MAX_RANGE
	var target = null
	
	var overlapping = charge_detection_area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player"):
			var distance = global_position.distance_to(body.global_position)
			if distance >= CHARGE_MIN_RANGE and distance <= CHARGE_MAX_RANGE:
				if distance < shortest_distance:
					shortest_distance = distance
					target = body
	
	return target

func get_slam_target():
	if !player_detection_area:
		return null
		
	var shortest_distance = SLAM_RANGE
	var nearest_player = null
	
	var overlapping = player_detection_area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player"):
			var distance = global_position.distance_to(body.global_position)
			if distance <= SLAM_RANGE:  # Only detect within slam range
				if distance < shortest_distance:
					shortest_distance = distance
					nearest_player = body
	
	return nearest_player

func spawn_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.global_position = global_position
	ghost.flip_h = animated_sprite.flip_h
	ghost.scale = scale
	ghost.modulate = Color(1, 1, 1, GHOST_OPACITY)
	ghost.z_index = z_index - 1  # Place ghost behind the enemy
	get_parent().add_child(ghost)
	
	# Create fade out tween
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_DURATION)
	tween.tween_callback(ghost.queue_free)

func spawn_damage_number(damage: int) -> void:
	if !DamageNumber:
		return
		
	var number = DamageNumber.instantiate()
	get_parent().add_child(number)
	
	# Position the number at the enemy's position with a slight offset
	number.global_position = global_position + Vector2(0, -30)
	
	# Setup the number
	number.setup(damage)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var damage = BASE_ATTACK_DAMAGE  # Use the constant directly
		var knockback_dir = (area.global_position - global_position).normalized()
		
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)  # Only pass damage amount
			
		# Apply knockback separately if needed
		if area.get_parent() is CharacterBody2D:
			area.get_parent().velocity = knockback_dir * KNOCKBACK_FORCE

func get_attack_damage() -> int:
	return BASE_ATTACK_DAMAGE
