extends Node
class_name State

signal state_entered
signal state_exited

var state_machine = null
var player = null
var animation_player = null
var animation_tree = null
var debug_enabled := false

func enter() -> void:
	emit_signal("state_entered")

func exit() -> void:
	emit_signal("state_exited")

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass 