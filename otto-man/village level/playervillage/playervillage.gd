extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D

const SPEED = 100.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0

enum Direction { RIGHT, LEFT, BACK, FRONT }
var current_direction = Direction.FRONT

func _physics_process(delta: float) -> void:
	# Get input direction
	var input_direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	).normalized()
	
	# Handle movement with acceleration and friction
	if input_direction != Vector2.ZERO:
		# Accelerate in input direction
		velocity = velocity.move_toward(input_direction * SPEED, ACCELERATION * delta)
		
		# Update direction based on movement
		if abs(input_direction.x) > abs(input_direction.y):
			# Horizontal movement is dominant
			if input_direction.x > 0:
				current_direction = Direction.RIGHT
				animated_sprite_2d.play("walk_right")
			else:
				current_direction = Direction.LEFT
				animated_sprite_2d.play("walk_left")
		else:
			# Vertical movement is dominant
			if input_direction.y < 0:
				current_direction = Direction.BACK
				animated_sprite_2d.play("walk_back")
			else:
				current_direction = Direction.FRONT
				animated_sprite_2d.play("walk")
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		
		# Play appropriate idle animation based on direction
		match current_direction:
			Direction.RIGHT:
				animated_sprite_2d.play("idle_right")
			Direction.LEFT:
				animated_sprite_2d.play("idle_left")
			Direction.BACK:
				animated_sprite_2d.play("idle_back")
			Direction.FRONT:
				animated_sprite_2d.play("idle")
	
	move_and_slide()
