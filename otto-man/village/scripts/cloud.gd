extends Node2D

@export var speed_min: float = 20.0
@export var speed_max: float = 50.0
@export var fade_in_duration: float = 2.5
@export var fade_out_duration: float = 2.5

# If true, cloud moves from right to left (spawns on the right).
# If false, cloud moves from left to right (spawns on the left).
@export var move_left: bool = false 

var current_speed: float

# Make sure you have a Sprite2D node named "CloudSprite" as a child of this node in your cloud.tscn
@onready var cloud_sprite: Sprite2D = $CloudSprite 
@onready var viewport_size: Vector2 = get_viewport_rect().size

func _ready() -> void:
	if not cloud_sprite:
		printerr("Cloud.gd: CloudSprite node not found in Cloud scene! Please add a Sprite2D named CloudSprite as a child.")
		queue_free() # Cannot operate without a sprite
		return

	if not cloud_sprite.texture:
		printerr("Cloud.gd: CloudSprite has no texture assigned in the Cloud scene. Please assign a default texture or the CloudManager should assign one.")
		# We can let it continue, as a CloudManager might assign a texture right after instancing.
		# For now, let it be, but visually it will be an empty moving node until texture is set.

	current_speed = randf_range(speed_min, speed_max)
	if move_left:
		current_speed = -abs(current_speed) # Ensure speed is negative
	else:
		current_speed = abs(current_speed)  # Ensure speed is positive

	# Initial state: invisible for fade-in. Preserve original color, only change alpha.
	var original_color = cloud_sprite.modulate
	original_color.a = 0.0
	cloud_sprite.modulate = original_color

	var tween_fade_in = create_tween()
	# Target the original alpha value (presumably 1.0 if fully opaque)
	tween_fade_in.tween_property(cloud_sprite, "modulate:a", 1.0, fade_in_duration).from(0.0)
	tween_fade_in.play()

func _process(delta: float) -> void:
	if not is_instance_valid(cloud_sprite) or not cloud_sprite.texture:
		return # Wait for texture or if sprite is somehow gone

	position.x += current_speed * delta

	# Check for despawn when off-screen
	# The CloudManager will eventually handle spawning positions and more robust despawning.
	# This is a basic self-cleanup.
	var sprite_actual_width = cloud_sprite.texture.get_width() * cloud_sprite.scale.x
	var global_sprite_left_edge = global_position.x - sprite_actual_width * cloud_sprite.get_rect().size.x * cloud_sprite.offset.x
	var global_sprite_right_edge = global_sprite_left_edge + sprite_actual_width

	var off_screen_buffer = 100.0 # pixels

	if current_speed > 0: # Moving right
		if global_sprite_left_edge > viewport_size.x + off_screen_buffer:
			# print("Cloud off-screen right, removing: ", name)
			queue_free()
	elif current_speed < 0: # Moving left
		if global_sprite_right_edge < -off_screen_buffer:
			# print("Cloud off-screen left, removing: ", name)
			queue_free()

# This function can be called by a CloudManager to gracefully remove the cloud
func initiate_fade_out_and_remove() -> void:
	if not is_instance_valid(cloud_sprite):
		queue_free() # Can't fade if no sprite
		return

	# If already transparent or nearly transparent, just remove
	if cloud_sprite.modulate.a < 0.01:
		queue_free()
		return

	var tween_fade_out = create_tween().set_parallel(false) # Ensure sequence
	tween_fade_out.tween_property(cloud_sprite, "modulate:a", 0.0, fade_out_duration)
	tween_fade_out.tween_callback(queue_free)
	tween_fade_out.play()

# The CloudManager will be responsible for setting the actual cloud texture
# from your 8 PNGs when it instances this scene.
# You can add a helper function here if needed, e.g.:
# func set_texture(new_texture: Texture2D) -> void:
#    if cloud_sprite:
#        cloud_sprite.texture = new_texture

func _exit_tree() -> void:
	# Clean up any running tweens if the node is removed prematurely
	# Godot's tweens are usually good about this, but explicit cleanup can be safe.
	var tweens = get_tree().get_nodes_in_group("tweens") # Default group for SceneTreeTween
	for t in tweens:
		if t is Tween and t.is_valid() and t.get_parent() == self: # Check if tween belongs to this node
			t.kill()
