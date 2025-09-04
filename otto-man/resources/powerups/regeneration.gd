# regeneration.gd
# Powerup that regenerates 1% health per second
#
# Integration:
# - Uses PlayerStats for health management
# - Affects: current_health
# - Duration: Permanent
# - Type: Defense tree, Tier 1
#
# Implementation:
# 1. Regenerates 1% of max health per second
# 2. Only works when health is below maximum
# 3. Stops regenerating at full health

extends PowerupEffect

const REGEN_RATE = 0.01  # 1% per second
var regen_timer := 0.0

func _init() -> void:
	powerup_name = "Regeneration"
	description = "Regenerate 1% health per second"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE
	affected_stats = ["current_health"]
	tree_name = "defense"  # Defense tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	regen_timer = 0.0
	print("[Regeneration] Activated - 1% health per second")

func process(player: CharacterBody2D, delta: float) -> void:
	if !player or !is_instance_valid(player):
		return
	
	# Update regeneration timer
	regen_timer += delta
	
	# Regenerate every second
	if regen_timer >= 1.0:
		regen_timer = 0.0
		_apply_regeneration()

func _apply_regeneration() -> void:
	if !player_stats:
		return
	
	var max_health = player_stats.get_stat("max_health")
	var current_health = player_stats.get_current_health()
	
	# Only regenerate if not at full health
	if current_health < max_health:
		var heal_amount = max_health * REGEN_RATE
		var new_health = min(current_health + heal_amount, max_health)
		
		player_stats.set_current_health(new_health)
		print("[Regeneration] Healed " + str(heal_amount) + " HP")

func deactivate(player: CharacterBody2D) -> void:
	print("[Regeneration] Deactivated")
	super.deactivate(player)

# Synergize with other defense powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups
