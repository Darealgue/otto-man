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
## Playable hücrelerin etrafına kaç kat `full` duvar halkası konacağı.
## 1 = yalnızca yola bitişik halka; 2 = bir dış halka daha (kamera kenarı için).
const SURROUNDING_WALL_RINGS := 2

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
			"res://chunks/dungeon/basic/basic_platform4.tscn",
			"res://chunks/dungeon/basic/basic_platform_exit.tscn"
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
	var spawn_stealth_chest: bool = false
	var stealth_chest_gold: int = 0
	var spawn_dungeon_event: String = ""  # "" | "merchant" | "curse"
	var boss_arena_tier: String = ""  # "" | "mini" | "major"

# Member variables
var grid: Array = []
var chunks_placed: int = 0
var current_path: Array = []
var overview_camera: Camera2D
var is_overview_active: bool = true
var current_path_id_counter: int = 0 # Counter for unique path IDs
var current_grid_height: int = BASE_GRID_HEIGHT # Dynamic height, calculated per level
var _exterior_wall_positions: Array[Vector2i] = []
var _exterior_wall_chunks: Array[Node2D] = []
## Challenge kalp ödülü: segment boyunca retry'larda da kalır; başarılı üretimde temizlenir.
var _segment_force_guaranteed_rescue: bool = false

@export var current_level: int = 1  # Effective level (düşman/spawn için; challenge birikiminden)
var effective_trap_level: int = 1   # Tuzak seviyesi (challenge trap_level_offset)
@export var level_config: LevelConfig  # Reference to our dungeon configuration resource

# --- Boss schedule helpers (debug-only for now) ---
# Levels mapping for boss events; we keep it data-driven and simple
# Kapalıyken bitiş her zaman normal "finish" chunk; boss_arena + kilitli kapı spawn olmaz.
const DUNGEON_BOSS_ARENAS_ENABLED := false
const BOSS_SCHEDULE: Dictionary = {
	3: "mini",
	5: "major",
	7: "mini",
	9: "major",
}

## Segment çıkış anahtarı: kolay hedefler değil, güçlü düşmanlar taşır.
const KEY_CARRIER_FODDER_SCRIPT_MARKERS: Array[String] = [
	"basic/",
	"flying/",
	"turtle/",
]
const KEY_CARRIER_PREFERRED_SCRIPT_MARKERS: Array[String] = [
	"heavy/",
	"canonman/",
	"firemage/",
	"hunter/",
	"summoner/",
	"spearman/",
]
const KEY_CARRIER_EMERGENCY_SCENES: Array[String] = [
	"res://enemy/heavy/heavy_enemy.tscn",
	"res://enemy/spearman/spearman_enemy.tscn",
	"res://enemy/firemage/firemage_enemy.tscn",
]
## Zindan chunk'ları origin'den uzaktır; (0,0) genelde şablon/ghost düşman.
const MIN_KEY_HOLDER_POSITION_SQ: float = 160000.0

func get_boss_event_type(level: int) -> String:
	# Returns "" | "mini" | "major" according to cyclic schedule (3,5,7,9...)
	if not DUNGEON_BOSS_ARENAS_ENABLED:
		return ""
	if level < 3:
		return ""
	var keys: Array[int] = [3, 5, 7, 9]
	var idx: int = (level - 3) % keys.size()
	var mapped_level: int = keys[idx]
	var result = BOSS_SCHEDULE.get(mapped_level, "")
	return String(result)


func get_finish_boss_tier() -> String:
	if not DUNGEON_BOSS_ARENAS_ENABLED:
		return ""
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and bool(drs.get("run_started")):
		var seg: int = int(drs.get("run_segments_completed")) if "run_segments_completed" in drs else int(drs.get("run_segment_count"))
		var max_seg: int = int(drs.get("run_max_segments")) if "run_max_segments" in drs else int(drs.get("MAX_SEGMENTS"))
		if seg >= max_seg:
			var scheduled: String = get_boss_event_type(current_level)
			return "major" if scheduled == "major" else "mini"
		return ""
	return get_boss_event_type(current_level)

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
var _segment_finish_door: Node = null
var _segment_finish_is_boss: bool = false

# Debug-only stats from the last generate_layout()/resolve_junctions() run,
# surfaced together via _debug_print_generation_summary().
var _debug_last_max_branch_depth_reached: int = 0
var _debug_last_junctions_formed: int = 0

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

signal level_completed
signal level_started

## Kamp/run dışında sahne doğrudan açılırsa Inspector'daki eski current_level oyunu bozmasın.
func _apply_run_difficulty_from_state() -> void:
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs and drs.run_started:
		var base_diff: int = int(drs.get("run_base_difficulty"))
		var enemy_off: int = int(drs.get("enemy_level_offset"))
		var trap_off: int = int(drs.get("trap_level_offset"))
		current_level = 1 + enemy_off + base_diff
		effective_trap_level = 1 + trap_off + base_diff
		current_level = clampi(current_level, 1, 9)
		effective_trap_level = clampi(effective_trap_level, 1, 9)
		print(
			"[LevelGenerator] Run difficulty -> level=%d trap=%d (base_diff=%d enemy_off=%d trap_off=%d size_off=%d)" % [
				current_level, effective_trap_level, base_diff, enemy_off, trap_off,
				int(drs.get("dungeon_size_offset"))
			]
		)
	else:
		if current_level != 1:
			push_warning(
				"[LevelGenerator] Aktif zindan run'ı yok; Inspector'daki current_level=%d yok sayılıp 1 kullanılıyor. (Köy→Kamp→Kapı akışını kullan.)" % current_level
			)
		current_level = 1
		effective_trap_level = 1

func _ready() -> void:
	if bool(get_meta("_tutorial_decor_only", false)):
		return
	add_to_group("level_generator")
	print("[LevelGenerator] _ready() called")
	is_overview_active = false  # Zindanda yakın kamera (oyuncu) ile başla; V ile uzak/overview

	_apply_run_difficulty_from_state()
	
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
	_segment_finish_door = null
	_segment_finish_is_boss = false
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

func _free_chunks_from_failed_attempt() -> void:
	if grid.is_empty():
		return
	var freed := 0
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			var cell: GridCell = grid[x][y]
			if cell.chunk and is_instance_valid(cell.chunk):
				cell.chunk.free() # Immediate (not queue_free) - must be gone before the next attempt places new chunks in the same spots
				cell.chunk = null
				freed += 1
	chunks_placed = 0
	placed_gate_positions.clear()
	door_positions.clear()
	for ext_chunk in _exterior_wall_chunks:
		if is_instance_valid(ext_chunk):
			ext_chunk.free()
	_exterior_wall_chunks.clear()
	_exterior_wall_positions.clear()
	if freed > 0:
		print("  Freed %d chunk(s) from previous failed attempt." % freed)

func generate_level() -> bool:
	print("\nStarting level generation...")
	var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("reset_for_segment"):
		stealth_mgr.reset_for_segment()
	var drs_start := get_node_or_null("/root/DungeonRunState")
	_segment_force_guaranteed_rescue = (
		is_instance_valid(drs_start)
		and bool(drs_start.get("run_started"))
		and bool(drs_start.get("guaranteed_rescue_next"))
	)
	if _segment_force_guaranteed_rescue:
		print("[LevelGenerator] ♥ Challenge garanti kurtarma — bu segment için aktif")
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
	var map_level: int = current_level
	var drs = get_node_or_null("/root/DungeonRunState")
	var size_off: int = int(drs.dungeon_size_offset) if drs and drs.run_started else 0
	current_grid_width = level_config.get_length_for_level(map_level) + size_off * 2
	current_grid_width = mini(current_grid_width, level_config.max_length + size_off * 2)
	current_grid_height = BASE_GRID_HEIGHT + floor((map_level - 1) / 4) * 2
	print("  Calculated current_grid_width:", current_grid_width)
	print("  Calculated current_grid_height:", current_grid_height)
	
	# Door positions will be calculated after chunks are created
	# ------------------------------------

	# Make multiple attempts to generate a valid level if needed
	var max_attempts = 5 # Increased attempts slightly
	var attempt = 0

	while attempt < max_attempts:
		print("\n--- Attempt %d --- " % (attempt + 1))
		
		# Free any chunks (and their spawned enemies/decorations) placed during a
		# previous failed attempt. `grid = []` below only resets the LOGICAL grid;
		# without this, the actual chunk scene nodes from the previous attempt
		# stay in the tree and the next attempt's chunks get placed right on top
		# of them (stacked/overlapping chunks + duplicated enemy spawns).
		_free_chunks_from_failed_attempt()
		_exterior_wall_positions.clear()
		_exterior_wall_chunks.clear()
		
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
					_debug_print_generation_summary()
					if DEBUG_ENEMY_TILES:
						_debug_print_ascii_grid()
					unify_terrain()
					_populate_traps_on_unified_terrain()
					setup_level_transitions()
					spawn_player()
					if _segment_force_guaranteed_rescue:
						if _level_has_rescue_room():
							if is_instance_valid(drs_start):
								drs_start.guaranteed_rescue_next = false
							print("[LevelGenerator] ♥ Garanti kurtarma odası yerleştirildi")
						else:
							push_error("[LevelGenerator] ♥ Garanti kurtarma seçildi ama odası yok — segment üretimi hatalı")
					_segment_force_guaranteed_rescue = false
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
	_segment_force_guaranteed_rescue = false
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
		if DEBUG_ENEMY_TILES:
			print("  BFS: Processing", current, "Connections:", grid[current.x][current.y].connections)
		
		# Check if we've reached the finish
		if current == finish_pos:
			if DEBUG_ENEMY_TILES:
				print("  BFS: Reached Finish!")
			path_found = true
			break # Exit BFS loop
		
		# Add all connected neighbors
		for dir_enum in Direction.values():
			var dir = dir_enum # Use a distinct variable name
			# Check if the current cell has an outgoing connection in this direction
			if grid[current.x][current.y].connections[dir]:
				var next_pos = current + DIRECTION_VECTORS[dir]
				if DEBUG_ENEMY_TILES:
					print("    BFS: Checking neighbor", next_pos, "in direction", dir)
				
				if is_valid_position(next_pos):
					# Check if neighbor hasn't been visited yet
					if not visited.has(next_pos):
						# Verify the connection is two-way (neighbor connects back)
						var opposite_dir = get_opposite_direction(dir)
						# Check if neighbor cell exists and has the reverse connection
						if grid[next_pos.x][next_pos.y].connections[opposite_dir]:
							if DEBUG_ENEMY_TILES:
								print("      BFS: Valid neighbor found! Adding to queue.", "Neighbor connections:", grid[next_pos.x][next_pos.y].connections)
							queue.append(next_pos)
							visited[next_pos] = true
						else:
							if DEBUG_ENEMY_TILES:
								print("      BFS: Neighbor %s does not connect back (Connections: %s). Skipping." % [str(next_pos), str(grid[next_pos.x][next_pos.y].connections)])
					else:
						if DEBUG_ENEMY_TILES:
							print("      BFS: Neighbor %s already visited. Skipping." % str(next_pos))
				else:
					if DEBUG_ENEMY_TILES:
						print("    BFS: Neighbor %s is outside grid bounds. Skipping." % str(next_pos))
			#else: # Optional: Log if current cell had no connection in this dir
			#	if DEBUG_ENEMY_TILES:
			#		print("    BFS: No connection from current %s in direction %d" % [str(current), dir])
				
	# After BFS loop, check the result and return
	if path_found:
		if DEBUG_ENEMY_TILES:
			print("Valid path found from start to finish!")
		return true
	else:
		if DEBUG_ENEMY_TILES:
			print("No valid path found from start to finish after BFS!")
		return false

func generate_layout() -> bool:
	print("\nPhase 1: Generating abstract layout...")
	
	# Get level-specific values
	var num_branches = level_config.get_num_branches_for_level(current_level)
	var num_dead_ends = level_config.get_num_dead_ends_for_level(current_level)
	var num_main_paths = level_config.get_num_main_paths_for_level(current_level)
	var max_branch_depth = level_config.get_max_branch_depth_for_level(current_level)
	
	# Initialize path generator
	var path_gen = PathGenerator.new(current_grid_width, current_grid_height) # Use current_grid_height
	print("  Initialized PathGenerator with width:", current_grid_width)
	
	# Set start position
	var start_pos = Vector2i(0, current_grid_height / 2) # Use current_grid_height
	
	# Set up start position with proper connections
	if grid[start_pos.x][start_pos.y].visited:
		push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(start_pos), grid[start_pos.x][start_pos.y].visited_by, "generate_layout_start"])
	grid[start_pos.x][start_pos.y].cell_type = CellType.MAIN_PATH
	grid[start_pos.x][start_pos.y].visited = true
	grid[start_pos.x][start_pos.y].visited_by = "generate_layout_start" # Track visit
	set_single_open_connection(start_pos, Direction.RIGHT)
	
	# Randomize finish position with more vertical variation
	var finish_y = randi() % (current_grid_height - 4) + 2 # Range 2 to current_grid_height - 3
	var finish_pos = Vector2i(current_grid_width - 2, clamp(finish_y, 2, current_grid_height - 3))
	
	# Set up finish position with proper connections
	if grid[finish_pos.x][finish_pos.y].visited:
		push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(finish_pos), grid[finish_pos.x][finish_pos.y].visited_by, "generate_layout_finish"])
	grid[finish_pos.x][finish_pos.y].cell_type = CellType.MAIN_PATH
	grid[finish_pos.x][finish_pos.y].visited = true
	grid[finish_pos.x][finish_pos.y].visited_by = "generate_layout_finish" # Track visit
	set_single_open_connection(finish_pos, Direction.LEFT)
	
	# Ensure the cell before finish has a right connection
	var pre_finish_pos = Vector2i(finish_pos.x - 1, finish_pos.y)
	if is_valid_position(pre_finish_pos):
		if grid[pre_finish_pos.x][pre_finish_pos.y].visited:
			push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(pre_finish_pos), grid[pre_finish_pos.x][pre_finish_pos.y].visited_by, "generate_layout_pre_finish"])
		grid[pre_finish_pos.x][pre_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[pre_finish_pos.x][pre_finish_pos.y].visited = true
		grid[pre_finish_pos.x][pre_finish_pos.y].visited_by = "generate_layout_pre_finish" # Track visit
		set_single_open_connection(pre_finish_pos, Direction.RIGHT)
	
	var all_paths = [] # Flat list of every segment's points, used later as a dead-end source
	# Explicit work queue for controlled, depth-limited branching. This replaces
	# the old pattern of appending new branches to the very array a `for` loop was
	# iterating over (which made sub-branching depend on undefined engine behavior).
	# `queue` only ever grows via explicit push_back calls below and is walked with
	# a manual index, so its traversal order and termination are fully deterministic.
	var queue: Array = []
	
	# Generate first main path (always from start)
	var first_path = generate_main_path(start_pos, finish_pos, path_gen)
	if first_path.is_empty():
		return false
	all_paths.append(first_path)
	queue.append({"points": first_path, "depth": 0})
	_connect_lead_in_cell(pre_finish_pos, Direction.RIGHT)
	
	# Generate additional main paths if needed
	for i in range(1, num_main_paths):
		# Find a suitable starting point from the first path
		var branch_point = find_suitable_branch_point(first_path)
		if branch_point == null:
			continue
			
		# Generate a new finish position with more vertical variation
		var new_finish_x = current_grid_width - 2 - (i * 2)  # Space paths apart
		var new_finish_y = randi() % (current_grid_height - 4) + 2
		var new_finish_pos = Vector2i(new_finish_x, clamp(new_finish_y, 2, current_grid_height - 3))
		
		# Set up connections for the new finish position
		if grid[new_finish_pos.x][new_finish_pos.y].visited:
			push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(new_finish_pos), grid[new_finish_pos.x][new_finish_pos.y].visited_by, "generate_layout_new_finish"])
		grid[new_finish_pos.x][new_finish_pos.y].cell_type = CellType.MAIN_PATH
		grid[new_finish_pos.x][new_finish_pos.y].visited = true
		grid[new_finish_pos.x][new_finish_pos.y].visited_by = "generate_layout_new_finish" # Track visit
		set_single_open_connection(new_finish_pos, Direction.LEFT)
		
		# Ensure the cell before new finish has a right connection
		var pre_new_finish_pos = Vector2i(new_finish_pos.x - 1, new_finish_pos.y)
		if is_valid_position(pre_new_finish_pos):
			if grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited:
				push_warning("Cell %s already visited by '%s', now being revisited by '%s'" % [str(pre_new_finish_pos), grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited_by, "generate_layout_pre_new_finish"])
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].cell_type = CellType.MAIN_PATH
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited = true
			grid[pre_new_finish_pos.x][pre_new_finish_pos.y].visited_by = "generate_layout_pre_new_finish" # Track visit
			set_single_open_connection(pre_new_finish_pos, Direction.RIGHT)
		
		# Generate new path
		var new_path = generate_main_path(branch_point, new_finish_pos, path_gen)
		if not new_path.is_empty():
			all_paths.append(new_path)
			queue.append({"points": new_path, "depth": 0})
			_connect_lead_in_cell(pre_new_finish_pos, Direction.RIGHT)
	
	# Walk the queue: every segment (main path or branch) may spawn further
	# branches up to `max_branch_depth_for_level`, each becoming a new queue entry
	# at depth+1. This is how "dallardan dallanma" (branches off branches) is now
	# an explicit, bounded feature instead of an accidental side effect.
	var queue_index := 0
	var max_depth_reached := 0
	while queue_index < queue.size():
		var segment = queue[queue_index]
		queue_index += 1
		var segment_depth: int = segment["depth"]
		max_depth_reached = maxi(max_depth_reached, segment_depth)
		if segment_depth >= max_branch_depth:
			continue
		for branch_start in _pick_branch_points(segment["points"], num_branches):
			var branch_points = generate_branch(branch_start)
			if not branch_points.is_empty():
				all_paths.append(branch_points)
				queue.append({"points": branch_points, "depth": segment_depth + 1})
	
	_debug_last_max_branch_depth_reached = max_depth_reached
	if DEBUG_ENEMY_TILES:
		print("  generate_layout: %d segment(s) carved (max depth reached: %d, cap: %d)" % [queue.size(), max_depth_reached, max_branch_depth])
	
	# Add dead ends
	for _i in range(num_dead_ends):
		add_dead_end(all_paths)
	
	# Challenge ödülü: uygun dead-end yoksa bir yatay çıkmaz yol aç (kurtarma odası için zemin)
	if _needs_guaranteed_rescue_room_this_segment():
		_add_one_rescue_dead_end(all_paths)
	
	return true

# Picks up to `desired_count` random candidate points (in the first two-thirds of
# the segment, so branches don't sprout right next to a finish/rejoin point) to
# spawn new branches from. Replaces the old fixed "every 4 cells" stride with a
# count that actually comes from LevelConfig.
func _pick_branch_points(path_points: Array, desired_count: int) -> Array:
	var result: Array = []
	if desired_count <= 0 or path_points.size() < 4:
		return result
	var last_third_start = maxi(3, path_points.size() * 2 / 3)
	var candidate_indices: Array = []
	for i in range(2, last_third_start):
		candidate_indices.append(i)
	candidate_indices.shuffle()
	for idx in candidate_indices:
		if result.size() >= desired_count:
			break
		result.append(path_points[idx])
	return result

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
	var boss_tier := get_finish_boss_tier()
	if not boss_tier.is_empty():
		print("%s-boss level: placing boss_arena at finish position %s (tier=%s)" % [
			boss_tier.capitalize(), str(finish_pos), boss_tier
		])
		grid[finish_pos.x][finish_pos.y].boss_arena_tier = boss_tier
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
	if _segment_force_guaranteed_rescue and not _level_has_rescue_room():
		if _inject_emergency_rescue_dead_end():
			print("[LevelGenerator] ♥ Acil kurtarma dead-end enjekte edildi (populate)")
		else:
			push_warning("[LevelGenerator] ♥ Garanti kurtarma: acil dead-end enjekte edilemedi")
	_tag_stealth_chest_side_paths()
	_tag_dungeon_event_side_paths()

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
			if DEBUG_ENEMY_TILES:
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

	_place_exterior_wall_chunks()

	return true  # Return true if we've successfully populated all required cells

func _tag_villager_and_vip_deadends() -> void:
	var deadends: Array[Vector2i] = _collect_horizontal_rescue_deadends()

	deadends.shuffle()
	var force_guaranteed := _segment_force_guaranteed_rescue
	var rescue_chance: float = 0.12
	if force_guaranteed:
		rescue_chance = 1.0
	elif level_config and level_config.has_method("get_rescue_room_chance"):
		rescue_chance = level_config.get_rescue_room_chance(current_level)
	var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("consume_stealth_rescue_bonus"):
		rescue_chance = stealth_mgr.consume_stealth_rescue_bonus(rescue_chance)
		if rescue_chance >= 0.27:
			print("[LevelGenerator] Stealth rescue bonus uygulandı — rescue_chance=%.2f" % rescue_chance)

	var placed_rescue := false
	for pos in deadends:
		if randf() >= rescue_chance:
			continue
		if _assign_rescue_room_at(pos):
			placed_rescue = true

	if force_guaranteed and not placed_rescue:
		for pos in deadends:
			if _assign_rescue_room_at(pos):
				placed_rescue = true
				print("[LevelGenerator] ♥ Garanti kurtarma odası @ %s" % str(pos))
				break

func _collect_horizontal_rescue_deadends() -> Array[Vector2i]:
	var deadends: Array[Vector2i] = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos := Vector2i(x, y)
			var c: GridCell = grid[x][y] as GridCell
			if not c.visited or c.chunk != null:
				continue
			if not c.reserved_chunk.is_empty():
				continue
			if c.cell_type != CellType.DEAD_END and c.cell_type != CellType.BRANCH_PATH:
				continue
			var conn_count := 0
			for dir in Direction.values():
				if c.connections[dir]:
					conn_count += 1
			if conn_count != 1:
				continue
			if pos.x <= 0:
				continue
			var dir_idx := _single_open_dir_index(c)
			if dir_idx != Direction.LEFT and dir_idx != Direction.RIGHT:
				continue
			deadends.append(pos)
	return deadends


func _level_has_rescue_room() -> bool:
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var reserved: String = String(grid[x][y].reserved_chunk)
			if _is_rescue_reserved_chunk(reserved):
				return true
	return false


func _needs_guaranteed_rescue_room_this_segment() -> bool:
	return _segment_force_guaranteed_rescue


func _add_one_rescue_dead_end(all_paths: Array) -> bool:
	# Önce ana yol ortasından (x>=2) dene; başlangıç hücresine yapışık dead-end filtreleniyordu.
	var anchor_positions: Array[Vector2i] = []
	for path in all_paths:
		if not (path is Array):
			continue
		for pos in path:
			if pos is Vector2i and is_valid_position(pos) and pos.x >= 2:
				anchor_positions.append(pos)
	anchor_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x > b.x
	)
	for pos in anchor_positions:
		for side_dir in [Direction.LEFT, Direction.RIGHT]:
			var dead_pos: Vector2i = pos + DIRECTION_VECTORS[side_dir]
			if not is_valid_position(dead_pos):
				continue
			if dead_pos.x <= 0:
				continue
			if grid[dead_pos.x][dead_pos.y].visited:
				continue
			grid[dead_pos.x][dead_pos.y].visited = true
			grid[dead_pos.x][dead_pos.y].visited_by = "add_challenge_rescue"
			grid[dead_pos.x][dead_pos.y].cell_type = CellType.DEAD_END
			var open_from_dead: int = Direction.RIGHT if side_dir == Direction.LEFT else Direction.LEFT
			set_single_open_connection(dead_pos, open_from_dead)
			set_grid_connection(pos, side_dir, true)
			print("[LevelGenerator] ♥ Challenge kurtarma dead-end @ %s (anchor %s)" % [str(dead_pos), str(pos)])
			return true
	return false


func _inject_emergency_rescue_dead_end() -> bool:
	for x in range(2, maxi(3, current_grid_width - 2)):
		for y in range(current_grid_height):
			var pos := Vector2i(x, y)
			var c: GridCell = grid[x][y] as GridCell
			if not c.visited or c.chunk != null:
				continue
			if c.cell_type != CellType.MAIN_PATH and c.cell_type != CellType.BRANCH_PATH:
				continue
			for side_dir in [Direction.LEFT, Direction.RIGHT]:
				var dead_pos: Vector2i = pos + DIRECTION_VECTORS[side_dir]
				if not is_valid_position(dead_pos) or dead_pos.x <= 0:
					continue
				if grid[dead_pos.x][dead_pos.y].visited:
					continue
				grid[dead_pos.x][dead_pos.y].visited = true
				grid[dead_pos.x][dead_pos.y].visited_by = "emergency_rescue"
				grid[dead_pos.x][dead_pos.y].cell_type = CellType.DEAD_END
				var open_from_dead: int = Direction.RIGHT if side_dir == Direction.LEFT else Direction.LEFT
				set_single_open_connection(dead_pos, open_from_dead)
				set_grid_connection(pos, side_dir, true)
				if _assign_rescue_room_at(dead_pos):
					print("[LevelGenerator] ♥ Acil kurtarma @ %s" % str(dead_pos))
					return true
	return false


func _assign_rescue_room_at(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	var c: GridCell = grid[pos.x][pos.y] as GridCell
	if c.chunk != null or not c.reserved_chunk.is_empty():
		return false
	var dir_idx := _single_open_dir_index(c)
	if dir_idx != Direction.LEFT and dir_idx != Direction.RIGHT:
		return false
	if randi() % 2 == 0:
		c.reserved_chunk = "villager_dead_end_left" if dir_idx == Direction.LEFT else "villager_dead_end_right"
	else:
		c.reserved_chunk = "vip_dead_end_left" if dir_idx == Direction.LEFT else "vip_dead_end_right"
	return true

func _single_open_dir_index(c: GridCell) -> int:
	for d in Direction.values():
		if c.connections[d]:
			return d
	return Direction.LEFT


const STEALTH_CHEST_SCRIPT := preload("res://interactables/dungeon/StealthTreasureChest.gd")
const DUNGEON_EVENT_SCRIPT := preload("res://interactables/dungeon/DungeonEventInteractable.gd")


func _tag_stealth_chest_side_paths() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not bool(drs.get("run_started")):
		return
	var candidates: Array[Vector2i] = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos := Vector2i(x, y)
			var c: GridCell = grid[x][y] as GridCell
			if not c.visited or c.chunk != null:
				continue
			if c.cell_type != CellType.DEAD_END and c.cell_type != CellType.BRANCH_PATH:
				continue
			if not c.reserved_chunk.is_empty() and _is_rescue_reserved_chunk(c.reserved_chunk):
				continue
			var conn_count := 0
			for dir in Direction.values():
				if c.connections[dir]:
					conn_count += 1
			if conn_count < 1 or conn_count > 2:
				continue
			if pos.x <= 1:
				continue
			candidates.append(pos)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var max_chests: int = mini(4, candidates.size())
	var chest_count: int = randi_range(mini(2, max_chests), max_chests)
	for i in range(chest_count):
		var pos: Vector2i = candidates[i]
		var cell: GridCell = grid[pos.x][pos.y] as GridCell
		cell.spawn_stealth_chest = true
		cell.stealth_chest_gold = randi_range(12, 25)
	print("[LevelGenerator] Stealth sandık işaretlendi: %d yan yol hücresi" % chest_count)


func _tag_dungeon_event_side_paths() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not bool(drs.get("run_started")):
		return
	var event_chance: float = 0.14
	if level_config and level_config.has_method("get_dungeon_event_chance"):
		event_chance = level_config.get_dungeon_event_chance(current_level)
	var merchant_candidates: Array[Vector2i] = []
	var curse_candidates: Array[Vector2i] = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos := Vector2i(x, y)
			var c: GridCell = grid[x][y] as GridCell
			if not c.visited or c.chunk != null:
				continue
			if c.cell_type != CellType.DEAD_END and c.cell_type != CellType.BRANCH_PATH:
				continue
			if not c.reserved_chunk.is_empty() and _is_rescue_reserved_chunk(c.reserved_chunk):
				continue
			if c.spawn_stealth_chest or not c.spawn_dungeon_event.is_empty():
				continue
			var conn_count := 0
			for dir in Direction.values():
				if c.connections[dir]:
					conn_count += 1
			if conn_count < 1 or conn_count > 2:
				continue
			if pos.x <= 1:
				continue
			merchant_candidates.append(pos)
			curse_candidates.append(pos)
	if merchant_candidates.is_empty() and curse_candidates.is_empty():
		return
	merchant_candidates.shuffle()
	curse_candidates.shuffle()
	var tagged: int = 0
	if not merchant_candidates.is_empty() and randf() < event_chance:
		grid[merchant_candidates[0].x][merchant_candidates[0].y].spawn_dungeon_event = "merchant"
		tagged += 1
	if not curse_candidates.is_empty() and randf() < event_chance:
		var curse_pos: Vector2i = curse_candidates[0]
		if grid[curse_pos.x][curse_pos.y].spawn_dungeon_event.is_empty():
			grid[curse_pos.x][curse_pos.y].spawn_dungeon_event = "curse"
			tagged += 1
	if tagged > 0:
		print("[LevelGenerator] Mini-event odası işaretlendi: %d (şans=%.2f)" % [tagged, event_chance])


func _is_rescue_reserved_chunk(reserved: String) -> bool:
	var key: String = reserved.to_lower()
	return "villager" in key or "vip" in key


func _collect_floor_decor_anchor_cells(tile_map: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tile_set: TileSet = tile_map.tile_set
	if tile_set == null:
		return out
	var decor_layer_index: int = -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == "decor_anchor":
			decor_layer_index = i
			break
	if decor_layer_index == -1:
		return out
	for cell in tile_map.get_used_cells():
		var tile_data: TileData = tile_map.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var tag: String = str(tile_data.get_custom_data("decor_anchor")).strip_edges()
		if _tutorial_decor_anchor_is_floor_only(tag):
			out.append(cell)
	return out


func _collect_stealth_chest_spawn_cell(tile_map: Node) -> Vector2i:
	var anchor_cells: Array[Vector2i] = _collect_floor_decor_anchor_cells(tile_map)
	if not anchor_cells.is_empty():
		return anchor_cells.pick_random()
	# Fallback: decor_anchor yoksa chunk ortasına yakın dolu zemin hücresi
	var used_cells: Array = tile_map.get_used_cells()
	if used_cells.is_empty():
		return Vector2i(-9999, -9999)
	var best: Vector2i = used_cells[0]
	var best_score: int = -999999
	var center_x: float = 0.0
	for c in used_cells:
		center_x += float(c.x)
	center_x /= float(used_cells.size())
	for c in used_cells:
		var cell: Vector2i = c as Vector2i
		if tile_map.get_cell_source_id(cell) == -1:
			continue
		var score: int = -int(absf(float(cell.x) - center_x)) + cell.y
		if score > best_score:
			best_score = score
			best = cell
	return best


func _spawn_stealth_chest_for_chunk(chunk_node: Node2D) -> void:
	if not chunk_node.has_meta("stealth_chest_gold"):
		return
	var gold_total: int = int(chunk_node.get_meta("stealth_chest_gold"))
	chunk_node.remove_meta("stealth_chest_gold")
	if gold_total <= 0:
		return
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not bool(drs.get("run_started")):
		return
	var tile_map: Node = chunk_node.find_child("TileMapLayer", true, false)
	if tile_map == null:
		push_warning("[LevelGenerator] Stealth sandık: TileMapLayer yok (%s)" % chunk_node.name)
		return
	var cell: Vector2i = _collect_stealth_chest_spawn_cell(tile_map)
	if cell.x <= -9000:
		push_warning("[LevelGenerator] Stealth sandık: zemin hücresi bulunamadı (%s)" % chunk_node.name)
		return
	var spawn_pos: Vector2 = _compute_decoration_spawn_position(
		tile_map,
		cell,
		DecorationConfig.SpawnLocation.FLOOR_CENTER
	)
	var chest: StealthTreasureChest = STEALTH_CHEST_SCRIPT.new()
	chest.name = "StealthTreasureChest"
	chest.setup(gold_total)
	chunk_node.add_child(chest)
	chest.global_position = spawn_pos + Vector2(0.0, 5.0)
	print("[LevelGenerator] Stealth sandık spawn @ %s chunk=%s gold=%d" % [str(spawn_pos), chunk_node.name, gold_total])


func _spawn_dungeon_event_for_chunk(chunk_node: Node2D) -> void:
	if not chunk_node.has_meta("dungeon_event_type"):
		return
	var event_type: String = String(chunk_node.get_meta("dungeon_event_type"))
	chunk_node.remove_meta("dungeon_event_type")
	if event_type != "merchant" and event_type != "curse":
		return
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not bool(drs.get("run_started")):
		return
	var tile_map: Node = chunk_node.find_child("TileMapLayer", true, false)
	if tile_map == null:
		push_warning("[LevelGenerator] Mini-event: TileMapLayer yok (%s)" % chunk_node.name)
		return
	var cell: Vector2i = _collect_stealth_chest_spawn_cell(tile_map)
	if cell.x <= -9000:
		push_warning("[LevelGenerator] Mini-event: zemin hücresi bulunamadı (%s)" % chunk_node.name)
		return
	var spawn_pos: Vector2 = _compute_decoration_spawn_position(
		tile_map,
		cell,
		DecorationConfig.SpawnLocation.FLOOR_CENTER
	)
	var event_node: DungeonEventInteractable = DUNGEON_EVENT_SCRIPT.new()
	event_node.name = "DungeonEvent_%s" % event_type
	event_node.setup(event_type, current_level)
	chunk_node.add_child(event_node)
	event_node.global_position = spawn_pos + Vector2(0.0, 5.0)
	print("[LevelGenerator] Mini-event spawn @ %s type=%s chunk=%s" % [str(spawn_pos), event_type, chunk_node.name])

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
	
	if DEBUG_ENEMY_TILES:
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
	if DEBUG_ENEMY_TILES:
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

	var placed_cell: GridCell = grid[pos.x][pos.y] as GridCell

	# Extra setup for boss arenas (mini-boss levels)
	if chunk_type == "boss_arena":
		var tier: String = String(placed_cell.boss_arena_tier)
		if tier.is_empty():
			tier = "mini"
		_spawn_miniboss_in_arena(chunk, tier)

	# TileMap tabanlı dekorasyonları oluştur
	if placed_cell.spawn_stealth_chest:
		chunk.set_meta("stealth_chest_gold", placed_cell.stealth_chest_gold)
	if not placed_cell.spawn_dungeon_event.is_empty():
		chunk.set_meta("dungeon_event_type", placed_cell.spawn_dungeon_event)
	_populate_decorations_from_tilemap(chunk)
	
	# Remove old EnemySpawner nodes from chunk (legacy system)
	_remove_legacy_enemy_spawners(chunk)
	
	# TileMap tabanlı düşmanları oluştur (boss arenada ekstra spawn yok)
	if chunk_type != "boss_arena":
		_populate_enemies_from_tilemap(chunk)

	# NOTE: Trap population moved to after unify_terrain() — see _populate_traps_on_unified_terrain()
	
	if DEBUG_ENEMY_TILES:
		print("Successfully placed " + chunk_type + " at " + str(pos)) # Improved logging
	return true

const DEBUG_DECOR_TILES: bool = false


func _decor_entry_has_loadable_visual(decoration_data: Dictionary) -> bool:
	if decoration_data.is_empty():
		return false
	var scene_paths_var: Variant = decoration_data.get("scene_paths", null)
	if typeof(scene_paths_var) == TYPE_ARRAY:
		for v in scene_paths_var as Array:
			var p := String(v).strip_edges()
			if not p.is_empty() and ResourceLoader.exists(p):
				return true
	elif typeof(scene_paths_var) == TYPE_PACKED_STRING_ARRAY:
		for v in scene_paths_var as PackedStringArray:
			var p2 := String(v).strip_edges()
			if not p2.is_empty() and ResourceLoader.exists(p2):
				return true
	var sprites_var: Variant = decoration_data.get("sprites", null)
	if typeof(sprites_var) == TYPE_ARRAY:
		for v in sprites_var as Array:
			var ps := String(v).strip_edges()
			if not ps.is_empty() and ResourceLoader.exists(ps):
				return true
	elif typeof(sprites_var) == TYPE_PACKED_STRING_ARRAY:
		for v in sprites_var as PackedStringArray:
			var ps2 := String(v).strip_edges()
			if not ps2.is_empty() and ResourceLoader.exists(ps2):
				return true
	return false


func _is_tutorial_heavy_blocking_decor(decor_name: String) -> bool:
	match decor_name:
		"gate1", "gate2", "box2", "box3", "pipe2", "banner1", "sculpture1", "sculpture2":
			return true
		_:
			return false


func _tutorial_decor_anchor_is_floor_only(tag: String) -> bool:
	var t := tag.strip_edges()
	return t == "floor_surface" or t == "floor" or t == "floor_breakable" or t == "forest_floor_surface"


func _is_cell_on_used_rect_outer_boundary(used_rect: Rect2i, cell: Vector2i) -> bool:
	var left_x := used_rect.position.x
	var right_x := used_rect.position.x + used_rect.size.x - 1
	var top_y := used_rect.position.y
	var bottom_y := used_rect.position.y + used_rect.size.y - 1
	var margin := 4
	return cell.x <= left_x + margin or cell.x >= right_x - margin or cell.y <= top_y + margin or cell.y >= bottom_y - margin


func _populate_decorations_from_tilemap(chunk_node: Node2D) -> void:
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	if not tile_map:
		if DEBUG_DECOR_TILES:
			print("[DecorPopulate] SKIPPING: Chunk '%s' does not have a child node named 'TileMapLayer'." % chunk_node.name)
		return
	_populate_decorations_from_tilemap_impl(tile_map, chunk_node, self, false, {
		"tutorial": false,
		"skip_gold_breakable": false,
		"require_loadable_visual": false,
		"floor_anchors_only": false,
	})
	_spawn_stealth_chest_for_chunk(chunk_node)
	_spawn_dungeon_event_for_chunk(chunk_node)


func run_tutorial_tile_decorations(tile_map: TileMapLayer, output_parent: Node2D, scene_root: Node2D, tutorial_options: Dictionary = {}) -> void:
	if tile_map == null or output_parent == null or scene_root == null:
		push_warning("[LevelGenerator] run_tutorial_tile_decorations: geçersiz parametre.")
		return
	var opts := tutorial_options.duplicate()
	opts["tutorial"] = true
	_populate_decorations_from_tilemap_impl(tile_map, scene_root, output_parent, true, opts)


func _populate_decorations_from_tilemap_impl(tile_map: Node, chunk_node: Node2D, output_parent: Node, skip_chunk_pixel_bounds: bool, decoration_options: Dictionary = {}) -> void:
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
		if DEBUG_DECOR_TILES:
			print("[DecorPopulate] SKIPPING: TileSet in chunk '%s' does not have a custom data layer named '%s'." % [chunk_node.name, decor_layer_name])
		return

	var decor_used_rect: Rect2i = tile_map.get_used_rect()
	var used_cells = tile_map.get_used_cells()
	var found_data_count = 0
	var chunk_placed_lighting_world: Array[Vector2] = []

	var is_tutorial: bool = bool(decoration_options.get("tutorial", false))
	var chance_scale: float = clampf(float(decoration_options.get("chance_scale", 0.16)), 0.0, 1.0)
	var max_spawns: int = maxi(0, int(decoration_options.get("max_spawns", 52)))
	var skip_ceiling: bool = bool(decoration_options.get("skip_ceiling", true))
	var skip_gold_breakable: bool = bool(decoration_options.get("skip_gold_breakable", true))
	var require_loadable_visual: bool = bool(decoration_options.get("require_loadable_visual", is_tutorial))
	var skip_heavy_blocking: bool = bool(decoration_options.get("skip_heavy_blocking", true))
	var floor_anchors_only: bool = bool(decoration_options.get("floor_anchors_only", is_tutorial))
	var skip_tutorial_door_proximity: bool = is_tutorial and bool(decoration_options.get("skip_tutorial_door_proximity", true))
	var skip_tutorial_chunk_edge: bool = is_tutorial and bool(decoration_options.get("skip_tutorial_chunk_edge", true))
	var tutorial_placed: int = 0
	var asset_visual_cache: Dictionary = {}

	var iter_cells: Array = used_cells
	if floor_anchors_only:
		var floor_cells: Array[Vector2i] = []
		for c in used_cells:
			var td0: TileData = tile_map.get_cell_tile_data(c)
			if td0 == null:
				continue
			var cd0: Variant = td0.get_custom_data(decor_layer_name)
			if not cd0:
				continue
			var tg0 := str(cd0).strip_edges()
			if _tutorial_decor_anchor_is_floor_only(tg0):
				floor_cells.append(c)
		iter_cells = floor_cells

	for cell in iter_cells:
		if is_tutorial and max_spawns > 0 and tutorial_placed >= max_spawns:
			return
		var tile_data = tile_map.get_cell_tile_data(cell)
		if not tile_data:
			continue
		var custom_data = tile_data.get_custom_data(decor_layer_name)
		if not custom_data:
			continue
		var tag := str(custom_data).strip_edges()
		if tag.is_empty():
			continue
		if floor_anchors_only and not _tutorial_decor_anchor_is_floor_only(tag):
			continue
		var rules_key := tag
		if not config.PRIORITY_DECOR_RULES.has(rules_key):
			if rules_key == "right_wall_surface" or rules_key == "lef_wall_surface":
				rules_key = "wall_surface"
		var rules = config.PRIORITY_DECOR_RULES.get(rules_key, null)
		if not rules:
			continue
		if is_tutorial and skip_ceiling and tag == "ceiling_surface":
			continue
		found_data_count += 1

		# --- Hiyerarşik kural sistemi ---
		for rule in rules:
			# Global kural: Chunk'ın en dış sınırındaki tile'larda dekor spawn etme
			if _is_cell_on_used_rect_outer_boundary(decor_used_rect, cell):
				continue
			# Ek güvenlik: Hücre chunk'ın piksel bazlı güvenli alanının dışında mı?
			if not skip_chunk_pixel_bounds and not _is_cell_within_chunk_safe_bounds(tile_map, cell, chunk_node, 160.0):
				continue
			if rule.is_empty():
				continue
			if is_tutorial and skip_gold_breakable:
				var rt: Variant = rule.get("decoration_type", null)
				if rt != null:
					var rti: int = int(rt)
					if rti == int(DecorationConfig.DecorationType.GOLD) or rti == int(DecorationConfig.DecorationType.BREAKABLE):
						continue
			var decoration_pool: Dictionary = config.get_decorations_for_type(rule.decoration_type)
			var roll_chance: float = float(rule.get("chance", 0.0))
			if DecorationConfig.DUNGEON_LIGHTING_SPAWN_CHANCE_MULTIPLIER != 1.0:
				if _priority_rule_can_include_dungeon_lighting(rule, decoration_pool):
					roll_chance = clampf(roll_chance * DecorationConfig.DUNGEON_LIGHTING_SPAWN_CHANCE_MULTIPLIER, 0.0, 1.0)
			if is_tutorial:
				roll_chance = clampf(roll_chance * chance_scale, 0.0, 1.0)
			if randf() >= roll_chance:
				continue
			# Kuralda izin verilen ve lokasyona uygun dekorları filtrele
			var valid_decors = []
			for decor_name in rule.decoration_names:
				if decor_name in decoration_pool:
					var dn := str(decor_name)
					if is_tutorial and skip_heavy_blocking and _is_tutorial_heavy_blocking_decor(dn):
						continue
					if require_loadable_visual:
						var dd_raw: Variant = decoration_pool.get(decor_name, {})
						if typeof(dd_raw) != TYPE_DICTIONARY:
							continue
						var dd_vis: Dictionary = dd_raw
						var has_vis: bool
						if asset_visual_cache.has(dn):
							has_vis = bool(asset_visual_cache[dn])
						else:
							has_vis = _decor_entry_has_loadable_visual(dd_vis)
							asset_visual_cache[dn] = has_vis
						if not has_vis:
							continue
					valid_decors.append(decor_name)
			if valid_decors.is_empty():
				if "gate1" in rule.decoration_names:
					if DEBUG_DECOR_TILES:
						print("[GateDebug] valid_decors EMPTY at tile=", cell, " rule_names=", rule.decoration_names)
				if tag == "ceiling_surface" or tag == "wall_surface":
					if DEBUG_DECOR_TILES:
						print("[WebDebug] Tile ", cell, " tag=", tag, " → valid_decors EMPTY (pool=", decoration_pool, ")")
				continue
			var selected_decor_name = valid_decors.pick_random()
			if selected_decor_name == "gate1" and DEBUG_DECOR_TILES:
				if DEBUG_DECOR_TILES:
					print("[GateDebug] SELECT tile=", cell, " names=", valid_decors)
			if (tag == "ceiling_surface" or tag == "wall_surface") and DEBUG_DECOR_TILES:
				print("[WebDebug] Tile ", cell, " tag=", tag, " pool=", decoration_pool, " valid=", valid_decors, " selected=", selected_decor_name)
			var spawn_loc: int = _derive_spawn_location_from_tile_data(tag, rule)
			if is_tutorial and skip_ceiling and spawn_loc == DecorationConfig.SpawnLocation.CEILING:
				continue
			if floor_anchors_only:
				if spawn_loc != DecorationConfig.SpawnLocation.FLOOR_CENTER and spawn_loc != DecorationConfig.SpawnLocation.FLOOR_CORNER:
					continue
			var spawner = DecorationSpawner.new()
			# Add spawner to scene tree temporarily for door proximity check
			output_parent.add_child(spawner)
			
			var did_spawn = false
			var decoration_instance = spawner.create_decoration_instance(selected_decor_name, rule.decoration_type)
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
						if DEBUG_DECOR_TILES:
							print("[GateDebug] CLEARANCE footprint=", w_tiles, "x", h_tiles, " grow_dir=", grow_dir)
					var anchor: Vector2i = cell
					var dbg: bool = (selected_decor_name == "gate1" or selected_decor_name == "box2")
					if not _has_clearance_tiles(tile_map, anchor, w_tiles, h_tiles, grow_dir, spawn_loc, dbg, selected_decor_name):
						if selected_decor_name == "gate1":
							if DEBUG_DECOR_TILES:
								print("[GateDebug] FAIL clearance at tile=", cell)
						decoration_instance.queue_free()
						spawner.queue_free()
						continue
					# Background support check for pipes/gates only
					if selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "gate1" or selected_decor_name == "gate2":
						var bg_map: Node = _find_background_tilemap(chunk_node)
						if not _has_background_support(bg_map, anchor, w_tiles, h_tiles, grow_dir, dbg, selected_decor_name):
							decoration_instance.queue_free()
							spawner.queue_free()
							continue
					# Additional wall collision guard only for non-floor placements
					var floor_based := (spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CENTER or spawn_loc == DecorationConfig.SpawnLocation.FLOOR_CORNER)
					if not floor_based:
						if _footprint_overlaps_wall(tile_map, anchor, w_tiles, h_tiles, grow_dir, spawn_loc):
							if selected_decor_name == "gate1":
								if DEBUG_DECOR_TILES:
									print("[GateDebug] FAIL border overlap at tile=", cell)
							decoration_instance.queue_free()
							spawner.queue_free()
							continue
			# Skip cells near open chunk edges for floor-like placements (tutorial: tek parça harita, gereksiz pahalı)
			if (not is_tutorial or not skip_tutorial_chunk_edge) and _is_near_open_chunk_edge(tile_map, cell, chunk_node, spawn_loc, rule):
				if tag == "ceiling_surface" or tag == "wall_surface":
					if DEBUG_DECOR_TILES:
						print("[WebDebug] SKIP near edge tile=", cell, " name=", selected_decor_name, " spawn_loc=", spawn_loc)
				decoration_instance.queue_free()
				spawner.queue_free()
				continue
			# Avoid outside L-shaped dead zones
			if _is_outside_L_deadzone(tile_map, cell, spawn_loc):
				if (tag == "ceiling_surface" or tag == "wall_surface") and DEBUG_DECOR_TILES:
					print("[WebDebug] SKIP outside L deadzone tile=", cell, " name=", selected_decor_name, " spawn_loc=", spawn_loc)
				decoration_instance.queue_free()
				spawner.queue_free()
				continue
			output_parent.add_child(decoration_instance)
			# Keep the spawner alive as a child so signal targets remain valid
			# (create_decoration_instance connects signals to spawner methods)
			output_parent.add_child(spawner)
			var spawn_pos: Vector2 = _compute_decoration_spawn_position(tile_map, cell, spawn_loc)
			
			# Check door proximity for gate, pipe and banner decorations (GERÇEK spawn pozisyonu ile)
			if (not is_tutorial or not skip_tutorial_door_proximity) and selected_decor_name in ["gate1", "gate2", "pipe1", "pipe2", "banner1"]:
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
					if DEBUG_DECOR_TILES:
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
					if is_tutorial and bool(decoration_options.get("skip_tutorial_support_search", true)):
						pass
					else:
						var adj: Dictionary = _find_supported_position(spawn_pos, half_w, 12.0, 3.0)
						if selected_decor_name == "gate1" or selected_decor_name == "box2":
							if DEBUG_DECOR_TILES:
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
			if not is_tutorial and (selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "banner1" or selected_decor_name == "sculpture1" or selected_decor_name == "sculpture2") and (_is_near_gate_pos_list(final_pos, float(tile_map.tile_set.tile_size.x) * 5.0) or _is_near_existing_gate(final_pos, float(tile_map.tile_set.tile_size.x) * 5.0)):
				if DEBUG_DECOR_TILES:
					print("[GateDebug] SKIP overlap near existing gate at pos=", final_pos)
				decoration_instance.queue_free()
				spawner.queue_free()
				# do not mark placed; allow next rules to try
				continue
			if DecorationConfig.is_dungeon_lighting_decor(selected_decor_name) and DecorationConfig.dungeon_lighting_too_close(final_pos, chunk_placed_lighting_world):
				decoration_instance.queue_free()
				spawner.queue_free()
				continue
			if selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "box2":
				if DEBUG_DECOR_TILES:
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
				if DEBUG_DECOR_TILES:
					print("[GateDebug] EXTENTS ", selected_decor_name, " sprite_left=", sprite_left_x, " sprite_right=", sprite_right_x,
					" span_left=", span_left_x, " span_right=", span_right_x,
					" diff_left=", diff_left, " diff_right=", diff_right)
				# Y taban hizası: zemin çizgisi vs sprite altı
				var floor_center_dbg: Vector2 = (left_center_dbg + right_center_dbg) * 0.5
				var floor_line_y: float = floor_center_dbg.y + tile_size_dbg.y * 0.5
				var expected_bottom_y: float = floor_line_y + 5.0
				var sprite_bottom_y: float = final_pos.y + vis_sz.y * 0.5
				var diff_bottom_y: float = expected_bottom_y - sprite_bottom_y
				if DEBUG_DECOR_TILES:
					print("[GateDebug] EXTENTS_Y ", selected_decor_name,
					" sprite_bottom=", sprite_bottom_y,
					" expected_bottom=", expected_bottom_y,
					" diff_bottom=", diff_bottom_y)
			# Track placed large decor positions to avoid same-pass overlaps
			if selected_decor_name == "gate1" or selected_decor_name == "gate2" or selected_decor_name == "pipe1" or selected_decor_name == "pipe2" or selected_decor_name == "banner1" or selected_decor_name == "sculpture1" or selected_decor_name == "sculpture2":
				placed_gate_positions.append(final_pos)
			if DecorationConfig.is_dungeon_lighting_decor(selected_decor_name):
				chunk_placed_lighting_world.append(final_pos)
			if selected_decor_name == "gate1":
				if DEBUG_DECOR_TILES:
					print("[GateDebug] SPAWNED at ", decoration_instance.global_position, " floor_based=", floor_based)
			if (tag == "ceiling_surface" or tag == "wall_surface") and DEBUG_DECOR_TILES:
				print("[WebDebug] SPAWNED ", selected_decor_name, " at ", decoration_instance.global_position)
			if DEBUG_DECOR_TILES:
				print("[DecorPopulate] SUCCESS: Spawned decoration '%s' at tile %s (world pos: %s)" % [selected_decor_name, cell, decoration_instance.global_position])
			did_spawn = true
			if is_tutorial:
				tutorial_placed += 1
			# Do not free spawner here; it holds signal handlers for the decoration
			if did_spawn:
				break # Bir kural tuttuysa diğerlerini deneme
	
	if found_data_count > 0:
		pass # print("[DecorPopulate] INFO: Finished chunk '%s'. Found %d tiles with '%s' data." % [chunk_node.name, found_data_count, decor_layer_name])


func _priority_rule_can_include_dungeon_lighting(rule: Dictionary, decoration_pool: Dictionary) -> bool:
	if not rule.has("decoration_names") or rule.decoration_names.is_empty():
		return false
	for decor_name in rule.decoration_names:
		if not decoration_pool.has(decor_name):
			continue
		if DecorationConfig.is_dungeon_lighting_decor(str(decor_name)):
			return true
	return false


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
		"wall_surface", "right_wall_surface", "lef_wall_surface":
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
				if DEBUG_DECOR_TILES:
					print("[GateDebug] OCCUPIED at ", c, " for ", name)
			return false
	# Additional side clearance on the right to avoid hugging walls for wide floor decors
	if grow_dir == "up" and (name == "box2" or name == "gate1" or name == "box1"):
		var half_w_left_side := int(floor((w_tiles - 1) / 2.0))
		var half_w_right_side := int(ceil((w_tiles - 1) / 2.0))
		var right_pad_x := half_w_right_side + 1
		for dy in range(1, h_tiles + 1):
			var right_nei := anchor + Vector2i(right_pad_x, -dy)
			if tile_map.get_cell_source_id(right_nei) != -1:
				if dbg:
					if DEBUG_DECOR_TILES:
						print("[GateDebug] SIDE_RIGHT_OCCUPIED at ", right_nei, " for ", name)
				return false
	# For floor-based growth, ensure all supporting floor tiles directly below footprint are solid
	if grow_dir == "up":
		# Base row must be fully walkable/solid across the footprint
		for dx in range(-half_w_left, half_w_right + 1):
			var base := anchor + Vector2i(dx, 0)
			if tile_map.get_cell_source_id(base) == -1:
				if dbg:
					if DEBUG_DECOR_TILES:
						print("[GateDebug] BASE_GAP at ", base, " for ", name)
				return false
		# Require at least 1 extra floor tile padding on both left and right of the footprint
		var left_pad := anchor + Vector2i(-half_w_left - 1, 0)
		var right_pad := anchor + Vector2i(half_w_right + 1, 0)
		if tile_map.get_cell_source_id(left_pad) == -1 or tile_map.get_cell_source_id(right_pad) == -1:
			if dbg:
				if DEBUG_DECOR_TILES:
					print("[GateDebug] EDGE_TOO_CLOSE left_pad=", left_pad, " right_pad=", right_pad, " for ", name)
			return false
		for dx in range(-half_w_left, half_w_right + 1):
			var below := anchor + Vector2i(dx, 1)
			if _get_cell_source_id_any(tile_map, below) == -1:
				if dbg:
					if DEBUG_DECOR_TILES:
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
	return _is_cell_on_used_rect_outer_boundary(tile_map.get_used_rect(), cell)

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
		if n is Node2D and ((n as Node2D).name == "gate1" or (n as Node2D).name == "gate2" or (n as Node2D).name == "pipe1" or (n as Node2D).name == "pipe2" or (n as Node2D).name == "sculpture1" or (n as Node2D).name == "sculpture2"):
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

# Find background TileMap / TileMapLayer under the given chunk (tutorial uses TileMapLayer "bg").
func _find_background_tilemap(chunk_node: Node2D) -> Node:
	if chunk_node == null:
		return null
	var candidates: Array = []
	for child in chunk_node.get_children():
		if child is TileMap or child is TileMapLayer:
			candidates.append(child)
	for c in candidates:
		var n := c as Node
		var nm := n.name.to_lower()
		if nm.find("background") != -1 or nm.find("bg") != -1:
			return c
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

# Opens exactly one direction on a cell and explicitly closes the other three.
# Replaces the "for dir_enum in Direction.values(): if dir_enum != X: set false"
# pattern that used to be copy-pasted at every start/finish/dead-end/branch site.
func set_single_open_connection(pos: Vector2i, open_dir: Direction) -> void:
	for dir_enum in Direction.values():
		set_grid_connection(pos, dir_enum, dir_enum == open_dir)

## "Lead-in" cells (pre_finish_pos / pre_new_finish_pos) are marked visited
## BEFORE generate_main_path() runs, specifically so its A* traversal skips
## re-marking them. That means they never receive that path's path_id, so
## _connect_same_path_segments()/resolve_junctions() (which both key off
## matching path_id) can never wire them up to whichever real path cell the
## main path ends up drawing next to them. Bridge that manually, based on
## plain physical adjacency, in every direction except the fixed "forward"
## port (already wired to the finish cell by set_single_open_connection).
func _connect_lead_in_cell(pos: Vector2i, forward_dir: Direction) -> void:
	if not is_valid_position(pos):
		return
	for dir_enum in Direction.values():
		if dir_enum == forward_dir:
			continue
		var neighbor_pos = pos + DIRECTION_VECTORS[dir_enum]
		if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].cell_type != CellType.EMPTY:
			set_grid_connection(pos, dir_enum, true)

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
			_segment_finish_door = finish_door
			_segment_finish_is_boss = finish_chunk.scene_file_path.contains("boss_arena")
			# Kapı pozisyonunu kaydet
			door_positions.append(finish_door.global_position)
			
			# Connect the pre-placed door to our signal handler
			if not finish_door.door_opened.is_connected(_on_door_opened):
				finish_door.door_opened.connect(_on_door_opened)
			
			# If the finish cell is a boss arena, lock the door until boss dies
			if _segment_finish_is_boss:
				print("Boss arena detected at finish. Locking FinishDoor until boss is defeated.")
				finish_door.lock_door()
				finish_door.door_type = "Boss"  # Change type to Boss for different appearance
			
			print("Connected to pre-placed finish door")
		else:
			print("WARNING: No FinishDoor found in finish/boss chunk")
	else:
		print("ERROR: No chunk found at finish position", finish_pos)


func lock_finish_door_for_alarm() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not bool(drs.get("run_started")):
		return
	if _segment_finish_is_boss or not is_instance_valid(_segment_finish_door):
		return
	if drs.has_method("clear_stale_key_holder_id"):
		drs.call("clear_stale_key_holder_id")
	var key_id: String = DungeonRunState.SEGMENT_EXIT_KEY_ID
	if "SEGMENT_EXIT_KEY_ID" in drs:
		key_id = String(drs.get("SEGMENT_EXIT_KEY_ID"))
	if drs.has_method("has_dungeon_key") and bool(drs.call("has_dungeon_key", key_id)):
		print("[LevelGenerator] Alarm — oyuncuda anahtar var, çıkış kapısı kilitlenmedi")
		return
	if _segment_finish_door.has_method("set_alarm_locked"):
		_segment_finish_door.call("set_alarm_locked", true, key_id)
	elif _segment_finish_door.has_method("lock_door"):
		_segment_finish_door.lock_door()
		if _segment_finish_door.has_method("set_requires_key"):
			_segment_finish_door.set_requires_key(true, key_id)
	print("[LevelGenerator] Alarm — çıkış kapısı kilitlendi, anahtar gerekli")
	call_deferred("_assign_segment_key_holder_deferred")
	call_deferred("_reveal_segment_key_holder_marker")


func on_segment_exit_key_obtained() -> void:
	if not is_instance_valid(_segment_finish_door):
		return
	var key_id: String = DungeonRunState.SEGMENT_EXIT_KEY_ID
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and "SEGMENT_EXIT_KEY_ID" in drs:
		key_id = String(drs.get("SEGMENT_EXIT_KEY_ID"))
	if _segment_finish_door.has_method("set_alarm_locked"):
		_segment_finish_door.call("set_alarm_locked", false, key_id)
	if _segment_finish_door.has_method("unlock_door"):
		_segment_finish_door.unlock_door()
	if _segment_finish_door.has_method("set_requires_key"):
		_segment_finish_door.set_requires_key(false, "")
	var sm: Node = get_node_or_null("/root/StealthManager")
	if sm != null:
		var hud: Node = sm.get("_hud")
		if hud != null and is_instance_valid(hud) and hud.has_method("show_key_obtained_toast"):
			hud.call("show_key_obtained_toast")


func _assign_segment_key_holder_deferred() -> void:
	_assign_segment_key_holder_async(0)


func _assign_segment_key_holder_async(attempt: int) -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs):
		return
	if drs.has_method("clear_stale_key_holder_id"):
		drs.call("clear_stale_key_holder_id")
	if drs.has_method("has_segment_key_holder") and bool(drs.call("has_segment_key_holder")):
		return
	var candidates: Array = _collect_segment_key_holder_candidates()
	if candidates.is_empty():
		if attempt < 16:
			await get_tree().create_timer(0.35).timeout
			_assign_segment_key_holder_async(attempt + 1)
		else:
			if bool(drs.get("segment_exit_requires_key")):
				push_warning("[LevelGenerator] Alarm anahtarı için uygun düşman yok — yere anahtar bırakılıyor")
				_spawn_emergency_key_drop(drs)
			else:
				push_warning("[LevelGenerator] Segment anahtar taşıyıcısı atanamadı — yedek düşman")
				_spawn_emergency_key_holder(drs)
		return
	var picked: Node = _pick_segment_key_holder(candidates)
	if not is_instance_valid(picked):
		push_warning("[LevelGenerator] Anahtar taşıyıcı seçilemedi — acil anahtar deneniyor")
		if bool(drs.get("segment_exit_requires_key")):
			_spawn_emergency_key_drop(drs)
		return
	if not is_placed_combat_enemy(picked):
		push_warning("[LevelGenerator] Geçersiz anahtar adayı atlandı @ %s" % picked.global_position)
		if bool(drs.get("segment_exit_requires_key")):
			_spawn_emergency_key_drop(drs)
		return
	if drs.has_method("assign_segment_key_holder"):
		drs.call("assign_segment_key_holder", picked)
	var type_name: String = picked.get_script().resource_path.get_file().get_basename() if picked.get_script() else picked.name
	print("[LevelGenerator] Segment çıkış anahtarı taşıyıcı: %s @ %s" % [type_name, picked.global_position])
	if bool(drs.get("segment_exit_requires_key")):
		_reveal_segment_key_holder_marker()


func is_placed_combat_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if not enemy.is_inside_tree():
		return false
	if enemy.is_in_group("boss"):
		return false
	if "MiniBoss" in enemy.name:
		return false
	if "current_behavior" in enemy and String(enemy.current_behavior) == "dead":
		return false
	if not enemy is Node2D:
		return false
	var pos: Vector2 = (enemy as Node2D).global_position
	if pos.length_squared() < MIN_KEY_HOLDER_POSITION_SQ:
		return false
	return true


func count_placed_combat_enemies() -> int:
	return _collect_segment_key_holder_candidates().size()


func get_alarm_key_fallback_drop_pos() -> Vector2:
	if is_instance_valid(_segment_finish_door):
		return _segment_finish_door.global_position + Vector2(-220, -32)
	return global_position + Vector2(400, 0)


func _collect_segment_key_holder_candidates() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_placed_combat_enemy(node):
			continue
		out.append(node)
	return out


func _enemy_script_path_lower(enemy: Node) -> String:
	if not is_instance_valid(enemy):
		return ""
	var sc: Variant = enemy.get_script()
	if sc is Script:
		var rp: String = (sc as Script).resource_path
		if not rp.is_empty():
			return rp.to_lower()
	if enemy.scene_file_path:
		return str(enemy.scene_file_path).to_lower()
	return ""


func _is_fodder_key_carrier(enemy: Node) -> bool:
	if bool(enemy.get_meta("summoner_summoned_bird", false)):
		return true
	var path: String = _enemy_script_path_lower(enemy)
	for marker in KEY_CARRIER_FODDER_SCRIPT_MARKERS:
		if marker in path:
			return true
	return false


func _is_preferred_key_carrier(enemy: Node) -> bool:
	if _is_fodder_key_carrier(enemy):
		return false
	var path: String = _enemy_script_path_lower(enemy)
	for marker in KEY_CARRIER_PREFERRED_SCRIPT_MARKERS:
		if marker in path:
			return true
	return false


func _pick_segment_key_holder(candidates: Array) -> Node:
	if candidates.is_empty():
		return null
	var preferred: Array = []
	var non_fodder: Array = []
	for node in candidates:
		if not is_instance_valid(node):
			continue
		if _is_preferred_key_carrier(node):
			preferred.append(node)
		elif not _is_fodder_key_carrier(node):
			non_fodder.append(node)
	if not preferred.is_empty():
		return preferred[randi() % preferred.size()] as Node
	if not non_fodder.is_empty():
		return non_fodder[randi() % non_fodder.size()] as Node
	# Son çare: haritada yalnızca basic/kuş kaldıysa
	return candidates[randi() % candidates.size()] as Node


func _reveal_segment_key_holder_marker() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs):
		return
	if drs.has_method("_find_living_key_holder"):
		var holder: Node = drs.call("_find_living_key_holder")
		if is_instance_valid(holder):
			_mark_segment_key_holder(holder)
			return
	var holder_id: String = String(drs.get("segment_key_holder_id"))
	if holder_id.is_empty():
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if str(node.get_instance_id()) == holder_id:
			_mark_segment_key_holder(node)
			return


func _spawn_emergency_key_drop(drs: Node) -> void:
	var key_id: String = DungeonRunState.SEGMENT_EXIT_KEY_ID
	if "SEGMENT_EXIT_KEY_ID" in drs:
		key_id = String(drs.get("SEGMENT_EXIT_KEY_ID"))
	var spawn_pos: Vector2 = global_position + Vector2(400, 0)
	if is_instance_valid(_segment_finish_door):
		spawn_pos = _segment_finish_door.global_position + Vector2(-220, -32)
	const Spawner = preload("res://interactables/dungeon/DungeonLootDropSpawner.gd")
	Spawner.spawn_dungeon_key(spawn_pos, key_id)
	print("[LevelGenerator] Acil anahtar yere bırakıldı @ %s" % spawn_pos)


func _mark_segment_key_holder(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.get_node_or_null("SegmentExitKeyMarker") != null:
		return
	var marker := Label.new()
	marker.name = "SegmentExitKeyMarker"
	marker.text = "🔑"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 18)
	marker.position = Vector2(-10, -48)
	marker.z_index = 20
	enemy.add_child(marker)


func _spawn_emergency_key_holder(drs: Node) -> void:
	var scene_path: String = KEY_CARRIER_EMERGENCY_SCENES[randi() % KEY_CARRIER_EMERGENCY_SCENES.size()]
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		scene = load("res://enemy/spearman/spearman_enemy.tscn") as PackedScene
	if scene == null:
		return
	var enemy: Node = scene.instantiate()
	add_child(enemy)
	var spawn_pos: Vector2 = global_position + Vector2(400, 0)
	if is_instance_valid(_segment_finish_door):
		spawn_pos = _segment_finish_door.global_position + Vector2(-280, -32)
	enemy.global_position = spawn_pos
	if "enemy_level" in enemy:
		enemy.enemy_level = current_level
	if drs.has_method("assign_segment_key_holder"):
		drs.call("assign_segment_key_holder", enemy)
	if bool(drs.get("segment_exit_requires_key")):
		_mark_segment_key_holder(enemy)


func _on_door_opened(door_type: String) -> void:
	if is_transitioning:
		return
		
	print("Door opened: ", door_type)  # Debug print
	if door_type == "Start":
		print("Emitting level_started signal")  # Debug print
		level_started.emit()
	elif door_type == "Finish" or door_type == "Boss":
		var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
		var drs_finish = get_node_or_null("/root/DungeonRunState")
		if door_type == "Finish" and is_instance_valid(stealth_mgr) and is_instance_valid(drs_finish):
			if bool(stealth_mgr.get("segment_alarm")) and bool(drs_finish.get("segment_exit_requires_key")):
				var exit_key: String = String(drs_finish.get("SEGMENT_EXIT_KEY_ID"))
				if drs_finish.has_method("has_dungeon_key") and not bool(drs_finish.call("has_dungeon_key", exit_key)):
					push_warning("[LevelGenerator] Çıkış anahtarı olmadan geçiş engellendi")
					if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("_ensure_hud"):
						stealth_mgr.call("_ensure_hud")
					var hud: Node = stealth_mgr.get("_hud") if is_instance_valid(stealth_mgr) else null
					if hud != null and is_instance_valid(hud) and hud.has_method("show_exit_key_required_toast"):
						hud.call("show_exit_key_required_toast")
					if is_instance_valid(_segment_finish_door):
						_segment_finish_door.is_open = false
						if "current_state" in _segment_finish_door:
							_segment_finish_door.current_state = 0  # DoorState.CLOSED
						if _segment_finish_door.has_method("close_door_now"):
							_segment_finish_door.close_door_now()
					return
		if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("on_segment_completed"):
			stealth_mgr.on_segment_completed()
		var drs = get_node_or_null("/root/DungeonRunState")
		if is_instance_valid(drs) and drs.get("run_started") == true:
			if drs.has_method("sync_warmup_limits"):
				drs.sync_warmup_limits()
			if drs.has_method("on_segment_completed"):
				drs.call("on_segment_completed")
			is_transitioning = true
			level_completed.emit()
			var payload: Dictionary = {}
			payload["source"] = "dungeon"
			payload["travel_hours_back"] = 2.0
			var sm = get_node_or_null("/root/SceneManager")

			if drs.is_run_complete():
				var max_seg: int = int(drs.run_max_segments) if "run_max_segments" in drs else int(drs.MAX_SEGMENTS)
				var done_seg: int = int(drs.run_segments_completed) if "run_segments_completed" in drs else int(drs.run_segment_count)
				print("[LevelGenerator] Run complete (%d/%d segments) -> final camp (boss or exit)" % [done_seg, max_seg])
				if sm and sm.has_method("change_to_camp"):
					payload["final_camp"] = true
					sm.change_to_camp(payload)
				elif sm and sm.has_method("change_to_world_map"):
					sm.change_to_world_map({"source": "dungeon", "return_reason": "dungeon_exit"})
				else:
					is_transitioning = false
				return

			if sm and sm.has_method("change_to_camp"):
				print("[LevelGenerator] Finish/Boss -> Camp (mid-run), player state preserved via PlayerStats")
				sm.change_to_camp(payload)
			else:
				is_transitioning = false
				push_warning("[LevelGenerator] SceneManager.change_to_camp not found, falling back to next level")
				_finish_door_fallback_next_level()
			return
		# Eski akış: run yoksa veya kamp yoksa yeni seviye üret
		print("Emitting level_completed signal")  # Debug print
		is_transitioning = true
		_clear_all_enemies_from_previous_level()
		level_completed.emit()
		current_level += 1
		call_deferred("_generate_next_level_after_cleanup")
		var timer = get_tree().create_timer(transition_cooldown)
		timer.timeout.connect(func(): is_transitioning = false)

func _finish_door_fallback_next_level() -> void:
	# Fallback when change_to_camp is not available: clear and generate next level
	_clear_all_enemies_from_previous_level()
	current_level += 1
	call_deferred("_generate_next_level_after_cleanup")
	var timer = get_tree().create_timer(transition_cooldown)
	timer.timeout.connect(func(): is_transitioning = false)

func _generate_next_level_after_cleanup() -> void:
	# This is called via call_deferred from _on_door_opened after cleanup.
	# At this point, old chunks and unified_terrain should be fully freed.
	generate_level()  # Generate new level

func _on_miniboss_spawned(enemy: Node, boss_chunk: Node2D) -> void:
	# Wire defeat to enabling FinishZone under the boss arena chunk
	if enemy and enemy.has_signal("enemy_defeated"):
		enemy.connect("enemy_defeated", Callable(self, "_on_miniboss_defeated").bind(boss_chunk))

func _calculate_door_positions() -> void:
	# Kapı pozisyonlarını gerçek door pozisyonlarından al
	door_positions.clear()
	
	# Gerçek door pozisyonlarını dinamik olarak al
	var doors = get_tree().get_nodes_in_group("doors")
	if DEBUG_DECOR_TILES:
		print("[DoorPositions] Found doors in group: ", doors.size())
	
	for door in doors:
		if door and is_instance_valid(door):
			var door_pos = door.global_position
			door_positions.append(door_pos)
			if DEBUG_DECOR_TILES:
				print("[DoorPositions] Added door at: ", door_pos)
	
	# Fallback: Eğer door bulunamazsa hata ver
	if door_positions.is_empty():
		if DEBUG_DECOR_TILES:
			print("[DoorPositions] ERROR: No doors found! This should not happen!")
		push_error("No doors found in scene - door proximity check will fail!")
	
	if DEBUG_DECOR_TILES:
		print("[DoorPositions] Final door positions: ", door_positions)

func get_door_positions() -> Array[Vector2]:
	# Decoration spawner'lar için kapı pozisyonlarını döndür
	return door_positions

func _spawn_miniboss_in_arena(chunk: Node2D, tier: String = "mini") -> void:
	var mini_scene_path := "res://enemy/miniboss/shield_captain/shield_captain.tscn"
	var mini_scene: PackedScene = load(mini_scene_path)
	if mini_scene == null:
		push_error("[BossArena] Failed to load miniboss scene at path: " + mini_scene_path)
		return
	print("[BossArena] Instantiating miniboss (%s) from %s" % [tier, mini_scene_path])
	var mini = mini_scene.instantiate()
	mini.name = "MiniBoss_ShieldCaptain"
	if tier == "major":
		if "max_health_override" in mini:
			mini.set("max_health_override", float(mini.get("max_health_override")) * 1.5)
		if mini.has_method("set") and "cleave_damage" in mini:
			mini.set("cleave_damage", float(mini.get("cleave_damage")) * 1.2)
	chunk.add_child(mini)
	mini.global_position = chunk.global_position + Vector2(960, 600)
	if mini.has_signal("enemy_defeated"):
		mini.connect("enemy_defeated", Callable(self, "_on_miniboss_defeated").bind(chunk))
	var _mini_ref = mini
	get_tree().create_timer(0.05).timeout.connect(func(): _attach_boss_bar(_mini_ref))


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
	# Find UI root — önce sahne GameUI, sonra oyuncu UI
	var ui_root: Node = null
	var scene_root := get_tree().current_scene
	if scene_root:
		var game_ui := scene_root.get_node_or_null("GameUI/Container")
		if game_ui:
			ui_root = game_ui
	if ui_root == null:
		ui_root = get_tree().get_first_node_in_group("ui_root")
	if ui_root == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_node("UI"):
			ui_root = players[0].get_node("UI")
	if ui_root == null:
		var canvas := CanvasLayer.new()
		canvas.name = "TempUIRoot"
		canvas.layer = HudCanvasLayers.HUD
		scene_root.add_child(canvas) if scene_root else add_child(canvas)
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
			if DEBUG_ENEMY_TILES:
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

# Carves a single branch off `branch_start` (vertical leg, then a short horizontal
# leg, then an attempt to rejoin a main path). Returns the array of newly-carved
# points on success (caller decides whether to add it to all_paths / the branch
# queue), or an empty array if nothing usable was carved.
#
# Note: this only checks for direct overlap with already-visited cells (a hard
# requirement - we must never overwrite another segment's data). It does NOT
# avoid merely running *close* to other paths anymore: whether two segments that
# end up adjacent actually connect is now decided later, explicitly and
# probabilistically, by resolve_junctions() in finalize_connections().
func generate_branch(branch_start: Vector2i) -> Array:
	# Skip if this is the start position or too close to finish
	if branch_start == Vector2i(0, current_grid_height / 2) or abs(branch_start.x - current_grid_width - 2) < 5: # Use current_grid_height
		return []

	# Determine branch direction (up or down)
	var branch_dir = Direction.UP if randf() < 0.5 else Direction.DOWN
	var branch_length = randi() % 4 + 3  # 3-6 chunks

	current_path_id_counter += 1
	var current_branch_id = current_path_id_counter

	var current_branch_points = []
	var current_pos = branch_start
	# branch_start itself belongs to whichever path it split from; the branch's
	# own points start from the first newly-carved cell.

	# Leg 1: move vertically away from the source path
	var can_continue = true
	for _i in range(branch_length):
		var next_pos = current_pos + DIRECTION_VECTORS[branch_dir]
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			can_continue = false
			break

		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "generate_branch_vertical"
		grid[next_pos.x][next_pos.y].path_id = current_branch_id

		set_grid_connection(current_pos, branch_dir, true)
		set_single_open_connection(next_pos, get_opposite_direction(branch_dir))

		current_pos = next_pos
		current_branch_points.append(current_pos)

	if not can_continue:
		return []

	# Leg 2: move horizontally, then try to rejoin a main path vertically.
	# Skip entirely if we're already too close to the finish column.
	if current_pos.x >= current_grid_width - 7:
		return []

	var rejoin_dir = get_opposite_direction(branch_dir)
	if not is_valid_direction(rejoin_dir):
		return []

	var rejoin_target_x = branch_start.x + randi() % 3 + 2  # 2-4 chunks
	while current_pos.x < rejoin_target_x and current_pos.x < current_grid_width - 8:
		var next_pos = current_pos + DIRECTION_VECTORS[Direction.RIGHT]
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			break

		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "generate_branch_horizontal"
		grid[next_pos.x][next_pos.y].path_id = current_branch_id

		set_grid_connection(current_pos, Direction.RIGHT, true)
		set_single_open_connection(next_pos, Direction.LEFT)

		current_pos = next_pos
		current_branch_points.append(current_pos)

	# Leg 3: try to rejoin an existing main path (up to 3 steps)
	var can_rejoin = true
	var rejoin_steps = 0
	while rejoin_steps < 3:
		var next_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
		if not is_valid_position(next_pos) or grid[next_pos.x][next_pos.y].visited:
			if is_valid_position(next_pos) and grid[next_pos.x][next_pos.y].cell_type == CellType.MAIN_PATH:
				break # Found main path, stop and connect below
			can_rejoin = false
			break

		grid[next_pos.x][next_pos.y].cell_type = CellType.BRANCH_PATH
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "generate_branch_rejoin"
		grid[next_pos.x][next_pos.y].path_id = current_branch_id

		set_grid_connection(current_pos, rejoin_dir, true)
		set_single_open_connection(next_pos, get_opposite_direction(rejoin_dir))

		current_pos = next_pos
		current_branch_points.append(current_pos)
		rejoin_steps += 1

	if not can_rejoin:
		# Vertical/horizontal legs still stand (they'll read as a natural dead-end
		# chunk since their last cell only has the "came from" connection), but
		# this segment isn't handed back for further branching or dead-end sourcing.
		return []

	var main_path_pos = current_pos + DIRECTION_VECTORS[rejoin_dir]
	if not (is_valid_position(main_path_pos) and grid[main_path_pos.x][main_path_pos.y].visited and grid[main_path_pos.x][main_path_pos.y].cell_type == CellType.MAIN_PATH):
		push_warning("generate_branch: Failed to connect to main path after rejoin attempt from branch start %s" % str(branch_start))
		return []

	set_grid_connection(current_pos, rejoin_dir, true)
	if grid[branch_start.x][branch_start.y].cell_type != CellType.BRANCH_POINT:
		grid[branch_start.x][branch_start.y].cell_type = CellType.BRANCH_POINT
		grid[branch_start.x][branch_start.y].visited_by += "+branch_point"

	return current_branch_points

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
	var next_pos = current_pos + DIRECTION_VECTORS[dead_end_dir]
	
	# Strict Check: Ensure the next position is valid AND not already visited
	if is_valid_position(next_pos) and not grid[next_pos.x][next_pos.y].visited:
		# Mark the valid, unvisited cell
		grid[next_pos.x][next_pos.y].cell_type = CellType.DEAD_END
		grid[next_pos.x][next_pos.y].visited = true
		grid[next_pos.x][next_pos.y].visited_by = "add_dead_end" # Track visit
		
		# Connect back to the source cell; the dead end keeps exactly one open port
		# (we intentionally don't touch current_pos's other connections here - it
		# might be part of the main path or another branch).
		var opposite_dir = get_opposite_direction(dead_end_dir)
		if is_valid_direction(opposite_dir):
			set_grid_connection(current_pos, dead_end_dir, true)
			set_single_open_connection(next_pos, opposite_dir)
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
	# Pass 1: wire up each drawn path/branch's OWN internal cells (same path_id).
	# This is the only thing that used to rely on the old "any adjacent non-empty
	# cell auto-connects" rule; every cross-segment connection (branch attachment,
	# branch rejoin, dead-end) is already set explicitly by the code that carves it.
	_connect_same_path_segments()
	# Pass 2: decide, per level config, whether unrelated segments that ended up
	# adjacent should merge into a real junction or stay walled-off from each other.
	resolve_junctions()
	print("Grid connections finalized.")

# Pass 1 helper: connects adjacent cells that belong to the same path_id
# (i.e. were carved by the same generate_main_path/generate_branch call).
func _connect_same_path_segments() -> void:
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos = Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			if cell.cell_type == CellType.EMPTY or cell.path_id == -1:
				continue
			for dir_enum in Direction.values():
				var neighbor_pos = pos + DIRECTION_VECTORS[dir_enum]
				if not is_valid_position(neighbor_pos):
					continue
				var neighbor: GridCell = grid[neighbor_pos.x][neighbor_pos.y]
				if neighbor.cell_type == CellType.EMPTY:
					continue
				if neighbor.path_id == cell.path_id:
					set_grid_connection(pos, dir_enum, true)

# Pass 2: for cells belonging to DIFFERENT path segments that happen to be
# adjacent without an explicit connection, roll the dice (level_config driven)
# to decide whether they merge into a shared junction chunk or stay separate
# (bitişik ama bağlantısız — visually close, gameplay-wise walled off).
# Only RIGHT/DOWN are checked per cell so every unordered pair is evaluated once.
func resolve_junctions() -> void:
	var junction_chance := 0.35
	if level_config:
		junction_chance = level_config.get_path_junction_chance(current_level)
	var junctions_formed := 0
	var pass2_dirs = [Direction.RIGHT, Direction.DOWN]
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var pos = Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			# Dead ends must keep exactly one connection (rescue/stealth/event
			# tagging relies on this); start/finish/anchor cells (path_id == -1)
			# already have their single required connection set explicitly.
			if cell.cell_type == CellType.EMPTY or cell.cell_type == CellType.DEAD_END or cell.path_id == -1:
				continue
			for dir_enum in pass2_dirs:
				if cell.connections[dir_enum]:
					continue # Already connected (same segment or earlier explicit link)
				var neighbor_pos = pos + DIRECTION_VECTORS[dir_enum]
				if not is_valid_position(neighbor_pos):
					continue
				var neighbor: GridCell = grid[neighbor_pos.x][neighbor_pos.y]
				if neighbor.cell_type == CellType.EMPTY or neighbor.cell_type == CellType.DEAD_END or neighbor.path_id == -1:
					continue
				if neighbor.path_id == cell.path_id:
					continue # Same segment, Pass 1 already handled it
				if randf() < junction_chance:
					set_grid_connection(pos, dir_enum, true)
					junctions_formed += 1
	_debug_last_junctions_formed = junctions_formed
	if DEBUG_ENEMY_TILES:
		print("  resolve_junctions: %d junction(s) formed (chance=%.2f)" % [junctions_formed, junction_chance])

# Always-on, one-line summary so branching/crossing behaviour can be sanity
# checked from the console without turning on the noisier DEBUG_ENEMY_TILES flag.
func _debug_print_generation_summary() -> void:
	var main_count := 0
	var branch_count := 0
	var dead_end_count := 0
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			match grid[x][y].cell_type:
				CellType.MAIN_PATH, CellType.BRANCH_POINT:
					main_count += 1
				CellType.BRANCH_PATH:
					branch_count += 1
				CellType.DEAD_END:
					dead_end_count += 1
	print("[LevelGenerator] Layout summary: main=%d branch=%d dead_end=%d junctions_formed=%d max_branch_depth_reached=%d" % [
		main_count, branch_count, dead_end_count, _debug_last_junctions_formed, _debug_last_max_branch_depth_reached
	])

# Verbose ASCII dump of the whole grid (cell type per cell), gated behind
# DEBUG_ENEMY_TILES. Handy for eyeballing "do paths actually cross/branch as
# expected?" without opening the full Godot scene.
# Legend: .=empty S=start F=finish M=main B=branch +=branch_point D=dead_end #=wall
func _debug_print_ascii_grid() -> void:
	var start_pos = Vector2i(0, current_grid_height / 2)
	print("[LevelGenerator] ASCII grid (x -> right, y -> down). Legend: .=empty S=start F=finish M=main B=branch +=branch_point D=dead_end #=wall")
	for y in range(current_grid_height):
		var row := ""
		for x in range(current_grid_width):
			var pos := Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			var ch := "."
			if pos == start_pos:
				ch = "S"
			elif cell.chunk and cell.chunk.scene_file_path.contains("finish_chunk"):
				ch = "F"
			else:
				match cell.cell_type:
					CellType.MAIN_PATH: ch = "M"
					CellType.BRANCH_PATH: ch = "B"
					CellType.BRANCH_POINT: ch = "+"
					CellType.DEAD_END: ch = "D"
					CellType.WALL: ch = "#"
					CellType.EMPTY: ch = "."
			row += ch
		print("  " + row)

# --- NEW FUNCTION --- 
func _is_playable_layout_cell(cell_type: CellType) -> bool:
	return cell_type != CellType.EMPTY and cell_type != CellType.WALL

func _collect_empty_cells_for_wall_ring(trigger: Callable) -> Array:
	var cells_to_make_wall: Array = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			if grid[x][y].cell_type != CellType.EMPTY:
				continue
			var pos := Vector2i(x, y)
			for offset: Vector2i in _WALL_NEIGHBOR_OFFSETS:
				var neighbor_pos: Vector2i = pos + offset
				if not is_valid_position(neighbor_pos):
					continue
				if trigger.call(grid[neighbor_pos.x][neighbor_pos.y].cell_type):
					cells_to_make_wall.append(pos)
					break
	return cells_to_make_wall

const _WALL_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
]

func _apply_wall_cells(cells_to_make_wall: Array) -> int:
	for pos in cells_to_make_wall:
		grid[pos.x][pos.y].cell_type = CellType.WALL
		grid[pos.x][pos.y].visited_by = "fill_surrounding_walls"
	return cells_to_make_wall.size()

func _count_wall_neighbors_8(pos: Vector2i) -> int:
	var count := 0
	for offset: Vector2i in _WALL_NEIGHBOR_OFFSETS:
		var neighbor_pos: Vector2i = pos + offset
		if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].cell_type == CellType.WALL:
			count += 1
	return count

func _count_oob_neighbors(pos: Vector2i) -> int:
	var count := 0
	for offset: Vector2i in _WALL_NEIGHBOR_OFFSETS:
		if not is_valid_position(pos + offset):
			count += 1
	return count

func _seal_wall_envelope_gaps() -> int:
	# Dış zarfın köşelerinde kalan 1'lik boşlukları kapat.
	# Örnek (sol üst çentik):
	#   W W .
	#   W P P
	#   ? . .   <- ? hücresi: yalnızca 1 kardinal duvar; ama 2 diyagonal/kardinal duvar komşusu var
	var cells_to_make_wall: Array = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			if grid[x][y].cell_type != CellType.EMPTY:
				continue
			var pos := Vector2i(x, y)
			var wall_neighbors_8 := _count_wall_neighbors_8(pos)
			var oob_neighbors := _count_oob_neighbors(pos)
			var cardinal_wall_neighbors := 0
			for dir_enum in Direction.values():
				var neighbor_pos: Vector2i = pos + DIRECTION_VECTORS[dir_enum]
				if is_valid_position(neighbor_pos) and grid[neighbor_pos.x][neighbor_pos.y].cell_type == CellType.WALL:
					cardinal_wall_neighbors += 1
			var should_fill := false
			if cardinal_wall_neighbors >= 2:
				should_fill = true
			elif wall_neighbors_8 >= 2:
				# Diyagonal dış köşe: iki duvar komşusu (8 yön) yeterli.
				should_fill = true
			elif wall_neighbors_8 >= 1 and oob_neighbors >= 2:
				# Grid'in fiziksel köşesinde (ör. 0,0): en az bir duvar + iki grid dışı kenar.
				should_fill = true
			elif wall_neighbors_8 >= 1 and oob_neighbors >= 1:
				# Grid kenarı (üst/alt/sol/sağ): tek dış sınır + bitişik duvar yeterli.
				should_fill = true
			if should_fill:
				cells_to_make_wall.append(pos)
	return _apply_wall_cells(cells_to_make_wall)

func _get_dungeon_content_bounds() -> Rect2i:
	var min_x: int = current_grid_width
	var max_x: int = -1
	var min_y: int = current_grid_height
	var max_y: int = -1
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			if grid[x][y].cell_type == CellType.EMPTY:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _queue_exterior_wall_position(pos: Vector2i) -> void:
	if _exterior_wall_positions.has(pos):
		return
	_exterior_wall_positions.append(pos)

func _fill_bounding_box_wall_padding() -> int:
	# Tüm zindan içeriğinin etrafına sabit kalınlıkta duvar zarfı ör.
	# Üst/sol çentikler ve grid sınırına yapışık odalar için grid dışına da kuyruk bırakır.
	var bounds := _get_dungeon_content_bounds()
	if bounds.size == Vector2i.ZERO:
		return 0
	var pad: int = SURROUNDING_WALL_RINGS
	var ex_min_x: int = bounds.position.x - pad
	var ex_max_x: int = bounds.position.x + bounds.size.x - 1 + pad
	var ex_min_y: int = bounds.position.y - pad
	var ex_max_y: int = bounds.position.y + bounds.size.y - 1 + pad
	var marked := 0
	for x in range(ex_min_x, ex_max_x + 1):
		for y in range(ex_min_y, ex_max_y + 1):
			if is_valid_position(Vector2i(x, y)):
				if grid[x][y].cell_type != CellType.EMPTY:
					continue
				grid[x][y].cell_type = CellType.WALL
				grid[x][y].visited_by = "fill_surrounding_walls_bbox"
				marked += 1
			else:
				_queue_exterior_wall_position(Vector2i(x, y))
	return marked

func _place_exterior_wall_chunks() -> void:
	if _exterior_wall_positions.is_empty():
		return
	var chunk_scene: PackedScene = load(CHUNKS["full"]["scenes"][0])
	if not chunk_scene:
		push_error("Failed to load exterior wall chunk scene.")
		return
	for pos in _exterior_wall_positions:
		var chunk: Node2D = chunk_scene.instantiate()
		if not chunk:
			continue
		add_child(chunk)
		chunk.position = grid_to_world(pos)
		_exterior_wall_chunks.append(chunk)
		chunks_placed += 1
	if DEBUG_ENEMY_TILES:
		print("  Placed %d exterior wall chunk(s) outside grid bounds." % _exterior_wall_positions.size())

func fill_surrounding_walls() -> void:
	print("Filling surrounding walls...")
	var total_marked := 0
	
	# Halka 1: oynanabilir hücrelere (yol/dal/çıkmaz) bitişik boşluklar.
	var ring1 := _collect_empty_cells_for_wall_ring(
		func(cell_type: CellType) -> bool: return _is_playable_layout_cell(cell_type)
	)
	total_marked += _apply_wall_cells(ring1)
	
	# Halka 2..N: mevcut duvarlardan dışarı doğru genişlet (kamera boşluğu için).
	for _ring in range(1, SURROUNDING_WALL_RINGS):
		var outer_ring := _collect_empty_cells_for_wall_ring(
			func(cell_type: CellType) -> bool: return cell_type == CellType.WALL
		)
		total_marked += _apply_wall_cells(outer_ring)
	
	# Köşe/diyagonal çatlakları yama (bir yama başka çatlak açabilir; birkaç tur yeterli).
	for _patch_pass in range(4):
		var patched := _seal_wall_envelope_gaps()
		total_marked += patched
		if patched == 0:
			break
	
	# Son adım: bounding box tabanlı sabit dış zarf (üst kenar boşlukları dahil).
	total_marked += _fill_bounding_box_wall_padding()
	
	print("Surrounding walls marked. Count: %d (rings=%d, exterior=%d)" % [
		total_marked, SURROUNDING_WALL_RINGS, _exterior_wall_positions.size()
	])
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
		var drs := get_node_or_null("/root/DungeonRunState")
		var night_mode: bool = is_instance_valid(drs) and drs.has_method("has_segment_modifier") and drs.has_segment_modifier("night_mode")
		if night_mode:
			shader_material.set_shader_parameter("max_darkness", 0.92)
			shader_material.set_shader_parameter("light_radius", 280.0)
			shader_material.set_shader_parameter("ambient_light", 0.05)
		else:
			shader_material.set_shader_parameter("max_darkness", 0.8)
			shader_material.set_shader_parameter("light_radius", 800.0)
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
	canvas_layer.layer = HudCanvasLayers.WORLD_VIGNETTE
	
	screen_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# ColorRect'i CanvasLayer'e ekle
	canvas_layer.add_child(screen_darkness)
	
	# CanvasLayer'i scene root'a ekle
	scene_root.add_child(canvas_layer)
	HudCanvasLayers.apply_to_scene_root(scene_root)

# ==============================================================================
# TILE-BASED ENEMY SPAWN SYSTEM
# ==============================================================================

const DEBUG_ENEMY_TILES: bool = false

func _populate_enemies_from_tilemap(chunk_node: Node2D) -> void:
	# CRITICAL: Don't spawn enemies in start, finish or rescue (villager/vip) chunks
	var chunk_name = chunk_node.name.to_lower()
	var scene_path = chunk_node.scene_file_path.to_lower() if chunk_node.scene_file_path else ""
	
	if "villager_dead_end" in scene_path or "vip_dead_end" in scene_path:
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] SKIPPING: Rescue chunk - no enemies spawn here")
		return
	
	if "start" in chunk_name or "start_chunk" in scene_path:
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] SKIPPING: Start chunk - no enemies spawn here")
		return
	
	if "finish" in chunk_name or "finish_chunk" in scene_path:
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] SKIPPING: Finish chunk - no enemies spawn here")
		return
	
	# Tile-based enemy spawn system - similar to decoration system
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	
	if not tile_map:
		if DEBUG_ENEMY_TILES:
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
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] SKIPPING: TileSet in chunk '%s' does not have a custom data layer named '%s'." % [chunk_node.name, enemy_layer_name])
		return
	
	var used_cells = tile_map.get_used_cells()
	var enemy_spawn_count = 0
	var spawned_positions: Array[Vector2] = []  # Track spawned positions
	
	# Determine chunk type to set spawn limits (do this once before the loop)
	var chunk_type_str = _get_chunk_type_for_node(chunk_node)
	var max_spawns = 2  # Default for regular chunks
	var spawn_chance_value = 0.6  # Default spawn chance
	
	# Dungeon chunks get many more enemies - basic enemies are cannon fodder
	if chunk_type_str == "dungeon":
		var spawn_config = SpawnConfig.new()
		var spawn_rules = spawn_config.get_spawn_count("dungeon", current_level)
		max_spawns = spawn_rules.max_spawns
		var drs_chunk = get_node_or_null("/root/DungeonRunState")
		if drs_chunk and drs_chunk.run_started:
			max_spawns += (drs_chunk.enemy_count_offset + int(drs_chunk.get("run_base_difficulty"))) * 2
			if drs_chunk.is_first_segment():
				max_spawns = maxi(1, max_spawns / 2)
		spawn_chance_value = 1.0
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] Dungeon chunk detected - max_spawns: %d, spawn_chance: %.1f" % [max_spawns, spawn_chance_value])
			print("[EnemyPopulate] Chunk name: %s, detected type: %s" % [chunk_node.name, chunk_type_str])
	else:
		max_spawns = 2  # Regular chunks get fewer enemies
		spawn_chance_value = 0.6  # 60% chance for regular chunks
		if DEBUG_ENEMY_TILES:
			print("[EnemyPopulate] Regular chunk detected - max_spawns: %d, spawn_chance: %.1f" % [max_spawns, spawn_chance_value])
			print("[EnemyPopulate] Chunk name: %s, detected type: %s" % [chunk_node.name, chunk_type_str])
	
	if DEBUG_ENEMY_TILES:
		print("[EnemyPopulate] Processing %d cells in chunk '%s' (type: %s)" % [used_cells.size(), chunk_node.name, chunk_type_str])
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
			if DEBUG_ENEMY_TILES:
				print("[EnemyPopulate] Checking floor tile at: %s" % cell)
		# Check for 3-tile area pattern (like decorations)
		if _check_three_by_three_area(tile_map, cell, enemy_layer_name):
			# Spawn enemies up to the limit for this chunk type
			if enemy_spawn_count < max_spawns:
				if DEBUG_ENEMY_TILES:
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
					if DEBUG_ENEMY_TILES:
						print("[EnemyPopulate] SKIP: Spawn position %s is outside chunk bounds" % spawn_position)
					continue
				
				# Check minimum distance from other spawned enemies (prevent clustering)
				# Reduced distance for dungeon chunks to allow more enemies
				var min_distance = 150.0 if chunk_type_str == "dungeon" else 200.0  # Closer spacing for dungeon
				var too_close = false
				for existing_pos in spawned_positions:
					if spawn_position.distance_to(existing_pos) < min_distance:
						too_close = true
						break
				
				if too_close:
					if DEBUG_ENEMY_TILES:
						print("[EnemyPopulate] SKIP: Spawn position %s too close to existing enemy" % spawn_position)
					continue
				
				# DETAILED DEBUG (Normal level)
				if DEBUG_ENEMY_TILES:
					print("[EnemyPopulate] Spawning enemy at: %s" % spawn_position)
				
				# Create enemy spawner
				# In Godot 4, we can't use .new() on a script directly
				# Instead, create a Node2D and set its script
				var enemy_spawner = Node2D.new()
				var enemy_spawner_script = load("res://enemy/tile_enemy_spawner.gd")
				enemy_spawner.set_script(enemy_spawner_script)
				# After set_script(), export variables need to be set using set() method
				# or we need to wait a frame. Using set() is more reliable.
				enemy_spawner.set("current_level", current_level)
				enemy_spawner.set("chunk_type", chunk_type_str)
				# Use dynamic spawn chance based on chunk type (set above)
				enemy_spawner.set("spawn_chance", spawn_chance_value)
				enemy_spawner.global_position = spawn_position
				
				# DETAILED SPAWNER DEBUG (Reduced)
				if DEBUG_ENEMY_TILES:
					print("[EnemyPopulate] Spawner created at: %s" % enemy_spawner.global_position)
				
				# Add to chunk
				chunk_node.add_child(enemy_spawner)
				
				# FIX: Reset position after add_child (parent-child transform issue)
				enemy_spawner.global_position = spawn_position
				
				# DETAILED SPAWNER DEBUG AFTER ADD (Reduced)
				if DEBUG_ENEMY_TILES:
					print("[EnemyPopulate] Spawner added to: %s" % enemy_spawner.get_parent().name)
				
				# Activate spawner - use call_deferred to ensure script is fully loaded
				# Script needs to be fully initialized before calling methods
				enemy_spawner.call_deferred("activate")
				
				# Add visual marker for debug - show which tile was selected for spawning
				if DEBUG_ENEMY_TILES:
					print("[EnemyPopulate] Adding marker for tile: %s" % center_cell)
					_add_spawn_tile_marker(tile_map, center_cell, chunk_node)
				
				# Track this spawn position
				spawned_positions.append(spawn_position)
				enemy_spawn_count += 1
				if DEBUG_ENEMY_TILES:
					print("[EnemyPopulate] Spawned enemy at 3-tile area: %s" % center_cell)
	
	if DEBUG_ENEMY_TILES:
		print("[EnemyPopulate] Spawned %d enemies in chunk '%s'" % [enemy_spawn_count, chunk_node.name])

# Add visual marker to show which tile was selected for enemy spawning
func _add_spawn_tile_marker(tile_map: TileMapLayer, cell: Vector2i, chunk_node: Node2D) -> void:
	# Get tile position for debugging
	var tile_pos = tile_map.map_to_local(cell)
	var world_pos = tile_map.to_global(tile_pos)
	
	# Console'da spawn pozisyonunu göster
	if DEBUG_ENEMY_TILES:
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
	
	if DEBUG_ENEMY_TILES:
		print("🔍 HEIGHT CHECK: Checking clearance above %s" % center_cell)
	
	# Spawn alanının üstündeki tile'ları kontrol et
	for i in range(1, min_height + 1):
		var check_cell = center_cell + Vector2i(0, -i)  # Yukarı doğru
		var tile_data = tile_map.get_cell_tile_data(check_cell)
		
		if DEBUG_ENEMY_TILES:
			print("  📍 Checking cell %s (height: %d)" % [check_cell, i])
		
		# Eğer üstte HERHANGİ BİR tile varsa, yeterli yükseklik yok
		if tile_data:
			var custom_data = tile_data.get_custom_data(layer_name)
			if DEBUG_ENEMY_TILES:
				print("    ❌ Found tile with data: '%s'" % custom_data)
			
			# Solid tile'lar: wall, ceiling, platform vb.
			if custom_data in ["wall", "ceiling", "platform", "solid", "block", "terrain"]:
				if DEBUG_ENEMY_TILES:
					print("❌ HEIGHT CHECK FAILED: Solid tile at %s (height: %d, data: %s)" % [check_cell, i, custom_data])
				return false
			else:
				# Eğer tile var ama solid değilse, yine de yükseklik yok
				if DEBUG_ENEMY_TILES:
					print("❌ HEIGHT CHECK FAILED: Any tile at %s (height: %d, data: %s)" % [check_cell, i, custom_data])
				return false
		else:
			if DEBUG_ENEMY_TILES:
				print("    ✅ No tile found - clear space")
	
	if DEBUG_ENEMY_TILES:
		print("✅ HEIGHT CHECK PASSED: Clear space above %s (height: %d+)" % [center_cell, min_height])
	return true

func _get_chunk_type_for_node(chunk_node: Node2D) -> String:
	# Determine chunk type based on chunk name, scene path, or other properties
	var chunk_name = chunk_node.name.to_lower()
	var scene_path = chunk_node.scene_file_path.to_lower() if chunk_node.scene_file_path else ""
	
	if DEBUG_ENEMY_TILES:
		print("[LevelGenerator] Checking chunk type for: %s (path: %s)" % [chunk_node.name, scene_path])
	
	# Check chunk name first
	if "combat" in chunk_name:
		if DEBUG_ENEMY_TILES:
			print("[LevelGenerator] Detected as combat chunk (by name)")
		return "combat"
	elif "dungeon" in chunk_name or "zindan" in chunk_name or "boss" in chunk_name:
		if DEBUG_ENEMY_TILES:
			print("[LevelGenerator] Detected as dungeon chunk (by name)")
		return "dungeon"
	
	# Check scene path - if it contains "dungeon", it's a dungeon chunk
	if scene_path != "":
		if "dungeon" in scene_path:
			if DEBUG_ENEMY_TILES:
				print("[LevelGenerator] Detected as dungeon chunk (by scene path)")
			return "dungeon"
		elif "combat" in scene_path:
			if DEBUG_ENEMY_TILES:
				print("[LevelGenerator] Detected as combat chunk (by scene path)")
			return "combat"
	
	# If chunk is in chunks/dungeon/ directory, it's a dungeon chunk
	# All chunks in this game are dungeon chunks unless explicitly marked otherwise
	# Default to dungeon for all chunks since we're in dungeon levels
	if DEBUG_ENEMY_TILES:
		print("[LevelGenerator] Defaulting to dungeon chunk (all chunks are dungeon chunks)")
	return "dungeon"

func _clear_all_enemies_from_previous_level() -> void:
	print("[LevelGenerator] Clearing all enemies from previous level...")
	
	# Clear enemies from all chunks
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			var cell = grid[x][y]
			if cell.chunk:
				_clear_enemies_from_chunk(cell.chunk)
				_clear_traps_from_chunk(cell.chunk)
	
	# Clear enemies from unified terrain if it exists
	if unified_terrain:
		_clear_enemies_from_chunk(unified_terrain)
		_clear_traps_from_chunk(unified_terrain)

	# Clear trap projectiles that might still be flying around
	for proj in get_tree().get_nodes_in_group("trap_projectile"):
		if is_instance_valid(proj):
			proj.queue_free()

	# Clear blood splatters from previous fights
	for splatter in get_tree().get_nodes_in_group("blood_splatter"):
		if is_instance_valid(splatter):
			splatter.queue_free()

	# Clear poison pools (acid puddles) left from previous level
	for pool in get_tree().get_nodes_in_group("poison_pools"):
		if is_instance_valid(pool):
			pool.queue_free()

	print("[LevelGenerator] Enemy & trap cleanup completed")

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

# ==============================================================================
# TRAP POPULATION (V2 tile-based system)
# ==============================================================================

func _populate_traps_on_unified_terrain() -> void:
	if not unified_terrain:
		push_error("[TrapPopulate] unified_terrain is null — cannot spawn traps")
		return

	var ts: TileSet = unified_terrain.tile_set
	if not ts:
		push_error("[TrapPopulate] unified_terrain has no tile_set")
		return

	# Determine which custom data layer to read
	var surface_layer_name := ""
	var use_dedicated_layer := false
	for i in range(ts.get_custom_data_layers_count()):
		if ts.get_custom_data_layer_name(i) == "trap_surface":
			surface_layer_name = "trap_surface"
			use_dedicated_layer = true
			break
	if surface_layer_name == "":
		for i in range(ts.get_custom_data_layers_count()):
			if ts.get_custom_data_layer_name(i) == "decor_anchor":
				surface_layer_name = "decor_anchor"
				break
	if surface_layer_name == "":
		print("[TrapPopulate] No trap-eligible custom data layer in unified_terrain")
		return

	# Build exclusion rects for start / finish / boss / rescue chunks (no traps there)
	var exclude_rects: Array[Rect2] = _build_excluded_chunk_rects()

	# Accept both "_surface" and short names; include common typo "lef_wall_surface" (missing t)
	var trap_surface_tags := ["floor_surface", "ceiling_surface", "left_wall_surface", "lef_wall_surface", "right_wall_surface", "floor", "ceiling", "left_wall", "right_wall"]

	# 1. Collect all eligible cells grouped by surface tag
	var surface_cells: Dictionary = {}  # tag_string -> Array[Vector2i]
	for cell in unified_terrain.get_used_cells(0):
		var td: TileData = unified_terrain.get_cell_tile_data(0, cell)
		if not td:
			continue
		var stype = td.get_custom_data(surface_layer_name)
		if not stype or stype == "":
			continue
		if not use_dedicated_layer and stype not in trap_surface_tags:
			continue

		# Convert cell to world position to check against exclusion rects
		var world_pos: Vector2 = unified_terrain.map_to_local(cell) + unified_terrain.global_position
		var excluded := false
		for r in exclude_rects:
			if r.has_point(world_pos):
				excluded = true
				break
		if excluded:
			continue

		if not surface_cells.has(stype):
			surface_cells[stype] = []
		surface_cells[stype].append(cell)

	if surface_cells.is_empty():
		print("[TrapPopulate] No trap-eligible tiles in unified_terrain")
		return

	# 2. Build contiguous runs per surface type (fixed order: left wall before right so both get rounds)
	var surface_run_queues: Array = []
	var surface_order: Array[String] = ["floor_surface", "ceiling_surface", "left_wall_surface", "lef_wall_surface", "left_wall", "right_wall_surface", "right_wall"]
	for stype_str in surface_order:
		if not surface_cells.has(stype_str):
			continue
		var surface := TrapConfigV2.surface_from_string(stype_str)
		var cells: Array = surface_cells[stype_str]
		var runs: Array = _find_contiguous_runs(cells, surface)
		runs.shuffle()
		if not runs.is_empty():
			surface_run_queues.append({
				"surface": surface,
				"stype_str": stype_str,
				"runs": runs,
				"index": 0
			})

	# 3. Round-robin spawn across surface types
	var trap_spawn_count: int = 0
	var max_trap_groups: int = _get_max_trap_groups_for_level(current_level)
	var spawned_trap_positions: Array[Vector2] = []
	var half_tile := Vector2(ts.tile_size) * 0.5
	var queue_idx: int = 0
	var stall_counter: int = 0
	var max_stall: int = surface_run_queues.size() * 3

	while trap_spawn_count < max_trap_groups and not surface_run_queues.is_empty():
		if stall_counter >= max_stall:
			break
		var q: Dictionary = surface_run_queues[queue_idx % surface_run_queues.size()]
		var runs: Array = q.runs
		var ri: int = q.index

		if ri >= runs.size():
			queue_idx += 1
			stall_counter += 1
			continue

		var run: Array = runs[ri]
		q.index = ri + 1

		if randf() > _get_trap_spawn_chance():
			queue_idx += 1
			stall_counter += 1
			continue

		stall_counter = 0
		var surface: TrapConfigV2.SurfaceType = q.surface
		var stype_str: String = q.stype_str

		var size_range := TrapConfigV2.get_group_size_range(effective_trap_level)
		var max_possible: int = mini(size_range.y, run.size())
		var min_possible: int = mini(size_range.x, max_possible)
		var group_size: int = randi_range(min_possible, max_possible)
		if group_size <= 0:
			queue_idx += 1
			continue

		var max_start: int = maxi(0, run.size() - group_size)
		var start_idx: int = randi_range(0, max_start)

		var trap_type := TrapConfigV2.select_random_trap(surface, effective_trap_level)

		var first_cell: Vector2i = run[start_idx]
		var first_world_pos: Vector2 = unified_terrain.map_to_local(first_cell) + unified_terrain.global_position
		var too_close := false
		for existing_pos in spawned_trap_positions:
			if first_world_pos.distance_to(existing_pos) < 128.0:
				too_close = true
				break
		if too_close:
			queue_idx += 1
			continue

		var spawned_any := false
		for i in range(group_size):
			var cell: Vector2i = run[start_idx + i]

			if not _is_valid_trap_tile_unified(cell, surface, surface_layer_name):
				continue

			var local_pos: Vector2 = unified_terrain.map_to_local(cell)
			var world_pos: Vector2 = local_pos + unified_terrain.global_position

			match surface:
				TrapConfigV2.SurfaceType.FLOOR:
					world_pos.y -= half_tile.y
				TrapConfigV2.SurfaceType.CEILING:
					world_pos.y += half_tile.y
				TrapConfigV2.SurfaceType.LEFT_WALL:
					world_pos.x += half_tile.x
				TrapConfigV2.SurfaceType.RIGHT_WALL:
					world_pos.x -= half_tile.x

			var spawner := Node2D.new()
			var spawner_script = load("res://traps_v2/tile_trap_spawner.gd")
			spawner.set_script(spawner_script)
			spawner.set("trap_type", trap_type)
			spawner.set("surface_type", surface)
			spawner.set("current_level", effective_trap_level)
			spawner.global_position = world_pos
			unified_terrain.add_child(spawner)
			spawner.global_position = world_pos
			spawner.call_deferred("activate")
			spawned_any = true

		if not spawned_any:
			queue_idx += 1
			continue

		spawned_trap_positions.append(first_world_pos)
		trap_spawn_count += 1
		queue_idx += 1

func _populate_enemies_on_unified_terrain() -> void:
	if not unified_terrain:
		push_error("[EnemyPopulate] unified_terrain is null — cannot spawn enemies")
		return

	var ts: TileSet = unified_terrain.tile_set
	if not ts:
		push_error("[EnemyPopulate] unified_terrain has no tile_set")
		return

	var enemy_layer_name := "decor_anchor"
	var has_enemy_layer := false
	for i in range(ts.get_custom_data_layers_count()):
		if ts.get_custom_data_layer_name(i) == enemy_layer_name:
			has_enemy_layer = true
			break
	if not has_enemy_layer:
		print("[EnemyPopulate] No '%s' custom data layer on unified_terrain" % enemy_layer_name)
		return

	var exclude_rects: Array[Rect2] = _build_excluded_chunk_rects()

	var used_cells := unified_terrain.get_used_cells(0)
	if used_cells.is_empty():
		print("[EnemyPopulate] No used cells on unified_terrain")
		return

	# Basitleştirilmiş sistem: SpawnConfig'e bağlı kalmadan,
	# unified terrain'deki floor/floor_surface anchor'larından
	# rastgele birkaç düşman spawnla.
	var floor_cells: Array[Vector2i] = []
	for cell in used_cells:
		var td: TileData = unified_terrain.get_cell_tile_data(0, cell)
		if not td:
			continue
		var stype = td.get_custom_data(enemy_layer_name)
		if not stype or stype == "":
			continue
		var s := String(stype)
		if s != "floor" and s != "floor_surface":
			continue
		# Exclusion rect'lerin dışında mı?
		var world_pos: Vector2 = unified_terrain.map_to_local(cell) + unified_terrain.global_position
		var excluded := false
		for r in exclude_rects:
			if r.has_point(world_pos):
				excluded = true
				break
		if excluded:
			continue
		floor_cells.append(cell)

	if floor_cells.is_empty():
		print("[EnemyPopulate] No floor anchors on unified_terrain")
		return

	floor_cells.shuffle()

	var level_cap: int = _get_max_unified_enemies_for_level(current_level)
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs and drs.run_started:
		level_cap += (drs.enemy_count_offset + int(drs.get("run_base_difficulty"))) * 2
		if drs.is_first_segment():
			level_cap = maxi(1, level_cap / 2)
	var max_spawns: int = mini(level_cap, floor_cells.size())
	var spawned_positions: Array[Vector2] = []
	var tile_size_v2: Vector2 = Vector2(ts.tile_size)
	var half_tile := tile_size_v2 * 0.5

	print("[EnemyPopulate] floor_cells=%d, will spawn up to %d enemies (level=%d)" % [
		floor_cells.size(), max_spawns, current_level
	])

	for i in range(max_spawns):
		var cell: Vector2i = floor_cells[i]
		var local_pos = unified_terrain.map_to_local(cell)
		var tile_center: Vector2 = unified_terrain.to_global(local_pos) + half_tile

		var floor_offset_y = 150.0
		var spawn_position = tile_center + Vector2(0.0, -floor_offset_y)

		var min_distance = 150.0
		var too_close = false
		for existing_pos in spawned_positions:
			if spawn_position.distance_to(existing_pos) < min_distance:
				too_close = true
				break
		if too_close:
			continue

		var enemy_spawner := Node2D.new()
		var enemy_spawner_script = load("res://enemy/tile_enemy_spawner.gd")
		enemy_spawner.set_script(enemy_spawner_script)
		enemy_spawner.set("current_level", current_level)
		enemy_spawner.set("chunk_type", "dungeon")
		enemy_spawner.set("spawn_chance", 1.0)
		enemy_spawner.global_position = spawn_position
		add_child(enemy_spawner)
		enemy_spawner.call_deferred("activate")

		spawned_positions.append(spawn_position)

	print("[EnemyPopulate] Spawned %d enemies on unified terrain" % spawned_positions.size())

func _build_excluded_chunk_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for x in range(current_grid_width):
		for y in range(current_grid_height):
			if x < 0 or x >= grid.size():
				continue
			if y < 0 or y >= grid[x].size():
				continue
			var chunk = grid[x][y].chunk
			if not chunk:
				continue
			var path: String = chunk.scene_file_path.to_lower() if chunk.scene_file_path else ""
			var cname: String = chunk.name.to_lower()
			# Start / finish / boss / rescue (villager + vip) chunk'larını unified trap/enemy için dışarıda bırak
			if "start" in cname or "start_chunk" in path \
					or "finish" in cname or "finish_chunk" in path \
					or "boss" in cname or "boss_arena" in path \
					or "villager_dead_end" in path or "vip_dead_end" in path:
				var rect := Rect2(chunk.global_position, CHUNK_SIZE)
				rects.append(rect)
	return rects

func _is_valid_trap_tile_unified(cell: Vector2i, surface: TrapConfigV2.SurfaceType, layer_name: String) -> bool:
	var this_tile: TileData = unified_terrain.get_cell_tile_data(0, cell)
	if not this_tile:
		return false

	var check_offset: Vector2i
	match surface:
		TrapConfigV2.SurfaceType.FLOOR:
			check_offset = Vector2i(0, -1)
		TrapConfigV2.SurfaceType.CEILING:
			check_offset = Vector2i(0, 1)
		TrapConfigV2.SurfaceType.LEFT_WALL:
			check_offset = Vector2i(1, 0)
		TrapConfigV2.SurfaceType.RIGHT_WALL:
			check_offset = Vector2i(-1, 0)
		_:
			return true

	var neighbor_cell := cell + check_offset
	var neighbor_data: TileData = unified_terrain.get_cell_tile_data(0, neighbor_cell)

	if neighbor_data:
		var neighbor_tag = neighbor_data.get_custom_data(layer_name)
		if neighbor_tag and neighbor_tag != "":
			return false
		if neighbor_data.get_collision_polygons_count(0) > 0:
			return false

	return true

# ---------- LEGACY chunk-based trap populate (no longer used) ----------
func _populate_traps_from_tilemap(chunk_node: Node2D) -> void:
	var chunk_name = chunk_node.name.to_lower()
	var scene_path = chunk_node.scene_file_path.to_lower() if chunk_node.scene_file_path else ""
	
	# Start / finish / rescue (villager/vip) chunk'larında tuzak spawn etme
	if "villager_dead_end" in scene_path or "vip_dead_end" in scene_path:
		return
	if "start" in chunk_name or "start_chunk" in scene_path:
		return
	if "finish" in chunk_name or "finish_chunk" in scene_path:
		return

	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	if not tile_map:
		return

	var tile_set = tile_map.tile_set
	if not tile_set:
		return

	# Look for a dedicated "trap_surface" custom data layer first.
	# Fallback to "decor_anchor" with _surface tags if trap_surface doesn't exist.
	var surface_layer_name := ""
	var use_dedicated_layer := false

	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == "trap_surface":
			surface_layer_name = "trap_surface"
			use_dedicated_layer = true
			break

	if surface_layer_name == "":
		for i in range(tile_set.get_custom_data_layers_count()):
			if tile_set.get_custom_data_layer_name(i) == "decor_anchor":
				surface_layer_name = "decor_anchor"
				break

	if surface_layer_name == "":
		return

	# When using decor_anchor as fallback, only consider these specific tags
	var trap_surface_tags := ["floor_surface", "ceiling_surface", "left_wall_surface", "right_wall_surface"]

	# 1. Collect all cells grouped by surface_type (only trap-eligible tags)
	var surface_cells: Dictionary = {}  # surface_tag -> Array[Vector2i]
	for cell in tile_map.get_used_cells():
		var tile_data = tile_map.get_cell_tile_data(cell)
		if not tile_data:
			continue
		var stype = tile_data.get_custom_data(surface_layer_name)
		if not stype or stype == "":
			continue
		# If using dedicated layer, accept all non-empty values
		# If using decor_anchor fallback, only accept trap-specific tags
		if not use_dedicated_layer and stype not in trap_surface_tags:
			continue
		if not surface_cells.has(stype):
			surface_cells[stype] = []
		surface_cells[stype].append(cell)

	# DEBUG: show what we found
	for tag in surface_cells:
		print("[TrapPopulate] Found %d cells with tag '%s' in chunk '%s' (layer: %s)" % [surface_cells[tag].size(), tag, chunk_node.name, surface_layer_name])

	if surface_cells.is_empty():
		print("[TrapPopulate] No trap-eligible tiles in chunk '%s'" % chunk_node.name)
		return

	# 2. Build a list of (surface, shuffled_runs) per surface type
	var surface_run_queues: Array = []  # Array of { surface: SurfaceType, stype_str: String, runs: Array }
	for stype_str in surface_cells:
		var surface := TrapConfigV2.surface_from_string(stype_str)
		var cells: Array = surface_cells[stype_str]
		var runs: Array = _find_contiguous_runs(cells, surface)
		runs.shuffle()
		if not runs.is_empty():
			surface_run_queues.append({
				"surface": surface,
				"stype_str": stype_str,
				"runs": runs,
				"index": 0
			})

	# Round-robin across surface types so each gets fair representation
	var trap_spawn_count: int = 0
	var max_trap_groups: int = _get_max_trap_groups_for_level(current_level)
	var spawned_trap_positions: Array[Vector2] = []
	var half_tile := Vector2(tile_set.tile_size) * 0.5
	var queue_idx: int = 0
	var stall_counter: int = 0
	var max_stall: int = surface_run_queues.size() * 3

	while trap_spawn_count < max_trap_groups and not surface_run_queues.is_empty():
		if stall_counter >= max_stall:
			break
		var q: Dictionary = surface_run_queues[queue_idx % surface_run_queues.size()]
		var runs: Array = q.runs
		var ri: int = q.index

		if ri >= runs.size():
			queue_idx += 1
			stall_counter += 1
			continue

		var run: Array = runs[ri]
		q.index = ri + 1

		# Spawn chance per group
		if randf() > _get_trap_spawn_chance():
			queue_idx += 1
			stall_counter += 1
			continue

		stall_counter = 0
		var surface: TrapConfigV2.SurfaceType = q.surface
		var stype_str: String = q.stype_str

		var size_range := TrapConfigV2.get_group_size_range(effective_trap_level)
		var max_possible: int = mini(size_range.y, run.size())
		var min_possible: int = mini(size_range.x, max_possible)
		var group_size: int = randi_range(min_possible, max_possible)
		if group_size <= 0:
			queue_idx += 1
			continue

		var max_start: int = maxi(0, run.size() - group_size)
		var start_idx: int = randi_range(0, max_start)

		var trap_type := TrapConfigV2.select_random_trap(surface, effective_trap_level)

		var first_cell: Vector2i = run[start_idx]
		var first_world_pos: Vector2 = tile_map.to_global(tile_map.map_to_local(first_cell))
		var too_close := false
		for existing_pos in spawned_trap_positions:
			if first_world_pos.distance_to(existing_pos) < 128.0:
				too_close = true
				break
		if too_close:
			queue_idx += 1
			continue

		var spawned_any := false
		for i in range(group_size):
			var cell: Vector2i = run[start_idx + i]

			# Validate: the adjacent tile in the open direction must be empty
			if not _is_valid_trap_tile(tile_map, cell, surface, surface_layer_name):
				continue

			var local_pos: Vector2 = tile_map.map_to_local(cell)
			var world_pos: Vector2 = tile_map.to_global(local_pos)

			match surface:
				TrapConfigV2.SurfaceType.FLOOR:
					world_pos.y -= half_tile.y
				TrapConfigV2.SurfaceType.CEILING:
					world_pos.y += half_tile.y
				TrapConfigV2.SurfaceType.LEFT_WALL:
					world_pos.x += half_tile.x
				TrapConfigV2.SurfaceType.RIGHT_WALL:
					world_pos.x -= half_tile.x

			var spawner := Node2D.new()
			var spawner_script = load("res://traps_v2/tile_trap_spawner.gd")
			spawner.set_script(spawner_script)
			spawner.set("trap_type", trap_type)
			spawner.set("surface_type", surface)
			spawner.set("current_level", effective_trap_level)
			spawner.global_position = world_pos
			chunk_node.add_child(spawner)
			spawner.global_position = world_pos
			spawner.call_deferred("activate")
			spawned_any = true

		if not spawned_any:
			queue_idx += 1
			continue

		spawned_trap_positions.append(first_world_pos)
		trap_spawn_count += 1
		print("[TrapPopulate] Spawned group of %d %s at %s (surface: %s)" % [
			group_size,
			TrapConfigV2.TrapType.keys()[trap_type],
			first_world_pos,
			stype_str
		])
		queue_idx += 1

	print("[TrapPopulate] Total trap groups in chunk '%s': %d" % [chunk_node.name, trap_spawn_count])

func _find_contiguous_runs(cells: Array, surface: TrapConfigV2.SurfaceType) -> Array:
	## Find groups of adjacent cells along the appropriate axis.
	## Floor/ceiling: horizontal runs (same y, consecutive x).
	## Walls: vertical runs (same x, consecutive y).
	var is_horizontal := (surface == TrapConfigV2.SurfaceType.FLOOR or surface == TrapConfigV2.SurfaceType.CEILING)

	# Build a set for O(1) lookup
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	var visited: Dictionary = {}
	var runs: Array = []

	for c in cells:
		if visited.has(c):
			continue
		# Walk along the axis to build a run
		var run: Array[Vector2i] = []
		var current: Vector2i = c
		while cell_set.has(current) and not visited.has(current):
			visited[current] = true
			run.append(current)
			if is_horizontal:
				current = Vector2i(current.x + 1, current.y)
			else:
				current = Vector2i(current.x, current.y + 1)
		if run.size() > 0:
			runs.append(run)

	return runs

func _get_max_trap_groups_for_level(level: int) -> int:
	var use_level: int = effective_trap_level
	# Düşük seviyelerde az tuzak; tuzak sayısı kademeli artsın (ani sıçrama olmasın)
	var per_chunk: int
	match use_level:
		0: per_chunk = 0
		1: per_chunk = 1
		2: per_chunk = 1
		3: per_chunk = 2
		4: per_chunk = 2
		5: per_chunk = 3
		6: per_chunk = 3
		7: per_chunk = 4
		8: per_chunk = 4
		_: per_chunk = 5
	var chunk_count: int = 0
	for x in range(current_grid_width):
		if x < 0 or x >= grid.size(): continue
		for y in range(current_grid_height):
			if y < 0 or y >= grid[x].size(): continue
			var c = grid[x][y].chunk
			if c:
				var n: String = c.name.to_lower()
				if "start" in n or "finish" in n or "boss" in n:
					continue
				chunk_count += 1
	var total: int = per_chunk * maxi(1, chunk_count)
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs and drs.run_started:
		var trap_base: int = int(drs.get("run_base_difficulty"))
		if drs.trap_count_offset > 0 or trap_base > 0:
			total += (drs.trap_count_offset + trap_base) * 2
		if drs.is_first_segment():
			total = maxi(0, total / 2)
	return total

func _get_trap_spawn_chance() -> float:
	var use_level: int = effective_trap_level
	# Düşük seviyede tuzak spawn olasılığı düşük; ani artış olmasın
	var chance: float
	match use_level:
		0: chance = 0.0
		1: chance = 0.22
		2: chance = 0.26
		3: chance = 0.32
		4: chance = 0.38
		5: chance = 0.42
		6: chance = 0.46
		7, 8: chance = 0.50
		_: chance = 0.54
	return chance

func _get_max_unified_enemies_for_level(level: int) -> int:
	# Unified terrain üzerinde toplam düşman üst sınırı (1–9 seviye)
	match level:
		1: return 4
		2: return 5
		3: return 6
		4: return 7
		5: return 8
		6: return 10
		7: return 12
		8: return 14
		9: return 16
		_: return 16

func _clear_traps_from_chunk(chunk_node: Node2D) -> void:
	if not chunk_node:
		return
	var trap_spawners = chunk_node.find_children("*", "TileTrapSpawner", true, false)
	for spawner in trap_spawners:
		if spawner.has_method("clear_trap"):
			spawner.clear_trap()
		spawner.queue_free()

func _is_valid_trap_tile(tile_map: Node, cell: Vector2i, surface: TrapConfigV2.SurfaceType, layer_name: String) -> bool:
	## Check that the tile is solid AND the adjacent tile in the open direction is empty.
	## Floor trap: tile below player's feet — the cell above must be empty (air).
	## Ceiling trap: tile above player's head — the cell below must be empty.
	## Wall trap: the cell in the shoot direction must be empty.

	# First, verify this cell itself has tile data
	var this_tile: TileData = tile_map.get_cell_tile_data(cell)
	if not this_tile:
		return false

	# Determine which neighbor must be empty
	var check_offset: Vector2i
	match surface:
		TrapConfigV2.SurfaceType.FLOOR:
			check_offset = Vector2i(0, -1)  # cell above must be air
		TrapConfigV2.SurfaceType.CEILING:
			check_offset = Vector2i(0, 1)   # cell below must be air
		TrapConfigV2.SurfaceType.LEFT_WALL:
			check_offset = Vector2i(1, 0)   # cell to the right must be air
		TrapConfigV2.SurfaceType.RIGHT_WALL:
			check_offset = Vector2i(-1, 0)  # cell to the left must be air
		_:
			return true

	var neighbor_cell := cell + check_offset
	var neighbor_data: TileData = tile_map.get_cell_tile_data(neighbor_cell)

	# Neighbor must be empty (no tile) or at least not a solid surface tile
	if neighbor_data:
		var neighbor_tag = neighbor_data.get_custom_data(layer_name)
		# If neighbor also has a surface tag, it's solid — not a valid open space
		if neighbor_tag and neighbor_tag != "":
			return false
		# Even without a tag, if there's tile data with collision, it's solid
		if neighbor_data.get_collision_polygons_count(0) > 0:
			return false

	return true
