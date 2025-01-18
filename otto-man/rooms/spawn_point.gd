extends Node2D
class_name SpawnPoint

@onready var enemy_detector = $EnemyDetector
var has_spawned: bool = false  # Track if this spawn point has already been used

func _ready() -> void:
	# Ensure we have the detector
	if !enemy_detector:
		push_error("SpawnPoint missing EnemyDetector!")
		return
		
	
	# Make the marker visible in editor but hidden in game
	if has_node("Marker"):
		var marker = get_node("Marker")
		marker.visible = Engine.is_editor_hint()

func is_spawn_clear() -> bool:
	# If we've already spawned, this point is no longer valid
	if has_spawned:
		return false
		
	if !enemy_detector:
		return false
		
	var overlapping = enemy_detector.get_overlapping_bodies()
	
	return overlapping.is_empty()

func mark_as_used() -> void:
	has_spawned = true 
