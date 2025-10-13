extends State

const WALL_JUMP_FORCE := Vector2(700, -550)
const WALL_JUMP_BOOST_DURATION := 0.2
const MIN_WALL_NORMAL_X := 0.7
const WALL_STICK_DURATION := 0.15
const MAX_UPWARD_SLIDE_SPEED := 100.0
const WALL_SLIDE_SPEED_MULTIPLIER := 0.5
const WALL_DETACH_BUFFER := 0.1
const INPUT_THRESHOLD := 0.5  # Only consider input above this threshold
const PRESS_AWAY_GRACE := 0.3  # Increased grace period
const REENTRY_COOLDOWN := 0.05  # Reduced cooldown for more responsive wall sliding

@onready var wall_ray_left: RayCast2D = $"../../WallRayLeft"
@onready var wall_ray_right: RayCast2D = $"../../WallRayRight"

var wall_stick_timer := 0.0
var last_valid_normal := Vector2.ZERO
var has_valid_wall := false
var wall_detach_timer := 0.0
var current_wall_normal := Vector2.ZERO
var press_away_timer := 0.0  # Track how long we've been pressing away
var reentry_cooldown_timer := 0.0  # Track cooldown for this instance
var locked_sprite_direction := false  # Whether we've locked the sprite direction
var wall_side := 0  # -1 for left wall, 1 for right wall

func _ready():
	assert(wall_ray_left != null, "Left wall raycast not found!")
	assert(wall_ray_right != null, "Right wall raycast not found!")
	wall_ray_left.collision_mask = CollisionLayers.WORLD
	wall_ray_right.collision_mask = CollisionLayers.WORLD

func update_cooldown(delta: float) -> void:
	if reentry_cooldown_timer > 0:
		reentry_cooldown_timer = max(0.0, reentry_cooldown_timer - delta)

func is_on_cooldown() -> bool:
	return reentry_cooldown_timer > 0.0

func can_enter() -> bool:
	# Don't allow re-entry if we're already wall sliding
	if state_machine.current_state == self:
		# print("[WALL_SLIDE_DEBUG] WallSlide: Already wall sliding, cannot enter")
		return false
		
	# Always skip cooldown for Jump, Fall, and Run states for immediate wall slide
	var skip_cooldown = state_machine.previous_state and (state_machine.previous_state.name == "Jump" or state_machine.previous_state.name == "Fall" or state_machine.previous_state.name == "Run")
	# print("[WALL_SLIDE_DEBUG] WallSlide: Previous state: ", state_machine.previous_state.name if state_machine.previous_state else "None", " skip_cooldown: ", skip_cooldown)
	
	# If we're on cooldown and not coming from Jump/Fall/Run, prevent entry
	if not skip_cooldown and is_on_cooldown():
		# print("[WALL_SLIDE_DEBUG] WallSlide: On cooldown, cannot enter")
		return false
	
	# Check if we're actually on a wall
	var left_wall = wall_ray_left.is_colliding()
	var right_wall = wall_ray_right.is_colliding()
	# print("[WALL_SLIDE_DEBUG] WallSlide: Wall detection - left: ", left_wall, " right: ", right_wall)
	
	return left_wall or right_wall

func reset_cooldown() -> void:
	reentry_cooldown_timer = 0.0

func enter():
	if !player:
		return
	
	# print("[WALL_SLIDE_DEBUG] WallSlide: ENTERING wall slide state")
	
	# Get wall normal from raycast and determine wall side
	current_wall_normal = _get_wall_normal()
	var left_colliding = wall_ray_left.is_colliding()
	var right_colliding = wall_ray_right.is_colliding()
	wall_side = -1 if left_colliding else 1
	
	# print("[WALL_SLIDE_DEBUG] WallSlide: Wall normal: ", current_wall_normal, " wall_side: ", wall_side)
	
	if current_wall_normal == Vector2.ZERO:
		# print("[WALL_SLIDE_DEBUG] WallSlide: No wall normal found, transitioning to Fall")
		state_machine.transition_to("Fall")
		return
	
	# Reset cooldown on successful entry
	reset_cooldown()
	
	# Initialize wall slide
	player.velocity.x = 0
	player.velocity.y = min(player.velocity.y, player.wall_slide_speed)
	player.current_gravity_multiplier = player.wall_slide_gravity_multiplier
	player.wall_normal = current_wall_normal
	player.is_wall_sliding = true
	wall_detach_timer = 0.0
	press_away_timer = 0.0
	wall_stick_timer = WALL_STICK_DURATION
	
	# Lock sprite direction based on wall side
	locked_sprite_direction = true
	
	# Face TOWARDS the wall: face left on left wall, face right on right wall
	player.sprite.flip_h = wall_side < 0
	
	# Double check the sprite direction was set correctly
	if player.sprite.flip_h != (wall_side < 0):
		await get_tree().process_frame
		player.sprite.flip_h = wall_side < 0
	
	# Play wall slide animation
	animation_player.play("wall_slide")

func physics_update(delta: float):
	if !player:
		return
	
	# Update cooldown timer
	update_cooldown(delta)
	
	# Track wall collision
	var is_on_wall = player.is_on_wall()
	var wall_normal = player.get_wall_normal()
	var left_colliding = wall_ray_left.is_colliding()
	var right_colliding = wall_ray_right.is_colliding()
	
	# Verify sprite direction is still correct
	if locked_sprite_direction and player.sprite.flip_h != (wall_side < 0):
		player.sprite.flip_h = wall_side < 0
	
	# Update wall detach timer
	if not is_on_wall:
		wall_detach_timer += delta
		
		# Only unlock sprite direction if explicitly moving in opposite direction
		var input_dir = Input.get_axis("left", "right")
		if abs(input_dir) >= INPUT_THRESHOLD:
			var would_unlock = (wall_side < 0 and input_dir > 0) or (wall_side > 0 and input_dir < 0)
			if would_unlock:
				locked_sprite_direction = false
	else:
		wall_detach_timer = 0.0
		wall_stick_timer = WALL_STICK_DURATION
		
		# Verify wall side hasn't changed
		var current_side = -1 if left_colliding else 1
		if current_side != wall_side:
			wall_side = current_side
			if locked_sprite_direction:
				player.sprite.flip_h = wall_side < 0

	# Check for jump input FIRST - if jumping, don't check for ledgegrab
	if Input.is_action_just_pressed("jump"):
		_perform_wall_jump(current_wall_normal)
		return
	
	# --- Ledge Grab Check (only when not jumping) ---
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		_end_wall_slide() # Ensure wall slide cleanup happens
		state_machine.transition_to("LedgeGrab")
		return
	# --- END Ledge Grab Check ---
	
	# Apply wall slide physics
	player.velocity.y = min(player.velocity.y + player.gravity * delta * player.wall_slide_gravity_multiplier, 100.0)
	
	# Play correct wall slide animation based on vertical velocity
	var target_animation: String
	if player.velocity.y > 5.0: # Small threshold to prevent flickering when velocity is near zero
		target_animation = "wall_slide_down"
	elif player.velocity.y < -5.0:
		target_animation = "wall_slide_up"
	else:
		target_animation = animation_player.current_animation # Keep current animation if near zero or static
		# Optionally, you could play a specific 'wall_slide_idle' animation here if you have one.

	if target_animation != "" and animation_player.current_animation != target_animation:
		animation_player.play(target_animation)
	
	# Check if we should exit wall slide
	var input_dir = Input.get_axis("left", "right")
	var pressing_away = false
	
	if abs(input_dir) >= INPUT_THRESHOLD:
		pressing_away = (wall_side < 0 and input_dir > 0) or (wall_side > 0 and input_dir < 0)
		
		if pressing_away:
			press_away_timer += delta
		else:
			press_away_timer = 0.0
			wall_stick_timer = WALL_STICK_DURATION
	else:
		press_away_timer = 0.0
		wall_stick_timer = WALL_STICK_DURATION
	
	# Update wall stick timer
	if wall_stick_timer > 0:
		wall_stick_timer -= delta
	
	# Exit check
	var should_exit = false
	if wall_detach_timer >= WALL_DETACH_BUFFER:
		should_exit = true
	elif pressing_away and press_away_timer >= PRESS_AWAY_GRACE and wall_stick_timer <= 0:
		should_exit = true
	
	if should_exit:
		# Set ledgegrab cooldown when exiting wallslide to prevent immediate ledgegrab
		player.ledge_grab_cooldown_timer = 0.2  # 0.2 second cooldown
		_end_wall_slide()
		state_machine.transition_to("Fall")
		return
	
	player.move_and_slide()

func _get_wall_normal() -> Vector2:
	if wall_ray_left.is_colliding():
		return Vector2.RIGHT
	elif wall_ray_right.is_colliding():
		return Vector2.LEFT
	return Vector2.ZERO

func _perform_wall_jump(wall_normal: Vector2):
	# Calculate wall jump velocity
	var jump_velocity = Vector2(
		WALL_JUMP_FORCE.x * wall_normal.x,
		WALL_JUMP_FORCE.y
	)
	
	_end_wall_slide()
	
	# Set player state for wall jump
	player.velocity = jump_velocity
	player.is_wall_jumping = true
	player.wall_jump_direction = wall_normal.x
	
	# Set ledgegrab cooldown to prevent immediate ledgegrab after wall jump
	player.ledge_grab_cooldown_timer = 0.2  # 0.2 second cooldown
	
	# When wall jumping, face AWAY from the wall
	player.sprite.flip_h = wall_side > 0  # This stays > because we want to face AWAY for the jump
	locked_sprite_direction = false  # Allow sprite direction to change after wall jump
	
	state_machine.transition_to("Jump")

func _end_wall_slide():
	# WALLSLIDE FIX: Wallslide bittiğinde zıplama haklarını koru
	# Bu sayede ikinci, üçüncü wallslide'lerde de zıplama hakkı korunur
	if not player.has_double_jumped:
		player.enable_double_jump()
	
	player.end_wall_slide()
	reentry_cooldown_timer = REENTRY_COOLDOWN

func exit():
	pass
