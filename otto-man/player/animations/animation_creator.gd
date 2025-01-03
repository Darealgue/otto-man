extends Node

static func create_animations(sprite: AnimatedSprite2D, player: AnimationPlayer) -> void:
	if !sprite or !player:
		push_error("Invalid sprite or animation player!")
		return
		
	# Get sprite frames
	var sprite_frames = sprite.sprite_frames
	if !sprite_frames:
		push_error("No sprite frames found in AnimatedSprite2D!")
		return
	
	# Create animation library
	var library = AnimationLibrary.new()
	
	# Create animations for each sprite animation
	for anim_name in sprite_frames.get_animation_names():
		var animation = Animation.new()
		
		# Create track for sprite frame
		var track_index = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, "%s:frame" % sprite.get_path())
		
		# Get frame count and speed
		var frame_count = sprite_frames.get_frame_count(anim_name)
		var fps = sprite_frames.get_animation_speed(anim_name)
		var duration = frame_count / float(fps) if fps > 0 else 1.0
		
		# Add keyframes
		for i in range(frame_count):
			var time = i * duration / frame_count if frame_count > 0 else 0.0
			animation.track_insert_key(track_index, time, i)
		
		# Set loop mode
		animation.loop_mode = Animation.LOOP_LINEAR if _should_loop(anim_name) else Animation.LOOP_NONE
		
		# Add animation to library
		library.add_animation(anim_name, animation)
	
	# Add library to player
	player.add_animation_library("", library)

static func _should_loop(anim_name: String) -> bool:
	match anim_name:
		"idle", "run", "fall", "block":
			return true
		_:
			return false

static func setup_animation_library(player: AnimationPlayer) -> void:
	if !player:
		push_error("Invalid animation player!")
		return
	
	# Get the default library
	var library = player.get_animation_library("")
	if not library:
		push_error("No default animation library found!")
		return
	
	# Set up animation lengths and transitions
	var animations = {
		"idle": {"length": 1.0, "loop": true},
		"run": {"length": 0.8, "loop": true},
		"jump": {"length": 0.5, "loop": false},
		"double_jump": {"length": 0.5, "loop": false},
		"fall": {"length": 0.5, "loop": true},
		"wall_jump": {"length": 0.5, "loop": false},
		"attack": {"length": 0.4, "loop": false},
		"block": {"length": 0.3, "loop": true},
		"block_impact": {"length": 0.2, "loop": false},
		"dash": {"length": 0.3, "loop": false}
	}
	
	# Update animation properties
	for anim_name in animations.keys():
		var anim = library.get_animation(anim_name)
		if anim:
			anim.length = animations[anim_name].length
			anim.loop_mode = Animation.LOOP_LINEAR if animations[anim_name].loop else Animation.LOOP_NONE
