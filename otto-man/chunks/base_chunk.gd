@tool
extends Node2D
class_name BaseChunk

const ChunkTypeScript = preload("res://resources/chunks/chunk_type.gd")

# Core properties
@export var chunk_name: String = ""
@export var scene_path: String = ""
@export var can_spawn_enemies: bool = true
@export var min_enemies: int = 2
@export var max_enemies: int = 4
@export var allowed_enemy_types: Array[String] = []
@export var enemy_spawn_points: Array[Vector2] = []
@export var guaranteed_powerup: bool = false
@export var chunk_type: ChunkType
@export var debug_enabled: bool = false

# References
@onready var spawn_points: Array[Node] = []
@onready var connection_points: Dictionary = {}

# Runtime properties
var is_chunk_active: bool = false
var active_enemies: Array[Node] = []
var is_chunk_cleared: bool = false
var current_difficulty: int = 1
var used_spawn_points: Array[Node] = []

# Signals
signal chunk_activated
signal chunk_cleared
signal enemy_spawned(enemy: Node)
signal enemy_defeated(enemy: Node)

func _ready() -> void:
	print("[BaseChunk] Ready called on: ", name)
	if not Engine.is_editor_hint():
		# Setup in game
		_initialize_chunk()
	else:
		# Setup in editor
		_setup_editor_display()
	
	if debug_enabled:
		print("[BaseChunk] Initializing chunk: ", chunk_name)

func _initialize_chunk() -> void:
	print("[BaseChunk] Initializing chunk: ", name)
	if not chunk_type:
		push_error("[BaseChunk] Chunk missing ChunkType resource!")
		return
		
	print("[BaseChunk] Chunk type: ", chunk_type.chunk_name, " Category: ", chunk_type.category)
	
	# Collect spawn points only from this chunk
	var spawn_points_node = get_node_or_null("SpawnPoints")
	if spawn_points_node:
		spawn_points = spawn_points_node.get_children()
		print("[BaseChunk] Found spawn points in chunk: ", spawn_points.size())
	else:
		push_error("[BaseChunk] No SpawnPoints node found in chunk!")
	
	# Setup connection points
	_setup_connection_points()
	
	# Connect to area triggers
	var triggers = get_tree().get_nodes_in_group("chunk_triggers")
	print("[BaseChunk] Found triggers: ", triggers.size())
	for trigger in triggers:
		if trigger is Area2D:
			trigger.body_entered.connect(_on_trigger_area_entered)

func _setup_connection_points() -> void:
	# Find all connection point nodes
	for connection in chunk_type.connections:
		var point_name = ChunkTypeScript.ConnectionType.keys()[connection].to_lower()
		var point = get_node_or_null("ConnectionPoints/" + point_name)
		if point:
			connection_points[connection] = point

func activate_chunk() -> void:
	print("[BaseChunk] Activating chunk: ", name)
	if is_chunk_active:
		print("[BaseChunk] Chunk already active")
		return
		
	is_chunk_active = true
	
	# Clean up any invalid enemies first
	cleanup_dead_enemies()
	
	# Wake up all enemies in the chunk
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("wake_up"):
			enemy.wake_up()
	
	# Only spawn enemies if this is a combat chunk and we haven't cleared it yet
	if chunk_type and chunk_type.category == ChunkTypeScript.ChunkCategory.COMBAT and not is_chunk_cleared:
		print("[BaseChunk] This is a combat chunk, spawning enemies")
		_spawn_enemies()
	else:
		print("[BaseChunk] Not spawning enemies - chunk is cleared or not combat type")
	
	chunk_activated.emit()
	
	if debug_enabled:
		print("[BaseChunk] Activated chunk: ", chunk_name)

func deactivate_chunk() -> void:
	if !is_chunk_active:
		return
		
	is_chunk_active = false
	
	# Clean up any invalid enemies first
	cleanup_dead_enemies()
	
	# Put all enemies to sleep
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("go_to_sleep"):
			enemy.go_to_sleep()
			
	if debug_enabled:
		print("[BaseChunk] Deactivated chunk: ", chunk_name)

func _spawn_enemies() -> void:
	if not chunk_type or not chunk_type.can_spawn_enemies:
		print("[BaseChunk] Chunk cannot spawn enemies")
		return
		
	# Get number of enemies to spawn
	var num_enemies = randi_range(chunk_type.min_enemies, chunk_type.max_enemies)
	print("[BaseChunk] Attempting to spawn ", num_enemies, " enemies")
	
	# Limit number of enemies to available spawn points
	num_enemies = mini(num_enemies, spawn_points.size())
	
	# Try to spawn enemies at valid points
	var spawned_count = 0
	while spawned_count < num_enemies:
		var spawn_point = _get_valid_spawn_point()
		if not spawn_point:
			break
			
		_spawn_enemy(spawn_point)
		spawned_count += 1
		
	print("[BaseChunk] Successfully spawned ", spawned_count, " enemies")

func _spawn_enemy(spawn_point: Node2D) -> void:
	if not chunk_type or not chunk_type.can_spawn_enemies or chunk_type.allowed_enemy_types.is_empty():
		print("[BaseChunk] Cannot spawn enemy - invalid chunk type configuration")
		return
		
	var enemy_scene_path = chunk_type.allowed_enemy_types.pick_random()
	print("[BaseChunk] Attempting to spawn enemy from path: ", enemy_scene_path)
	# Extract pool name from path (e.g. "res://enemy/flying/flying_enemy.tscn" -> "flying_enemy")
	var pool_name = enemy_scene_path.get_file().get_basename()
	var enemy = ObjectPool.get_object(pool_name)
	if enemy:
		print("[BaseChunk] Successfully got enemy from pool: ", enemy_scene_path)
		add_child(enemy)  # Add enemy to scene tree
		enemy.global_position = spawn_point.global_position
		spawn_point.mark_as_used()  # Mark the spawn point as used
		active_enemies.append(enemy)
		print("[BaseChunk] Spawned enemy at position: ", spawn_point.global_position)
	else:
		push_error("[BaseChunk] Failed to get enemy from pool: ", enemy_scene_path)
		print("[BaseChunk] Available pools: ", ObjectPool.pools.keys())

func _get_valid_spawn_point() -> Node2D:
	var available_points = []
	for point in spawn_points:
		if point.is_spawn_clear():
			available_points.append(point)
	
	if available_points.is_empty():
		print("[BaseChunk] No valid spawn points available")
		return null
		
	return available_points.pick_random()

func _on_enemy_defeated(enemy: Node) -> void:
	if is_instance_valid(enemy):
		active_enemies.erase(enemy)
		enemy_defeated.emit(enemy)
		
		# Check if chunk is cleared
		cleanup_dead_enemies()  # Clean up before checking if cleared
		if chunk_type.category == ChunkTypeScript.ChunkCategory.COMBAT and active_enemies.is_empty():
			is_chunk_cleared = true
			chunk_cleared.emit()

func _on_trigger_area_entered(body: Node2D) -> void:
	print("[BaseChunk] Trigger entered by: ", body.name)
	if body.is_in_group("player"):
		print("[BaseChunk] Player entered chunk trigger")
		activate_chunk()

func get_connection_point(type: int) -> Node2D:
	return connection_points.get(type)

func _setup_editor_display() -> void:
	# Visual helpers for editor
	if chunk_type:
		# Show connection points
		for connection in chunk_type.connections:
			var point = get_connection_point(connection)
			if point:
				point.visible = true

func get_active_enemy_count() -> int:
	cleanup_dead_enemies()  # Clean up before returning count
	return active_enemies.size()

func cleanup_dead_enemies() -> void:
	var valid_enemies: Array[Node] = []
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("get_behavior"):
			continue
		if enemy.get_behavior() == "dead":
			continue
		valid_enemies.append(enemy)
	active_enemies = valid_enemies
 
