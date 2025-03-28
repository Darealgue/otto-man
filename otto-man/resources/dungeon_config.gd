extends Resource
class_name DungeonConfig

@export var base_length: int = 14
@export var base_branches: int = 2
@export var base_dead_ends: int = 1
@export var length_increase_per_level: float = 1.0
@export var branch_increase_per_level: float = 0.5
@export var dead_end_increase_per_level: float = 0.3
@export var max_length: int = 20
@export var max_branches: int = 5
@export var max_dead_ends: int = 3

func get_length_for_level(level: int) -> int:
	# Ensure level is at least 1
	level = max(1, level)
	
	# Calculate length with a smoother increase
	var length = base_length + (level - 1) * length_increase_per_level
	# Add some randomness to make it less predictable
	length += randi() % 3 - 1
	return clamp(length, base_length, max_length)

func get_num_branches_for_level(level: int) -> int:
	# Ensure level is at least 1
	level = max(1, level)
	
	# Calculate branches with a smoother increase
	var branches = base_branches + (level - 1) * branch_increase_per_level
	# Add some randomness
	branches += randi() % 2
	return clamp(branches, base_branches, max_branches)

func get_num_dead_ends_for_level(level: int) -> int:
	# Ensure level is at least 1
	level = max(1, level)
	
	# Calculate dead ends with a smoother increase
	var dead_ends = base_dead_ends + (level - 1) * dead_end_increase_per_level
	# Add some randomness
	dead_ends += randi() % 2
	return clamp(dead_ends, base_dead_ends, max_dead_ends) 