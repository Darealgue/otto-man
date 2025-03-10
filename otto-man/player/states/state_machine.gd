extends Node

var current_state: State
var previous_state: State

@onready var state: State = get_child(0)

func _ready() -> void:
	await owner.ready
	# Set initial state
	current_state = get_child(0) as State
	previous_state = current_state
	
	# Initialize all states
	for child in get_children():
		var state = child as State
		if state:
			state.state_machine = self
			state.player = owner
			state.animation_player = owner.get_node("AnimationPlayer")
			
			# Validate required components
			if not (state.player and state.animation_player):
				push_error("[StateMachine] State", state.name, "is missing required components!")
	
	# Enter initial state
	if current_state:
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String, force: bool = false) -> void:
	if not has_node(target_state_name):
		return
		
	# Don't transition to the same state unless forced
	if not force and current_state and current_state.name == target_state_name:
		return
		
	var target_state = get_node(target_state_name)
	if target_state:
		if current_state:
			current_state.exit()
		previous_state = current_state
		current_state = target_state
		current_state.enter()
	else:
		push_error("[StateMachine] State", target_state_name, "not found in state machine!")
