@tool
extends Resource
class_name ChunkType

# Enums for chunk properties
enum ConnectionType {
    NONE = 0,
    LEFT = 1,
    RIGHT = 2,
    TOP = 4,
    BOTTOM = 8
}

enum ChunkCategory {
    PLATFORM,    # Basic platforming
    COMBAT,      # Combat arena
    CHALLENGE,   # Difficult platforming/combat mix
    REWARD,      # Powerup/treasure room
    BOSS,        # Boss arena
    SPECIAL      # Special events/shops
}

# Basic Properties
@export var chunk_name: String
@export_file("*.tscn") var scene_path: String
@export var category: ChunkCategory
@export var connections: Array[int] = []  # Using ConnectionType flags

# Size and Layout
@export var chunk_size: Vector2 = Vector2(1920, 1080)  # Default screen size
@export var min_ceiling_height: float = 200.0  # Minimum height for player jumping
@export var required_platform_count: int = 3   # Minimum platforms needed

# Gameplay Settings
@export_group("Difficulty")
@export var difficulty_range: Vector2i = Vector2i(1, 10)  # Min/Max difficulty
@export var weight: float = 1.0  # Chance of being selected
@export var required_powerups: Array[String] = []  # Required powerups to access

@export_group("Combat")
@export var can_spawn_enemies: bool = true
@export var min_enemies: int = 0
@export var max_enemies: int = 5
@export var allowed_enemy_types: Array[String] = []
@export var enemy_spawn_points: Array[Vector2] = []

@export_group("Rewards")
@export var guaranteed_powerup: bool = false
@export var powerup_types: Array[String] = []
@export var coin_value: int = 0

# Validation
func is_valid() -> bool:
    # Basic validation
    if chunk_name.is_empty() or scene_path.is_empty():
        return false
    
    # Connection validation
    if connections.is_empty():
        return false
        
    # Size validation
    if chunk_size.x < 960 or chunk_size.y < 540:  # Minimum size check
        return false
        
    # Combat validation
    if can_spawn_enemies and allowed_enemy_types.is_empty():
        return false
        
    return true

# Connection checking
func has_connection(type: ConnectionType) -> bool:
    for connection in connections:
        if connection & type:
            return true
    return false

func can_connect_to(other: ChunkType, direction: ConnectionType) -> bool:
    # Check if this chunk has the required connection
    if not has_connection(direction):
        return false
        
    # Check if other chunk has the opposite connection
    var opposite = get_opposite_connection(direction)
    return other.has_connection(opposite)

func get_opposite_connection(type: ConnectionType) -> ConnectionType:
    match type:
        ConnectionType.LEFT: return ConnectionType.RIGHT
        ConnectionType.RIGHT: return ConnectionType.LEFT
        ConnectionType.TOP: return ConnectionType.BOTTOM
        ConnectionType.BOTTOM: return ConnectionType.TOP
        _: return ConnectionType.NONE

# Difficulty checks
func is_within_difficulty(current_difficulty: int) -> bool:
    return current_difficulty >= difficulty_range.x and current_difficulty <= difficulty_range.y

# Enemy spawning
func get_random_enemy_type() -> String:
    if allowed_enemy_types.is_empty():
        return ""
    return allowed_enemy_types[randi() % allowed_enemy_types.size()]

func get_random_spawn_point() -> Vector2:
    if enemy_spawn_points.is_empty():
        # Return a default position if no spawn points defined
        return Vector2(chunk_size.x / 2, chunk_size.y - 100)
    return enemy_spawn_points[randi() % enemy_spawn_points.size()] 