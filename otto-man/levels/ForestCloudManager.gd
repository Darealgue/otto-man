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

func _ready() -> void:
	# Base CloudManager._ready() çağrılır ve _spawn_initial_clouds() otomatik çağrılır
	# Ama parallax layer'lar hazır olmayabilir, bu yüzden bir frame bekleyip tekrar dene
	super._ready()
	# Parallax layer'lar hazır olmayabilir, bir frame bekleyip başlangıç bulutlarını spawn et
	call_deferred("_ensure_initial_clouds")

func _ensure_initial_clouds() -> void:
	# Eğer başlangıç bulutları spawn olmadıysa (parallax layer'lar hazır değildi), tekrar dene
	if _parallax_layers.is_empty():
		# Parallax layer'ları tekrar kontrol et
		_parallax_layers.clear()
		for path in parallax_layer_paths:
			var layer = get_node_or_null(path)
			if layer is ParallaxLayer:
				_parallax_layers.append(layer)
	
	# Eğer hala layer'lar yoksa, bir kez daha dene (scene tree tam hazır olmayabilir)
	if _parallax_layers.is_empty():
		await get_tree().process_frame
		_parallax_layers.clear()
		for path in parallax_layer_paths:
			var layer = get_node_or_null(path)
			if layer is ParallaxLayer:
				_parallax_layers.append(layer)
	
	# Şimdi başlangıç bulutlarını spawn et (eğer daha önce spawn olmadıysa)
	if not _parallax_layers.is_empty() and WeatherManager:
		_spawn_initial_clouds()
		print("[ForestCloudManager] Initial clouds spawned: ", _parallax_layers.size(), " layers available")

func _spawn_cloud() -> void:
	print("[ForestCloudManager] _spawn_cloud() called")
	if _parallax_layers.is_empty() or not cloud_scene or cloud_textures.is_empty():
		print("[ForestCloudManager] Resources missing, refreshing...")
		# Try refreshing parallax layers once in case they were not ready at _ready
		_parallax_layers.clear()
		for path in parallax_layer_paths:
			var layer = get_node_or_null(path)
			if layer is ParallaxLayer:
				_parallax_layers.append(layer)
				print("[ForestCloudManager] Found layer: ", layer.name, " at path: ", path)
		if _parallax_layers.is_empty() or not cloud_scene or cloud_textures.is_empty():
			printerr("[ForestCloudManager] Cannot spawn cloud, essential resources missing. Layers: ", _parallax_layers.size(), " Scene: ", cloud_scene != null, " Textures: ", cloud_textures.size())
			return

	var target_layer: ParallaxLayer = _parallax_layers.pick_random()
	if not is_instance_valid(target_layer):
		printerr("[ForestCloudManager] Picked ParallaxLayer is not valid.")
		return
	print("[ForestCloudManager] Selected layer: ", target_layer.name)

	var new_cloud_instance = cloud_scene.instantiate()
	if not new_cloud_instance is Node2D:
		printerr("[ForestCloudManager] Instanced cloud scene is not a Node2D.")
		queue_free_instance(new_cloud_instance)
		return

	var cloud_sprite_node = new_cloud_instance.get_node_or_null("CloudSprite")
	if not cloud_sprite_node is Sprite2D:
		printerr("[ForestCloudManager] 'CloudSprite' node not found or not a Sprite2D in the instanced cloud scene.")
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
		printerr("[ForestCloudManager] No cloud movement direction allowed (check allow_left/right_moving_clouds).")
		queue_free_instance(new_cloud_instance)
		return

	if new_cloud_instance.has_method("set_movement_direction"):
		new_cloud_instance.set_movement_direction(move_left)
	else:
		new_cloud_instance.set("move_left", move_left)

	# Forest için hızı ayarla (kendi hızıyla gitmeli ama çok hızlı olmamalı)
	if new_cloud_instance.has_method("set"):
		new_cloud_instance.set("speed_min", 10.0)
		new_cloud_instance.set("speed_max", 25.0)
		new_cloud_instance.set("fade_in_duration", 1.0)

	# Compute position relative to SCREEN (Viewport), ignoring world coordinates/player height
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	print("[ForestCloudManager] Viewport size: ", viewport_size)
	
	# Add to layer first so we can set local position
	target_layer.add_child(new_cloud_instance)
	print("[ForestCloudManager] Cloud added to layer: ", target_layer.name)

	# Use Village approach: direct screen coordinates when motion_scale.x = 0
	# Convert negative Y offsets to positive offsets from top of screen
	var spawn_y_offset_raw = randf_range(cloud_y_position_min, cloud_y_position_max)
	var spawn_y = abs(spawn_y_offset_raw) - 100.0  # Convert -275 to -175 range to 175 to 275 range, then move 100px up
	print("[ForestCloudManager] Y calculation: min=", cloud_y_position_min, " max=", cloud_y_position_max, " raw_offset=", spawn_y_offset_raw, " spawn_y=", spawn_y)

	# Adjust offscreen offset for scaled sprite width
	var sprite_width = (cloud_sprite.texture.get_width() if cloud_sprite.texture else 256.0) * max(new_cloud_instance.scale.x, 1.0)
	var off_screen_offset = sprite_width * 0.6 
	print("[ForestCloudManager] Sprite width: ", sprite_width, " off_screen_offset: ", off_screen_offset)

	# Use direct screen coordinates like Village does (motion_scale.x = 0 means fixed to screen)
	var left_screen_x = -200.0  # Extended 200px to the left
	var right_screen_x = viewport_size.x
	
	var spawn_x: float
	if move_left:  # Spawns on the right, moves left
		spawn_x = right_screen_x + off_screen_offset
	else:  # Spawns on the left, moves right
		spawn_x = left_screen_x - off_screen_offset
	print("[ForestCloudManager] X calculation: left=", left_screen_x, " right=", right_screen_x, " spawn_x=", spawn_x, " move_left=", move_left)
	
	# Set position using direct screen coordinates (like Village does)
	new_cloud_instance.position = Vector2(spawn_x, spawn_y)
	
	# Debug: Check cloud visibility and position (after being added to scene tree)
	var global_pos = new_cloud_instance.global_position
	var screen_pos = new_cloud_instance.get_global_transform_with_canvas().origin if new_cloud_instance.is_inside_tree() else Vector2.ZERO
	var is_visible = new_cloud_instance.visible
	var modulate_val = cloud_sprite.modulate if cloud_sprite else Color.WHITE
	
	print("[ForestCloudManager] ✅ Cloud spawned at LOCAL position: ", new_cloud_instance.position, " on layer: ", target_layer.name)
	print("[ForestCloudManager] 🌍 Cloud GLOBAL position: ", global_pos)
	print("[ForestCloudManager] 📺 Cloud SCREEN position: ", screen_pos)
	print("[ForestCloudManager] 👁️ Cloud visible: ", is_visible, " modulate: ", modulate_val)
	print("[ForestCloudManager] 📏 Layer motion_scale: ", target_layer.motion_scale, " layer position: ", target_layer.position, " layer global_pos: ", target_layer.global_position)
	print("[ForestCloudManager] 🎨 Cloud sprite scale: ", cloud_sprite.scale, " cloud instance scale: ", new_cloud_instance.scale)
	print("[ForestCloudManager] 🔍 Viewport visible rect: ", viewport.get_visible_rect())
	
	# Deferred debug check after one frame
	call_deferred("_debug_cloud_after_frame", new_cloud_instance.get_path())

func _debug_cloud_after_frame(cloud_path: NodePath) -> void:
	var cloud = get_node_or_null(cloud_path)
	if not cloud:
		print("[ForestCloudManager] ⚠️ Cloud not found at path: ", cloud_path)
		return
	
	var cloud_sprite = cloud.get_node_or_null("CloudSprite")
	if not cloud_sprite:
		print("[ForestCloudManager] ⚠️ CloudSprite not found in cloud")
		return
	
	var global_pos = cloud.global_position
	var screen_pos = cloud.get_global_transform_with_canvas().origin
	var viewport = get_viewport()
	var viewport_rect = viewport.get_visible_rect()
	var is_on_screen = viewport_rect.has_point(screen_pos) or viewport_rect.intersects(Rect2(screen_pos - Vector2(100, 100), Vector2(200, 200)))
	
	print("[ForestCloudManager] 🔍 [AFTER FRAME] Cloud at path: ", cloud_path)
	print("[ForestCloudManager] 🌍 Global pos: ", global_pos, " Screen pos: ", screen_pos)
	print("[ForestCloudManager] 📺 Viewport rect: ", viewport_rect, " Is on screen: ", is_on_screen)
	print("[ForestCloudManager] 👁️ Visible: ", cloud.visible, " Modulate: ", cloud_sprite.modulate if cloud_sprite else "N/A")
	print("[ForestCloudManager] 📏 Parent layer: ", cloud.get_parent().name if cloud.get_parent() else "N/A")
