extends Node

@export var initial_state := NodePath()
@onready var state: State = get_node(initial_state)
@onready var player = owner

func _ready():
	for child in get_children():
		if child is State:
			child.state_machine = self
			child.player = player
			child.animation_player = player.get_node("AnimationPlayer")
			child.animation_tree = player.get_node("AnimationTree")
	
	state.enter()

func _physics_process(delta):
	state.physics_update(delta)

func transition_to(target_state_name: String):
	if not has_node(target_state_name):
		return
		
	state.exit()
	state = get_node(target_state_name)
	state.enter()
