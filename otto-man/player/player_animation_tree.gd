@tool
extends AnimationTree

@onready var sprite = $"../AnimatedSprite2D"
@onready var animation_player = $AnimationPlayer

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Set up the animation tree
		active = true
		
		# Create state machine
		var root = AnimationNodeStateMachine.new()
		tree_root = root
		
		# Create blend spaces
		_create_movement_blend()
		_create_air_blend()
		_create_combat_blend()
		
		# Set up transitions
		_setup_transitions()
		
		# Initialize the animation tree
		AnimationTreeSetup.setup_animation_tree(self, sprite)

func _create_movement_blend() -> void:
	var blend_space = AnimationNodeBlendSpace1D.new()
	
	# Add points for idle and run
	blend_space.add_blend_point(0.0, _create_animation_node("idle"))
	blend_space.add_blend_point(1.0, _create_animation_node("run"))
	
	# Add to state machine
	tree_root.add_node("movement", blend_space, Vector2(300, 0))

func _create_air_blend() -> void:
	var blend_space = AnimationNodeBlendSpace1D.new()
	
	# Add points for jump, double jump, and fall
	blend_space.add_blend_point(-1.0, _create_animation_node("jump"))
	blend_space.add_blend_point(0.0, _create_animation_node("double_jump"))
	blend_space.add_blend_point(1.0, _create_animation_node("fall"))
	
	# Add to state machine
	tree_root.add_node("air_state", blend_space, Vector2(300, 100))

func _create_combat_blend() -> void:
	var blend_space = AnimationNodeBlendSpace1D.new()
	
	# Add points for attack and block
	blend_space.add_blend_point(-1.0, _create_animation_node("attack"))
	blend_space.add_blend_point(0.0, _create_animation_node("block"))
	blend_space.add_blend_point(1.0, _create_animation_node("block_impact"))
	
	# Add to state machine
	tree_root.add_node("combat", blend_space, Vector2(300, 200))

func _create_animation_node(anim_name: String) -> AnimationNodeAnimation:
	var node = AnimationNodeAnimation.new()
	node.animation = anim_name
	return node

func _setup_transitions() -> void:
	var state_machine = tree_root as AnimationNodeStateMachine
	
	# Get animation data
	var animations = preload("res://player/animations/player_animations.gd").new()
	
	# Set up transitions for each animation
	for anim in animations.get_all_animations():
		var from_name = anim.name
		
		for to_name in anim.transitions:
			var transition = AnimationNodeStateMachineTransition.new()
			
			# Set transition properties
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
			
			# Add transition
			state_machine.add_transition(from_name, to_name, transition)
			
			# Set transition time based on animation type
			var time = animations.NORMAL
			if from_name in animations.combat_states or to_name in animations.combat_states:
				time = animations.FAST
			elif from_name in animations.air_states or to_name in animations.air_states:
				time = animations.FAST
			state_machine.set_transition_time(from_name, to_name, time) 