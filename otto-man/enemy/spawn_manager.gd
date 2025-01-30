extends Node
class_name SpawnManager

var _spawn_config: SpawnConfig
var _spawn_points: Array[EnemySpawner] = []
var _active_points: Array[EnemySpawner] = []
var _chunk_type: String = "basic"
var _current_level: int = 1

func _ready() -> void:
	_spawn_config = SpawnConfig.new()
	
	# Collect all spawn points in the chunk
	for child in get_parent().get_children():
		if child is EnemySpawner:
			_spawn_points.append(child as EnemySpawner)
			child.chunk_type = _chunk_type

func initialize(chunk_type: String, level: int) -> void:
	_chunk_type = chunk_type
	_current_level = level
	
	# Update all spawn points with current settings
	for point in _spawn_points:
		point.chunk_type = chunk_type
		point.current_level = level
	
	# Select which spawn points to activate
	_active_points = _spawn_config.select_spawn_points(_spawn_points, chunk_type, level)
	
	# Activate selected points
	for point in _spawn_points:
		if point in _active_points:
			point.activate()
		else:
			point.deactivate()

func get_active_spawn_points() -> Array[EnemySpawner]:
	return _active_points

func clear_all_enemies() -> void:
	for point in _spawn_points:
		point.clear_enemies()

func set_level(level: int) -> void:
	_current_level = level
	initialize(_chunk_type, level)  # Re-initialize with new level

# Optional: Start all spawners with a cooldown
func start_all_spawning(interval: float = 5.0) -> void:
	for point in _active_points:
		point.start_spawning(interval) 
