extends State

const LEDGE_GRAB_DURATION := 0.2
const CLIMB_FORCE := Vector2(0, -400)
const LEDGE_OFFSET := Vector2(-9, 16)  # Set to the perfect values we found
const GRAB_DISTANCE := 20.0
const MOUNT_OFFSET := Vector2(0, -32)  # Vertical offset to clear the platform
const MOUNT_FORWARD_OFFSET := 20  # How many pixels to move forward onto the platform
const LEDGE_GRAB_COOLDOWN := 0.2  # Cooldown duration after letting go

@onready var wall_ray_left: RayCast2D = $"../../WallRayLeft"
@onready var wall_ray_right: RayCast2D = $"../../WallRayRight"
@onready var ledge_ray_top_left: RayCast2D = $"../../LedgeRayTopLeft"
@onready var ledge_ray_top_right: RayCast2D = $"../../LedgeRayTopRight"

var grab_timer := 0.0
var ledge_position := Vector2.ZERO
var can_climb := false
var facing_direction := 1

func _ready():
	# Enable all raycasts
	wall_ray_left.enabled = true
	wall_ray_right.enabled = true
	ledge_ray_top_left.enabled = true
	ledge_ray_top_right.enabled = true
	
	print("DEBUG: Ledge grab state ready")
	print("DEBUG: Raycasts enabled - Left:", wall_ray_left.enabled, 
		  " Right:", wall_ray_right.enabled,
		  " TopLeft:", ledge_ray_top_left.enabled,
		  " TopRight:", ledge_ray_top_right.enabled)

func physics_update(delta: float):
	if grab_timer > 0:
		grab_timer -= delta
	
	# Handle instant mounting with up button
	if Input.is_action_just_pressed("up") and can_climb:
		print("DEBUG: Instant mounting to platform")
		# Move player to top of platform and forward
		var mount_pos = ledge_position + MOUNT_OFFSET
		mount_pos.x += facing_direction * MOUNT_FORWARD_OFFSET  # Move in the direction we're facing
		player.global_position = mount_pos
		player.velocity = Vector2.ZERO
		# Flip the player to face the opposite direction
		player.sprite.flip_h = !player.sprite.flip_h
		state_machine.transition_to("Idle")
		return
	
	# Handle climbing up with jump
	if Input.is_action_just_pressed("jump") and can_climb:
		print("DEBUG: Climbing up ledge")
		player.velocity = CLIMB_FORCE
		player.velocity.x = facing_direction * 150  # Horizontal boost for smoother climb
		state_machine.transition_to("Jump")
		return
	
	# Handle letting go
	var input_dir = Input.get_axis("left", "right")
	if Input.is_action_just_pressed("down") or input_dir * facing_direction < 0:
		print("DEBUG: Letting go of ledge - Input dir:", input_dir, " Facing:", facing_direction)
		player.velocity = Vector2.ZERO  # Reset velocity before falling
		player.ledge_grab_cooldown_timer = LEDGE_GRAB_COOLDOWN  # Start cooldown
		state_machine.transition_to("Fall")
		return
	
	# Keep player in place
	player.velocity = Vector2.ZERO
	player.global_position = ledge_position + (LEDGE_OFFSET * Vector2(facing_direction, 1))  # Flip X offset based on facing direction

func enter():
	print("DEBUG: Entering ledge grab state")
	animation_player.stop()
	animation_player.play("ledge_grab")
	
	# Store ledge position and facing direction
	var ledge_data = _get_ledge_position()
	ledge_position = ledge_data.position
	facing_direction = ledge_data.direction
	
	if ledge_position == Vector2.ZERO:
		print("DEBUG: No valid ledge found")
		state_machine.transition_to("Fall")
		return
	
	# Snap to ledge position with offset (flipped based on direction)
	player.global_position = ledge_position + (LEDGE_OFFSET * Vector2(facing_direction, 1))
	player.velocity = Vector2.ZERO
	grab_timer = LEDGE_GRAB_DURATION
	can_climb = true
	
	# Face the correct direction - when grabbing left wall, face right and vice versa
	player.sprite.flip_h = facing_direction > 0  # Inverted logic for correct facing
	
	print("DEBUG: Grabbed ledge at:", ledge_position, " facing:", facing_direction)

func _get_ledge_position() -> Dictionary:
	var result = {"position": Vector2.ZERO, "direction": 0}
	
	# Get input direction
	var input_dir = Input.get_axis("left", "right")
	var chosen_direction = input_dir if input_dir != 0 else -1 if player.velocity.x < 0 else 1 if player.velocity.x > 0 else 0
	
	# Check wall collisions
	var left_wall = wall_ray_left.is_colliding()
	var right_wall = wall_ray_right.is_colliding()
	
	# Only print when there's a potential ledge grab
	if left_wall or right_wall:
		print("DEBUG: Ledge check - Wall:", "Left" if left_wall else "Right", "Dir:", chosen_direction)
		print("DEBUG: Top rays - Left:", ledge_ray_top_left.is_colliding(), "Right:", ledge_ray_top_right.is_colliding())
	
	# Check left side
	if chosen_direction <= 0 and left_wall and not ledge_ray_top_left.is_colliding():
		result.position = wall_ray_left.get_collision_point()
		result.direction = -1
		return result
	
	# Check right side
	if chosen_direction >= 0 and right_wall and not ledge_ray_top_right.is_colliding():
		result.position = wall_ray_right.get_collision_point()
		result.direction = 1
		return result
	
	return result

func can_ledge_grab() -> bool:
	# Check cooldown first
	if player.ledge_grab_cooldown_timer > 0:
		print("DEBUG: Ledge grab on cooldown:", player.ledge_grab_cooldown_timer)
		return false
		
	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	
	# Only print when we find a valid ledge
	if can_grab:
		print("DEBUG: Valid ledge found at", ledge.position, "Dir:", ledge.direction)
	
	return can_grab
