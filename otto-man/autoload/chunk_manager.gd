extends Node

signal chunk_loaded(chunk: Node)
signal chunk_unloaded(chunk: Node)
signal difficulty_changed(new_difficulty: int)

var active_chunks: Array[Node] = []
var chunk_activation_distance: float = 2500.0  # Increased from 1500 to 2500
var chunk_deactivation_distance: float = 3500.0  # Increased from 2000 to 3500
var debug_enabled: bool = false
var current_difficulty: int = 1

# Generation settings
var chunk_width: float = 1920.0  # Width of each chunk in pixels
var initial_chunks: int = 4      # Increased from 3 to 4
var current_chunk_x: float = 0.0 # Track current generation position
var chunks_ahead: int = 3        # Increased from 2 to 3
var last_chunk_x: float = 0.0    # Track rightmost chunk position
var last_player_x: float = 0.0   # Track player's last x position to detect direction

func set_difficulty(new_difficulty: int) -> void:
	if new_difficulty != current_difficulty:
		current_difficulty = new_difficulty
		difficulty_changed.emit(current_difficulty)
		if debug_enabled:
			print("[ChunkManager] Difficulty changed to: ", current_difficulty)

func get_spawn_position() -> Vector2:
	# If we have no chunks, return a default position
	if active_chunks.is_empty():
		return Vector2(200, 0)
	
	# Get the first chunk (leftmost)
	var first_chunk = active_chunks.front()
	if not first_chunk:
		return Vector2(200, 0)
	
	# Return a position near the start of the first chunk
	return Vector2(first_chunk.global_position.x + 200, first_chunk.global_position.y + 200)

func start_generation() -> void:
	# Clear any existing chunks
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()
	
	# Reset generation position
	current_chunk_x = 0.0
	
	# Generate initial chunks
	for i in range(initial_chunks):
		generate_next_chunk()
		
	if debug_enabled:
		print("[ChunkManager] Started generation with ", initial_chunks, " chunks")

func generate_next_chunk() -> void:
	# Define available chunk resources
	var available_chunks = [
		"res://resources/chunks/test_platform_chunk.tres",
		"res://chunks/combat_platform_chunk.tscn"
	]
	
	# Randomly select a chunk
	var selected_chunk_path = available_chunks.pick_random()
	var loaded_resource = load(selected_chunk_path)
	if not loaded_resource:
		push_error("[ChunkManager] Failed to load resource: " + selected_chunk_path)
		return
	
	# Get the scene path and chunk type
	var scene_path: String
	var chunk_type = null
	
	if loaded_resource is PackedScene:
		# If it's a direct scene file
		scene_path = selected_chunk_path
	else:
		# If it's a ChunkType resource
		chunk_type = loaded_resource
		scene_path = chunk_type.scene_path
	
	# Instance the chunk scene
	var chunk_scene = load(scene_path)
	if not chunk_scene:
		push_error("[ChunkManager] Failed to load chunk scene: " + scene_path)
		return
		
	var chunk = chunk_scene.instantiate()
	get_tree().current_scene.add_child(chunk)
	
	# Set up the chunk type and ensure enemy spawning is configured
	if chunk_type:  # If we loaded from a ChunkType resource
		chunk.chunk_type = chunk_type
		chunk.min_enemies = chunk_type.min_enemies
		chunk.max_enemies = chunk_type.max_enemies
		chunk.can_spawn_enemies = chunk_type.can_spawn_enemies
		chunk.allowed_enemy_types = chunk_type.allowed_enemy_types.duplicate()
	
	# Ensure spawn points are set up
	var spawn_points_node = chunk.get_node_or_null("SpawnPoints")
	if spawn_points_node:
		chunk.spawn_points = spawn_points_node.get_children()
		if debug_enabled:
			print("[ChunkManager] Found ", chunk.spawn_points.size(), " spawn points in chunk")
	else:
		push_error("[ChunkManager] No SpawnPoints node found in chunk!")
	
	# Position the chunk
	chunk.global_position.x = current_chunk_x
	current_chunk_x += chunk_width
	
	# Register the chunk
	register_chunk(chunk)
	
	if debug_enabled:
		print("[ChunkManager] Generated new chunk at x: ", current_chunk_x)
		print("[ChunkManager] Chunk type: ", scene_path)
		print("[ChunkManager] Enemy settings - Min: ", chunk.min_enemies, " Max: ", chunk.max_enemies)
		print("[ChunkManager] Spawn points: ", chunk.spawn_points.size())

func _process(_delta: float) -> void:
	var player = get_nearest_player()
	if !player:
		return
		
	manage_chunk_states(player)
	check_generate_chunks(player)

func manage_chunk_states(player: Node2D) -> void:
	for chunk in active_chunks:
		if !is_instance_valid(chunk):
			continue
			
		var distance = chunk.global_position.distance_to(player.global_position)
		var moving_left = player.global_position.x < last_player_x
		var activation_threshold = chunk_activation_distance
		if moving_left:
			activation_threshold *= 2.0  # Increased from 1.5 to 2.0 for more generous activation when moving left
		
		# Activate nearby chunks
		if distance <= activation_threshold and !chunk.is_chunk_active:
			chunk.activate_chunk()
			if debug_enabled:
				print("[ChunkManager] Activating chunk at distance: ", distance)
		
		# Deactivate far chunks
		elif distance > chunk_deactivation_distance and chunk.is_chunk_active:
			chunk.deactivate_chunk()
			if debug_enabled:
				print("[ChunkManager] Deactivating chunk at distance: ", distance)
	
	last_player_x = player.global_position.x

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func register_chunk(chunk: Node) -> void:
	if chunk not in active_chunks:
		active_chunks.append(chunk)
		chunk_loaded.emit(chunk)
		
		# Check if chunk should start active
		var player = get_nearest_player()
		if player:
			var distance = chunk.global_position.distance_to(player.global_position)
			if distance <= chunk_activation_distance:
				chunk.activate_chunk()
			else:
				chunk.deactivate_chunk()

func unregister_chunk(chunk: Node) -> void:
	if chunk in active_chunks:
		active_chunks.erase(chunk)
		chunk_unloaded.emit(chunk)

func cleanup_chunks() -> void:
	active_chunks = active_chunks.filter(func(chunk): return is_instance_valid(chunk))
	
	for chunk in active_chunks:
		if chunk.has_method("cleanup_dead_enemies"):
			chunk.cleanup_dead_enemies() 

func check_generate_chunks(player: Node2D) -> void:
	# Find the rightmost chunk
	var rightmost_x = -INF
	for chunk in active_chunks:
		if chunk.global_position.x > rightmost_x:
			rightmost_x = chunk.global_position.x
	
	# If player is getting close to the rightmost chunk, generate more
	var distance_to_end = rightmost_x - player.global_position.x
	if distance_to_end < chunk_width * 2:  # Generate more when within 2 chunks of the end
		if debug_enabled:
			print("[ChunkManager] Player approaching end, generating new chunk")
		generate_next_chunk() 
