@tool
extends Node2D
class_name ForestRampChunk

# Vertical ramp chunk for forest built from square units.

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN
}

@export var is_up: bool = true # true: ramp_up (moves one row up), false: ramp_down
@export var size_in_units: Vector2i = Vector2i(1, 2) # 1x2 for ramp
@export var unit_size: int = 2048
@export var debug_draw: bool = true

var size: Vector2:
	get: return Vector2(size_in_units.x * unit_size, size_in_units.y * unit_size)

var connections: Array[Direction] = []
var connection_points: Dictionary = {}

var chunk_type: String = "forest"

func _ready() -> void:
	connections = [Direction.LEFT, Direction.RIGHT]
	_initialize_chunk()
	if Engine.is_editor_hint():
		queue_redraw()

func _initialize_chunk() -> void:
	_setup_connection_points()

func _setup_connection_points() -> void:
	connection_points.clear()
	var points_node = get_node_or_null("ConnectionPoints")
	if not points_node:
		return
	for direction in connections:
		_add_connection_point(points_node, direction)

func _add_connection_point(points_node: Node, direction: Direction) -> void:
	var point_name = Direction.keys()[direction].to_lower()
	var point = points_node.get_node_or_null(point_name)
	if point:
		connection_points[direction] = point

func has_connection(direction: Direction) -> bool:
	return direction in connections

func get_connection_point(direction: Direction) -> Node2D:
	return connection_points.get(direction)

func get_chunk_size() -> Vector2:
	return size

func _draw() -> void:
	if not debug_draw:
		return
	# Draw bounds
	draw_rect(Rect2(Vector2.ZERO, size), Color.SEA_GREEN, false, 2.0)
	# Visual hint: diagonal for up/down
	var start := Vector2(0, (size.y if is_up else 0))
	var end := Vector2(size.x, (0 if is_up else size.y))
	draw_line(start, end, Color.LIGHT_GREEN, 2.0)
	for dir in connections:
		var p := _get_default_connection_point(dir)
		draw_circle(p, 6.0, Color.LIGHT_GREEN)

func _get_default_connection_point(dir: Direction) -> Vector2:
	match dir:
		Direction.LEFT:
			# Connect mid of lower edge for ramp_up to align bottoms; for ramp_down align tops.
			return Vector2(0, (size.y - unit_size * 0.5) if is_up else (unit_size * 0.5))
		Direction.RIGHT:
			return Vector2(size.x, (unit_size * 0.5) if is_up else (size.y - unit_size * 0.5))
	return Vector2.ZERO
