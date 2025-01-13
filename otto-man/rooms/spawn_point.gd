extends Node2D
class_name SpawnPoint

@onready var enemy_detector = $EnemyDetector

func _ready() -> void:
    # Ensure we have the detector
    if !enemy_detector:
        push_error("SpawnPoint missing EnemyDetector!")
        
    # Make the marker visible in editor but hidden in game
    if has_node("Marker"):
        var marker = get_node("Marker")
        marker.visible = Engine.is_editor_hint()

func is_spawn_clear() -> bool:
    # Check if there are any enemies in the spawn area
    return !enemy_detector or enemy_detector.get_overlapping_bodies().is_empty() 