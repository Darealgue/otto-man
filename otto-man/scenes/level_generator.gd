extends Node2D

enum Direction {
	LEFT = 0,
	RIGHT = 1,
	UP = 2,
	DOWN = 3
}

# Simple port system - like magnets, either can connect or can't
enum Port {
	CLOSED,  # No connection possible
	OPEN     # Connection possible
}

# Grid settings
const GRID_WIDTH = 20
const GRID_HEIGHT = 10
const CHUNK_SIZE = Vector2(1920, 1088)  # Updated to be perfectly divisible by tile size (32x32)
const GRID_SPACING = Vector2(1920, 1088)  # Space between chunks must match chunk size
const MIN_CHUNKS = 30  # Increased minimum chunks for larger levels

# Direction vectors for easy position calculations
const DIRECTION_VECTORS = {
	Direction.LEFT: Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
	Direction.UP: Vector2i(0, -1),
	Direction.DOWN: Vector2i(0, 1)
}

# Chunk definitions with their port configurations
const CHUNKS = {
	"start": {
		"scene": "res://chunks/special/start_chunk.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"basic": {
		"scene": "res://chunks/basic/basic_platform.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"combat": {
		"scene": "res://chunks/special/combat_arena.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"vertical": {
		"scene": "res://chunks/vertical/climbing_tower.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"corner_left_up": {
		"scene": "res://chunks/hub/l_corner_left_up.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"corner_right_up": {
		"scene": "res://chunks/hub/l_corner_right_up.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"corner_left_down": {
		"scene": "res://chunks/hub/l_corner_left_down.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"corner_right_down": {
		"scene": "res://chunks/hub/l_corner_right_down.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_down": {
		"scene": "res://chunks/hub/t_junction_down.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"t_junction_up": {
		"scene": "res://chunks/hub/t_junction_up.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_right": {
		"scene": "res://chunks/hub/t_junction_right.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_left": {
		"scene": "res://chunks/hub/t_junction_left.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"four_way_hub": {
		"scene": "res://chunks/hub/four_way_hub.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"finish": {
		"scene": "res://chunks/special/finish_chunk.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"dead_end_up": {
		"scene": "res://chunks/special/dead_end_up.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"dead_end_down": {
		"scene": "res://chunks/special/dead_end_down.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"dead_end_right": {
		"scene": "res://chunks/special/dead_end_right.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"dead_end_left": {
		"scene": "res://chunks/special/dead_end_left.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	}
}

# Layout cell types for first phase generation
enum CellType {
	EMPTY,          # No chunk here
	MAIN_PATH,      # Part of the main path from start to finish
	BRANCH_PATH,    # Part of a side branch
	DEAD_END,       # End of a branch
	BRANCH_POINT    # Where a branch splits from main path
}

# Grid cell to store layout and chunk information
class GridCell:
	var chunk: Node2D = null
	var visited: bool = false
	var cell_type: CellType = CellType.EMPTY
	var connections: Array[bool] = [false, false, false, false]  # LEFT, RIGHT, UP, DOWN

# Member variables
var grid: Array = []
var chunks_placed: int = 0
var current_path: Array = []
var overview_camera: Camera2D
var is_overview_active: bool = true
var start_positions: Array = []
var finish_positions: Array = []
var path_points: Array = []
const max_consecutive_same_direction = 3

@export var current_level: int = 1  # Current level number
@export var level_config: DungeonConfig  # Reference to our dungeon configuration resource

var current_grid_width = 20  # This will be updated based on level
var CHUNK_WEIGHTS = {
	"basic": 70,
	"combat": 30,
	"vertical": 50,
	"corner_left_up": 50,
	"corner_right_up": 50,
	"corner_left_down": 50,
	"corner_right_down": 50,
	"t_junction_up": 50,
	"t_junction_down": 50,
	"t_junction_left": 50,
	"t_junction_right": 50,
	"four_way_hub": 50  # Increased from 30 to 50 to make it more available when needed
}

var player_camera_zoom_cache := Vector2.ONE  # Add this at the top with other variables

var is_transitioning: bool = false
var transition_cooldown: float = 1.0

var chunk_cache: Dictionary = {}
var BATCH_SIZE = 20  # Increased from 10 to 20
var is_chunk_loading_async: bool = true

class PathGenerator:
	var astar := AStar2D.new()
	var grid_width: int
	var grid_height: int
	
	func _init(width: int, height: int):
		grid_width = width
		grid_height = height
		_setup_astar_grid()
	
	func _setup_astar_grid():
		# Add points for each grid position
		for x in range(grid_width):
			for y in range(grid_height):
				var idx = _get_point_index(Vector2i(x, y))
				astar.add_point(idx, Vector2(x, y))
		
		# Connect points with their neighbors
		for x in range(grid_width):
			for y in range(grid_height):
				var current = Vector2i(x, y)
				var current_idx = _get_point_index(current)
				
				# Connect to right neighbor
				if x < grid_width - 1:
					var right = Vector2i(x + 1, y)
					var right_idx = _get_point_index(right)
					astar.connect_points(current_idx, right_idx)
				
				# Connect to bottom neighbor
				if y < grid_height - 1:
					var bottom = Vector2i(x, y + 1)
					var bottom_idx = _get_point_index(bottom)
					astar.connect_points(current_idx, bottom_idx)
	
	func _get_point_index(pos: Vector2i) -> int:
		return pos.x + (pos.y * grid_width)
	
	func generate_main_path(start_pos: Vector2i, target_length: int) -> Array:
		var path := []
		var current := start_pos
		path.append(current)
		
		# Generate path with more vertical variation
		var target_x = min(grid_width - 2, start_pos.x + target_length)
		var attempts := 0
		var max_attempts := 100
		
		while path.size() < target_length and attempts < max_attempts:
			attempts += 1
			
			# Encourage vertical movement every few steps
			var force_vertical = path.size() % 4 == 0
			var target: Vector2i
			
			if force_vertical:
				# Pick a point above or below current position
				var vertical_offset = randi() % 5 - 2  # -2 to +2
				var target_y = clamp(current.y + vertical_offset, 1, grid_height - 2)
				target = Vector2i(current.x, target_y)
			else:
				# Move forward with some vertical variation
				var forward_steps = randi() % 3 + 1  # 1 to 3 steps forward
				var target_x_local = min(current.x + forward_steps, grid_width - 2)
				var y_variation = randi() % 3 - 1  # -1 to +1
				var target_y = clamp(current.y + y_variation, 1, grid_height - 2)
				target = Vector2i(target_x_local, target_y)
			
			var astar_path = astar.get_point_path(_get_point_index(current), _get_point_index(target))
			
			for point in astar_path:
				var grid_pos = Vector2i(point.x, point.y)
				if not path.has(grid_pos):
					path.append(grid_pos)
					if path.size() >= target_length:
						break
			
			current = path[-1]
			
			# Add some backtracking occasionally
			if randf() < 0.2 and path.size() > 3:
				var backtrack_steps = randi() % 3 + 1
				current = path[max(0, path.size() - backtrack_steps - 1)]
		
		return path
	
	func generate_branches(main_path: Array, branch_count: int, min_length: int, max_length: int) -> Array:
		var branches := []
		var attempts := 0
		var max_attempts := branch_count * 3  # Increased attempts for better branches
		
		while branches.size() < branch_count and attempts < max_attempts:
			attempts += 1
			
			# Prefer middle sections of main path for branching
			var valid_start_indices = []
			for i in range(1, main_path.size() - 1):
				var pos = main_path[i]
				if pos.x > 2 and pos.x < grid_width - 3:  # Avoid edges
					valid_start_indices.append(i)
			
			if valid_start_indices.is_empty():
				continue
			
			var start_idx = valid_start_indices[randi() % valid_start_indices.size()]
			var start_point = main_path[start_idx]
			var branch_length = randi() % (max_length - min_length + 1) + min_length
			
			# Generate target point with more variation
			var direction = randi() % 4  # 0: up, 1: right, 2: down, 3: left
			var target: Vector2i
			match direction:
				0:  # Up
					target = Vector2i(start_point.x + randi() % 3 - 1, max(1, start_point.y - branch_length))
				1:  # Right
					target = Vector2i(min(grid_width - 2, start_point.x + branch_length), start_point.y + randi() % 3 - 1)
				2:  # Down
					target = Vector2i(start_point.x + randi() % 3 - 1, min(grid_height - 2, start_point.y + branch_length))
				3:  # Left
					target = Vector2i(max(2, start_point.x - branch_length), start_point.y + randi() % 3 - 1)
			
			var branch_path = astar.get_point_path(_get_point_index(start_point), _get_point_index(target))
			
			# Validate branch
			if branch_path.size() >= min_length:
				var grid_path := []
				var is_valid = true
				
				for point in branch_path:
					var grid_pos = Vector2i(point.x, point.y)
					# Check if this position is already used by another branch
					for existing_branch in branches:
						if existing_branch.has(grid_pos):
							is_valid = false
							break
					if not is_valid:
						break
					grid_path.append(grid_pos)
				
				if is_valid:
					branches.append(grid_path)
		
		return branches

signal level_completed
signal level_started

func _ready() -> void:
	is_overview_active = true
	setup_camera()
	preload_chunks()
	generate_level()

func setup_camera() -> void:
	overview_camera = Camera2D.new()
	add_child(overview_camera)
	
	# Position camera to see the whole level
	var level_size = Vector2(current_grid_width * CHUNK_SIZE.x, GRID_HEIGHT * CHUNK_SIZE.y)
	overview_camera.position = level_size / 2
	
	# Calculate zoom to fit the level
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_x = viewport_size.x / level_size.x
	var zoom_y = viewport_size.y / level_size.y
	overview_camera.zoom = Vector2(min(zoom_x, zoom_y) * 0.9, min(zoom_x, zoom_y) * 0.9)
	
	# Only make current if we're in overview mode
	if is_overview_active:
		overview_camera.make_current()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):  # We'll set this up in Project Settings
		toggle_camera()

func toggle_camera() -> void:
	is_overview_active = !is_overview_active
	var player = get_node_or_null("Player")
	
	if is_overview_active:
		if overview_camera:
			overview_camera.make_current()
	elif player and player.has_node("Camera2D"):
		var player_camera = player.get_node("Camera2D")
		player_camera.make_current()
		# Ensure player camera is enabled
		player_camera.enabled = true

func clear_level() -> void:
	# Store camera state and zoom
	var player = get_node_or_null("Player")
	var player_camera_zoom = Vector2.ONE
	if player and player.has_node("Camera2D"):
		is_overview_active = !player.get_node("Camera2D").is_current()
		player_camera_zoom = player.get_node("Camera2D").zoom
	
	# Store player and zone references before clearing
	var stored_player = player
	var start_zone = get_node_or_null("StartZone")
	var finish_zone = get_node_or_null("FinishZone")
	
	# Remove all chunks except the LevelGenerator itself, player, and zones
	for child in get_children():
		if child != overview_camera and child != stored_player and child != start_zone and child != finish_zone:
			child.queue_free()
	
	# Reset grid
	grid.clear()
	chunks_placed = 0
	current_path.clear()
	
	# Update overview camera for new level size
	setup_camera()
	
	# Store zoom for next player camera if we don't have a player yet
	if not stored_player:
		player_camera_zoom_cache = player_camera_zoom

func preload_chunks() -> void:
	print("\nPreloading chunks...")
	var start_time = Time.get_ticks_msec()
	
	for chunk_type in CHUNKS:
		var scene = load(CHUNKS[chunk_type]["scene"])
		if scene:
			chunk_cache[chunk_type] = scene
	
	var end_time = Time.get_ticks_msec()
	print("Chunk preloading completed in ", (end_time - start_time) / 1000.0, " seconds")

func generate_level() -> void:
	var start_time = Time.get_ticks_msec()
	print("\n=== STARTING LEVEL GENERATION ===")
	print("Current level: ", current_level)
	
	# Clear existing level
	clear_level()
	
	# Calculate grid width based on level
	current_grid_width = GRID_WIDTH + (current_level - 1) * 2  # Increase width by 2 for each level
	print("Grid width for level ", current_level, ": ", current_grid_width)
	
	# Preload chunks if needed
	if not is_chunk_loading_async:
		preload_chunks()
	
	# Increment level counter
	current_level += 1
	
	# Generate the layout first
	print("\nGenerating level layout...")
	if not generate_layout():
		push_error("Failed to generate layout!")
		return
	print("Layout generation completed successfully")
	
	# Populate chunks
	print("\nPopulating chunks...")
	if not populate_chunks():
		push_error("Failed to populate chunks!")
		return
	print("Chunk population completed successfully")
	
	# Process chunks in batches
	print("\nProcessing chunks...")
	var chunks_to_process = []
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			if grid[x][y].chunk:
				chunks_to_process.append(grid[x][y].chunk)
	
	var total_chunks = chunks_to_process.size()
	var processed_chunks = 0
	
	print("Processing ", total_chunks, " chunks in batches of ", BATCH_SIZE)
	while processed_chunks < total_chunks:
		var batch_end = min(processed_chunks + BATCH_SIZE, total_chunks)
		var batch = chunks_to_process.slice(processed_chunks, batch_end)
		
		# Process batch
		for chunk in batch:
			if chunk and chunk.has_meta("original_collision"):
				var original_collision = chunk.get_meta("original_collision")
				chunk.collision_layer = original_collision.layer
				chunk.collision_mask = original_collision.mask
		
		processed_chunks = batch_end
		print("Processed ", processed_chunks, " of ", total_chunks, " chunks")
		
		# Reduced delay between batches
		await get_tree().create_timer(0.05).timeout
	
	print("Setting up level transitions...")
	var transition_start = Time.get_ticks_msec()
	setup_level_transitions()
	var transition_end = Time.get_ticks_msec()
	print("Level transitions setup completed in ", (transition_end - transition_start) / 1000.0, " seconds")
	
	print("Spawning player...")
	var spawn_start = Time.get_ticks_msec()
	spawn_player()
	var spawn_end = Time.get_ticks_msec()
	print("Player spawned in ", (spawn_end - spawn_start) / 1000.0, " seconds")
	
	var end_time = Time.get_ticks_msec()
	print("Level generation completed in ", (end_time - start_time) / 1000.0, " seconds")

func generate_layout() -> bool:
	print("\n=== PHASE 1: GENERATING ABSTRACT LAYOUT ===")
	print("Grid dimensions: ", current_grid_width, "x", GRID_HEIGHT)
	print("Current level: ", current_level)
	
	# Initialize grid
	print("\nInitializing grid...")
	initialize_grid()
	
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			grid[x][y].cell_type = CellType.EMPTY
			grid[x][y].visited = false
			for dir in Direction.values():
				grid[x][y].connections[dir] = false
	print("Grid initialized with empty cells")
	
	# Set up start and finish positions
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var finish_pos = Vector2i(current_grid_width - 1, GRID_HEIGHT / 2)
	print("\nSetting up start and finish positions:")
	print("Start position: ", start_pos)
	print("Finish position: ", finish_pos)
	
	# Mark start position
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	# Clear all connections first
	for dir in Direction.values():
		grid[start_pos.x][start_pos.y].connections[dir] = false
	# Only set right connection
	grid[start_pos.x][start_pos.y].connections[Direction.RIGHT] = true
	print("Start position marked as MAIN_PATH with RIGHT connection only")
	
	# Mark finish position
	grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
	grid[finish_pos.x][finish_pos.y].visited = true
	# Clear all connections first
	for dir in Direction.values():
		grid[finish_pos.x][finish_pos.y].connections[dir] = false
	# Only set left connection
	grid[finish_pos.x][finish_pos.y].connections[Direction.LEFT] = true
	print("Finish position marked as MAIN_PATH with LEFT connection only")
	
	# Calculate number of main paths based on level
	var num_main_paths = 1 + (current_level - 1) / 4  # Every 4 levels, add a new path
	print("\nGenerating ", num_main_paths, " main paths...")
	
	# Generate first path from start position
	print("\nGenerating first path from start position")
	generate_single_path(Vector2i(1, GRID_HEIGHT / 2), true)
	
	# Generate additional paths if needed
	for i in range(1, num_main_paths):
		print("\nGenerating additional path ", i + 1)
		
		# Find a valid starting point
		var valid_start_points = []
		for x in range(1, current_grid_width - 1):
			for y in range(1, GRID_HEIGHT - 1):
				if grid[x][y].cell_type == CellType.MAIN_PATH:
					# Check if this point has potential for a new path
					var has_potential = false
					for dir in Direction.values():
						var next_pos = Vector2i(x, y) + DIRECTION_VECTORS[dir]
						if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
							has_potential = true
							break
					if has_potential:
						valid_start_points.append(Vector2i(x, y))
		
		if not valid_start_points.is_empty():
			var start_point = valid_start_points[randi() % valid_start_points.size()]
			print("Selected start point for additional path: ", start_point)
			generate_single_path(start_point, false)
		else:
			print("No valid start points found for additional path")
	
	return true

func generate_single_path(start_pos: Vector2i, is_first_path: bool) -> void:
	var current_pos = start_pos
	var path_segments = 0
	var vertical_moves = 0
	var horizontal_moves = 0
	var last_direction = Direction.RIGHT
	var consecutive_same_direction = 0
	
	# Add start position to path if it's the first path
	if is_first_path:
		path_points.clear()
		path_points.append(Vector2i(0, GRID_HEIGHT / 2))
		# Ensure start chunk is connected to first path segment
		grid[0][GRID_HEIGHT / 2].connections[Direction.RIGHT] = true
		grid[1][GRID_HEIGHT / 2].connections[Direction.LEFT] = true
		print("Connecting start chunk to first path segment")
	
	print("Starting path generation from position: ", current_pos)
	
	# Mark the starting position
	grid[current_pos.x][current_pos.y].cell_type = CellType.MAIN_PATH
	grid[current_pos.x][current_pos.y].visited = true
	
	while current_pos.x < current_grid_width - 1:
		path_segments += 1
		print("Path segment ", path_segments, ": ")
		
		# Determine next direction based on current state
		var next_direction = select_next_direction(
			current_pos,
			last_direction,
			consecutive_same_direction,
			vertical_moves,
			horizontal_moves
		)
		
		# Calculate potential next position
		var next_pos = current_pos + get_direction_vector(next_direction)
		print("Attempting ", get_direction_name(next_direction), " movement")
		print("Potential next position: ", next_pos)
		
		# Validate position
		if is_valid_position(next_pos):
			# Check if this would create a diagonal connection
			if not would_create_diagonal(current_pos, next_pos):
				print("Valid position found, moving to: ", next_pos)
				# Set connections
				grid[current_pos.x][current_pos.y].connections[next_direction] = true
				grid[next_pos.x][next_pos.y].connections[get_opposite_direction(next_direction)] = true
				print("Setting connection from ", current_pos, " to ", next_pos, " in direction ", next_direction)
				print("Setting connection from ", next_pos, " to ", current_pos, " in direction ", get_opposite_direction(next_direction))
				
				# Mark both positions as main path
				grid[current_pos.x][current_pos.y].cell_type = CellType.MAIN_PATH
				grid[current_pos.x][current_pos.y].visited = true
				grid[next_pos.x][next_pos.y].cell_type = CellType.MAIN_PATH
				grid[next_pos.x][next_pos.y].visited = true
				
				# Update path points
				path_points.append(next_pos)
				
				# Update movement counters
				if next_direction == Direction.UP or next_direction == Direction.DOWN:
					vertical_moves += 1
				else:
					horizontal_moves += 1
				
				# Update consecutive direction tracking
				if next_direction == last_direction:
					consecutive_same_direction += 1
				else:
					consecutive_same_direction = 0
					last_direction = next_direction
				
				current_pos = next_pos
				continue
			else:
				print("Diagonal connection would be created, trying alternative direction")
				# Try alternative directions
				var alternative_directions = [Direction.RIGHT, Direction.UP, Direction.DOWN]
				alternative_directions.erase(next_direction)
				var found_valid = false
				
				for alt_dir in alternative_directions:
					var alt_pos = current_pos + get_direction_vector(alt_dir)
					if is_valid_position(alt_pos) and not would_create_diagonal(current_pos, alt_pos):
						next_direction = alt_dir
						next_pos = alt_pos
						found_valid = true
						break
				
				if not found_valid:
					print("No valid alternative direction found, defaulting to right movement")
					next_pos = Vector2i(current_pos.x + 1, current_pos.y)
		else:
			print("Invalid position, trying alternative direction")
			# Try alternative directions
			var alternative_directions = [Direction.RIGHT, Direction.UP, Direction.DOWN]
			alternative_directions.erase(next_direction)
			var found_valid = false
			
			for alt_dir in alternative_directions:
				var alt_pos = current_pos + get_direction_vector(alt_dir)
				if is_valid_position(alt_pos) and not would_create_diagonal(current_pos, alt_pos):
					next_direction = alt_dir
					next_pos = alt_pos
					found_valid = true
					break
				
			if not found_valid:
				print("No valid alternative direction found, defaulting to right movement")
				next_pos = Vector2i(current_pos.x + 1, current_pos.y)
				
		# Handle movement to next position
		grid[current_pos.x][current_pos.y].connections[Direction.RIGHT] = true
		grid[next_pos.x][next_pos.y].connections[Direction.LEFT] = true
		print("Setting connection from ", current_pos, " to ", next_pos, " in direction 1")
		print("Setting connection from ", next_pos, " to ", current_pos, " in direction 0")
		
		# Mark both positions as main path
		grid[current_pos.x][current_pos.y].cell_type = CellType.MAIN_PATH
		grid[current_pos.x][current_pos.y].visited = true
		grid[next_pos.x][next_pos.y].cell_type = CellType.MAIN_PATH
		grid[next_pos.x][next_pos.y].visited = true
		
		path_points.append(next_pos)
		horizontal_moves += 1
		consecutive_same_direction = 0
		last_direction = Direction.RIGHT
		current_pos = next_pos
	
	print("\nMain path generation completed:")
	print("Total path segments: ", path_segments)
	print("Path points: ", path_points)
	
	# Connect final path segment to finish position
	if not path_points.is_empty():
		var final_pos = path_points[-1]
		var finish_pos = Vector2i(current_grid_width - 1, GRID_HEIGHT / 2)
		grid[final_pos.x][final_pos.y].connections[Direction.RIGHT] = true
		grid[finish_pos.x][finish_pos.y].connections[Direction.LEFT] = true
		print("\nConnecting final path segment to finish position")
		print("Final connection established from ", final_pos, " to ", finish_pos)
	
	# Generate branches
	print("\nGenerating branches...")
	var num_branches = min(3, current_grid_width / 5)  # Scale branches with level size
	print("Target number of branches: ", num_branches)
	var branch_points = []
	
	# Find potential branch points
	for i in range(1, path_points.size() - 1):
		var point = path_points[i]
		if point.x > 1 and point.x < current_grid_width - 2:  # Avoid branching near start/finish
			branch_points.append(point)
	print("Found ", branch_points.size(), " potential branch points")
	
	# Create branches
	var branches_created = 0
	for _i in range(num_branches):
		if branch_points.is_empty():
			print("No more valid branch points available")
			break
		
		var branch_start_idx = randi() % branch_points.size()
		var branch_start = branch_points[branch_start_idx]
		branch_points.remove_at(branch_start_idx)
		print("\nCreating branch ", branches_created + 1, " from point: ", branch_start)
		
		# Determine branch direction (up or down)
		var branch_direction = Direction.UP if randi() % 2 == 0 else Direction.DOWN
		var branch_length = randi() % 3 + 2  # 2-4 segments
		print("Branch direction: ", branch_direction, ", Target length: ", branch_length)
		
		var branch_pos = branch_start
		var actual_length = 0
		for _j in range(branch_length):
			var next_pos = branch_pos + DIRECTION_VECTORS[branch_direction]
			print("Attempting to extend branch to: ", next_pos)
			
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				print("Invalid or occupied position, stopping branch")
				break
			
			# Set up branch connections
			grid[branch_pos.x][branch_pos.y].connections[branch_direction] = true
			grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
			grid[next_pos.x][next_pos.y].visited = true
			grid[next_pos.x][next_pos.y].connections[get_opposite_direction(branch_direction)] = true
			print("Branch connection established from ", branch_pos, " to ", next_pos)
			
			branch_pos = next_pos
			actual_length += 1
		
		# Mark end of branch as dead end
		grid[branch_pos.x][branch_pos.y].cell_type = CellType.DEAD_END
		print("Branch completed with length ", actual_length, ", marked as dead end at ", branch_pos)
		branches_created += 1
	
	print("\nBranch generation completed:")
	print("Total branches created: ", branches_created)
	
	# Print final grid state
	print("\nFinal grid state:")
	for y in range(GRID_HEIGHT):
		var row = ""
		for x in range(current_grid_width):
			if grid[x][y].cell_type == CellType.EMPTY:
				row += "."
			elif grid[x][y].cell_type == CellType.MAIN_PATH:
				row += "M"
			elif grid[x][y].cell_type == CellType.BRANCH_PATH:
				row += "B"
			elif grid[x][y].cell_type == CellType.DEAD_END:
				row += "D"
		print(row)
	
	print("\nLayout generation completed successfully")

func populate_chunks() -> bool:
	print("\n=== PHASE 2: POPULATING CHUNKS ===")
	
	# Create a list of positions to process
	var positions_to_process = []
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			if grid[x][y].visited:
				positions_to_process.append(Vector2i(x, y))
	
	print("\nFound ", positions_to_process.size(), " positions to process")
	
	# Sort positions from left to right
	positions_to_process.sort_custom(func(a, b): return a.x < b.x)
	print("Positions sorted from left to right")
	
	# Process each position
	var chunks_placed = 0
	for pos in positions_to_process:
		print("\n=== Processing position: ", pos, " ===")
		
		# Skip if already has a chunk
		if grid[pos.x][pos.y].chunk != null:
			print("Position already has a chunk, skipping...")
			continue
		
		# Get cell data
		var cell = grid[pos.x][pos.y]
		print("Cell type: ", cell.cell_type)
		print("Connections: ", cell.connections)
		
		# Handle special cases first
		var chunk_type = ""
		if pos.x == 0:  # Leftmost column
			chunk_type = "start"
			print("Special case: Start chunk (leftmost column)")
		elif pos.x == current_grid_width - 1:  # Rightmost column
			chunk_type = "finish"
			print("Special case: Finish chunk (rightmost column)")
		elif cell.cell_type == CellType.DEAD_END and cell.connections.count(true) == 1:  # Only handle dead ends with exactly one connection
			# Determine dead end type based on connections
			if cell.connections[Direction.LEFT]:
				chunk_type = "dead_end_right"
			elif cell.connections[Direction.RIGHT]:
				chunk_type = "dead_end_left"
			elif cell.connections[Direction.UP]:
				chunk_type = "dead_end_down"
			elif cell.connections[Direction.DOWN]:
				chunk_type = "dead_end_up"
			print("Special case: Dead end chunk (", chunk_type, ")")
		
		# If no special case, select appropriate chunk
		if chunk_type.is_empty():
			print("No special case, selecting appropriate chunk based on connections...")
			chunk_type = select_appropriate_chunk(cell)
			print("Selected chunk type: ", chunk_type)
		
		# Validate chunk selection
		if chunk_type.is_empty():
			push_error("Failed to select appropriate chunk for position " + str(pos))
			return false
		
		# Create chunk instance
		print("\nCreating chunk instance...")
		var chunk_scene = load(CHUNKS[chunk_type]["scene"])
		if chunk_scene == null:
			push_error("Failed to load chunk scene: " + CHUNKS[chunk_type]["scene"])
			return false
		print("Chunk scene loaded successfully")
		
		var chunk_instance = chunk_scene.instantiate()
		if chunk_instance == null:
			push_error("Failed to instantiate chunk scene")
			return false
		print("Chunk instance created successfully")
		
		# Position the chunk
		var world_pos = Vector2(pos.x * GRID_SPACING.x, pos.y * GRID_SPACING.y)
		chunk_instance.position = world_pos
		print("Chunk positioned at world coordinates: ", world_pos)
		
		# Add chunk to grid and scene
		grid[pos.x][pos.y].chunk = chunk_instance
		add_child(chunk_instance)
		chunks_placed += 1
		print("Chunk added to grid and scene tree")
		
		# Validate connections for this chunk
		print("\nValidating connections for chunk at ", pos)
		if not validate_connections(pos, chunk_type):
			push_error("Connection validation failed for chunk at " + str(pos))
			return false
		print("Connection validation successful")
	
	print("\n=== Chunk Population Summary ===")
	print("Total chunks placed: ", chunks_placed)
	print("Total positions processed: ", positions_to_process.size())
	
	# Print final chunk placement visualization
	print("\nFinal chunk placement visualization:")
	for y in range(GRID_HEIGHT):
		var row = ""
		for x in range(current_grid_width):
			if grid[x][y].chunk == null:
				row += "."
			else:
				var chunk_type = get_chunk_type(grid[x][y].chunk)
				match chunk_type:
					"start": row += "S"
					"finish": row += "F"
					"dead_end_up": row += "U"
					"dead_end_down": row += "D"
					"dead_end_left": row += "L"
					"dead_end_right": row += "R"
					"basic": row += "B"
					"vertical": row += "V"
					"corner_left_up": row += "1"
					"corner_right_up": row += "2"
					"corner_left_down": row += "3"
					"corner_right_down": row += "4"
					"t_junction_up": row += "5"
					"t_junction_down": row += "6"
					"t_junction_left": row += "7"
					"t_junction_right": row += "8"
					"four_way_hub": row += "9"
					_: row += "?"
		print(row)
	
	print("\nChunk population completed successfully")
	return true

func select_appropriate_chunk(cell: GridCell) -> String:
	# Count total connections
	var connection_count = 0
	for dir in Direction.values():
		if cell.connections[dir]:
			connection_count += 1
	
	print("Selecting chunk with ", connection_count, " connections")
	
	# Handle different connection counts
	match connection_count:
		1:  # Dead end
			if cell.connections[Direction.LEFT]:
				return "dead_end_right"
			elif cell.connections[Direction.RIGHT]:
				return "dead_end_left"
			elif cell.connections[Direction.UP]:
				return "dead_end_down"
			elif cell.connections[Direction.DOWN]:
				return "dead_end_up"
	
		2:  # Basic path or corner
			if cell.connections[Direction.LEFT] and cell.connections[Direction.RIGHT]:
				return "basic"
			elif cell.connections[Direction.UP] and cell.connections[Direction.DOWN]:
				return "vertical"
			elif cell.connections[Direction.LEFT] and cell.connections[Direction.UP]:
				return "corner_left_up"
			elif cell.connections[Direction.RIGHT] and cell.connections[Direction.UP]:
				return "corner_right_up"
			elif cell.connections[Direction.LEFT] and cell.connections[Direction.DOWN]:
				return "corner_left_down"
			elif cell.connections[Direction.RIGHT] and cell.connections[Direction.DOWN]:
				return "corner_right_down"
		
		3:  # T-junction
			if not cell.connections[Direction.LEFT]:
				return "t_junction_left"
			elif not cell.connections[Direction.RIGHT]:
				return "t_junction_right"
			elif not cell.connections[Direction.UP]:
				return "t_junction_up"
			elif not cell.connections[Direction.DOWN]:
				return "t_junction_down"
		
		4:  # Four-way intersection
			return "four_way_hub"
	
	# If no match found, use basic chunk as fallback
	print("Warning: No specific chunk type found, using basic as fallback")
	return "basic"

func validate_connections(pos: Vector2i, chunk_type: String) -> bool:
	print("\n=== Validating connections for ", chunk_type, " at position ", pos, " ===")
	
	# Get the ports configuration for the chunk type
	var ports = CHUNKS[chunk_type]["ports"]
	print("\nChunk ports configuration:")
	for dir in Direction.values():
		print("Direction ", dir, ": ", ports[dir])
		
	# Special handling for start and finish chunks
	if chunk_type == "start":
		print("\nValidating start chunk connections...")
		# Start chunks should only have right connection
		for dir in Direction.values():
			if dir == Direction.RIGHT:
				if not grid[pos.x][pos.y].connections[dir]:
					print("ERROR: Start chunk missing required RIGHT connection")
					return false
				print("✓ RIGHT connection validated")
			else:
				if grid[pos.x][pos.y].connections[dir]:
					print("ERROR: Start chunk has invalid connection in direction ", dir)
					return false
				print("✓ No connection in direction ", dir, " (valid)")
		print("Start chunk validation successful!")
		return true
	
	if chunk_type == "finish":
		print("\nValidating finish chunk connections...")
		# Finish chunks should only have left connection
		for dir in Direction.values():
			if dir == Direction.LEFT:
				if not grid[pos.x][pos.y].connections[dir]:
					print("ERROR: Finish chunk missing required LEFT connection")
					return false
				print("✓ LEFT connection validated")
			else:
				if grid[pos.x][pos.y].connections[dir]:
					print("ERROR: Finish chunk has invalid connection in direction ", dir)
					return false
				print("✓ No connection in direction ", dir, " (valid)")
		print("Finish chunk validation successful!")
		return true
	
	# Check each direction
	print("\nValidating connections in each direction...")
	for dir in Direction.values():
		var neighbor_pos = pos + DIRECTION_VECTORS[dir]
		var has_connection = grid[pos.x][pos.y].connections[dir]
		var port_state = ports[dir]
		
		print("\nDirection ", dir, ":")
		print("- Has connection: ", has_connection)
		print("- Port state: ", port_state)
		print("- Neighbor position: ", neighbor_pos)
		
		if has_connection:
			# If we have a connection, the port must be open
			if port_state != Port.OPEN:
				print("ERROR: Connection exists but port is closed")
				return false
			print("✓ Port is open (valid)")
			
			# Check if the neighbor exists and has a matching connection
			if is_valid_position(neighbor_pos):
				var opposite_dir = get_opposite_direction(dir)
				if grid[neighbor_pos.x][neighbor_pos.y].visited:
					if not grid[neighbor_pos.x][neighbor_pos.y].connections[opposite_dir]:
						print("ERROR: Missing matching connection at neighbor position")
						print("Current connections: ", grid[pos.x][pos.y].connections)
						print("Neighbor connections: ", grid[neighbor_pos.x][neighbor_pos.y].connections)
						return false
					print("✓ Matching connection found at neighbor")
				else:
					print("WARNING: Neighbor position is not visited")
			else:
				print("ERROR: Connection leads outside grid")
				return false
		else:
			# If we don't have a connection, the port must be closed
			if port_state != Port.CLOSED:
				print("ERROR: No connection but port is open")
				return false
			print("✓ Port is closed (valid)")
	
	print("\nAll connections validated successfully!")
	return true

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < current_grid_width and pos.y >= 0 and pos.y < GRID_HEIGHT

func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * GRID_SPACING.x, pos.y * GRID_SPACING.y)

func is_valid_tile_coord(x: int, y: int) -> bool:
	# Valid tile ranges based on the tileset
	if (x >= 0 and x <= 2 and y >= 0 and y <= 2) or \
			(x == 4 and y >= 0 and y <= 4) or \
			((x == 12 or x == 14) and y >= 0 and y <= 8):
		return true
	return false

func place_chunk(pos: Vector2i, chunk_type: String) -> bool:
	print("\nAttempting to place chunk:", chunk_type, "at position:", pos)
	if not is_valid_position(pos):
		print("Invalid position for chunk placement")
		return false
	
	if grid[pos.x][pos.y].chunk != null:
		print("Chunk already exists at position")
		return false
	
	var ports = CHUNKS[chunk_type]["ports"]
	print("Chunk ports configuration:", ports)
	
	# Validate connections before placing the chunk
	if not validate_connections(pos, chunk_type):
		print("Connection validation failed, cannot place chunk")
		return false
	
	var chunk
	if chunk_cache.has(chunk_type):
		chunk = chunk_cache[chunk_type].instantiate()
	else:
		var scene = load(CHUNKS[chunk_type]["scene"])
		if not scene:
			print("Failed to load chunk scene:", CHUNKS[chunk_type]["scene"])
			return false
		chunk = scene.instantiate()
	
	add_child(chunk)
	chunk.position = grid_to_world(pos)
	grid[pos.x][pos.y].chunk = chunk
	
	print("Successfully placed", chunk_type, "at", pos)
	return true

func get_chunk_type(chunk: Node) -> String:
	if not chunk:
		return ""
	
	for type in CHUNKS:
		if chunk.scene_file_path == CHUNKS[type]["scene"]:
			return type
	
	return ""

func get_opposite_direction(dir: Direction) -> Direction:
	if not is_valid_direction(dir):
		push_error("Invalid direction value: " + str(dir))
		return Direction.RIGHT  # Safe fallback
		
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT  # Fallback, should never reach here

func set_grid_connection(pos: Vector2i, dir: int, value: bool) -> void:
	if not is_valid_position(pos) or not is_valid_direction(dir):
		return
	
	grid[pos.x][pos.y].connections[dir] = value

func spawn_player() -> void:
	print("\n=== Spawning Player ===")
	
	# Find start position
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	print("Start position: ", start_pos)
	
	# Find start chunk
	var start_chunk = grid[start_pos.x][start_pos.y].chunk
	if start_chunk == null:
		push_error("No start chunk found at position " + str(start_pos))
		return
	print("Found start chunk at position: ", start_pos)
	
	# Get spawn point from start chunk
	var spawn_point = start_chunk.get_node_or_null("SpawnPoint")
	if spawn_point == null:
		push_error("No spawn point found in start chunk")
		return
	print("Found spawn point in start chunk")
	
	# Get player scene
	var player_scene = preload("res://player/player.tscn")
	if player_scene == null:
		push_error("Failed to load player scene")
		return
	print("Player scene loaded successfully")
	
	# Create player instance
	var player = player_scene.instantiate()
	if player == null:
		push_error("Failed to instantiate player scene")
		return
	print("Player instance created successfully")
	
	# Add player to scene
	add_child(player)
	print("Player added to scene tree")
	
	# Position player at spawn point
	player.global_position = spawn_point.global_position
	print("Player positioned at: ", player.global_position)
	
	# Enable player camera
	var camera = player.get_node_or_null("Camera2D")
	if camera != null:
		camera.enabled = true
		print("Player camera enabled")
	else:
		push_warning("No camera found in player scene")
	
	# Ensure player is in the correct group for enemies to find it
	if not player.is_in_group("player"):
		player.add_to_group("player")
		print("Added player to 'player' group")
	
	print("Player spawn completed successfully")

func is_valid_direction(dir: int) -> bool:
	return dir >= 0 and dir < 4  # Since we have 4 directions (LEFT=0, RIGHT=1, UP=2, DOWN=3)

func get_direction_between(from: Vector2i, to: Vector2i) -> Direction:
	var diff = to - from
	if diff.x > 0:
		return Direction.RIGHT
	elif diff.x < 0:
		return Direction.LEFT
	elif diff.y > 0:
		return Direction.DOWN
	elif diff.y < 0:
		return Direction.UP
	return Direction.RIGHT  # fallback

func setup_level_transitions() -> void:
	print("\nSetting up level transitions...")
	
	# Handle start zones
	for i in range(start_positions.size()):
		var start_pos = start_positions[i]
		print("Setting up start zone at position:", start_pos)
		
		if grid[start_pos.x][start_pos.y].chunk:
			print("Found start chunk, setting up start zone")
			var start_zone = get_node_or_null("StartZone" + str(i))
			
			if not start_zone:
				# Only create if it doesn't exist
				print("Creating new start zone")
				start_zone = preload("res://scenes/level_transition_zone.tscn").instantiate()
				start_zone.name = "StartZone" + str(i)
				start_zone.zone_type = "Start"
				start_zone.player_entered.connect(_on_zone_entered)
				add_child(start_zone)
			
			# Move existing or new start zone to correct position
			start_zone.reparent(grid[start_pos.x][start_pos.y].chunk)
			start_zone.position = Vector2(200, 400)
			print("Start zone positioned at:", start_zone.position)
		else:
			print("WARNING: Start chunk not found at position", start_pos)
	
	# Handle finish zones
	for i in range(finish_positions.size()):
		var finish_pos = finish_positions[i]
		print("Setting up finish zone at position:", finish_pos)
		
		if grid[finish_pos.x][finish_pos.y].chunk:
			print("Found finish chunk, setting up finish zone")
			var finish_zone = get_node_or_null("FinishZone" + str(i))
			
			if not finish_zone:
				# Only create if it doesn't exist
				print("Creating new finish zone")
				finish_zone = preload("res://scenes/level_transition_zone.tscn").instantiate()
				finish_zone.name = "FinishZone" + str(i)
				finish_zone.zone_type = "Finish"
				finish_zone.player_entered.connect(_on_zone_entered)
				add_child(finish_zone)
			
			# Move existing or new finish zone to correct position
			finish_zone.reparent(grid[finish_pos.x][finish_pos.y].chunk)
			finish_zone.position = Vector2(1400, 400)  # Changed to x=1400
			print("Finish zone positioned at:", finish_zone.position)
		else:
			print("ERROR: No chunk found at finish position", finish_pos)

func _on_zone_entered(zone_type: String) -> void:
	if is_transitioning:
		return
		
	print("Zone entered: ", zone_type)
	
	# Add cooldown check to prevent duplicate signals
	var current_time = Time.get_ticks_msec()
	if not has_meta("last_zone_time") or current_time - get_meta("last_zone_time") > 1000:
		set_meta("last_zone_time", current_time)
		
	if zone_type == "Start":
		print("Emitting level_started signal")
		level_started.emit()
	elif zone_type == "Finish":
		print("Emitting level_completed signal")
		is_transitioning = true
		level_completed.emit()
		current_level += 1
		
		var start_time = Time.get_ticks_msec()
		print("Starting level generation...")
		
		generate_level()
		
		var end_time = Time.get_ticks_msec()
		print("Level generation completed in ", (end_time - start_time) / 1000.0, " seconds")
	
	# Reset transition flag after cooldown
	var timer = get_tree().create_timer(transition_cooldown)
	timer.timeout.connect(func(): is_transitioning = false)

func validate_all_connections() -> bool:
	print("\nValidating all chunk connections...")
	
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].chunk:
				var chunk_type = get_chunk_type(grid[x][y].chunk)
				if not chunk_type.is_empty():
					if not validate_connections(pos, chunk_type):
						print("Connection validation failed at position ", pos)
						return false
	
	print("All connections validated successfully!")
	return true

func select_next_direction(current_pos: Vector2i, last_direction: int, consecutive_same_direction: int, vertical_moves: int, horizontal_moves: int) -> int:
	# Calculate movement ratio
	var total_moves = vertical_moves + horizontal_moves
	var vertical_ratio = 0.0
	if total_moves > 0:
		vertical_ratio = float(vertical_moves) / total_moves
	
	# Define direction weights
	var weights = {
		Direction.LEFT: 0.0,  # Never go left in main path
		Direction.RIGHT: 1.0,
		Direction.UP: 0.5,
		Direction.DOWN: 0.5
	}
	
	# Adjust weights based on current state
	if consecutive_same_direction >= max_consecutive_same_direction:
		# Reduce weight of current direction
		weights[last_direction] *= 0.5
	
	# Adjust vertical movement weights based on ratio
	if vertical_ratio < 0.3:  # Too few vertical moves
		weights[Direction.UP] *= 1.5
		weights[Direction.DOWN] *= 1.5
	elif vertical_ratio > 0.7:  # Too many vertical moves
		weights[Direction.RIGHT] *= 1.5
	
	# Adjust weights based on position
	if current_pos.y < 2:  # Near top
		weights[Direction.UP] *= 0.5
	if current_pos.y > GRID_HEIGHT - 3:  # Near bottom
		weights[Direction.DOWN] *= 0.5
	
	# Select direction based on weights
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_sum = 0.0
	
	for direction in weights.keys():
		current_sum += weights[direction]
		if random_value <= current_sum:
			return direction
	
	return Direction.RIGHT  # Default to right if something goes wrong

func would_create_diagonal(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	# Check if the move would create a diagonal connection
	var dx = to_pos.x - from_pos.x
	var dy = to_pos.y - from_pos.y
	
	# If both x and y change, it's a diagonal move
	return abs(dx) > 0 and abs(dy) > 0

func get_direction_name(direction: int) -> String:
	match direction:
		Direction.LEFT: return "left"
		Direction.RIGHT: return "right"
		Direction.UP: return "up"
		Direction.DOWN: return "down"
		_: return "unknown"

func get_direction_vector(direction: int) -> Vector2i:
	match direction:
		Direction.LEFT: return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
		Direction.UP: return Vector2i(0, -1)
		Direction.DOWN: return Vector2i(0, 1)
		_: return Vector2i(1, 0)  # Default to right

func initialize_grid() -> void:
	grid.clear()
	for x in range(current_grid_width):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(GridCell.new())
