extends Node

signal room_transition_started(from_room: BaseRoom, to_room: BaseRoom)
signal room_transition_completed(new_room: BaseRoom)

var current_room: BaseRoom
var completed_rooms: Array[String] = []
var player: CharacterBody2D

func register_player(p: CharacterBody2D) -> void:
	player = p
	
func register_room(room: BaseRoom) -> void:
	if current_room == null:
		current_room = room
		
func transition_to_room(next_room_path: String) -> void:
	if not player or not current_room:
		push_error("Cannot transition: missing player or current room")
		return
		
	# Load next room
	var next_room_scene = load(next_room_path)
	if not next_room_scene:
		push_error("Failed to load room: " + next_room_path)
		return
		
	var next_room = next_room_scene.instantiate()
	if not next_room is BaseRoom:
		push_error("Scene is not a BaseRoom: " + next_room_path)
		next_room.queue_free()
		return
		
	# Emit transition started
	room_transition_started.emit(current_room, next_room)
	
	# Get current room's parent
	var room_parent = current_room.get_parent()
	
	# Move player to entrance of new room
	player.global_position = next_room.entrance_position.global_position
	
	# Remove old room
	room_parent.remove_child(current_room)
	current_room.queue_free()
	
	# Add new room
	room_parent.add_child(next_room)
	current_room = next_room
	
	# Register room completion
	if not completed_rooms.has(next_room_path):
		completed_rooms.append(next_room_path)
	
	# Emit transition completed
	room_transition_completed.emit(next_room)
	
func mark_room_completed(room_path: String) -> void:
	if not completed_rooms.has(room_path):
		completed_rooms.append(room_path)
		
func is_room_completed(room_path: String) -> bool:
	return completed_rooms.has(room_path) 
