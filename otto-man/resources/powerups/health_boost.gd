extends PowerupResource

# Health boost values for each rarity
const HEALTH_BOOSTS = {
	"Common": 0.15,    # 15% boost
	"Rare": 0.25,     # 25% boost
	"Epic": 0.35,     # 35% boost
	"Legendary": 0.50  # 50% boost
}

var boost_stack := []  # Track individual boosts

func _init() -> void:
	name = "Health Boost"
	description = "Increases max health"  # Base description, will be modified in get_modified_description
	rarity = 0  # Start as Common
	weight = RARITY_CHANCES["Common"]
	stackable = true
	max_stacks = 3
	powerup_type = PowerupType.HEALTH_BOOST
	print("DEBUG: Initialized Health Boost powerup with rarity: ", rarity)

func apply_powerup(player: CharacterBody2D) -> void:
	if player.has_method("modify_max_health"):
		var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
		var boost = HEALTH_BOOSTS[rarity_name]
		boost_stack.append(boost)  # Add this boost to our stack
		
		# Calculate total multiplier (1 + sum of all boosts)
		var total_multiplier = 1.0
		for boost_value in boost_stack:
			total_multiplier += boost_value
		
		print("[Health Boost] Applied +" + str(int(boost * 100)) + "% health [" + rarity_name + "]")
		print("[Health Boost] Total multiplier is now x" + str(total_multiplier))
		
		player.modify_max_health(total_multiplier)

func remove_powerup(player: CharacterBody2D) -> void:
	if player.has_method("reset_max_health"):
		boost_stack.clear()  # Clear all boosts
		player.reset_max_health()

func get_modified_description() -> String:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var boost = HEALTH_BOOSTS[rarity_name]
	var boost_percent = int(boost * 100)
	
	# Dynamic base description
	var desc = "Increases max health by " + str(boost_percent) + "%"
	
	# Add stack information if stacked
	if !boost_stack.is_empty():
		var total_boost = 0.0
		for boost_value in boost_stack:
			total_boost += boost_value
		var total_percent = int(total_boost * 100)
		desc += "\nCurrent total: +" + str(total_percent) + "%"
	
	# Add rarity tag
	desc += "\n[" + rarity_name + "]"
	
	return desc 