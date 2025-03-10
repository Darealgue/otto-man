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
	

func physics_update(delta: float):
	if grab_timer > 0:
		grab_timer -= delta
	
	# Handle instant mounting with up button
	if Input.is_action_just_pressed("up") and can_climb:
		# Move player to top of platform and forward
		var mount_pos = ledge_position + MOUNT_OFFSET
		mount_pos.x += facing_direction * MOUNT_FORWARD_OFFSET  # Move in the direction we're facing
		
		# Smoothly interpolate to the mount position
		player.global_position = player.global_position.lerp(mount_pos, 0.5)
		player.velocity = Vector2.ZERO
		
		# Keep the same sprite direction - don't flip
		
		# Ensure we're on the ground before transitioning to idle
		if player.is_on_floor():
			animation_player.play("idle")
			state_machine.transition_to("Idle")
		else:
			# If somehow not on floor, transition to fall
			animation_player.play("fall")
			state_machine.transition_to("Fall")
		return
	
	# Handle climbing up with jump
	if Input.is_action_just_pressed("jump") and can_climb:
		player.velocity = CLIMB_FORCE
		player.velocity.x = facing_direction * 150  # Horizontal boost for smoother climb
		animation_player.play("jump_upwards")  # Play jump animation when climbing
		state_machine.transition_to("Jump")
		return
	
	# Handle letting go
	var input_dir = Input.get_axis("left", "right")
	if Input.is_action_just_pressed("down") or input_dir * facing_direction < 0:
		player.velocity = Vector2.ZERO  # Reset velocity before falling
		player.ledge_grab_cooldown_timer = LEDGE_GRAB_COOLDOWN  # Start cooldown
		animation_player.play("fall")  # Play fall animation when letting go
		state_machine.transition_to("Fall")
		return
	
	# Keep player in place
	player.velocity = Vector2.ZERO
	player.global_position = ledge_position + (LEDGE_OFFSET * Vector2(facing_direction, 1))  # Flip X offset based on facing direction

func enter():
	animation_player.stop()
	animation_player.play("ledge_grab")
	
	# Store ledge position and facing direction
	var ledge_data = _get_ledge_position()
	ledge_position = ledge_data.position
	facing_direction = ledge_data.direction
	
	if ledge_position == Vector2.ZERO:
		state_machine.transition_to("Fall")
		return
	
	# Snap to ledge position with offset (flipped based on direction)
	player.global_position = ledge_position + (LEDGE_OFFSET * Vector2(facing_direction, 1))
	player.velocity = Vector2.ZERO
	grab_timer = LEDGE_GRAB_DURATION
	can_climb = true
	
	# Face the correct direction - when grabbing left wall, face right and vice versa
	# When grabbing a ledge, we want to face towards the wall
	player.sprite.flip_h = facing_direction < 0  # Face towards the wall
	

func _get_ledge_position() -> Dictionary:
	var result = {"position": Vector2.ZERO, "direction": 0}
	
	# Get input direction
	var input_dir = Input.get_axis("left", "right")
	var chosen_direction = input_dir if input_dir != 0 else -1 if player.velocity.x < 0 else 1 if player.velocity.x > 0 else 0
	
	# Check wall collisions
	var left_wall = wall_ray_left.is_colliding()
	var right_wall = wall_ray_right.is_colliding()
	
	# Check left side
	if chosen_direction <= 0 and left_wall and not ledge_ray_top_left.is_colliding():
		result.position = wall_ray_left.get_collision_point()
		result.direction = -1  # Grabbing left wall, face right
		return result
	
	# Check right side
	if chosen_direction >= 0 and right_wall and not ledge_ray_top_right.is_colliding():
		result.position = wall_ray_right.get_collision_point()
		result.direction = 1  # Grabbing right wall, face left
		return result
	
	return result

func can_ledge_grab() -> bool:
	# Check cooldown first
	if player.ledge_grab_cooldown_timer > 0:
		return false
		
	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	
	return can_grab
