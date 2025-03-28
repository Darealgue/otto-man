extends Node2D
class_name CityLevelGenerator

signal level_started
signal level_completed

@export var current_level: int = 1
@export var chunk_spacing: float = 0.0  # Space between chunks
@export var level_config: LevelConfig  # Reference to level configuration

var main_paths: Array[Array] = []  # Array of arrays, each containing chunks for a main path
var branch_chunks: Array[LinearChunk] = []  # Chunks that form branches
var merge_points: Array[LinearChunk] = []  # Points where branches can merge back to main paths
var player: Node2D

# Preload your existing chunk scenes
var chunk_scenes = {}  # We'll load these in _ready() to catch any errors

func _ready() -> void:
	add_to_group("level_generator")
	
	# Load chunk scenes with error handling
	_load_chunk_scenes()
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[CityLevelGenerator] Player not found!")
		return
	
	# Start with initial chunks
	_generate_level()
	
	# Start level
	level_started.emit()

func _load_chunk_scenes() -> void:
	print("[CityLevelGenerator] Loading chunk scenes...")
	
	var scene_paths = {
		"poor": "res://chunks/city/neighborhoods/poor/poor_house_1.tscn",
		"middle": "res://chunks/city/neighborhoods/middle/middle_house_1.tscn",
		"rich": "res://chunks/city/neighborhoods/rich/rich_house_1.tscn"
	}
	
	for type in scene_paths:
		var path = scene_paths[type]
		print("  Loading", type, "chunk from:", path)
		
		if not FileAccess.file_exists(path):
			push_error("[CityLevelGenerator] Chunk scene file not found:", path)
			continue
			
		var scene = load(path)
		if scene:
			chunk_scenes[type] = scene
			print("  Successfully loaded", type, "chunk")
			print("  Scene type:", scene.get_class())
		else:
			push_error("[CityLevelGenerator] Failed to load chunk scene:", path)

func _generate_level() -> void:
	# Clear existing chunks
	_clear_all_chunks()
	
	# Get number of main paths for this level
	var num_main_paths = level_config.get_num_main_paths(current_level)
	print("[CityLevelGenerator] Generating level with", num_main_paths, "main paths")
	
	# Generate each main path
	for i in range(num_main_paths):
		var path_chunks: Array[LinearChunk] = []
		var path_length = level_config.get_length_for_level(current_level)
		var current_x = i * (path_length * 100)  # Space paths horizontally
		
		print("[CityLevelGenerator] Generating main path", i + 1)
		
		# Generate chunks for this path
		for j in range(path_length):
			var chunk_type = _select_chunk_type()
			var chunk = _spawn_chunk(chunk_type)
			if chunk:
				chunk.position.x = current_x
				chunk.position.y = 0  # Reset Y position for each path
				path_chunks.append(chunk)
				current_x += chunk.size.x + chunk_spacing
				
				# Add merge points randomly
				if randf() < 0.3:  # 30% chance for merge point
					merge_points.append(chunk)
		
		main_paths.append(path_chunks)
	
	# Generate branches
	_generate_branches()

func _generate_branches() -> void:
	var num_branches = level_config.get_num_branches_for_level(current_level)
	print("[CityLevelGenerator] Generating", num_branches, "branches")
	
	for i in range(num_branches):
		# Select a random main path to branch from
		var source_path_index = randi() % main_paths.size()
		var source_path = main_paths[source_path_index]
		
		# Select a random chunk from the source path
		var source_chunk = source_path[randi() % source_path.size()]
		
		# Create branch
		var branch_length = randi_range(3, 6)  # Random branch length
		var current_x = source_chunk.position.x
		var current_y = source_chunk.position.y + 200  # Start branch below main path
		
		print("[CityLevelGenerator] Generating branch", i + 1, "from path", source_path_index + 1)
		
		for j in range(branch_length):
			var chunk_type = _select_chunk_type()
			var chunk = _spawn_chunk(chunk_type)
			if chunk:
				chunk.position.x = current_x
				chunk.position.y = current_y
				branch_chunks.append(chunk)
				current_x += chunk.size.x + chunk_spacing
				
				# Check if this branch should merge back to a main path
				if level_config.should_merge_branch() and not merge_points.is_empty():
					var merge_point = merge_points[randi() % merge_points.size()]
					_connect_branch_to_main(chunk, merge_point)
					break

func _connect_branch_to_main(branch_chunk: LinearChunk, main_chunk: LinearChunk) -> void:
	# Create a connection chunk between branch and main path
	var connection_chunk = _spawn_chunk("middle")  # Use middle chunk for connection
	if connection_chunk:
		connection_chunk.position = Vector2(
			branch_chunk.position.x,
			(branch_chunk.position.y + main_chunk.position.y) / 2
		)
		branch_chunks.append(connection_chunk)
		print("[CityLevelGenerator] Connected branch to main path")

func _select_chunk_type() -> String:
	var types = ["poor", "middle", "rich"]
	return types[randi() % types.size()]

func _clear_all_chunks() -> void:
	# Clear main paths
	for path in main_paths:
		for chunk in path:
			chunk.queue_free()
	main_paths.clear()
	
	# Clear branch chunks
	for chunk in branch_chunks:
		chunk.queue_free()
	branch_chunks.clear()
	
	# Clear merge points
	merge_points.clear()

func _spawn_chunk(chunk_type: String) -> LinearChunk:
	print("  [_spawn_chunk] Starting spawn of", chunk_type)
	
	if not chunk_scenes.has(chunk_type):
		push_error("[CityLevelGenerator] Invalid chunk type:", chunk_type)
		return null
	
	var chunk_scene = chunk_scenes[chunk_type]
	if not chunk_scene:
		push_error("[CityLevelGenerator] Chunk scene is null:", chunk_type)
		return null
		
	print("  [_spawn_chunk] Scene found for", chunk_type, ", attempting instantiation")
	print("  [_spawn_chunk] Scene type:", chunk_scene.get_class())
	
	var instance = chunk_scene.instantiate()
	if not instance:
		push_error("[CityLevelGenerator] Failed to instantiate scene:", chunk_type)
		return null
		
	print("  [_spawn_chunk] Instance created, type:", instance.get_class())
	
	var chunk = instance as LinearChunk
	if not chunk:
		push_error("[CityLevelGenerator] Instance is not a LinearChunk:", chunk_type)
		push_error("  Got type:", instance.get_class())
		instance.free()
		return null
		
	print("  [_spawn_chunk] Successfully cast to LinearChunk")
	add_child(chunk)
	chunk.set_level(current_level)
	return chunk

func _physics_process(_delta: float) -> void:
	if not player:
		return
	
	# Update chunk visibility based on player position
	for path in main_paths:
		for chunk in path:
			_update_chunk_visibility(chunk)
	
	for chunk in branch_chunks:
		_update_chunk_visibility(chunk)

func _update_chunk_visibility(chunk: LinearChunk) -> void:
	var chunk_start = chunk.global_position.x
	var chunk_end = chunk_start + chunk.size.x
	var player_x = player.global_position.x
	
	# Simple visibility toggling based on distance
	chunk.visible = abs(player_x - (chunk_start + chunk.size.x * 0.5)) < chunk.size.x * 2

func get_spawn_position() -> Vector2:
	if main_paths.is_empty() or main_paths[0].is_empty():
		return Vector2.ZERO
	
	# Return the center of the first chunk of the first path at ground level
	var first_chunk = main_paths[0][0]
	return Vector2(
		first_chunk.position.x + first_chunk.size.x * 0.1,  # 10% into the first chunk
		first_chunk.position.y + first_chunk.size.y - 100  # Ground level with offset
	) 
