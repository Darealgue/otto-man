# bloodthirsty.gd
# Powerup that restores health when killing enemies
#
# Integration:
# - Listens to enemy death events
# - Affects: current_health
# - Duration: Permanent
# - Type: Combat tree, Tier 2
#
# Implementation:
# 1. Restores 10% health on enemy kill
# 2. Works with Vampire Lord synergy
# 3. Cannot heal above max health

extends PowerupEffect

const HEAL_PERCENTAGE = 0.10  # 10% health restore
var synergy_active = false

func _init() -> void:
	powerup_name = "Bloodthirsty"
	description = "Killing enemies restores 10% health"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["current_health"]
	tree_name = "combat"  # Combat tree, Tier 2

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	# Connect to PowerupManager for synergy detection
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		powerup_manager.synergy_activated.connect(_on_synergy_activated)
		powerup_manager.powerup_deactivated.connect(_on_powerup_deactivated)
	
	# Check if Vampire Lord synergy is already active
	_check_vampire_lord_synergy()
	
	print("[Bloodthirsty] Activated - 10% health on kill")

func deactivate(player: CharacterBody2D) -> void:
	# Disconnect signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		if powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
			powerup_manager.synergy_activated.disconnect(_on_synergy_activated)
		if powerup_manager.is_connected("powerup_deactivated", _on_powerup_deactivated):
			powerup_manager.powerup_deactivated.disconnect(_on_powerup_deactivated)
	
	print("[Bloodthirsty] Deactivated")
	super.deactivate(player)

# Called when an enemy is killed
func on_enemy_killed(enemy: Node2D) -> void:
	if !player_stats:
		return
	
	var max_health = player_stats.get_stat("max_health")
	var current_health = player_stats.get_current_health()
	
	# Calculate heal amount
	var heal_percentage = HEAL_PERCENTAGE
	if synergy_active:
		heal_percentage = 0.25  # 25% with Vampire Lord synergy
	
	var heal_amount = max_health * heal_percentage
	var new_health = min(current_health + heal_amount, max_health)
	
	player_stats.set_current_health(new_health)
	print("[Bloodthirsty] Healed " + str(heal_amount) + " HP from kill")

func _on_synergy_activated(synergy_name: String) -> void:
	if synergy_name == "vampire_lord":
		synergy_active = true
		print("[Bloodthirsty] Vampire Lord synergy activated!")

func _on_powerup_deactivated(powerup: PowerupEffect) -> void:
	# Check if Vampire Lord synergy is still active
	_check_vampire_lord_synergy()

func _check_vampire_lord_synergy() -> void:
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		synergy_active = "vampire_lord" in powerup_manager.get_active_synergies()

# Synergize with other combat powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups
