extends Resource
class_name PowerupResource

# Basic powerup information
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""

# Stack information
@export var stack_count: int = 0
@export var can_stack: bool = true

# Function to apply the powerup effect
func apply_effect(player: CharacterBody2D) -> void:
	pass

# Function to remove the powerup effect (if needed)
func remove_effect(player: CharacterBody2D) -> void:
	pass

# Function to update effect when stacks change
func update_stack_effect(player: CharacterBody2D) -> void:
	pass 