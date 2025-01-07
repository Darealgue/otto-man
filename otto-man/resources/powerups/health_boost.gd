# health_boost.gd
# Powerup that permanently increases player's max health by 20%
#
# Integration:
# - Uses PlayerStats for all stat modifications
# - Affects: max_health
# - Duration: Permanent
# - Type: Multiplicative (uses stat multiplier)
#
# Implementation:
# 1. Gets current max_health from PlayerStats
# 2. Applies 20% increase using add_stat_multiplier
# 3. PlayerStats handles syncing with player
#
# Important: 
# - All stat changes MUST go through PlayerStats system
# - DO NOT modify player values directly
# - Current health is handled by PlayerStats' stat_changed signal

extends PowerupEffect

const HEALTH_INCREASE = 0.2  # 20% increase

func _init() -> void:
	powerup_name = "Health Upgrade"
	description = "Permanently increases max health by 20%"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE
	affected_stats = ["max_health"]

func _ready() -> void:
	# Ensure we have PlayerStats reference
	if !player_stats:
		player_stats = get_node("/root/PlayerStats")
		if !player_stats:
			push_error("[Health Boost] PlayerStats singleton not found!")

func activate(player: CharacterBody2D) -> void:
	
	# Ensure we have PlayerStats reference
	if !player_stats:
		player_stats = get_node("/root/PlayerStats")
	if !player_stats:
		push_error("[Health Boost] PlayerStats singleton not found!")
		return
	
	# Get current values before modification
	var old_max_health = player_stats.get_stat("max_health")
	var old_current_health = player_stats.get_current_health()
	var old_multiplier = player_stats.stat_multipliers["max_health"]
	
	# Apply the health increase multiplier
	player_stats.add_stat_multiplier("max_health", 1.0 + HEALTH_INCREASE)
	
	# Get new values after modification
	var new_max_health = player_stats.get_stat("max_health")
	var new_current_health = player_stats.get_current_health()
	var new_multiplier = player_stats.stat_multipliers["max_health"]
	
	super.activate(player)

func deactivate(player: CharacterBody2D) -> void:
	
	# Ensure we have PlayerStats reference
	if !player_stats:
		player_stats = get_node("/root/PlayerStats")
	if !player_stats:
		push_error("[Health Boost] PlayerStats singleton not found!")
		return
	
	# Get current values before deactivation
	var old_max_health = player_stats.get_stat("max_health")
	var old_current_health = player_stats.get_current_health()
	var old_multiplier = player_stats.stat_multipliers["max_health"]
	
	# Remove the health increase multiplier
	player_stats.add_stat_multiplier("max_health", 1.0 / (1.0 + HEALTH_INCREASE))
	
	# Get new values after deactivation
	var new_max_health = player_stats.get_stat("max_health")
	var new_current_health = player_stats.get_current_health()
	var new_multiplier = player_stats.stat_multipliers["max_health"]
	
	super.deactivate(player)

func conflicts_with(other: PowerupEffect) -> bool:
	# Health Boost can stack with any powerup
	return false
