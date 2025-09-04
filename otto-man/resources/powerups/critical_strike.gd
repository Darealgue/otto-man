# critical_strike.gd
# Powerup that gives 25% chance to deal 2x damage on attacks
#
# Integration:
# - Uses AttackManager for damage modification
# - Affects: base_damage (through critical hits)
# - Duration: Permanent
# - Type: Combat tree, Tier 1
#
# Implementation:
# 1. Connects to AttackManager for damage modification
# 2. 25% chance to double damage on each attack
# 3. Works with all attack types

extends PowerupEffect

const CRIT_CHANCE = 0.25  # 25% chance
const CRIT_MULTIPLIER = 2.0  # 2x damage

func _init() -> void:
	powerup_name = "Critical Strike"
	description = "25% chance to deal 2x damage on attacks"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["base_damage"]
	tree_name = "combat"  # Combat tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	# Enable critical strike in AttackManager
	var attack_manager = get_node("/root/AttackManager")
	if attack_manager:
		attack_manager.enable_critical_strike(player, CRIT_CHANCE, CRIT_MULTIPLIER)
	
	print("[Critical Strike] Activated - 25% chance for 2x damage")

func deactivate(player: CharacterBody2D) -> void:
	# Disable critical strike in AttackManager
	var attack_manager = get_node("/root/AttackManager")
	if attack_manager:
		attack_manager.disable_critical_strike(player)
	
	super.deactivate(player)

# Synergize with other combat powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups
