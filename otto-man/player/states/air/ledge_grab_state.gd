extends State

## Set to true while debugging: prints exactly why a grab attempt succeeds/fails
## to the Godot Output panel every time "block" is held while airborne.
const DEBUG_LEDGE := true

const LEDGE_GRAB_DURATION := 0.2
const CLIMB_FORCE := Vector2(0, -400)
## X: slightly farther from wall surface to reduce wedging; Y: hand height on ledge
const LEDGE_OFFSET := Vector2(-6, 36)
const GRAB_DISTANCE := 20.0
const MOUNT_OFFSET := Vector2(0, -5)  # Vertical offset to move player down (negative = down)
const MOUNT_FORWARD_OFFSET := 20  # How many pixels to move forward onto the platform
const LEDGE_GRAB_COOLDOWN := 0.3  # Cooldown duration after letting go (increased for post-jump detection)

## Match player body vs terrain (see CharacterBody2D collision_mask in player scene)
const LEDGE_PHYSICS_MASK := CollisionLayers.WORLD | CollisionLayers.PLATFORM
const LEDGE_REJECT_UPWARD_VELOCITY := -120.0

## --- Wall-top corner scan ---
## We probe individual points (not raycasts - see _find_wall_top) a few pixels
## INTO the wall's own footprint, scanning upward from the wall-hit height in
## small steps, until we find the first point that ISN'T solid. That's the top
## of the wall we're touching. If solid continues for the whole scan window,
## the wall is too tall/flat to climb from here and is correctly rejected.
const WALL_TOP_SCAN_STEP := 4.0        # px per probe step while climbing the wall's face
const WALL_TOP_SCAN_ABOVE := 140.0     # how far above the wall-hit point we search (~4 tiles)
const WALL_PROBE_INSET := 4.0          # px into the wall's own footprint, away from the open corridor
const SHELF_PROBE_FORWARD := 12.0      # px past the corner (climb direction) to confirm a floor
const SHELF_PROBE_DEPTH := 40.0        # how far below the found top we look for that floor

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


## Uses the player's current CollisionShape2D capsule (standing or already shrunk by crouch).
func _feet_body_overlaps_solid(feet_global: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var cs := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is CapsuleShape2D):
		return false
	var cap := cs.shape as CapsuleShape2D
	var test_capsule := CapsuleShape2D.new()
	test_capsule.radius = cap.radius
	test_capsule.height = cap.height
	var body_xform := Transform2D(player.global_rotation, feet_global)
	var shape_center_global: Vector2 = body_xform * cs.position
	var shape_xform := Transform2D(player.global_rotation, shape_center_global)
	var pq := PhysicsShapeQueryParameters2D.new()
	pq.shape = test_capsule
	pq.transform = shape_xform
	pq.collision_mask = LEDGE_PHYSICS_MASK
	pq.exclude = [player]
	var hits: Array = space.intersect_shape(pq, 8)
	return hits.size() > 0


## Before apply_crouch_shape_now(), test mount using the same capsule size Crouch would apply (standing dims from Crouch or current shape).
func _overlaps_crouch_sized_at(feet_global: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var cs := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is CapsuleShape2D):
		return false
	var cap := cs.shape as CapsuleShape2D
	var crouch_node = player.get_node_or_null("StateMachine/Crouch")
	var stand_h: float = cap.height
	var base_cy: float = cs.position.y
	if crouch_node and crouch_node.has_initialized:
		stand_h = crouch_node.original_height
		base_cy = crouch_node.original_position_y
	var ch: float = stand_h * 0.5
	var center_local_y: float = base_cy + (stand_h - ch) * 0.5
	var test_capsule := CapsuleShape2D.new()
	test_capsule.radius = cap.radius
	test_capsule.height = ch
	var body_xform := Transform2D(player.global_rotation, feet_global)
	var shape_center_global: Vector2 = body_xform * Vector2(cs.position.x, center_local_y)
	var shape_xform := Transform2D(player.global_rotation, shape_center_global)
	var pq := PhysicsShapeQueryParameters2D.new()
	pq.shape = test_capsule
	pq.transform = shape_xform
	pq.collision_mask = LEDGE_PHYSICS_MASK
	pq.exclude = [player]
	return space.intersect_shape(pq, 8).size() > 0


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.new()
	q.from = from
	q.to = to
	q.collision_mask = LEDGE_PHYSICS_MASK
	q.exclude = [player]
	return player.get_world_2d().direct_space_state.intersect_ray(q)


func _ready():
	# REMOVED node assignment from here
	pass

func physics_update(delta: float):
	if grab_timer > 0:
		grab_timer -= delta
	
	# Handle instant mounting with up button
	if Input.is_action_just_pressed("up") and can_climb:
		var saved_pos: Vector2 = player.global_position
		
		# Compute initial mount position
		var base_mount = ledge_position + MOUNT_OFFSET
		base_mount.x += facing_direction * MOUNT_FORWARD_OFFSET
		
		# Check if there's a wall ahead at the mount position - if so, don't allow climbing
		if _has_wall_ahead_at_mount_position(base_mount, facing_direction):
			return
		
		# Refine to a safe mount (back off a bit if tight tunnel) + overlap validation
		var mount_pos: Vector2 = _find_safe_mount_position(base_mount, facing_direction)
		if mount_pos == Vector2.ZERO:
			return
		
		# Ensure small collider BEFORE teleporting (avoid wedging)
		var crouch_state_pre = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state_pre and crouch_state_pre.has_method("apply_crouch_shape_now"):
			crouch_state_pre.apply_crouch_shape_now()
		
		# Pre-teleport overlap (uses current = crouch capsule on node)
		if _feet_body_overlaps_solid(mount_pos):
			if crouch_state_pre and crouch_state_pre.has_method("restore_standing_shape_now"):
				crouch_state_pre.restore_standing_shape_now()
			return
		
		player.global_position = mount_pos
		player.velocity = Vector2.ZERO
		
		# Snap to ground and register floor contact
		var snap_result: Dictionary = _ray(player.global_position, player.global_position + Vector2.DOWN * 64)
		if snap_result.has("position"):
			player.global_position.y = snap_result.position.y - 1
			player.velocity.y = 5
			player.apply_move_and_slide()
		
		# Post-move: still embedded in solid -> abort climb (stay on ledge)
		if _feet_body_overlaps_solid(player.global_position):
			player.global_position = saved_pos
			player.velocity = Vector2.ZERO
			if crouch_state_pre and crouch_state_pre.has_method("restore_standing_shape_now"):
				crouch_state_pre.restore_standing_shape_now()
			return
		
		# Force crouch on mount (longer if headroom tight)
		var extra_crouch := 0.1  # shortened minimum crouch after ledgegrab
		var crouch_state = player.get_node_or_null("StateMachine/Crouch")
		if crouch_state and crouch_state.has_method("force_crouch"):
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
	# Nudge away from wall if overlapping solid (forest chunk seams / thick tiles)
	for _nudge_i in range(6):
		if not _feet_body_overlaps_solid(player.global_position):
			break
		player.global_position.x += -facing_direction * 2.0
	player.velocity = Vector2.ZERO
	grab_timer = LEDGE_GRAB_DURATION
	can_climb = true
	
	# Face the correct direction - when grabbing left wall, face right and vice versa
	# When grabbing a ledge, we want to face towards the wall
	player.sprite.flip_h = facing_direction < 0  # Face towards the wall

func _get_ledge_position() -> Dictionary:
	if not player:
		push_error("LedgeGrab _get_ledge_position: Player reference is null!")
		return {"position": Vector2.ZERO, "direction": 0}

	var wl = player.get_node("WallRayLeft") as RayCast2D
	var wr = player.get_node("WallRayRight") as RayCast2D

	if not (wl and wr):
		push_error("LedgeGrab _get_ledge_position: Failed to find WallRayLeft/WallRayRight on Player!")
		return {"position": Vector2.ZERO, "direction": 0}

	# Allow grab as long as the player is airborne
	if player.is_on_floor():
		return {"position": Vector2.ZERO, "direction": 0}

	# In a corridor exactly as wide as the wall-ray reach, BOTH sides can register a
	# wall at the same time. Check whichever side matches the player's held direction
	# (or last facing direction if no horizontal input) first, so a narrow shaft that
	# opens on one side doesn't always resolve to the other, unrelated wall.
	var input_dir: float = InputManager.get_flattened_axis(&"left", &"right")
	var preferred_side := 1 if player.facing_direction >= 0 else -1
	if input_dir > 0.1:
		preferred_side = 1
	elif input_dir < -0.1:
		preferred_side = -1

	var primary_ray: RayCast2D = wr if preferred_side > 0 else wl
	var primary := _scan_ledge_side(primary_ray, preferred_side)
	if primary.direction != 0:
		return primary

	var other_side := -preferred_side
	var secondary_ray: RayCast2D = wr if other_side > 0 else wl
	return _scan_ledge_side(secondary_ray, other_side)


## Checks one wall ray for a real, mountable corner (side = -1 left wall / +1 right wall).
func _scan_ledge_side(wall_ray: RayCast2D, side: int) -> Dictionary:
	var empty := {"position": Vector2.ZERO, "direction": 0}
	if not wall_ray.is_colliding():
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: wall ray not colliding" % side)
		return empty

	var collision_point: Vector2 = wall_ray.get_collision_point()
	if DEBUG_LEDGE:
		print("[LEDGEGRAB_DEBUG] side=%d collision_point=%s player=%s" % [side, collision_point, player.global_position])

	var top_scan := _find_wall_top(collision_point, side)
	if not top_scan.found:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: wall top not found within scan range -> flat/tall wall, reject" % side)
		return empty

	var top_y: float = top_scan.top_y
	if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: wall top found at y=%.1f (gap=%.1f)" % [side, top_y, collision_point.y - top_y])

	if not _has_standable_shelf(collision_point, side, top_y):
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: no standable shelf at corner -> reject" % side)
		return empty

	# Align vertically to the 32px tile grid, with per-column hysteresis to avoid flicker
	# when the raw scan lands right on a tile boundary from frame to frame.
	var ledge_y_aligned: float = floor(top_y / 32.0) * 32.0
	var key_x: int = int(round(collision_point.x / 32.0) * 32)
	if ledge_y_cache.has(key_x):
		var prev_y = ledge_y_cache[key_x]
		if abs(ledge_y_aligned - prev_y) <= 3:
			ledge_y_aligned = prev_y
	ledge_y_cache[key_x] = ledge_y_aligned

	var ledge_x: float = collision_point.x - side * 4.0
	var candidate := {"position": Vector2(ledge_x, ledge_y_aligned), "direction": side}

	# NOTE: we deliberately do NOT hard-reject here based on an overlap check at the
	# hang position. The player is, by definition, pressed against the wall right now
	# (that's how the wall ray detected it), so a fresh shape query near that position
	# will often report a tiny overlap purely from the same collision skin/margin the
	# physics engine already tolerates during normal movement. enter() below already
	# nudges the player away from solid geometry after snapping to this position, which
	# is the right place to correct for that - rejecting the grab outright here caused
	# essentially every real grab attempt to fail.
	if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: VALID LEDGE at %s" % [side, candidate.position])
	return candidate


## Finds the top of the wall the player is touching by testing individual points
## for solidity, scanning upward from the wall-hit height. Point queries (as opposed
## to short raycasts) are immune to two classes of bugs that plagued earlier versions
## of this scan:
##  - A ray that STARTS inside a solid shape never reports a hit for that shape.
##  - A ray crossing the (invisible) seam between two adjacent-but-separate physics
##    shapes (e.g. neighboring merged TileMap collision rectangles) can register a
##    false "hit" at that seam even though the wall is 100% continuously solid there.
## A point-in-shape test has neither problem: it simply asks "is any collider here?".
func _find_wall_top(collision_point: Vector2, side: int) -> Dictionary:
	var probe_x: float = collision_point.x + side * WALL_PROBE_INSET
	if not _is_solid_point(Vector2(probe_x, collision_point.y)):
		return {"found": false, "top_y": 0.0}

	var steps: int = int(WALL_TOP_SCAN_ABOVE / WALL_TOP_SCAN_STEP)
	var last_solid_y: float = collision_point.y
	for i in range(1, steps):
		var y: float = collision_point.y - float(i) * WALL_TOP_SCAN_STEP
		if _is_solid_point(Vector2(probe_x, y)):
			last_solid_y = y
		else:
			return {"found": true, "top_y": last_solid_y}
	return {"found": false, "top_y": 0.0}


## Point-in-shape solid test (see _find_wall_top comment for why this is used
## instead of short raycasts).
func _is_solid_point(pos: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = LEDGE_PHYSICS_MASK
	q.exclude = [player]
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return space_state.intersect_point(q, 1).size() > 0


## Confirms there's an actual floor to stand on just past the corner (not just an
## open corridor with nothing to land on, and not a one-way platform edge).
func _has_standable_shelf(collision_point: Vector2, side: int, top_y: float) -> bool:
	var probe_x: float = collision_point.x + side * SHELF_PROBE_FORWARD
	var from_pt := Vector2(probe_x, top_y - 4.0)
	var to_pt := Vector2(probe_x, top_y + SHELF_PROBE_DEPTH)
	var hit := _ray(from_pt, to_pt)
	if DEBUG_LEDGE:
		print("[LEDGEGRAB_DEBUG] side=%d shelf ray probe_x=%.1f from_y=%.1f to_y=%.1f hit=%s" % [side, probe_x, from_pt.y, to_pt.y, hit])
	if not hit.has("position"):
		return false
	if _is_one_way_platform(hit.collider):
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] side=%d: shelf is a one-way platform, rejecting" % side)
		return false
	return true

func can_ledge_grab() -> bool:
	# Node checks are now handled inside _get_ledge_position

	# Ledge grab sadece korunma tuşuna basıldığında çalışır
	if not Input.is_action_pressed("block"):
		return false

	# Check cooldown first
	if player.ledge_grab_cooldown_timer > 0:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] can_ledge_grab: rejected, cooldown=%.2f" % player.ledge_grab_cooldown_timer)
		return false

	# Strong upward motion: don't snap to ledge (reduces bad grabs near apex)
	if player.velocity.y < LEDGE_REJECT_UPWARD_VELOCITY:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] can_ledge_grab: rejected, velocity.y=%.1f < %.1f" % [player.velocity.y, LEDGE_REJECT_UPWARD_VELOCITY])
		return false

	var ledge = _get_ledge_position()
	var can_grab = ledge.direction != 0 and ledge.position != Vector2.ZERO
	if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] can_ledge_grab: result=%s ledge=%s" % [can_grab, ledge])

	return can_grab

func _has_wall_ahead(at_pos: Vector2, facing_dir: int) -> bool:
	var space_state = player.get_world_2d().direct_space_state
	var head_y = at_pos.y - 22  # approx half-height for standing bottom-origin
	var from_pt = Vector2(at_pos.x + facing_dir * 4, head_y)
	var to_pt = Vector2(at_pos.x + facing_dir * 12, head_y)
	var q = PhysicsRayQueryParameters2D.new()
	q.from = from_pt
	q.to = to_pt
	q.collision_mask = LEDGE_PHYSICS_MASK
	q.exclude = [player]
	var res = space_state.intersect_ray(q)
	return res.has("position")

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
		q.collision_mask = LEDGE_PHYSICS_MASK
		q.exclude = [player]
		var res = space_state.intersect_ray(q)
		if res.has("position"):
			return true  # Wall detected at any check point
	
	return false  # No wall detected

func _ground_snap(at_pos: Vector2) -> Vector2:
	var q = PhysicsRayQueryParameters2D.new()
	q.from = at_pos
	q.to = at_pos + Vector2.DOWN * 64
	q.collision_mask = LEDGE_PHYSICS_MASK
	q.exclude = [player]
	var res = player.get_world_2d().direct_space_state.intersect_ray(q)
	if res.has("position"):
		return Vector2(at_pos.x, res.position.y - 1)
	return at_pos

func _find_safe_mount_position(base_mount: Vector2, facing_dir: int) -> Vector2:
	# Try a few forward back-offs and small vertical pulls to avoid tight tunnel walls
	var forward_candidates = [MOUNT_FORWARD_OFFSET, 16, 12, 8, 4, 0, -4]
	var vertical_deltas = [0, -4, -8, -12, 4, 8]
	
	for f in forward_candidates:
		for dy in vertical_deltas:
			var candidate = Vector2(ledge_position.x + facing_dir * f, base_mount.y + dy)
			var snapped_candidate = _ground_snap(candidate)
			if _has_wall_ahead(snapped_candidate, facing_dir):
				continue
			if _has_wall_ahead_at_mount_position(snapped_candidate, facing_dir):
				continue
			if _overlaps_crouch_sized_at(snapped_candidate):
				continue
			return snapped_candidate
	
	var fallback: Vector2 = _ground_snap(base_mount)
	if not _has_wall_ahead(fallback, facing_dir) and not _has_wall_ahead_at_mount_position(fallback, facing_dir) and not _overlaps_crouch_sized_at(fallback):
		return fallback
	return Vector2.ZERO

func _is_one_way_platform(collider: Node2D) -> bool:
	# Check if the collider is a one-way platform
	if not collider:
		return false
	
	if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Checking collider: ", collider.name, " class: ", collider.get_class())
	
	# Method 1: Check if it's a OneWayPlatform class
	if collider.get_class() == "OneWayPlatform":
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found OneWayPlatform class")
		return true
	
	# Method 2: Check if it's in the one-way platform group
	if collider.is_in_group("one_way_platforms"):
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found one_way_platforms group")
		return true
	
	# Method 3: Check if it's a TileMap with one-way collision
	if collider is TileMap:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found TileMap, checking for one-way collision")
		# Check if this TileMap has one-way collision enabled
		# We'll check the collision at the specific position
		var space_state = player.get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = player.global_position
		query.collision_mask = LEDGE_PHYSICS_MASK
		query.exclude = [player]
		
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider == collider:
				# Check if this collision has one-way properties
				if result.has("one_way_collision") and result.one_way_collision:
					if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found one-way collision in TileMap")
					return true
				break
	
	# Method 4: Check collision shape for one-way collision
	var collision_shape = collider.get_node_or_null("CollisionShape2D")
	if collision_shape:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found CollisionShape2D, checking one-way collision")
		if collision_shape.one_way_collision:
			if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found one-way collision in CollisionShape2D")
			return true
	
	# Method 5: Check if it's a platform with one-way collision margin
	if collision_shape and collision_shape.one_way_collision_margin > 0:
		if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] Found one-way collision margin: ", collision_shape.one_way_collision_margin)
		return true
	
	if DEBUG_LEDGE: print("[LEDGEGRAB_DEBUG] No one-way platform detected")
	return false
