extends PowerupResource

# Dash strike damage values for each rarity
const DASH_DAMAGES = {
	"Common": 5,      # +5 damage
	"Rare": 10,      # +10 damage
	"Epic": 15,      # +15 damage
	"Legendary": 20   # +20 damage
}

const COOLDOWN_MULTIPLIER = 1.5  # 50% longer cooldown

func _init() -> void:
	name = "Dash Strike"
	description = "Deal damage while dashing but has 50% longer cooldown"
	rarity = 0  # Start as Common
	weight = RARITY_CHANCES["Common"]
	stackable = false
	max_stacks = 1

func _apply(player: CharacterBody2D) -> void:
	if player.has_method("enable_dash_damage"):
		var damage = DASH_DAMAGES[["Common", "Rare", "Epic", "Legendary"][rarity]]
		var total_damage = damage * stack_count
		player.enable_dash_damage(total_damage)
		
	if player.has_method("modify_dash_cooldown"):
		player.modify_dash_cooldown(COOLDOWN_MULTIPLIER)

func _remove(player: CharacterBody2D) -> void:
	if player.has_method("disable_dash_damage"):
		player.disable_dash_damage()
	if player.has_method("reset_dash_cooldown"):
		player.reset_dash_cooldown()

func get_modified_description() -> String:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var damage = DASH_DAMAGES[rarity_name]
	
	# Dynamic description with damage amount
	var desc = "Dash deals +" + str(damage) + " damage to enemies"
	desc += "\nDash cooldown increased by 50%"
	
	# Add stack information if stacked
	if stack_count > 1:
		var total_damage = damage * stack_count
		desc += "\nCurrent total: +" + str(total_damage) + " damage"
	
	# Add rarity tag
	desc += "\n[" + rarity_name + "]"
	
	return desc 