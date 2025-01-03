extends Node

# Animation state names
const IDLE = "idle"
const RUN = "run"
const JUMP = "jump"
const DOUBLE_JUMP = "double_jump"
const FALL = "fall"
const WALL_SLIDE = "wall_slide"
const WALL_JUMP = "wall_jump"
const ATTACK = "attack"
const BLOCK = "block"
const BLOCK_IMPACT = "block_impact"
const DASH = "dash"

# Animation parameters
const BLEND_POSITION = "parameters/blend_position"
const MOVEMENT_BLEND = "parameters/movement/blend_position"
const AIR_BLEND = "parameters/air_state/blend_position"
const COMBAT_BLEND = "parameters/combat/blend_position"

# Transition times
const FAST_TRANSITION = 0.1
const NORMAL_TRANSITION = 0.2
const SLOW_TRANSITION = 0.3

static func setup_animation_tree(tree: AnimationTree) -> void:
	# Set up blend spaces
	tree.set(MOVEMENT_BLEND, 0.0)  # For ground movement
	tree.set(AIR_BLEND, 0.0)      # For air states
	tree.set(COMBAT_BLEND, 0.0)   # For combat actions
	
	# Set default transition times
	var state_machine = tree.get("parameters/playback")
	state_machine.set_default_blend_time(NORMAL_TRANSITION) 