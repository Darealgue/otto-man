extends AnimationNodeStateMachinePlayback

# State machine states
const MOVEMENT = "movement"
const AIR_STATE = "air_state"
const COMBAT = "combat"

# Transition conditions
const MOVEMENT_TO_AIR = "movement_to_air"
const AIR_TO_MOVEMENT = "air_to_movement"
const MOVEMENT_TO_COMBAT = "movement_to_combat"
const COMBAT_TO_MOVEMENT = "combat_to_movement"
const AIR_TO_COMBAT = "air_to_combat"
const COMBAT_TO_AIR = "combat_to_air"

func _init() -> void:
	# Set up initial state
	start("movement")
	
	# Set up conditions
	_setup_conditions()

func _setup_conditions() -> void:
	# Movement transitions
	set_condition(MOVEMENT_TO_AIR, false)
	set_condition(MOVEMENT_TO_COMBAT, false)
	
	# Air transitions
	set_condition(AIR_TO_MOVEMENT, false)
	set_condition(AIR_TO_COMBAT, false)
	
	# Combat transitions
	set_condition(COMBAT_TO_MOVEMENT, false)
	set_condition(COMBAT_TO_AIR, false)

func transition_to_air() -> void:
	set_condition(MOVEMENT_TO_AIR, true)
	set_condition(AIR_TO_MOVEMENT, false)

func transition_to_ground() -> void:
	set_condition(AIR_TO_MOVEMENT, true)
	set_condition(MOVEMENT_TO_AIR, false)

func transition_to_combat() -> void:
	if get_current_node() == MOVEMENT:
		set_condition(MOVEMENT_TO_COMBAT, true)
		set_condition(COMBAT_TO_MOVEMENT, false)
	elif get_current_node() == AIR_STATE:
		set_condition(AIR_TO_COMBAT, true)
		set_condition(COMBAT_TO_AIR, false)

func transition_from_combat() -> void:
	if is_on_ground():
		set_condition(COMBAT_TO_MOVEMENT, true)
		set_condition(MOVEMENT_TO_COMBAT, false)
	else:
		set_condition(COMBAT_TO_AIR, true)
		set_condition(AIR_TO_COMBAT, false)

func is_on_ground() -> bool:
	return get_current_node() == MOVEMENT 