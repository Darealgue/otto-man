extends State

const WALL_JUMP_FORCE := Vector2(700, -550)
const WALL_JUMP_BOOST_DURATION := 0.2
const MIN_WALL_NORMAL_X := 0.7
const WALL_STICK_DURATION := 0.15
const MAX_UPWARD_SLIDE_SPEED := 100.0  # Increased from 50 to 100 to allow more upward movement
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
	

func _get_wall_collision() -> WallCollision:
	# First check raycasts as they're more reliable
	if wall_ray_left.is_colliding():
		var collision_point = wall_ray_left.get_collision_point()
		var normal = wall_ray_left.get_collision_normal()
		return WallCollision.new(normal, collision_point)
		
	if wall_ray_right.is_colliding():
		var collision_point = wall_ray_right.get_collision_point()
		var normal = wall_ray_right.get_collision_normal()
		return WallCollision.new(normal, collision_point)
	
	# Fallback to direct wall collision
	if player.is_on_wall():
		for i in range(player.get_slide_collision_count()):
			var collision = player.get_slide_collision(i)
			var normal = collision.get_normal()
			if abs(normal.x) >= MIN_WALL_NORMAL_X:
				return WallCollision.new(normal, collision.get_position())
	
	return null

func can_wall_slide() -> bool:
	var collision = _get_wall_collision()
	
	if collision:
		wall_stick_timer = WALL_STICK_DURATION
		last_valid_normal = collision.get_normal()
		has_valid_wall = true
		return true
		
	if has_valid_wall and wall_stick_timer > 0:
		return true
		
	if player.velocity.y < -100:
		return false
		
	has_valid_wall = false
	return false

func enter():
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
	# Check for ground contact first
	if player.is_on_floor():
		state_machine.transition_to("Idle")
		return
		
	# Check if we're still on the wall
	var wall_normal = _get_wall_normal()
	if wall_normal == Vector2.ZERO:
		_end_wall_slide()
		return
	
	# Handle wall jump input
	if Input.is_action_just_pressed("jump"):
		_perform_wall_jump(wall_normal)
		return
	
	# Check if moving away from wall
	var input_dir = Input.get_axis("left", "right")
	if input_dir * wall_normal.x > 0:
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
	# Calculate wall jump velocity with better momentum preservation
	var jump_velocity = Vector2(
		player.wall_jump_velocity.x * wall_normal.x * 1.2,  # Increased horizontal force by 20%
		player.wall_jump_velocity.y * 0.9  # Slightly reduced vertical force for better control
	)
	
	# Preserve some of the player's existing horizontal velocity
	var preserved_velocity = player.velocity.x * 0.4  # Preserve 40% of current horizontal velocity
	jump_velocity.x += preserved_velocity
	
	# Apply the wall jump with consistent velocity
	player.velocity = jump_velocity
	player.is_wall_jumping = true
	player.wall_jump_direction = wall_normal.x  # Direction matches wall normal
	player.wall_jump_timer = player.wall_jump_control_delay * 0.7  # Reduced control delay by 30%
	player.wall_jump_boost_timer = player.wall_jump_control_delay * 0.7
	
	# Face away from wall - flip sprite to face jump direction
	player.sprite.flip_h = wall_normal.x > 0  # Face opposite to wall normal
	
	_end_wall_slide()
	state_machine.transition_to("Jump")  # Let Jump state handle the animation

func _end_wall_slide():
	player.end_wall_slide()
	state_machine.transition_to("Fall")
