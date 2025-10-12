class_name BaseEnemy
extends CharacterBody2D

# Preload autoloads
@onready var object_pool = get_node("/root/ObjectPool")

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)

# Core components
@export var stats: EnemyStats
@export var debug_enabled: bool = false

# Sleep state management
var is_sleeping: bool = false
var sleep_distance: float = 1000.0  # Distance at which enemy goes to sleep
var wake_distance: float = 800.0    # Distance at which enemy wakes up
var last_position: Vector2          # Store position when going to sleep
var last_behavior: String          # Store behavior when going to sleep

# Debug ID
var enemy_id: String = ""

# Node references
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var state_machine = $StateMachine

# Basic state tracking
var current_behavior: String = "idle"
var target: Node2D = null
var can_attack: bool = true
var attack_timer: float = 0.0
var health: float
var direction: int = 1
var behavior_timer: float = 0.0  # Timer for behavior state changes
var health_bar = null  # Add health bar reference

# Constants
const GRAVITY: float = 980.0
const FLOOR_SNAP: float = 32.0
const HURT_FLASH_DURATION := 0.1  # Duration of the red flash
const DEATH_KNOCKBACK_FORCE := 150.0  # Force applied when dying
const DEATH_UP_FORCE := 100.0  # Upward force when dying
const FALL_DELETE_TIME := 2.0  # Time after falling before deleting
const DEATH_FADE_INTERVAL := 0.4  # How often to fade in/out
const DEATH_FADE_MIN := 0.3  # Minimum opacity during fade
const DEATH_FADE_MAX := 0.8  # Maximum opacity during fade
const DEATH_FADE_SPEED := 2.0  # How fast to fade

var death_fade_timer: float = 0.0
var fade_out: bool = true  # Whether we're currently fading out or in

var invulnerable: bool = false
var invulnerability_timer: float = 0.0
const INVULNERABILITY_DURATION: float = 0.1  # Short invulnerability window

# Add debug print counter to avoid spam
var _debug_print_counter: int = 0
const DEBUG_PRINT_INTERVAL: int = 60  # Print every 60 frames

# Add static variable at class level
var _was_in_range := false

# Air hitstun float (juggle) settings
var air_float_timer: float = 0.0
@export var air_float_duration: float = 0.25
@export var air_float_gravity_scale: float = 0.35
@export var air_float_max_fall_speed: float = 420.0

func _ready() -> void:
	add_to_group("enemies")
	enemy_id = "%s_%d" % [get_script().resource_path.get_file().get_basename(), get_instance_id()]
	
	if stats:
		health = stats.max_health
	else:
		push_warning("No stats resource assigned to enemy!")
		health = 100.0
	
	var health_bar_scene = preload("res://ui/enemy_health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.position = Vector2(0, -60)
	health_bar.setup(health)
	# Notify initial health for external UI (e.g., boss bar)
	_health_emit_changed()
	
	call_deferred("_initialize_components")
	
	await get_tree().process_frame
	
	if global_position.is_equal_approx(Vector2.ZERO):
		push_warning("[Enemy:%s] Enemy initialized at origin (0,0)" % enemy_id)
		return
	
	last_position = global_position
	last_behavior = "idle"

func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if global_position == Vector2.ZERO:
		return
	
	# Only process movement and behavior if awake
	if not is_sleeping:
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
		handle_behavior(delta)
		
		# Apply gravity and move
		if not is_on_floor() and current_behavior != "dead":
			var g_scale := 1.0
			# Apply juggle float whenever timer is active, not only in hurt state
			if air_float_timer > 0.0:
				g_scale = air_float_gravity_scale
				air_float_timer = max(0.0, air_float_timer - delta)
			velocity.y += GRAVITY * g_scale * delta
			# Cap fall speed while float is active
			if air_float_timer > 0.0:
				velocity.y = min(velocity.y, air_float_max_fall_speed)
		# When hurt and moving upward, don't instantly cancel vertical velocity on floor contact
		if is_on_floor() and current_behavior == "hurt" and velocity.y < 0.0:
			# Skip vertical zeroing this frame to allow visible pop-up
			pass
		move_and_slide()

func handle_behavior(delta: float) -> void:
	# Remove sleep check from here since we're doing it in _physics_process
	if is_sleeping:
		return
		
	behavior_timer += delta
	
	# Get player within detection range for behavior
	target = get_nearest_player_in_range()
	
	match current_behavior:
		"patrol":
			handle_patrol(delta)
		"idle":
			handle_patrol(delta)
		"alert":
			handle_alert(delta)
		"chase":
			handle_chase(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return
	
	# Handle hurt state in base class first
	if current_behavior == "hurt":
		behavior_timer += delta
		
		# Only exit hurt state if timer is up AND mostly stopped
		if behavior_timer >= 0.2 and abs(velocity.x) <= 25:  # Reduced hurt state duration
			change_behavior("chase")
			# Make sure hurtbox is re-enabled
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
		return  # Don't let child classes override hurt behavior
	
	# Let child classes handle other behaviors
	_handle_child_behavior(delta)

# New function for child classes to override
func _handle_child_behavior(_delta: float) -> void:
	pass  # Child classes will override this

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		if Engine.get_physics_frames() % 60 == 0:  # Only print every ~1 second
			print("[BaseEnemy:%s] No players found in scene" % enemy_id)
		return null
	
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_player = player
	
	
	return nearest_player

func get_nearest_player_in_range() -> Node2D:
	var player = get_nearest_player()
	if !player:
		return null
		
	var distance = global_position.distance_to(player.global_position)
	var detection_range = stats.detection_range if stats else 300.0
	
	# Only print when detection status changes
	var is_in_range = distance <= detection_range
	
	if is_in_range != _was_in_range:
		_was_in_range = is_in_range
	
	return player if is_in_range else null

func start_attack_cooldown() -> void:
	can_attack = false
	attack_timer = stats.attack_cooldown if stats else 2.0

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	if current_behavior == "dead" or invulnerable:
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
	
	# Apply knockback (use explicit up_force if provided)
	velocity.x = -direction * knockback_force
	if knockback_up_force >= 0.0:
		velocity.y = -knockback_up_force
	else:
		velocity.y = -knockback_force * 0.5
	# If we have upward velocity from hit, start float window for juggle
	if velocity.y < 0.0:
		air_float_timer = air_float_duration
	
	# Enter hurt state
	change_behavior("hurt")
	behavior_timer = 0.0
	
	# Brief invulnerability
	invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	
	# Check for death
	if health <= 0:
		# Can barını hemen gizle (die() fonksiyonundan önce)
		if health_bar:
			health_bar.hide_bar()
		die()
	else:
		# Disable hurtbox briefly
		if hurtbox:
			hurtbox.monitoring = false
			hurtbox.monitorable = false

func _flash_hurt() -> void:
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)  # Red flash
		await get_tree().create_timer(HURT_FLASH_DURATION).timeout
		sprite.modulate = Color(1, 1, 1, 1)  # Reset color

func _apply_death_knockback() -> void:
	# Get direction from the last hit (player position)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		
		# Apply knockback force
		velocity = Vector2(
			dir.x * DEATH_KNOCKBACK_FORCE,
			-DEATH_UP_FORCE  # Negative for upward force
		)
		
		# Start fall delete timer when off screen or after maximum time
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func handle_hurt() -> void:
	if sprite:
		sprite.play("hurt")
	current_behavior = "hurt"
	behavior_timer = 0.0  # Reset behavior timer

func _on_hurt_animation_finished() -> void:
	pass  # No longer needed, behavior handles state changes

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
		sprite.play("death")
		# Set z_index above player (player z_index = 5)
		sprite.z_index = 6
	
	# Disable ALL collision to ensure falling through platforms
	collision_layer = 0
	collision_mask = 0
	
	# Disable components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Apply death knockback
	_apply_death_knockback()
	
	# Start fade out
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	fade_out = true
	
	# Don't return to pool - let corpses persist
	# await get_tree().create_timer(2.0).timeout
	# var scene_path = scene_file_path
	# var pool_name = scene_path.get_file().get_basename()
	# object_pool.return_object(self, pool_name)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.y = minf(velocity.y, GRAVITY)

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == "dead" and not force:
		return
		
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	# Play appropriate animation if available
	if sprite and sprite.has_method("play"):
		sprite.play(new_behavior)
		
	# Reset attack cooldown when changing behavior
	if new_behavior != "attack":
		can_attack = true
		attack_timer = 0.0

func _on_fall_timer_timeout() -> void:
	# Check if we're off screen or far below the ground
	if not is_on_screen() or global_position.y > 1000:
		# If we're dead and off screen, just queue_free
		if current_behavior == "dead":
			queue_free()
		else:
			# Start another timer if still alive
			var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
			fall_timer.timeout.connect(_on_fall_timer_timeout)
	else:
		# Start another timer if still on screen
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func is_on_screen() -> bool:
	if not is_instance_valid(self):
		return false
		
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return false
		
	var screen_rect = get_viewport_rect()
	var camera_pos = camera.get_screen_center_position()
	var top_left = camera_pos - screen_rect.size / 2
	var bottom_right = camera_pos + screen_rect.size / 2
	
	return global_position.x >= top_left.x - 100 and global_position.x <= bottom_right.x + 100 and \
		   global_position.y >= top_left.y - 100 and global_position.y <= bottom_right.y + 100

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	if current_behavior != "dead" and not invulnerable:
		var damage = hitbox.get_damage() if hitbox.has_method("get_damage") else 10.0
		var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0, "up_force": 100.0}
		print("[BaseEnemy:", enemy_id, "] hurt signal received dmg=", damage, " kb=", knockback_data.force)
		take_damage(damage, knockback_data.force, knockback_data.get("up_force", -1.0))

func _health_emit_changed() -> void:
	var max_h = stats.max_health if stats else 100.0
	health_changed.emit(health, max_h)
 
func _initialize_components() -> void:
	hurtbox = $Hurtbox
	if not hurtbox:
		push_error("Hurtbox node not found in enemy")
		return
	# Connect hurt signal if not already and if hurt signal exists
	if hurtbox.has_signal("hurt") and not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
		hurtbox.hurt.connect(_on_hurtbox_hurt)
		
	hitbox = $Hitbox
	if not hitbox:
		push_error("Hitbox node not found in enemy")
		return
		
	state_machine = $StateMachine
	if not state_machine:
		push_error("StateMachine node not found in enemy")
		return

func reset() -> void:
	# Reset all state when reusing from pool
	current_behavior = "idle"
	target = null
	can_attack = true
	attack_timer = 0.0
	health = stats.max_health if stats else 100.0
	direction = 1
	behavior_timer = 0.0
	invulnerable = false
	invulnerability_timer = 0.0
	velocity = Vector2.ZERO
	
	# Reset visuals
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		if sprite.has_method("play"):
			sprite.play("idle")
	
	# Reset health bar
	if health_bar:
		health_bar.setup(health)
		
	# Re-enable components
	if hitbox:
		hitbox.enable()
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
	

func handle_patrol(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_alert(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_chase(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_hurt_behavior(_delta: float) -> void:
	behavior_timer += _delta
	# Apply strong horizontal damping while hurt to avoid infinite drift
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * _delta)
	
	# Only exit hurt state if timer is up AND mostly stopped
	if behavior_timer >= 0.2 and abs(velocity.x) <= 25:  # Reduced hurt state duration
		change_behavior("chase")
		# Make sure hurtbox is re-enabled
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func check_sleep_state() -> void:
	if current_behavior == "dead" or not is_instance_valid(self):
		return
		
	var player = get_nearest_player()
	if !player:
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	if is_sleeping and distance <= wake_distance:
		wake_up()
	elif !is_sleeping and distance >= sleep_distance:
		# Don't go to sleep if we just spawned (give a grace period)
		if Engine.get_physics_frames() < 60:  # About 1 second grace period
			return
		go_to_sleep()

func go_to_sleep() -> void:
	if is_sleeping or current_behavior == "dead":
		return
			
	is_sleeping = true
	last_position = global_position
	last_behavior = current_behavior
	
	if self is FlyingEnemy:
		set_meta("last_velocity", velocity)
		set_meta("last_direction", direction)
	
	set_process(false)
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	if sprite and sprite.has_method("pause"):
		sprite.pause()

func wake_up() -> void:
	if !is_sleeping or current_behavior == "dead":
		return
			
	is_sleeping = false
	
	set_process(true)
	if hitbox:
		hitbox.enable()
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
	
	if self is FlyingEnemy:
		if has_meta("last_velocity"):
			velocity = get_meta("last_velocity")
		if has_meta("last_direction"):
			direction = get_meta("last_direction")
	
	if sprite and sprite.has_method("play"):
		sprite.play()
	
	if self is FlyingEnemy:
		if last_behavior == "neutral" and has_method("is_returning") and not get("is_returning"):
			change_behavior("chase")
		else:
			change_behavior(last_behavior)
	else:
		change_behavior(last_behavior)
