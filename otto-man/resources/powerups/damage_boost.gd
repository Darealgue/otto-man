@tool
extends PowerupEffect

const DAMAGE_BOOST = 0.2  # 20% damage increase

func _init() -> void:
	powerup_name = "Damage Upgrade"
	description = "Permanently increases damage by 20%"
	duration = -1  # -1 means permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["base_damage"]
	tree_name = "combat"  # Add tree association

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	var old_damage = player_stats.get_stat("base_damage")
	
	# Add multiplier to the stat system
	player_stats.add_stat_multiplier("base_damage", 1.0 + DAMAGE_BOOST)
	

func deactivate(player: CharacterBody2D) -> void:
	if !is_instance_valid(player):
		# Reset multiplier in stat system
		player_stats.add_stat_multiplier("base_damage", 1.0 / (1.0 + DAMAGE_BOOST))  # Divide to remove multiplier
		super.deactivate(player)

# Synergize with other damage upgrades
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking damage upgrades
