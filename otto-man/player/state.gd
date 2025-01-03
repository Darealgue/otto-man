extends Node
class_name State

var state_machine = null
var player = null
var animation_tree = null
var animation_player = null

func _ready():
	await owner.ready
	player = owner as CharacterBody2D
	animation_tree = owner.get_node("AnimationTree")
	animation_player = owner.get_node("AnimationPlayer")
	
	if animation_tree:
		print("Animation Tree found")
	else:
		push_error("Animation Tree not found")
		
	if animation_player:
		print("Animation Player found")
	else:
		push_error("Animation Player not found")

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