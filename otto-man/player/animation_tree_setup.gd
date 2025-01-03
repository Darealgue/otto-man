extends Node

const TRANSITION_RESET = "parameters/conditions/reset"

static func setup_animation_tree(tree: AnimationTree, sprite: AnimatedSprite2D) -> void:
	# Get the animation player
	var state_machine = tree.get("parameters/playback")
	
	# Create animation library
	var animation_player = AnimationPlayer.new()
	tree.add_child(animation_player)
	
	# Get frame counts for each animation
	var animations = {}
	for anim in sprite.sprite_frames.get_animation_names():
		animations[anim] = {
			"frames": sprite.sprite_frames.get_frame_count(anim),
			"speed": sprite.sprite_frames.get_animation_speed(anim)
		}
	
	# Create animations from sprite frames
	for anim_name in animations.keys():
		var animation = Animation.new()
		var track_index = animation.add_track(Animation.TYPE_VALUE)
		
		# Set track path to frame property
		animation.track_set_path(track_index, "%s:frame" % sprite.get_path())
		
		# Calculate frame times
		var frame_count = animations[anim_name].frames
		var speed = animations[anim_name].speed
		var duration = frame_count / float(speed)
		
		# Add keyframes
		for i in range(frame_count):
			var time = i * duration / frame_count
			animation.track_insert_key(track_index, time, i)
		
		# Set loop mode
		animation.loop_mode = Animation.LOOP_LINEAR if _should_loop(anim_name) else Animation.LOOP_NONE
		
		# Add animation to player
		animation_player.add_animation(anim_name, animation)
	
	# Set up state machine parameters
	_setup_state_machine_parameters(tree)

static func _should_loop(anim_name: String) -> bool:
	# Define which animations should loop
	match anim_name:
		"idle", "run", "fall", "wall_slide", "block":
			return true
		_:
			return false

static func _setup_state_machine_parameters(tree: AnimationTree) -> void:
	# Movement blend space
	tree.set("parameters/movement/blend_position", 0)
	
	# Air state blend space
	tree.set("parameters/air_state/blend_position", 0)
	
	# Combat blend space
	tree.set("parameters/combat/blend_position", 0)
	
	# Set default transition times
	var state_machine = tree.get("parameters/playback")
	state_machine.set_default_blend_time(0.2)  # Normal transition time
	
	# Set specific transition times
	_set_transition_times(state_machine) 