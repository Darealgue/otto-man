# PlayerStats.gd
# Central singleton for managing all player statistics and modifications.
# 
# This is the SINGLE SOURCE OF TRUTH for all player stats.
# All stat modifications MUST go through this system.
#
# How to use:
# 1. Get stats using get_stat() or helper functions
# 2. Modify stats using add_stat_bonus() or add_stat_multiplier()
# 3. Listen to stat_changed signal to react to changes
#
# Stats are calculated as: (base_value * multiplier) + bonus
# - base_stats: Initial values
# - stat_multipliers: Percentage-based modifications (start at 1.0 = 100%)
# - stat_bonuses: Flat additions/subtractions (start at 0)
#
# Important: 
# - Never modify player stats directly - always use this system
# - Powerups should use add_stat_multiplier() for percentage changes
# - Use add_stat_bonus() for flat value changes
# - Always check get_stat() return value before using
#
# Example:
# var current_max_health = PlayerStats.get_stat("max_health")
# PlayerStats.add_stat_multiplier("max_health", 1.2) # Increase by 20%
# PlayerStats.add_stat_bonus("max_health", 50) # Add flat 50 HP

extends Node

signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(new_health: float)

# Base stats
var base_stats = {
	"max_health": 100.0,
	"base_damage": 10.0,
	"movement_speed": 600.0,
	"jump_force": 600.0,
	"shield_cooldown": 15.0,
	"dash_cooldown": 1.2,
	"block_charges": 3,
}

# Current health tracking
var current_health: float = 100.0

# Multipliers for each stat (start at 1.0 = 100%)
var stat_multipliers = {
	"max_health": 1.0,
	"base_damage": 1.0,
	"movement_speed": 1.0,
	"jump_force": 1.0,
	"shield_cooldown": 1.0,
	"dash_cooldown": 1.0,
	"block_charges": 1.0,
}

# Flat bonuses (start at 0)
var stat_bonuses = {
	"max_health": 0.0,
	"base_damage": 0.0,
	"movement_speed": 0.0,
	"jump_force": 0.0,
	"shield_cooldown": 0.0,
	"dash_cooldown": 0.0,
	"block_charges": 0.0,
}


# Get the final value of a stat after all multipliers and bonuses
func get_stat(stat_name: String) -> float:
	if !base_stats.has(stat_name):
		push_error("[PlayerStats] Trying to get invalid stat: " + stat_name)
		return 0.0
		
	var base = base_stats[stat_name]
	var multiplier = stat_multipliers[stat_name]
	var bonus = stat_bonuses[stat_name]
	
	return (base * multiplier) + bonus

# Add a flat bonus to a stat
func add_stat_bonus(stat_name: String, amount: float) -> void:
	if !stat_bonuses.has(stat_name):
		push_error("Trying to modify invalid stat: " + stat_name)
		return
		
	var old_value = get_stat(stat_name)
	stat_bonuses[stat_name] += amount
	var new_value = get_stat(stat_name)
	
	if stat_name == "max_health":
		_scale_current_health(old_value, new_value)
		
	stat_changed.emit(stat_name, old_value, new_value)

# Multiply a stat by a factor
func add_stat_multiplier(stat_name: String, factor: float) -> void:
	if !stat_multipliers.has(stat_name):
		push_error("Trying to modify invalid stat: " + stat_name)
		return
		
	var old_value = get_stat(stat_name)
	stat_multipliers[stat_name] *= factor
	var new_value = get_stat(stat_name)
	
	if stat_name == "max_health":
		_scale_current_health(old_value, new_value)
		
	stat_changed.emit(stat_name, old_value, new_value)

# Scale current health when max health changes
func _scale_current_health(old_max: float, new_max: float) -> void:
	if old_max <= 0:
		current_health = new_max
	else:
		var health_percentage = current_health / old_max
		current_health = new_max * health_percentage
	health_changed.emit(current_health)

# Reset all stats to base values
func reset_stats() -> void:
	for stat in stat_multipliers.keys():
		stat_multipliers[stat] = 1.0
		stat_bonuses[stat] = 0.0
		stat_changed.emit(stat, get_stat(stat), base_stats[stat])
	
	current_health = get_stat("max_health")
	health_changed.emit(current_health)

# Get all active effects that modify a specific stat
func get_stat_modifiers(stat_name: String) -> Array:
	var powerup_manager = get_node("/root/PowerupManager")
	if !powerup_manager:
		return []
		
	var modifiers = []
	for powerup in powerup_manager.get_active_powerups():
		if powerup.affects_stat(stat_name):
			modifiers.append(powerup)
	return modifiers

# Helper functions for common stat operations
func get_max_health() -> float:
	var max_health = get_stat("max_health")
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(value: float, show_damage_number: bool = true) -> void:
	var old_health = current_health
	current_health = clamp(value, 0, get_max_health())
	health_changed.emit(current_health)
	
	if show_damage_number and current_health < old_health:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var damage_amount = old_health - current_health
			var damage_number = preload("res://effects/damage_number.tscn").instantiate()
			player.add_child(damage_number)
			damage_number.global_position = player.global_position + Vector2(0, -50)
			damage_number.setup(int(damage_amount), false, true)

func get_base_damage() -> float:
	return get_stat("base_damage")

func get_movement_speed() -> float:
	return get_stat("movement_speed")

func get_shield_cooldown() -> float:
	return get_stat("shield_cooldown")

func get_dash_cooldown() -> float:
	return get_stat("dash_cooldown")

func get_block_charges() -> int:
	return int(get_stat("block_charges"))

# Add more helper functions as needed... 
