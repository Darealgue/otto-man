extends PowerupResource

# Damage boost values for each rarity (flat damage increase)
const DAMAGE_BOOSTS = {
	"Common": 5,     # +5 damage
	"Rare": 10,      # +10 damage
	"Epic": 20,      # +20 damage
	"Legendary": 30   # +30 damage
}

var boost_stack := []  # Track individual boosts

func _init() -> void:
	name = "Damage Boost"
	description = "Increases damage dealt"
	stackable = true
	max_stacks = 999
	weight = RARITY_CHANCES["Common"]

func apply_powerup(player: CharacterBody2D) -> void:
	if !player.has_method("modify_damage"):
		return
	
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var damage_boost = DAMAGE_BOOSTS[rarity_name]
	boost_stack.append(damage_boost)  # Add this boost to our stack
	
	# Calculate total boost by summing all boosts
	var total_boost = 0
	for boost in boost_stack:
		total_boost += boost
	
	print("[Damage Boost] Applied +" + str(damage_boost) + " damage [" + rarity_name + "]")
	print("[Damage Boost] Total boost is now +" + str(total_boost))
	
	# Pass the total flat damage boost
	player.modify_damage(total_boost)

func remove_powerup(player: CharacterBody2D) -> void:
	if player.has_method("reset_damage"):
		boost_stack.clear()  # Clear all boosts
		player.reset_damage()

func can_stack() -> bool:
	return true

func get_modified_description() -> String:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var damage_boost = DAMAGE_BOOSTS[rarity_name]
	
	var desc = "+" + str(damage_boost) + " damage"
	if !boost_stack.is_empty():
		var total_boost = 0
		for boost in boost_stack:
			total_boost += boost
		desc += "\nCurrent total: +" + str(total_boost) + " damage"
		desc += "\nTotal damage: " + str(10 + total_boost)
	
	desc += "\n[" + rarity_name + "]"
	return desc 
