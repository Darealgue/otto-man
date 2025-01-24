extends Node2D

# Import BaseChunk's Direction enum
const Direction = BaseChunk.Direction

# Simple port system - like magnets, either can connect or can't
enum Port {
	CLOSED = 0,  # No connection possible
	OPEN = 1     # Connection possible
}

# Grid settings
const GRID_WIDTH = 20
const GRID_HEIGHT = 10
const CHUNK_SIZE = Vector2(1920, 1080)  # Restored original chunk size
const GRID_SPACING = Vector2(1920, 1080)  # Space between chunks
const MIN_CHUNKS = 20

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
	
	# Start from middle of left side
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	print("Starting at position: ", start_pos)
	
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	
	# Initialize all connections to false for start chunk
	for dir in Direction.values():
		grid[start_pos.x][start_pos.y].connections[dir] = false
	
	# Set ONLY the right connection for start chunk
	grid[start_pos.x][start_pos.y].connections[Direction.RIGHT] = true
	
	current_path = [start_pos]
	
	# Set connection for the first chunk after start - MUST be basic or combat
	var first_chunk_pos = start_pos + DIRECTION_VECTORS[Direction.RIGHT]
	if is_valid_position(first_chunk_pos):
		grid[first_chunk_pos.x][first_chunk_pos.y].cell_type = CellType.MAIN_PATH
		grid[first_chunk_pos.x][first_chunk_pos.y].visited = true
		
		# Initialize all connections to false for first chunk
		for dir in Direction.values():
			grid[first_chunk_pos.x][first_chunk_pos.y].connections[dir] = false
		
		# Set LEFT and RIGHT connections for first chunk to ensure it's a basic platform
		grid[first_chunk_pos.x][first_chunk_pos.y].connections[Direction.LEFT] = true
		grid[first_chunk_pos.x][first_chunk_pos.y].connections[Direction.RIGHT] = true
		current_path.append(first_chunk_pos)
	
	# Generate main path first
	var current_pos = first_chunk_pos
	var attempts = 0
	var max_attempts = 200  # Increased max attempts
	var chunks_generated = 2  # Start and first chunk count as first two chunks
	var finish_placed = false
	var reached_right_side = false
	
	while attempts < max_attempts and not finish_placed:
		attempts += 1
		
		# If we've reached the right side, try to place finish
		if current_pos.x >= GRID_WIDTH - 2:
			reached_right_side = true
			var finish_pos = current_pos + DIRECTION_VECTORS[Direction.RIGHT]
			if is_valid_position(finish_pos) and not grid[finish_pos.x][finish_pos.y].visited:
				grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
				grid[finish_pos.x][finish_pos.y].visited = true
				grid[current_pos.x][current_pos.y].connections[Direction.RIGHT] = true
				grid[finish_pos.x][finish_pos.y].connections[Direction.LEFT] = true
				chunks_generated += 1
				finish_placed = true
				print("Placed finish at ", finish_pos)
				break
		
		# Try to extend main path
		var available_dirs = []
		
		# If we haven't reached minimum chunks or right side, strongly prefer moving right
		if not reached_right_side and current_pos.x < GRID_WIDTH - 2:
			available_dirs.append_array([Direction.RIGHT, Direction.RIGHT, Direction.RIGHT])  # More weight for right
		
		# Add vertical movements as options
		if current_pos.y > 1:
			available_dirs.append(Direction.UP)
		if current_pos.y < GRID_HEIGHT - 2:
			available_dirs.append(Direction.DOWN)
		
		# If we're stuck, allow backtracking left temporarily
		if available_dirs.is_empty() and current_pos.x < GRID_WIDTH - 2:
			if current_pos.y > 1:
				available_dirs.append(Direction.UP)
			if current_pos.y < GRID_HEIGHT - 2:
				available_dirs.append(Direction.DOWN)
			if current_pos.x > 1:
				available_dirs.append(Direction.LEFT)
		
		available_dirs.shuffle()
		var moved = false
		
		for dir in available_dirs:
			var next_pos = current_pos + DIRECTION_VECTORS[dir]
			if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
				grid[next_pos.x][next_pos.y].cell_type = CellType.MAIN_PATH
				grid[next_pos.x][next_pos.y].visited = true
				
				# Add connections
				grid[current_pos.x][current_pos.y].connections[dir] = true
				grid[next_pos.x][next_pos.y].connections[get_opposite_direction(dir)] = true
				
				current_path.append(next_pos)
				current_pos = next_pos
				moved = true
				attempts = 0
				chunks_generated += 1
				
				# Add branches only if we haven't reached the right side
				if not reached_right_side and chunks_generated < MIN_CHUNKS * 1.5 and randf() < 0.5:
					chunks_generated += add_branch(current_pos)
				
				break
		
		if moved:
			continue
			
		# If we can't move, backtrack
		if current_path.size() > 1:
			current_path.pop_back()
			current_pos = current_path.back()
		else:
			break
	
	print("Layout generation finished")
	print("Total chunks generated: ", chunks_generated)
	print("Required chunks: ", MIN_CHUNKS)
	print("Finish placed: ", finish_placed)
	
	return chunks_generated >= MIN_CHUNKS and finish_placed

func add_branch(start_pos: Vector2i) -> int:
	var branch_length = randi() % 5 + 3  # Longer branches: 3-7 chunks
	var current_pos = start_pos
	grid[current_pos.x][current_pos.y].cell_type = CellType.BRANCH_POINT
	var chunks_added = 0
	
	# Consider all directions for branching
	var available_dirs = []
	if current_pos.x < GRID_WIDTH - 2: available_dirs.append(Direction.RIGHT)
	if current_pos.y > 1: available_dirs.append(Direction.UP)
	if current_pos.y < GRID_HEIGHT - 2: available_dirs.append(Direction.DOWN)
	
	if available_dirs.is_empty():
		return chunks_added
		
	var branch_dir = available_dirs[randi() % available_dirs.size()]
	var branch_path = []
	
	for i in range(branch_length):
		var next_pos = current_pos + DIRECTION_VECTORS[branch_dir]
		if not is_valid_position(next_pos):
			break
			
		# Allow connecting to existing paths to create loops
		if grid[next_pos.x][next_pos.y].visited:
			# Only connect if it's not the immediate previous chunk
			if branch_path.size() > 1:
				grid[current_pos.x][current_pos.y].connections[branch_dir] = true
				grid[next_pos.x][next_pos.y].connections[get_opposite_direction(branch_dir)] = true
				chunks_added += 1
			break
			
		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		
		# Add connections
		grid[current_pos.x][current_pos.y].connections[branch_dir] = true
		grid[next_pos.x][next_pos.y].connections[get_opposite_direction(branch_dir)] = true
		
		branch_path.append(next_pos)
		current_pos = next_pos
		chunks_added += 1
		
		# Higher chance to change direction (40%)
		if i < branch_length - 1 and randf() < 0.4:
			var new_dirs = []
			if current_pos.x < GRID_WIDTH - 2: new_dirs.append(Direction.RIGHT)
			if current_pos.y > 1 and branch_dir != Direction.DOWN: new_dirs.append(Direction.UP)
			if current_pos.y < GRID_HEIGHT - 2 and branch_dir != Direction.UP: new_dirs.append(Direction.DOWN)
			
			if not new_dirs.is_empty():
				branch_dir = new_dirs[randi() % new_dirs.size()]
	
	# Only mark as dead end if we didn't connect to another path
	if not branch_path.is_empty() and not grid[current_pos.x][current_pos.y].connections.has(true):
		grid[branch_path.back().x][branch_path.back().y].cell_type = CellType.DEAD_END
	
	return chunks_added

func populate_chunks() -> bool:
	print("\nPhase 2: Populating with actual chunks...")
	
	# First place start chunk
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	if not place_chunk(start_pos, "start"):
		return false
	
	# Find and place finish chunk - look for rightmost main path position
	var finish_placed = false
	var finish_pos: Vector2i
	for x in range(GRID_WIDTH - 1, -1, -1):  # Search from right to left
		for y in range(GRID_HEIGHT):
			if grid[x][y].visited and grid[x][y].cell_type == CellType.MAIN_PATH:
				if not finish_placed:  # Only place finish if we haven't already
					finish_pos = Vector2i(x, y)
					if place_chunk(finish_pos, "finish"):
						finish_placed = true
						break
		if finish_placed:
			break
	
	if not finish_placed:
		return false
	
	# Then populate rest of the layout
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if grid[x][y].visited and not grid[x][y].chunk:
				var cell = grid[x][y]
				var chunk_type = select_appropriate_chunk(pos, cell)
				if chunk_type.is_empty() or not place_chunk(pos, chunk_type):
					print("Failed to place appropriate chunk at ", pos)
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
	
	# If all connections are required, only allow four_way_hub
	if connection_count == 4:
		return "four_way_hub"
	
	# Special handling for T-junctions based on required connections
	if connection_count == 3:
		# T-junction down: needs LEFT, RIGHT, DOWN but not UP
		if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and \
		   required_connections[Direction.DOWN] and not required_connections[Direction.UP]:
			return "t_junction_down"
			
		# T-junction up: needs LEFT, RIGHT, UP but not DOWN
		if required_connections[Direction.LEFT] and required_connections[Direction.RIGHT] and \
		   required_connections[Direction.UP] and not required_connections[Direction.DOWN]:
			return "t_junction_up"
			
		# T-junction right: needs LEFT, UP, DOWN but not RIGHT
		if required_connections[Direction.LEFT] and required_connections[Direction.UP] and \
		   required_connections[Direction.DOWN] and not required_connections[Direction.RIGHT]:
			return "t_junction_right"
			
		# T-junction left: needs RIGHT, UP, DOWN but not LEFT
		if required_connections[Direction.RIGHT] and required_connections[Direction.UP] and \
		   required_connections[Direction.DOWN] and not required_connections[Direction.LEFT]:
			return "t_junction_left"
	
	# Get list of valid chunks that match the required connections
	var valid_chunks = []
	for chunk_type in CHUNK_WEIGHTS.keys():
		# Skip start, finish, and T-junctions (handled separately)
		if chunk_type == "start" or chunk_type == "finish" or chunk_type.begins_with("t_junction"):
			continue
			
		var ports = CHUNK_PORTS[chunk_type]
		var is_valid = true
		
		# Check each direction
		for dir in Direction.values():
			# If a connection is required, the port must be open
			if required_connections[dir] and ports[dir] == Port.CLOSED:
				is_valid = false
				break
			# If no connection is required, the port must be closed
			if not required_connections[dir] and ports[dir] == Port.OPEN:
				# Special case for dead ends - they should have exactly one open port
				if chunk_type.begins_with("dead_end"):
					var open_ports = 0
					for d in Direction.values():
						if ports[d] == Port.OPEN:
							open_ports += 1
					if open_ports != 1:
						is_valid = false
						break
				else:
					is_valid = false
					break
		
		if is_valid:
			valid_chunks.append(chunk_type)
	
	print("Valid chunks: ", valid_chunks)
	
	# If no valid chunks found, return empty string
	if valid_chunks.is_empty():
		return ""
	
	# If this is a dead end position (only one connection needed), prioritize dead ends
	if connection_count == 1 and cell.cell_type == CellType.DEAD_END:
		var dead_ends = valid_chunks.filter(func(chunk): return chunk.begins_with("dead_end"))
		if not dead_ends.is_empty():
			return dead_ends[randi() % dead_ends.size()]
	
	# Otherwise use weighted selection
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
	var ports = CHUNK_PORTS[chunk_type]
	
	# First verify that the chunk's ports match the required connections
	for dir in Direction.values():
		if grid[pos.x][pos.y].connections[dir] and ports[dir] == Port.CLOSED:
			print("Chunk ", chunk_type, " has closed port in direction ", dir, " but connection is required")
			return false
		if not grid[pos.x][pos.y].connections[dir] and ports[dir] == Port.OPEN:
			print("Chunk ", chunk_type, " has open port in direction ", dir, " but no connection is required")
			return false
	
	# Then verify connections with surrounding chunks
	for dir in Direction.values():
		var next_pos = pos + DIRECTION_VECTORS[dir]
		if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].chunk:
			var next_chunk_type = get_chunk_type(grid[next_pos.x][next_pos.y].chunk)
			if next_chunk_type.is_empty():
				continue
				
			var opposite_dir = get_opposite_direction(dir)
			var next_ports = CHUNK_PORTS[next_chunk_type]
			
			# If either chunk has a closed port where they meet, they can't connect
			if (ports[dir] == Port.CLOSED and grid[next_pos.x][next_pos.y].connections[opposite_dir]) or \
			   (next_ports[opposite_dir] == Port.CLOSED and grid[pos.x][pos.y].connections[dir]):
				print("Connection mismatch between ", chunk_type, " and ", next_chunk_type, " at direction ", dir)
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
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT

const CHUNK_PORTS = {
	"start": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.CLOSED
	},
	"finish": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.CLOSED
	},
	"basic": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.CLOSED
	},
	"combat": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.CLOSED
	},
	"vertical": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.OPEN
	},
	"t_junction_up": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.CLOSED
	},
	"t_junction_down": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.OPEN
	},
	"t_junction_left": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.OPEN
	},
	"t_junction_right": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.OPEN
	},
	"corner_right_up": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.CLOSED
	},
	"corner_right_down": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.OPEN
	},
	"corner_left_up": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.CLOSED
	},
	"corner_left_down": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.OPEN
	},
	"dead_end_up": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.OPEN
	},
	"dead_end_down": {
		Direction.LEFT: Port.CLOSED,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.CLOSED
	},
	"dead_end_right": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.CLOSED,
		Direction.UP: Port.CLOSED,
		Direction.DOWN: Port.CLOSED
	},
	"four_way_hub": {
		Direction.LEFT: Port.OPEN,
		Direction.RIGHT: Port.OPEN,
		Direction.UP: Port.OPEN,
		Direction.DOWN: Port.OPEN
	}
}

# Chunk weights for random selection
const CHUNK_WEIGHTS = {
	"basic": 30,  # Reduced weight for basic platforms
	"combat": 25,
	"vertical": 20,
	"t_junction_up": 25,    # Increased weight for T-junctions
	"t_junction_down": 25,
	"t_junction_left": 25,
	"t_junction_right": 25,
	"corner_right_up": 20,  # Increased weight for corners
	"corner_right_down": 20,
	"corner_left_up": 20,
	"corner_left_down": 20,
	"four_way_hub": 15,    # Added four-way hub for complex intersections
	"dead_end_up": 15,
	"dead_end_down": 15,
	"dead_end_right": 15
}

func spawn_player() -> void:
	var start_pos = Vector2i(0, GRID_HEIGHT / 2)
	var start_chunk = grid[start_pos.x][start_pos.y].chunk
	
	if start_chunk:
		var player_scene = load("res://player/player.tscn")
		if player_scene:
			var player = player_scene.instantiate()
			player.name = "Player"  # Set a consistent name to find it later
			add_child(player)
			# Position player at the start chunk's position plus a small offset to ensure they're on the ground
			player.position = start_chunk.position + Vector2(200, 400)  # Adjust these values based on your chunk layout
			print("Player spawned at: ", player.position)
