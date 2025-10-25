extends Node2D

# Helper: abstract get_cell_source_id across TileMap vs TileMapLayer APIs
func _get_cell_source_id_any(tilemap_node: Node, cell: Vector2i) -> int:
	if tilemap_node == null:
		return -1
	var cls := tilemap_node.get_class()
	# TileMap (Godot 4): get_cell_source_id(layer, pos)
	if cls == "TileMap" and tilemap_node.has_method("get_cell_source_id"):
		var v = tilemap_node.callv("get_cell_source_id", [0, cell])
		return int(v) if typeof(v) == TYPE_INT else -1
	# TileMapLayer: get_cell_source_id(pos)
	if cls == "TileMapLayer" and tilemap_node.has_method("get_cell_source_id"):
		var v2 = tilemap_node.callv("get_cell_source_id", [cell])
		return int(v2) if typeof(v2) == TYPE_INT else -1
	# Fallback: try both signatures defensively
	if tilemap_node.has_method("get_cell_source_id"):
		var r2 = tilemap_node.callv("get_cell_source_id", [0, cell])
		if typeof(r2) == TYPE_INT:
			return int(r2)
		var r1 = tilemap_node.callv("get_cell_source_id", [cell])
		if typeof(r1) == TYPE_INT:
			return int(r1)
	return -1

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
const GRID_WIDTH = 20 # Base width, will be overridden
const BASE_GRID_HEIGHT = 10 # Base height for levels 1-4
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
			"res://chunks/dungeon/basic/basic_platform2.tscn",
			"res://chunks/dungeon/basic/basic_platform3.tscn",
			"res://chunks/dungeon/basic/basic_platform4.tscn"
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
			"res://chunks/dungeon/hub/l_corner_right_down2.tscn",
			"res://chunks/dungeon/hub/l_corner_right_down3.tscn",
			"res://chunks/dungeon/hub/l_corner_right_down4.tscn"
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
			"res://chunks/dungeon/hub/l_corner_left_up2.tscn",
			"res://chunks/dungeon/hub/l_corner_left_up3.tscn",
			"res://chunks/dungeon/hub/l_corner_left_up4.tscn"
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
			"res://chunks/dungeon/hub/l_corner_left_down2.tscn",
			"res://chunks/dungeon/hub/l_corner_left_down3.tscn",
			"res://chunks/dungeon/hub/l_corner_left_down4.tscn"
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
			"res://chunks/dungeon/hub/l_corner_right_up2.tscn",
			"res://chunks/dungeon/hub/l_corner_right_up3.tscn",
			"res://chunks/dungeon/hub/l_corner_right_up4.tscn"
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
			"res://chunks/dungeon/hub/t_junction_right2.tscn",
			"res://chunks/dungeon/hub/t_junction_right3.tscn",
			"res://chunks/dungeon/hub/t_junction_right4.tscn"
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
			"res://chunks/dungeon/hub/t_junction_left2.tscn",
			"res://chunks/dungeon/hub/t_junction_left3.tscn",
			"res://chunks/dungeon/hub/t_junction_left4.tscn"
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
			"res://chunks/dungeon/hub/t_junction_up2.tscn",
			"res://chunks/dungeon/hub/t_junction_up3.tscn",
			"res://chunks/dungeon/hub/t_junction_up4.tscn"
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
			"res://chunks/dungeon/hub/t_junction_down2.tscn",
			"res://chunks/dungeon/hub/t_junction_down3.tscn",
			"res://chunks/dungeon/hub/t_junction_down4.tscn"
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
			"res://chunks/dungeon/hub/four_way_hub2.tscn",
			"res://chunks/dungeon/hub/four_way_hub3.tscn",
			"res://chunks/dungeon/hub/four_way_hub4.tscn"
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
			"res://chunks/dungeon/vertical/climbing_tower2.tscn",
			"res://chunks/dungeon/vertical/climbing_tower3.tscn",
			"res://chunks/dungeon/vertical/climbing_tower4.tscn"
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
,
	# --- Special dead-end chunks for villager/VIP rooms (spawned via reservation) ---
	"villager_dead_end_left": {
		# Note: Scene mapping swapped to match actual doorway orientation in prefab
		"scenes": ["res://chunks/dungeon/special/villager_dead_end_right.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"villager_dead_end_right": {
		# Note: Scene mapping swapped to match actual doorway orientation in prefab
		"scenes": ["res://chunks/dungeon/special/villager_dead_end_left.tscn"],
		"ports": {
			Direction.LEFT: Port.CLOSED,
			Direction.RIGHT: Port.OPEN,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"vip_dead_end_left": {
		# Note: Scene mapping swapped to match actual doorway orientation in prefab
		"scenes": ["res://chunks/dungeon/special/vip_dead_end_right.tscn"],
		"ports": {
			Direction.LEFT: Port.OPEN,
			Direction.RIGHT: Port.CLOSED,
			Direction.UP: Port.CLOSED,
			Direction.DOWN: Port.CLOSED
		}
	},
	"vip_dead_end_right": {
		# Note: Scene mapping swapped to match actual doorway orientation in prefab
		"scenes": ["res://chunks/dungeon/special/vip_dead_end_left.tscn"],
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
	BRANCH_POINT,   # Where a branch splits from main path
	WALL            # A wall cell surrounding paths
}

# Grid cell to store layout and chunk information
class GridCell:
	var chunk: Node2D = null
	var visited: bool = false
	var cell_type: CellType = CellType.EMPTY
	var connections: Array[bool] = [false, false, false, false]  # LEFT, RIGHT, UP, DOWN
	var visited_by: String = "" # Track which function first visited this cell
	var path_id: int = -1 # ID of the path segment this cell belongs to
	var reserved_chunk: String = "" # If set, override selection with this exact chunk type

# Member variables
var grid: Array = []
var chunks_placed: int = 0
var current_path: Array = []
var overview_camera: Camera2D
var is_overview_active: bool = true
var current_path_id_counter: int = 0 # Counter for unique path IDs
var current_grid_height: int = BASE_GRID_HEIGHT # Dynamic height, calculated per level

@export var current_level: int = 1  # Current level number
@export var level_config: LevelConfig  # Reference to our dungeon configuration resource

# --- Boss schedule helpers (debug-only for now) ---
# Levels mapping for boss events; we keep it data-driven and simple
const BOSS_SCHEDULE: Dictionary = {
	3: "mini",
	5: "major",
	7: "mini",
	9: "major",
}

func get_boss_event_type(level: int) -> String:
	# Returns "" | "mini" | "major" according to cyclic schedule (3,5,7,9...)
	if level < 3:
		return ""
	var keys: Array[int] = [3, 5, 7, 9]
	var idx: int = (level - 3) % keys.size()
	var mapped_level: int = keys[idx]
	var result = BOSS_SCHEDULE.get(mapped_level, "")
	return String(result)

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
var placed_gate_positions: Array[Vector2] = []
var door_positions: Array[Vector2] = []  # Kapı pozisyonlarını sakla

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
	print("[LevelGenerator] _ready() called")
	is_overview_active = true  # Start with overview camera
	
	# Load level config if not set
	if not level_config:
		print("[LevelGenerator] Loading level config...")
		level_config = load("res://resources/dungeon_config.tres")
		if not level_config:
			push_error("Failed to load dungeon_config.tres!")
			return
		print("[LevelGenerator] Level config loaded successfully")
	else:
		print("[LevelGenerator] Level config already set")
	
	print("[LevelGenerator] Starting level generation...")
	generate_level()
	print("[LevelGenerator] Setting up camera...")
	setup_camera()
	print("[LevelGenerator] Setting up level transitions...")
	setup_level_transitions()
	print("[LevelGenerator] Adding screen darkness controller...")
	add_screen_darkness_controller()
	print("[LevelGenerator] _ready() completed")

func setup_camera() -> void:
	overview_camera = Camera2D.new()
	add_child(overview_camera)
	
	# Position camera to see the whole level
	var level_size = Vector2(current_grid_width * CHUNK_SIZE.x, current_grid_height * CHUNK_SIZE.y) # Use current_grid_height
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
	placed_gate_positions.clear()
	door_positions.clear()  # Kapı pozisyonlarını temizle
	# Store camera state and zoom
	var player = get_node_or_null("Player")
	var player_camera_zoom = Vector2.ONE
	if player and player.has_node("Camera2D"):
		is_overview_active = !player.get_node("Camera2D").is_current()
		player_camera_zoom = player.get_node("Camera2D").zoom
	
	# Store player reference before clearing
	var stored_player = player
	
	# Remove unified terrain if it exists
	if unified_terrain:
		unified_terrain.queue_free()
		unified_terrain = null
	
	# Remove all chunks except the LevelGenerator itself and player
	# Doors are now part of chunks, so they'll be removed with chunks
	for child in get_children():
		if child != overview_camera and child != stored_player:
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

func generate_level() -> bool:
	print("\nStarting level generation...")
	var boss_type := get_boss_event_type(current_level)
	if boss_type != "":
		print("  Boss schedule: level ", current_level, " -> ", boss_type)
	
	# Clear previous level first (before calculating new width or initializing grid)
	clear_level()

	# Check level_config first before using it
	if not level_config:
		push_error("Level configuration not set!")
		return false
	
	# --- Calculate dynamic dimensions --- 
	current_grid_width = level_config.get_length_for_level(current_level)
	current_grid_height = BASE_GRID_HEIGHT + floor((current_level - 1) / 4) * 2 # Increase height by 2 every 4 levels
	print("  Calculated current_grid_width:", current_grid_width)
	print("  Calculated current_grid_height:", current_grid_height)
	
	# Door positions will be calculated after chunks are created
	# ------------------------------------

	# Make multiple attempts to generate a valid level if needed
	var max_attempts = 5 # Increased attempts slightly
	var attempt = 0

	while attempt < max_attempts:
		print("\n--- Attempt %d --- " % (attempt + 1))
		
		# Initialize grid AT THE START of each attempt
		grid = [] 
		for x in range(current_grid_width):
			grid.append([])
			for y in range(current_grid_height): # Use current_grid_height
				grid[x].append(GridCell.new())
		print("  Grid initialized for attempt. Size: ", grid.size(), "x", (grid[0].size() if grid.size() > 0 else 0))

		if generate_layout():
			# --- NEW STEP: Finalize connections AFTER layout is done ---
			finalize_connections() 
			# --- END NEW STEP ---
			
			# --- NEW STEP: Fill empty cells around paths with WALL type --- 
			fill_surrounding_walls()
			# --- END NEW STEP ---
			
			if populate_chunks():
				# Calculate door positions after chunks are created
				_calculate_door_positions()
				# Verify if there's a valid path from start to finish
				if verify_level_path():
					print("Level generated successfully on attempt %d!" % (attempt + 1))
					unify_terrain()  
					setup_level_transitions()
					spawn_player()
					return true # Success!
				else:
					print("Verification failed (no valid path), retrying...")
			else:
				print("Populate chunks failed, retrying...")
		else:
			print("Generate layout failed, retrying...")
		
		# Attempt failed, increment and loop (grid will be re-initialized)
		attempt += 1
		# Removed the explicit grid clearing/re-initialization from here

	print("\nFailed to generate level after ", max_attempts, " attempts!")
	return false # Explicitly return false if all attempts fail

func verify_level_path() -> bool:
	print("Verifying path from start to finish...")
	
	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
	
	# Find finish position (support both finish_chunk and boss_arena)
	var finish_pos = Vector2i.ZERO
	for x in range(current_grid_width - 1, -1, -1):
		for y in range(current_grid_height): # Use current_grid_height
			# Check if the cell has a chunk AND the chunk's scene path contains "finish_chunk"
			if grid[x][y].chunk and (grid[x][y].chunk.scene_file_path.contains("finish_chunk")
					or grid[x][y].chunk.scene_file_path.contains("boss_arena")):
				finish_pos = Vector2i(x, y)
				break
		if finish_pos != Vector2i.ZERO:
			break
	
	if finish_pos == Vector2i.ZERO:
		print("Finish/boss arena not found during verification!")
		return false
	
	print("Start position:", start_pos)
	print("Finish position:", finish_pos)
	
	# Do a BFS to find a path from start to finish
	var queue = [start_pos]
	var visited = {}
	visited[start_pos] = true
	var path_found = false
	
	while not queue.is_empty():
		var current = queue.pop_front()
		print("  BFS: Processing", current, "Connections:", grid[current.x][current.y].connections)
		
		# Check if we've reached the finish
		if current == finish_pos:
			print("  BFS: Reached Finish!")
			path_found = true
			break # Exit BFS loop
		
		# Add all connected neighbors
		for dir_enum in Direction.values():
			var dir = dir_enum # Use a distinct variable name
			# Check if the current cell has an outgoing connection in this direction
			if grid[current.x][current.y].connections[dir]:
				var next_pos = current + DIRECTION_VECTORS[dir]
				print("    BFS: Checking neighbor", next_pos, "in direction", dir)
				
				if is_valid_position(next_pos):
					# Check if neighbor hasn't been visited yet
					if not visited.has(next_pos):
						# Verify the connection is two-way (neighbor connects back)
						var opposite_dir = get_opposite_direction(dir)
						# Check if neighbor cell exists and has the reverse connection
						if grid[next_pos.x][next_pos.y].connections[opposite_dir]:
							print("      BFS: Valid neighbor found! Adding to queue.", "Neighbor connections:", grid[next_pos.x][next_pos.y].connections)
							queue.append(next_pos)
							visited[next_pos] = true
						else:
							print("      BFS: Neighbor %s does not connect back (Connections: %s). Skipping." % [str(next_pos), str(grid[next_pos.x][next_pos.y].connections)])
					else:
						print("      BFS: Neighbor %s already visited. Skipping." % str(next_pos))
				else:
					print("    BFS: Neighbor %s is outside grid bounds. Skipping." % str(next_pos))
			#else: # Optional: Log if current cell had no connection in this dir
			#	print("    BFS: No connection from current %s in direction %d" % [str(current), dir])
				
	# After BFS loop, check the result and return
	if path_found:
		print("Valid path found from start to finish!")
		return true # Return inside if
	else:
		print("No valid path found from start to finish after BFS!")
		return false # Return inside else
	
	# Fallback return to satisfy linter, should ideally never be reached
	# Keep this structure as the previous single return didn't help
	push_error("verify_level_path reached unexpected end point!") # Keep error for safety
	return false

func generate_layout() -> bool:
	print("\nPhase 1: Generating abstract layout...")
	
	# Get level-specific values
	var num_branches = level_config.get_num_branches_for_level(current_level)
	var num_dead_ends = level_config.get_num_dead_ends_for_level(current_level)
	var num_main_paths = level_config.get_num_main_paths_for_level(current_level)
	
	# Initialize path generator
	var path_gen = PathGenerator.new(current_grid_width, current_grid_height) # Use current_grid_height
	print("  Initialized PathGenerator with width:", current_grid_width)
	
	# Set start position
	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
	
	# Set up start position with proper connections
	# <<< START DEBUG >>>
	if grid[start_pos.x][start_pos.y].visited:
		push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(start_pos), grid[start_pos.x][start_pos.y].visited_by, "generate_layout_start"])
	# <<< END DEBUG >>>
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	grid[start_pos.x][start_pos.y].visited_by = "generate_layout_start" # Track visit
	# Make sure to explicitly set all connections for the start chunk - only RIGHT connection
	for dir_enum in Direction.values():
		set_grid_connection(start_pos, dir_enum, (dir_enum == Direction.RIGHT))
	
	# Randomize finish position with more vertical variation - WIDER RANGE
	# var finish_y = BASE_GRID_HEIGHT / 2 + (randi() % 5 - 2)  # Old: -2 to +2 from center
	var finish_y = randi() % (current_grid_height - 4) + 2 # New: Use range 2 to current_grid_height - 3 # Use current_grid_height
	var finish_pos = Vector2i(current_grid_width - 2, clamp(finish_y, 2, current_grid_height - 3)) # Clamp y # Use current_grid_height
	
	# Set up finish position with proper connections
	# <<< START DEBUG >>>
	if grid[finish_pos.x][finish_pos.y].visited:
		push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(finish_pos), grid[finish_pos.x][finish_pos.y].visited_by, "generate_layout_finish"])
	# <<< END DEBUG >>>
	grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
	grid[finish_pos.x][finish_pos.y].visited = true
	grid[finish_pos.x][finish_pos.y].visited_by = "generate_layout_finish" # Track visit
	# Set finish chunk connections (only left connection)
	for dir_enum in Direction.values():
		set_grid_connection(finish_pos, dir_enum, (dir_enum == Direction.LEFT))
	
	# Ensure the cell before finish has a right connection
	var pre_finish_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(pre_finish_pos):
		# <<< START DEBUG >>>
		if grid[pre_finish_pos.x][pre_finish_pos.y].visited:
			push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(pre_finish_pos), grid[pre_finish_pos.x][pre_finish_pos.y].visited_by, "generate_layout_pre_finish"])
		# <<< END DEBUG >>>
		grid[pre_finish_pos.x][pre_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[pre_finish_pos.x][pre_finish_pos.y].visited = true
		grid[pre_finish_pos.x][pre_finish_pos.y].visited_by = "generate_layout_pre_finish" # Track visit
		# Use set_grid_connection, setting all others to false implicitly if needed by the function
		# We only want RIGHT=true here, others false.
		set_grid_connection(pre_finish_pos, Direction.RIGHT, true)
		set_grid_connection(pre_finish_pos, Direction.LEFT, false)
		set_grid_connection(pre_finish_pos, Direction.UP, false)
		set_grid_connection(pre_finish_pos, Direction.DOWN, false)
	
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
			
		# Generate a new finish position with more vertical variation - WIDER RANGE
		var new_finish_x = current_grid_width - 2 - (i * 2)  # Space paths apart
		# var new_finish_y = BASE_GRID_HEIGHT / 2 + (randi() % 5 - 2)  # Old: More vertical variation
		var new_finish_y = randi() % (current_grid_height - 4) + 2 # New: Use range 2 to current_grid_height - 3 # Use current_grid_height
		var new_finish_pos = Vector2i(new_finish_x, clamp(new_finish_y, 2, current_grid_height - 3)) # Clamp y # Use current_grid_height
		
		# Set up connections for the new finish position
		# <<< START DEBUG >>>
		if grid[new_finish_pos.x][new_finish_pos.y].visited:
			push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(new_finish_pos), grid[new_finish_pos.x][new_finish_pos.y].visited_by, "generate_layout_new_finish"])
		# <<< END DEBUG >>>
		grid[new_finish_pos.x][new_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[new_finish_pos.x][new_finish_pos.y].visited = true
		grid[new_finish_pos.x][new_finish_pos.y].visited_by = "generate_layout_new_finish" # Track visit
		for dir_enum in Direction.values():
			# Set connections for the new finish position (only LEFT connection)
			set_grid_connection(new_finish_pos, dir_enum, (dir_enum == Direction.LEFT))
		
		# Ensure the cell before new finish has a right connection
		var pre_new_finish_pos = Vector2i(new_finish_pos.x - 1, new_finish_pos.y)
		if is_valid_position(pre_new_finish_pos):
			# <<< START DEBUG >>>
			if grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited:
				push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(pre_new_finish_pos), grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited_by, "generate_layout_pre_new_finish"])
			# <<< END DEBUG >>>
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].cell_type = CellType.MAIN_PATH
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited = true
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited_by = "generate_layout_pre_new_finish" # Track visit
			# Use set_grid_connection, setting all others to false implicitly if needed by the function
			# We only want RIGHT=true here, others false.
			set_grid_connection(pre_new_finish_pos, Direction.RIGHT, true)
			set_grid_connection(pre_new_finish_pos, Direction.LEFT, false)
			set_grid_connection(pre_new_finish_pos, Direction.UP, false)
			set_grid_connection(pre_new_finish_pos, Direction.DOWN, false)
		
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
	return Vector2i(2, current_grid_height / 2) # Use current_grid_height

func generate_main_path(start_pos: Vector2i, finish_pos: Vector2i, path_gen: PathGenerator) -> Array:
	var path_points = [] # Removed explicit type hint
	var waypoints = []
	waypoints.append(start_pos)
	
	# --- Assign unique ID for this path segment ---
	current_path_id_counter += 1
	var path_segment_id = current_path_id_counter
	# ---------------------------------------------
	
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
			# Check validity AND if not already visited (though less likely at this stage)
			if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
				continue_directions.append(dir)
		
		# If there are possible directions to continue, pick one and add to waypoints
		if not continue_directions.is_empty():
			var chosen_dir = continue_directions[randi() % continue_directions.size()]
			var next_pos = right_of_start + DIRECTION_VECTORS[chosen_dir]
			
			# Add the next waypoint if not already there
			if not waypoints.has(next_pos):
				waypoints.append(next_pos)
	
	# Add more intermediate waypoints for a more winding path
	var num_waypoints = randi() % 3 + 3  # 3-5 waypoints
	for i in range(num_waypoints):
		var x = start_pos.x + ((i + 1) * (finish_pos.x - start_pos.x)) / (num_waypoints + 1)
		# Add more vertical variation - WIDER RANGE
		# var y = BASE_GRID_HEIGHT / 2 + (randi() % 5 - 2)  # Old: -2 to +2 vertical variation
		var y = randi() % (current_grid_height - 4) + 2 # New: Use range 2 to current_grid_height - 3 # Use current_grid_height
		# Ensure waypoint is within bounds
		x = clamp(x, 1, current_grid_width - 2) # Prevent waypoints too close to edges
		y = clamp(y, 2, current_grid_height - 3) # Clamp y within the new wider range # Use current_grid_height
		waypoints.append(Vector2i(x, y))
	
	# Ensure path returns to finish height gradually
	var last_waypoint = waypoints[-1]
	if abs(last_waypoint.y - finish_pos.y) > 1: # Allow slightly more difference before forcing pre-finish
		var pre_finish_x = clamp(finish_pos.x - 2, 1, current_grid_width - 2)
		var pre_finish_y = clamp(finish_pos.y, 1, current_grid_height - 2) # Use current_grid_height
		var pre_finish = Vector2i(pre_finish_x, pre_finish_y)
		# Avoid duplicate waypoints
		if not waypoints.has(pre_finish):
			waypoints.append(pre_finish)
	# Avoid duplicate waypoints for finish
	if not waypoints.has(finish_pos):
		waypoints.append(finish_pos)
	
	# Generate path through waypoints using A*
	for i in range(waypoints.size() - 1):
		var start_node = waypoints[i]
		var end_node = waypoints[i + 1]
		
		# Ensure start and end nodes are valid before pathfinding
		if not is_valid_position(start_node) or not is_valid_position(end_node):
			push_warning("generate_main_path: Invalid waypoint pair %s -> %s. Skipping segment." % [str(start_node), str(end_node)])
			continue
			
		var path_segment = path_gen.astar.get_point_path(
			path_gen._get_point_index(start_node),
			path_gen._get_point_index(end_node)
		)
		
		# Iterate through points in the A* segment
		for j in range(path_segment.size()):
			# A* returns Vector2, convert to Vector2i
			var grid_pos = Vector2i(int(round(path_segment[j].x)), int(round(path_segment[j].y)))
			
			# Bounds check before accessing grid
			if not is_valid_position(grid_pos):
				push_error("!!! generate_main_path: A* returned invalid grid_pos %s. Skipping." % str(grid_pos))
				continue
				
			# --- Visited Check --- 
			# Skip marking/adding if ALREADY visited (prevents loops/overwrites)
			if grid[grid_pos.x][grid_pos.y].visited:
				# Optional: Log that we skipped a visited cell
				# print("  generate_main_path: Skipping already visited cell %s" % str(grid_pos))
				continue # Skip this point entirely
			# --- End Visited Check ---

			# Add to path_points list if it's a new, valid, unvisited point
			# (Consecutive duplicate check is less relevant now due to the visited check above)
			if path_points.is_empty() or path_points[-1] != grid_pos:
				path_points.append(grid_pos)
			
			# Mark the cell
			grid[grid_pos.x][grid_pos.y].cell_type = CellType.MAIN_PATH
			grid[grid_pos.x][grid_pos.y].visited = true
			grid[grid_pos.x][grid_pos.y].visited_by = "generate_main_path"
			grid[grid_pos.x][grid_pos.y].path_id = path_segment_id # Assign the ID

	# --- REMOVED CONNECTION SETTING LOGIC ---
	# Connection setting will be handled by finalize_connections() later

	# Existing return statement
	return path_points

func populate_chunks() -> bool:
	print("\nPhase 2: Populating with actual chunks...")
	
	# 1. Place start chunk first
	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
	if not place_chunk(start_pos, "start"):
		print("Failed to place start chunk")
		return false
	
	# 2. Find finish position AFTER layout & connection finalization
	var finish_pos = find_finish_position() # Use helper function
	if finish_pos == Vector2i.MAX:
		print("Failed to find a valid finish position for chunk placement!")
		# Attempt to find the rightmost MAIN_PATH cell as a fallback
		var fallback_finish = Vector2i.ZERO
		for x in range(current_grid_width - 1, -1, -1):
			for y in range(current_grid_height): # Use current_grid_height
				if grid[x][y].cell_type == CellType.MAIN_PATH:
					fallback_finish = Vector2i(x, y)
					break
			if fallback_finish != Vector2i.ZERO:
				break
		if fallback_finish != Vector2i.ZERO:
			print("Using fallback finish position: ", fallback_finish)
			finish_pos = fallback_finish
		else:
			print("Could not find any main path cell as fallback finish position.")
			return false # Cannot proceed without a finish position
		
	# Boss-aware finish placement
	var boss_event := get_boss_event_type(current_level)
	if boss_event == "mini":
		# On mini-boss levels, replace finish with boss arena directly at the finish position
		print("Mini-boss level: placing boss_arena at finish position ", finish_pos)
		if not place_chunk(finish_pos, "boss_arena"):
			print("Failed to place boss_arena at ", finish_pos)
			return false
	else:
		# Default behaviour: place finish chunk
		if not place_chunk(finish_pos, "finish"):
			print("Failed to place finish chunk at ", finish_pos)
			return false
		
	# Optional: tag special dead-end cells before main placement (light heuristic)
	_tag_villager_and_vip_deadends()

	# --- Simplified Main Population Loop --- 
	# Iterate through all grid cells once
	for x in range(current_grid_width):
		for y in range(current_grid_height): # Use current_grid_height
			var pos = Vector2i(x, y)
			var cell = grid[x][y]
			
			# Skip if empty, already has a chunk, or is the start/finish cell (already placed)
			# MODIFIED: Don't skip EMPTY initially, walls will be handled first
			# if cell.cell_type == CellType.EMPTY or cell.chunk != null or pos == start_pos or pos == finish_pos:
			# 	continue
			
			# --- Handle WALL cells FIRST --- 
			if cell.cell_type == CellType.WALL:
				if not place_chunk(pos, "full"):
					print("Failed to place WALL chunk 'full' at %s" % str(pos))
					# Decide if failure here should stop generation. Probably yes.
					return false 
				continue # Wall placed, move to next cell
			# --- END Handle WALL cells ---
			
			# Now handle the original skips for non-wall cells
			if cell.cell_type == CellType.EMPTY or cell.chunk != null or pos == start_pos or pos == finish_pos:
				continue

			# Check if the cell should have been part of the generated layout
			if not cell.visited:
				# This cell was likely isolated during layout, skip it
				# print("Skipping non-visited cell at", pos)
				continue
				
			# --- Determine chunk based on *connections*, not cell_type --- 
			# Use the existing select_appropriate_chunk function which relies on connections
			var chunk_type = select_appropriate_chunk(pos, cell)
			# Reserved override for special rooms (villager/vip)
			if not cell.reserved_chunk.is_empty():
				chunk_type = cell.reserved_chunk
			
			# <<< START DEBUG LOG >>>
			print(">>> populate_chunks: Checking cell at ", pos)
			print("    Cell Type (Layout): ", cell.cell_type)
			print("    Visited By: ", cell.visited_by)
			print("    Connections: [L:%s, R:%s, U:%s, D:%s]" % [
					str(cell.connections[Direction.LEFT]),
					str(cell.connections[Direction.RIGHT]),
					str(cell.connections[Direction.UP]),
					str(cell.connections[Direction.DOWN])
				])
			print("    Selected Chunk Type: '%s'" % chunk_type)
			# <<< END DEBUG LOG >>>
			
			if chunk_type.is_empty():
				push_error("Failed to select appropriate chunk for cell at %s. Connections L:%s R:%s U:%s D:%s" % [
					str(pos),
					str(cell.connections[Direction.LEFT]),
					str(cell.connections[Direction.RIGHT]),
					str(cell.connections[Direction.UP]),
					str(cell.connections[Direction.DOWN])
				])
				# Print neighbor connections too for debugging
				for dir_enum in Direction.values():
					var neighbor_pos = pos + DIRECTION_VECTORS[dir_enum]
					if is_valid_position(neighbor_pos):
						var n_cell = grid[neighbor_pos.x][neighbor_pos.y]
						print("      Neighbor %s (%s): Visited=%s, Chunk=%s, Connections=[L:%s, R:%s, U:%s, D:%s]" % [
							str(neighbor_pos), str(n_cell.cell_type), str(n_cell.visited), str(n_cell.chunk != null),
							str(n_cell.connections[Direction.LEFT]), str(n_cell.connections[Direction.RIGHT]),
							str(n_cell.connections[Direction.UP]), str(n_cell.connections[Direction.DOWN])
						])
					else:
						print("      Neighbor %s: Out of bounds" % str(neighbor_pos))
				return false # Stop generation if a required chunk cannot be selected
				
			# Place the selected chunk
			if not place_chunk(pos, chunk_type):
				print("Failed to place chunk '%s' at %s" % [chunk_type, str(pos)])
				return false # Stop generation if placement fails
				
	# --- End Simplified Loop ---
	
	# (Removed old loops for main_path, branch_path, dead_end)

	# Ensure finish chunk is still properly connected after all placements (as a safeguard)
	# This might be less necessary now but keep for safety
	if finish_pos != Vector2i.MAX: # Check if we found a valid finish pos
		var pre_finish_pos = finish_pos + DIRECTION_VECTORS[Direction.LEFT]
		if is_valid_position(pre_finish_pos) and grid[pre_finish_pos.x][pre_finish_pos.y].chunk:
			var pre_finish_cell = grid[pre_finish_pos.x][pre_finish_pos.y]
			var finish_cell = grid[finish_pos.x][finish_pos.y]
			# Explicitly set the final connection using the modified set_grid_connection
			set_grid_connection(pre_finish_pos, Direction.RIGHT, true)
			# Also ensure finish only connects LEFT (set_grid_connection handles this now)
			set_grid_connection(finish_pos, Direction.RIGHT, false)
			set_grid_connection(finish_pos, Direction.UP, false)
			set_grid_connection(finish_pos, Direction.DOWN, false)
			
			print("Re-verified connection to finish chunk from ", pre_finish_pos)

	return true  # Return true if we've successfully populated all required cells

func _tag_villager_and_vip_deadends() -> void:
	# Very light heuristic: mark some BRANCH/DEAD_END cells that have exactly one connection
	# as villager/vip dead-end rooms, with simple spacing rules.
	var deadends: Array[Vector2i] = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos := Vector2i(x, y)
			var c: GridCell = grid[x][y] as GridCell
			if not c.visited or c.chunk != null:
				continue
			if c.cell_type != CellType.DEAD_END and c.cell_type != CellType.BRANCH_PATH:
				continue
			var conn_count := 0
			for dir in Direction.values():
				if c.connections[dir]:
					conn_count += 1
			if conn_count != 1:
				continue
			# Keep away from start/finish/boss vicinity (simple x threshold)
			if pos.x <= 1:
				continue
			deadends.append(pos)

	deadends.shuffle()
	# Simple quotas; can be data-driven later
	var villager_quota := 1
	var vip_quota := 1

	for i in range(deadends.size()):
		var pos = deadends[i]
		var c: GridCell = grid[pos.x][pos.y] as GridCell
		if vip_quota > 0 and pos.x > current_grid_width - 5:
			# Prefer VIP deeper in the floor
			var dir_idx := _single_open_dir_index(c)
			# Only reserve horizontally connected dead-ends for LEFT/RIGHT variants
			if dir_idx == Direction.LEFT:
				c.reserved_chunk = "vip_dead_end_left"
			elif dir_idx == Direction.RIGHT:
				c.reserved_chunk = "vip_dead_end_right"
			else:
				# Vertical dead-ends are skipped for VIP; try another candidate
				continue
			vip_quota -= 1
			continue
		if villager_quota > 0:
			var dir_idx2 := _single_open_dir_index(c)
			# Only reserve horizontally connected dead-ends for LEFT/RIGHT variants
			if dir_idx2 == Direction.LEFT:
				c.reserved_chunk = "villager_dead_end_left"
			elif dir_idx2 == Direction.RIGHT:
				c.reserved_chunk = "villager_dead_end_right"
			else:
				# Vertical dead-ends are skipped for Villager; try another candidate
				continue
			villager_quota -= 1
			continue
		if villager_quota <= 0 and vip_quota <= 0:
			break

func _single_open_dir_index(c: GridCell) -> int:
	for d in Direction.values():
		if c.connections[d]:
			return d
	return Direction.LEFT

func select_appropriate_chunk(pos: Vector2i, cell: GridCell) -> String:
	# Special case for start position - always return "start"
	if pos == Vector2i(0, current_grid_height / 2): # Use current_grid_height
		return "start"
	
	# Special case for the position right after start - we need to be more flexible
	if pos == Vector2i(1, current_grid_height / 2): # Use current_grid_height
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
			if next_pos == Vector2i(0, current_grid_height / 2) and dir != Direction.LEFT: # Use current_grid_height
				required_connections[dir] = false
				cell.connections[dir] = false
	
	print("Required connections: ", required_connections)
	
	# Count total required connections
	var connection_count = 0
	for required in required_connections:
		if required:
			connection_count += 1
	
	# Check for the impossible case: a cell marked as part of a path but with 0 connections
	if connection_count == 0 and cell.cell_type != CellType.EMPTY:
		push_error("select_appropriate_chunk: Cell at %s is type %s but has 0 required connections! Layout generation error?" % [str(pos), str(cell.cell_type)])
		return "" # Cannot place a chunk here
	
	# Handle four-connection case first (four-way hub)
	if connection_count == 4:
		return "four_way_hub"
	
	# Handle single connection case (dead ends)
	if connection_count == 1:
		if required_connections[Direction.LEFT]:
			# If LEFT connection is required, use dead_end_right (LEFT closed)
			return "dead_end_right" 
		if required_connections[Direction.RIGHT]:
			# If RIGHT connection is required, use dead_end_left (RIGHT closed)
			return "dead_end_left" 
		if required_connections[Direction.UP]:
			# If UP connection is required, use dead_end_down (UP closed)
			return "dead_end_down"
		if required_connections[Direction.DOWN]:
			# If DOWN connection is required, use dead_end_up (DOWN closed)
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
		
		# Ensure chunk type exists in both dictionaries (or handle potential missing weights)
		if not CHUNK_WEIGHTS.has(chunk_type):
			# Decide how to handle chunks without weights: skip, default weight, error?
			# For now, let's skip them to be safe, but print a warning
			push_warning("Chunk type '%s' found in CHUNKS but not in CHUNK_WEIGHTS. Skipping." % chunk_type)
			continue
			
		var ports = CHUNKS[chunk_type]["ports"]
		var is_perfect_match = true
		
		# Check each direction for perfect match
		for dir in Direction.values():
			var connection_required = required_connections[dir]
			var port_is_open = (ports[dir] == Port.OPEN)
			
			# If connection is required, port must be open.
			# If connection is NOT required, port must be CLOSED.
			if connection_required != port_is_open:
				is_perfect_match = false
				break
		
		if is_perfect_match:
			valid_chunks.append(chunk_type)
	
	print("Perfectly valid chunks: ", valid_chunks)
	
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
	return pos.x >= 0 and pos.x < current_grid_width and pos.y >= 0 and pos.y < current_grid_height # Use current_grid_height

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
	print("\nAttempting to place chunk: " + chunk_type + " at position: " + str(pos)) # Improved logging

	# Check if position is valid first
	if not is_valid_position(pos):
		push_error("Invalid position provided to place_chunk: " + str(pos))
		return false

	# Check if a chunk ALREADY exists at this grid location
	if grid[pos.x][pos.y].chunk != null:
		push_error("DUPLICATE CHUNK ERROR: Cannot place chunk '%s' at %s. Chunk '%s' (%s) already exists!" % \
					[chunk_type, str(pos), grid[pos.x][pos.y].chunk.name, grid[pos.x][pos.y].chunk.scene_file_path])
		return false # Crucial: Prevent placing a duplicate chunk

	# Check if chunk type is valid
	if not CHUNKS.has(chunk_type):
		push_error("Invalid chunk type provided to place_chunk: " + chunk_type) # Changed to error
		return false

	var chunk_data = CHUNKS[chunk_type]
	# Random scene selection should be safe
	var scene_path = chunk_data["scenes"][randi() % chunk_data["scenes"].size()]
	var chunk_scene = load(scene_path)

	if not chunk_scene:
		push_error("Failed to load chunk scene: " + scene_path) # Changed to error
		return false

	var chunk = chunk_scene.instantiate()
	if not chunk:
		push_error("Failed to instantiate chunk scene: " + scene_path) # Changed to error
		return false

	# Removed the suppression of warnings, as it might hide other issues.
	# It was related to tilemap errors, which might be resolved or need addressing separately.
	# var prev_error_prints = ProjectSettings.get_setting("...")
	# ProjectSettings.set_setting("...", false)

	add_child(chunk)
	chunk.position = grid_to_world(pos)

	# ProjectSettings.set_setting("...", prev_error_prints)

	grid[pos.x][pos.y].chunk = chunk # Assign the new chunk to the grid

	# Extra setup for boss arenas (mini-boss levels)
	if chunk_type == "boss_arena":
		# Add a dedicated spawner to this arena and wire up finish enabling after defeat
		var spawner_scene: PackedScene = load("res://enemy/enemy_spawner.tscn")
		if spawner_scene:
			var spawner: Node2D = spawner_scene.instantiate()
			spawner.name = "MiniBossSpawner"
			# Configure basic params
			if spawner.has_method("set"): # safe set
				spawner.set("auto_spawn", true)
				spawner.set("spawn_on_level_start", false)
				# Replace spawner usage with direct miniboss scene instantiation
				pass
			# Directly instantiate Shield Captain miniboss
			var mini_scene_path := "res://enemy/miniboss/shield_captain/shield_captain.tscn"
			var mini_scene: PackedScene = load(mini_scene_path)
			if mini_scene:
				print("[BossArena] Instantiating miniboss from ", mini_scene_path)
				var mini = mini_scene.instantiate()
				mini.name = "MiniBoss_ShieldCaptain"
				chunk.add_child(mini)
				mini.global_position = chunk.global_position + Vector2(960, 600)
				# Wire defeat → enable finish
				if mini.has_signal("enemy_defeated"):
					mini.connect("enemy_defeated", Callable(self, "_on_miniboss_defeated").bind(chunk))
				# Defer boss bar attachment to ensure UI is ready
				var _mini_ref = mini
				get_tree().create_timer(0.05).timeout.connect(func(): _attach_boss_bar(_mini_ref))
			else:
				push_error("[BossArena] Failed to load miniboss scene at path: " + mini_scene_path)

	# TileMap tabanlı dekorasyonları oluştur
	_populate_decorations_from_tilemap(chunk)
	
	# Remove old EnemySpawner nodes from chunk (legacy system)
	_remove_legacy_enemy_spawners(chunk)
	
	# TileMap tabanlı düşmanları oluştur
	_populate_enemies_from_tilemap(chunk)

	print("Successfully placed " + chunk_type + " at " + str(pos)) # Improved logging
	return true

func _populate_decorations_from_tilemap(chunk_node: Node2D) -> void:
	# Kullanıcının belirttiği gibi, tüm chunk'larda TileMap'in adı "TileMapLayer".
	# Bu yüzden doğrudan bu ismi aramak en verimli yöntem.
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)

	if not tile_map:
		print("[DecorPopulate] SKIPPING: Chunk '%s' does not have a child node named 'TileMapLayer'." % chunk_node.name)
		return

	var config = DecorationConfig.new()
	var tile_set = tile_map.tile_set
	if not tile_set:
		push_warning("TileMap in '%s' has no TileSet." % chunk_node.name)
		return

	var decor_layer_name = "decor_anchor"
	var decor_layer_index = -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == decor_layer_name:
			decor_layer_index = i
			break
	if decor_layer_index == -1:
		print("[DecorPopulate] SKIPPING: TileSet in chunk '%s' does not have a custom data layer named '%s'." % [chunk_node.name, decor_layer_name])
		return

	var used_cells = tile_map.get_used_cells()
	var found_data_count = 0

	for cell in used_cells:
		var tile_data = tile_map.get_cell_tile_data(cell)
		if not tile_data:
			continue
		var custom_data = tile_data.get_custom_data(decor_layer_name)
		# print("DEBUG: cell=", cell, " custom_data=", custom_data)
		# print("DEBUG: rules for ", custom_data, " = ", rules)
		if not custom_data:
			continue
		var rules = config.PRIORITY_DECOR_RULES.get(custom_data, null)
		# print("DEBUG: rules for ", custom_data, " = ", rules)
		if not rules:
			continue
		found_data_count += 1

		# --- Hiyerarşik kural sistemi ---
		for rule in rules:
			# Global kural: Chunk'ın en dış sınırındaki tile'larda dekor spawn etme
			if _is_on_chunk_outer_boundary(tile_map, cell):
				continue
			# Ek güvenlik: Hücre chunk'ın piksel bazlı güvenli alanının dışında mı?
			if not _is_cell_within_chunk_safe_bounds(tile_map, cell, chunk_node, 160.0):
				continue
			if rule.is_empty():
				continue
			if randf() < rule.chance:
				# Kuralda izin verilen ve lokasyona uygun dekorları filtrele
				var decoration_pool = config.get_decorations_for_type(rule.decoration_type)
				var valid_decors = []
				for decor_name in rule.decoration_names:
					if decor_name in decoration_pool:
						valid_decors.append(decor_name)
				if valid_decors.is_empty():
					if "gate1" in rule.decoration_names:
						print("[GateDebug] valid_decors EMPTY at tile=", cell, " rule_names=", rule.decoration_names)
					if custom_data == "ceiling_surface" or custom_data == "wall_surface":
						print("[WebDebug] Tile ", cell, " tag=", custom_data, " → valid_decors EMPTY (pool=", decoration_pool, ")")
					continue
				var selected_decor_name = valid_decors.pick_random()
				if selected_decor_name == "gate1":
					print("[GateDebug] SELECT tile=", cell, " names=", valid_decors)
				if custom_data == "ceiling_surface" or custom_data == "wall_surface":
					print("[WebDebug] Tile ", cell, " tag=", custom_data, " pool=", decoration_pool, " valid=", valid_decors, " selected=", selected_decor_name)
				var spawner = DecorationSpawner.new()
				# Add spawner to scene tree temporarily for door proximity check
				add_child(spawner)
				
				var did_spawn = false
				var decoration_instance = spawner.create_decoration_instance(selected_decor_name, rule.decoration_type)
				# Derive spawn location first for edge filtering
				var spawn_loc: int = _derive_spawn_location_from_tile_data(custom_data, rule)
				# Optional clearance check for larger decorations
				var needs_clearance: bool = false
				var w_tiles: int = 1
				var h_tiles: int = 1
				var grow_dir: String = "up"
				if selected_decor_name in decoration_pool:
						var dd: Dictionary = decoration_pool.get(selected_decor_name, {})
						if dd.has("width_tiles") and dd.width_tiles is int:
							needs_clearance = true
							w_tiles = int(dd.width_tiles)
						if dd.has("height_tiles") and dd.height_tiles is int:
							needs_clearance = true
							h_tiles = int(dd.height_tiles)
						if dd.has("grow_dir") and dd.grow_dir is String:
							grow_dir = String(dd.grow_dir)
				if needs_clearance:
						# Ensure base support uses at least the visual width in tiles
						var vis_size_nc: Vector2 = _get_visual_size_from_instance(decoration_instance)
						var tile_w_nc: float = float(tile_map.tile_set.tile_size.x)
						if tile_w_nc > 0.0:
							var vis_tiles_nc: int = int(ceil(vis_size_nc.x / tile_w_nc))
							if vis_tiles_nc > w_tiles:
								w_tiles = vis_tiles_nc
						if selected_decor_name == "gate1":
							print("[GateDebug] CLEARANCE footprint=", w_tiles, "x", h_tiles, " grow_dir=", grow_dir)
						var anchor: Vector2i = cell
						var dbg: bool = (selected_decor_name == "gate1" or selected_decor_name == "box2")
						if not _has_clearance_tiles(tile_map, anchor, w_tiles, h_tiles, grow_dir, spawn_loc, dbg, selected_decor_name):
							if selected_decor_name == "gate1":
								print("[GateDebug] FAIL clearance at tile=", cell)
							decoration_instance.queue_free()
							spawner.queue_free()
							continue
						# Background support check for pipes/gates only
						if selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "gate1" or selected_decor_name == "gate2":
							var bg_map: TileMap = _find_background_tilemap(chunk_node)
							if not _has_background_support(bg_map, anchor, w_tiles, h_tiles, grow_dir, dbg, selected_decor_name):
								decoration_instance.queue_free()
								spawner.queue_free()
								continue
						# Additional wall collision guard only for non-floor placements
						var floor_based := (spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CENTER or spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CORNER)
						if not floor_based:
							if _footprint_overlaps_wall(tile_map, anchor, w_tiles, h_tiles, grow_dir, spawn_loc):
								if selected_decor_name == "gate1":
									print("[GateDebug] FAIL border overlap at tile=", cell)
								decoration_instance.queue_free()
								spawner.queue_free()
								continue
				# Skip cells near open chunk edges for floor-like placements
				if _is_near_open_chunk_edge(tile_map, cell, chunk_node, spawn_loc, rule):
					if custom_data == "ceiling_surface" or custom_data == "wall_surface":
						print("[WebDebug] SKIP near edge tile=", cell, " name=", selected_decor_name, " spawn_loc=", spawn_loc)
					decoration_instance.queue_free()
					spawner.queue_free()
					continue
				# Avoid outside L-shaped dead zones
				if _is_outside_L_deadzone(tile_map, cell, spawn_loc):
					if custom_data == "ceiling_surface" or custom_data == "wall_surface":
						print("[WebDebug] SKIP outside L deadzone tile=", cell, " name=", selected_decor_name, " spawn_loc=", spawn_loc)
					decoration_instance.queue_free()
					spawner.queue_free()
					continue
				add_child(decoration_instance)
				# Keep the spawner alive as a child so signal targets remain valid
				# (create_decoration_instance connects signals to spawner methods)
				add_child(spawner)
				var spawn_pos: Vector2 = _compute_decoration_spawn_position(tile_map, cell, spawn_loc)
				
				# Check door proximity for gate, pipe and banner decorations (GERÇEK spawn pozisyonu ile)
				if selected_decor_name in ["gate1", "gate2", "pipe1", "pipe2", "banner1"]:
					var is_too_close = false
					if selected_decor_name == "banner1":
						is_too_close = spawner._is_near_door_banner(spawn_pos)
					else:
						is_too_close = spawner._is_near_door(spawn_pos)
					
					if is_too_close:
						decoration_instance.queue_free()
						spawner.queue_free()
						continue
				
				# For clearance-based floor decors (box2, gate1), cancel global left bias to stay tile-aligned
				if needs_clearance and (spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CENTER or spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CORNER):
					# Align X to exact multi-tile floor span center
					var tile_size_v2: Vector2 = Vector2(tile_map.tile_set.tile_size)
					var half_w_left := int(floor((w_tiles - 1) / 2.0))
					var left_cell: Vector2i = cell + Vector2i(-half_w_left, 0)
					var right_cell: Vector2i = left_cell + Vector2i(w_tiles - 1, 0)
					var left_center: Vector2 = tile_map.to_global(tile_map.map_to_local(left_cell)) + tile_size_v2 / 2.0
					var right_center: Vector2 = tile_map.to_global(tile_map.map_to_local(right_cell)) + tile_size_v2 / 2.0
					var before := spawn_pos.x
					spawn_pos.x = (left_center.x + right_center.x) * 0.5
					if selected_decor_name == "gate1" or selected_decor_name == "box2":
						print("[GateDebug] ALIGN cells=", left_cell, "..", right_cell, " left_center=", left_center.x, " right_center=", right_center.x, " beforeX=", before, " afterX=", spawn_pos.x)
				# For clearance-based floor decors (box2, gate1), remove previous upward lift
				var floor_based := (spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CENTER or spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CORNER)
				# No extra vertical offset; sprite bottom alignment will sit on floor
				# Safety: skip placements that would hang over edges (half in air or inside wall)
				var dec_type: String = ""
				if decoration_instance.has_meta("decoration_type"):
					dec_type = String(decoration_instance.get_meta("decoration_type"))
				var needs_support: bool = (spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CENTER \
					or spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CORNER)
				if needs_support and (dec_type == "gold" or dec_type == "breakable" or dec_type == "background"):
					var vis_size: Vector2 = _get_visual_size_from_instance(decoration_instance)
					var tile_w: float = float(tile_map.tile_set.tile_size.x)
					var half_w: float = min(max(4.0, vis_size.x * 0.5), tile_w * 0.45)
					if needs_clearance:
						# For clearance-based decors, we already verified base support tile-by-tile; skip span search
						pass
					else:
						var adj: Dictionary = _find_supported_position(spawn_pos, half_w, 12.0, 3.0)
						if selected_decor_name == "gate1" or selected_decor_name == "box2":
							print("[GateDebug] SUPPORT half_w=", half_w, " spawn_pos=", spawn_pos, " adj=", adj)
						if adj.has("ok") and bool(adj.ok):
							spawn_pos = adj.pos
				# Global fine-tune: only a slight vertical settle for small decors; no extra X nudge
				var final_pos := spawn_pos
				if not needs_clearance:
					final_pos = spawn_pos + Vector2(0, 5)
				
				# Set position for ALL decorations (not just gates/pipes)
				decoration_instance.global_position = final_pos
				
				# Prevent overlapping large decors: gates/pipes/banners/sculptures
				if (selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "banner1" or selected_decor_name == "sculpture1") and (_is_near_gate_pos_list(final_pos, float(tile_map.tile_set.tile_size.x) * 5.0) or _is_near_existing_gate(final_pos, float(tile_map.tile_set.tile_size.x) * 5.0)):
					print("[GateDebug] SKIP overlap near existing gate at pos=", final_pos)
					decoration_instance.queue_free()
					spawner.queue_free()
					# do not mark placed; allow next rules to try
					continue
				if selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "box2":
					print("[GateDebug] FINAL_POS ", selected_decor_name, " at ", final_pos)
					# Compute visual vs tile-span extents for precise debug
					var vis_sz: Vector2 = _get_visual_size_from_instance(decoration_instance)
					var tile_size_dbg: Vector2 = Vector2(tile_map.tile_set.tile_size)
					var half_w_left_dbg := int(floor((w_tiles - 1) / 2.0))
					var left_cell_dbg: Vector2i = cell + Vector2i(-half_w_left_dbg, 0)
					var right_cell_dbg: Vector2i = left_cell_dbg + Vector2i(w_tiles - 1, 0)
					var left_center_dbg: Vector2 = tile_map.to_global(tile_map.map_to_local(left_cell_dbg)) + tile_size_dbg / 2.0
					var right_center_dbg: Vector2 = tile_map.to_global(tile_map.map_to_local(right_cell_dbg)) + tile_size_dbg / 2.0
					var span_left_x: float = left_center_dbg.x - tile_size_dbg.x * 0.5
					var span_right_x: float = right_center_dbg.x + tile_size_dbg.x * 0.5
					var sprite_left_x: float = final_pos.x - vis_sz.x * 0.5
					var sprite_right_x: float = final_pos.x + vis_sz.x * 0.5
					var diff_left := sprite_left_x - span_left_x
					var diff_right := span_right_x - sprite_right_x
					print("[GateDebug] EXTENTS ", selected_decor_name, " sprite_left=", sprite_left_x, " sprite_right=", sprite_right_x,
						" span_left=", span_left_x, " span_right=", span_right_x,
						" diff_left=", diff_left, " diff_right=", diff_right)
					# Y taban hizası: zemin çizgisi vs sprite altı
					var floor_center_dbg: Vector2 = (left_center_dbg + right_center_dbg) * 0.5
					var floor_line_y: float = floor_center_dbg.y + tile_size_dbg.y * 0.5
					var expected_bottom_y: float = floor_line_y + 5.0
					var sprite_bottom_y: float = final_pos.y + vis_sz.y * 0.5
					var diff_bottom_y: float = expected_bottom_y - sprite_bottom_y
					print("[GateDebug] EXTENTS_Y ", selected_decor_name,
						" sprite_bottom=", sprite_bottom_y,
						" expected_bottom=", expected_bottom_y,
						" diff_bottom=", diff_bottom_y)
				# Track placed large decor positions to avoid same-pass overlaps
				if selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "banner1" or selected_decor_name == "sculpture1":
					placed_gate_positions.append(final_pos)
				if selected_decor_name == "gate1":
					print("[GateDebug] SPAWNED at ", decoration_instance.global_position, " floor_based=", floor_based)
				if custom_data == "ceiling_surface" or custom_data == "wall_surface":
					print("[WebDebug] SPAWNED ", selected_decor_name, " at ", decoration_instance.global_position)
				print("[DecorPopulate] SUCCESS: Spawned decoration '%s' at tile %s (world pos: %s)" % [selected_decor_name, cell, decoration_instance.global_position])
				did_spawn = true
				# Do not free spawner here; it holds signal handlers for the decoration
				if did_spawn:
					break # Bir kural tuttuysa diğerlerini deneme
	
	if found_data_count > 0:
		pass # print("[DecorPopulate] INFO: Finished chunk '%s'. Found %d tiles with '%s' data." % [chunk_node.name, found_data_count, decor_layer_name])

# --- Decoration spawn alignment helpers ---
# Derive a reasonable spawn location based on tile tag and rule
func _derive_spawn_location_from_tile_data(custom_data: String, rule: Dictionary) -> int:
	# If rule explicitly provides allowed_locations, prefer one of them
	if rule and rule.has("allowed_locations") and rule.allowed_locations is Array and not rule.allowed_locations.is_empty():
		return rule.allowed_locations.pick_random()

	# Fallbacks based on tile custom data tag
	match custom_data:
		"floor_surface", "floor", "floor_breakable":
			return DecorationConfig.SpawnLocation.FLOOR_CENTER
		"ceiling_surface":
			return DecorationConfig.SpawnLocation.CEILING
		"wall_surface":
			# Choose one to vary visuals
			return [DecorationConfig.SpawnLocation.WALL_LOW, DecorationConfig.SpawnLocation.WALL_HIGH].pick_random()
		"corner_high":
			return DecorationConfig.SpawnLocation.CORNER_HIGH
		"corner_low":
			return DecorationConfig.SpawnLocation.CORNER_LOW
		_:
			return DecorationConfig.SpawnLocation.FLOOR_CENTER

# Compute a world position aligned to tile edges based on spawn location
func _compute_decoration_spawn_position(tile_map, cell: Vector2i, spawn_loc: int) -> Vector2:
	var tile_size_v2: Vector2 = Vector2(tile_map.tile_set.tile_size)
	var tile_center: Vector2 = tile_map.to_global(tile_map.map_to_local(cell)) + tile_size_v2 / 2.0
	var floor_offset_y := 20.0
	var fudge_y := 2.0
	var fudge_x := 2.0
	# Horizontal bias: consistent global left shift to avoid right-edge hanging
	var bias_x := -8.0

	var top_center := tile_center + Vector2(0, -tile_size_v2.y / 2.0)
	var bottom_center := tile_center + Vector2(0, tile_size_v2.y / 2.0)
	var mid_left := tile_center + Vector2(-tile_size_v2.x / 2.0, 0)
	var mid_right := tile_center + Vector2(tile_size_v2.x / 2.0, 0)
	var top_left := tile_center + Vector2(-tile_size_v2.x / 2.0, -tile_size_v2.y / 2.0)
	var top_right := tile_center + Vector2(tile_size_v2.x / 2.0, -tile_size_v2.y / 2.0)
	var bottom_left := tile_center + Vector2(-tile_size_v2.x / 2.0, tile_size_v2.y / 2.0)
	var bottom_right := tile_center + Vector2(tile_size_v2.x / 2.0, tile_size_v2.y / 2.0)

	match spawn_loc:
		DecorationConfig.SpawnLocation.FLOOR_CENTER:
			# Place slightly above the floor (towards air)
			return top_center + Vector2(bias_x, -floor_offset_y)
		DecorationConfig.SpawnLocation.FLOOR_CORNER:
			# Prefer inner corner (avoid outside of L-shaped dead zones)
			var prefer_left := _has_vertical_wall_on_right(tile_map, cell)
			var prefer_right := _has_vertical_wall_on_left(tile_map, cell)
			if prefer_left and not prefer_right:
				return top_left + Vector2(bias_x, -floor_offset_y)
			elif prefer_right and not prefer_left:
				# Nudge inward from the right edge
				return top_right + Vector2(bias_x, -floor_offset_y)
			else:
				var corner = [top_left, top_right].pick_random()
				return corner + Vector2(bias_x, -floor_offset_y)
		DecorationConfig.SpawnLocation.CEILING:
			return bottom_center + Vector2(0, fudge_y)
		DecorationConfig.SpawnLocation.WALL_LOW:
			# Approximate lower half of wall
			return tile_center + Vector2(0, tile_size_v2.y * 0.25)
		DecorationConfig.SpawnLocation.WALL_HIGH:
			# Approximate upper half of wall
			return tile_center + Vector2(0, -tile_size_v2.y * 0.25)
		DecorationConfig.SpawnLocation.CORNER_HIGH:
			var high_corner = [top_left, top_right].pick_random()
			return high_corner + Vector2(fudge_x, -fudge_y)
		DecorationConfig.SpawnLocation.CORNER_LOW:
			var low_corner = [bottom_left, bottom_right].pick_random()
			return low_corner + Vector2(fudge_x, fudge_y)
		_:
			# Safe fallback similar to previous behavior but slightly above center
			return tile_center + Vector2(0, -tile_size_v2.y * 0.25)

# Ensure rectangular empty space around anchor based on footprint and growth direction
func _has_clearance_tiles(tile_map, anchor: Vector2i, w_tiles: int, h_tiles: int, grow_dir: String, spawn_loc: int, dbg: bool = false, name: String = "") -> bool:
	var offsets: Array[Vector2i] = []
	var half_w_left := int(floor((w_tiles - 1) / 2.0))
	var half_w_right := w_tiles - 1 - half_w_left
	match grow_dir:
		"up":
			for dy in range(1, h_tiles + 1):
				for dx in range(-half_w_left, half_w_right + 1):
					offsets.append(Vector2i(dx, -dy))
		"down":
			for dy in range(1, h_tiles + 1):
				for dx in range(-half_w_left, half_w_right + 1):
					offsets.append(Vector2i(dx, dy))
		"out":
			var nx := 1
			var ny := 0
			if spawn_loc == DecorationConfig.SpawnLocation.WALL_LOW or spawn_loc == DecorationConfig.SpawnLocation.WALL_HIGH:
				# Heuristic: assume outward is to the right for now
				nx = 1; ny = 0
			for i in range(1, w_tiles + 1):
				for j in range(0, h_tiles):
					offsets.append(Vector2i(nx * i, -j))
		_:
			# Default to up
			for dy in range(1, h_tiles + 1):
				for dx in range(-half_w_left, half_w_right + 1):
					offsets.append(Vector2i(dx, -dy))
	for off in offsets:
		var c := anchor + off
		if _get_cell_source_id_any(tile_map, c) != -1:
			if dbg:
				print("[GateDebug] OCCUPIED at ", c, " for ", name)
			return false
	# Additional side clearance on the right to avoid hugging walls for wide floor decors
	if grow_dir == "up" and (name == "box2" or name == "gate1"):
		var half_w_left_side := int(floor((w_tiles - 1) / 2.0))
		var half_w_right_side := int(ceil((w_tiles - 1) / 2.0))
		var right_pad_x := half_w_right_side + 1
		for dy in range(1, h_tiles + 1):
			var right_nei := anchor + Vector2i(right_pad_x, -dy)
			if tile_map.get_cell_source_id(right_nei) != -1:
				if dbg:
					print("[GateDebug] SIDE_RIGHT_OCCUPIED at ", right_nei, " for ", name)
				return false
	# For floor-based growth, ensure all supporting floor tiles directly below footprint are solid
	if grow_dir == "up":
		# Base row must be fully walkable/solid across the footprint
		for dx in range(-half_w_left, half_w_right + 1):
			var base := anchor + Vector2i(dx, 0)
			if tile_map.get_cell_source_id(base) == -1:
				if dbg:
					print("[GateDebug] BASE_GAP at ", base, " for ", name)
				return false
		# Require at least 1 extra floor tile padding on both left and right of the footprint
		var left_pad := anchor + Vector2i(-half_w_left - 1, 0)
		var right_pad := anchor + Vector2i(half_w_right + 1, 0)
		if tile_map.get_cell_source_id(left_pad) == -1 or tile_map.get_cell_source_id(right_pad) == -1:
			if dbg:
				print("[GateDebug] EDGE_TOO_CLOSE left_pad=", left_pad, " right_pad=", right_pad, " for ", name)
			return false
		for dx in range(-half_w_left, half_w_right + 1):
			var below := anchor + Vector2i(dx, 1)
			if _get_cell_source_id_any(tile_map, below) == -1:
				if dbg:
					print("[GateDebug] NO SUPPORT below ", below, " for ", name)
				return false
	return true

# Background support: ensure background TileMap has tiles behind the footprint
func _has_background_support(bg_map, anchor: Vector2i, w_tiles: int, h_tiles: int, grow_dir: String, dbg: bool, name: String) -> bool:
	if bg_map == null:
		return true
	var half_w_left := int(floor((w_tiles - 1) / 2.0))
	var half_w_right := int(ceil((w_tiles - 1) / 2.0))
	var offsets: Array[Vector2i] = []
	match grow_dir:
		"up":
			for dy in range(0, h_tiles):
				for dx in range(-half_w_left, half_w_right + 1):
					offsets.append(Vector2i(dx, -dy))
		_:
			for dy in range(0, h_tiles):
				for dx in range(-half_w_left, half_w_right + 1):
					offsets.append(Vector2i(dx, -dy))
	for off in offsets:
		var c := anchor + off
		if _get_cell_source_id_any(bg_map, c) == -1:
			if dbg:
				print("[BgCheck] NO_BG at ", c, " for ", name)
			return false
	return true

# Check if the rectangular footprint touches any solid tile around its border
func _footprint_overlaps_wall(tile_map, anchor: Vector2i, w_tiles: int, h_tiles: int, grow_dir: String, spawn_loc: int) -> bool:
	var border: Array[Vector2i] = []
	var half_w_left: int = int(floor((w_tiles - 1) / 2.0))
	var half_w_right: int = w_tiles - 1 - half_w_left
	# Compute footprint cells (relative to anchor) depending on growth
	var cells: Array[Vector2i] = []
	match grow_dir:
		"up":
			for dy in range(0, h_tiles):
				for dx in range(-half_w_left, half_w_right + 1):
					cells.append(Vector2i(dx, -dy))
		"down":
			for dy in range(0, h_tiles):
				for dx in range(-half_w_left, half_w_right + 1):
					cells.append(Vector2i(dx, dy))
		_:
			for dy in range(0, h_tiles):
				for dx in range(-half_w_left, half_w_right + 1):
					cells.append(Vector2i(dx, -dy))
	# Build a 1-tile-thick border around these cells
	var neighbor_dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var seen: Dictionary = {}
	for c in cells:
		for d in neighbor_dirs:
			var b: Vector2i = c + d
			if not seen.has(b):
				seen[b] = true
				border.append(b)
	# If any border cell is solid, we consider overlap risky
	for off in border:
		# Do not treat the supporting floor as an overlapping wall
		if grow_dir == "up":
			if off.y == 1 and off.x >= -half_w_left and off.x <= half_w_right:
				continue
		elif grow_dir == "down":
			if off.y == -1 and off.x >= -half_w_left and off.x <= half_w_right:
				continue
		var check: Vector2i = anchor + off
		if tile_map.get_cell_source_id(check) != -1:
			return true
	return false

# Strict boundary rule: returns true if cell lies on the outermost tile ring of the chunk
func _is_on_chunk_outer_boundary(tile_map, cell: Vector2i) -> bool:
	var used_rect: Rect2i = tile_map.get_used_rect()
	var left_x := used_rect.position.x
	var right_x := used_rect.position.x + used_rect.size.x - 1
	var top_y := used_rect.position.y
	var bottom_y := used_rect.position.y + used_rect.size.y - 1
	# Outer boundary margin (tiles). Increased to be stricter against dead-zones
	var margin := 4
	return cell.x <= left_x + margin or cell.x >= right_x - margin or cell.y <= top_y + margin or cell.y >= bottom_y - margin

# Pixel-based check: ensure the tile's local position within its chunk is away from the outer bounds
func _is_cell_within_chunk_safe_bounds(tile_map, cell: Vector2i, chunk_node: Node2D, margin_px: float) -> bool:
	var chunk := chunk_node as Node2D
	if not chunk:
		return true
	var cell_local_in_tilemap: Vector2 = tile_map.map_to_local(cell)
	var cell_global: Vector2 = tile_map.to_global(cell_local_in_tilemap)
	var cell_local_in_chunk: Vector2 = chunk.to_local(cell_global)
	var chunk_size: Vector2 = CHUNK_SIZE
	if chunk.has_method("get_chunk_size"):
		chunk_size = chunk.call("get_chunk_size")
	return cell_local_in_chunk.x >= margin_px and cell_local_in_chunk.x <= (chunk_size.x - margin_px) and cell_local_in_chunk.y >= margin_px and cell_local_in_chunk.y <= (chunk_size.y - margin_px)

# Returns true if the tile cell is within a margin of an OPEN edge of its chunk
func _is_near_open_chunk_edge(tile_map, cell: Vector2i, chunk_node: Node2D, spawn_loc: int, rule: Dictionary) -> bool:
	# Apply to ALL decoration types to avoid dead zones along chunk seams
	var check_any := true

	var used_rect: Rect2i = tile_map.get_used_rect()
	var left_x := used_rect.position.x
	var right_x := used_rect.position.x + used_rect.size.x - 1
	var top_y := used_rect.position.y
	var bottom_y := used_rect.position.y + used_rect.size.y - 1
	var EDGE_MARGIN_TILES := 4

	var near_left := (cell.x - left_x) < EDGE_MARGIN_TILES
	var near_right := (right_x - cell.x) < EDGE_MARGIN_TILES
	var near_top := (cell.y - top_y) < EDGE_MARGIN_TILES
	var near_bottom := (bottom_y - cell.y) < EDGE_MARGIN_TILES

	# Determine grid position of this chunk to check neighbors
	var grid_pos := _find_grid_pos_for_chunk(chunk_node)
	if grid_pos == Vector2i(-1, -1):
		return false

	var has_left_neighbor := is_valid_position(grid_pos + DIRECTION_VECTORS[Direction.LEFT]) and grid[grid_pos.x + DIRECTION_VECTORS[Direction.LEFT].x][grid_pos.y + DIRECTION_VECTORS[Direction.LEFT].y].chunk != null
	var has_right_neighbor := is_valid_position(grid_pos + DIRECTION_VECTORS[Direction.RIGHT]) and grid[grid_pos.x + DIRECTION_VECTORS[Direction.RIGHT].x][grid_pos.y + DIRECTION_VECTORS[Direction.RIGHT].y].chunk != null
	var has_top_neighbor := is_valid_position(grid_pos + DIRECTION_VECTORS[Direction.UP]) and grid[grid_pos.x + DIRECTION_VECTORS[Direction.UP].x][grid_pos.y + DIRECTION_VECTORS[Direction.UP].y].chunk != null
	var has_bottom_neighbor := is_valid_position(grid_pos + DIRECTION_VECTORS[Direction.DOWN]) and grid[grid_pos.x + DIRECTION_VECTORS[Direction.DOWN].x][grid_pos.y + DIRECTION_VECTORS[Direction.DOWN].y].chunk != null

	# If there is a neighbor on that side AND the cell is near that edge, skip spawn
	if has_top_neighbor and near_top:
		return true
	if has_bottom_neighbor and near_bottom:
		return true
	if has_left_neighbor and near_left:
		return true
	if has_right_neighbor and near_right:
		return true

	return false

# New rule: avoid outside corners of L shapes.
# If this floor tile has a vertical wall immediately to left or right and empty space on the other side,
# block 'outside' corner placements.
func _is_outside_L_deadzone(tile_map, cell: Vector2i, spawn_loc: int) -> bool:
	# Only relevant for floor-like anchors
	if spawn_loc != DecorationConfig.SpawnLocation.FLOOR_CENTER and \
		spawn_loc != DecorationConfig.SpawnLocation.FLOOR_CORNER:
		return false
	# Check neighboring tiles in the same TileMap layer
	var left_cell := cell + Vector2i(-1, 0)
	var right_cell := cell + Vector2i(1, 0)
	var up_cell := cell + Vector2i(0, -1)
	var left_tile: TileData = tile_map.get_cell_tile_data(left_cell)
	var right_tile: TileData = tile_map.get_cell_tile_data(right_cell)
	var up_tile: TileData = tile_map.get_cell_tile_data(up_cell)
	var has_left_wall := left_tile != null and left_tile.get_collision_polygons_count(0) > 0
	var has_right_wall := right_tile != null and right_tile.get_collision_polygons_count(0) > 0
	var has_air_above := up_tile == null
	# Outside L if we have a wall on one side and air above (rises vertically) and the other side is air
	if has_left_wall and has_air_above and right_tile == null:
		return true
	if has_right_wall and has_air_above and left_tile == null:
		return true
	return false

func _has_vertical_wall_on_left(tile_map, cell: Vector2i) -> bool:
	var left_cell := cell + Vector2i(-1, 0)
	var up_cell := cell + Vector2i(-1, -1)
	var left: TileData = tile_map.get_cell_tile_data(left_cell)
	var up: TileData = tile_map.get_cell_tile_data(up_cell)
	return (left != null and up != null)

func _has_vertical_wall_on_right(tile_map, cell: Vector2i) -> bool:
	var right_cell := cell + Vector2i(1, 0)
	var up_cell := cell + Vector2i(1, -1)
	var right: TileData = tile_map.get_cell_tile_data(right_cell)
	var up: TileData = tile_map.get_cell_tile_data(up_cell)
	return (right != null and up != null)

# Check proximity to existing "gate1" nodes to avoid visual overlaps
func _is_near_existing_gate(pos: Vector2, min_dx: float) -> bool:
	var existing := get_tree().get_nodes_in_group("background_decor")
	for n in existing:
		if n is Node2D and ((n as Node2D).name == "gate1" or (n as Node2D).name == "gate2" or (n as Node2D).name == "pipe1" or (n as Node2D).name == "pipe2" or (n as Node2D).name == "sculpture1"):
			var d := (n as Node2D).global_position.distance_to(pos)
			if d < min_dx:
				return true
	return false

func _is_near_gate_pos_list(pos: Vector2, min_dx: float) -> bool:
	for p in placed_gate_positions:
		if p.distance_to(pos) < min_dx:
			return true
	return false


# Locate the grid coordinates of a given chunk node
func _find_grid_pos_for_chunk(chunk_node: Node2D) -> Vector2i:
	for x in range(current_grid_width):
		if x < 0 or x >= grid.size():
			continue
		for y in range(current_grid_height):
			if y < 0 or y >= grid[x].size():
				continue
			if grid[x][y].chunk == chunk_node:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# Find background TileMap layer under the given chunk
func _find_background_tilemap(chunk_node: Node2D) -> TileMap:
	if chunk_node == null:
		return null
	# Heuristic: look for a child named like background or a TileMap with lower z_index
	var candidates := []
	for child in chunk_node.get_children():
		if child is TileMap:
			candidates.append(child)
	# Prefer a node with name containing "background"
	for c in candidates:
		var n := c as Node
		var nm := n.name.to_lower()
		if nm.find("background") != -1 or nm.find("bg") != -1:
			return c
	# Fallback: return first TileMap if any
	if candidates.size() > 0:
		return candidates[0]
	return null

# Estimate visual width of an instance (Sprite2D/AnimatedSprite2D) to validate edge support
func _get_visual_size_from_instance(node: Node2D) -> Vector2:
	var size := Vector2(32, 32)
	var spr := node.get_node_or_null("Sprite") as Sprite2D
	if spr and spr.texture:
		var w := 0
		var h := 0
		if spr.texture is AtlasTexture:
			var at := spr.texture as AtlasTexture
			w = int(at.region.size.x)
			h = int(at.region.size.y)
		else:
			w = spr.texture.get_width()
			h = spr.texture.get_height()
		if spr.vframes > 1:
			h = int(floor(float(h) / float(max(1, spr.vframes))))
		if spr.hframes > 1:
			w = int(floor(float(w) / float(max(1, spr.hframes))))
		return Vector2(w, h)
	var anim := node.get_node_or_null("Anim") as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.get_frame_count("idle") > 0:
		var tex := anim.sprite_frames.get_frame_texture("idle", 0)
		if tex:
			if tex is AtlasTexture:
				var at2 := tex as AtlasTexture
				return Vector2(at2.region.size.x, at2.region.size.y)
			elif tex is Texture2D:
				return Vector2(tex.get_width(), tex.get_height())
	return size

# Raycast span check: ensure there is ground support across [x-half_w, x+half_w]
func _has_ground_support_span(center_pos: Vector2, half_w: float) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var mask: int = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var samples: int = 5
	var hits: int = 0
	for i in range(samples):
		var t: float = (i as float) / float(samples - 1)
		var x: float = lerp(center_pos.x - half_w, center_pos.x + half_w, t)
		var from: Vector2 = Vector2(x, center_pos.y - 16)
		var to: Vector2 = Vector2(x, center_pos.y + 128)
		var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
		params.collision_mask = mask
		params.collide_with_areas = false
		params.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(params)
		if hit and hit.has("position"):
			hits += 1
	# Require majority of samples to have support
	return hits >= int(ceil(float(samples) * 0.6))

# Try to nudge spawn_pos horizontally inward to find a supported placement
func _find_supported_position(center_pos: Vector2, half_w: float, max_nudge: float, step: float) -> Dictionary:
	var result := {"ok": false, "pos": center_pos}
	if _has_ground_support_span(center_pos, half_w):
		result.ok = true
		return result
	var dir := [-1.0, 1.0]
	var d := step
	while d <= max_nudge:
		for s in dir:
			var candidate := center_pos + Vector2(s * d, 0)
			if _has_ground_support_span(candidate, half_w):
				result.ok = true
				result.pos = candidate
				return result
		d += step
	return result

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
		push_error("Invalid position or direction in set_grid_connection: %s, %d" % [str(pos), dir])
		return
	
	grid[pos.x][pos.y].connections[dir] = value
	
	# Also set the connection for the neighbor in the opposite direction
	var neighbor_pos = pos + DIRECTION_VECTORS[dir]
	var opposite_dir = get_opposite_direction(dir)
	
	if is_valid_position(neighbor_pos) and is_valid_direction(opposite_dir):
		# Ensure the neighbor cell exists before accessing it
		if grid.size() > neighbor_pos.x and grid[neighbor_pos.x].size() > neighbor_pos.y:
			# --- MODIFIED LOGIC --- 
			# Only set neighbor's connection if we are setting the current one to TRUE
			if value:
				grid[neighbor_pos.x][neighbor_pos.y].connections[opposite_dir] = true
			# If setting current connection to false, DO NOT automatically set neighbor to false.
			# This allows for one-way disconnections without breaking neighbor's state.
			# else: # Removed explicit setting to false
			#   grid[neighbor_pos.x][neighbor_pos.y].connections[opposite_dir] = false
			# --- END MODIFIED LOGIC ---
		else:
			push_warning("Neighbor cell %s does not exist in grid. Cannot set opposite connection for %s." % [str(neighbor_pos), str(pos)])
	else:
		# Only print warning if we intended to set a connection (value=true)
		if value:
			push_warning("Neighbor position %s or opposite direction %d is invalid for %s. Cannot set opposite connection." % [str(neighbor_pos), opposite_dir, str(pos)])

func spawn_player() -> void:
	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
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
		
		# Player pozisyonu artık setup_level_transitions() tarafından ayarlanıyor
		# Burada sadece kamera ayarlarını yapıyoruz
		print("Player spawn completed, position will be set by door system")
		
		# Set up player camera
		if player.has_node("Camera2D"):
			var player_camera = player.get_node("Camera2D")
			player_camera.enabled = true
			
			if not is_overview_active:
				player_camera.make_current()
			else:
				overview_camera.make_current()
			
			# Notify ScreenEffects that camera is now available
			print("[LevelGenerator] Notifying ScreenEffects about camera availability")
			if ScreenEffects:
				print("[LevelGenerator] ScreenEffects found, calling _find_camera()")
				ScreenEffects._find_camera()
			else:
				print("[LevelGenerator] ERROR: ScreenEffects not found!")

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

# Helper function to locate the finish chunk's grid position
func find_finish_position() -> Vector2i:
	for x in range(current_grid_width - 1, -1, -1):
		# Check grid bounds before accessing y
		if x < 0 or x >= grid.size():
			continue
		for y in range(current_grid_height): # Use current_grid_height
			# Check grid bounds before accessing cell properties
			if y < 0 or y >= grid[x].size():
				continue
			# Check if the cell has a chunk AND it's the finish chunk (using scene path is more reliable)
			# Also check cell_type as an additional safeguard, though scene path is better
			if grid[x][y].chunk and grid[x][y].chunk.scene_file_path.contains("finish_chunk") or \
			   (grid[x][y].cell_type == CellType.MAIN_PATH and x == current_grid_width - 1): # Fallback for finish chunks near edge
				# Found it based on chunk scene or cell type near the edge
				return Vector2i(x, y)

	# Fallback if no finish chunk scene found (e.g., during early layout generation)
	# Look for the rightmost MAIN_PATH cell
	for x in range(current_grid_width - 1, -1, -1):
		if x < 0 or x >= grid.size(): continue
		for y in range(current_grid_height): # Use current_grid_height
			if y < 0 or y >= grid[x].size(): continue
			if grid[x][y].cell_type == CellType.MAIN_PATH:
				return Vector2i(x, y)
				
	push_warning("find_finish_position: Could not find finish position based on chunk or cell type.")
	return Vector2i.MAX # Return an indicator that it wasn't found

func setup_level_transitions() -> void:
	print("\nSetting up level transitions...") # This prints!

	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
	var finish_pos = Vector2i.ZERO
	var finish_found = false

	# <<< DEBUG: Check grid dimensions before loop >>>
	if grid.size() != current_grid_width:
		push_error("!!! setup_level_transitions: Grid size mismatch! grid.size()=%d, current_grid_width=%d" % [grid.size(), current_grid_width])
		# Potentially return or handle error? For now just log.
	
	# Search for finish chunk (or boss arena on mini levels)
	for x in range(current_grid_width - 1, -1, -1):
		# <<< DEBUG: Check x bounds >>>
		if x < 0 or x >= grid.size():
			push_error("!!! setup_level_transitions (loop): x=%d out of bounds for grid size %d" % [x, grid.size()])
			continue
		for y in range(current_grid_height): # Use current_grid_height
			# <<< DEBUG: Check y bounds >>>
			if y < 0 or y >= grid[x].size():
				push_error("!!! setup_level_transitions (loop): y=%d out of bounds for grid[%d] size %d" % [y, x, grid[x].size()])
				continue

			# Access grid[x][y].chunk
			if grid[x][y].chunk and (grid[x][y].chunk.scene_file_path.contains("finish_chunk")
				or grid[x][y].chunk.scene_file_path.contains("boss_arena")):
				finish_pos = Vector2i(x, y)
				finish_found = true
				break
		if finish_found:
			break

	if not finish_found:
		# Fallback is okay, but accessing grid with it might be bad if grid is too small
		finish_pos = Vector2i(current_grid_width - 2, current_grid_height / 2) # Use current_grid_height
		print("WARNING: Finish chunk not found, using fallback position:", finish_pos)

	print("Start position:", start_pos)
	print("Finish position:", finish_pos)

	# Handle start door - use pre-placed door in start chunk
	# <<< DEBUG: Check start_pos bounds >>>
	if start_pos.x < 0 or start_pos.x >= grid.size() or start_pos.y < 0 or start_pos.y >= grid[start_pos.x].size():
		push_error("!!! setup_level_transitions: start_pos %s out of bounds for grid size %d!" % [str(start_pos), grid.size()])
		return # Cannot continue if start_pos is invalid

	if grid[start_pos.x][start_pos.y].chunk:
		print("Found start chunk, connecting to pre-placed start door")
		var start_chunk = grid[start_pos.x][start_pos.y].chunk
		var start_door = start_chunk.get_node_or_null("StartDoor")
		
		if start_door:
			# Connect the pre-placed door to our signal handler
			if not start_door.door_opened.is_connected(_on_door_opened):
				start_door.door_opened.connect(_on_door_opened)
			print("Connected to pre-placed start door")
			
			# Kapı pozisyonunu kaydet
			door_positions.append(start_door.global_position)
			
			# Player'ı start kapısının pozisyonunda spawn et
			var player = get_node_or_null("Player")
			if player:
				# StartDoor'un gerçek global pozisyonunu kullan
				player.global_position = start_door.global_position + Vector2(0, -64)  # Kapının hemen üstünde
				print("[LevelGenerator] Player spawned at StartDoor position: ", player.global_position)
				print("[LevelGenerator] StartDoor actual position: ", start_door.global_position)
			else:
				print("WARNING: No Player found in scene")
		else:
			print("WARNING: No StartDoor found in start chunk")
	else:
		print("WARNING: Start chunk not found at position", start_pos)
	
	# Handle finish door - use pre-placed door in finish/boss chunk
	# <<< DEBUG: Check finish_pos bounds >>>
	if finish_pos.x < 0 or finish_pos.x >= grid.size() or finish_pos.y < 0 or finish_pos.y >= grid[finish_pos.x].size():
		push_error("!!! setup_level_transitions: finish_pos %s out of bounds for grid size %d!" % [str(finish_pos), grid.size()])
		return # Cannot continue if finish_pos is invalid

	if grid[finish_pos.x][finish_pos.y].chunk:
		print("Found finish/boss chunk, connecting to pre-placed finish door")
		var finish_chunk = grid[finish_pos.x][finish_pos.y].chunk
		var finish_door = finish_chunk.get_node_or_null("FinishDoor")
		
		if finish_door:
			# Kapı pozisyonunu kaydet
			door_positions.append(finish_door.global_position)
			
			# Connect the pre-placed door to our signal handler
			if not finish_door.door_opened.is_connected(_on_door_opened):
				finish_door.door_opened.connect(_on_door_opened)
			
			# If the finish cell is a boss arena, lock the door until boss dies
			if finish_chunk.scene_file_path.contains("boss_arena"):
				print("Boss arena detected at finish. Locking FinishDoor until boss is defeated.")
				finish_door.lock_door()
				finish_door.door_type = "Boss"  # Change type to Boss for different appearance
			
			print("Connected to pre-placed finish door")
		else:
			print("WARNING: No FinishDoor found in finish/boss chunk")
	else:
		print("ERROR: No chunk found at finish position", finish_pos)

func _on_door_opened(door_type: String) -> void:
	if is_transitioning:
		return
		
	print("Door opened: ", door_type)  # Debug print
	if door_type == "Start":
		print("Emitting level_started signal")  # Debug print
		level_started.emit()
	elif door_type == "Finish" or door_type == "Boss":
		print("Emitting level_completed signal")  # Debug print
		is_transitioning = true
		
		# Clear all enemies from previous level before generating new level
		_clear_all_enemies_from_previous_level()
		
		level_completed.emit()
		current_level += 1
		generate_level()  # Generate new level
		
		# Reset transition flag after cooldown
		var timer = get_tree().create_timer(transition_cooldown)
		timer.timeout.connect(func(): is_transitioning = false)
		# Player will be automatically spawned at the start of new level

func _on_miniboss_spawned(enemy: Node, boss_chunk: Node2D) -> void:
	# Wire defeat to enabling FinishZone under the boss arena chunk
	if enemy and enemy.has_signal("enemy_defeated"):
		enemy.connect("enemy_defeated", Callable(self, "_on_miniboss_defeated").bind(boss_chunk))

func _calculate_door_positions() -> void:
	# Kapı pozisyonlarını gerçek door pozisyonlarından al
	door_positions.clear()
	
	# Gerçek door pozisyonlarını dinamik olarak al
	var doors = get_tree().get_nodes_in_group("doors")
	print("[DoorPositions] Found doors in group: ", doors.size())
	
	for door in doors:
		if door and is_instance_valid(door):
			var door_pos = door.global_position
			door_positions.append(door_pos)
			print("[DoorPositions] Added door at: ", door_pos)
	
	# Fallback: Eğer door bulunamazsa hata ver
	if door_positions.is_empty():
		print("[DoorPositions] ERROR: No doors found! This should not happen!")
		push_error("No doors found in scene - door proximity check will fail!")
	
	print("[DoorPositions] Final door positions: ", door_positions)

func get_door_positions() -> Array[Vector2]:
	# Decoration spawner'lar için kapı pozisyonlarını döndür
	return door_positions

func _on_miniboss_defeated(boss_chunk: Node2D) -> void:
	if not boss_chunk:
		return
	var finish_door: Node = boss_chunk.get_node_or_null("FinishDoor")
	if finish_door:
		if finish_door.has_method("unlock_door"):
			finish_door.unlock_door()
		print("[LevelGenerator] MiniBoss defeated. FinishDoor unlocked.")
	else:
		print("[LevelGenerator] MiniBoss defeated but no FinishDoor found in boss chunk.")

func _attach_boss_bar(mini: Node) -> void:
	if not is_instance_valid(mini):
		return
	# Find UI root
	var ui_root = get_tree().get_first_node_in_group("ui_root")
	if ui_root == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_node("UI"):
			ui_root = players[0].get_node("UI")
	# If still not found, create a temporary CanvasLayer under current scene
	if ui_root == null:
		var canvas := CanvasLayer.new()
		canvas.name = "TempUIRoot"
		add_child(canvas)
		ui_root = canvas
	# Add bar
	var boss_bar_scene: PackedScene = load("res://ui/boss_health_bar.tscn")
	if boss_bar_scene and ui_root:
		# Remove existing if any
		var existing = ui_root.get_node_or_null("BossHealthBar")
		if existing:
			existing.queue_free()
		var boss_bar = boss_bar_scene.instantiate()
		boss_bar.name = "BossHealthBar"
		ui_root.add_child(boss_bar)
		# Start hidden; will reveal on proximity
		boss_bar.visible = false
		# Prepare silently; reveal on proximity
		boss_bar.defer_reveal = true
		boss_bar.call_deferred("setup_silent", (mini.stats.max_health if mini.has_method("get") and mini.stats else 100.0))
		# Bind updates
		if mini.has_signal("health_changed"):
			mini.connect("health_changed", Callable(boss_bar, "update_health"))
		# Auto-hide when boss dies
		if mini.has_signal("enemy_defeated"):
			mini.connect("enemy_defeated", Callable(boss_bar, "queue_free"))
		# Proximity-based reveal
		var proximity_threshold: float = 520.0
		var hide_threshold: float = 640.0
		var proximity_timer := Timer.new()
		proximity_timer.wait_time = 0.1
		proximity_timer.one_shot = false
		proximity_timer.autostart = true
		boss_bar.add_child(proximity_timer)
		proximity_timer.timeout.connect(func():
			if not is_instance_valid(mini) or not is_instance_valid(boss_bar):
				if is_instance_valid(proximity_timer):
					proximity_timer.stop()
					proximity_timer.queue_free()
				return
			var players = get_tree().get_nodes_in_group("player")
			if players.size() == 0:
				return
			var player = players[0]
			if player is Node2D and mini is Node2D:
				var player_pos: Vector2 = player.global_position
				var boss_pos: Vector2 = (mini as Node2D).global_position
				var dist = player_pos.distance_to(boss_pos)
				if dist <= proximity_threshold:
					if boss_bar.has_method("reveal"):
						boss_bar.reveal()
					else:
						boss_bar.visible = true
				elif dist >= hide_threshold:
					if boss_bar.has_method("conceal"):
						boss_bar.conceal()
		)
func unify_terrain() -> void:
	print("\nPhase 3: Unifying terrain...")
	
	# Create new unified terrain
	unified_terrain = UnifiedTerrain.new()
	add_child(unified_terrain)
	
	# Collect all chunks
	var chunks = []
	for x in range(current_grid_width):
		# <<< START DEBUG >>>
		# Check if x is valid for grid FIRST
		if x < 0 or x >= grid.size():
			push_error("!!! unify_terrain: x (%d) is out of bounds for grid (size %d)! Breaking outer loop." % [x, grid.size()])
			break # Exit outer loop
		# <<< END DEBUG >>>
		for y in range(current_grid_height): # Use current_grid_height
			# <<< START DEBUG >>>
			# Check if y is valid for grid[x] ONLY if x was valid
			if y < 0 or y >= grid[x].size():
				push_error("!!! unify_terrain: y (%d) is out of bounds for grid[%d] (size %d)! Breaking inner loop." % [y, x, grid[x].size()])
				break # Exit inner loop
			# <<< END DEBUG >>>
			
			# <<< PARANOID CHECK >>>
			var check_x = x
			var check_y = y
			var current_grid_size = grid.size()
			if check_x < 0 or check_x >= current_grid_size:
				push_error("!!! PARANOID FAIL X (before chunk access): x=%d, grid_size=%d" % [check_x, current_grid_size])
				continue # Skip to next y in inner loop (or break inner? continue is safer)
			var current_row_size = grid[check_x].size()
			if check_y < 0 or check_y >= current_row_size:
				push_error("!!! PARANOID FAIL Y (before chunk access): y=%d, row_size=%d" % [check_y, current_row_size])
				continue # Skip to next y
			# <<< END PARANOID CHECK >>>
			
			# <<< FINAL CHECK BEFORE ACCESS >>>
			print("  unify_terrain: Accessing grid[%d][%d]. Current grid.size() = %d" % [x, y, grid.size()])
			# <<< END FINAL CHECK >>>
			
			if grid[x][y].chunk: # Access that might fail
				chunks.append(grid[x][y].chunk)
	
	# Process chunks in the unified terrain
	unified_terrain.unify_chunks(chunks)
	
	# Hide original tilemaps (except those containing dark tiles)
	for chunk in chunks:
		var chunk_map = chunk.get_node("TileMap")
		if chunk_map:
			# Check if this chunk contains dark tiles
			if not chunk_contains_dark_tiles(chunk_map):
				chunk_map.visible = false
			else:
				print("Keeping chunk visible due to dark tiles: ", chunk.name)
	
	print("Terrain unification complete!")

# Check if a chunk contains dark tiles that should remain visible
func chunk_contains_dark_tiles(chunk_map: TileMap) -> bool:
	# Dark tile coordinates that should be excluded from unification (local chunk coordinates)
	var dark_tile_coordinates = [
		Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11),
		Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
		Vector2i(4, 13), Vector2i(5, 13), Vector2i(6, 13),
		Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
		Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12),
		Vector2i(8, 13), Vector2i(9, 13), Vector2i(10, 13)
	]
	
	# Get all used cells in the chunk
	var used_cells = chunk_map.get_used_cells(0)
	
	# Check if any of the used cells are at dark tile coordinates
	for cell in used_cells:
		if cell in dark_tile_coordinates:
			print("Found dark tile at local coordinates: ", cell, " in chunk")
			return true
	
	return false

func generate_branch(branch_start: Vector2i, all_paths: Array) -> void:
	# Skip if this is the start position or too close to finish
	if branch_start == Vector2i(0, current_grid_height / 2) or abs(branch_start.x - current_grid_width - 2) < 5: # Use current_grid_height
		return
		
	# Determine branch direction (up or down)
	var branch_dir = Direction.UP if randf() < 0.5 else Direction.DOWN
	# var branch_length = randi() % 3 + 2  # Old: 2-4 chunks
	var branch_length = randi() % 4 + 3  # New: 3-6 chunks
	
	# --- Assign unique ID for this branch ---
	current_path_id_counter += 1
	var current_branch_id = current_path_id_counter
	# ----------------------------------------
	
	# Create branch path
	var current_branch_points = []
	var current_pos = branch_start
	# Don't add branch_start itself to the points list immediately, 
	# it belongs to the main path ID. The branch starts *from* the next cell.
	# current_branch_points.append(current_pos)
	
	# Move vertically
	var can_continue = true
	for _i in range(branch_length):
		var next_pos = current_pos + DIRECTION_VECTORS[branch_dir]
		# Strict Check: Ensure the next position is valid AND not already visited
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			# Log if visited
			if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited:
				push_warning("generate_branch (vertical): Cell %s already visited by '%s'. Stopping branch extension." % [str(next_pos), grid[next_pos.x][next_pos.y].visited_by])
			can_continue = false
			break # Stop extending this branch vertically

		# --- NEW path_id Proximity Check (2-cell radius) ---
		var too_close = false
		# Check cells within a 2-unit Manhattan distance (or simple square)
		for dx in range(-2, 3): # Check x offsets -2, -1, 0, 1, 2
			for dy in range(-2, 3): # Check y offsets -2, -1, 0, 1, 2
				# Skip the cell itself (dx=0, dy=0)
				if dx == 0 and dy == 0:
					continue
					
				# Skip the immediate previous cell (where we came from)
				# Calculate the position relative to next_pos we came from
				var relative_prev_pos = current_pos - next_pos 
				if dx == relative_prev_pos.x and dy == relative_prev_pos.y:
					continue

				var check_pos = next_pos + Vector2i(dx, dy)
				
				if is_valid_position(check_pos) and grid[check_pos.x][check_pos.y].visited:
					# Check if the visited neighbor belongs to a DIFFERENT path segment
					if grid[check_pos.x][check_pos.y].path_id != current_branch_id:
						# Exception: Allow proximity to the original branch_start point itself
						if check_pos != branch_start:
							push_warning("generate_branch (vertical): Cell %s too close (dist %d,%d) to different path (ID %d) at %s. Stopping branch extension." % [
								str(next_pos), dx, dy, grid[check_pos.x][check_pos.y].path_id, str(check_pos)
							])
							too_close = true
							break # Found a blocking neighbor in this row
			if too_close:
				break # Found a blocking neighbor in the radius
				
		if too_close:
			can_continue = false
			break # Stop extending this branch vertically
		# --- END path_id Proximity Check ---

		# Mark the valid, unvisited cell
		# REMOVED CHECK AND OVERWRITE LOGIC - Handled by the check above
		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "generate_branch_vertical" # More specific tracking
		grid[next_pos.x][next_pos.y].path_id = current_branch_id # Assign the ID

		# Set connections for both current and next positions
		set_grid_connection(current_pos, branch_dir, true)
		# Clear any other connections for the next position (done implicitly if needed by set_grid_connection)
		# Let's be explicit to be safe, ensure only opposite connection is set
		for dir_enum in Direction.values():
			if dir_enum != get_opposite_direction(branch_dir):
				set_grid_connection(next_pos, dir_enum, false)

		current_pos = next_pos
		current_branch_points.append(current_pos) # Add the newly marked cell to the list

	if not can_continue:
		return # Don't attempt horizontal if vertical failed

	# Connect back to any main path if not too close to finish
	if current_pos.x < current_grid_width - 7:
		var rejoin_dir = get_opposite_direction(branch_dir)
		if not is_valid_direction(rejoin_dir):
			return

		# Move horizontally towards main path
		var rejoin_target_x = branch_start.x + randi() % 3 + 2  # Shorter horizontal segments (2-4 chunks)
		while current_pos.x < rejoin_target_x and current_pos.x < current_grid_width - 8:
			var next_pos = current_pos + DIRECTION_VECTORS[Direction.RIGHT] # Assuming horizontal rejoin moves RIGHT
			# Strict Check: Ensure the next position is valid AND not already visited
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				# Log if visited
				if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited:
					push_warning("generate_branch (horizontal): Cell %s already visited by '%s'. Stopping branch extension." % [str(next_pos), grid[next_pos.x][next_pos.y].visited_by])
				break # Stop extending horizontally
			
			# --- NEW path_id Proximity Check (2-cell radius) ---
			var too_close = false
			# Check cells within a 2-unit Manhattan distance (or simple square)
			for dx in range(-2, 3): # Check x offsets -2, -1, 0, 1, 2
				for dy in range(-2, 3): # Check y offsets -2, -1, 0, 1, 2
					# Skip the cell itself (dx=0, dy=0)
					if dx == 0 and dy == 0:
						continue
						
					# Skip the immediate previous cell (where we came from - assuming RIGHT direction means prev is LEFT)
					if dx == -1 and dy == 0: # Previous cell is at relative (-1, 0)
						continue
	
					var check_pos = next_pos + Vector2i(dx, dy)
					
					if is_valid_position(check_pos) and grid[check_pos.x][check_pos.y].visited:
						# Check if the visited neighbor belongs to a DIFFERENT path segment
						if grid[check_pos.x][check_pos.y].path_id != current_branch_id:
							# No specific exception needed here like in vertical? Maybe allow branch_start proximity?
							# For now, let's keep it strict. If it's close to *any* other path ID, stop.
							# Exception: Allow proximity to the original branch_start point itself?
							# Let's add the branch_start exception here too for consistency.
							if check_pos != branch_start:
								push_warning("generate_branch (horizontal): Cell %s too close (dist %d,%d) to different path (ID %d) at %s. Stopping branch extension." % [
									str(next_pos), dx, dy, grid[check_pos.x][check_pos.y].path_id, str(check_pos)
								])
								too_close = true
								break # Found a blocking neighbor in this row
				if too_close:
					break # Found a blocking neighbor in the radius
					
				if too_close:
					break # Stop extending horizontally
			# --- END path_id Proximity Check ---
			
			# Mark the valid, unvisited cell
			# REMOVED CHECK AND OVERWRITE LOGIC - Handled by the check above
			grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
			grid[next_pos.x][next_pos.y].visited = true
			grid[next_pos.x][next_pos.y].visited_by = "generate_branch_horizontal" # More specific tracking
			grid[next_pos.x][next_pos.y].path_id = current_branch_id # Assign the ID

			# Set horizontal connections
			set_grid_connection(current_pos, Direction.RIGHT, true)
			# Clear any other connections for the next position (done implicitly if needed by set_grid_connection)
			# Let's be explicit to be safe, ensure only LEFT connection is set
			for dir_enum in Direction.values():
				if dir_enum != Direction.LEFT:
					set_grid_connection(next_pos, dir_enum, false)

			current_pos = next_pos
			current_branch_points.append(current_pos) # Add the newly marked cell

		# Now try to rejoin with any main path
		var can_rejoin = true
		var rejoin_steps = 0
		while rejoin_steps < 3:  # Limit vertical rejoining to 3 steps
			var next_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			# Strict Check: Ensure the next position is valid AND not already visited (unless it's the target main path)
			var is_target_main_path = is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited and grid[next_pos.x][next_pos.y].cell_type == CellType.MAIN_PATH
			# --- Refined Visited Check (No longer need is_target_main_path here) ---
			if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
				# If the visited cell IS the target main path, allow it and break the rejoin loop
				if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited and grid[next_pos.x][next_pos.y].cell_type == CellType.MAIN_PATH:
					print("  generate_branch: Rejoining main path at %s" % str(next_pos)) # Debug print
					break # Found main path, stop vertical movement
				# Otherwise, if it's visited and *not* the main path, stop rejoining.
				else:
					if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited:
						push_warning("generate_branch (rejoin): Cell %s already visited by '%s' (not main path). Stopping rejoin." % [str(next_pos), grid[next_pos.x][next_pos.y].visited_by])
					can_rejoin = false
					break # Stop rejoining
			
			# --- NEW path_id Proximity Check (2-cell radius, rejoin logic) ---
			var too_close_rejoin = false
			# Check cells within a 2-unit Manhattan distance (or simple square)
			for dx in range(-2, 3): # Check x offsets -2, -1, 0, 1, 2
				for dy in range(-2, 3): # Check y offsets -2, -1, 0, 1, 2
					# Skip the cell itself (dx=0, dy=0)
					if dx == 0 and dy == 0:
						continue
						
					# Skip the immediate previous cell (where we came from)
					var relative_prev_pos = current_pos - next_pos
					if dx == relative_prev_pos.x and dy == relative_prev_pos.y:
						continue
						
					# Skip the immediate cell we are going towards (the potential main path)
					# Calculate the position relative to next_pos we are going towards
					var relative_target_pos = (current_pos + DIRECTION_VECTORS[rejoin_dir]) - next_pos 
					# This seems overly complex, let's simplify. We just need to check the *neighbor* cell's properties.
					# Instead of skipping the target, we check its properties below.
					
					var check_pos = next_pos + Vector2i(dx, dy)
					
					if is_valid_position(check_pos) and grid[check_pos.x][check_pos.y].visited:
						# Check if the visited neighbor belongs to a DIFFERENT path segment
						if grid[check_pos.x][check_pos.y].path_id != current_branch_id:
							# --- REJOIN EXCEPTION --- 
							# Allow proximity ONLY if the neighbor is the MAIN PATH we are trying to reach.
							# We assume any MAIN_PATH cell could be a valid rejoin target.
							if grid[check_pos.x][check_pos.y].cell_type != CellType.MAIN_PATH:
								# It's a different path ID AND it's not the main path -> Too close!
								push_warning("generate_branch (rejoin): Cell %s too close (dist %d,%d) to different non-main path (ID %d, Type %d) at %s. Stopping rejoin." % [
									str(next_pos), dx, dy, grid[check_pos.x][check_pos.y].path_id, grid[check_pos.x][check_pos.y].cell_type, str(check_pos)
								])
								too_close_rejoin = true
								break # Found a blocking neighbor in this row
							# Else (it IS the main path), proximity is allowed, do nothing.
				if too_close_rejoin:
					break # Found a blocking neighbor in the radius
					
			if too_close_rejoin:
				can_rejoin = false
				break # Stop rejoining
			# --- END path_id Proximity Check ---
			
			# Check if we've reached a visited cell (the main path) - MOVED check to the top of the loop
			# if is_target_main_path:
			# 	print("  generate_branch: Rejoining main path at %s" % str(next_pos)) # Debug print
			# 	break # Found main path, stop vertical movement
			
			# Mark the valid, unvisited cell (part of the rejoin path)
			# REMOVED CHECK AND OVERWRITE LOGIC - Handled by the check above
			grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
			grid[next_pos.x][next_pos.y].visited = true
			grid[next_pos.x][next_pos.y].visited_by = "generate_branch_rejoin" # More specific tracking
			grid[next_pos.x][next_pos.y].path_id = current_branch_id # Assign the ID

			# Set vertical connections for rejoining
			set_grid_connection(current_pos, rejoin_dir, true)
			# Clear any other connections for the next position (done implicitly if needed by set_grid_connection)
			# Let's be explicit to be safe, ensure only opposite connection is set
			var opposite_rejoin_dir = get_opposite_direction(rejoin_dir)
			for dir_enum in Direction.values():
				if dir_enum != opposite_rejoin_dir:
					set_grid_connection(next_pos, dir_enum, false)

			current_pos = next_pos
			current_branch_points.append(current_pos) # Add the newly marked cell

			rejoin_steps += 1

		if can_rejoin:
			# Connect to main path (only if rejoin was successful)
			var main_path_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
			if is_valid_position(main_path_pos) and grid[main_path_pos.x][main_path_pos.y].visited and grid[main_path_pos.x][main_path_pos.y].cell_type == CellType.MAIN_PATH:
				set_grid_connection(current_pos, rejoin_dir, true)
				# The opposite connection (main_path_pos to current_pos) should be handled by set_grid_connection
				# Also mark the branch start as a branch point IF it wasn't already
				if grid[branch_start.x][branch_start.y].cell_type != CellType.BRANCH_POINT:
					grid[branch_start.x][branch_start.y].cell_type = CellType.BRANCH_POINT
					grid[branch_start.x][branch_start.y].visited_by += "+branch_point"
					
				# Add the successful branch path
				all_paths.append(current_branch_points)
			else:
				push_warning("generate_branch: Failed to connect to main path after rejoin attempt from branch start %s" % str(branch_start))
		else:
			push_warning("generate_branch: Rejoin attempt failed for branch start %s" % str(branch_start)) 

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
	
	# Strict Check: Ensure the next position is valid AND not already visited
	if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
		# Mark the valid, unvisited cell
		grid[next_pos.x][next_pos.y].cell_type = CellType.DEAD_END
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "add_dead_end" # Track visit
		
		# Set up connections for the dead end
		var opposite_dir = get_opposite_direction(dead_end_dir)
		if is_valid_direction(opposite_dir):
			# Set connection from dead end back to previous cell
			set_grid_connection(next_pos, opposite_dir, true)
			# Set connection from previous cell to dead end
			# This might overwrite existing connections in the previous cell, which is intended for dead ends.
			set_grid_connection(current_pos, dead_end_dir, true)
			
			# Clear any other connections for the dead_end cell itself (next_pos)
			for dir_enum in Direction.values():
				if dir_enum != opposite_dir:
					set_grid_connection(next_pos, dir_enum, false)
					
			# We generally SHOULD NOT clear other connections for the cell the dead end branches FROM (current_pos)
			# because it might be part of the main path or another branch.
			# However, the original code had logic to clear horizontal connections for vertical dead ends.
			# Let's replicate that specific clearing logic carefully using set_grid_connection.
			
			# For vertical connections, ensure proper alignment (original logic)
			if dead_end_dir == Direction.UP or dead_end_dir == Direction.DOWN:
				# Clear horizontal connections on the dead end cell
				set_grid_connection(next_pos, Direction.LEFT, false)
				set_grid_connection(next_pos, Direction.RIGHT, false)
				# Clear horizontal connections on the cell it branches from IF it's not the initial start pos?
				# The original logic check was `current_pos != dead_end_start_pos` which seems complex here.
				# Let's stick to only clearing the dead_end cell's other connections for now, 
				# as clearing the source cell (current_pos) might break main paths.
				pass # Already handled by the loop above clearing non-opposite connections
	else:
		# Log if the cell was already visited
		if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].visited:
			push_warning("add_dead_end: Cell %s already visited by '%s'. Cannot create dead end." % [str(next_pos), grid[next_pos.x][next_pos.y].visited_by])
		# ADDED: Log if position was invalid too
		elif not is_valid_position(next_pos):
			push_warning("add_dead_end BLOCKED because position %s is invalid." % str(next_pos))

func is_valid_connection(from_pos: Vector2i, to_pos: Vector2i, dir: Direction) -> bool:
	# If connecting to/from the start chunk, only allow its RIGHT connection
	if from_pos == Vector2i(0, current_grid_height / 2):  # Start position # Use current_grid_height
		return dir == Direction.RIGHT
	
	# If connecting TO the start chunk, only allow from its RIGHT side (LEFT direction)
	if to_pos == Vector2i(0, current_grid_height / 2): # Use current_grid_height
		return dir == Direction.LEFT
	
	# Regular connection is valid
	return true

func finalize_connections() -> void:
	print("Finalizing grid connections...")
	for x in range(current_grid_width):
		for y in range(current_grid_height): # Use current_grid_height
			var pos = Vector2i(x, y)
			
			# Skip empty cells
			if grid[x][y].cell_type == CellType.EMPTY:
				continue

			# Check neighbours
			for dir_enum in Direction.values():
				var dir = dir_enum
				var neighbor_pos = pos + DIRECTION_VECTORS[dir]
				
				# Check if neighbor is valid and also not empty
				if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].cell_type != CellType.EMPTY:
					# Check for special start/finish cases to enforce single connection
					# Start cell (0, BASE_GRID_HEIGHT/2) should only connect RIGHT
					if pos == Vector2i(0, current_grid_height / 2) and dir != Direction.RIGHT: # Use current_grid_height
						continue # Skip setting connection
					# Neighbor is start cell, connection must be LEFT from neighbor's perspective (dir = RIGHT from pos)
					if neighbor_pos == Vector2i(0, current_grid_height / 2) and dir != Direction.RIGHT: # Use current_grid_height
						continue # Skip setting connection

					# Find finish position dynamically (could be multiple)
					var finish_positions = []
					for fx in range(current_grid_width - 1, current_grid_width - 3, -1): # Check last two columns
						if fx < 0: continue
						for fy in range(current_grid_height): # Use current_grid_height
							if is_valid_position(Vector2i(fx, fy)) and grid[fx][fy].cell_type == CellType.MAIN_PATH:
								# Heuristic: Assume rightmost main path cells are potential finishes
								finish_positions.append(Vector2i(fx, fy))
								break # Found one in this column

					# Finish cell(s) should only connect LEFT
					if pos in finish_positions and dir != Direction.LEFT:
						continue # Skip setting connection
					# Neighbor is a finish cell, connection must be RIGHT from neighbor's perspective (dir = LEFT from pos)
					if neighbor_pos in finish_positions and dir != Direction.LEFT:
						continue # Skip setting connection

					# If not a special start/finish case preventing connection, set it
					# Use the modified set_grid_connection which only sets true for neighbor
					set_grid_connection(pos, dir, true) 
					# Optional: Log the connection made
					# print("  Finalize: Connected %s -> %s" % [str(pos), str(neighbor_pos)])
	print("Grid connections finalized.")

# --- NEW FUNCTION --- 
func fill_surrounding_walls() -> void:
	print("Filling surrounding walls...")
	# Logic to iterate grid and mark walls will go here
	# We need to store the cells to change first, then change them, 
	# to avoid a wall placed in one step affecting the next cell's check.
	var cells_to_make_wall = []
	
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			# Only consider currently empty cells
			if grid[x][y].cell_type == CellType.EMPTY:
				var has_path_neighbor = false
				# Check all 8 neighbors
				var neighbor_offsets = [
					Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), # Cardinal
					Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1) # Diagonal
				]
				for offset in neighbor_offsets:
					var neighbor_pos = Vector2i(x, y) + offset
					# If neighbor is valid and NOT empty (and not a wall itself from a previous theoretical pass - though we do it in one go now)
					if is_valid_position(neighbor_pos) and \
						grid[neighbor_pos.x][neighbor_pos.y].cell_type != CellType.EMPTY and \
						grid[neighbor_pos.x][neighbor_pos.y].cell_type != CellType.WALL: # Don't trigger based on other walls
						has_path_neighbor = true
						break # Found one path neighbor, no need to check others
				
				# If this empty cell has a path neighbor, mark it to become a wall
				if has_path_neighbor:
					cells_to_make_wall.append(Vector2i(x,y))

	# Now, actually change the cell types for the marked cells
	for pos in cells_to_make_wall:
		grid[pos.x][pos.y].cell_type = CellType.WALL
		# Optional: Mark who visited/changed it
		grid[pos.x][pos.y].visited_by = "fill_surrounding_walls"
		# Walls don't need path IDs or connections set here.

	print("Surrounding walls marked. Count: %d" % cells_to_make_wall.size()) # Updated print
# --- END NEW FUNCTION ---

# Screen darkness controller'ı ekle
func add_screen_darkness_controller() -> void:
	print("[LevelGenerator] Adding screen darkness controller...")
	
	# Deferred olarak ekle ki scene tree tamamen hazır olsun
	call_deferred("_add_screen_darkness_controller_deferred")

func _add_screen_darkness_controller_deferred() -> void:
	print("[LevelGenerator] Adding screen darkness controller (deferred)...")
	
	# Screen darkness controller'ı oluştur - ColorRect kullanarak
	var screen_darkness = ColorRect.new()
	screen_darkness.name = "ScreenDarknessOverlay"
	screen_darkness.color = Color(0.0, 0.0, 0.0, 0.0)  # Başlangıçta şeffaf
	screen_darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Shader material oluştur
	var shader = load("res://shaders/screen_darkness.gdshader")
	if shader:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		screen_darkness.material = shader_material
		
		# Shader parametrelerini ayarla
		shader_material.set_shader_parameter("max_darkness", 0.8)
		shader_material.set_shader_parameter("light_radius", 800.0)  # 4 katına çıkarıldı (200 -> 800)
		shader_material.set_shader_parameter("ambient_light", 0.2)
		shader_material.set_shader_parameter("player_screen_position", Vector2(960, 540))  # Başlangıç pozisyonu
		
		print("[LevelGenerator] Shader applied to ColorRect successfully")
	else:
		print("[LevelGenerator] ERROR: Could not load screen_darkness.gdshader")
	
	# Player pozisyonunu güncelleyen script ekle
	var update_script = GDScript.new()
	update_script.source_code = """
extends ColorRect

var player: Node2D
var camera: Camera2D
var shader_material: ShaderMaterial

func _ready():
	# Player'ı bul
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	
	# Shader material'ı al
	if material:
		shader_material = material

func _process(delta):
	if not shader_material or not player or not camera:
		return
	
	# Player'ın screen pozisyonunu hesapla - direkt oyuncuyu takip et
	var viewport = get_viewport()
	var player_world_pos = player.global_position
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom
	var viewport_size = viewport.get_visible_rect().size
	
	# World pozisyonunu screen pozisyonuna çevir
	# Camera'nın offset'ini dikkate al (camera.position)
	var camera_offset = camera.position
	var relative_pos = player_world_pos - camera_pos + camera_offset
	var player_screen_pos = (relative_pos * camera_zoom) + viewport_size / 2.0
	
	# Shader'a gönder
	shader_material.set_shader_parameter("player_screen_position", player_screen_pos)
"""
	screen_darkness.set_script(update_script)
	
	# CanvasLayer oluştur ve ColorRect'i içine ekle
	var scene_root = get_tree().current_scene
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ScreenDarknessLayer"
	canvas_layer.layer = 100  # En üstte render edilsin
	
	# ColorRect'i CanvasLayer'e ekle
	canvas_layer.add_child(screen_darkness)
	
	# CanvasLayer'i scene root'a ekle
	scene_root.add_child(canvas_layer)

# ==============================================================================
# TILE-BASED ENEMY SPAWN SYSTEM
# ==============================================================================

func _populate_enemies_from_tilemap(chunk_node: Node2D) -> void:
	# Tile-based enemy spawn system - similar to decoration system
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	
	if not tile_map:
		print("[EnemyPopulate] SKIPPING: Chunk '%s' does not have a child node named 'TileMapLayer'." % chunk_node.name)
		return
	
	var tile_set = tile_map.tile_set
	if not tile_set:
		push_warning("TileMap in '%s' has no TileSet." % chunk_node.name)
		return
	
	# Find enemy anchor custom data layer (use decor_anchor for now)
	var enemy_layer_name = "decor_anchor"
	var enemy_layer_index = -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == enemy_layer_name:
			enemy_layer_index = i
			break
	
	if enemy_layer_index == -1:
		print("[EnemyPopulate] SKIPPING: TileSet in chunk '%s' does not have a custom data layer named '%s'." % [chunk_node.name, enemy_layer_name])
		return
	
	var used_cells = tile_map.get_used_cells()
	var enemy_spawn_count = 0
	var spawned_positions: Array[Vector2] = []  # Track spawned positions
	
	print("[EnemyPopulate] Processing %d cells in chunk '%s'" % [used_cells.size(), chunk_node.name])
	
	# CHUNK DEBUG
	print("[EnemyPopulate] === CHUNK DEBUG ===")
	print("[EnemyPopulate] Chunk: %s" % chunk_node.name)
	print("[EnemyPopulate] Chunk Global Pos: %s" % chunk_node.global_position)
	print("[EnemyPopulate] TileMap Global Pos: %s" % tile_map.global_position)
	print("[EnemyPopulate] ===================")
	
	# Process each cell to find 3-tile patterns
	for cell in used_cells:
		var tile_data = tile_map.get_cell_tile_data(cell)
		if not tile_data:
			continue
		
		var custom_data = tile_data.get_custom_data(enemy_layer_name)
		if not custom_data:
			continue
		
		# Check if this is a floor tile that can spawn enemies
		if custom_data == "floor" or custom_data == "floor_surface":
			# DEBUG: Check what tiles we're looking at
			print("[EnemyPopulate] Checking floor tile at: %s" % cell)
		# Check for 3-tile area pattern (like decorations)
		if _check_three_by_three_area(tile_map, cell, enemy_layer_name):
			# Spawn 2-3 enemies per chunk total (reduced from 4)
			if enemy_spawn_count < 2:
				print("[EnemyPopulate] Found 3-tile area at cell: %s (spawn count: %d)" % [cell, enemy_spawn_count])
					# Spawn enemy at center of 3x3 area
				var center_cell = cell  # Center of 3x3 area
				var tile_size_v2: Vector2 = Vector2(tile_map.tile_set.tile_size)
				var local_pos = tile_map.map_to_local(center_cell)
				var tile_center: Vector2 = tile_map.to_global(local_pos) + tile_size_v2 / 2.0
				
				# Use same positioning as decorations (FLOOR_CENTER)
				var floor_offset_y := 150.0  # Increased even more for heavy enemies
				var bias_x := 0.0  # No X bias to prevent chunk boundary issues
				var spawn_position = tile_center + Vector2(bias_x, -floor_offset_y)
				
				# Check if spawn position is within reasonable bounds (simple check)
				var chunk_pos = chunk_node.global_position
				var chunk_size = Vector2(1920, 1080)  # Standard chunk size
				var spawn_local = spawn_position - chunk_pos
				
				if spawn_local.x < 0 or spawn_local.x > chunk_size.x or spawn_local.y < 0 or spawn_local.y > chunk_size.y:
					print("[EnemyPopulate] SKIP: Spawn position %s is outside chunk bounds" % spawn_position)
					continue
				
				# Check minimum distance from other spawned enemies (prevent clustering)
				var min_distance = 200.0  # Minimum distance between enemies
				var too_close = false
				for existing_pos in spawned_positions:
					if spawn_position.distance_to(existing_pos) < min_distance:
						too_close = true
						break
				
				if too_close:
					print("[EnemyPopulate] SKIP: Spawn position %s too close to existing enemy" % spawn_position)
					continue
				
				# DETAILED DEBUG (Normal level)
				print("[EnemyPopulate] Spawning enemy at: %s" % spawn_position)
				
				# Create enemy spawner
				var enemy_spawner_script = load("res://enemy/tile_enemy_spawner.gd")
				var enemy_spawner = enemy_spawner_script.new()
				enemy_spawner.global_position = spawn_position
				enemy_spawner.current_level = current_level
				enemy_spawner.chunk_type = _get_chunk_type_for_node(chunk_node)
				enemy_spawner.spawn_chance = 0.6  # 60% chance to spawn (reduced from 100%)
				
				# DETAILED SPAWNER DEBUG (Reduced)
				print("[EnemyPopulate] Spawner created at: %s" % enemy_spawner.global_position)
				
				# Add to chunk
				chunk_node.add_child(enemy_spawner)
				
				# FIX: Reset position after add_child (parent-child transform issue)
				enemy_spawner.global_position = spawn_position
				
				# DETAILED SPAWNER DEBUG AFTER ADD (Reduced)
				print("[EnemyPopulate] Spawner added to: %s" % enemy_spawner.get_parent().name)
				
				# Activate spawner
				enemy_spawner.activate()
				
				# Add visual marker for debug - show which tile was selected for spawning
				print("[EnemyPopulate] Adding marker for tile: %s" % center_cell)
				_add_spawn_tile_marker(tile_map, center_cell, chunk_node)
				
				# Track this spawn position
				spawned_positions.append(spawn_position)
				enemy_spawn_count += 1
				print("[EnemyPopulate] Spawned enemy at 3-tile area: %s" % center_cell)
	
	print("[EnemyPopulate] Spawned %d enemies in chunk '%s'" % [enemy_spawn_count, chunk_node.name])

# Add visual marker to show which tile was selected for enemy spawning
func _add_spawn_tile_marker(tile_map: TileMapLayer, cell: Vector2i, chunk_node: Node2D) -> void:
	# Get tile position for debugging
	var tile_pos = tile_map.map_to_local(cell)
	var world_pos = tile_map.to_global(tile_pos)
	
	# Console'da spawn pozisyonunu göster
	print("🎯 SPAWN TILE: Cell(%s) -> World(%s) in chunk '%s'" % [cell, world_pos, chunk_node.name])
	
	# Label kullan - en basit çözüm (DISABLED)
	# var label = Label.new()
	# label.name = "SpawnMarker_%s_%s" % [cell.x, cell.y]
	# label.text = "🎯 SPAWN 🎯"
	# label.position = world_pos - Vector2(50, 50)
	# label.size = Vector2(100, 100)
	# label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# label.add_theme_color_override("font_color", Color.RED)
	# label.add_theme_color_override("font_outline_color", Color.BLACK)
	# label.add_theme_color_override("font_outline_size", 3)
	# label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 
	# # Label'ı main scene'e ekle
	# get_tree().current_scene.add_child(label)
	# print("✅ LABEL MARKER added at world pos: %s" % world_pos)
	# 
	# # Test marker ekle - sabit pozisyonda
	# var test_label = Label.new()
	# test_label.name = "TestMarker"
	# test_label.text = "🔵 TEST 🔵"
	# test_label.position = Vector2(50, 50)
	# test_label.size = Vector2(200, 200)
	# test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# test_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# test_label.add_theme_color_override("font_color", Color.BLUE)
	# test_label.add_theme_color_override("font_outline_color", Color.BLACK)
	# test_label.add_theme_color_override("font_outline_size", 3)
	# test_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# get_tree().current_scene.add_child(test_label)
	# print("🔵 TEST LABEL MARKER added at (50, 50)")

func _check_three_by_three_area(tile_map: TileMapLayer, center_cell: Vector2i, layer_name: String) -> bool:
	# Check if 3x3 area around center cell is clear (like decorations)
	# Even more flexible: check center + 2 horizontal directions
	var check_cells = [
		center_cell,  # Center
		center_cell + Vector2i(-1, 0),  # Left
		center_cell + Vector2i(1, 0)    # Right
	]
	
	# Check the 3 key tiles
	for check_cell in check_cells:
		var tile_data = tile_map.get_cell_tile_data(check_cell)
		
		# If any tile in the area is not floor, return false
		if not tile_data:
			return false
		
		var custom_data = tile_data.get_custom_data(layer_name)
		if custom_data != "floor" and custom_data != "floor_surface":
			return false
	
	# Check that center area is not on chunk boundary
	if _is_on_chunk_outer_boundary(tile_map, center_cell):
		return false
	
	# YÜKSEKLİK KONTROLÜ EKLE - Düşman için yeterli yükseklik var mı?
	if not _check_spawn_height_clearance(tile_map, center_cell, layer_name):
		return false
	
	return true

# Yeni fonksiyon: Düşman spawn alanının üstünde yeterli yükseklik var mı kontrol et
func _check_spawn_height_clearance(tile_map: TileMapLayer, center_cell: Vector2i, layer_name: String) -> bool:
	# Düşman için minimum 4 tile yükseklik gerekli (daha güvenli)
	var min_height = 4
	
	print("🔍 HEIGHT CHECK: Checking clearance above %s" % center_cell)
	
	# Spawn alanının üstündeki tile'ları kontrol et
	for i in range(1, min_height + 1):
		var check_cell = center_cell + Vector2i(0, -i)  # Yukarı doğru
		var tile_data = tile_map.get_cell_tile_data(check_cell)
		
		print("  📍 Checking cell %s (height: %d)" % [check_cell, i])
		
		# Eğer üstte HERHANGİ BİR tile varsa, yeterli yükseklik yok
		if tile_data:
			var custom_data = tile_data.get_custom_data(layer_name)
			print("    ❌ Found tile with data: '%s'" % custom_data)
			
			# Solid tile'lar: wall, ceiling, platform vb.
			if custom_data in ["wall", "ceiling", "platform", "solid", "block", "terrain"]:
				print("❌ HEIGHT CHECK FAILED: Solid tile at %s (height: %d, data: %s)" % [check_cell, i, custom_data])
				return false
			else:
				# Eğer tile var ama solid değilse, yine de yükseklik yok
				print("❌ HEIGHT CHECK FAILED: Any tile at %s (height: %d, data: %s)" % [check_cell, i, custom_data])
				return false
		else:
			print("    ✅ No tile found - clear space")
	
	print("✅ HEIGHT CHECK PASSED: Clear space above %s (height: %d+)" % [center_cell, min_height])
	return true

func _get_chunk_type_for_node(chunk_node: Node2D) -> String:
	# Determine chunk type based on chunk name or other properties
	var chunk_name = chunk_node.name.to_lower()
	if "combat" in chunk_name:
		return "combat"
	elif "dungeon" in chunk_name:
		return "dungeon"
	elif "boss" in chunk_name:
		return "dungeon"  # Boss chunks are dungeon type
	else:
		return "basic"

func _clear_all_enemies_from_previous_level() -> void:
	print("[LevelGenerator] Clearing all enemies from previous level...")
	
	# Clear enemies from all chunks
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var cell = grid[x][y]
			if cell.chunk:
				_clear_enemies_from_chunk(cell.chunk)
	
	# Clear enemies from unified terrain if it exists
	if unified_terrain:
		_clear_enemies_from_chunk(unified_terrain)
	
	print("[LevelGenerator] Enemy cleanup completed")

func _clear_enemies_from_chunk(chunk_node: Node2D) -> void:
	if not chunk_node:
		return
	
	# Clear tile-based enemy spawners
	var tile_enemy_spawners = chunk_node.find_children("*", "TileEnemySpawner", true, false)
	for spawner in tile_enemy_spawners:
		if spawner.has_method("clear_enemies"):
			spawner.clear_enemies()
		spawner.queue_free()
	
	# Clear old EnemySpawner nodes (legacy system)
	var enemy_spawners = chunk_node.find_children("*", "EnemySpawner", true, false)
	for spawner in enemy_spawners:
		if spawner.has_method("clear_enemies"):
			spawner.clear_enemies()
		spawner.queue_free()
	
	# Clear any remaining enemy nodes
	var enemies = chunk_node.find_children("*", "BaseEnemy", true, false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	# Clear enemies from SpawnManager if it exists
	var spawn_manager = chunk_node.find_child("SpawnManager", true, false)
	if spawn_manager and spawn_manager.has_method("clear_all_enemies"):
		spawn_manager.clear_all_enemies()

func _remove_legacy_enemy_spawners(chunk_node: Node2D) -> void:
	# Remove old EnemySpawner nodes from chunk (legacy system)
	var enemy_spawners = chunk_node.find_children("*", "EnemySpawner", true, false)
	for spawner in enemy_spawners:
		print("[LevelGenerator] Removing legacy EnemySpawner: %s" % spawner.name)
		spawner.queue_free()
	
	# Remove SpawnManager nodes as well
	var spawn_managers = chunk_node.find_children("*", "SpawnManager", true, false)
	for manager in spawn_managers:
		print("[LevelGenerator] Removing legacy SpawnManager: %s" % manager.name)
		manager.queue_free() 
