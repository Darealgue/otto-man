@tool
extends Node2D
class_name BaseChunk

# Possible connection directions
enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN
}

# Size configuration
@export var size_in_units: Vector2i = Vector2i(1, 1)
@export var debug_draw: bool = true
@export var size = Vector2(1920, 1080)

# Connections are determined by scene name
var connections: Array[Direction] = []

# Connection points - automatically updated based on size
var connection_points: Dictionary = {}
var base_size = Vector2(1920, 1080)
var actual_size: Vector2:
	get: return base_size * size_in_units

# Called when the node enters the scene tree
func _ready() -> void:
	# Initialize connections based on scene name
	_initialize_connections()
	
	if not Engine.is_editor_hint():
		print("[BaseChunk] Initialized: ", name)
		print("  - Size: ", size)
		print("  - Connections: ", connections)
	else:
		_initialize_chunk()

func _initialize_chunk() -> void:
	print("[BaseChunk] Initializing chunk: ", name)
	print("  - Size: ", size_in_units)
	
	# Setup connection points
	_setup_connection_points()

func _initialize_connections() -> void:
	connections.clear()
	
	# Get the scene name for connection setup
	var scene_name = get_scene_file_path().get_file().get_basename()
	
	# Initialize connections based on scene name
	if scene_name == "start_chunk":
		connections = [Direction.RIGHT]
	elif scene_name == "finish_chunk":
		connections = [Direction.LEFT]
	elif scene_name == "basic_platform" or scene_name == "combat_arena":
		connections = [Direction.LEFT, Direction.RIGHT]
	elif scene_name == "climbing_tower":
		connections = [Direction.UP, Direction.DOWN]
	elif scene_name.begins_with("l_corner"):
		if "left_up" in scene_name:
			connections = [Direction.LEFT, Direction.UP]
		elif "left_down" in scene_name:
			connections = [Direction.LEFT, Direction.DOWN]
		elif "right_up" in scene_name:
			connections = [Direction.RIGHT, Direction.UP]
		elif "right_down" in scene_name:
			connections = [Direction.RIGHT, Direction.DOWN]
	elif scene_name.begins_with("t_junction"):
		if "left" in scene_name:
			connections = [Direction.RIGHT, Direction.UP, Direction.DOWN]
		elif "right" in scene_name:
			connections = [Direction.LEFT, Direction.UP, Direction.DOWN]
		elif "up" in scene_name:
			connections = [Direction.LEFT, Direction.RIGHT, Direction.DOWN]
		elif "down" in scene_name:
			connections = [Direction.LEFT, Direction.RIGHT, Direction.UP]
	elif scene_name == "four_way_hub":
		connections = [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]

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

# Debug drawing in editor
func _setup_debug_draw() -> void:
	if not debug_draw:
		queue_redraw()
		return
		
	# Update connection points
	_setup_connection_points()
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw chunk bounds
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLUE, false, 2.0)
		
		# Draw connection points
		for dir in connections:
			var point = _get_connection_point(dir)
			draw_circle(point, 10, Color.GREEN)

func _get_connection_point(dir: Direction) -> Vector2:
	match dir:
		Direction.LEFT: return Vector2(0, size.y / 2)
		Direction.RIGHT: return Vector2(size.x, size.y / 2)
		Direction.UP: return Vector2(size.x / 2, 0)
		Direction.DOWN: return Vector2(size.x / 2, size.y)
	return Vector2.ZERO
 
