@tool
extends Node

static func setup_animation_tree(tree: AnimationTree) -> void:
	print("[AnimationTreeInitializer] Setting up animation tree...")
	
	# Create state machine
	var state_machine = AnimationNodeStateMachine.new()
	tree.tree_root = state_machine
	
	print("[AnimationTreeInitializer] Creating blend spaces...")
	# Create blend spaces
	_create_blend_spaces(state_machine)
	
	print("[AnimationTreeInitializer] Creating transitions...")
	# Create transitions
	_create_transitions(state_machine)
	
	# Set initial state
	state_machine.set_node_position("movement", Vector2(0, 0))
	# The default state will be the first one added (movement)
	print("[AnimationTreeInitializer] Animation tree setup complete")

static func _create_blend_spaces(state_machine: AnimationNodeStateMachine) -> void:
	# Ground movement blend space (add this first as it's our default state)
	var movement_blend = AnimationNodeBlendSpace1D.new()
	movement_blend.add_blend_point(_create_animation_node("idle"), 0.0)
	movement_blend.add_blend_point(_create_animation_node("run"), 1.0)
	state_machine.add_node("movement", movement_blend, Vector2(0, 0))
	print("[AnimationTreeInitializer] Added movement blend space")
	
	# Air state blend space
	var air_blend = AnimationNodeBlendSpace1D.new()
	air_blend.add_blend_point(_create_animation_node("jump"), -1.0)
	air_blend.add_blend_point(_create_animation_node("double_jump"), 0.0)
	air_blend.add_blend_point(_create_animation_node("fall"), 1.0)
	state_machine.add_node("air_state", air_blend, Vector2(300, 0))
	print("[AnimationTreeInitializer] Added air blend space")
	
	# Combat blend space
	var combat_blend = AnimationNodeBlendSpace1D.new()
	combat_blend.add_blend_point(_create_animation_node("attack1"), -1.0)
	combat_blend.add_blend_point(_create_animation_node("block_hold"), 0.0)
	combat_blend.add_blend_point(_create_animation_node("block_impact"), 1.0)
	state_machine.add_node("combat", combat_blend, Vector2(150, 150))
	print("[AnimationTreeInitializer] Added combat blend space")
	
	# Wall states
	state_machine.add_node("wall_slide", _create_animation_node("wall_slide"), Vector2(300, 150))
	state_machine.add_node("wall_jump", _create_animation_node("wall_jump"), Vector2(450, 150))
	print("[AnimationTreeInitializer] Added wall states")
	
	# Special states
	state_machine.add_node("dash", _create_animation_node("dash"), Vector2(450, 0))
	print("[AnimationTreeInitializer] Added special states")

static func _create_animation_node(name: String) -> AnimationNodeAnimation:
	var node = AnimationNodeAnimation.new()
	node.animation = name
	return node

static func _create_transitions(state_machine: AnimationNodeStateMachine) -> void:
	# Movement transitions
	_add_transition(state_machine, "movement", "air_state", "movement_to_air")
	_add_transition(state_machine, "air_state", "movement", "air_to_movement")
	_add_transition(state_machine, "movement", "combat", "movement_to_combat")
	_add_transition(state_machine, "combat", "movement", "combat_to_movement")
	print("[AnimationTreeInitializer] Added movement transitions")
	
	# Air transitions
	_add_transition(state_machine, "air_state", "wall_slide", "air_to_wall")
	_add_transition(state_machine, "wall_slide", "air_state", "wall_to_air")
	_add_transition(state_machine, "wall_slide", "wall_jump", "wall_to_jump")
	_add_transition(state_machine, "wall_jump", "air_state", "jump_to_air")
	print("[AnimationTreeInitializer] Added air transitions")
	
	# Combat transitions
	_add_transition(state_machine, "combat", "air_state", "combat_to_air")
	_add_transition(state_machine, "air_state", "combat", "air_to_combat")
	print("[AnimationTreeInitializer] Added combat transitions")
	
	# Dash transitions
	_add_transition(state_machine, "movement", "dash", "movement_to_dash")
	_add_transition(state_machine, "air_state", "dash", "air_to_dash")
	_add_transition(state_machine, "dash", "movement", "dash_to_movement")
	_add_transition(state_machine, "dash", "air_state", "dash_to_air")
	print("[AnimationTreeInitializer] Added dash transitions")

static func _add_transition(state_machine: AnimationNodeStateMachine, from: String, to: String, name: String) -> void:
	var transition = AnimationNodeStateMachineTransition.new()
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	transition.xfade_time = 0.15
	state_machine.add_transition(from, to, transition)
	state_machine.add_transition(to, from, transition)
	print("[AnimationTreeInitializer] Added transition: ", from, " <-> ", to) 
