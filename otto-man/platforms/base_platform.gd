@tool
extends StaticBody2D
class_name BasePlatform

# Core properties
@export var platform_size: Vector2 = Vector2(192, 32)
@export var platform_color: Color = Color(0.5, 0.5, 0.5, 1.0)

# References
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
	if not Engine.is_editor_hint():
		_initialize_platform()
	else:
		_update_editor_display()

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