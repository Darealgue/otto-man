extends Node2D
class_name BaseRoom

signal room_started
signal room_completed
signal enemy_spawned(enemy: Node)
signal enemy_defeated(enemy: Node)

@export var spawn_points: Array[Node2D]
@export var entrance_position: Node2D
@export var exit_position: Node2D
@export var next_room_path: String

var is_room_active := false
var is_room_cleared := false
var active_enemies: Array[Node] = []
var room_barriers: Array[StaticBody2D] = []

func _ready() -> void:
	# Register with RoomManager
	RoomManager.register_room(self)
	
	# Connect to necessary signals
	for spawn in spawn_points:
		if spawn.has_node("EnemyDetector"):
			var detector = spawn.get_node("EnemyDetector")
			detector.body_entered.connect(_on_enemy_detector_entered)
			detector.body_exited.connect(_on_enemy_detector_exited)
			
	# Connect exit area if it exists
	if exit_position and exit_position.has_node("ExitArea"):
		var exit_area = exit_position.get_node("ExitArea")
		exit_area.body_entered.connect(_on_exit_area_entered)

func _on_exit_area_entered(body: Node) -> void:
	if body.is_in_group("player") and is_room_cleared and next_room_path:
		RoomManager.transition_to_room(next_room_path)

func start_room() -> void:
	if is_room_active:
		return
		
	is_room_active = true
	is_room_cleared = false
	room_started.emit()
	
	# Seal the room
	_seal_room()
	
	# Start spawning enemies
	spawn_initial_enemies()

func _seal_room() -> void:
	# Override in child classes to implement room sealing
	pass

func _unseal_room() -> void:
	# Override in child classes to implement room unsealing
	pass

func spawn_initial_enemies() -> void:
	# Override in specific room implementations
	pass

func _on_enemy_detector_entered(body: Node) -> void:
	if body.is_in_group("enemies") and not active_enemies.has(body):
		active_enemies.append(body)
		enemy_spawned.emit(body)
		
		# Connect to enemy death signal
		if body.has_signal("enemy_defeated"):
			if not body.enemy_defeated.is_connected(_on_enemy_defeated):
				body.enemy_defeated.connect(_on_enemy_defeated)

func _on_enemy_detector_exited(body: Node) -> void:
	if body.is_in_group("enemies"):
		active_enemies.erase(body)

func _on_enemy_defeated(enemy: Node) -> void:
	active_enemies.erase(enemy)
	enemy_defeated.emit(enemy)
	
	# Check if room is cleared
	if active_enemies.is_empty() and is_room_active and not is_room_cleared:
		complete_room()

func complete_room() -> void:
	if is_room_cleared:
		return
		
	is_room_cleared = true
	is_room_active = false
	_unseal_room()
	room_completed.emit()
	
	# Mark room as completed in RoomManager
	RoomManager.mark_room_completed(scene_file_path)

func cleanup() -> void:
	# Clean up enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
	# Clean up barriers
	_unseal_room()
	
	# Reset state
	is_room_active = false
	is_room_cleared = false 
