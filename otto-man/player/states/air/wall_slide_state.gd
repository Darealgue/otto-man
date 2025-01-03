extends State

const WALL_JUMP_FORCE := Vector2(700, -550)
const WALL_JUMP_BOOST_DURATION := 0.2
const MIN_WALL_NORMAL_X := 0.7
const WALL_STICK_DURATION := 0.15
const MAX_UPWARD_SLIDE_SPEED := 50.0  # Maximum speed when sliding up
const WALL_SLIDE_SPEED_MULTIPLIER := 0.5  # Reduces the overall wall slide speed

@onready var wall_ray_left: RayCast2D = $"../../WallRayLeft"
@onready var wall_ray_right: RayCast2D = $"../../WallRayRight"

var wall_stick_timer := 0.0
var last_valid_normal := Vector2.ZERO
var has_valid_wall := false
var initial_wall_side := 0  # -1 for left wall, 1 for right wall
var initial_sprite_flip := false  # Store initial sprite flip state

class WallCollision:
	var normal: Vector2
	var point: Vector2
	
	func _init(n: Vector2, p: Vector2):
		normal = n
		point = p
	
	func get_normal() -> Vector2:
		return normal

func _ready():
	# Ensure raycasts exist and are configured
	assert(wall_ray_left != null, "Left wall raycast not found! Add RayCast2D named WallRayLeft as child of player")
	assert(wall_ray_right != null, "Right wall raycast not found! Add RayCast2D named WallRayRight as child of player")
	
	# Configure raycasts
	wall_ray_left.collision_mask = 1  # Only detect walls
	wall_ray_right.collision_mask = 1
	
	print("DEBUG: Wall raycasts configuration:")
	print("Left raycast - Enabled:", wall_ray_left.enabled, 
		  " Collision mask:", wall_ray_left.collision_mask,
		  " Target:", wall_ray_left.target_position)
	print("Right raycast - Enabled:", wall_ray_right.enabled,
		  " Collision mask:", wall_ray_right.collision_mask,
		  " Target:", wall_ray_right.target_position)

func _get_wall_collision() -> WallCollision:
	# First check raycasts as they're more reliable
	if wall_ray_left.is_colliding():
		var collision_point = wall_ray_left.get_collision_point()
		var normal = wall_ray_left.get_collision_normal()
		print("DEBUG: Left raycast hit at distance:", (collision_point - wall_ray_left.global_position).length(), " Normal:", normal)
		return WallCollision.new(normal, collision_point)
		
	if wall_ray_right.is_colliding():
		var collision_point = wall_ray_right.get_collision_point()
		var normal = wall_ray_right.get_collision_normal()
		print("DEBUG: Right raycast hit at distance:", (collision_point - wall_ray_right.global_position).length(), " Normal:", normal)
		return WallCollision.new(normal, collision_point)
	
	# Fallback to direct wall collision
	if player.is_on_wall():
		for i in range(player.get_slide_collision_count()):
			var collision = player.get_slide_collision(i)
			var normal = collision.get_normal()
			if abs(normal.x) >= MIN_WALL_NORMAL_X:
				print("DEBUG: Found wall collision with normal:", normal)
				return WallCollision.new(normal, collision.get_position())
	
	print("DEBUG: No wall detected - Left ray colliding:", wall_ray_left.is_colliding(),
		  " Right ray colliding:", wall_ray_right.is_colliding(),
		  " On wall:", player.is_on_wall())
	return null

func can_wall_slide() -> bool:
	var collision = _get_wall_collision()
	
	if collision:
		wall_stick_timer = WALL_STICK_DURATION
		last_valid_normal = collision.get_normal()
		has_valid_wall = true
		print("DEBUG: Wall slide possible - Normal:", last_valid_normal)
		return true
		
	if has_valid_wall and wall_stick_timer > 0:
		print("DEBUG: Using wall stick buffer - Time left:", wall_stick_timer)
		return true
		
	if player.velocity.y < -100:
		print("DEBUG: Moving upward too fast for wall slide")
		return false
		
	has_valid_wall = false
	return false

func enter():
	print("DEBUG: Entering wall slide state")
	animation_player.play("wall_slide")
	
	# Get wall normal from raycast
	var wall_normal = _get_wall_normal()
	if wall_normal == Vector2.ZERO:
		state_machine.transition_to("Fall")
		return
	
	# Initialize wall slide
	player.velocity.x = 0
	player.velocity.y = min(player.velocity.y, player.wall_slide_speed)
	player.current_gravity_multiplier = player.wall_slide_gravity_multiplier
	player.wall_normal = wall_normal
	player.is_wall_sliding = true
	
	# Set sprite direction - face towards wall
	player.sprite.flip_h = wall_normal.x < 0

func physics_update(delta: float):
	# Check if we're still on the wall
	var wall_normal = _get_wall_normal()
	if wall_normal == Vector2.ZERO:
		_end_wall_slide()
		return
	
	# Handle wall jump input
	if Input.is_action_just_pressed("jump"):
		print("DEBUG: Wall jump triggered")
		_perform_wall_jump(wall_normal)
		return
	
	# Check if moving away from wall
	var input_dir = Input.get_axis("left", "right")
	if input_dir * wall_normal.x > 0:
		print("DEBUG: Detaching from wall due to input")
		_end_wall_slide()
		return
	
	# Apply wall slide physics
	player.velocity.y = min(player.velocity.y + player.gravity * player.current_gravity_multiplier * delta, player.wall_slide_speed)
	player.velocity.x = -wall_normal.x * player.wall_stick_force  # Apply stick force
	player.move_and_slide()

func _get_wall_normal() -> Vector2:
	var wall_normal = Vector2.ZERO
	
	if wall_ray_left.is_colliding():
		wall_normal = Vector2.RIGHT
	elif wall_ray_right.is_colliding():
		wall_normal = Vector2.LEFT
	
	return wall_normal

func _perform_wall_jump(wall_normal: Vector2):
	# Calculate wall jump velocity - jump away from wall
	var jump_velocity = Vector2(
		player.wall_jump_velocity.x * wall_normal.x,  # Jump in direction of wall normal
		player.wall_jump_velocity.y  # Vertical component
	)
	
	# Apply the wall jump with consistent velocity
	player.velocity = jump_velocity
	player.is_wall_jumping = true
	player.wall_jump_direction = wall_normal.x  # Direction matches wall normal
	player.wall_jump_timer = player.wall_jump_control_delay
	player.wall_jump_boost_timer = player.wall_jump_control_delay
	
	# Face away from wall - flip sprite to face jump direction
	player.sprite.flip_h = wall_normal.x > 0  # Face opposite to wall normal
	
	_end_wall_slide()
	state_machine.transition_to("Jump")  # Let Jump state handle the animation

func _end_wall_slide():
	print("DEBUG: Exiting wall slide state")
	player.end_wall_slide()
	state_machine.transition_to("Fall")
