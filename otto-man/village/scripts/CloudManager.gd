extends Node

# SCENE AND TEXTURES
## The packed scene for individual clouds (cloud.tscn)
@export var cloud_scene: PackedScene
## Array to hold your different cloud textures (PNGs)
## You can drag and drop your 8 cloud PNG files here in the Godot Editor.
@export var cloud_textures: Array[Texture2D] = []

# PARALLAX LAYERS
## NodePaths to the ParallaxLayer nodes in your VillageScene.tscn
## You will need to create these ParallaxLayer nodes as children of your ParallaxBackground
## and then assign their paths here in the Godot Editor.
## Example: @export var parallax_layer_paths: Array[NodePath] = [&"../ParallaxLayer1", &"../ParallaxLayer2"]
@export var parallax_layer_paths: Array[NodePath] = []

# SPAWNING PARAMETERS
## Minimum time (seconds) between cloud spawn attempts
@export var min_spawn_interval: float = 3.0
## Maximum time (seconds) between cloud spawn attempts
@export var max_spawn_interval: float = 8.0
## Chance (0.0 to 1.0) to actually spawn a cloud when the timer triggers
## This helps create days with fewer or no clouds.
@export var cloud_spawn_chance: float = 0.75
## Minimum Y position for spawning clouds (relative to viewport top)
@export var cloud_y_position_min: float = 50.0
## Maximum Y position for spawning clouds (relative to viewport top, or a bit above for variety)
@export var cloud_y_position_max: float = 200.0
## If true, clouds can spawn moving left. If false, they only spawn moving right.
## You might want different managers or logic for different directions, or randomize this.
@export var allow_left_moving_clouds: bool = true
## If true, clouds can spawn moving right.
@export var allow_right_moving_clouds: bool = true


# INTERNAL VARIABLES
var _parallax_layers: Array[Node] = []
var _spawn_timer: Timer
var _viewport_width: float = 0.0


func _ready() -> void:
	if not cloud_scene:
		printerr("CloudManager: Cloud Scene not set. Please assign your cloud.tscn to the 'Cloud Scene' export variable.")
		set_process(false) # Disable processing
		return

	if cloud_textures.is_empty():
		printerr("CloudManager: Cloud Textures array is empty. Please add your cloud PNGs to the 'Cloud Textures' export variable.")
		set_process(false)
		return

	if parallax_layer_paths.is_empty():
		printerr("CloudManager: Parallax Layer Paths array is empty. Please create ParallaxLayer nodes and assign their paths.")
		set_process(false)
		return

	# Get actual ParallaxLayer nodes
	for path in parallax_layer_paths:
		var layer = get_node_or_null(path)
		if layer is ParallaxLayer:
			_parallax_layers.append(layer)
		else:
			printerr("CloudManager: Node at path '", path, "' is not a ParallaxLayer or not found.")
	
	if _parallax_layers.is_empty():
		printerr("CloudManager: No valid ParallaxLayer nodes were found. Cloud spawning will not work.")
		set_process(false)
		return
		
	_viewport_width = get_viewport().get_visible_rect().size.x

	# Setup spawn timer
	_spawn_timer = Timer.new()
	# Keep ticking regardless of parent pause/state
	_spawn_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_timer.wait_time = randf_range(min_spawn_interval, max_spawn_interval)
	_spawn_timer.one_shot = false # Keep repeating
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_spawn_timer.start()

	# Initial spawn attempt to not wait for the first timer cycle
	_on_spawn_timer_timeout()


func _on_spawn_timer_timeout() -> void:
	# Reset timer for next interval
	if is_instance_valid(_spawn_timer):
		_spawn_timer.wait_time = randf_range(min_spawn_interval, max_spawn_interval)

	if randf() > cloud_spawn_chance:
		# print("CloudManager: Skipped spawning cloud due to chance.")
		return

	_spawn_cloud()


func _spawn_cloud() -> void:
	if _parallax_layers.is_empty() or not cloud_scene or cloud_textures.is_empty():
		printerr("CloudManager: Cannot spawn cloud, essential resources missing.")
		return

	# 1. Choose a ParallaxLayer
	var target_layer: ParallaxLayer = _parallax_layers.pick_random()
	if not is_instance_valid(target_layer):
		printerr("CloudManager: Picked ParallaxLayer is not valid.")
		return

	# 2. Instance the cloud scene
	var new_cloud_instance = cloud_scene.instantiate()
	if not new_cloud_instance is Node2D: # Assuming cloud.tscn root is Node2D or derived
		printerr("CloudManager: Instanced cloud scene is not a Node2D.")
		queue_free_instance(new_cloud_instance) # Helper to safely free
		return

	# 3. Get the CloudSprite from the instanced cloud
	# Make sure your cloud.tscn has a Sprite2D named "CloudSprite"
	var cloud_sprite_node = new_cloud_instance.get_node_or_null("CloudSprite")
	if not cloud_sprite_node is Sprite2D:
		printerr("CloudManager: 'CloudSprite' node not found or not a Sprite2D in the instanced cloud scene.")
		queue_free_instance(new_cloud_instance)
		return
	var cloud_sprite: Sprite2D = cloud_sprite_node

	# 4. Assign a random texture
	cloud_sprite.texture = cloud_textures.pick_random()

	# 4.5. Randomly flip the cloud sprite horizontally for variety
	if randi() % 2 == 0:
		cloud_sprite.flip_h = true
	else:
		cloud_sprite.flip_h = false # Ensure it's reset if not flipped

	# 5. Determine spawn side and set cloud's initial properties
	var move_left = false
	if allow_left_moving_clouds and allow_right_moving_clouds:
		move_left = randi() % 2 == 0 # 50/50 chance
	elif allow_left_moving_clouds:
		move_left = true
	elif allow_right_moving_clouds:
		move_left = false
	else:
		# Neither direction allowed, so don't spawn
		printerr("CloudManager: No cloud movement direction allowed (check allow_left/right_moving_clouds).")
		queue_free_instance(new_cloud_instance)
		return
		
	# Access the script attached to new_cloud_instance (assuming it's cloud.gd)
	if new_cloud_instance.has_method("set_movement_direction"): # Check if a custom setup method exists
		new_cloud_instance.set_movement_direction(move_left)
	elif new_cloud_instance.has_meta("move_left"): # Or try setting exported var directly if no method
		new_cloud_instance.set("move_left", move_left)
	else:
		# Fallback to checking if cloud.gd is directly attached and has the export
		var cloud_script = new_cloud_instance.get_script()
		# This direct set might be tricky if the var isn't @export'ed or script not directly on root
		# For now, we rely on cloud.gd's own _ready() to use its exported 'move_left'
		# but we will need to ensure cloud.gd can be configured
		# The cloud.gd script already has an @export var move_left, which it uses in its _ready()
		# We should set this *before* adding to scene tree if its _ready() depends on it.
		new_cloud_instance.set("move_left", move_left)

	# 7. Add the instanced cloud as a child to the chosen ParallaxLayer
	# The ParallaxLayer will then manage its movement based on its own scroll speed.
	target_layer.add_child(new_cloud_instance)
	
	# 6. Set cloud's initial position (off-screen)
	var spawn_y = randf_range(cloud_y_position_min, cloud_y_position_max)
	var sprite_width = cloud_sprite.texture.get_width() * cloud_sprite.scale.x
	var off_screen_offset = sprite_width + 50

	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	
	# Check if the target layer is fixed to screen (motion_scale.x approx 0)
	if is_zero_approx(target_layer.motion_scale.x):
		# Scale 0 means the layer does not move relative to the camera.
		# It stays fixed in screen space.
		# So we spawn relative to the Viewport rectangle directly (0 to viewport_size.x)
		# Do NOT add camera position.
		var left_screen_x = -200.0 # Extended 200px to the left
		var right_screen_x = viewport_size.x
		
		if move_left: # Spawns on the right, moves left
			new_cloud_instance.position = Vector2(right_screen_x + off_screen_offset, spawn_y)
		else: # Spawns on the left, moves right
			new_cloud_instance.position = Vector2(left_screen_x - off_screen_offset, spawn_y)
	else:
		# Standard Parallax behavior (scale > 0)
		# We calculate world position based on camera
		var cam := viewport.get_camera_2d()
		var cam_x := 0.0
		if cam and cam is Camera2D:
			cam_x = (cam as Camera2D).global_position.x
		var left_world_x = cam_x - (viewport_size.x * 0.5) - 200.0 # Extended 200px to the left
		var right_world_x = cam_x + (viewport_size.x * 0.5)

		if move_left: # Spawns on the right, moves left
			new_cloud_instance.global_position = Vector2(right_world_x + off_screen_offset, spawn_y)
		else: # Spawns on the left, moves right
			new_cloud_instance.global_position = Vector2(left_world_x - off_screen_offset, spawn_y)
	# print("CloudManager: Spawned new cloud '", new_cloud_instance.name, "' on layer '", target_layer.name, "', moving left: ", move_left)

# Helper function to safely free an instance if it's valid
func queue_free_instance(instance: Node) -> void:
	if is_instance_valid(instance):
		instance.queue_free()

# Optional: A function to clear all currently managed clouds
func clear_all_clouds() -> void:
	for layer_path in parallax_layer_paths:
		var layer_node = get_node_or_null(layer_path)
		if layer_node is ParallaxLayer:
			for child in layer_node.get_children():
				# Check if the child is a cloud instance (e.g., by checking its script or name pattern)
				if child.get_script() == preload("res://village/scripts/cloud.gd"): # Adjust path if needed
					# Call fade out on the cloud if it has the method
					if child.has_method("initiate_fade_out_and_remove"):
						child.initiate_fade_out_and_remove()
					else:
						child.queue_free() # Fallback to immediate removal
	# print("CloudManager: Cleared all clouds.") 
 
