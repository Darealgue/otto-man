@tool
extends Resource
class_name PowerupResource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum PowerupType { 
	SHIELD, 
	FIRE_TRAIL, 
	DASH_STRIKE,
	DAMAGE_BOOST,
	HEALTH_BOOST,
	# New synergy powerups
	SHIELD_BREAK_TIME,
	SHIELD_REGEN,
	TIME_WALKER,
	SHIELD_BURST,
	PERFECT_SHIELD,
	LINGERING_FLAMES,
	BURNING_RUSH,
	FLAME_DASH,
	HEAT_WAVE,
	PHOENIX_FORM,
	CHAIN_DASH,
	IMPACT_FORCE,
	DASH_MASTER,
	MOMENTUM_STRIKE,
	TIME_DASH
}

@export var powerup_type: PowerupType
@export var name: String
@export var description: String
@export var rarity: Rarity = Rarity.COMMON
@export var required_powerups: Array[PowerupType] = []  # Powerups required for this one to appear
@export var synergy_level: int = 0  # 0 = base, 1 = tier 1, 2 = tier 2, 3 = tier 3
@export var stackable: bool = true
@export var max_stacks: int = -1  # -1 means infinite
@export var weight: float = 1.0  # For rarity chances

const RARITY_CHANCES = {
	"Common": 0.60,    # 60% chance
	"Rare": 0.25,     # 25% chance
	"Epic": 0.10,     # 10% chance
	"Legendary": 0.05  # 5% chance
}

var stack_count: int = 0

func can_stack() -> bool:
	if not stackable:
		return false
	if max_stacks == -1:
		return true
	return stack_count < max_stacks

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.7, 0.7, 0.7, 1.0)  # Gray
		Rarity.RARE:
			return Color(0.0, 0.5, 1.0, 1.0)  # Blue
		Rarity.EPIC:
			return Color(0.6, 0.0, 1.0, 1.0)  # Purple
		Rarity.LEGENDARY:
			return Color(1.0, 0.5, 0.0, 1.0)  # Orange
	return Color.WHITE

func get_modified_description() -> String:
	var rarity_prefix = ""
	match rarity:
		Rarity.COMMON:
			rarity_prefix = "[Common] "
		Rarity.RARE:
			rarity_prefix = "[Rare] "
		Rarity.EPIC:
			rarity_prefix = "[Epic] "
		Rarity.LEGENDARY:
			rarity_prefix = "[Legendary] "
	
	var desc = rarity_prefix + description
	if stack_count > 1:
		desc += "\nStack Count: " + str(stack_count)
	return desc

# Returns true if this powerup can be offered based on player's current powerups
func is_available(current_powerups: Array[PowerupType]) -> bool:
	if required_powerups.is_empty():
		return true
	
	# Check if all required powerups are present
	for required in required_powerups:
		if not required in current_powerups:
			return false
	return true

# Returns true if this powerup would create a valid synergy with current powerups
func creates_valid_synergy(current_powerups: Array[PowerupType]) -> bool:
	# Base powerups are always valid
	if synergy_level == 0:
		return true
	
	# Count how many powerups from the same tree we have
	var same_tree_count := 0
	match powerup_type:
		# Shield tree
		PowerupType.SHIELD_BREAK_TIME, PowerupType.SHIELD_REGEN, PowerupType.TIME_WALKER, \
		PowerupType.SHIELD_BURST, PowerupType.PERFECT_SHIELD:
			if PowerupType.SHIELD in current_powerups:
				same_tree_count += 1
			# Count other shield tree powerups
			for powerup in current_powerups:
				if powerup in [PowerupType.SHIELD_BREAK_TIME, PowerupType.SHIELD_REGEN, 
							  PowerupType.TIME_WALKER, PowerupType.SHIELD_BURST]:
					same_tree_count += 1
		
		# Fire trail tree
		PowerupType.LINGERING_FLAMES, PowerupType.BURNING_RUSH, PowerupType.FLAME_DASH, \
		PowerupType.HEAT_WAVE, PowerupType.PHOENIX_FORM:
			if PowerupType.FIRE_TRAIL in current_powerups:
				same_tree_count += 1
			# Count other fire trail powerups
			for powerup in current_powerups:
				if powerup in [PowerupType.LINGERING_FLAMES, PowerupType.BURNING_RUSH,
							  PowerupType.FLAME_DASH, PowerupType.HEAT_WAVE]:
					same_tree_count += 1
		
		# Dash strike tree
		PowerupType.CHAIN_DASH, PowerupType.IMPACT_FORCE, PowerupType.DASH_MASTER, \
		PowerupType.MOMENTUM_STRIKE, PowerupType.TIME_DASH:
			if PowerupType.DASH_STRIKE in current_powerups:
				same_tree_count += 1
			# Count other dash strike powerups
			for powerup in current_powerups:
				if powerup in [PowerupType.CHAIN_DASH, PowerupType.IMPACT_FORCE,
							  PowerupType.DASH_MASTER, PowerupType.MOMENTUM_STRIKE]:
					same_tree_count += 1
	
	# Check if we have enough synergies for this tier
	return same_tree_count >= synergy_level 

# Virtual method to apply the powerup effect
func apply_powerup(player: CharacterBody2D) -> void:
	push_error("apply_powerup not implemented in " + name)

# Virtual method to remove the powerup effect
func remove_powerup(player: CharacterBody2D) -> void:
	push_error("remove_powerup not implemented in " + name) 