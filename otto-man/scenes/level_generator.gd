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
const CHUNK_SIZE = Vector2(1920, 1080)  # Restored original chunk size
const GRID_SPACING = Vector2(1920, 1080)  # Space between chunks
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
	
	if generate_layout():
		if populate_chunks():
			print("Level generated successfully!")
			setup_level_transitions()  # Make sure transitions are set up after chunks are placed
			spawn_player()  # Spawn player after transitions are set up
			return
	
	print("Failed to generate level!")

func generate_layout() -> bool:
	print("\nPhase 1: Generating abstract layout...")
	
	# Get level-specific values
	var num_branches = level_config.get_num_branches_for_level(current_level)
	var num_dead_ends = level_config.get_num_dead_ends_for_level(current_level)
	
	# Initialize path generator
	var path_gen = PathGenerator.new(current_grid_width, GRID_HEIGHT)
	
	# Set start and finish positions
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var finish_pos = Vector2i(current_grid_width - 2, GRID_HEIGHT / 2)
	
	# Mark start and finish in grid
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	# Set start chunk connections (only right connection)
	for dir in Direction.values():
		grid[start_pos.x][start_pos.y].connections[dir] = (dir == Direction.RIGHT)
	
	grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
	grid[finish_pos.x][finish_pos.y].visited = true
	
	var all_paths = []
	
	# Generate main path with waypoints for more interesting routes
	var waypoints = []
	waypoints.append(start_pos)
	
	# Add 2-3 intermediate waypoints for main path
	var num_waypoints = randi() % 2 + 2
	for i in range(num_waypoints):
		var x = start_pos.x + ((i + 1) * (finish_pos.x - start_pos.x)) / (num_waypoints + 1)
		var y = GRID_HEIGHT / 2 + (randi() % 3 - 1)  # Less vertical variation
		waypoints.append(Vector2i(x, y))
	
	# Ensure path returns to finish height gradually
	var last_waypoint = waypoints[-1]
	if abs(last_waypoint.y - finish_pos.y) > 0:
		var pre_finish = Vector2i(finish_pos.x - 2, finish_pos.y)
		waypoints.append(pre_finish)
	waypoints.append(finish_pos)
	
	# Generate main path through waypoints
	var main_path_points = []
	for i in range(waypoints.size() - 1):
		var path_segment = path_gen.astar.get_point_path(
			path_gen._get_point_index(waypoints[i]),
			path_gen._get_point_index(waypoints[i + 1])
		)
		
		for j in range(path_segment.size() - (1 if i < waypoints.size() - 2 else 0)):
			var grid_pos = Vector2i(path_segment[j].x, path_segment[j].y)
			main_path_points.append(grid_pos)
			grid[grid_pos.x][grid_pos.y].cell_type = CellType.MAIN_PATH
			grid[grid_pos.x][grid_pos.y].visited = true
	
	# Set connections for main path
	for i in range(main_path_points.size()):
		var current = main_path_points[i]
		
		if i > 0:  # Connect to previous
			var prev = main_path_points[i - 1]
			var dir = get_direction_between(prev, current)
			if is_valid_direction(dir):
				grid[current.x][current.y].connections[get_opposite_direction(dir)] = true
				grid[prev.x][prev.y].connections[dir] = true
		
		if i < main_path_points.size() - 1:  # Connect to next
			var next = main_path_points[i + 1]
			var dir = get_direction_between(current, next)
			if is_valid_direction(dir):
				grid[current.x][current.y].connections[dir] = true
				grid[next.x][next.y].connections[get_opposite_direction(dir)] = true
	
	# Ensure finish chunk is properly connected
	for dir in Direction.values():
		grid[finish_pos.x][finish_pos.y].connections[dir] = (dir == Direction.LEFT)  # Only left connection
	
	# Ensure clean connection to finish
	var pre_finish_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(pre_finish_pos):
		for dir in Direction.values():
			grid[pre_finish_pos.x][pre_finish_pos.y].connections[dir] = (dir == Direction.LEFT or dir == Direction.RIGHT)  # Left and right connections only
	
	all_paths.append(main_path_points)
	
	# Create branch points every 4 chunks along the main path, but not in the last third
	var branch_start_positions = []
	var last_third_start = main_path_points.size() * 2 / 3
	for i in range(2, last_third_start, 4):
		branch_start_positions.append(main_path_points[i])
	
	# Generate branches from each branch point
	for branch_start in branch_start_positions:
		# Skip if too close to finish
		if abs(branch_start.x - finish_pos.x) < 6:
			continue
			
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
			continue
		
		# Connect back to main path if not too close to finish
		if current_pos.x < finish_pos.x - 5:
			var rejoin_dir = get_opposite_direction(branch_dir)
			if not is_valid_direction(rejoin_dir):
				continue
			
			# Move horizontally towards main path
			var rejoin_target_x = branch_start.x + randi() % 3 + 2  # Shorter horizontal segments (2-4 chunks)
			while current_pos.x < rejoin_target_x and current_pos.x < finish_pos.x - 6:
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
			
			# Now try to rejoin with the main path
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
	
	# Add some dead ends (but not near finish)
	for _i in range(num_dead_ends):
		# Start from middle points of paths
		var source_path = all_paths[randi() % all_paths.size()]
		if source_path.size() < 3:
			continue
			
		var start_idx = randi() % (source_path.size() - 2) + 1
		var dead_end_start = source_path[start_idx]
		
		# Skip if too close to finish
		if abs(dead_end_start.x - finish_pos.x) < 5:
			continue
		
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
			continue
			
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
	
	return true

func populate_chunks() -> bool:
	print("\nPhase 2: Populating with actual chunks...")
	
	# 1. Place start chunk first
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	if not place_chunk(start_pos, "start"):
		print("Failed to place start chunk")
		return false
	
	# 2. Place finish chunk
	var finish_pos = Vector2i(current_grid_width - 2, GRID_HEIGHT / 2)
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
	
	return true  # Return true if we've made it through all placements

func select_appropriate_chunk(pos: Vector2i, cell: GridCell) -> String:
	# Get required connections based on surrounding cells
	var required_connections = [false, false, false, false]  # [LEFT, RIGHT, UP, DOWN]
	
	# First check existing connections in the grid cell
	for dir in Direction.values():
		if cell.connections[dir]:
			required_connections[dir] = true
	
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

func place_chunk(pos: Vector2i, chunk_type: String) -> bool:
	if not is_valid_position(pos):
		return false
	
	# Don't place if there's already a chunk here
	if grid[pos.x][pos.y].chunk != null:
		return false
	
	# Get the ports for this chunk type
	var ports = CHUNKS[chunk_type]["ports"]
	
	# First verify that the chunk's ports match the required connections
	for dir in Direction.values():
		# If a connection is required, the port must be open
		if grid[pos.x][pos.y].connections[dir] and ports[dir] != Port.OPEN:
			print("Chunk ", chunk_type, " has incorrect port state in direction ", dir)
			return false
	
	# Then verify connections with surrounding chunks
	for dir in Direction.values():
		var next_pos = pos + DIRECTION_VECTORS[dir]
		if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].chunk:
			var next_chunk_type = get_chunk_type(grid[next_pos.x][next_pos.y].chunk)
			if next_chunk_type.is_empty():
				continue
				
			var opposite_dir = get_opposite_direction(dir)
			var next_ports = CHUNKS[next_chunk_type]["ports"]
			
			# Only check if this chunk requires a connection in this direction
			if grid[pos.x][pos.y].connections[dir]:
				if ports[dir] != Port.OPEN or next_ports[opposite_dir] != Port.OPEN:
					print("Connection mismatch between chunks at direction ", dir)
					return false
	
	var scene = load(CHUNKS[chunk_type]["scene"])
	if not scene:
		print("Failed to load chunk scene: ", CHUNKS[chunk_type]["scene"])
		return false
	
	var chunk = scene.instantiate()
	add_child(chunk)
	chunk.position = grid_to_world(pos)
	
	grid[pos.x][pos.y].chunk = chunk
	
	print("Placed ", chunk_type, " at ", pos)
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
		
		# Move existing or new player to start position
		player.position = start_chunk.position + Vector2(200, 400)
		print("Player moved to: ", player.position)
		
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
	var finish_pos = Vector2i(current_grid_width - 2, GRID_HEIGHT / 2)
	
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
		finish_zone.position = Vector2(200, 400)
		print("Finish zone positioned at:", finish_zone.position)
	else:
		print("ERROR: No chunk found at finish position", finish_pos)

func _on_zone_entered(zone_type: String) -> void:
	print("Zone entered: ", zone_type)  # Debug print
	if zone_type == "Start":
		print("Emitting level_started signal")  # Debug print
		level_started.emit()
	elif zone_type == "Finish":
		print("Emitting level_completed signal")  # Debug print
		level_completed.emit()
		current_level += 1
		generate_level()  # Generate new level
		# Player will be automatically spawned at the start of new level
