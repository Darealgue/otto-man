extends PowerupEffect

const BLOCK_CHARGES_BONUS = 1

func _init() -> void:
	powerup_name = "Endurance"
	description = "Block charges +1"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE
	affected_stats = ["block_charges"]
	tree_name = "defense"  # Defense tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	# Add block charges
	player_stats.add_stat_bonus("block_charges", BLOCK_CHARGES_BONUS)
	
	print("[Endurance] Activated - +1 block charge")

func deactivate(player: CharacterBody2D) -> void:
	# Remove block charges
	player_stats.add_stat_bonus("block_charges", -BLOCK_CHARGES_BONUS)
	
	print("[Endurance] Deactivated")
	super.deactivate(player)
