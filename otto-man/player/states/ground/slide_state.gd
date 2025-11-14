extends "../state.gd"

const SLIDE_DURATION := 0.5  # Duration of slide in seconds
const MIN_SPEED_TO_SLIDE := 200.0  # Minimum speed required to slide
const SLIDE_FRICTION := 1000.0  # Increased friction for faster slowdown
const INITIAL_SLIDE_SPEED := 800.0  # Initial speed when starting slide
const FLOOR_CHECK_DELAY := 0.15  # Increased delay before checking floor state
const SLIDE_GRAVITY_MULTIPLIER := 0.5  # Reduced gravity during slide
const DOWN_FORCE := 200.0  # Force to keep player grounded
const SLIDE_HEIGHT_RATIO := 0.5  # How much to reduce height during slide
const MIN_SLIDE_SPEED := 100.0  # Minimum speed to maintain slide
const EXIT_SPEED := 150.0  # Speed to set when exiting slide

var slide_timer := 0.0
var floor_check_timer := 0.0
var slide_direction := 1.0
var original_height: float = 44.0  # Actual height from scene
var original_position_y: float = -22.0  # Actual position from scene
var original_hurtbox_height: float = 44.0  # Actual hurtbox height from scene
var original_hurtbox_position_y: float = -22.0  # Actual hurtbox position from scene
var has_initialized := false
var last_floor_position: Vector2

func can_enter() -> bool:
	# Allow entry from run state or when player has sufficient speed
	var from_run = state_machine.previous_state.name == "Run"
	var has_speed = abs(player.velocity.x) >= MIN_SPEED_TO_SLIDE
	return from_run or has_speed

func _ready() -> void:
	# Initialize dimensions when the state is ready
	if player:
		var collision_shape = player.get_node("CollisionShape2D")
		var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
		
		if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
			original_height = collision_shape.shape.height
			original_position_y = collision_shape.position.y
			original_hurtbox_height = hurtbox_shape.shape.height
			original_hurtbox_position_y = hurtbox_shape.position.y
			has_initialized = true

func enter():
	if !player:
		return
		
	# Reset timers
	slide_timer = 0.0
	floor_check_timer = 0.0
	
	# Store initial floor position
	last_floor_position = player.position
		
	# Store the direction we're sliding in based on input or current velocity
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	if input_dir != 0:
		slide_direction = sign(input_dir)
	else:
		slide_direction = sign(player.velocity.x)
	if slide_direction == 0:
		slide_direction = player.get_facing_direction()
	
		
	# Initialize dimensions if not done yet
	var collision_shape = player.get_node("CollisionShape2D")
	var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
	
	if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		
		if !has_initialized:
			original_height = collision_shape.shape.height
			original_position_y = collision_shape.position.y
			original_hurtbox_height = hurtbox_shape.shape.height
			original_hurtbox_position_y = hurtbox_shape.position.y
			has_initialized = true
		
		# Calculate new heights for sliding
		var new_height = original_height * SLIDE_HEIGHT_RATIO
		var new_hurtbox_height = original_hurtbox_height * SLIDE_HEIGHT_RATIO
		
		# Reduce heights and adjust positions to keep bottom at same level
		collision_shape.shape.height = new_height
		collision_shape.position.y = original_position_y + (original_height - new_height) * 0.5
		
		hurtbox_shape.shape.height = new_hurtbox_height
		hurtbox_shape.position.y = original_hurtbox_position_y + (original_hurtbox_height - new_hurtbox_height) * 0.5
		
		
	# Set initial slide velocity
	player.velocity.x = INITIAL_SLIDE_SPEED * slide_direction
	# Add a small downward velocity to help maintain ground contact
	player.velocity.y = DOWN_FORCE
	
	# Play slide animation
	animation_player.play("slide")

func exit():
	if !player:
		return
		
	# Restore original collision shape and hurtbox height and position
	var collision_shape = player.get_node("CollisionShape2D")
	var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
	
	if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		
		# Restore original dimensions
		collision_shape.shape.height = original_height
		collision_shape.position.y = original_position_y
		
		hurtbox_shape.shape.height = original_hurtbox_height
		hurtbox_shape.position.y = original_hurtbox_position_y
		
		
	# Set a reasonable exit velocity to prevent immediate re-entry to slide
	player.velocity.x = sign(player.velocity.x) * min(abs(player.velocity.x), EXIT_SPEED)

func physics_update(delta: float):
	if !player:
		return
		
	slide_timer += delta
	floor_check_timer += delta
	
	# Apply reduced gravity during slide
	player.velocity.y += player.gravity * SLIDE_GRAVITY_MULTIPLIER * delta
	
	# Keep player grounded with constant downward force
	if player.is_on_floor():
		player.velocity.y = DOWN_FORCE
		last_floor_position = player.position
	
	
	# Get current input direction
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	
	# Apply slide movement with more controlled deceleration
	var current_speed = abs(player.velocity.x)
	var friction_multiplier = 1.0
	
	# Increase friction if input direction is opposite to slide direction
	if input_dir != 0 and sign(input_dir) != sign(slide_direction):
		friction_multiplier = 2.0
	
	# Apply friction
	var new_speed = move_toward(current_speed, 0, SLIDE_FRICTION * friction_multiplier * delta)
	player.velocity.x = new_speed * slide_direction
	
	# Check if we should exit slide
	if slide_timer >= SLIDE_DURATION or current_speed < MIN_SLIDE_SPEED:
		if Input.is_action_pressed("crouch"):
			# Set velocity to prevent immediate re-slide
			player.velocity.x = sign(player.velocity.x) * min(abs(player.velocity.x), EXIT_SPEED)
			state_machine.transition_to("Crouch")
		else:
			# Add a brief crouch period before transitioning to idle to prevent getting stuck
			state_machine.transition_to("Crouch")
		return
	elif not Input.is_action_pressed("crouch"):
		# Add a brief crouch period before transitioning to idle to prevent getting stuck
		state_machine.transition_to("Crouch")
		return
		
	# Only check floor state after initial delay and if we've moved significantly from last floor position
	if floor_check_timer >= FLOOR_CHECK_DELAY and not player.is_on_floor():
		var distance_from_floor = (player.position - last_floor_position).length()
		if distance_from_floor > 20:  # Only transition if we've moved significantly away from the floor
			state_machine.transition_to("Fall")
			return
	
	player.move_and_slide() 
