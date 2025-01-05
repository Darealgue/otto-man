extends Node
class_name State

@export var gravity: float = 0.0
var state_machine = null
var player = null
var animation_tree = null
var animation_player = null
var debug_enabled: bool = OS.is_debug_build()

func _ready():
	await owner.ready
	player = owner as CharacterBody2D
	if not player:
		push_error("State's owner must be a CharacterBody2D")
		return
		
	animation_tree = owner.get_node("AnimationTree")
	animation_player = owner.get_node("AnimationPlayer")
	
	_validate_components()

func _validate_components():
	var errors = []
	
	if not animation_tree:
		errors.append("AnimationTree not found")
	if not animation_player:
		errors.append("AnimationPlayer not found")
	if not state_machine:
		errors.append("StateMachine not set")
	
	if errors.size() > 0:
		push_error("State validation failed: " + ", ".join(errors))
		return false
	return true

func enter():
	pass

func exit():
	pass

func handle_input(_event: InputEvent):
	pass

func update(_delta: float):
	pass

func physics_update(_delta: float):
	pass

func transition_to(state_name: String):
	if state_machine:
		state_machine.transition_to(state_name)
	else:
		push_error("Cannot transition state: StateMachine not set") 