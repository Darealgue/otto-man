@tool
extends Node

const AnimationTreeInitializer = preload("res://player/animations/animation_tree_initializer.gd")

# This script helps set up the Player scene with all required nodes and configurations
static func setup_player_scene(player: Node) -> void:
	print("[PlayerSceneSetup] Setting up player scene...")
	
	# Add AnimationPlayer if it doesn't exist
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if not anim_player:
		print("[PlayerSceneSetup] Creating AnimationPlayer...")
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		player.add_child(anim_player)
		anim_player.owner = player
	
	# Add AnimationTree if it doesn't exist
	var anim_tree = player.get_node_or_null("AnimationTree")
	if not anim_tree:
		print("[PlayerSceneSetup] Creating AnimationTree...")
		anim_tree = AnimationTree.new()
		anim_tree.name = "AnimationTree"
		player.add_child(anim_tree)
		anim_tree.owner = player
		
		# Configure AnimationTree
		anim_tree.active = true
		anim_tree.root_motion_track = NodePath("")
		anim_tree.anim_player = anim_player.get_path()
		
		print("[PlayerSceneSetup] Initializing animation tree...")
		# Initialize animation tree
		AnimationTreeInitializer.setup_animation_tree(anim_tree)
		
		# Add required parameters
		_add_parameters(anim_tree)
		
		print("[PlayerSceneSetup] Animation tree setup complete")
	else:
		print("[PlayerSceneSetup] Updating existing animation tree...")
		# Update existing animation tree
		anim_tree.active = true
		anim_tree.root_motion_track = NodePath("")
		anim_tree.anim_player = anim_player.get_path()
		
		# Re-initialize animation tree
		AnimationTreeInitializer.setup_animation_tree(anim_tree)
		
		# Update parameters
		_add_parameters(anim_tree)
		
		print("[PlayerSceneSetup] Animation tree update complete")

static func _add_parameters(tree: AnimationTree) -> void:
	print("[PlayerSceneSetup] Adding animation parameters...")
	
	# Movement blend parameter
	var movement_param = "parameters/movement/blend_position"
	_set_parameter_if_needed(tree, movement_param, 0.0)
	
	# Air state blend parameter
	var air_param = "parameters/air_state/blend_position"
	_set_parameter_if_needed(tree, air_param, 0.0)
	
	# Combat blend parameter
	var combat_param = "parameters/combat/blend_position"
	_set_parameter_if_needed(tree, combat_param, 0.0)
	
	# State conditions
	var conditions = [
		"movement_to_air",
		"air_to_movement",
		"movement_to_combat",
		"combat_to_movement",
		"air_to_combat",
		"combat_to_air",
		"air_to_wall",
		"wall_to_air",
		"wall_to_jump",
		"jump_to_air",
		"movement_to_dash",
		"air_to_dash",
		"dash_to_movement",
		"dash_to_air"
	]
	
	print("[PlayerSceneSetup] Adding state conditions...")
	for condition in conditions:
		var param = "parameters/conditions/" + condition
		_set_parameter_if_needed(tree, param, false)
			
	print("[PlayerSceneSetup] Animation parameters added")

static func _set_parameter_if_needed(tree: AnimationTree, param: String, default_value) -> void:
	# Try to get the current value, if it fails, set the default value
	if tree.get(param) == null:
		tree.set(param, default_value)
		print("[PlayerSceneSetup] Added parameter: ", param)

# Helper function to ensure the animation tree is properly set up
static func verify_animation_tree(player: Node) -> bool:
	var anim_tree = player.get_node_or_null("AnimationTree")
	if not anim_tree:
		push_error("[PlayerSceneSetup] Animation tree not found!")
		return false
		
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if not anim_player:
		push_error("[PlayerSceneSetup] Animation player not found!")
		return false
		
	if not anim_tree.active:
		push_error("[PlayerSceneSetup] Animation tree is not active!")
		return false
		
	if not anim_tree.tree_root:
		push_error("[PlayerSceneSetup] Animation tree has no root!")
		return false
		
	print("[PlayerSceneSetup] Animation tree verification passed")
	return true 
