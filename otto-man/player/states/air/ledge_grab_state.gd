extends State

const LEDGE_GRAB_DURATION := 0.2
const CLIMB_FORCE := Vector2(0, -400)
const LEDGE_OFFSET := Vector2(-6, 36)  # Adjusted X offset (-9 + 3 = -6) to move player 3px closer to the wall
const GRAB_DISTANCE := 20.0
const MOUNT_OFFSET := Vector2(0, -5)  # Vertical offset to move player down (negative = down)
const MOUNT_FORWARD_OFFSET := 20  # How many pixels to move forward onto the platform
const LEDGE_GRAB_COOLDOWN := 0.3  # Cooldown duration after letting go (increased for post-jump detection)

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
var ledge_y_cache := {}  # hysteresis cache: key = rounded wall X, value = aligned ledge Y

func _ready():
	# REMOVED node assignment from here
	pass

func physics_update(delta: float):
	if grab_timer > 0:
		grab_timer -= delta
	
	# Handle instant mounting with up button
	if Input.is_action_just_pressed("up") and can_climb:
		print("[LedgeGrab] Up button pressed, starting teleport...")
		print("[LedgeGrab] Ledge position: ", ledge_position)
		print("[LedgeGrab] MOUNT_OFFSET: ", MOUNT_OFFSET)
		print("[LedgeGrab] MOUNT_FORWARD_OFFSET: ", MOUNT_FORWARD_OFFSET)
		print("[LedgeGrab] Facing direction: ", facing_direction)
		
		# Compute initial mount position
		var base_mount = ledge_position + MOUNT_OFFSET
		base_mount.x += facing_direction * MOUNT_FORWARD_OFFSET
		
		# Refine to a safe mount (back off a bit if tight tunnel)
		var mount_pos = _find_safe_mount_position(base_mount, facing_direction)
		
		# Ensure small collider BEFORE teleporting (avoid wedging)
		var crouch_state_pre = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state_pre and crouch_state_pre.has_method("apply_crouch_shape_now"):
			print("[LedgeGrab] Applying crouch collider before teleport")
			crouch_state_pre.apply_crouch_shape_now()
		
		print("[LedgeGrab] Mount position: ", mount_pos)
		print("[LedgeGrab] Current player position: ", player.global_position)
		
		# Set position directly without move_and_slide to avoid collision issues
		player.global_position = mount_pos
		player.velocity = Vector2.ZERO
		
		print("[LedgeGrab] After position set: ", player.global_position)
		print("[LedgeGrab] Is on floor after position set: ", player.is_on_floor())
		
		# Snap to ground and register floor contact
		var space_state = player.get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.new()
		query.from = player.global_position
		query.to = player.global_position + Vector2.DOWN * 64
		query.exclude = [player]
		var result = space_state.intersect_ray(query)
		if result:
			player.global_position.y = result.position.y - 1
			player.velocity.y = 5
			player.move_and_slide()
		
		print("[LedgeGrab] After snap+slide: ", player.global_position, " on_floor=", player.is_on_floor())
		
		# Force crouch on mount (longer if headroom tight)
		var headroom_tight := _is_tight_headroom(player.global_position)
		var extra_crouch := 0.1  # shortened minimum crouch after ledgegrab
		print("[LedgeGrab] Headroom tight=", headroom_tight, " extra_crouch=", extra_crouch)
		var crouch_state = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state and crouch_state.has_method("force_crouch"):
			print("[LedgeGrab] Calling Crouch.force_crouch()")
			crouch_state.force_crouch(extra_crouch)
		else:
			print("[LedgeGrab] Crouch state or method not found; transitioning without force")
		state_machine.transition_to("Crouch")
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
	
	# Store current velocity and position
	var original_velocity = player.velocity
	var original_position = player.global_position
	# Freeze velocity during detection
	player.velocity = Vector2.ZERO
	
	# Store ledge position and facing direction
	var ledge_data = _get_ledge_position()
	ledge_position = ledge_data.position
	facing_direction = ledge_data.direction
	
	# Restore original position and velocity
	player.global_position = original_position
	player.velocity = original_velocity
	
	print("[LedgeGrab] Ledge detection - Ledge position: ", ledge_position)
	
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
		
	# --- REMOVED Debug Info ---
	
	var wl = player.get_node("WallRayLeft") as RayCast2D
	var wr = player.get_node("WallRayRight") as RayCast2D
	var sctl = player.get_node("LedgeShapeCastTopLeft") as ShapeCast2D
	var sctr = player.get_node("LedgeShapeCastTopRight") as ShapeCast2D
	
	# Check if nodes were found
	if not (wl and wr and sctl and sctr):
		push_error("LedgeGrab _get_ledge_position: Failed to find one or more RayCast/ShapeCast nodes on Player!")
		# REMOVED Debug prints for missing nodes
		if not wl: print(" - WallRayLeft not found") # Keeping error prints, removing debug prints
		if not wr: print(" - WallRayRight not found")
		if not sctl: print(" - LedgeShapeCastTopLeft not found")
		if not sctr: print(" - LedgeShapeCastTopRight not found")
		return {"position": Vector2.ZERO, "direction": 0}
			
	var result = {"position": Vector2.ZERO, "direction": 0}
	
	# Allow grab as long as the player is airborne
	if player.is_on_floor():
		# REMOVED Debug print for player on floor
		return result

	# Force shapecasts to update collision info - important before checking!
	sctl.force_shapecast_update()
	sctr.force_shapecast_update()
	
	# REMOVED Debug print for collision states (Left)
	var wl_colliding = wl.is_colliding()
	var sc_tl_colliding = sctl.is_colliding()
	# REMOVED ShapeCast Collision Details (Left)
	
	# Check left side
	# Condition: Wall detected on the left AND no collision directly above the left ledge point AND the shapecast is not colliding (clear space above)
	if wl_colliding and not sc_tl_colliding:
		# Use the wall ray's collision point for accurate vertical positioning
		var collision_point = wl.get_collision_point()
		
		print("[LedgeGrab] Left wall collision point: ", collision_point)
		
		# Find the actual ledge position by checking from just above downwards
		var ledge_y = collision_point.y
		var space_state = player.get_world_2d().direct_space_state
		var found_surface = false
		
		# Start from a reasonable distance above the collision point (max 32px, not 100px)
		for i in range(32):  # reduced scan range to 32px upwards
			var check_query = PhysicsRayQueryParameters2D.new()
			check_query.from = Vector2(collision_point.x + 4, collision_point.y - i - 2)
			check_query.to = Vector2(collision_point.x + 4, collision_point.y - i)
			check_query.exclude = [player]
			var check_result = space_state.intersect_ray(check_query)
			if check_result:
				ledge_y = collision_point.y - i
				found_surface = true
				print("[LedgeGrab] Found ledge surface at y: ", ledge_y, " (checked ", i, " pixels up)")
				break
		
		# If no surface found within reasonable range, use collision point
		if not found_surface:
			ledge_y = collision_point.y
			print("[LedgeGrab] No ledge surface found above, using collision point y: ", ledge_y)
		# Align vertically to 32px grid and apply hysteresis by X tile
		var ledge_y_aligned = floor(ledge_y / 32.0) * 32.0
		print("[LedgeGrab] Grid alignment: raw_y=", ledge_y, " aligned_y=", ledge_y_aligned)
		
		var key_x = int(round(collision_point.x / 32.0) * 32)
		if ledge_y_cache.has(key_x):
			var prev_y = ledge_y_cache[key_x]
			if abs(ledge_y_aligned - prev_y) <= 3:
				print("[LedgeGrab] Using cached Y position: ", prev_y, " (was ", ledge_y_aligned, ")")
				ledge_y_aligned = prev_y
		ledge_y_cache[key_x] = ledge_y_aligned
		var ledge_x = collision_point.x + 4
		result.position = Vector2(ledge_x, ledge_y_aligned)
		result.direction = -1  # Grabbing left wall, player should face right
		print("[LedgeGrab] Final left ledge position: ", result.position)
		return result
		
	# REMOVED Debug print for collision states (Right)
	var wr_colliding = wr.is_colliding()
	var sc_tr_colliding = sctr.is_colliding()
	# REMOVED ShapeCast Collision Details (Right)
	
	# Check right side
	# Condition: Wall detected on the right AND no collision directly above the right ledge point AND the shapecast is not colliding (clear space above)
	if wr_colliding and not sc_tr_colliding:
		var collision_point = wr.get_collision_point()
		print("[LedgeGrab] Right wall collision point: ", collision_point)
		
		# Find the actual ledge position by checking from just above downwards
		var ledge_y = collision_point.y
		var space_state = player.get_world_2d().direct_space_state
		var found_surface = false
		
		# Start from a reasonable distance above the collision point (max 32px, not 100px)
		for i in range(32):  # reduced scan range to 32px upwards
			var check_query = PhysicsRayQueryParameters2D.new()
			check_query.from = Vector2(collision_point.x - 4, collision_point.y - i - 2)
			check_query.to = Vector2(collision_point.x - 4, collision_point.y - i)
			check_query.exclude = [player]
			var check_result = space_state.intersect_ray(check_query)
			if check_result:
				ledge_y = collision_point.y - i
				found_surface = true
				print("[LedgeGrab] Found ledge surface at y: ", ledge_y, " (checked ", i, " pixels up)")
				break
		
		# If no surface found within reasonable range, use collision point
		if not found_surface:
			ledge_y = collision_point.y
			print("[LedgeGrab] No ledge surface found above, using collision point y: ", ledge_y)
		# Align vertically to 32px grid and apply hysteresis by X tile
		var ledge_y_aligned = floor(ledge_y / 32.0) * 32.0
		print("[LedgeGrab] Grid alignment: raw_y=", ledge_y, " aligned_y=", ledge_y_aligned)
		
		var key_x = int(round(collision_point.x / 32.0) * 32)
		if ledge_y_cache.has(key_x):
			var prev_y = ledge_y_cache[key_x]
			if abs(ledge_y_aligned - prev_y) <= 3:
				print("[LedgeGrab] Using cached Y position: ", prev_y, " (was ", ledge_y_aligned, ")")
				ledge_y_aligned = prev_y
		ledge_y_cache[key_x] = ledge_y_aligned
		var ledge_x = collision_point.x - 4
		result.position = Vector2(ledge_x, ledge_y_aligned)
		result.direction = 1  # Grabbing right wall, player should face left
		print("[LedgeGrab] Final right ledge position: ", result.position)
		return result
	
	# REMOVED Debug print for no ledge detected
	return result

func can_ledge_grab() -> bool:
	# Node checks are now handled inside _get_ledge_position

	# Check cooldown first
	# REMOVED Debug print for cooldown timer
	if player.ledge_grab_cooldown_timer > 0:
		# REMOVED Debug print for cooldown active
		return false
		
	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	# REMOVED Debug print for _get_ledge_position result
	
	return can_grab

func _has_wall_ahead(at_pos: Vector2, facing_dir: int) -> bool:
	var space_state = player.get_world_2d().direct_space_state
	var head_y = at_pos.y - 22  # approx half-height for standing bottom-origin
	var from_pt = Vector2(at_pos.x + facing_dir * 4, head_y)
	var to_pt = Vector2(at_pos.x + facing_dir * 12, head_y)
	var q = PhysicsRayQueryParameters2D.new()
	q.from = from_pt
	q.to = to_pt
	q.exclude = [player]
	var res = space_state.intersect_ray(q)
	return res != null

func _ground_snap(at_pos: Vector2) -> Vector2:
	var space_state = player.get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.new()
	q.from = at_pos
	q.to = at_pos + Vector2.DOWN * 64
	q.exclude = [player]
	var res = space_state.intersect_ray(q)
	if res:
		return Vector2(at_pos.x, res.position.y - 1)
	return at_pos

func _find_safe_mount_position(base_mount: Vector2, facing_dir: int) -> Vector2:
	print("[LedgeGrab] Finding safe mount position from base: ", base_mount, " facing_dir: ", facing_dir)
	
	# Try a few forward back-offs and small vertical pulls to avoid tight tunnel walls
	var forward_candidates = [MOUNT_FORWARD_OFFSET, 16, 12, 8, 4, 0, -4]
	var vertical_deltas = [0, -4, -8, -12]
	
	for f in forward_candidates:
		for dy in vertical_deltas:
			var candidate = Vector2(ledge_position.x + facing_dir * f, base_mount.y + dy)
			var snapped_candidate = _ground_snap(candidate)
			var has_wall = _has_wall_ahead(snapped_candidate, facing_dir)
			
			print("[LedgeGrab] Testing candidate f=", f, " dy=", dy, " pos=", candidate, " snapped=", snapped_candidate, " has_wall=", has_wall)
			
			if not has_wall:
				print("[LedgeGrab] Safe mount position found: ", snapped_candidate)
				return snapped_candidate
	
	# Fallback
	var fallback = _ground_snap(base_mount)
	print("[LedgeGrab] Using fallback mount position: ", fallback)
	return fallback

func _is_tight_headroom(at_pos: Vector2) -> bool:
	var space_state = player.get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.new()
	q.from = at_pos
	q.to = at_pos + Vector2.UP * 48
	q.exclude = [player]
	var res = space_state.intersect_ray(q)
	return res != null
