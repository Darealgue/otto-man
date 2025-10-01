extends "res://village/scripts/CloudManager.gd"

func _enter_tree() -> void:
	# Ensure required export fields are populated before base _ready runs
	if not cloud_scene:
		cloud_scene = load("res://village/scenes/cloud.tscn")
	if cloud_textures.is_empty():
		var arr: Array[Texture2D] = []
		for p in [
			"res://village/assets/clouds/cloud1.png",
			"res://village/assets/clouds/cloud2.png",
			"res://village/assets/clouds/cloud3.png",
			"res://village/assets/clouds/cloud4.png",
			"res://village/assets/clouds/cloud5.png",
			"res://village/assets/clouds/cloud6.png",
			"res://village/assets/clouds/cloud7.png",
			"res://village/assets/clouds/cloud8.png"
		]:
			var t := load(p)
			if t and t is Texture2D:
				arr.append(t)
		cloud_textures = arr
	if parallax_layer_paths.is_empty():
		parallax_layer_paths = [
			NodePath("../ParallaxBackground/ParallaxLayerFar"),
			NodePath("../ParallaxBackground/ParallaxLayerMid"),
			NodePath("../ParallaxBackground/ParallaxLayerNear")
		]
	# Reasonable defaults for forest
	if min_spawn_interval <= 0.0:
		min_spawn_interval = 4.0
	if max_spawn_interval <= 0.0:
		max_spawn_interval = 8.0
	# Ensure frequent spawns in forest
	cloud_spawn_chance = 1.0
	# Spawn band near top of the screen; keep if not provided by caller
	if cloud_y_position_max <= cloud_y_position_min:
		cloud_y_position_min = 200.0
		cloud_y_position_max = 320.0

func _spawn_cloud() -> void:
	if _parallax_layers.is_empty() or not cloud_scene or cloud_textures.is_empty():
		# Try refreshing parallax layers once in case they were not ready at _ready
		_parallax_layers.clear()
		for path in parallax_layer_paths:
			var layer = get_node_or_null(path)
			if layer is ParallaxLayer:
				_parallax_layers.append(layer)
		if _parallax_layers.is_empty() or not cloud_scene or cloud_textures.is_empty():
			printerr("CloudManager: Cannot spawn cloud, essential resources missing.")
			return

	var target_layer: ParallaxLayer = _parallax_layers.pick_random()
	if not is_instance_valid(target_layer):
		printerr("CloudManager: Picked ParallaxLayer is not valid.")
		return

	var new_cloud_instance = cloud_scene.instantiate()
	if not new_cloud_instance is Node2D:
		printerr("CloudManager: Instanced cloud scene is not a Node2D.")
		queue_free_instance(new_cloud_instance)
		return

	var cloud_sprite_node = new_cloud_instance.get_node_or_null("CloudSprite")
	if not cloud_sprite_node is Sprite2D:
		printerr("CloudManager: 'CloudSprite' node not found or not a Sprite2D in the instanced cloud scene.")
		queue_free_instance(new_cloud_instance)
		return
	var cloud_sprite: Sprite2D = cloud_sprite_node

	cloud_sprite.texture = cloud_textures.pick_random()
	if randi() % 2 == 0:
		cloud_sprite.flip_h = true
	else:
		cloud_sprite.flip_h = false

	var move_left = false
	if allow_left_moving_clouds and allow_right_moving_clouds:
		move_left = randi() % 2 == 0
	elif allow_left_moving_clouds:
		move_left = true
	elif allow_right_moving_clouds:
		move_left = false
	else:
		printerr("CloudManager: No cloud movement direction allowed (check allow_left/right_moving_clouds).")
		queue_free_instance(new_cloud_instance)
		return

	if new_cloud_instance.has_method("set_movement_direction"):
		new_cloud_instance.set_movement_direction(move_left)
	else:
		new_cloud_instance.set("move_left", move_left)

	# Compute Y relative to current camera center so clouds are on-screen in forest
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var cam := viewport.get_camera_2d()
	var cam_y := 0.0
	if cam and cam is Camera2D:
		cam_y = (cam as Camera2D).global_position.y
	# spawn_y offset within top strip
	# Keep clouds near top regardless of player vertical movement
	var spawn_y = randf_range(cloud_y_position_min, cloud_y_position_max)
	# Force clouds high: offset from camera top + extra 700px
	var world_y = cam_y - (viewport_size.y * 0.5) + spawn_y - 400.0
	# Damp vertical parallax by anchoring to viewport top instead of following chunks closely

	var sprite_width = (cloud_sprite.texture.get_width() if cloud_sprite.texture else 256.0) * max(cloud_sprite.scale.x, 1.0)
	var off_screen_offset = sprite_width * 0.5 + 100.0

	# Add to layer first so setting global_position works in world-space
	target_layer.add_child(new_cloud_instance)

	# Place cloud relative to current camera view edges so it starts just off-screen
	var cam_x: float = 0.0
	if cam and cam is Camera2D:
		cam_x = (cam as Camera2D).global_position.x
	var left_world_x: float = cam_x - (viewport_size.x * 0.5)
	var right_world_x: float = cam_x + (viewport_size.x * 0.5)
	var spawn_world_x: float = (right_world_x + off_screen_offset) if move_left else (left_world_x - off_screen_offset)
	new_cloud_instance.global_position = Vector2(spawn_world_x, world_y)
