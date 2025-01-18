extends CharacterBody2D

@export_enum("Horizontal", "Vertical") var movement_type: int = 0
@export var movement_speed: float = 100.0
@export var movement_distance: float = 200.0

var start_position: Vector2
var target_position: Vector2
var moving_to_target: bool = true
var current_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	start_position = global_position
	if movement_type == 0:  # Horizontal
		target_position = start_position + Vector2(movement_distance, 0)
	else:  # Vertical
		target_position = start_position + Vector2(0, movement_distance)

func _physics_process(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	var distance_to_target = global_position.distance_to(target_position)
	var distance_to_start = global_position.distance_to(start_position)
	
	if moving_to_target and distance_to_target < 1:
		moving_to_target = false
	elif not moving_to_target and distance_to_start < 1:
		moving_to_target = true
		
	var move_target = target_position if moving_to_target else start_position
	direction = (move_target - global_position).normalized()
	
	current_velocity = direction * movement_speed
	set_velocity(current_velocity)
	move_and_slide() 
