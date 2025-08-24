extends Node

# Minimal placeholder to satisfy components that expect a state machine.
# Provides a current_state Node with a name property.

var current_state: Node

func _ready() -> void:
	current_state = Node.new()
	current_state.name = "None"

