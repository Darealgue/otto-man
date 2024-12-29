extends Resource
class_name PowerupResource

@export var name: String
@export var description: String
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: int = 0
@export var weight: float = 1.0  # For rarity chances
@export var stackable: bool = true
@export var max_stacks: int = -1  # -1 means infinite

# Rarity chances and boost values
const RARITY_CHANCES = {
	"Common": 0.60,    # 60% chance
	"Rare": 0.25,     # 25% chance
	"Epic": 0.10,     # 10% chance
	"Legendary": 0.05  # 5% chance
}

# Boost values for each rarity (can be overridden by specific powerups)
const RARITY_BOOSTS = {
	"Common": 0.10,    # 10% boost
	"Rare": 0.15,     # 15% boost
	"Epic": 0.20,     # 20% boost
	"Legendary": 0.25  # 25% boost
}

# Rarity colors for UI
const RARITY_COLORS = {
	"Common": Color(0.7, 0.7, 0.7, 0.8),     # Gray
	"Rare": Color(0.0, 0.5, 1.0, 0.8),       # Blue
	"Epic": Color(0.6, 0.0, 1.0, 0.8),       # Purple
	"Legendary": Color(1.0, 0.6, 0.0, 0.8)   # Orange
}

var stack_count: int = 0

func can_stack() -> bool:
	if not stackable:
		return false
	if max_stacks == -1:
		return true
	return stack_count < max_stacks

func apply_powerup(player: CharacterBody2D) -> void:
	_apply(player)

func remove_powerup(player: CharacterBody2D) -> void:
	stack_count = 0
	_remove(player)

# Virtual methods to be overridden by specific powerups
func _apply(_player: CharacterBody2D) -> void:
	pass

func _remove(_player: CharacterBody2D) -> void:
	pass

func get_modified_description() -> String:
	var desc = description
	if stack_count > 1:
		desc += "\nStack Count: " + str(stack_count)
	
	# Add rarity information
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	desc += "\n[" + rarity_name + "]"
	
	return desc

func get_rarity_boost() -> float:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	return RARITY_BOOSTS[rarity_name]

func get_rarity_color() -> Color:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	return RARITY_COLORS[rarity_name] 