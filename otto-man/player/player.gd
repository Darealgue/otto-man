extends CharacterBody2D

signal health_changed(new_health: float)
signal perfect_parry  # Signal for Perfect Guard powerup
signal dash_started

@export var speed: float = 450.0
@export var jump_velocity: float = 600.0
@export var double_jump_velocity: float = 550.0
@export var acceleration: float = 3000.0
@export var air_acceleration: float = 1500.0  # Lower acceleration in air for better momentum
@export var friction: float = 2000.0
@export var air_friction: float = 200.0  # Much lower friction in air to preserve momentum
@export var stop_friction_multiplier: float = 2.0
@export var air_control_multiplier: float = 0.5  # Reduced from 0.65 for more precise control
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var fall_gravity_multiplier: float = 2.0
@export var max_fall_speed: float = 2000.0
@export var jump_cut_height: float = 0.5
@export var max_jump_time: float = 0.4
@export var jump_horizontal_dampening: float = 0.9
@export var wall_slide_speed: float = 150.0
@export var wall_jump_velocity: Vector2 = Vector2(450.0, -600.0)
@export var wall_slide_gravity_multiplier: float = 0.5
@export var wall_stick_force: float = 20.0
@export var wall_stick_distance: float = 15.0
@export var wall_jump_horizontal_dampening: float = 0.2
@export var wall_jump_boost: float = 1.5
@export var wall_detach_boost: float = 300.0
@export var wall_jump_momentum_preservation: float = 0.8
@export var wall_jump_control_delay: float = 0.15
@export var debug_enabled: bool = false
@export var precision_air_control_multiplier: float = 0.9  # How much control player has in air when holding down
@export var precision_air_friction: float = 400.0  # Higher air friction when holding down for more precise control
@export var air_momentum_cancel_rate: float = 0.85  # How quickly to reduce horizontal velocity when releasing direction in air

const COYOTE_TIME := 0.15  # Time in seconds player can still jump after leaving ground
const FALL_GRAVITY_MULTIPLIER := 1.5  # Makes falling faster than rising

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_double_jump: bool = false
var has_double_jumped: bool = false
var coyote_timer: float = 0.0
var was_on_floor: bool = false
var jump_timer: float = 0.0
var is_jumping: bool = false
var jump_buffer_timer: float = 0.0
var current_gravity_multiplier: float = 1.0
var is_wall_sliding: bool = false
var wall_normal: Vector2 = Vector2.ZERO
var can_wall_jump: bool = true
var wall_jump_timer: float = 0.0
var is_wall_jumping: bool = false
var wall_jump_direction: float = 0.0
var wall_jump_boost_timer: float = 0.0
var last_hit_position: Vector2 = Vector2.ZERO
var last_hit_knockback: Dictionary = {}
var ledge_grab_cooldown_timer: float = 0.0  # Cooldown timer for ledge grabbing
var invincibility_timer: float = 0.0  # Invincibility timer after getting hit

# Stats multipliers for powerups
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var base_damage: float = 15.0  # Base damage value
var damage_multipliers: Array[float] = []  # Array to store all active multipliers
var is_dashing: bool = false  # For Speed Demon powerup

@onready var animation_tree = $AnimationTree
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var dash_state = $StateMachine/Dash as State
@onready var hurtbox = $Hurtbox
@onready var hitbox = $Hitbox
@onready var state_machine = $StateMachine

func _ready():
	# Add to player group
	add_to_group("player")
	
	animation_player.active = true
	animation_tree.active = false
	
	# Initialize health from PlayerStats
	var player_stats = get_node("/root/PlayerStats")
	if player_stats:
		player_stats.health_changed.connect(_on_health_changed)
		emit_signal("health_changed", player_stats.get_current_health())
		player_stats.stat_changed.connect(_on_stat_changed)
	
	# Set up hitbox and hurtbox
	if hitbox:
		hitbox.collision_layer = 16  # Layer 5 (Player hitbox)
		hitbox.collision_mask = 32   # Layer 6 (Enemy hurtbox)
	
	if hurtbox:
		hurtbox.collision_layer = 8   # Layer 4 (Player hurtbox)
		hurtbox.collision_mask = 64   # Layer 7 (Enemy hitbox)
		# Disconnect any existing connections to avoid duplicates
		if hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.disconnect(_on_hurtbox_hurt)
		# Connect the hurt signal
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	else:
		push_error("[Player] Warning: No hurtbox found!")
	
	# Register with PowerupManager and RoomManager
	PowerupManager.register_player(self)
	RoomManager.register_player(self)
	
	# Initialize stats
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	
	# Connect dash state signals
	if dash_state:
		if not dash_state.is_connected("state_entered", _on_dash_state_entered):
			dash_state.connect("state_entered", _on_dash_state_entered)
		if not dash_state.is_connected("state_exited", _on_dash_state_exited):
			dash_state.connect("state_exited", _on_dash_state_exited)
		
	# Initialize stats from PlayerStats
	_sync_stats_from_player_stats()

func _physics_process(delta):
	# Update dash cooldown
	if dash_state and dash_state.has_method("cooldown_update"):
		dash_state.cooldown_update(delta)
	
	# Handle dash input
	if Input.is_action_just_pressed("dash") and dash_state and dash_state.has_method("can_start_dash") and dash_state.can_start_dash():
		$StateMachine.transition_to("Dash")
		return
	
	# Handle sprite flipping
	if not is_wall_jumping:  # Only auto-flip sprite when not wall jumping
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false
	
	# Handle jump buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Handle coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
		if jump_buffer_timer > 0:  # Execute buffered jump
			start_jump()
			jump_buffer_timer = 0.0
	elif was_on_floor:
		coyote_timer -= delta
		if coyote_timer <= 0:
			was_on_floor = false
	
	# Handle variable jump height and gravity
	if is_jumping:
		jump_timer += delta
		current_gravity_multiplier = 1.0
		if jump_timer >= max_jump_time or not Input.is_action_pressed("jump"):
			is_jumping = false
			if velocity.y < 0:  # Only cut jump height if still moving upward
				velocity.y *= jump_cut_height
				current_gravity_multiplier = fall_gravity_multiplier
	else:
		# Apply stronger gravity when falling
		current_gravity_multiplier = fall_gravity_multiplier if velocity.y > 0 else 1.0
	
	# Apply maximum fall speed with the new higher limit
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	# Update wall jump timer
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# Handle wall jump momentum with better control
	if is_wall_jumping:
		var input_dir = Input.get_axis("left", "right")
		
		# Only allow input control after delay
		if wall_jump_timer <= 0 and input_dir != 0:
			# Calculate target velocity while preserving wall jump momentum
			var target_x = velocity.x
			if sign(input_dir) == sign(wall_jump_direction):
				# Moving in same direction as wall jump - maintain momentum
				target_x = wall_jump_velocity.x * wall_jump_direction
			else:
				# Moving opposite to wall jump - gradual control but preserve some momentum
				target_x = lerp(velocity.x, input_dir * speed, 0.1)  # Gradual transition
			
			velocity.x = target_x
		
		# End wall jump state only when touching ground
		if is_on_floor():
			is_wall_jumping = false
			wall_jump_direction = 0.0

	if wall_jump_boost_timer > 0:
		# Apply continuous boost in the wall jump direction while preserving current velocity
		var boosted_velocity = wall_jump_direction * wall_jump_velocity.x * wall_jump_boost
		velocity.x = lerp(velocity.x, boosted_velocity, 0.5)  # Smooth transition
		wall_jump_boost_timer -= delta

	# Update ledge grab cooldown
	if ledge_grab_cooldown_timer > 0:
		ledge_grab_cooldown_timer -= delta
			
	# Update invincibility timer
	if invincibility_timer > 0:
		invincibility_timer -= delta

	# Apply speed multiplier to movement
	if Input.is_action_pressed("right"):
		velocity.x = move_toward(velocity.x, speed * speed_multiplier, acceleration * delta)
	elif Input.is_action_pressed("left"):
		velocity.x = move_toward(velocity.x, -speed * speed_multiplier, acceleration * delta)
	else:
		apply_friction(delta)

func can_jump() -> bool:
	# Prevent jumping if pressing down
	if Input.is_action_pressed("down"):
		return false
	return is_on_floor() or coyote_timer > 0

func start_jump():
	# Don't start jump if pressing down
	if Input.is_action_pressed("down"):
		return
		
	is_jumping = true
	jump_timer = 0.0
	velocity.y = -jump_velocity
	# Reduce horizontal boost for more predictable jumps
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.2  # Reduced from 0.3

func start_double_jump():
	# Don't start double jump if pressing down
	if Input.is_action_pressed("down"):
		return
		
	is_jumping = true
	jump_timer = 0.0
	velocity.y = -double_jump_velocity
	# Reduce horizontal boost for double jump too
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.25  # Reduced from 0.4

func apply_friction(delta: float, input_dir: float = 0.0, precision_mode: bool = false) -> void:
	# Use different friction values for ground and air
	var friction_to_use = friction if is_on_floor() else (precision_air_friction if precision_mode else air_friction)
	
	# Apply extra friction when stopping (input direction is opposite to velocity or zero)
	if (input_dir == 0.0) or (sign(input_dir) != sign(velocity.x)):
		friction_to_use *= stop_friction_multiplier if is_on_floor() else 1.0  # Don't multiply air friction
	
	velocity.x = move_toward(velocity.x, 0, friction_to_use * delta)

func reset_jump_state():
	can_double_jump = false
	has_double_jumped = false
	is_jumping = false
	jump_timer = 0.0
	coyote_timer = 0.0
	was_on_floor = false
	jump_buffer_timer = 0.0
	current_gravity_multiplier = 1.0

func enable_double_jump():
	can_double_jump = true
	has_double_jumped = false

func take_damage(amount: float, show_damage_number: bool = true):
	var player_stats = get_node("/root/PlayerStats")
	if player_stats:
		var current_health = player_stats.get_current_health()
		player_stats.set_current_health(current_health - amount, show_damage_number)

func heal(amount: float):
	var player_stats = get_node("/root/PlayerStats")
	if player_stats:
		var current_health = player_stats.get_current_health()
		player_stats.set_current_health(current_health + amount)

func is_moving_away_from_wall() -> bool:
	var input_dir = Input.get_axis("left", "right")
	return input_dir * wall_normal.x > 0

func is_on_wall_slide() -> bool:
	return is_on_wall() and not is_on_floor() and not is_moving_away_from_wall()

func start_wall_slide(normal: Vector2) -> void:
	is_wall_sliding = true
	wall_normal = normal
	can_wall_jump = true
	current_gravity_multiplier = wall_slide_gravity_multiplier
	
	# Apply magnetic effect
	if abs(velocity.x) < wall_stick_force:
		velocity.x = -wall_normal.x * wall_stick_force
	
func end_wall_slide() -> void:
	is_wall_sliding = false
	wall_normal = Vector2.ZERO
	current_gravity_multiplier = 1.0

func wall_jump():
	is_jumping = true
	is_wall_jumping = true
	jump_timer = 0.0
	wall_jump_timer = wall_jump_control_delay
	
	# Store wall jump direction - should be same as wall normal to jump away from wall
	wall_jump_direction = wall_normal.x
	
	# Calculate jump velocities with preserved momentum
	var jump_x = wall_jump_velocity.x * wall_jump_direction * wall_jump_boost
	var jump_y = wall_jump_velocity.y * wall_jump_boost
	
	# Set velocities directly without any dampening
	velocity = Vector2(jump_x, jump_y)
	
	# Add an immediate position adjustment for instant feedback
	position.x += wall_jump_direction * 20
	
	# Enable double jump after wall jump
	enable_double_jump()

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Check if player is invincible
	if invincibility_timer > 0:
		return
		
	# Store attacker's position and knockback data for hurt state BEFORE taking damage
	last_hit_position = hitbox.global_position
	if hitbox.has_method("get_knockback_data"):
		last_hit_knockback = hitbox.get_knockback_data()
	
	# Check if we're in block state
	if state_machine and state_machine.current_state.name == "Block":
		# Use the damage value set by block state (0 for parry, reduced for block)
		var is_parry = hurtbox.last_damage == 0  # Check if this was a parry
		take_damage(hurtbox.last_damage, !is_parry)  # Only show damage number if not a parry
	else:
		# Normal damage handling
		if hitbox.has_method("get_damage"):
			var damage = hitbox.get_damage()
			take_damage(damage)  # Show damage number for normal hits
	
	# Only transition to hurt state if not blocking
	if state_machine and state_machine.has_node("Hurt") and state_machine.current_state.name != "Block":
		# Force immediate transition to hurt state
		if state_machine.current_state:
			state_machine.current_state.exit()
		
		var hurt_state = state_machine.get_node("Hurt")
		state_machine.current_state = hurt_state
		state_machine.current_state.enter()
	
	# Flash the sprite red to indicate damage (only if actually taking damage)
	if hurtbox.last_damage > 0:
		sprite.modulate = Color(1, 0, 0, 1)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color(1, 1, 1, 1)

func has_coyote_time() -> bool:
	return coyote_timer > 0.0

# Powerup-related functions
func modify_damage_multiplier(multiplier: float) -> void:
	# This function now only handles attack damage multipliers
	
	# Convert multiplier to bonus (e.g., 1.2 becomes 0.2)
	var bonus = multiplier - 1.0
	damage_multipliers.append(bonus)
	
	# Calculate total bonus (additive stacking)
	var total_bonus = 0.0
	for bonus_value in damage_multipliers:
		total_bonus += bonus_value
	
	# Apply total bonus
	damage_multiplier = 1.0 + total_bonus
	
	
	# Update hitbox damage using base damage from PlayerStats
	if hitbox:
		hitbox.damage = base_damage * damage_multiplier

func remove_damage_multiplier(multiplier: float) -> void:
	# Convert multiplier to bonus before removing
	var bonus = multiplier - 1.0
	damage_multipliers.erase(bonus)
	
	# Recalculate total bonus
	var total_bonus = 0.0
	for bonus_value in damage_multipliers:
		total_bonus += bonus_value
	
	# Apply the total bonus
	damage_multiplier = 1.0 + total_bonus
	
	# Update hitbox damage using base damage
	if hitbox:
		hitbox.damage = base_damage * damage_multiplier

func modify_speed(multiplier: float) -> void:
	# This function is now just for temporary speed modifications (like dash)
	speed_multiplier = multiplier

func get_stats() -> Dictionary:
	var player_stats = get_node("/root/PlayerStats")
	return {
		"current_health": get_current_health(),
		"max_health": get_max_health(),
		"damage_multiplier": damage_multiplier,
		"movement_speed": speed * speed_multiplier,
		"base_damage": base_damage,
		"total_damage": base_damage * damage_multiplier,
		"speed_multiplier": speed_multiplier
	}

# Update dash state tracking
func _on_dash_state_entered() -> void:
	is_dashing = true
	emit_signal("dash_started")

func _on_dash_state_exited() -> void:
	is_dashing = false

# Update perfect parry detection
func _on_successful_parry() -> void:
	emit_signal("perfect_parry")

# Add new functions for stat syncing
func _sync_stats_from_player_stats() -> void:
	var player_stats = get_node("/root/PlayerStats")
	if !player_stats:
		return
		
	speed = player_stats.get_stat("movement_speed")
	base_damage = player_stats.get_stat("base_damage")

func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	match stat_name:
		"movement_speed":
			speed = new_value
		"base_damage":
			base_damage = new_value
			if hitbox:
				hitbox.damage = base_damage * damage_multiplier

func _on_health_changed(new_health: float) -> void:
	emit_signal("health_changed", new_health)

func get_max_health() -> float:
	var player_stats = get_node("/root/PlayerStats")
	return player_stats.get_max_health() if player_stats else 100.0

func get_current_health() -> float:
	var player_stats = get_node("/root/PlayerStats")
	return player_stats.get_current_health() if player_stats else 100.0

func get_health_percent() -> float:
	var max_health = get_max_health()
	return get_current_health() / max_health if max_health > 0 else 1.0

# Make dash state accessible for powerups
func get_dash_state() -> State:
	return dash_state

func apply_movement(delta: float, input_dir: float) -> void:
	# Use different acceleration values for ground and air
	var current_acceleration = acceleration if is_on_floor() else air_acceleration
	var target_speed = speed
	
	# In air, apply different control based on if down is held
	if !is_on_floor():
		if Input.is_action_pressed("down"):
			# Precision mode - better control and more friction
			target_speed *= precision_air_control_multiplier
			if input_dir == 0:
				apply_friction(delta, input_dir, true)  # Use precision friction
				return
		else:
			target_speed *= air_control_multiplier
			
			# Quick momentum cancellation when releasing direction in air
			# Only if not wall jumping to preserve wall jump feel
			if input_dir == 0 and !is_wall_jumping:
				velocity.x *= air_momentum_cancel_rate
			# Add extra friction when changing direction in air
			elif input_dir != 0 and sign(input_dir) != sign(velocity.x):
				velocity.x *= 0.95  # Slight momentum reduction when turning
	
	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, current_acceleration * delta)
	else:
		apply_friction(delta, input_dir)
