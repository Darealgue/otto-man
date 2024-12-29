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
	powerup_type = PowerupType.DASH_STRIKE

func apply_powerup(player: CharacterBody2D) -> void:
	print("DEBUG: Applying dash strike powerup")
	if player.has_method("enable_dash_damage"):
		var damage = DASH_DAMAGES[["Common", "Rare", "Epic", "Legendary"][rarity]]
		var total_damage = damage * stack_count
		print("DEBUG: Enabling dash damage with ", total_damage, " damage")
		player.enable_dash_damage(total_damage)
		
	if player.has_method("modify_dash_cooldown"):
		print("DEBUG: Modifying dash cooldown with multiplier ", COOLDOWN_MULTIPLIER)
		player.modify_dash_cooldown(COOLDOWN_MULTIPLIER)

func remove_powerup(player: CharacterBody2D) -> void:
	print("DEBUG: Removing dash strike powerup")
	if player.has_method("disable_dash_damage"):
		print("DEBUG: Disabling dash damage")
		player.disable_dash_damage()
	if player.has_method("reset_dash_cooldown"):
		print("DEBUG: Resetting dash cooldown")
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