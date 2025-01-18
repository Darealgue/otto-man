@tool
extends AnimatableBody2D
class_name MovingPlatform

# Movement properties
@export var movement_type: MovementType = MovementType.HORIZONTAL
@export var movement_speed: float = 100.0
@export var movement_distance: float = 200.0
@export var wait_time: float = 0.5

# Editor properties
@export var platform_size: Vector2 = Vector2(192, 32)
@export var platform_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var show_path: bool = true:
	set(value):
		show_path = value
		queue_redraw()

enum MovementType {
	HORIZONTAL,
	VERTICAL,
	CIRCULAR
}

# Runtime properties
var start_position: Vector2
var target_position: Vector2
var moving_to_target: bool = true
var wait_timer: float = 0.0

# References
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
	if not Engine.is_editor_hint():
		start_position = position
		_calculate_target_position()
		_initialize_platform()
	else:
		_update_editor_display()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if wait_timer > 0:
		wait_timer -= delta
		return
		
	var move_direction = (target_position - position).normalized()
	var distance_to_target = position.distance_to(target_position)
	
	if distance_to_target < 1.0:
		position = target_position
		moving_to_target = !moving_to_target
		wait_timer = wait_time
		_calculate_target_position()
	else:
		# Use move_and_collide for AnimatableBody2D
		var velocity = move_direction * movement_speed
		var collision = move_and_collide(velocity * delta)
		if collision:
			print("Platform collided with: ", collision.get_collider().name)

func _calculate_target_position() -> void:
	match movement_type:
		MovementType.HORIZONTAL:
			target_position = start_position + (Vector2.RIGHT if moving_to_target else Vector2.LEFT) * movement_distance
		MovementType.VERTICAL:
			target_position = start_position + (Vector2.UP if moving_to_target else Vector2.DOWN) * movement_distance
		MovementType.CIRCULAR:
			var angle = PI if moving_to_target else 0
			target_position = start_position + Vector2(cos(angle), sin(angle)) * movement_distance

func _draw() -> void:
	if Engine.is_editor_hint() and show_path:
		match movement_type:
			MovementType.HORIZONTAL:
				draw_line(Vector2(-movement_distance/2, 0), Vector2(movement_distance/2, 0), Color.YELLOW, 2.0)
			MovementType.VERTICAL:
				draw_line(Vector2(0, -movement_distance/2), Vector2(0, movement_distance/2), Color.YELLOW, 2.0)
			MovementType.CIRCULAR:
				draw_arc(Vector2.ZERO, movement_distance/2, 0, PI*2, 32, Color.YELLOW, 2.0)

func _initialize_platform() -> void:
	# Set up collision shape
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
		collision_shape.shape = RectangleShape2D.new()
	
	collision_shape.shape.size = platform_size
	
	# Set up visual display
	if not sprite:
		sprite = ColorRect.new()
		add_child(sprite)
	
	sprite.size = platform_size
	sprite.position = -platform_size / 2
	sprite.color = platform_color

func _update_editor_display() -> void:
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = platform_size
	
	if sprite:
		sprite.size = platform_size
		sprite.position = -platform_size / 2
		sprite.color = platform_color 