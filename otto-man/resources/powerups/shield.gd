extends PowerupResource

# Shield damage block values for each rarity
const SHIELD_BLOCKS = {
	"Common": 20,     # 20 damage blocked
	"Rare": 30,      # 30 damage blocked
	"Epic": 40,      # 40 damage blocked
	"Legendary": 50   # 50 damage blocked
}

func _init() -> void:
	name = "Shield"
	description = "Blocks damage once"  # Base description, will be modified in get_modified_description
	rarity = 0  # Start as Common
	weight = RARITY_CHANCES["Common"]
	stackable = false
	max_stacks = 1
	powerup_type = PowerupType.SHIELD
	print("DEBUG: Initialized Shield powerup with rarity: ", rarity)

func apply_powerup(player: CharacterBody2D) -> void:
	if player.has_method("enable_shield"):
		var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
		var block_amount = SHIELD_BLOCKS[rarity_name]
		print("DEBUG: Applying Shield - Rarity: ", rarity_name, ", Block amount: ", block_amount)
		player.enable_shield(block_amount)

func remove_powerup(player: CharacterBody2D) -> void:
	if player.has_method("disable_shield"):
		print("DEBUG: Removing Shield")
		player.disable_shield()

func get_modified_description() -> String:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var block_amount = SHIELD_BLOCKS[rarity_name]
	
	print("DEBUG: Generating Shield description")
	print("- Rarity: ", rarity_name)
	print("- Block amount: ", block_amount)
	
	# Dynamic description with block amount
	var desc = "Blocks " + str(block_amount) + " damage from a single hit"
	desc += "\nRecharges after each enemy kill"
	
	# Add rarity tag
	desc += "\n[" + rarity_name + "]"
	
	print("DEBUG: Final description: ", desc)
	return desc