class_name LevelConfig extends Resource

# Base values (Level 1)
@export var base_length: int = 15  # Starting dungeon length
@export var length_increase_per_level: int = 2  # How many chunks to add per level

# Maximum values (to prevent levels from becoming too large)
@export var max_length: int = 40  # Maximum dungeon length

# Optional scaling factors
@export var branch_ratio: float = 0.2  # Number of branches relative to length
@export var dead_end_ratio: float = 0.15  # Number of dead ends relative to length
@export var combat_room_base_chance: float = 0.2  # Base chance for combat rooms
@export var combat_chance_increase: float = 0.02  # How much to increase combat chance per level

# New parameters for multiple main paths
@export var min_main_paths: int = 1  # Minimum number of main paths
@export var max_main_paths: int = 3  # Maximum number of main paths
@export var branch_merge_chance: float = 0.3  # Chance for a branch to merge back to a main path
@export var path_cross_chance: float = 0.2  # Chance for paths to cross each other

func get_length_for_level(level: int) -> int:
    var target_length = base_length + (level - 1) * length_increase_per_level
    return mini(target_length, max_length)  # Never exceed max_length

func get_num_branches_for_level(level: int) -> int:
    var length = get_length_for_level(level)
    return maxi(2, floori(length * branch_ratio))  # Minimum 2 branches

func get_num_dead_ends_for_level(level: int) -> int:
    var length = get_length_for_level(level)
    return maxi(2, floori(length * dead_end_ratio))  # Minimum 2 dead ends

func get_combat_chance_for_level(level: int) -> float:
    return minf(combat_room_base_chance + (level - 1) * combat_chance_increase, 0.7)  # Cap at 70% chance

func get_num_main_paths(level: int) -> int:
    # As level increases, more main paths become possible
    var max_paths = mini(max_main_paths, 1 + (level - 1) / 3)  # Add a new path every 3 levels
    return randi_range(min_main_paths, max_paths)

func should_merge_branch() -> bool:
    return randf() < branch_merge_chance

func should_cross_paths() -> bool:
    return randf() < path_cross_chance

@export var min_branches: int = 2  # Minimum number of branch paths
@export var max_branches: int = 4  # Maximum number of branch paths
@export var min_dead_ends: int = 2  # Minimum number of dead ends
@export var max_dead_ends: int = 4  # Maximum number of dead ends
@export var combat_room_chance: float = 0.3  # Chance for a basic platform to be a combat room
@export var description: String = ""  # Optional description of this level configuration 