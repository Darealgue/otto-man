extends Node

signal stat_changed(stat_name: String, old_value: float, new_value: float)

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
		push_error("Trying to get invalid stat: " + stat_name)
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
	stat_changed.emit(stat_name, old_value, new_value)

# Multiply a stat by a factor
func add_stat_multiplier(stat_name: String, factor: float) -> void:
	if !stat_multipliers.has(stat_name):
		push_error("Trying to modify invalid stat: " + stat_name)
		return
		
	var old_value = get_stat(stat_name)
	stat_multipliers[stat_name] *= factor
	var new_value = get_stat(stat_name)
	stat_changed.emit(stat_name, old_value, new_value)

# Reset all stats to base values
func reset_stats() -> void:
	for stat in stat_multipliers.keys():
		stat_multipliers[stat] = 1.0
		stat_bonuses[stat] = 0.0
		stat_changed.emit(stat, get_stat(stat), base_stats[stat])

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
	return get_stat("max_health")

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