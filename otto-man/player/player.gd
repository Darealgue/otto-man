extends CharacterBody2D

signal health_changed(new_health: float)

@export var speed: float = 450.0
@export var jump_velocity: float = 600.0
@export var double_jump_velocity: float = 550.0
@export var acceleration: float = 3000.0
@export var friction: float = 2000.0
@export var stop_friction_multiplier: float = 2.0
@export var max_health: float = 100.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var fall_gravity_multiplier: float = 1.3
@export var max_fall_speed: float = 1500.0
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

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var health: float = max_health
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

@onready var animation_tree = $AnimationTree
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var dash_state = $StateMachine/Dash as State
@onready var hurtbox = $Hurtbox
@onready var hitbox = $Hitbox
@onready var state_machine = $StateMachine

func _ready():
	animation_player.active = true
	animation_tree.active = false
	
	health = max_health
	emit_signal("health_changed", health)
	print("[Player] Initial health:", health)
	
	# Set up hitbox and hurtbox
	if hitbox:
		hitbox.is_player = true
		hitbox.collision_layer = 16  # Layer 5 (Player hitbox)
		hitbox.collision_mask = 32   # Layer 6 (Enemy hurtbox)
		print("[Player] Setting hitbox is_player to true")
	
	if hurtbox:
		hurtbox.is_player = true
		hurtbox.collision_layer = 8   # Layer 4 (Player hurtbox)
		hurtbox.collision_mask = 64   # Layer 7 (Enemy hitbox)
		print("[Player] Setting hurtbox is_player to true")
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	else:
		print("[Player] Warning: No hurtbox found!")

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
		coyote_timer = coyote_time
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
		current_gravity_multiplier = fall_gravity_multiplier if velocity.y > 0 else 1.0
	
	# Apply maximum fall speed
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed
	
	# Debug animation state
	if Input.is_action_just_pressed("jump"):
		print("Jump pressed - Current animation:", animation_player.current_animation)

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
		if ledge_grab_cooldown_timer <= 0:
			print("DEBUG: Ledge grab cooldown ended")
			
	# Update invincibility timer
	if invincibility_timer > 0:
		invincibility_timer -= delta

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0

func start_jump():
	is_jumping = true
	jump_timer = 0.0
	velocity.y = -jump_velocity
	# Add a larger horizontal boost for more dynamic movement
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.3

func start_double_jump():
	is_jumping = true
	jump_timer = 0.0
	velocity.y = -double_jump_velocity
	# Add a larger horizontal boost for double jump
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.4

func apply_friction(delta: float, input_dir: float = 0.0) -> void:
	# Apply extra friction when stopping (input direction is opposite to velocity or zero)
	var friction_to_use = friction
	if (input_dir == 0.0) or (sign(input_dir) != sign(velocity.x)):
		friction_to_use *= stop_friction_multiplier
	
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

func take_damage(amount: float):
	# Check if player is invincible
	if invincibility_timer > 0:
		print("[Player] Damage ignored - Invincible for:", invincibility_timer, "seconds")
		return
		
	print("[Player] take_damage called with amount:", amount)
	health -= amount
	health = clamp(health, 0, max_health)
	print("[Player] Health after damage:", health)
	emit_signal("health_changed", health)

func heal(amount: float):
	health += amount
	health = clamp(health, 0, max_health)
	emit_signal("health_changed", health)
	print("Player healed:", amount, " Current health:", health)

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
	print("\n=== WALL JUMP START ===")
	print("Wall normal:", wall_normal)
	print("Initial velocity:", velocity)
	
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
	
	print("Jump direction:", wall_jump_direction)
	print("Jump velocity - X:", velocity.x, " Y:", velocity.y)
	
	# Add an immediate position adjustment for instant feedback
	position.x += wall_jump_direction * 20
	
	# Enable double jump after wall jump
	enable_double_jump()
	print("=== WALL JUMP END ===")

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Check if player is invincible
	if invincibility_timer > 0:
		return
		
	if debug_enabled:
		print("[Player] Hurtbox hurt by:", hitbox.get_parent().name)
	
	# Store attacker's position and knockback data for hurt state BEFORE taking damage
	last_hit_position = hitbox.global_position
	if hitbox.has_method("get_knockback_data"):
		last_hit_knockback = hitbox.get_knockback_data()
		if debug_enabled:
			print("[Player] Knockback data received - Force:", last_hit_knockback.force, " Up Force:", last_hit_knockback.up_force)
	
	if hitbox.has_method("get_damage"):
		var damage = hitbox.get_damage()
		if debug_enabled:
			print("[Player] Taking damage:", damage)
		take_damage(damage)
		if debug_enabled:
			print("[Player] Current health:", health)
	
	# Always transition to hurt state when hit, regardless of current state
	if state_machine and state_machine.has_node("Hurt"):
		if debug_enabled:
			print("[Player] Transitioning to hurt state")
		state_machine.transition_to("Hurt")
	else:
		push_error("[Player] Hurt state not found in state machine!")
	
	# Flash the sprite red to indicate damage
	sprite.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1, 1)
