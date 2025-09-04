# double_dash.gd
# Powerup that allows dashing twice before cooldown
#
# Integration:
# - Modifies player's dash system
# - Affects: dash_cooldown (indirectly)
# - Duration: Permanent
# - Type: Mobility tree, Tier 1
#
# Implementation:
# 1. Increases dash charges from 1 to 2
# 2. Allows consecutive dashes
# 3. Works with existing dash mechanics

extends PowerupEffect

const DASH_CHARGES_BONUS = 1  # Add 1 extra dash charge

func _init() -> void:
	powerup_name = "Double Dash"
	description = "Can dash twice before cooldown"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.MOVEMENT
	affected_stats = ["dash_cooldown"]
	tree_name = "mobility"  # Mobility tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	# Add bonus dash charges
	player_stats.add_stat_bonus("dash_charges", DASH_CHARGES_BONUS)
	
	# Notify player about the change
	if player.has_method("update_dash_charges"):
		player.update_dash_charges()
	
	print("[Double Dash] Activated - +1 dash charge")

func deactivate(player: CharacterBody2D) -> void:
	# Remove bonus dash charges
	player_stats.add_stat_bonus("dash_charges", -DASH_CHARGES_BONUS)
	
	# Notify player about the change
	if player.has_method("update_dash_charges"):
		player.update_dash_charges()
	
	print("[Double Dash] Deactivated")
	super.deactivate(player)

# Synergize with other mobility powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups
