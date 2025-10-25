class_name HunterEnemy
extends "res://enemy/base_enemy.gd"

const PatrolPointScript = preload("res://enemy/hunter/patrol_point.gd")

# Default stats resource
@export var default_stats: EnemyStats = preload("res://enemy/hunter/hunter_enemy_stats.tres")

# Node references
@onready var terrain_detection = $TerrainDetection
@onready var ground_ray = $TerrainDetection/GroundRayCast
@onready var ledge_ray_left = $TerrainDetection/LedgeRayCastLeft
@onready var ledge_ray_right = $TerrainDetection/LedgeRayCastRight
@onready var wall_ray_left = $TerrainDetection/WallRayCastLeft
@onready var wall_ray_right = $TerrainDetection/WallRayCastRight
@onready var platform_ray = $TerrainDetection/PlatformRayCast
@onready var jump_height_ray = $TerrainDetection/JumpHeightRayCast
@onready var debug_node = $Debug

# Movement parameters
const GRAVITY_MULTIPLIER = 2.5
const JUMP_VELOCITY = -700.0  # Increased jump force further
const MAX_FALL_SPEED = 600.0  # Increased to match more aggressive movement
const CHASE_SPEED = 300.0  # Significantly increased chase speed
const APPROACH_SPEED = 150.0  # Increased approach speed
const JUMP_COOLDOWN = 0.3  # Reduced cooldown for more frequent jumps
const MAX_DROP_HEIGHT = 400.0  # Increased drop height for more aggressive pursuit

# Improved stuck detection and handling
const STUCK_CHECK_RADIUS = 20.0  # Increased check radius
const STUCK_MIN_ATTEMPT_INTERVAL = 1.0  # Reduced interval
const UNSTUCK_JUMP_VELOCITY = -650.0  # Increased unstuck jump force
const UNSTUCK_MOVE_DURATION = 0.5  # Reduced duration for quicker recovery
const UNSTUCK_SPEED = 350.0  # Significantly increased unstuck speed
const VERTICAL_STUCK_THRESHOLD = 200.0  # Increased threshold
const MAX_VERTICAL_ATTEMPTS = 4  # Increased attempts
const MAX_CONSECUTIVE_STUCK_ATTEMPTS = 3  # Increased max attempts
const STUCK_MOMENTUM_PRESERVATION = 0.7  # Increased momentum preservation

# Platform navigation
const PLATFORM_CHECK_HEIGHT = 250.0  # Increased height check
const EDGE_DETECTION_DISTANCE = 50.0  # Increased edge detection
const PLATFORM_APPROACH_DISTANCE = 80.0  # Increased approach distance
const MIN_PLATFORM_WIDTH = 60.0  # Reduced minimum platform width requirement

# State tracking
var jump_cooldown_timer = 0.0
var is_jumping = false
var wants_to_jump = false
var target_platform_height = 0.0
var last_safe_position = Vector2.ZERO
var last_unstuck_position := Vector2.ZERO
var unstuck_attempt_successful := false
var last_target_position = Vector2.ZERO
var stuck_timer := 0.0
var last_behavior_change := 0.0
var last_successful_path_time := 0.0

# Add new constants for improved edge detection and movement
const EDGE_APPROACH_SPEED = 100.0  # Slower speed when approaching edges
const EDGE_STOP_DISTANCE = 20.0  # Distance from edge to stop and prepare jump
const MIN_MOVEMENT_SPEED = 50.0  # Minimum speed to consider as moving

# Combat parameters
var attack_cooldown = 1.0
var attack_cooldown_timer: float = 0.0
var current_combo = 0
var max_combo = 3

# State tracking
var jump_count = 0
var max_jumps = 2
var target_position = Vector2.ZERO
var path_points = []
var current_path_index = 0
var patrol_start_position = Vector2.ZERO
var moving_right = true
var platform_drop_timer = 0.0
var wants_to_drop = false
var patrol_points: Array[PatrolPoint] = []
var current_patrol_target: PatrolPoint = null
var patrol_scan_timer: float = 0.0
var last_unstuck_attempt_time := 0.0
var consecutive_stuck_attempts := 0
var last_stuck_position := Vector2.ZERO

const MIN_GAP_WIDTH_FOR_JUMP := 32.0
const MAX_JUMPABLE_GAP := 400.0  # Reduced from 600 to be more realistic
const JUMP_PREPARATION_DISTANCE := 40.0
const MAX_JUMP_DISTANCE := 400.0  # Match with MAX_JUMPABLE_GAP
const MAX_JUMP_HEIGHT := 150.0  # Reduced from 200 to be more realistic
const MIN_LEDGE_HEIGHT := 32.0
const VERTICAL_SCAN_INTERVAL := 48.0  # Reduced for more precise scanning
const JUMP_SKIP_CHANCE := 0.0  # Removed random skip chance

var last_jump_position := Vector2.ZERO

# Patrol system parameters
const PATROL_SCAN_INTERVAL := 24  # Reduced from 32 for more precise scanning
const PATROL_RANGE := 800.0  # Increased from 500.0
const PATROL_SCAN_TIME := 3.0  # Reduced from 5.0 for more frequent updates
const PATROL_POINT_MIN_DISTANCE := 16.0  # Minimum distance between patrol points
const PATROL_POINT_MAX_DISTANCE := 600.0  # Maximum distance between connected points
var current_path: Array[PatrolPoint] = []
var path_index: int = 0

# Add this near the top of the file with other constants
const DEBUG_ENABLED = true  # Set to true to show patrol points and paths

# Debug settings
var debug_throttle_timer: float = 0.0
const DEBUG_THROTTLE_INTERVAL = 0.5  # Only print debug every 0.5 seconds
var last_logged_position := Vector2.ZERO
const MIN_POSITION_CHANGE = 20.0  # Only log position changes greater than this

const PATH_UPDATE_THRESHOLD = 100.0  # Only update path if target moves more than this distance
const STUCK_TIME_THRESHOLD = 1.0  # Time before considering hunter stuck
const STUCK_VELOCITY_THRESHOLD = 10.0  # Velocity threshold for stuck detection
const STUCK_POSITION_THRESHOLD = 5.0  # Position change threshold for stuck detection

var path_update_timer := 0.0
var no_path_timer := 0.0
var last_path_attempt_position := Vector2.ZERO

# Add new constants for boundary and unstuck behavior
const MAX_X_POSITION = 3000.0  # Maximum x position allowed
const MIN_X_POSITION = 0.0     # Minimum x position allowed

var unstuck_move_timer := 0.0  # Timer for unstuck movement duration
var unstuck_direction := 1.0   # Direction to move when unstuck (-1 or 1)

# Add patrol and path management constants
const PATROL_POINT_LIMIT = 30  # Maximum number of patrol points to generate
const MAX_CONNECTIONS_PER_POINT = 4  # Maximum connections per patrol point
const PATH_UPDATE_COOLDOWN = 1.0  # Time between path updates
const NO_PATH_COOLDOWN = 2.0  # Time to wait after failing to find a path

var consecutive_wall_jumps = 0

# Constants for improved chase behavior
const POSITION_LOG_THRESHOLD = 50.0  # Only log position changes above this threshold
const MIN_CHASE_DISTANCE = 100.0  # Minimum distance to maintain from target
const MAX_CHASE_DISTANCE = 800.0  # Maximum distance before disengaging

# State tracking
var last_logged_distance = 0.0
var last_path_update_distance = 0.0

func _ready() -> void:
	# Set sleep distances for performance optimization
	sleep_distance = 1500.0  # Distance at which enemy goes to sleep
	wake_distance = 1200.0  # Distance at which enemy wakes up
	# Initialize stats first
	if not stats:
		print("[Hunter] Loading default stats...")
		stats = default_stats
		if stats:
			print("[Hunter] Stats loaded - Speed:", stats.movement_speed, " Chase Speed:", stats.chase_speed)
		else:
			push_error("[Hunter] Failed to load default stats!")
	
	# Call parent _ready
	super._ready()
	
	# Set up collision masks for terrain detection
	for ray in $TerrainDetection.get_children():
		if ray is RayCast2D:
			ray.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
			ray.enabled = true
	
	# Set up collision layers correctly
	set_collision_layer_value(3, true)   # Enemy layer (layer 3)
	set_collision_mask_value(1, true)    # Terrain layer (layer 1)
	set_collision_mask_value(2, true)    # Player layer (layer 2)
	set_collision_mask_value(10, true)   # Platform layer (layer 10)
	
	# Store initial position for patrol
	patrol_start_position = global_position
	
	# Initialize patrol points after physics settles
	await get_tree().create_timer(0.1).timeout
	generate_patrol_points()
	
	last_target_position = global_position
	
	# Start with idle behavior and animation
	change_behavior("idle")
	if sprite:
		sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Update jump cooldown
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * GRAVITY_MULTIPLIER * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
		
		# Update animations based on vertical movement
		if sprite and not is_jumping:  # Only change if not in jump state
			if velocity.y > 10:  # Moving downward
				sprite.play("fall")
	else:
		is_jumping = false  # Reset jumping state when landing
	
	move_and_slide()
	
	handle_behavior(delta)

func handle_idle(delta):
	# Use stats for movement speed
	velocity.x = move_toward(velocity.x, 0, stats.movement_speed * delta)
	
	if sprite and sprite.animation != "idle":
		sprite.play("idle")
	
	# Check for player to chase using stats detection range
	target = get_nearest_player()
	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance <= stats.detection_range:
			print("[Hunter] Found target in range (", distance, " <= ", stats.detection_range, "), transitioning to chase")
			change_behavior("chase")
			return
		else:
			target = null
	
	# Only transition to patrol if we're truly idle (no target and almost stopped)
	if abs(velocity.x) < 10:
		change_behavior("patrol")

# Add debug function to check player detection
func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	
	if players == null or players.size() == 0:
		return null
		
	var nearest_player = players[0]
	var nearest_distance = global_position.distance_to(nearest_player.global_position)
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_player = player
			nearest_distance = distance
	
	return nearest_player

func handle_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
		
	# Update path and handle movement
	update_chase_path()
	
	# Handle terrain and movement
	handle_terrain()
	apply_gravity(delta)
	move_and_slide()
	update_sprite_direction()

func start_jump() -> void:
	if not is_on_floor():
		return
		
	jump_cooldown_timer = JUMP_COOLDOWN
	velocity.y = JUMP_VELOCITY
	
	# Calculate required horizontal velocity
	if target and is_instance_valid(target):
		var distance_to_target = target.global_position.x - global_position.x
		var time_to_peak = -JUMP_VELOCITY / (GRAVITY * GRAVITY_MULTIPLIER)
		var required_velocity = distance_to_target / (time_to_peak * 2)
		
		# Clamp horizontal velocity within reasonable bounds
		required_velocity = clamp(required_velocity, -CHASE_SPEED * 1.5, CHASE_SPEED * 1.5)
		velocity.x = required_velocity
	
	sprite.play("jump")
	is_jumping = true

func get_terrain_info() -> Dictionary:
	var info = {
		"gap_ahead": false,
		"wall_ahead": false,
		"wall_right": wall_ray_right.is_colliding(),
		"wall_left": wall_ray_left.is_colliding(),
		"gap_width": 0.0,
		"platform_above": false,
		"platform_height": 0.0,
		"can_jump": false,
		"can_jump_to_platform": false
	}
	
	var facing_right = not sprite.flip_h
	
	# Check for gaps based on facing direction
	if facing_right:
		info.gap_ahead = not ledge_ray_right.is_colliding() and ground_ray.is_colliding()
		info.wall_ahead = wall_ray_right.is_colliding()
		if info.gap_ahead:
			info.gap_width = estimate_gap_width(ledge_ray_right.global_position, 1)
	else:
		info.gap_ahead = not ledge_ray_left.is_colliding() and ground_ray.is_colliding()
		info.wall_ahead = wall_ray_left.is_colliding()
		if info.gap_ahead:
			info.gap_width = estimate_gap_width(ledge_ray_left.global_position, -1)
	
	info.can_jump = info.gap_width > 0 and info.gap_width < MAX_JUMPABLE_GAP and jump_cooldown_timer <= 0
	
	return info

func terrain_info() -> Dictionary:
	var info = {
		"gap_left": false,
		"gap_right": false,
		"gap_width": 0.0,
		"wall_left": false,
		"wall_right": false
	}
	
	# Get node references
	var ground_ray = $TerrainDetection/GroundRayCast
	var left_ray = $TerrainDetection/LedgeRayCastLeft
	var right_ray = $TerrainDetection/LedgeRayCastRight
	var wall_left = $TerrainDetection/WallRayCastLeft
	var wall_right = $TerrainDetection/WallRayCastRight
	
	# Check walls first
	info.wall_left = wall_left.is_colliding()
	info.wall_right = wall_right.is_colliding()
	
	# Only check for gaps if we're on the ground
	if is_on_floor():
		# Check left gap
		if !left_ray.is_colliding() and ground_ray.is_colliding():
			info.gap_left = true
			
		# Check right gap
		if !right_ray.is_colliding() and ground_ray.is_colliding():
			info.gap_right = true
		
		# Calculate gap width if there is a gap
		if info.gap_left or info.gap_right:
			var space_state = get_world_2d().direct_space_state
			var start_pos = global_position
			var direction = Vector2.RIGHT if info.gap_right else Vector2.LEFT
			var query = PhysicsRayQueryParameters2D.create(start_pos, start_pos + direction * MAX_JUMPABLE_GAP)
			query.collision_mask = CollisionLayers.WORLD  # Environment layer
			var result = space_state.intersect_ray(query)
			
			if result:
				info.gap_width = abs(global_position.x - result.position.x)
				if debug_enabled:
					print("[Hunter] Found gap - Width:", info.gap_width, ", Direction:", "right" if info.gap_right else "left")
			else:
				info.gap_width = MAX_JUMPABLE_GAP
				if debug_enabled:
					print("[Hunter] Gap exceeds max jumpable distance")
	
	return info

func estimate_gap_width(start_position: Vector2, direction: int) -> float:
	var space_state = get_world_2d().direct_space_state
	var max_distance = MAX_JUMP_DISTANCE
	var step = 10.0  # Smaller step size for more accurate detection
	
	# Start checking from the edge of the platform
	var edge_offset = 20.0
	var check_pos = start_position
	check_pos.x += edge_offset * direction
	
	for distance in range(0, int(max_distance), int(step)):
		var ray_start = check_pos + Vector2(distance * direction, 100.0)  # Check further down
		var ray_end = ray_start + Vector2(0, -50.0)  # Check upward
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = CollisionLayers.WORLD  # Environment layer
		var result = space_state.intersect_ray(query)
		
		if result:
			return distance - edge_offset  # Subtract the edge offset to get actual gap width
	
	return max_distance

func handle_attack(delta):
	if not target or not is_instance_valid(target):
		change_behavior("chase")
		return
	
	var distance = global_position.distance_to(target.global_position)
	if distance > stats.attack_range:
		change_behavior("chase")
		return
	
	# Start attack cooldown
	attack_cooldown_timer = attack_cooldown

func handle_death(delta):
	# Death behavior
	sprite.play("idle")  # Temporary until we have death animation
	pass

func _draw() -> void:
	if not debug_enabled:
		return
		
	# Draw patrol points
	for point in patrol_points:
		# Draw point
		var color = Color.GREEN
		if point.point_type == PatrolPoint.PointType.PLATFORM:
			color = Color.BLUE
		elif point.point_type == PatrolPoint.PointType.LEDGE:
			color = Color.YELLOW
		elif point.point_type == PatrolPoint.PointType.DROP_POINT:
			color = Color.RED
			
		draw_circle(to_local(point.position), 5, color)
		
		# Draw connections with arrows
		for connection in point.connections:
			var line_color = Color.WHITE
			match point.movement_type:
				PatrolPoint.MovementType.WALK:
					line_color = Color.GREEN
				PatrolPoint.MovementType.JUMP_UP:
					line_color = Color.YELLOW
				PatrolPoint.MovementType.JUMP_ACROSS:
					line_color = Color.RED
				PatrolPoint.MovementType.DROP_DOWN:
					line_color = Color.BLUE
			
			var start = to_local(point.position)
			var end = to_local(connection.position)
			draw_line(start, end, line_color, 2.0)
			
			# Draw arrow head
			var direction = (end - start).normalized()
			var arrow_size = 10
			var arrow_angle = PI / 6  # 30 degrees
			var arrow_point1 = end - direction.rotated(arrow_angle) * arrow_size
			var arrow_point2 = end - direction.rotated(-arrow_angle) * arrow_size
			draw_line(end, arrow_point1, line_color, 2.0)
			draw_line(end, arrow_point2, line_color, 2.0)
	
	# Draw current path
	if not current_path.is_empty():
		for i in range(current_path.size() - 1):
			var start = to_local(current_path[i].position)
			var end = to_local(current_path[i + 1].position)
			draw_line(start, end, Color.MAGENTA, 3.0)
		
		# Draw current target point with a larger circle
		if current_patrol_target:
			draw_circle(to_local(current_patrol_target.position), 8.0, Color.MAGENTA)
			
	# Draw terrain detection rays
	if debug_enabled:
		var ray_length = 50
		for ray in terrain_detection.get_children():
			if ray is RayCast2D:
				var start = to_local(ray.global_position)
				var end = start + ray.target_position.rotated(ray.global_rotation)
				var color = Color.RED if ray.is_colliding() else Color.YELLOW
				draw_line(start, end, color, 1.0)

func generate_patrol_points() -> void:
	print("[Hunter] Generating patrol points...")
	patrol_points.clear()
	
	# Get current position as starting point
	var start_pos = global_position
	var ground_points = []
	var platform_points = []
	
	# Scan for ground points
	var scan_width = 800
	var scan_height = 400
	var scan_interval = 32  # Reduced from 40 for more precise scanning
	
	var space_state = get_world_2d().direct_space_state
	
	# Scan for ground points with debug info
	print("[Hunter] Starting ground scan - Width:", scan_width, " Height:", scan_height)
	
	for x in range(-scan_width, scan_width + 1, scan_interval):
		if ground_points.size() >= PATROL_POINT_LIMIT / 2:
			break
			
		var query_pos = start_pos + Vector2(x, -50)  # Start a bit above
		var query = PhysicsRayQueryParameters2D.create(query_pos, query_pos + Vector2.DOWN * scan_height)
		query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
		var result = space_state.intersect_ray(query)
		
		if result:
			var point = PatrolPoint.new(result.position, PatrolPoint.PointType.GROUND)
			ground_points.append(point)
			patrol_points.append(point)
	
	print("[Hunter] Ground scan complete - Found", ground_points.size(), "points")
	
	# Scan for platforms above ground points
	print("[Hunter] Starting platform scan...")
	var platform_count = 0
	
	for ground_point in ground_points:
		if platform_points.size() >= PATROL_POINT_LIMIT / 2:
			break
			
		# Scan upward from each ground point
		var max_height = 300  # Maximum height to scan for platforms
		var step = 48  # Reduced from 60 for more precise scanning
		
		for height in range(step, max_height, step):
			var scan_pos = ground_point.position + Vector2.UP * height
			var query = PhysicsRayQueryParameters2D.create(scan_pos + Vector2.UP * 20, scan_pos + Vector2.DOWN * 40)
			query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
			var result = space_state.intersect_ray(query)
			
			if result:
				var point = PatrolPoint.new(result.position, PatrolPoint.PointType.PLATFORM)
				platform_points.append(point)
				patrol_points.append(point)
				platform_count += 1
				
				# Also scan horizontally from this platform
				for side_offset in [-80, -40, 40, 80]:  # Added more scan points
					if platform_points.size() >= PATROL_POINT_LIMIT / 2:
						break
						
					var side_pos = result.position + Vector2(side_offset, 0)
					var side_query = PhysicsRayQueryParameters2D.create(side_pos + Vector2.UP * 20, side_pos + Vector2.DOWN * 40)
					side_query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
					var side_result = space_state.intersect_ray(side_query)
					
					if side_result:
						var side_point = PatrolPoint.new(side_result.position, PatrolPoint.PointType.PLATFORM)
						platform_points.append(side_point)
						patrol_points.append(side_point)
						platform_count += 1
	
	print("[Hunter] Platform scan complete - Found", platform_count, "points")
	if platform_count == 0:
		print("[Hunter] WARNING: No platform points found - vertical navigation will be limited")
	print("[Hunter] Total patrol points:", patrol_points.size())
	
	# Connect patrol points with limits
	var connection_count = 0
	for i in patrol_points.size():
		var point_a = patrol_points[i]
		var connection_count_for_point = 0
		
		for j in range(i + 1, patrol_points.size()):
			if connection_count_for_point >= MAX_CONNECTIONS_PER_POINT:
				break
				
			var point_b = patrol_points[j]
			var distance = point_a.position.distance_to(point_b.position)
			var height_diff = point_b.position.y - point_a.position.y
			
			# More lenient connection rules
			if distance <= MAX_JUMP_DISTANCE * 1.2 and abs(height_diff) <= MAX_JUMP_HEIGHT:
				var movement_type = PatrolPoint.MovementType.WALK
				if height_diff < -20:
					movement_type = PatrolPoint.MovementType.JUMP_UP
				elif height_diff > 20:
					movement_type = PatrolPoint.MovementType.DROP_DOWN
				elif distance > MIN_GAP_WIDTH_FOR_JUMP:
					movement_type = PatrolPoint.MovementType.JUMP_ACROSS
				
				point_a.movement_type = movement_type
				point_a.add_connection(point_b)
				connection_count += 1
				connection_count_for_point += 1
	
	print("[Hunter] Connected patrol points - Total connections:", connection_count)

func update_path_to_target() -> bool:
	# Don't update path if on cooldown
	if path_update_timer > 0 or no_path_timer > 0:
		return false
		
	# Don't update if target hasn't moved significantly
	if target and last_path_attempt_position.distance_to(target.global_position) < PATH_UPDATE_THRESHOLD:
		return false
		
	path_update_timer = PATH_UPDATE_COOLDOWN
	last_path_attempt_position = target.global_position if target else Vector2.ZERO
	
	if not target:
		return false
		
	# Find closest patrol points to start and end
	var start_point = find_closest_patrol_point(global_position)
	var end_point = find_closest_patrol_point(target.global_position)
	
	if not start_point or not end_point:
		no_path_timer = NO_PATH_COOLDOWN
		return false
	
	# Find path between points
	var path = find_path(start_point, end_point)
	
	if path.is_empty():
		no_path_timer = NO_PATH_COOLDOWN
		return false
	
	# Update current path
	current_path = path
	return true

func find_path_to_target() -> Array[PatrolPoint]:
	if not target or not is_instance_valid(target):
		return []
		
	# Get closest patrol points to start and target positions
	var start_point = get_closest_patrol_point(global_position)
	var end_point = get_closest_patrol_point(target.global_position)
	
	if not start_point or not end_point:
		print("[Hunter] Could not find valid start/end points for path")
		return []
		
	print("[Hunter] Found path points - Start dist:", start_point.position.distance_to(global_position), " End dist:", end_point.position.distance_to(target_position))
	
	var path = find_path(start_point, target_position)
	if not path or path.is_empty():
		print("[Hunter] No path found to target")
		return []
		
	print("[Hunter] Found path with", path.size(), "points")
	return path

func handle_stuck_state() -> void:
	if target and is_instance_valid(target):
		var height_diff = target.global_position.y - position.y
		
		# Check for platforms above or below
		var platform_above = check_for_platform(Vector2.UP * PLATFORM_CHECK_HEIGHT)
		var platform_below = check_for_platform(Vector2.DOWN * PLATFORM_CHECK_HEIGHT)
		
		# Reset stuck timer and track attempts
		stuck_timer = 0.0
		consecutive_stuck_attempts += 1
		
		# Get terrain info for movement decisions
		var terrain = get_terrain_info()
		
		# If target is above and there's a platform above, try to reach it
		if height_diff < -100 and platform_above:
			if consecutive_wall_jumps < 3:
				velocity.y = UNSTUCK_JUMP_VELOCITY * 1.2
				is_jumping = true
				consecutive_wall_jumps += 1
				return
		
		# If target is below and there's a safe platform, consider dropping
		elif height_diff > 100 and platform_below:
			if abs(height_diff) < MAX_DROP_HEIGHT:
				unstuck_direction = sign(target.global_position.x - position.x)
				velocity.x = UNSTUCK_SPEED * 0.5 * unstuck_direction
				return
		
		# Handle gaps and walls
		if terrain.gap_ahead:
			if terrain.gap_width < MAX_JUMPABLE_GAP and jump_cooldown_timer <= 0:
				velocity.y = UNSTUCK_JUMP_VELOCITY
				velocity.x = UNSTUCK_SPEED * (1 if moving_right else -1)
				is_jumping = true
				return
			else:
				unstuck_direction = -1.0 if moving_right else 1.0
				velocity.x = UNSTUCK_SPEED * unstuck_direction
		elif terrain.wall_ahead:
			if consecutive_wall_jumps < 2:
				velocity.y = UNSTUCK_JUMP_VELOCITY
				velocity.x = UNSTUCK_SPEED * (-1 if terrain.wall_right else 1)
				is_jumping = true
				consecutive_wall_jumps += 1
			else:
				unstuck_direction = -1.0 if terrain.wall_right else 1.0
				velocity.x = UNSTUCK_SPEED * unstuck_direction
				consecutive_wall_jumps = 0
		
		# If too many stuck attempts, change behavior
		if consecutive_stuck_attempts >= MAX_CONSECUTIVE_STUCK_ATTEMPTS:
			change_behavior("idle")
			consecutive_stuck_attempts = 0
			consecutive_wall_jumps = 0
			velocity = Vector2.ZERO
			return
		
		# Apply movement
		unstuck_move_timer = UNSTUCK_MOVE_DURATION

func check_for_platform(offset: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var check_pos = global_position + offset
	
	# Check for platform at the target height
	var query = PhysicsRayQueryParameters2D.create(check_pos, check_pos + Vector2.DOWN * 50.0)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
	var result = space_state.intersect_ray(query)
	
	if result:
		# Check platform width
		var platform_start = result.position
		var platform_end = result.position
		
		# Check left edge
		for i in range(MIN_PLATFORM_WIDTH):
			query = PhysicsRayQueryParameters2D.create(
				platform_start + Vector2.LEFT * i,
				platform_start + Vector2.LEFT * i + Vector2.DOWN * 50.0
			)
			var left_result = space_state.intersect_ray(query)
			if not left_result:
				platform_start = platform_start + Vector2.LEFT * (i - 1)
				break
		
		# Check right edge
		for i in range(MIN_PLATFORM_WIDTH):
			query = PhysicsRayQueryParameters2D.create(
				platform_end + Vector2.RIGHT * i,
				platform_end + Vector2.RIGHT * i + Vector2.DOWN * 50.0
			)
			var right_result = space_state.intersect_ray(query)
			if not right_result:
				platform_end = platform_end + Vector2.RIGHT * (i - 1)
				break
		
		# Return true if platform is wide enough
		return platform_end.x - platform_start.x >= MIN_PLATFORM_WIDTH
	
	return false

func find_path(start_point: PatrolPoint, target_pos: Vector2) -> Array[PatrolPoint]:
	# Reset all patrol points for pathfinding
	for point in patrol_points:
		point.reset_pathfinding()
	
	# Initialize start point
	start_point.cost = 0
	start_point.total_cost = start_point.position.distance_to(target_pos)
	
	# Priority queue for A* (implemented as Array for simplicity)
	var open_set: Array[PatrolPoint] = [start_point]
	var closed_set: Array[PatrolPoint] = []
	
	while open_set.size() > 0:
		# Find point with lowest total cost
		var current = open_set[0]
		var current_index = 0
		for i in range(1, open_set.size()):
			if open_set[i].total_cost < current.total_cost:
				current = open_set[i]
				current_index = i
		
		# Remove current point from open set
		open_set.remove_at(current_index)
		closed_set.append(current)
		
		# Check if we're close enough to target
		if current.position.distance_to(target_pos) < 100.0:  # Adjust threshold as needed
			# Reconstruct path
			var path: Array[PatrolPoint] = []
			var path_point = current
			while path_point != null:
				path.push_front(path_point)
				path_point = path_point.parent
			return path
		
		# Process neighbors
		for neighbor in current.connections:
			if neighbor in closed_set:
				continue
			
			var tentative_cost = current.cost + current.get_connection_cost(neighbor)
			
			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_cost >= neighbor.cost:
				continue
			
			# This path is better, record it
			neighbor.parent = current
			neighbor.cost = tentative_cost
			neighbor.total_cost = tentative_cost + neighbor.position.distance_to(target_pos)
	
	# No path found
	return []

func _process(_delta: float) -> void:
	if debug_enabled:
		queue_redraw()  # Redraw debug visualization every frame

func can_perform_attack() -> bool:
	if not target or not is_instance_valid(target):
		return false
	if attack_cooldown_timer > 0:
		return false
	var distance = global_position.distance_to(target.global_position)
	if distance > stats.attack_range:
		return false
	if not is_on_floor():
		return false
	return true

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if new_behavior != current_behavior:
		print("[Hunter] Behavior change: ", current_behavior, " -> ", new_behavior)
		if new_behavior == "chase":
			print("[Hunter] Chase target position: ", target.global_position if target else "No target")
		last_behavior_change = Time.get_ticks_msec() / 1000.0
		
		# Update animation based on new behavior
		if sprite:
			# Don't change animation if jumping or falling
			if velocity.y < 0:
				sprite.play("jump")
			elif velocity.y > 0:
				sprite.play("fall")
			else:
				match new_behavior:
					"idle":
						sprite.play("idle")
					"patrol":
						sprite.play("patrol")
					"chase":
						sprite.play("chase")
					"attack":
						sprite.play("chase")  # Use chase animation for attack until we have attack animation
					"hurt":
						sprite.play("idle")  # Use idle animation for hurt until we have hurt animation
	
	super.change_behavior(new_behavior, force)

func check_ground_ahead(direction: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var check_distance = 50.0  # Distance ahead to check
	
	# Start position slightly above current position
	var start_pos = global_position + Vector2(0, -20)
	var end_pos = start_pos + Vector2(direction.x * check_distance, 40)  # Check downward
	
	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Terrain + Platforms
	var result = space_state.intersect_ray(query)
	
	return result != null

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY_MULTIPLIER * delta, MAX_FALL_SPEED)
	elif is_jumping:
		is_jumping = false

func jump() -> void:
	if is_on_floor() and not is_jumping:
		print("[Hunter] Starting jump")
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		jump_cooldown_timer = JUMP_COOLDOWN
		if sprite:
			sprite.play("jump")

func get_closest_patrol_point(position: Vector2) -> PatrolPoint:
	var closest_point: PatrolPoint = null
	var closest_distance: float = INF
	
	# Iterate through all patrol points
	for point in patrol_points:
		var distance = position.distance_to(point.position)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point
	
	return closest_point

func find_closest_patrol_point(position: Vector2) -> PatrolPoint:
	var closest_point: PatrolPoint = null
	var closest_distance: float = INF
	
	# Iterate through all patrol points
	for point in patrol_points:
		var distance = position.distance_to(point.position)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point
	
	return closest_point

func handle_patrol(delta: float) -> void:
	# Update animation
	if sprite and sprite.animation != "patrol":
		sprite.play("patrol")
		sprite.flip_h = not moving_right
	
	# Check for player to chase
	target = get_nearest_player()
	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance <= stats.detection_range:
			change_behavior("chase")
			return
	
	# Move in patrol direction
	velocity.x = (stats.movement_speed if stats else 100.0) * (1 if moving_right else -1)
	
	# Check for walls or gaps
	var terrain = get_terrain_info()
	if terrain.wall_ahead or (terrain.gap_ahead and not terrain.can_jump):
		moving_right = not moving_right
		velocity.x = 0

func update_animation() -> void:
	if not sprite:
		return
		
	# Don't override jump or fall animations
	if is_jumping:
		if sprite.animation != "jump":
			sprite.play("jump")
		return
	elif not is_on_floor() and velocity.y > 0:
		if sprite.animation != "fall":
			sprite.play("fall")
		return
		
	# Update sprite direction based on movement
	if abs(velocity.x) > 10:
		sprite.flip_h = velocity.x < 0
		
	# Set animation based on current state
	match current_behavior:
		"idle":
			if sprite.animation != "idle":
				sprite.play("idle")
		"patrol":
			if sprite.animation != "patrol":
				sprite.play("patrol")
		"chase":
			if sprite.animation != "chase":
				sprite.play("chase")
		"attack":
			if sprite.animation != "chase":  # Use chase animation for attack until we have attack animation
				sprite.play("chase")
		"hurt":
			if sprite.animation != "idle":  # Use idle animation for hurt until we have hurt animation
				sprite.play("idle")

func update_chase_path() -> void:
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Only log significant position changes
	if abs(distance_to_target - last_logged_distance) > POSITION_LOG_THRESHOLD:
		print("[Hunter] Significant position change - Distance to target:", distance_to_target)
		last_logged_distance = distance_to_target
	
	# Update path only when needed
	if abs(distance_to_target - last_path_update_distance) > PATH_UPDATE_THRESHOLD:
		last_path_update_distance = distance_to_target
		var path = find_path_to_target()
		if not path.is_empty():
			current_path = path
			print("[Hunter] Updated path with", current_path.size(), "points")
		else:
			print("[Hunter] No valid path found to target")
			# Only disengage if really far
			if distance_to_target > MAX_CHASE_DISTANCE:
				print("[Hunter] Target too far, disengaging")
				change_behavior("idle")
				return
	
	# Handle movement based on distance
	if distance_to_target < MIN_CHASE_DISTANCE:
		velocity.x = move_toward(velocity.x, 0, stats.chase_speed * get_physics_process_delta_time())
	else:
		# Move towards target
		var direction = (target.global_position - global_position).normalized()
		velocity.x = move_toward(velocity.x, direction.x * stats.chase_speed, stats.chase_speed * get_physics_process_delta_time())

func handle_terrain() -> void:
	var terrain = get_terrain_info()
	
	# Handle terrain obstacles
	if is_on_floor():
		var height_diff = target.global_position.y - global_position.y if target else 0
		
		# Jump conditions
		if terrain.gap_ahead and terrain.can_jump:
			start_jump()
		elif terrain.wall_ahead and abs(height_diff) < PLATFORM_CHECK_HEIGHT:
			start_jump()
		elif height_diff < -50 and jump_cooldown_timer <= 0:
			start_jump()
	
	# Update jump cooldown
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= get_physics_process_delta_time()

func update_sprite_direction() -> void:
	if not sprite:
		return
		
	# Update sprite direction based on movement
	if abs(velocity.x) > 10:
		sprite.flip_h = velocity.x < 0
	
	# Update animation based on state
	if is_jumping:
		sprite.play("jump")
	elif not is_on_floor() and velocity.y > 10:
		sprite.play("fall")
	else:
		sprite.play("chase")
