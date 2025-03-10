@tool
extends Node2D
class_name LinearChunk

# Only allow left/right connections for linear progression
enum Direction {
	LEFT,
	RIGHT
}

# Size configuration (using same base size as BaseChunk for consistency)
@export var size_in_units: Vector2i = Vector2i(1, 1)
@export var debug_draw: bool = true

# Base size and actual size calculations
const BASE_SIZE = Vector2(1920, 1080)
var size: Vector2:
	get: return BASE_SIZE * Vector2(size_in_units)

# Connections are determined by scene name
var connections: Array[Direction] = []
var connection_points: Dictionary = {}

var chunk_type: String = "city"  # Base type for city chunks
@onready var spawn_manager: SpawnManager = $SpawnManager as SpawnManager

func _ready() -> void:
	print("[LinearChunk] Initialized:", name)
	print("  - Size:", get_chunk_size())
	print("  - Actual size:", size)
	print("  - Size in units:", size_in_units)
	print("  - Connections:", get_connections())
	
	# Initialize spawn manager
	if spawn_manager:
		var level = 1  # Default level
		var level_generator = get_tree().get_first_node_in_group("level_generator")
		if level_generator:
			level = level_generator.current_level
		
		# Initialize spawn manager with chunk type and level
		spawn_manager.initialize(chunk_type, level)

func _initialize_chunk() -> void:
	print("[LinearChunk] Initializing chunk: ", name)
	print("  - Size: ", size_in_units)
	
	# Setup connection points
	_setup_connection_points()

func _setup_connection_points() -> void:
	# Clear existing points
	connection_points.clear()
	
	# Get the ConnectionPoints node
	var points_node = get_node_or_null("ConnectionPoints")
	if not points_node:
		print("  - Warning: No ConnectionPoints node found")
		return
	
	# Add connection points based on available connections
	for direction in connections:
		_add_connection_point(points_node, direction)

func _add_connection_point(points_node: Node, direction: Direction) -> void:
	var point_name = Direction.keys()[direction].to_lower()
	var point = points_node.get_node_or_null(point_name)
	if point:
		connection_points[direction] = point
		print("  - Added connection point: ", point_name)

func has_connection(direction: Direction) -> bool:
	return direction in connections

func get_connection_point(direction: Direction) -> Node2D:
	return connection_points.get(direction)

func get_available_connections() -> Array[Direction]:
	return connections.duplicate()

func get_chunk_size() -> Vector2:
	return BASE_SIZE * Vector2(size_in_units)  # Return actual size based on units

func get_connections() -> Array:
	# Override in specific chunks to define their connections
	return []

func get_chunk_position() -> Vector2:
	return position

func set_level(level: int) -> void:
	if spawn_manager:
		spawn_manager.set_level(level)

# Optional: Start spawning enemies with interval
func start_spawning(interval: float = 5.0) -> void:
	if spawn_manager:
		spawn_manager.start_all_spawning(interval)

# Clear all enemies in this chunk
func clear_enemies() -> void:
	if spawn_manager:
		spawn_manager.clear_all_enemies()

# Get active spawn points
func get_active_spawn_points() -> Array:
	if spawn_manager:
		return spawn_manager.get_active_spawn_points()
	return [] 
