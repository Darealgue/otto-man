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
const CHUNK_SIZE = Vector2(1920, 1088)  # Updated height to be divisible by 16
const GRID_SPACING = Vector2(1920, 1088)  # Updated spacing to match chunk size
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
		"scenes": ["res://chunks/dungeon/special/start_chunk.tscn"],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"finish": {
		"scenes": ["res://chunks/dungeon/special/finish_chunk.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"basic": {
		"scenes": [
			"res://chunks/dungeon/basic/basic_platform.tscn",
			"res://chunks/dungeon/basic/basic_platform1.tscn",
			"res://chunks/dungeon/basic/basic_platform2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"combat": {
		"scenes": ["res://chunks/dungeon/special/combat_arena.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"corner_right_down": {
		"scenes": [
			"res://chunks/dungeon/hub/l_corner_right_down.tscn",
			"res://chunks/dungeon/hub/l_corner_right_down1.tscn",
			"res://chunks/dungeon/hub/l_corner_right_down2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"corner_left_up": {
		"scenes": [
			"res://chunks/dungeon/hub/l_corner_left_up.tscn",
			"res://chunks/dungeon/hub/l_corner_left_up1.tscn",
			"res://chunks/dungeon/hub/l_corner_left_up2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"corner_left_down": {
		"scenes": [
			"res://chunks/dungeon/hub/l_corner_left_down.tscn",
			"res://chunks/dungeon/hub/l_corner_left_down1.tscn",
			"res://chunks/dungeon/hub/l_corner_left_down2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"corner_right_up": {
		"scenes": [
			"res://chunks/dungeon/hub/l_corner_right_up.tscn",
			"res://chunks/dungeon/hub/l_corner_right_up1.tscn",
			"res://chunks/dungeon/hub/l_corner_right_up2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"t_junction_right": {
		"scenes": [
			"res://chunks/dungeon/hub/t_junction_right.tscn",
			"res://chunks/dungeon/hub/t_junction_right1.tscn",
			"res://chunks/dungeon/hub/t_junction_right2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_left": {
		"scenes": [
			"res://chunks/dungeon/hub/t_junction_left.tscn",
			"res://chunks/dungeon/hub/t_junction_left1.tscn",
			"res://chunks/dungeon/hub/t_junction_left2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_up": {
		"scenes": [
			"res://chunks/dungeon/hub/t_junction_up.tscn",
			"res://chunks/dungeon/hub/t_junction_up1.tscn",
			"res://chunks/dungeon/hub/t_junction_up2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"t_junction_down": {
		"scenes": [
			"res://chunks/dungeon/hub/t_junction_down.tscn",
			"res://chunks/dungeon/hub/t_junction_down1.tscn",
			"res://chunks/dungeon/hub/t_junction_down2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"four_way_hub": {
		"scenes": [
			"res://chunks/dungeon/hub/four_way_hub.tscn",
			"res://chunks/dungeon/hub/four_way_hub1.tscn",
			"res://chunks/dungeon/hub/four_way_hub2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"vertical": {
		"scenes": [
			"res://chunks/dungeon/vertical/climbing_tower.tscn",
			"res://chunks/dungeon/vertical/climbing_tower1.tscn",
			"res://chunks/dungeon/vertical/climbing_tower2.tscn"
		],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"dead_end_up": {
		"scenes": ["res://chunks/dungeon/special/dead_end_up.tscn"],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
		}
	},
	"dead_end_down": {
		"scenes": ["res://chunks/dungeon/special/dead_end_down.tscn"],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.OPEN
		}
	},
	"dead_end_left": {
		"scenes": ["res://chunks/dungeon/special/dead_end_left.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"dead_end_right": {
		"scenes": ["res://chunks/dungeon/special/dead_end_right.tscn"],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"treasure_room": {
		"scenes": ["res://chunks/dungeon/special/treasure_room.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"challenge_room": {
		"scenes": ["res://chunks/dungeon/special/challenge_room.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"boss_arena": {
		"scenes": ["res://chunks/dungeon/special/boss_arena.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	},
	"full": {
		"scenes": ["res://chunks/dungeon/special/full.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
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

@export var current_level: int = 1  # Current level number
@export var level_config: LevelConfig  # Reference to our dungeon configuration resource

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

var unified_terrain: UnifiedTerrain

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
	is_overview_active = true  # Start with overview camera
	setup_camera()
	generate_level()
	setup_level_transitions()

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
	
	# Remove unified terrain if it exists
	if unified_terrain:
		unified_terrain.queue_free()
		unified_terrain = null
	
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

func generate_level() -> void:
	print("\nStarting level generation...")
	
	if not level_config:
		push_error("Level configuration not set!")
		return
	
	# Clear previous level first
	clear_level()
	
	# Update grid dimensions based on level
	current_grid_width = level_config.get_length_for_level(current_level)
	
	# Initialize grid
	grid = []
	for x in range(current_grid_width):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(GridCell.new())
	
	print("Level ", current_level, " - Grid size: ", current_grid_width, "x", GRID_HEIGHT)
	
	# Make multiple attempts to generate a valid level if needed
	var max_attempts = 3
	var attempt = 0
	
	while attempt < max_attempts:
		if generate_layout():
			if populate_chunks():
				# Verify if there's a valid path from start to finish
				if verify_level_path():
					print("Level generated successfully!")
					unify_terrain()  # New step
					setup_level_transitions()
					spawn_player()
					return
				else:
					print("No valid path from start to finish, retrying...")
		
		print("Attempt ", attempt+1, " failed, retrying...")
		attempt += 1
		
		# Clear the grid for a new attempt
		for x in range(current_grid_width):
			for y in range(GRID_HEIGHT):
				grid[x][y] = GridCell.new()
	
	print("Failed to generate level after ", max_attempts, " attempts!")

# Verify there is a valid path from start to finish
func verify_level_path() -> bool:
	print("Verifying path from start to finish...")
	
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	
	# Find finish position
	var finish_pos = Vector2i.ZERO
	for x in range(current_grid_width - 1, -1, -1):
		for y in range(GRID_HEIGHT):
			if grid[x][y].chunk and grid[x][y].chunk.scene_file_path.contains("finish_chunk"):
				finish_pos = Vector2i(x, y)
				break
		if finish_pos != Vector2i.ZERO:
			break
	
	if finish_pos == Vector2i.ZERO:
		print("Finish chunk not found!")
		return false
	
	print("Start position:", start_pos)
	print("Finish position:", finish_pos)
	
	# Do a BFS to find a path from start to finish
	var queue = [start_pos]
	var visited = {}
	visited[start_pos] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Check if we've reached the finish
		if current == finish_pos:
			print("Valid path found from start to finish!")
			return true
		
		# Add all connected neighbors
		for dir in Direction.values():
			if grid[current.x][current.y].connections[dir]:
				var next_pos = current + DIRECTION_VECTORS[dir]
				
				if is_valid_position(next_pos) and not visited.has(next_pos):
					# Verify the connection is two-way (neighbor connects back)
					var opposite_dir = get_opposite_direction(dir)
					if grid[next_pos.x][next_pos.y].connections[opposite_dir]:
						queue.append(next_pos)
						visited[next_pos] = true
	
	print("No valid path found from start to finish!")
	return false

func generate_layout() -> bool:
	print("\nPhase 1: Generating abstract layout...")
	
	# Get level-specific values
	var num_branches = level_config.get_num_branches_for_level(current_level)
	var num_dead_ends = level_config.get_num_dead_ends_for_level(current_level)
	var num_main_paths = level_config.get_num_main_paths_for_level(current_level)
	
	# Initialize path generator
	var path_gen = PathGenerator.new(current_grid_width, GRID_HEIGHT)
	
	# Set start position
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	
	# Set up start position with proper connections
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	# Make sure to explicitly set all connections for the start chunk - only RIGHT connection
	for dir in Direction.values():
		grid[start_pos.x][start_pos.y].connections[dir] = (dir == Direction.RIGHT)
	
	# Randomize finish position with more vertical variation
	var finish_y = GRID_HEIGHT / 2 + (randi() % 5 - 2)  # -2 to +2 from center
	var finish_pos = Vector2i(current_grid_width - 2, finish_y)
	
	# Set up finish position with proper connections
	grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
	grid[finish_pos.x][finish_pos.y].visited = true
	# Set finish chunk connections (only left connection)
	for dir in Direction.values():
		grid[finish_pos.x][finish_pos.y].connections[dir] = (dir == Direction.LEFT)
	
	# Ensure the cell before finish has a right connection
	var pre_finish_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(pre_finish_pos):
		grid[pre_finish_pos.x][pre_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[pre_finish_pos.x][pre_finish_pos.y].visited = true
		grid[pre_finish_pos.x][pre_finish_pos.y].connections[Direction.RIGHT] = true
		grid[pre_finish_pos.x][pre_finish_pos.y].connections[Direction.LEFT] = false
		grid[pre_finish_pos.x][pre_finish_pos.y].connections[Direction.UP] = false
		grid[pre_finish_pos.x][pre_finish_pos.y].connections[Direction.DOWN] = false
	
	var all_paths = []
	
	# Generate first main path (always from start)
	var first_path = generate_main_path(start_pos, finish_pos, path_gen)
	if first_path.is_empty():
		return false
	all_paths.append(first_path)
	
	# Generate additional main paths if needed
	for i in range(1, num_main_paths):
		# Find a suitable starting point from the first path
		var branch_point = find_suitable_branch_point(first_path)
		if branch_point == null:
			continue
			
		# Generate a new finish position with more vertical variation
		var new_finish_x = current_grid_width - 2 - (i * 2)  # Space paths apart
		var new_finish_y = GRID_HEIGHT / 2 + (randi() % 5 - 2)  # More vertical variation
		var new_finish_pos = Vector2i(new_finish_x, new_finish_y)
		
		# Set up connections for the new finish position
		grid[new_finish_pos.x][new_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[new_finish_pos.x][new_finish_pos.y].visited = true
		for dir in Direction.values():
			grid[new_finish_pos.x][new_finish_pos.y].connections[dir] = (dir == Direction.LEFT)
		
		# Ensure the cell before new finish has a right connection
		var pre_new_finish_pos = Vector2i(new_finish_pos.x - 1, new_finish_pos.y)
		if is_valid_position(pre_new_finish_pos):
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].cell_type = CellType.MAIN_PATH
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited = true
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].connections[Direction.RIGHT] = true
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].connections[Direction.LEFT] = false
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].connections[Direction.UP] = false
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].connections[Direction.DOWN] = false
		
		# Generate new path
		var new_path = generate_main_path(branch_point, new_finish_pos, path_gen)
		if not new_path.is_empty():
			all_paths.append(new_path)
	
	# Create branch points and generate branches
	for main_path in all_paths:
		# Create branch points every 4 chunks along the main path, but not in the last third
		var branch_start_positions = []
		var last_third_start = main_path.size() * 2 / 3
		for i in range(2, last_third_start, 4):
			branch_start_positions.append(main_path[i])
		
		# Generate branches from each branch point
		for branch_start in branch_start_positions:
			generate_branch(branch_start, all_paths)
	
	# Add dead ends
	for _i in range(num_dead_ends):
		add_dead_end(all_paths)
	
	return true

func find_suitable_branch_point(main_path: Array) -> Vector2i:
	# Look for a point in the first third of the path that can support a new connection
	var search_range = main_path.size() / 3
	for i in range(1, search_range):
		var pos = main_path[i]
		# Check if this position can support a new connection
		var available_dirs = []
		for dir in Direction.values():
			var next_pos = pos + DIRECTION_VECTORS[dir]
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				continue
			available_dirs.append(dir)
		
		if not available_dirs.is_empty():
			return pos
	
	# If no suitable point found, return the first valid position from the path
	if not main_path.is_empty():
		return main_path[0]
	
	# If path is empty, return a default position
	return Vector2i(2, GRID_HEIGHT / 2)

func generate_main_path(start_pos: Vector2i, finish_pos: Vector2i, path_gen: PathGenerator) -> Array:
	var path_points = []
	var waypoints = []
	waypoints.append(start_pos)
	
	# Always include the position to the right of start in the path,
	# and ensure at least one connection from that position to continue the path
	var right_of_start = Vector2i(start_pos.x + 1, start_pos.y)
	if is_valid_position(right_of_start) and right_of_start != waypoints[-1]:
		waypoints.append(right_of_start)
		
		# Get the possible directions to continue from right_of_start
		var continue_directions = []
		var possible_dirs = [Direction.RIGHT, Direction.UP, Direction.DOWN]
		
		for dir in possible_dirs:
			var next_pos = right_of_start + DIRECTION_VECTORS[dir]
			if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
				continue_directions.append(dir)
		
		# If there are possible directions to continue, pick one
		if not continue_directions.is_empty():
			var chosen_dir = continue_directions[randi() % continue_directions.size()]
			var next_pos = right_of_start + DIRECTION_VECTORS[chosen_dir]
			
			# Set up connections between right_of_start and next_pos
			if not waypoints.has(next_pos):
				waypoints.append(next_pos)
	
	# Add more intermediate waypoints for a more winding path
	var num_waypoints = randi() % 3 + 3  # 3-5 waypoints
	for i in range(num_waypoints):
		var x = start_pos.x + ((i + 1) * (finish_pos.x - start_pos.x)) / (num_waypoints + 1)
		# Add more vertical variation
		var y = GRID_HEIGHT / 2 + (randi() % 5 - 2)  # -2 to +2 vertical variation
		waypoints.append(Vector2i(x, y))
	
	# Ensure path returns to finish height gradually
	var last_waypoint = waypoints[-1]
	if abs(last_waypoint.y - finish_pos.y) > 0:
		var pre_finish = Vector2i(finish_pos.x - 2, finish_pos.y)
		waypoints.append(pre_finish)
	waypoints.append(finish_pos)
	
	# Generate path through waypoints
	for i in range(waypoints.size() - 1):
		var path_segment = path_gen.astar.get_point_path(
			path_gen._get_point_index(waypoints[i]),
			path_gen._get_point_index(waypoints[i + 1])
		)
		
		for j in range(path_segment.size() - (1 if i < waypoints.size() - 2 else 0)):
			var grid_pos = Vector2i(path_segment[j].x, path_segment[j].y)
			path_points.append(grid_pos)
			grid[grid_pos.x][grid_pos.y].cell_type = CellType.MAIN_PATH
			grid[grid_pos.x][grid_pos.y].visited = true
	
	# Set connections for the path
	for i in range(path_points.size()):
		var current = path_points[i]
		
		# Special handling for the start position - only allow RIGHT connection
		if current == Vector2i(0, GRID_HEIGHT / 2):  # Start position
			# Only maintain the RIGHT connection for start chunk
			for dir in Direction.values():
				grid[current.x][current.y].connections[dir] = (dir == Direction.RIGHT)
			continue
		
		if i > 0:  # Connect to previous
			var prev = path_points[i - 1]
			var dir = get_direction_between(prev, current)
			if is_valid_direction(dir) and is_valid_connection(prev, current, dir):
				grid[current.x][current.y].connections[get_opposite_direction(dir)] = true
				grid[prev.x][prev.y].connections[dir] = true
		
		if i < path_points.size() - 1:  # Connect to next
			var next = path_points[i + 1]
			var dir = get_direction_between(current, next)
			if is_valid_direction(dir) and is_valid_connection(current, next, dir):
				grid[current.x][current.y].connections[dir] = true
				grid[next.x][next.y].connections[get_opposite_direction(dir)] = true
	
	# Ensure finish chunk has proper connection
	if path_points.size() > 0:
		var last_path_point = path_points[-1]
		var dir_to_finish = get_direction_between(last_path_point, finish_pos)
		if is_valid_direction(dir_to_finish):
			# Clear all connections for the last path point
			for dir in Direction.values():
				grid[last_path_point.x][last_path_point.y].connections[dir] = false
			# Set only the connection to finish
			grid[last_path_point.x][last_path_point.y].connections[dir_to_finish] = true
			
			# Clear all connections for finish position
			for dir in Direction.values():
				grid[finish_pos.x][finish_pos.y].connections[dir] = false
			# Set only the connection from finish to last path point
			grid[finish_pos.x][finish_pos.y].connections[get_opposite_direction(dir_to_finish)] = true
	
	return path_points

func populate_chunks() -> bool:
	print("\nPhase 2: Populating with actual chunks...")
	
	# 1. Place start chunk first
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	if not place_chunk(start_pos, "start"):
		print("Failed to place start chunk")
		return false
	
	print("\nStart chunk connections:")
	print("RIGHT connection:", grid[start_pos.x][start_pos.y].connections[Direction.RIGHT])
	
	# Ensure no illegal connections to start chunk
	for dir in Direction.values():
		if dir != Direction.RIGHT:
			var neighbor_pos = start_pos + DIRECTION_VECTORS[dir]
			if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].visited:
				# Remove any connection to start chunk in this direction
				grid[neighbor_pos.x][neighbor_pos.y].connections[get_opposite_direction(dir)] = false
	
	# Ensure there's at least a path out of the start chunk
	var right_of_start = Vector2i(start_pos.x + 1, start_pos.y)
	if is_valid_position(right_of_start):
		print("\nProcessing chunk to the right of start:")
		print("Position right of start:", right_of_start)
		
		# Mark as visited and part of main path if not already
		if not grid[right_of_start.x][right_of_start.y].visited:
			grid[right_of_start.x][right_of_start.y].visited = true
			grid[right_of_start.x][right_of_start.y].cell_type = CellType.MAIN_PATH
			print("Marked as visited and part of main path")
		
		# Make sure it connects to the start chunk (the only mandatory connection)
		grid[right_of_start.x][right_of_start.y].connections[Direction.LEFT] = true
		print("Set LEFT connection to true")
		
		# Don't enforce other connections - let the level generator decide
		print("Current connections:", grid[right_of_start.x][right_of_start.y].connections)
		
		# Choose appropriate chunk type based on the connections
		var cell = grid[right_of_start.x][right_of_start.y]
		var chunk_type = select_appropriate_chunk(right_of_start, cell)
		
		if chunk_type.is_empty():
			print("No suitable chunk type found, defaulting to basic")
			chunk_type = "basic"
		
		# Place the appropriate chunk
		if not place_chunk(right_of_start, chunk_type):
			print("Failed to place chunk right of start")
			return false
		
		print("Successfully placed chunk right of start:", chunk_type)
		
		# Verify connections after placement
		print("After chunk placement:")
		print("Connections right of start: [LEFT:", grid[right_of_start.x][right_of_start.y].connections[Direction.LEFT], 
			  ", RIGHT:", grid[right_of_start.x][right_of_start.y].connections[Direction.RIGHT], 
			  ", UP:", grid[right_of_start.x][right_of_start.y].connections[Direction.UP], 
			  ", DOWN:", grid[right_of_start.x][right_of_start.y].connections[Direction.DOWN], "]")
	
	# 2. Find and place finish chunk
	var finish_pos = Vector2i.ZERO
	for x in range(current_grid_width - 1, -1, -1):
		for y in range(GRID_HEIGHT):
			if grid[x][y].cell_type == CellType.MAIN_PATH:
				finish_pos = Vector2i(x, y)
				break
		if finish_pos != Vector2i.ZERO:
			break
	
	if finish_pos == Vector2i.ZERO:
		print("Failed to find finish position")
		return false
		
	if not place_chunk(finish_pos, "finish"):
		print("Failed to place finish chunk")
		return false
		
	# 3. Place main path chunks
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].visited and not grid[x][y].chunk and grid[x][y].cell_type == CellType.MAIN_PATH:
				var cell = grid[x][y]
				var chunk_type = select_appropriate_chunk(pos, cell)
				if chunk_type.is_empty() or not place_chunk(pos, chunk_type):
					print("Failed to place main path chunk at ", pos)
					return false
	
	# 4. Place branch points and branch paths
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].visited and not grid[x][y].chunk and \
			   (grid[x][y].cell_type == CellType.BRANCH_POINT or grid[x][y].cell_type == CellType.BRANCH_PATH):
				var cell = grid[x][y]
				var chunk_type = select_appropriate_chunk(pos, cell)
				if chunk_type.is_empty() or not place_chunk(pos, chunk_type):
					print("Failed to place branch chunk at ", pos)
					return false
	
	# 5. Place dead ends
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].visited and not grid[x][y].chunk and grid[x][y].cell_type == CellType.DEAD_END:
				var cell = grid[x][y]
				
				# Find the single required connection
				var connection_dir = -1
				var connection_count = 0
				for dir in Direction.values():
					if cell.connections[dir]:
						connection_dir = dir
						connection_count += 1
				
				# Dead ends should only have one connection
				if connection_count != 1:
					print("Dead end at ", pos, " has incorrect number of connections: ", connection_count)
					continue
				
				# Select appropriate dead end based on connection direction
				var chunk_type = ""
				match connection_dir:
					Direction.LEFT:
						chunk_type = "dead_end_right"  # LEFT connection needed, use dead end with RIGHT port closed
					Direction.RIGHT:
						chunk_type = "dead_end_left"   # RIGHT connection needed, use dead end with LEFT port closed
					Direction.UP:
						chunk_type = "dead_end_down"   # UP connection needed, use dead end with DOWN port closed
					Direction.DOWN:
						chunk_type = "dead_end_up"     # DOWN connection needed, use dead end with UP port closed
					_:
						print("Invalid connection direction for dead end at ", pos)
						continue
				
				# Check if the connection is valid with neighboring chunk
				var check_pos = pos + DIRECTION_VECTORS[connection_dir]
				if is_valid_position(check_pos) and grid[check_pos.x][check_pos.y].chunk:
					var neighbor_type = get_chunk_type(grid[check_pos.x][check_pos.y].chunk)
					if not neighbor_type.is_empty():
						var neighbor_ports = CHUNKS[neighbor_type]["ports"]
						var opposite_dir = get_opposite_direction(connection_dir)
						
						# For vertical connections, ensure proper port alignment
						if connection_dir == Direction.UP or connection_dir == Direction.DOWN:
							if neighbor_ports[opposite_dir] != Port.OPEN:
								print("Cannot connect dead end at ", pos, " to neighbor in direction ", connection_dir)
								continue
						else:
							# For horizontal connections, check as before
							if neighbor_ports[opposite_dir] != Port.OPEN:
								print("Cannot connect dead end at ", pos, " to neighbor in direction ", connection_dir)
								continue
				
				if not place_chunk(pos, chunk_type):
					print("Failed to place dead end at ", pos)
					continue  # Skip this dead end and try others
	
	# 6. Ensure finish chunk is properly connected
	var last_path_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(last_path_pos) and grid[last_path_pos.x][last_path_pos.y].chunk:
		# Set up connection between last path chunk and finish chunk
		grid[last_path_pos.x][last_path_pos.y].connections[Direction.RIGHT] = true
		grid[finish_pos.x][finish_pos.y].connections[Direction.LEFT] = true
		
		# Update the chunks to reflect the connection
		var last_chunk = grid[last_path_pos.x][last_path_pos.y].chunk
		var finish_chunk = grid[finish_pos.x][finish_pos.y].chunk
		
		# Ensure the chunks are properly connected
		if last_chunk and finish_chunk:
			print("Connecting finish chunk to last path chunk")
	
	return true  # Return true if we've made it through all placements

func select_appropriate_chunk(pos: Vector2i, cell: GridCell) -> String:
	# Special case for start position - always return "start"
	if pos == Vector2i(0, GRID_HEIGHT / 2):
		return "start"
	
	# Special case for the position right after start - we need to be more flexible
	if pos == Vector2i(1, GRID_HEIGHT / 2):
		# Make sure it connects to start from LEFT
		cell.connections[Direction.LEFT] = true
		
		# We don't enforce RIGHT connection anymore, but respect what the level generator decided
		# Just get the required connections from the cell
		var required_connections = [false, false, false, false]  # [LEFT, RIGHT, UP, DOWN]
		
		# First check existing connections in the grid cell
		for dir in Direction.values():
			if cell.connections[dir]:
				required_connections[dir] = true
		
		print("Right-of-start required connections: ", required_connections)
		
		# Count how many connections are required
		var connection_count = 0
		for required in required_connections:
			if required:
				connection_count += 1
		
		# Select an appropriate chunk type based on the connections
		# Handle different connection counts
		if connection_count == 1:  # Only LEFT connection
			return "dead_end_right"
		elif connection_count == 2:
			if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT]:
				return "basic" if randf() < 0.7 else "combat"
			elif required_connections[Direction.LEFT] and required_connections[Direction.UP]:
				return "corner_left_up"
			elif required_connections[Direction.LEFT] and required_connections[Direction.DOWN]:
				return "corner_left_down"
		elif connection_count == 3:
			if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and required_connections[Direction.UP]:
				return "t_junction_down"
			elif required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and required_connections[Direction.DOWN]:
				return "t_junction_up"
			elif required_connections[Direction.LEFT] and required_connections[Direction.UP] and required_connections[Direction.DOWN]:
				return "t_junction_right"
		elif connection_count == 4:
			return "four_way_hub"
		
		# If no specific match, default to basic horizontal path
		return "basic"
	
	# Get required connections based on surrounding cells
	var required_connections = [false, false, false, false]  # [LEFT, RIGHT, UP, DOWN]
	
	# First check existing connections in the grid cell
	for dir in Direction.values():
		if cell.connections[dir]:
			required_connections[dir] = true
			
			# Extra check: if this is connecting to the start chunk in a direction other than LEFT,
			# set this connection to false to prevent unwanted connections
			var next_pos = pos + DIRECTION_VECTORS[dir]
			if next_pos == Vector2i(0, GRID_HEIGHT / 2) and dir != Direction.LEFT:
				required_connections[dir] = false
				cell.connections[dir] = false
	
	print("Required connections: ", required_connections)
	
	# Count total required connections
	var connection_count = 0
	for required in required_connections:
		if required:
			connection_count += 1
	
	# Handle four-connection case first (four-way hub)
	if connection_count == 4:
		return "four_way_hub"
	
	# Handle single connection case (dead ends)
	if connection_count == 1:
		if required_connections[Direction.LEFT]:
			return "dead_end_right"
		if required_connections[Direction.RIGHT]:
			return "dead_end_left"
		if required_connections[Direction.UP]:
			return "dead_end_down"
		if required_connections[Direction.DOWN]:
			return "dead_end_up"
	
	# Handle two-connection cases with corners
	if connection_count == 2:
		if required_connections[Direction.RIGHT] and required_connections[Direction.UP]:
			return "corner_right_up"
		if required_connections[Direction.RIGHT] and required_connections[Direction.DOWN]:
			return "corner_right_down"
		if required_connections[Direction.LEFT] and required_connections[Direction.UP]:
			return "corner_left_up"
		if required_connections[Direction.LEFT] and required_connections[Direction.DOWN]:
			return "corner_left_down"
		if required_connections[Direction.UP] and required_connections[Direction.DOWN]:
			return "vertical"
		if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT]:
			return "basic" if randf() < 0.7 else "combat"  # Favor basic platforms slightly more
	
	# Handle three-connection cases (T-junctions)
	if connection_count == 3:
		var t_junctions = []
		if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and required_connections[Direction.UP]:
			t_junctions.append("t_junction_down")   # DOWN is closed, others open
		if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and required_connections[Direction.DOWN]:
			t_junctions.append("t_junction_up")     # UP is closed, others open
		if required_connections[Direction.LEFT] and required_connections[Direction.UP] and required_connections[Direction.DOWN]:
			t_junctions.append("t_junction_right")  # RIGHT is closed, others open
		if required_connections[Direction.RIGHT] and required_connections[Direction.UP] and required_connections[Direction.DOWN]:
			t_junctions.append("t_junction_left")   # LEFT is closed, others open
		
		# If we have valid T-junctions, randomly select one
		if not t_junctions.is_empty():
			# Add some randomness to prefer different directions
			var rand = randf()
			if rand < 0.4:  # 40% chance to use a vertical junction (up/down)
				var vertical_junctions = t_junctions.filter(func(j): return j in ["t_junction_up", "t_junction_down"])
				if not vertical_junctions.is_empty():
					return vertical_junctions[randi() % vertical_junctions.size()]
			elif rand < 0.7:  # 30% chance to use a horizontal junction (left/right)
				var horizontal_junctions = t_junctions.filter(func(j): return j in ["t_junction_left", "t_junction_right"])
				if not horizontal_junctions.is_empty():
					return horizontal_junctions[randi() % horizontal_junctions.size()]
			
			# If preferred direction not found or remaining 30% chance, use any valid junction
			return t_junctions[randi() % t_junctions.size()]
	
	# For any other case, find a chunk that matches the required connections exactly
	var valid_chunks = []
	for chunk_type in CHUNKS:
		# Skip special chunks (handled separately)
		if chunk_type in ["start", "finish"]:
			continue
		
		# Ensure chunk type exists in both dictionaries
		if not CHUNK_WEIGHTS.has(chunk_type):
			continue
			
		var ports = CHUNKS[chunk_type]["ports"]
		var is_valid = true
		
		# Check each direction
		for dir in Direction.values():
			# If a connection is required, the port must be open
			if required_connections[dir] and ports[dir] != Port.OPEN:
					is_valid = false
					break
		
		if is_valid:
			valid_chunks.append(chunk_type)
	
	print("Valid chunks: ", valid_chunks)
	
	# If no valid chunks found, return empty string
	if valid_chunks.is_empty():
		return ""

	# Use weighted selection
	var total_weight = 0
	for chunk in valid_chunks:
		total_weight += CHUNK_WEIGHTS[chunk]
	
	var random_weight = randi() % total_weight
	var current_weight = 0
	
	for chunk in valid_chunks:
		current_weight += CHUNK_WEIGHTS[chunk]
		if random_weight < current_weight:
			return chunk
	
	return valid_chunks[0]  # Fallback

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
	print("\nAttempting to place chunk:" + chunk_type + "at position:" + str(pos))
	
	if not CHUNKS.has(chunk_type):
		print("Invalid chunk type:", chunk_type)
		return false
	
	var chunk_data = CHUNKS[chunk_type]
	var scene_path = chunk_data["scenes"][randi() % chunk_data["scenes"].size()]
	var chunk_scene = load(scene_path)
	
	if not chunk_scene:
		print("Failed to load chunk scene:", scene_path)
		return false
	
	var chunk = chunk_scene.instantiate()
	if not chunk:
		print("Failed to instantiate chunk:", chunk_type)
		return false
	
	# Suppress tilemap errors by disabling error printing temporarily
	var prev_error_prints = ProjectSettings.get_setting("debug/settings/gdscript/warnings/unassigned_variable_op_assign", true)
	ProjectSettings.set_setting("debug/settings/gdscript/warnings/unassigned_variable_op_assign", false)
	
	add_child(chunk)
	chunk.position = grid_to_world(pos)
	
	# Restore error printing
	ProjectSettings.set_setting("debug/settings/gdscript/warnings/unassigned_variable_op_assign", prev_error_prints)
	
	grid[pos.x][pos.y].chunk = chunk
	
	print("Successfully placed", chunk_type, "at", pos)
	return true

func get_chunk_type(chunk: Node) -> String:
	if not chunk:
		return ""
	
	for type in CHUNKS:
		if chunk.scene_file_path == CHUNKS[type]["scenes"][0]:
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
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var start_chunk = grid[start_pos.x][start_pos.y].chunk
	
	if start_chunk:
		var player = get_node_or_null("Player")
		
		if not player:
			# Only create a new player if one doesn't exist
			var player_scene = load("res://player/player.tscn")
			if player_scene:
				player = player_scene.instantiate()
				player.name = "Player"
				add_child(player)
		else:
			# If player exists, move it to the top of the scene tree
			remove_child(player)
			add_child(player)
		
		# Move existing or new player to start position
		player.position = start_chunk.position + Vector2(200, 400)
		print("Player moved to:", player.position)
		
		# Set up player camera
		if player.has_node("Camera2D"):
			var player_camera = player.get_node("Camera2D")
			player_camera.enabled = true
			
			if not is_overview_active:
				player_camera.make_current()
			else:
				overview_camera.make_current()

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
	
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	# Find the actual finish chunk position - should be at (current_grid_width - 2, y)
	var finish_pos = Vector2i.ZERO
	var finish_found = false
	
	# Search for finish chunk
	for x in range(current_grid_width - 1, -1, -1):
		for y in range(GRID_HEIGHT):
			if grid[x][y].chunk and grid[x][y].chunk.scene_file_path.contains("finish_chunk"):
				finish_pos = Vector2i(x, y)
				finish_found = true
				break
		if finish_found:
			break
	
	if not finish_found:
		# Fallback to expected finish position
		finish_pos = Vector2i(current_grid_width - 2, GRID_HEIGHT / 2)
	
	print("Start position:", start_pos)
	print("Finish position:", finish_pos)
	
	# Handle start zone
	if grid[start_pos.x][start_pos.y].chunk:
		print("Found start chunk, setting up start zone")
		var start_zone = get_node_or_null("StartZone")
		
		if not start_zone:
			# Only create if it doesn't exist
			print("Creating new start zone")
			start_zone = preload("res://scenes/level_transition_zone.tscn").instantiate()
			start_zone.name = "StartZone"
			start_zone.zone_type = "Start"
			start_zone.player_entered.connect(_on_zone_entered)
			add_child(start_zone)
		
		# Move existing or new start zone to correct position
		start_zone.reparent(grid[start_pos.x][start_pos.y].chunk)
		start_zone.position = Vector2(200, 400)
		print("Start zone positioned at:", start_zone.position)
	else:
		print("WARNING: Start chunk not found at position", start_pos)
	
	# Handle finish zone
	if grid[finish_pos.x][finish_pos.y].chunk:
		print("Found finish chunk, setting up finish zone")
		var finish_zone = get_node_or_null("FinishZone")
		
		if not finish_zone:
			# Only create if it doesn't exist
			print("Creating new finish zone")
			finish_zone = preload("res://scenes/level_transition_zone.tscn").instantiate()
			finish_zone.name = "FinishZone"
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
		
	print("Zone entered: ", zone_type)  # Debug print
	if zone_type == "Start":
		print("Emitting level_started signal")  # Debug print
		level_started.emit()
	elif zone_type == "Finish":
		print("Emitting level_completed signal")  # Debug print
		is_transitioning = true
		level_completed.emit()
		current_level += 1
		generate_level()  # Generate new level
		
		# Reset transition flag after cooldown
		var timer = get_tree().create_timer(transition_cooldown)
		timer.timeout.connect(func(): is_transitioning = false)
		# Player will be automatically spawned at the start of new level

func unify_terrain() -> void:
	print("\nPhase 3: Unifying terrain...")
	
	# Create new unified terrain
	unified_terrain = UnifiedTerrain.new()
	add_child(unified_terrain)
	
	# Collect all chunks
	var chunks = []
	for x in range(current_grid_width):
		for y in range(GRID_HEIGHT):
			if grid[x][y].chunk:
				chunks.append(grid[x][y].chunk)
	
	# Process chunks in the unified terrain
	unified_terrain.unify_chunks(chunks)
	
	# Hide original tilemaps
	for chunk in chunks:
		var chunk_map = chunk.get_node("TileMap")
		if chunk_map:
			chunk_map.visible = false
	
	print("Terrain unification complete!")

func generate_branch(branch_start: Vector2i, all_paths: Array) -> void:
	# Skip if this is the start position or too close to finish
	if branch_start == Vector2i(0, GRID_HEIGHT / 2) or abs(branch_start.x - current_grid_width - 2) < 5:
		return
		
	# Determine branch direction (up or down)
	var branch_dir = Direction.UP if randf() < 0.5 else Direction.DOWN
	var branch_length = randi() % 3 + 2  # 2-4 chunks
	
	# Create branch path
	var current_branch_points = []
	var current_pos = branch_start
	current_branch_points.append(current_pos)
	
	# Move vertically
	var can_continue = true
	for _i in range(branch_length):
		var next_pos = current_pos + DIRECTION_VECTORS[branch_dir]
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			can_continue = false
			break
			
		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		
		# Set connections for both current and next positions
		grid[current_pos.x][current_pos.y].connections[branch_dir] = true
		grid[next_pos.x][next_pos.y].connections[get_opposite_direction(branch_dir)] = true
		
		# Clear any other connections for the next position
		for dir in Direction.values():
			if dir != get_opposite_direction(branch_dir):
				grid[next_pos.x][next_pos.y].connections[dir] = false
		
		current_pos = next_pos
		current_branch_points.append(current_pos)
	
	if not can_continue:
		return
	
	# Connect back to any main path if not too close to finish
	if current_pos.x < current_grid_width - 7:
		var rejoin_dir = get_opposite_direction(branch_dir)
		if not is_valid_direction(rejoin_dir):
			return
		
		# Move horizontally towards main path
		var rejoin_target_x = branch_start.x + randi() % 3 + 2  # Shorter horizontal segments (2-4 chunks)
		while current_pos.x < rejoin_target_x and current_pos.x < current_grid_width - 8:
			var next_pos = current_pos + DIRECTION_VECTORS[Direction.RIGHT]
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				break
			
			grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
			grid[next_pos.x][next_pos.y].visited = true
			
			# Set horizontal connections
			grid[current_pos.x][current_pos.y].connections[Direction.RIGHT] = true
			grid[next_pos.x][next_pos.y].connections[Direction.LEFT] = true
			
			# Clear any other connections for the next position
			for dir in Direction.values():
				if dir != Direction.LEFT:
					grid[next_pos.x][next_pos.y].connections[dir] = false
			
			current_pos = next_pos
			current_branch_points.append(current_pos)
		
		# Now try to rejoin with any main path
		var can_rejoin = true
		var rejoin_steps = 0
		while rejoin_steps < 3:  # Limit vertical rejoining to 3 steps
			var next_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				can_rejoin = false
				break
			
			grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
			grid[next_pos.x][next_pos.y].visited = true
			
			# Set vertical connections for rejoining
			grid[current_pos.x][current_pos.y].connections[rejoin_dir] = true
			grid[next_pos.x][next_pos.y].connections[get_opposite_direction(rejoin_dir)] = true
			
			# Clear any other connections for the next position
			for dir in Direction.values():
				if dir != get_opposite_direction(rejoin_dir):
					grid[next_pos.x][next_pos.y].connections[dir] = false
			
			current_pos = next_pos
			current_branch_points.append(current_pos)
			
			# Check if we've reached a visited cell
			var check_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			if is_valid_position(check_pos) and grid[check_pos.x][check_pos.y].visited:
				break
			
			rejoin_steps += 1
		
		if can_rejoin:
			# Connect to main path
			var main_path_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			if is_valid_position(main_path_pos) and grid[main_path_pos.x][main_path_pos.y].visited:
				grid[current_pos.x][current_pos.y].connections[rejoin_dir] = true
				grid[main_path_pos.x][main_path_pos.y].connections[get_opposite_direction(rejoin_dir)] = true
				all_paths.append(current_branch_points)

func add_dead_end(all_paths: Array) -> void:
	# Start from middle points of paths
	var source_path = all_paths[randi() % all_paths.size()]
	if source_path.size() < 3:
		return
		
	var start_idx = randi() % (source_path.size() - 2) + 1
	var dead_end_start = source_path[start_idx]
	
	# Skip if too close to finish
	if abs(dead_end_start.x - current_grid_width - 2) < 5:
		return
	
	# Choose direction for dead end
	var available_dirs = []
	for dir in Direction.values():
		var next_pos = dead_end_start + DIRECTION_VECTORS[dir]
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			continue
			
		# Check if the current position can support a connection in this direction
		var can_connect = true
		if grid[dead_end_start.x][dead_end_start.y].chunk:
			var current_chunk_type = get_chunk_type(grid[dead_end_start.x][dead_end_start.y].chunk)
			if not current_chunk_type.is_empty():
				var current_ports = CHUNKS[current_chunk_type]["ports"]
				if current_ports[dir] != Port.OPEN:
					can_connect = false
		
		if can_connect:
			available_dirs.append(dir)
	
	if available_dirs.is_empty():
		return
		
	var dead_end_dir = available_dirs[randi() % available_dirs.size()]
	var current_pos = dead_end_start
	
	# Create dead end path
	var dead_end_length = randi() % 2 + 1  # 1-2 chunks
	var dead_end_start_pos = current_pos  # Remember where we started
	var next_pos = current_pos + DIRECTION_VECTORS[dead_end_dir]
	
	if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
		grid[next_pos.x][next_pos.y].cell_type = CellType.DEAD_END
		grid[next_pos.x][next_pos.y].visited = true
		
		# Set up connections for the dead end
		var opposite_dir = get_opposite_direction(dead_end_dir)
		if is_valid_direction(opposite_dir):
			# Set connection from dead end back to previous cell
			grid[next_pos.x][next_pos.y].connections[opposite_dir] = true
			# Set connection from previous cell to dead end
			grid[current_pos.x][current_pos.y].connections[dead_end_dir] = true
			
			# Clear any other connections for both cells
			for dir in Direction.values():
				if dir != opposite_dir:
					grid[next_pos.x][next_pos.y].connections[dir] = false
				if dir != dead_end_dir and current_pos != dead_end_start_pos:  # Don't clear other connections for the starting cell
					grid[current_pos.x][current_pos.y].connections[dir] = false
			
			# For vertical connections, ensure proper alignment
			if dead_end_dir == Direction.UP or dead_end_dir == Direction.DOWN:
				# Clear horizontal connections on both cells
				grid[next_pos.x][next_pos.y].connections[Direction.LEFT] = false
				grid[next_pos.x][next_pos.y].connections[Direction.RIGHT] = false
				if current_pos != dead_end_start_pos:
					grid[current_pos.x][current_pos.y].connections[Direction.LEFT] = false
					grid[current_pos.x][current_pos.y].connections[Direction.RIGHT] = false

func is_valid_connection(from_pos: Vector2i, to_pos: Vector2i, dir: Direction) -> bool:
	# If connecting to/from the start chunk, only allow its RIGHT connection
	if from_pos == Vector2i(0, GRID_HEIGHT / 2):  # Start position
		return dir == Direction.RIGHT
	
	# If connecting TO the start chunk, only allow from its RIGHT side (LEFT direction)
	if to_pos == Vector2i(0, GRID_HEIGHT / 2):
		return dir == Direction.LEFT
	
	# Regular connection is valid
	return true
