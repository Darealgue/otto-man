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
signal player_died()
signal carried_resources_changed(new_totals: Dictionary)
signal carried_resources_lost(losses: Dictionary)

const ResourceType = preload("res://resources/resource_types.gd")
static var RESOURCE_TYPES := ResourceType.all()

var resource_loss_fraction_on_hit := 0.2
var min_resource_loss_per_hit := 1

# Base stats
var base_stats = {
	"max_health": 100.0,
	"base_damage": 10.0,
	"fall_attack_damage": 10.0,
	"movement_speed": 600.0,
	"jump_force": 600.0,
	"shield_cooldown": 15.0,
	"dash_cooldown": 1.2,
	"block_charges": 3,
	"dash_charges": 1,  # Add dash charges stat
}

# Current health tracking
var current_health: float = 100.0

# Multipliers for each stat (start at 1.0 = 100%)
var stat_multipliers = {
	"max_health": 1.0,
	"base_damage": 1.0,
	"fall_attack_damage": 1.0,
	"movement_speed": 1.0,
	"jump_force": 1.0,
	"shield_cooldown": 1.0,
	"dash_cooldown": 1.0,
	"block_charges": 1.0,
	"dash_charges": 1.0,  # Add dash charges multiplier
}

# Flat bonuses (start at 0)
var stat_bonuses = {
	"max_health": 0.0,
	"base_damage": 0.0,
	"fall_attack_damage": 0.0,
	"movement_speed": 0.0,
	"jump_force": 0.0,
	"shield_cooldown": 0.0,
	"dash_cooldown": 0.0,
	"block_charges": 0.0,
	"dash_charges": 0.0,  # Add dash charges bonus
}

var carried_resources := {
	ResourceType.WOOD: 0,
	ResourceType.STONE: 0,
	ResourceType.WATER: 0,
	ResourceType.FOOD: 0,
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
	
	# Check for death
	if current_health <= 0.0 and old_health > 0.0:
		player_died.emit()
		print("[PlayerStats] 💀 Player died (health: %.1f)" % current_health)
	
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

# Add helper function for fall attack damage
func get_fall_attack_damage() -> float:
	return get_stat("fall_attack_damage")

# Add more helper functions as needed... 

func get_carried_resources() -> Dictionary:
	return carried_resources.duplicate()

func get_carried_resource(type: String) -> int:
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Requested invalid carried resource type: %s" % type)
		return 0
	return carried_resources[type]

func add_carried_resource(type: String, amount: int) -> void:
	if amount == 0:
		return
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Tried to add invalid resource type: %s" % type)
		return
	_set_carried_resource(type, carried_resources[type] + amount)

func add_carried_resources(amounts: Dictionary) -> void:
	if amounts.is_empty():
		return
	var changed := false
	for type in amounts.keys():
		var int_amount := int(amounts[type])
		if int_amount == 0:
			continue
		if !carried_resources.has(type):
			push_warning("[PlayerStats] add_carried_resources received unknown type: %s" % type)
			continue
		_set_carried_resource(type, carried_resources[type] + int_amount, false)
		changed = true
	if changed:
		_emit_carried_changed()

func remove_carried_resource(type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Tried to remove invalid resource type: %s" % type)
		return 0
	var available: int = int(carried_resources[type])
	var to_remove := clampi(amount, 0, available)
	if to_remove > 0:
		_set_carried_resource(type, available - to_remove)
	return to_remove

func clear_carried_resources() -> void:
	var had_resources := false
	for type in RESOURCE_TYPES:
		if carried_resources[type] != 0:
			carried_resources[type] = 0
			had_resources = true
	if had_resources:
		_emit_carried_changed()

func lose_carried_resources_by_fraction(fraction: float, min_loss_per_type: int = 0) -> Dictionary:
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0 and min_loss_per_type <= 0:
		return {}
	var losses := {}
	for type in RESOURCE_TYPES:
		var current: int = int(carried_resources[type])
		if current <= 0:
			continue
		var loss := int(round(current * fraction))
		if min_loss_per_type > 0:
			var min_loss := min_loss_per_type
			if current < min_loss:
				min_loss = current
			loss = max(loss, min_loss)
		loss = clamp(loss, 0, current)
		if loss > 0:
			carried_resources[type] = current - loss
			losses[type] = loss
	if losses.is_empty():
		return {}
	_emit_carried_changed()
	carried_resources_lost.emit(losses.duplicate())
	return losses

func _set_carried_resource(type: String, value: int, emit_signal_on_change: bool = true) -> void:
	var clamped: int = max(int(value), 0)
	if carried_resources[type] == clamped:
		return
	carried_resources[type] = clamped
	if emit_signal_on_change:
		_emit_carried_changed()

func _emit_carried_changed() -> void:
	carried_resources_changed.emit(carried_resources.duplicate())

func configure_resource_loss_on_hit(fraction: float, min_loss: int) -> void:
	resource_loss_fraction_on_hit = clampf(fraction, 0.0, 1.0)
	min_resource_loss_per_hit = max(min_loss, 0)

func lose_resources_on_damage() -> Dictionary:
	return lose_carried_resources_by_fraction(resource_loss_fraction_on_hit, min_resource_loss_per_hit)
