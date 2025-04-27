extends State

const LEDGE_GRAB_DURATION := 0.2
const CLIMB_FORCE := Vector2(0, -400)
const LEDGE_OFFSET := Vector2(-9, 36)  # Adjusted Y offset (41 - 5 = 36) to move player 5px higher
const GRAB_DISTANCE := 20.0
const MOUNT_OFFSET := Vector2(0, -37)  # Vertical offset to clear the platform (adjusted -32 - 5 = -37)
const MOUNT_FORWARD_OFFSET := 20  # How many pixels to move forward onto the platform
const LEDGE_GRAB_COOLDOWN := 0.2  # Cooldown duration after letting go

# Node references will be assigned in enter() using the player variable
# REMOVING class-level variables, will get them inside functions
# REMOVED: var wall_ray_left: RayCast2D
# REMOVED: var wall_ray_right: RayCast2D
# REMOVED: var ledge_shape_cast_top_left: ShapeCast2D
# REMOVED: var ledge_shape_cast_top_right: ShapeCast2D

var grab_timer := 0.0
var ledge_position := Vector2.ZERO
var can_climb := false
var facing_direction := 1

func _ready():
	# REMOVED node assignment from here
	pass

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
	# Ensure player reference is valid before accessing nodes
	if !player:
		# This check might be redundant if _ready succeeded, but kept for safety
		push_error("LedgeGrabState enter: Player reference not set!")
		state_machine.transition_to("Fall") # Transition to a safe state
		return

	# REMOVED Node assignment from here
	# REMOVED Node check from here
	
	# Nodes can be enabled here if they are disabled by default
	# Make sure node variables are valid before enabling
	# if wall_ray_left: wall_ray_left.enabled = true 
	# ... etc

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
	# Get node references directly using the player variable when needed
	if not player:
		push_error("LedgeGrab _get_ledge_position: Player reference is null!")
		return {"position": Vector2.ZERO, "direction": 0}
		
	# --- DEBUG: Print player path and children --- 
	print("--- LedgeGrab Debug Info ---")
	print("Player node path: ", player.get_path())
	print("Player children nodes: ", player.get_children())
	print("-----------------------------")
	# --- End Debug ---
	
	var wl = player.get_node("WallRayLeft") as RayCast2D
	var wr = player.get_node("WallRayRight") as RayCast2D
	var sctl = player.get_node("LedgeShapeCastTopLeft") as ShapeCast2D
	var sctr = player.get_node("LedgeShapeCastTopRight") as ShapeCast2D
	
	# Check if nodes were found
	if not (wl and wr and sctl and sctr):
		push_error("LedgeGrab _get_ledge_position: Failed to find one or more RayCast/ShapeCast nodes on Player!")
		# DEBUG: Print which nodes were not found
		if not wl: print(" - WallRayLeft not found")
		if not wr: print(" - WallRayRight not found")
		if not sctl: print(" - LedgeShapeCastTopLeft not found")
		if not sctr: print(" - LedgeShapeCastTopRight not found")
		return {"position": Vector2.ZERO, "direction": 0}
			
	var result = {"position": Vector2.ZERO, "direction": 0}

	# Allow grab as long as the player is airborne
	if player.is_on_floor():
		print("[LedgeGrab] _get_ledge_position: Player is on floor, exiting.") # DEBUG
		return result

	# Force shapecasts to update collision info - important before checking!
	sctl.force_shapecast_update()
	sctr.force_shapecast_update()
	
	# DEBUG: Print collision states
	var wl_colliding = wl.is_colliding()
	var sc_tl_colliding = sctl.is_colliding()
	print("[LedgeGrab] _get_ledge_position: Left Side - WallRay: ", wl_colliding, ", ShapeCastTop: ", sc_tl_colliding) # DEBUG
	# --- Added ShapeCast Collision Details --- 
	if sc_tl_colliding:
		print("  [Debug] Left ShapeCast colliding with: ", sctl.get_collider(0), " at point: ", sctl.get_collision_point(0))
	# --- End Added Details ---

	# Check left side
	# Condition: Wall detected on the left AND no collision directly above the left ledge point AND the shapecast is not colliding (clear space above)
	if wl_colliding and not sc_tl_colliding:
		# Use the wall ray's collision point for accurate vertical positioning
		var collision_point = wl.get_collision_point()
		# Use the wall ray's collision point X + offset for horizontal positioning
		result.position = Vector2(collision_point.x + 4, collision_point.y) # Adjusted horizontal offset from 8 to 4
		result.direction = -1  # Grabbing left wall, player should face right
		print("[LedgeGrab] Left ledge DETECTED. Collision Y: ", collision_point.y) # DEBUG Y value
		return result
		
	# DEBUG: Print collision states for right side
	var wr_colliding = wr.is_colliding()
	var sc_tr_colliding = sctr.is_colliding()
	print("[LedgeGrab] _get_ledge_position: Right Side - WallRay: ", wr_colliding, ", ShapeCastTop: ", sc_tr_colliding) # DEBUG
	# --- Added ShapeCast Collision Details --- 
	if sc_tr_colliding:
		print("  [Debug] Right ShapeCast colliding with: ", sctr.get_collider(0), " at point: ", sctr.get_collision_point(0))
	# --- End Added Details ---

	# Check right side
	# Condition: Wall detected on the right AND no collision directly above the right ledge point AND the shapecast is not colliding (clear space above)
	if wr_colliding and not sc_tr_colliding:
		var collision_point = wr.get_collision_point()
		# Use the wall ray's collision point X - offset for horizontal positioning
		result.position = Vector2(collision_point.x - 4, collision_point.y) # Adjusted horizontal offset from 8 to 4
		result.direction = 1  # Grabbing right wall, player should face left
		print("[LedgeGrab] Right ledge DETECTED. Collision Y: ", collision_point.y) # DEBUG Y value
		return result

	print("[LedgeGrab] _get_ledge_position: No ledge detected.") # DEBUG
	return result

func can_ledge_grab() -> bool:
	# Node checks are now handled inside _get_ledge_position

	# Check cooldown first
	print("[LedgeGrab] can_ledge_grab: Cooldown timer = ", player.ledge_grab_cooldown_timer) # DEBUG
	if player.ledge_grab_cooldown_timer > 0:
		print("[LedgeGrab] can_ledge_grab: Cooldown active, returning false.") # DEBUG
		return false
		
	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	print("[LedgeGrab] can_ledge_grab: Result from _get_ledge_position = ", ledge, ", Can Grab = ", can_grab) # DEBUG
	
	return can_grab
