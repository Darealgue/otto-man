extends Node2D
class_name CityLevelGenerator

signal level_started
signal level_completed

@export var current_level: int = 1
@export var chunk_spacing: float = 0.0  # Space between chunks

var active_chunks: Array[LinearChunk] = []
var current_chunk_index: int = 0
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
	_spawn_initial_chunks()
	
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

func _spawn_initial_chunks() -> void:
	# Clear any existing chunks
	for chunk in active_chunks:
		chunk.queue_free()
	active_chunks.clear()
	
	# Create initial sequence of chunks
	var sequence = ["poor", "middle", "rich"]  # Test sequence
	var current_x = 0.0
	
	print("[CityLevelGenerator] Spawning initial chunks...")
	print("  Sequence:", sequence)
	print("  Available chunk types:", chunk_scenes.keys())
	
	for chunk_type in sequence:
		print("  Attempting to spawn chunk:", chunk_type)
		var chunk = _spawn_chunk(chunk_type)
		if chunk:
			chunk.position.x = current_x
			active_chunks.append(chunk)
			print("[CityLevelGenerator] Successfully spawned chunk:", chunk_type)
			print("  - Position:", chunk.position)
			print("  - Size:", chunk.size)
			current_x += chunk.size.x + chunk_spacing
		else:
			push_error("[CityLevelGenerator] Failed to spawn chunk:", chunk_type)

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
	for chunk in active_chunks:
		var chunk_start = chunk.global_position.x
		var chunk_end = chunk_start + chunk.size.x
		var player_x = player.global_position.x
		
		# Simple visibility toggling based on distance
		chunk.visible = abs(player_x - (chunk_start + chunk.size.x * 0.5)) < chunk.size.x * 2  # Show within two chunk distances

func get_spawn_position() -> Vector2:
	if active_chunks.is_empty():
		return Vector2.ZERO
	
	# Return the center of the first chunk at ground level
	var first_chunk = active_chunks[0]
	return Vector2(
		first_chunk.position.x + first_chunk.size.x * 0.1,  # 10% into the first chunk
		first_chunk.position.y + first_chunk.size.y - 100  # Ground level with offset
	) 