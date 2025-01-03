extends Node
class_name State

@onready var state_machine: Node = null
var player = null
var animation_player = null
var animation_tree = null
@export var gravity: float = 0.0

func enter():
	pass

func exit():
	pass

func update(_delta: float):
	pass

func physics_update(_delta: float):
	pass

func handle_input(_event: InputEvent):
	pass 