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

func _ready() -> void:
	setup_camera()
	initialize_grid()
	if not generate_level():
		print("Failed to generate level!")
		get_tree().quit()

func setup_camera() -> void:
	overview_camera = Camera2D.new()
	overview_camera.make_current()
	add_child(overview_camera)
	
	# Position camera to see the whole level
	var level_size = Vector2(GRID_WIDTH * CHUNK_SIZE.x, GRID_HEIGHT * CHUNK_SIZE.y)
	overview_camera.position = level_size / 2
	
	# Calculate zoom to fit the level
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_x = viewport_size.x / level_size.x
	var zoom_y = viewport_size.y / level_size.y
	overview_camera.zoom = Vector2(min(zoom_x, zoom_y) * 0.9, min(zoom_x, zoom_y) * 0.9)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):  # We'll set this up in Project Settings
		toggle_camera()

func toggle_camera() -> void:
	is_overview_active = !is_overview_active
	if is_overview_active:
		overview_camera.make_current()
	else:
		# Find player node and activate its camera
		var player = get_node_or_null("Player")  # Adjust the node path if needed
		if player and player.has_node("Camera2D"):
			player.get_node("Camera2D").make_current()

func initialize_grid() -> void:
	grid.clear()
	for x in range(GRID_WIDTH):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(GridCell.new())
	
func generate_level() -> bool:
	print("\nStarting level generation...")
	
	# Phase 1: Generate abstract layout
	if not generate_layout():
		print("Failed to generate layout!")
		return false
	
	# Phase 2: Populate with actual chunks
	if not populate_chunks():
		print("Failed to populate chunks!")
		return false
		
	# Phase 3: Spawn player in start chunk
	spawn_player()
		
	print("Level generated successfully!")
	return true

func generate_layout() -> bool:
	print("\nPhase 1: Generating abstract layout...")
	
	# Initialize path generator
	var path_gen = PathGenerator.new(GRID_WIDTH, GRID_HEIGHT)
	
	# Set start and finish positions
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var finish_pos = Vector2i(GRID_WIDTH - 2, GRID_HEIGHT / 2)
	
	# Mark start and finish in grid
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
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
		var y = GRID_HEIGHT / 2 + (randi() % 5 - 2)  # Slight vertical variation
		waypoints.append(Vector2i(x, y))
	
	# Ensure the last waypoint before finish is at the same height
	var pre_finish = Vector2i(finish_pos.x - 1, finish_pos.y)
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
		if i > 0:
			var prev = main_path_points[i - 1]
			if current.x > prev.x:  # Moving right
				grid[current.x][current.y].connections[Direction.LEFT] = true
				grid[prev.x][prev.y].connections[Direction.RIGHT] = true
			elif current.x < prev.x:  # Moving left
				grid[current.x][current.y].connections[Direction.RIGHT] = true
				grid[prev.x][prev.y].connections[Direction.LEFT] = true
			
			if current.y > prev.y:  # Moving down
				grid[current.x][current.y].connections[Direction.UP] = true
				grid[prev.x][prev.y].connections[Direction.DOWN] = true
			elif current.y < prev.y:  # Moving up
				grid[current.x][current.y].connections[Direction.DOWN] = true
				grid[prev.x][prev.y].connections[Direction.UP] = true
	
	all_paths.append(main_path_points)
	
	# Create branch points every 4 chunks along the main path
	var branch_start_positions = []
	for i in range(2, main_path_points.size() - 8, 4):  # Stop further from finish
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
		for _i in range(branch_length):
			var next_pos = current_pos + DIRECTION_VECTORS[branch_dir]
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
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
		
		# Move horizontally towards main path
		var target_x = branch_start.x + randi() % 4 + 2  # Rejoin 2-5 chunks ahead
		while current_pos.x < target_x and current_pos.x < finish_pos.x - 6:  # Stop before finish area
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
		
		# Connect back to main path if not too close to finish
		if current_pos.x < finish_pos.x - 5:
			var rejoin_dir = get_opposite_direction(branch_dir)
			while not grid[current_pos.x][current_pos.y + DIRECTION_VECTORS[rejoin_dir].y].visited:
				var next_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
				if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
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
			
			# Connect to main path
			var main_path_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			if is_valid_position(main_path_pos) and grid[main_path_pos.x][main_path_pos.y].visited:
				grid[current_pos.x][current_pos.y].connections[rejoin_dir] = true
				grid[main_path_pos.x][main_path_pos.y].connections[get_opposite_direction(rejoin_dir)] = true
		
		all_paths.append(current_branch_points)
	
	# Add some dead ends (but not near finish)
	var num_dead_ends = 4
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
					var current_ports = CHUNK_PORTS[current_chunk_type]["ports"]
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
		
		# Set connection for the starting point
		grid[current_pos.x][current_pos.y].connections[dead_end_dir] = true
		
		for _j in range(dead_end_length):
			var next_pos = current_pos + DIRECTION_VECTORS[dead_end_dir]
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				break
				
			grid[next_pos.x][next_pos.y].cell_type = CellType.DEAD_END
			grid[next_pos.x][next_pos.y].visited = true
			
			# Set only the connection back to the previous chunk
			for dir in Direction.values():
				grid[next_pos.x][next_pos.y].connections[dir] = (dir == get_opposite_direction(dead_end_dir))
			
			current_pos = next_pos
	
	# Ensure finish chunk is properly connected
	for dir in Direction.values():
		grid[finish_pos.x][finish_pos.y].connections[dir] = (dir == Direction.LEFT)
	
	# Ensure clean connection to finish
	var pre_finish_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(pre_finish_pos):
		for dir in Direction.values():
			grid[pre_finish_pos.x][pre_finish_pos.y].connections[dir] = (dir == Direction.LEFT or dir == Direction.RIGHT)
	
	return true

func populate_chunks() -> bool:
	print("\nPhase 2: Populating with actual chunks...")
	
	# 1. Place start chunk first
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	if not place_chunk(start_pos, "start"):
		print("Failed to place start chunk")
		return false
	
	# 2. Place finish chunk
	var finish_pos = Vector2i(GRID_WIDTH - 2, GRID_HEIGHT / 2)
	if not place_chunk(finish_pos, "finish"):
		print("Failed to place finish chunk")
		return false
		
	# 3. Place main path chunks
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].visited and not grid[x][y].chunk and grid[x][y].cell_type == CellType.MAIN_PATH:
				var cell = grid[x][y]
				var chunk_type = select_appropriate_chunk(pos, cell)
				if chunk_type.is_empty() or not place_chunk(pos, chunk_type):
					print("Failed to place main path chunk at ", pos)
					return false
	
	# 4. Place branch points and branch paths
	for x in range(GRID_WIDTH):
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
	for x in range(GRID_WIDTH):
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
				
				# Check if the connection is valid with neighboring chunk
				var neighbor_pos = pos + DIRECTION_VECTORS[connection_dir]
				if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].chunk:
					var neighbor_type = get_chunk_type(grid[neighbor_pos.x][neighbor_pos.y].chunk)
					if not neighbor_type.is_empty():
						var neighbor_ports = CHUNK_PORTS[neighbor_type]["ports"]
						var opposite_dir = get_opposite_direction(connection_dir)
						if neighbor_ports[opposite_dir] != Port.OPEN:
							print("Cannot connect dead end at ", pos, " to neighbor in direction ", connection_dir)
							continue
				
				# Select appropriate dead end based on connection direction
				var chunk_type = ""
				match connection_dir:
					Direction.LEFT:
						chunk_type = "dead_end_right"  # Connects from the right
					Direction.RIGHT:
						chunk_type = "dead_end_left"   # Connects from the left
					Direction.UP:
						chunk_type = "dead_end_down"   # Connects from below
					Direction.DOWN:
						chunk_type = "dead_end_up"     # Connects from above
					_:
						print("Invalid connection direction for dead end at ", pos)
						continue
				
				# Clear all connections except the required one
				for dir in Direction.values():
					cell.connections[dir] = (dir == connection_dir)
				
				if not place_chunk(pos, chunk_type):
					print("Failed to place dead end at ", pos)
					return false
	
	return true

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
	
	# Handle single connection case (dead ends) first
	if connection_count == 1:
		if required_connections[Direction.LEFT]:
			return "dead_end_right"  # LEFT connection needed, use dead end with RIGHT port closed
		if required_connections[Direction.RIGHT]:
			return "dead_end_left"   # RIGHT connection needed, use dead end with LEFT port closed
		if required_connections[Direction.UP]:
			return "dead_end_down"   # UP connection needed, use dead end with DOWN port closed
		if required_connections[Direction.DOWN]:
			return "dead_end_up"     # DOWN connection needed, use dead end with UP port closed
	
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
	for chunk_type in CHUNK_PORTS.keys():
		# Skip special chunks (handled separately)
		if chunk_type in ["start", "finish"]:
			continue
		
		# Ensure chunk type exists in both dictionaries
		if not CHUNK_WEIGHTS.has(chunk_type):
			continue
			
		var ports = CHUNK_PORTS[chunk_type]["ports"]
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
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * GRID_SPACING.x, pos.y * GRID_SPACING.y)

func place_chunk(pos: Vector2i, chunk_type: String) -> bool:
	if not is_valid_position(pos):
		return false
	
	# Don't place if there's already a chunk here
	if grid[pos.x][pos.y].chunk != null:
		return false
	
	# Get the ports for this chunk type
	var ports = CHUNK_PORTS[chunk_type]["ports"]
	
	# First verify that the chunk's ports match the required connections
	for dir in Direction.values():
		# If a connection is required, the port must be open
		if grid[pos.x][pos.y].connections[dir] and ports[dir] != Port.OPEN:
			print("Chunk ", chunk_type, " has incorrect port state in direction ", dir)
			print("Required connection: ", grid[pos.x][pos.y].connections[dir])
			print("Port state: ", ports[dir])
			return false
	
	# Then verify connections with surrounding chunks
	for dir in Direction.values():
		var next_pos = pos + DIRECTION_VECTORS[dir]
		if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].chunk:
			var next_chunk_type = get_chunk_type(grid[next_pos.x][next_pos.y].chunk)
			if next_chunk_type.is_empty():
				continue
				
			var opposite_dir = get_opposite_direction(dir)
			var next_ports = CHUNK_PORTS[next_chunk_type]["ports"]
			
			# Check if either chunk requires a connection
			if grid[pos.x][pos.y].connections[dir] or grid[next_pos.x][next_pos.y].connections[opposite_dir]:
				# Both ports must be open for a valid connection
				if ports[dir] != Port.OPEN or next_ports[opposite_dir] != Port.OPEN:
					print("Connection mismatch between chunks at direction ", dir)
					return false
	
	var scene = load(CHUNK_PORTS[chunk_type]["scene"])
	if not scene:
		print("Failed to load chunk scene: ", CHUNK_PORTS[chunk_type]["scene"])
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
	
	for type in CHUNK_PORTS:
		if chunk.scene_file_path == CHUNK_PORTS[type]["scene"]:
			return type
	
	return ""

func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT

const CHUNK_PORTS = {
	"start": {
		"scene": "res://chunks/special/start_chunk.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
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
	"t_junction_up": {
		"scene": "res://chunks/hub/t_junction_up.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
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
	"t_junction_left": {
		"scene": "res://chunks/hub/t_junction_left.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
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
	"corner_right_up": {
		"scene": "res://chunks/hub/l_corner_right_up.tscn",
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.CLOSED
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
	"corner_left_up": {
		"scene": "res://chunks/hub/l_corner_left_up.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
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
	},
	"four_way_hub": {
		"scene": "res://chunks/hub/four_way_hub.tscn",
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.OPEN,
			Direction.DOWN: Port.OPEN
		}
	}
}

# Chunk weights for random selection
const CHUNK_WEIGHTS = {
	"basic": 15,           # Reduced basic platforms for more variety
	"combat": 35,          # Increased combat arenas for more action
	"vertical": 30,        # More vertical sections for exploration
	"t_junction_up": 35,   # Increased T-junctions for more branching paths
	"t_junction_down": 35,
	"t_junction_left": 35,
	"t_junction_right": 35,
	"corner_right_up": 30, # More corners for complex paths
	"corner_right_down": 30,
	"corner_left_up": 30,
	"corner_left_down": 30,
	"four_way_hub": 25,    # More intersections for maze-like feel
	"dead_end_up": 20,     # Slightly increased dead ends for exploration rewards
	"dead_end_down": 20,
	"dead_end_right": 20,
	"dead_end_left": 20
}

func spawn_player() -> void:
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var start_chunk = grid[start_pos.x][start_pos.y].chunk
	
	if start_chunk:
		var player_scene = load("res://player/player.tscn")
		if player_scene:
			var player = player_scene.instantiate()
			player.name = "Player"
			add_child(player)
			# Adjusted spawn position to be closer to the ground
			player.position = start_chunk.position + Vector2(200, 400)
			print("Player spawned at: ", player.position)
