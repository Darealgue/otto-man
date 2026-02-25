extends State

const LEDGE_GRAB_DURATION := 0.2
const CLIMB_FORCE := Vector2(0, -400)
const LEDGE_OFFSET := Vector2(-4, 36)  # Adjusted X offset to move player even closer to the wall for better grab
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
		# # print("[LedgeGrab] Up button pressed, starting teleport...")
		# # print("[LedgeGrab] Ledge position: ", ledge_position)
		# # print("[LedgeGrab] MOUNT_OFFSET: ", MOUNT_OFFSET)
		# # print("[LedgeGrab] MOUNT_FORWARD_OFFSET: ", MOUNT_FORWARD_OFFSET)
		# # print("[LedgeGrab] Facing direction: ", facing_direction)
		
		# Compute initial mount position
		var base_mount = ledge_position + MOUNT_OFFSET
		base_mount.x += facing_direction * MOUNT_FORWARD_OFFSET
		
		# Check if there's a wall ahead at the mount position - if so, don't allow climbing
		if _has_wall_ahead_at_mount_position(base_mount, facing_direction):
			# print("[LedgeGrab] Wall detected ahead at mount position, blocking climb")
			return
		
		# Refine to a safe mount (back off a bit if tight tunnel)
		var mount_pos = _find_safe_mount_position(base_mount, facing_direction)
		
		# Ensure small collider BEFORE teleporting (avoid wedging)
		var crouch_state_pre = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state_pre and crouch_state_pre.has_method("apply_crouch_shape_now"):
			# # print("[LedgeGrab] Applying crouch collider before teleport")
			crouch_state_pre.apply_crouch_shape_now()
		
		# # print("[LedgeGrab] Mount position: ", mount_pos)
		# # print("[LedgeGrab] Current player position: ", player.global_position)
		
		# Set position directly without move_and_slide to avoid collision issues
		player.global_position = mount_pos
		player.velocity = Vector2.ZERO
		
		# # print("[LedgeGrab] After position set: ", player.global_position)
		# # print("[LedgeGrab] Is on floor after position set: ", player.is_on_floor())
		
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
			player.apply_move_and_slide()
		
		# print("[LedgeGrab] After snap+slide: ", player.global_position, " on_floor=", player.is_on_floor())
		
		# Force crouch on mount (longer if headroom tight)
		var headroom_tight := _is_tight_headroom(player.global_position)
		var extra_crouch := 0.1  # shortened minimum crouch after ledgegrab
		# print("[LedgeGrab] Headroom tight=", headroom_tight, " extra_crouch=", extra_crouch)
		var crouch_state = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state and crouch_state.has_method("force_crouch"):
			# print("[LedgeGrab] Calling Crouch.force_crouch()")
			crouch_state.force_crouch(extra_crouch)
		else:
			pass
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
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
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
	
	# # print("[LedgeGrab] Ledge detection - Ledge position: ", ledge_position)
	
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
	
	# NEW: Simple check - if player is VERY CLOSE to platform tiles, disable ledgegrab
	# Gevşetilmiş kontrol - sadece çok yakınsa engelle
	if _is_player_very_close_to_platform_tiles():
		print("[LEDGEGRAB_DEBUG] Player very close to platform tiles, disabling ledgegrab")
		return result

	# Force shapecasts to update collision info - important before checking!
	sctl.force_shapecast_update()
	sctr.force_shapecast_update()
	
	# REMOVED Debug print for collision states (Left)
	var wl_colliding = wl.is_colliding()
	var sc_tl_colliding = sctl.is_colliding()
	# REMOVED ShapeCast Collision Details (Left)
	
	# Check left side
	# Condition: Wall detected on the left AND shapecast is not heavily colliding - more lenient for better detection
	# Allow ledge grab even if shapecast is slightly colliding (more forgiving)
	if wl_colliding and not sc_tl_colliding:
		# Additional check: Make sure there's actually a platform above the wall (real ledge)
		var collision_point = wl.get_collision_point()
		
		print("[LEDGEGRAB_DEBUG] ===== LEFT SIDE CHECK =====")
		print("[LEDGEGRAB_DEBUG] Player position: ", player.global_position)
		print("[LEDGEGRAB_DEBUG] Collision point: ", collision_point)
		print("[LEDGEGRAB_DEBUG] Wall ray left colliding: ", wl_colliding)
		print("[LEDGEGRAB_DEBUG] ShapeCast top left colliding: ", sc_tl_colliding)
		
		# NEW: Check if there are any platform tiles VERY CLOSE - if so, disable ledgegrab
		# Gevşetilmiş kontrol - sadece çok yakınsa engelle
		if _has_platform_tiles_very_close(collision_point, -1):
			print("[LEDGEGRAB_DEBUG] Left side - Platform tiles very close, blocking ledgegrab")
			return result  # Block ledgegrab if platform tiles are very close
		
		# NEW: Check if player is VERY CLOSE to platform tiles - if so, disable ledgegrab
		# Gevşetilmiş kontrol - sadece çok yakınsa engelle
		if _is_player_very_close_to_platform_tiles():
			print("[LEDGEGRAB_DEBUG] Left side - Player very close to platform tiles, blocking ledgegrab")
			return result  # Block ledgegrab if player is very close to platform tiles
		
		# Check for flat wall at player height - CRITICAL for preventing grab on flat walls
		# İYİLEŞTİRME: Flat wall kontrolünü platform kontrolünden SONRA yap
		# Önce platform var mı kontrol et, sonra flat wall kontrolü yap
		var is_real = _is_real_ledge(collision_point, -1)  # -1 for left side
		
		# Eğer gerçek bir ledge bulunduysa, flat wall kontrolü yap
		# Bu, gerçek köşelerin flat wall olarak algılanmasını önler
		if is_real:
			# Gerçek ledge bulundu - flat wall kontrolü yapma, direkt geç
			pass
		elif _is_flat_wall_at_player_height(-1):
			print("[LEDGEGRAB_DEBUG] Left side - FLAT WALL detected at player height, BLOCKING ledgegrab")
			return result  # Flat wall detected, skip
		print("[LEDGEGRAB_DEBUG] Left side - is_real_ledge: ", is_real)
		if not is_real:
			print("[LEDGEGRAB_DEBUG] Left side - NOT a real ledge, skipping")
			return result  # Not a real ledge, skip
		
		print("[LEDGEGRAB_DEBUG] Left side - VALID LEDGE FOUND!")
		
		# NEW: Check for flat wall using horizontal raycast from player's collision height
		# TEMPORARILY DISABLED FOR TESTING
		# if _is_flat_wall_at_player_height(-1):  # -1 for left side
		#	print("[LEDGEGRAB_DEBUG] Left side - flat wall detected at player height, blocking ledgegrab")
		#	return result  # Flat wall detected, skip
		
		# print("[LedgeGrab] Left wall collision point: ", collision_point)
		
		# Find the actual ledge position by checking from just above downwards
		var ledge_y = collision_point.y
		var space_state = player.get_world_2d().direct_space_state
		var found_surface = false
		
		# Start from a reasonable distance above the collision point (increased range for better detection)
		for i in range(48):  # increased scan range to 48px upwards for better ledge detection
			var check_query = PhysicsRayQueryParameters2D.new()
			check_query.from = Vector2(collision_point.x + 4, collision_point.y - i - 2)
			check_query.to = Vector2(collision_point.x + 4, collision_point.y - i)
			check_query.exclude = [player]
			var check_result = space_state.intersect_ray(check_query)
			if check_result:
				ledge_y = collision_point.y - i
				found_surface = true
				# print("[LedgeGrab] Found ledge surface at y: ", ledge_y, " (checked ", i, " pixels up)")
				break
		
		# If no surface found within reasonable range, use collision point
		if not found_surface:
			ledge_y = collision_point.y
			# print("[LedgeGrab] No ledge surface found above, using collision point y: ", ledge_y)
		# Align vertically to 32px grid and apply hysteresis by X tile
		var ledge_y_aligned = floor(ledge_y / 32.0) * 32.0
		# print("[LedgeGrab] Grid alignment: raw_y=", ledge_y, " aligned_y=", ledge_y_aligned)
		
		var key_x = int(round(collision_point.x / 32.0) * 32)
		if ledge_y_cache.has(key_x):
			var prev_y = ledge_y_cache[key_x]
			if abs(ledge_y_aligned - prev_y) <= 3:
				# print("[LedgeGrab] Using cached Y position: ", prev_y, " (was ", ledge_y_aligned, ")")
				ledge_y_aligned = prev_y
		ledge_y_cache[key_x] = ledge_y_aligned
		var ledge_x = collision_point.x + 4
		result.position = Vector2(ledge_x, ledge_y_aligned)
		result.direction = -1  # Grabbing left wall, player should face right
		# print("[LedgeGrab] Final left ledge position: ", result.position)
		return result
		
	# REMOVED Debug print for collision states (Right)
	var wr_colliding = wr.is_colliding()
	var sc_tr_colliding = sctr.is_colliding()
	# REMOVED ShapeCast Collision Details (Right)
	
	# Check right side
	# Condition: Wall detected on the right AND shapecast is not heavily colliding - more lenient for better detection
	# Allow ledge grab even if shapecast is slightly colliding (more forgiving)
	if wr_colliding and not sc_tr_colliding:
		# Additional check: Make sure there's actually a platform above the wall (real ledge)
		var collision_point = wr.get_collision_point()
		
		print("[LEDGEGRAB_DEBUG] ===== RIGHT SIDE CHECK =====")
		print("[LEDGEGRAB_DEBUG] Player position: ", player.global_position)
		print("[LEDGEGRAB_DEBUG] Collision point: ", collision_point)
		print("[LEDGEGRAB_DEBUG] Wall ray right colliding: ", wr_colliding)
		print("[LEDGEGRAB_DEBUG] ShapeCast top right colliding: ", sc_tr_colliding)
		
		# NEW: Check if there are any platform tiles VERY CLOSE - if so, disable ledgegrab
		# Gevşetilmiş kontrol - sadece çok yakınsa engelle
		if _has_platform_tiles_very_close(collision_point, 1):
			print("[LEDGEGRAB_DEBUG] Right side - Platform tiles very close, blocking ledgegrab")
			return result  # Block ledgegrab if platform tiles are very close
		
		# NEW: Check if player is VERY CLOSE to platform tiles - if so, disable ledgegrab
		# Gevşetilmiş kontrol - sadece çok yakınsa engelle
		if _is_player_very_close_to_platform_tiles():
			print("[LEDGEGRAB_DEBUG] Right side - Player very close to platform tiles, blocking ledgegrab")
			return result  # Block ledgegrab if player is very close to platform tiles
		
		# Check for flat wall at player height - CRITICAL for preventing grab on flat walls
		# İYİLEŞTİRME: Flat wall kontrolünü platform kontrolünden SONRA yap
		# Önce platform var mı kontrol et, sonra flat wall kontrolü yap
		var is_real = _is_real_ledge(collision_point, 1)  # 1 for right side
		
		# Eğer gerçek bir ledge bulunduysa, flat wall kontrolü yapma
		# Bu, gerçek köşelerin flat wall olarak algılanmasını önler
		if is_real:
			# Gerçek ledge bulundu - flat wall kontrolü yapma, direkt geç
			pass
		elif _is_flat_wall_at_player_height(1):
			print("[LEDGEGRAB_DEBUG] Right side - FLAT WALL detected at player height, BLOCKING ledgegrab")
			return result  # Flat wall detected, skip
		print("[LEDGEGRAB_DEBUG] Right side - is_real_ledge: ", is_real)
		if not is_real:
			print("[LEDGEGRAB_DEBUG] Right side - NOT a real ledge, skipping")
			return result  # Not a real ledge, skip
		
		print("[LEDGEGRAB_DEBUG] Right side - VALID LEDGE FOUND!")
		
		# NEW: Check for flat wall using horizontal raycast from player's collision height
		# TEMPORARILY DISABLED FOR TESTING
		# if _is_flat_wall_at_player_height(1):  # 1 for right side
		#	print("[LEDGEGRAB_DEBUG] Right side - flat wall detected at player height, blocking ledgegrab")
		#	return result  # Flat wall detected, skip
		# print("[LedgeGrab] Right wall collision point: ", collision_point)
		
		# Find the actual ledge position by checking from just above downwards
		var ledge_y = collision_point.y
		var space_state = player.get_world_2d().direct_space_state
		var found_surface = false
		
		# Start from a reasonable distance above the collision point (increased range for better detection)
		for i in range(48):  # increased scan range to 48px upwards for better ledge detection
			var check_query = PhysicsRayQueryParameters2D.new()
			check_query.from = Vector2(collision_point.x - 4, collision_point.y - i - 2)
			check_query.to = Vector2(collision_point.x - 4, collision_point.y - i)
			check_query.exclude = [player]
			var check_result = space_state.intersect_ray(check_query)
			if check_result:
				ledge_y = collision_point.y - i
				found_surface = true
				# print("[LedgeGrab] Found ledge surface at y: ", ledge_y, " (checked ", i, " pixels up)")
				break
		
		# If no surface found within reasonable range, use collision point
		if not found_surface:
			ledge_y = collision_point.y
			# print("[LedgeGrab] No ledge surface found above, using collision point y: ", ledge_y)
		# Align vertically to 32px grid and apply hysteresis by X tile
		var ledge_y_aligned = floor(ledge_y / 32.0) * 32.0
		# print("[LedgeGrab] Grid alignment: raw_y=", ledge_y, " aligned_y=", ledge_y_aligned)
		
		var key_x = int(round(collision_point.x / 32.0) * 32)
		if ledge_y_cache.has(key_x):
			var prev_y = ledge_y_cache[key_x]
			if abs(ledge_y_aligned - prev_y) <= 3:
				# print("[LedgeGrab] Using cached Y position: ", prev_y, " (was ", ledge_y_aligned, ")")
				ledge_y_aligned = prev_y
		ledge_y_cache[key_x] = ledge_y_aligned
		var ledge_x = collision_point.x - 4
		result.position = Vector2(ledge_x, ledge_y_aligned)
		result.direction = 1  # Grabbing right wall, player should face left
		# print("[LedgeGrab] Final right ledge position: ", result.position)
		return result
	
	# REMOVED Debug print for no ledge detected
	return result

func can_ledge_grab() -> bool:
	# Node checks are now handled inside _get_ledge_position

	# Check cooldown first
	if player.ledge_grab_cooldown_timer > 0:
		return false
	
	# Ledge grab sadece korunma tuşuna basıldığında çalışır
	if not Input.is_action_pressed("block"):
		return false
		
	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	
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

func _has_wall_ahead_at_mount_position(at_pos: Vector2, facing_dir: int) -> bool:
	var space_state = player.get_world_2d().direct_space_state
	
	# More comprehensive check to prevent teleporting into walls
	var check_points = [
		# Close range checks (2-4 pixels)
		Vector2(at_pos.x + facing_dir * 2, at_pos.y - 22),  # Head level, close
		Vector2(at_pos.x + facing_dir * 2, at_pos.y - 11),  # Mid level, close
		Vector2(at_pos.x + facing_dir * 2, at_pos.y),       # Feet level, close
		Vector2(at_pos.x + facing_dir * 4, at_pos.y - 22),  # Head level, medium
		Vector2(at_pos.x + facing_dir * 4, at_pos.y - 11),  # Mid level, medium
		Vector2(at_pos.x + facing_dir * 4, at_pos.y),       # Feet level, medium
		# Medium range checks (6-8 pixels) - more strict for wall detection
		Vector2(at_pos.x + facing_dir * 6, at_pos.y - 22),  # Head level, far
		Vector2(at_pos.x + facing_dir * 6, at_pos.y - 11),  # Mid level, far
		Vector2(at_pos.x + facing_dir * 6, at_pos.y),       # Feet level, far
		Vector2(at_pos.x + facing_dir * 8, at_pos.y - 22),  # Head level, furthest
		Vector2(at_pos.x + facing_dir * 8, at_pos.y - 11),  # Mid level, furthest
		Vector2(at_pos.x + facing_dir * 8, at_pos.y)        # Feet level, furthest
	]
	
	for check_point in check_points:
		var q = PhysicsRayQueryParameters2D.new()
		q.from = check_point
		q.to = check_point + Vector2(facing_dir * 6, 0)  # Check 6 pixels ahead (increased from 4)
		q.exclude = [player]
		var res = space_state.intersect_ray(q)
		if res:
			return true  # Wall detected at any check point
	
	return false  # No wall detected

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
	# print("[LedgeGrab] Finding safe mount position from base: ", base_mount, " facing_dir: ", facing_dir)
	
	# Try a few forward back-offs and small vertical pulls to avoid tight tunnel walls
	var forward_candidates = [MOUNT_FORWARD_OFFSET, 16, 12, 8, 4, 0, -4]
	var vertical_deltas = [0, -4, -8, -12]
	
	for f in forward_candidates:
		for dy in vertical_deltas:
			var candidate = Vector2(ledge_position.x + facing_dir * f, base_mount.y + dy)
			var snapped_candidate = _ground_snap(candidate)
			var has_wall = _has_wall_ahead(snapped_candidate, facing_dir)
			
			# print("[LedgeGrab] Testing candidate f=", f, " dy=", dy, " pos=", candidate, " snapped=", snapped_candidate, " has_wall=", has_wall)
			
			if not has_wall:
				# print("[LedgeGrab] Safe mount position found: ", snapped_candidate)
				return snapped_candidate
	
	# Fallback
	var fallback = _ground_snap(base_mount)
	# print("[LedgeGrab] Using fallback mount position: ", fallback)
	return fallback

func _is_tight_headroom(at_pos: Vector2) -> bool:
	var space_state = player.get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.new()
	q.from = at_pos
	q.to = at_pos + Vector2.UP * 48
	q.exclude = [player]
	var res = space_state.intersect_ray(q)
	return res != null

func _is_real_ledge(collision_point: Vector2, side: int) -> bool:
	# Check if there's actually a platform above the wall (real ledge)
	var space_state = player.get_world_2d().direct_space_state
	
	# İYİLEŞTİRME: Tüm geçerli platformları topla, sonra en uygun olanı seç
	# Bu, köşenin 1 tile altındaki platformları engeller
	var valid_platforms = []  # Array of dictionaries: {height, width, x_offset, gap_size}
	var max_platform_width = 0
	
	# Check for platform above the wall at multiple heights and positions
	# Increased range for better detection
	for height in range(12, 56, 6):  # Check from 12px to 54px above wall (wider range)
		# Check multiple X positions to ensure it's a real platform, not just a corner
		for x_offset in range(-12, 20, 4):  # Check from -12 to +16 pixels horizontally (wider range)
			var check_pos = Vector2(collision_point.x + side * 4 + x_offset, collision_point.y - height)
			
			# Check if there's a platform at this height and position
			var q = PhysicsRayQueryParameters2D.new()
			q.from = check_pos
			q.to = check_pos + Vector2.DOWN * 8  # Check 8px down from this position
			q.exclude = [player]
			var res = space_state.intersect_ray(q)
			
			if res:
				# NEW: Check if this is a one-way platform - if so, don't allow ledgegrab
				if _is_one_way_platform(res.collider):
					print("[LEDGEGRAB_DEBUG] One-way platform detected, blocking ledgegrab")
					continue  # Skip this platform, check others
				
				# Found a platform - check if it's substantial enough
				var platform_width = 0
				# Check platform width by scanning horizontally (wider scan)
				for width_check in range(-16, 32, 4):  # Even wider scan range for better detection
					var width_pos = Vector2(check_pos.x + width_check, check_pos.y)
					var width_q = PhysicsRayQueryParameters2D.new()
					width_q.from = width_pos
					width_q.to = width_pos + Vector2.DOWN * 8
					width_q.exclude = [player]
					var width_res = space_state.intersect_ray(width_q)
					if width_res:
						platform_width += 4
				
				max_platform_width = max(max_platform_width, platform_width)
				
				# CRITICAL: Check if platform is actually ABOVE the collision point
				# Platform should be at least 8 pixels above the collision point to be a real ledge
				var platform_height_above_wall = height  # check_pos.y zaten collision_point.y - height
				var platform_above_collision = platform_height_above_wall >= 8
				
				# Gap kontrolü: Platform'un collision point'e göre yüksekliği = gap_size
				var gap_size = platform_height_above_wall  # Platform'un collision point'e olan mesafesi = gap
				
				print("[LEDGEGRAB_DEBUG] Platform check - height: ", height, " platform_height_above_wall: ", platform_height_above_wall, " platform_above_collision: ", platform_above_collision, " platform_width: ", platform_width, " gap_size: ", gap_size)
				
				# Only consider it a valid platform if:
				# 1. Platform is wide enough (at least 8px)
				# 2. Platform is actually ABOVE the collision point (not at the same level)
				# 3. Platform collision point'in üstünde olmalı (gap_size > 0)
				if platform_width >= 8 and platform_above_collision and gap_size > 0:
					# İYİLEŞTİRME: Platform'u listeye ekle, hemen durma
					valid_platforms.append({
						"height": height,
						"width": platform_width,
						"x_offset": x_offset,
						"gap_size": gap_size,
						"platform_above": platform_above_collision
					})
					print("[LEDGEGRAB_DEBUG] ✓ Found VALID platform candidate - height: ", height, " x_offset: ", x_offset, " platform_width: ", platform_width, " gap_size: ", gap_size)
				else:
					print("[LEDGEGRAB_DEBUG] ✗ Platform found but NOT valid - width: ", platform_width, " gap_size: ", gap_size, " platform_above: ", platform_above_collision, " (need: width>=8, gap>0, above=true)")
	
	# İYİLEŞTİRME: En uygun platformu seç
	# Öncelik sırası:
	# 1. En yakın platform (en küçük height/gap_size) - ama çok yakın değilse (12-24px ideal)
	# 2. En geniş platform (en büyük width)
	# 3. Köşenin 1 tile altındaki platformları engelle (height > 24px olanları daha düşük öncelik)
	if valid_platforms.size() > 0:
		var best_platform = null
		var best_score = -999999.0
		
		for platform in valid_platforms:
			var height = platform.height
			var width = platform.width
			var gap_size = platform.gap_size
			
			# Score hesaplama:
			# - İdeal yükseklik: 12-24px (köşeye yakın ama çok yakın değil)
			# - Çok yüksek platformlar (30px+) köşenin altındaki platformlar olabilir, düşük skor
			# - Geniş platformlar daha iyi
			var height_score = 0.0
			if height >= 12 and height <= 24:
				height_score = 100.0  # İdeal aralık
			elif height < 12:
				height_score = 50.0 - (12 - height) * 5.0  # Çok yakın, düşük skor
			else:
				height_score = 100.0 - (height - 24) * 3.0  # Çok uzak, düşük skor
			
			var width_score = width * 2.0  # Geniş platformlar daha iyi
			
			var total_score = height_score + width_score
			
			print("[LEDGEGRAB_DEBUG] Platform candidate score - height: ", height, " width: ", width, " height_score: ", height_score, " width_score: ", width_score, " total: ", total_score)
			
			if total_score > best_score:
				best_score = total_score
				best_platform = platform
		
		if best_platform:
			print("[LEDGEGRAB_DEBUG] ✓✓✓ BEST PLATFORM SELECTED - height: ", best_platform.height, " width: ", best_platform.width, " gap_size: ", best_platform.gap_size, " score: ", best_score)
			return true
	
	if valid_platforms.size() == 0:
		print("[LEDGEGRAB_DEBUG] ✗✗✗ NO REAL LEDGE FOUND - max_platform_width: ", max_platform_width, " collision_point: ", collision_point)
		return false
	
	# En uygun platform zaten seçildi ve true döndürüldü
	return true

func _is_one_way_platform(collider: Node2D) -> bool:
	# Check if the collider is a one-way platform
	if not collider:
		return false
	
	print("[LEDGEGRAB_DEBUG] Checking collider: ", collider.name, " class: ", collider.get_class())
	
	# Method 1: Check if it's a OneWayPlatform class
	if collider.get_class() == "OneWayPlatform":
		print("[LEDGEGRAB_DEBUG] Found OneWayPlatform class")
		return true
	
	# Method 2: Check if it's in the one-way platform group
	if collider.is_in_group("one_way_platforms"):
		print("[LEDGEGRAB_DEBUG] Found one_way_platforms group")
		return true
	
	# Method 3: Check if it's a TileMap with one-way collision
	if collider is TileMap:
		print("[LEDGEGRAB_DEBUG] Found TileMap, checking for one-way collision")
		# Check if this TileMap has one-way collision enabled
		# We'll check the collision at the specific position
		var space_state = player.get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = player.global_position
		query.collision_mask = 1  # Ground layer
		query.exclude = [player]
		
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider == collider:
				# Check if this collision has one-way properties
				if result.has("one_way_collision") and result.one_way_collision:
					print("[LEDGEGRAB_DEBUG] Found one-way collision in TileMap")
					return true
				break
	
	# Method 4: Check collision shape for one-way collision
	var collision_shape = collider.get_node_or_null("CollisionShape2D")
	if collision_shape:
		print("[LEDGEGRAB_DEBUG] Found CollisionShape2D, checking one-way collision")
		if collision_shape.one_way_collision:
			print("[LEDGEGRAB_DEBUG] Found one-way collision in CollisionShape2D")
			return true
	
	# Method 5: Check if it's a platform with one-way collision margin
	if collision_shape and collision_shape.one_way_collision_margin > 0:
		print("[LEDGEGRAB_DEBUG] Found one-way collision margin: ", collision_shape.one_way_collision_margin)
		return true
	
	print("[LEDGEGRAB_DEBUG] No one-way platform detected")
	return false

func _is_platform_tile_at_position(pos: Vector2) -> bool:
	# Check if there's a platform tile (terrain=1) at the given position
	var space_state = player.get_world_2d().direct_space_state
	
	# Use a small raycast to check for platform tiles
	var query = PhysicsRayQueryParameters2D.new()
	query.from = pos
	query.to = pos + Vector2.DOWN * 4  # Small downward ray
	query.collision_mask = 1  # Ground layer
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	if result:
		# Check if this is a TileMap
		if result.collider is TileMap:
			var tilemap = result.collider as TileMap
			var cell_pos = tilemap.local_to_map(result.position)
			var tile_data = tilemap.get_cell_tile_data(0, cell_pos)
			
			if tile_data:
				# Check if this tile has terrain=1 (platform)
				if tile_data.has_method("get_terrain"):
					var terrain = tile_data.get_terrain()
					if terrain == 1:
						print("[LEDGEGRAB_DEBUG] Found platform tile (terrain=1) at ", cell_pos)
						return true
				
				# Check if this tile has one-way collision
				if tile_data.has_method("get_collision_polygon_one_way"):
					var is_one_way = tile_data.get_collision_polygon_one_way(0, 0)
					if is_one_way:
						print("[LEDGEGRAB_DEBUG] Found one-way collision tile at ", cell_pos)
						return true
	
	return false

func _has_platform_tiles_nearby(collision_point: Vector2, side: int) -> bool:
	# Check if there are any platform tiles (terrain=1) nearby
	var space_state = player.get_world_2d().direct_space_state
	
	# Check a wider area around the collision point for platform tiles
	var check_radius = 64  # Check 64 pixels around the collision point
	var check_positions = []
	
	# Check multiple positions around the collision point
	for x_offset in range(-check_radius, check_radius + 1, 16):
		for y_offset in range(-check_radius, check_radius + 1, 16):
			var check_pos = collision_point + Vector2(x_offset, y_offset)
			check_positions.append(check_pos)
	
	# Check each position for platform tiles
	for pos in check_positions:
		if _is_platform_tile_at_position(pos):
			print("[LEDGEGRAB_DEBUG] Found platform tile at ", pos, " near collision point ", collision_point)
			return true
	
	return false

func _has_platform_tiles_very_close(collision_point: Vector2, side: int) -> bool:
	# Very strict check - only disable if platform tiles are VERY close
	# This allows ledge grab even when somewhat near platforms
	var space_state = player.get_world_2d().direct_space_state
	
	# Check a very small area around the collision point for platform tiles
	var check_radius = 24  # Check only 24 pixels around the collision point (very close)
	var check_positions = []
	
	# Check fewer positions for performance
	for x_offset in range(-check_radius, check_radius + 1, 12):
		for y_offset in range(-check_radius, check_radius + 1, 12):
			var check_pos = collision_point + Vector2(x_offset, y_offset)
			check_positions.append(check_pos)
	
	# Check each position for platform tiles
	for pos in check_positions:
		if _is_platform_tile_at_position(pos):
			print("[LEDGEGRAB_DEBUG] Found platform tile very close at ", pos, " near collision point ", collision_point)
			return true
	
	return false


func _is_player_near_platform_tiles_simple() -> bool:
	# Simple and fast check - only check a small area around player
	var player_pos = player.global_position
	var check_radius = 32  # Only check 32 pixels around player (much smaller)
	
	# Check only 4 positions around player (much faster)
	var check_positions = [
		player_pos + Vector2(-check_radius, 0),  # Left
		player_pos + Vector2(check_radius, 0),   # Right
		player_pos + Vector2(0, -check_radius),  # Up
		player_pos + Vector2(0, check_radius)    # Down
	]
	
	for pos in check_positions:
		if _is_platform_tile_at_position(pos):
			return true
	
	return false

func _is_player_very_close_to_platform_tiles() -> bool:
	# Very strict check - only disable if player is VERY close to platform tiles
	# This allows ledge grab even when somewhat near platforms
	var player_pos = player.global_position
	var check_radius = 16  # Only check 16 pixels around player (very close)
	
	# Check only 4 positions around player
	var check_positions = [
		player_pos + Vector2(-check_radius, 0),  # Left
		player_pos + Vector2(check_radius, 0),   # Right
		player_pos + Vector2(0, -check_radius),  # Up
		player_pos + Vector2(0, check_radius)    # Down
	]
	
	for pos in check_positions:
		if _is_platform_tile_at_position(pos):
			return true
	
	return false

func _is_flat_wall_at_player_height(side: int) -> bool:
	# Check for flat wall using horizontal raycast from player's collision height
	# This prevents grabbing flat walls (walls without a platform above)
	# İYİLEŞTİRME: Flat wall kontrolü artık sadece platform kontrolünden SONRA yapılmalı
	# Ama şimdilik burada kalıyor, sadece daha az agresif yapıyoruz
	
	var space_state = player.get_world_2d().direct_space_state
	
	# Get player's collision height (approximately 22 pixels from bottom)
	var player_collision_height = player.global_position.y - 22
	
	print("[LEDGEGRAB_DEBUG] Checking flat wall - side: ", side, " player_collision_height: ", player_collision_height)
	
	# İYİLEŞTİRME: Sadece player'ın tam yüksekliğinde kontrol et, geniş bir aralıkta değil
	# Bu, gerçek köşeleri daha az reddetmesini sağlar
	var wall_hits = 0
	var total_checks = 0
	
	# İYİLEŞTİRME: Flat wall kontrolü artık daha az agresif
	# Sadece player'ın tam yüksekliğinde ve birkaç piksel yukarıda kontrol et
	# Daha az kontrol noktası = daha az agresif
	for height_offset in range(0, 8, 3):  # Sadece 0, 3, 6 piksel yukarıda kontrol et (3 nokta)
		var check_height = player_collision_height + height_offset
		
		# Cast horizontal ray from player position towards the wall
		var from_pos = Vector2(player.global_position.x, check_height)
		var to_pos = Vector2(player.global_position.x + side * 20, check_height)  # 20 pixels towards wall (daha kısa)
		
		var q = PhysicsRayQueryParameters2D.new()
		q.from = from_pos
		q.to = to_pos
		q.exclude = [player]
		var res = space_state.intersect_ray(q)
		
		total_checks += 1
		if res:
			wall_hits += 1
			print("[LEDGEGRAB_DEBUG] Wall hit at height: ", check_height, " hit_pos: ", res.position, " height_offset: ", height_offset)
	
	# If wall is detected at most heights, it's likely a flat wall
	var wall_ratio = float(wall_hits) / float(total_checks) if total_checks > 0 else 0.0
	print("[LEDGEGRAB_DEBUG] Flat wall check - wall_hits: ", wall_hits, " total_checks: ", total_checks, " ratio: ", wall_ratio)
	
	# İYİLEŞTİRME: Threshold'u %100'e çıkar - sadece TÜM kontrollerde duvar varsa flat wall kabul et
	# Bu, gerçek köşeleri daha az reddetmesini sağlar
	# Ayrıca, platform kontrolünden SONRA çağrıldığı için bu kontrol daha az önemli
	if wall_ratio >= 1.0:  # Sadece TÜM kontrollerde duvar varsa flat wall
		print("[LEDGEGRAB_DEBUG] FLAT WALL DETECTED - ratio: ", wall_ratio, " (threshold: 1.0 - all checks must hit)")
		return true
	
	print("[LEDGEGRAB_DEBUG] No flat wall detected - ratio: ", wall_ratio)
	return false
