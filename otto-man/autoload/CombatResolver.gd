extends Node

# === Combat System ===
# Feature flags
@export var war_enabled: bool = true

# Signals
signal battle_resolved(attacker: Dictionary, defender: Dictionary, result: Dictionary)
signal unit_losses(unit_type: String, losses: int)
signal equipment_consumed(equipment_type: String, amount: int)

# Unit types and their base stats
const UNIT_TYPES = {
	"soldiers": {  # Player's soldiers from Barracks
		"base_attack": 10,
		"base_defense": 12,
		"base_morale": 50,
		"equipment_cost": {"weapon": 1, "armor": 1},
		"supply_cost": {"bread": 1, "water": 1}
	},
	"infantry": {
		"base_attack": 10,
		"base_defense": 12,
		"base_morale": 50,
		"equipment_cost": {"weapon": 1, "armor": 1},
		"supply_cost": {"bread": 1, "water": 1}
	},
	"archers": {
		"base_attack": 8,
		"base_defense": 6,
		"base_morale": 45,
		"equipment_cost": {"weapon": 1, "armor": 0},
		"supply_cost": {"bread": 1, "water": 1}
	},
	"cavalry": {
		"base_attack": 15,
		"base_defense": 8,
		"base_morale": 60,
		"equipment_cost": {"weapon": 1, "armor": 1},
		"supply_cost": {"bread": 2, "water": 1}
	}
}

# Battle modifiers
const TACTICAL_BONUSES = {
	"terrain_advantage": 1.2,
	"morale_advantage": 1.15,
	"equipment_advantage": 1.1,
	"supply_advantage": 1.05
}

func _ready() -> void:
	# Initialize combat system
	pass

# === Core Battle Resolution ===
func resolve_battle(attacker: Dictionary, defender: Dictionary, battle_type: String = "raid") -> Dictionary:
	"""Resolve a battle between two forces"""
	if not war_enabled:
		return {"error": "War system disabled"}
	
	# Calculate battle stats
	var attacker_stats := _calculate_force_stats(attacker)
	var defender_stats := _calculate_force_stats(defender)
	
	# Apply tactical modifiers
	attacker_stats = _apply_tactical_modifiers(attacker_stats, attacker, "attacker")
	defender_stats = _apply_tactical_modifiers(defender_stats, defender, "defender")
	
	# Determine battle outcome
	var battle_result := _determine_battle_outcome(attacker_stats, defender_stats, battle_type)
	
	# Calculate losses and gains
	var losses := _calculate_losses(attacker_stats, defender_stats, battle_result)
	var gains := _calculate_gains(attacker, defender, battle_result)
	
	# Apply equipment consumption
	_apply_equipment_consumption(attacker, defender, losses)
	
	# Emit signals
	battle_resolved.emit(attacker, defender, battle_result)
	
	return {
		"victor": battle_result.victor,
		"attacker_losses": losses.attacker,
		"defender_losses": losses.defender,
		"gains": gains,
		"battle_stats": {
			"attacker_final": attacker_stats,
			"defender_final": defender_stats
		}
	}

func _calculate_force_stats(force: Dictionary) -> Dictionary:
	"""Calculate total stats for a military force"""
	var total_attack := 0.0
	var total_defense := 0.0
	var total_morale := 0.0
	var unit_count := 0
	
	# Process each unit type in the force
	for unit_type in force.get("units", {}):
		var count := int(force.units[unit_type])
		if count <= 0:
			continue
			
		var unit_stats = UNIT_TYPES.get(unit_type, {})
		if unit_stats.is_empty():
			continue
			
		# Calculate unit effectiveness based on equipment and supply
		var equipment_bonus: float = _calculate_equipment_bonus(force, unit_type)
		var supply_bonus: float = _calculate_supply_bonus(force, unit_type)
		
		# Apply bonuses to unit stats
		var effective_attack: float = (float(unit_stats.get("base_attack", 0)) + equipment_bonus) * supply_bonus
		var effective_defense: float = (float(unit_stats.get("base_defense", 0)) + equipment_bonus) * supply_bonus
		var effective_morale: float = float(unit_stats.get("base_morale", 50)) * supply_bonus
		
		# Add to totals
		total_attack += effective_attack * count
		total_defense += effective_defense * count
		total_morale += effective_morale * count
		unit_count += count
	
	# Apply attack_bonus and defense_bonus if provided (from Barracks equipment bonuses)
	var attack_bonus_multiplier = 1.0 + float(force.get("attack_bonus", 0.0))
	var defense_bonus_multiplier = 1.0 + float(force.get("defense_bonus", 0.0))
	total_attack *= attack_bonus_multiplier
	total_defense *= defense_bonus_multiplier
	
	# Apply morale_multiplier if provided
	var morale_multiplier = float(force.get("morale_multiplier", 1.0))
	total_morale *= morale_multiplier
	
	# Calculate averages
	var avg_morale = total_morale / max(1, unit_count)
	
	return {
		"total_attack": total_attack,
		"total_defense": total_defense,
		"avg_morale": avg_morale,
		"unit_count": unit_count
	}

func _calculate_equipment_bonus(force: Dictionary, unit_type: String) -> float:
	"""Calculate equipment bonus for a unit type"""
	var unit_stats = UNIT_TYPES.get(unit_type, {})
	var equipment_cost = unit_stats.get("equipment_cost", {})
	var equipment_bonus := 0.0
	
	# Check if force has required equipment
	for equipment_type in equipment_cost:
		var required := int(equipment_cost[equipment_type])
		var available := int(force.get("equipment", {}).get(equipment_type, 0))
		var ratio := float(available) / float(max(1, required))
		equipment_bonus += ratio * 0.1  # 10% bonus per equipment ratio
	
	return 1.0 + equipment_bonus

func _calculate_supply_bonus(force: Dictionary, unit_type: String) -> float:
	"""Calculate supply bonus for a unit type"""
	var unit_stats = UNIT_TYPES.get(unit_type, {})
	var supply_cost = unit_stats.get("supply_cost", {})
	var supply_bonus := 0.0
	
	# Check if force has required supplies
	for supply_type in supply_cost:
		var required := int(supply_cost[supply_type])
		var available := int(force.get("supplies", {}).get(supply_type, 0))
		var ratio := float(available) / float(max(1, required))
		supply_bonus += ratio * 0.05  # 5% bonus per supply ratio
	
	return 1.0 + supply_bonus

func _apply_tactical_modifiers(stats: Dictionary, force: Dictionary, role: String) -> Dictionary:
	"""Apply tactical modifiers to force stats"""
	var modified_stats := stats.duplicate()
	
	# Terrain advantage (if specified)
	if force.has("terrain_advantage"):
		modified_stats.total_attack *= TACTICAL_BONUSES.terrain_advantage
		modified_stats.total_defense *= TACTICAL_BONUSES.terrain_advantage
	
	# Morale advantage
	if modified_stats.avg_morale > 70:
		modified_stats.total_attack *= TACTICAL_BONUSES.morale_advantage
		modified_stats.total_defense *= TACTICAL_BONUSES.morale_advantage
	elif modified_stats.avg_morale < 30:
		modified_stats.total_attack *= 0.8
		modified_stats.total_defense *= 0.8
	
	# Equipment advantage
	var equipment_ratio := _calculate_equipment_ratio(force)
	if equipment_ratio > 0.8:
		modified_stats.total_attack *= TACTICAL_BONUSES.equipment_advantage
		modified_stats.total_defense *= TACTICAL_BONUSES.equipment_advantage
	
	return modified_stats

func _calculate_equipment_ratio(force: Dictionary) -> float:
	"""Calculate overall equipment ratio for a force"""
	var total_required := 0
	var total_available := 0
	
	for unit_type in force.get("units", {}):
		var count := int(force.units[unit_type])
		var unit_stats = UNIT_TYPES.get(unit_type, {})
		var equipment_cost = unit_stats.get("equipment_cost", {})
		
		for equipment_type in equipment_cost:
			var required := int(equipment_cost[equipment_type]) * count
			var available := int(force.get("equipment", {}).get(equipment_type, 0))
			
			total_required += required
			total_available += min(available, required)
	
	return float(total_available) / float(max(1, total_required))

func _determine_battle_outcome(attacker_stats: Dictionary, defender_stats: Dictionary, battle_type: String) -> Dictionary:
	"""Determine the outcome of a battle"""
	# Calculate battle power
	var attacker_power = attacker_stats.total_attack + attacker_stats.total_defense
	var defender_power = defender_stats.total_attack + defender_stats.total_defense
	
	# Add randomness (dice roll)
	var attacker_roll := randi() % 20 + 1  # 1-20
	var defender_roll := randi() % 20 + 1  # 1-20
	
	attacker_power += attacker_roll
	defender_power += defender_roll
	
	# Determine victor
	var victor := "defender"  # Default to defender (defense advantage)
	var margin := 0.0
	
	if attacker_power > defender_power:
		victor = "attacker"
		margin = float(attacker_power - defender_power) / float(max(1, defender_power))
	else:
		margin = float(defender_power - attacker_power) / float(max(1, attacker_power))
	
	# Determine battle severity based on margin
	var severity := "light"
	if margin > 0.5:
		severity = "heavy"
	elif margin > 0.2:
		severity = "moderate"
	
	return {
		"victor": victor,
		"severity": severity,
		"attacker_power": attacker_power,
		"defender_power": defender_power,
		"margin": margin
	}

func _calculate_losses(attacker_stats: Dictionary, defender_stats: Dictionary, battle_result: Dictionary) -> Dictionary:
	"""Calculate losses for both sides"""
	var severity = battle_result.get("severity", "light")
	var victor = battle_result.get("victor", "defender")
	
	# Base loss rates by severity
	var loss_rates := {
		"light": {"victor": 0.05, "loser": 0.15},
		"moderate": {"victor": 0.10, "loser": 0.25},
		"heavy": {"victor": 0.20, "loser": 0.40}
	}
	
	var rates = loss_rates.get(severity, loss_rates.light)
	
	# Calculate losses
	var attacker_losses := 0
	var defender_losses := 0
	
	if victor == "attacker":
		attacker_losses = int(attacker_stats.unit_count * rates.victor)
		defender_losses = int(defender_stats.unit_count * rates.loser)
	else:
		attacker_losses = int(attacker_stats.unit_count * rates.loser)
		defender_losses = int(defender_stats.unit_count * rates.victor)
	
	return {
		"attacker": attacker_losses,
		"defender": defender_losses
	}

func _calculate_gains(attacker: Dictionary, defender: Dictionary, battle_result: Dictionary) -> Dictionary:
	"""Calculate gains for the victor"""
	var victor = battle_result.get("victor", "defender")
	var severity = battle_result.get("severity", "light")
	
	if victor != "attacker":
		return {"gold": 0, "equipment": {}, "supplies": {}}
	
	# Calculate gains based on severity and defender's resources
	var gains := {"gold": 0, "equipment": {}, "supplies": {}}
	
	# Gold gains
	var base_gold := int(defender.get("gold", 0))
	var gold_multiplier := {"light": 0.1, "moderate": 0.2, "heavy": 0.3}
	gains.gold = int(base_gold * gold_multiplier.get(severity, 0.1))
	
	# Equipment gains (partial)
	var defender_equipment = defender.get("equipment", {})
	for equipment_type in defender_equipment:
		var available := int(defender_equipment[equipment_type])
		var gain_rate := {"light": 0.05, "moderate": 0.1, "heavy": 0.2}
		gains.equipment[equipment_type] = int(available * gain_rate.get(severity, 0.05))
	
	# Supply gains (partial)
	var defender_supplies = defender.get("supplies", {})
	for supply_type in defender_supplies:
		var available := int(defender_supplies[supply_type])
		var gain_rate := {"light": 0.1, "moderate": 0.2, "heavy": 0.3}
		gains.supplies[supply_type] = int(available * gain_rate.get(severity, 0.1))
	
	return gains

func _apply_equipment_consumption(attacker: Dictionary, defender: Dictionary, losses: Dictionary) -> void:
	"""Apply equipment consumption based on losses"""
	# Calculate equipment consumption for losses
	var attacker_consumption := _calculate_equipment_consumption(attacker, losses.attacker)
	var defender_consumption := _calculate_equipment_consumption(defender, losses.defender)
	
	# Apply consumption (this would need integration with actual resource systems)
	# For now, just emit signals
	for equipment_type in attacker_consumption:
		equipment_consumed.emit(equipment_type, attacker_consumption[equipment_type])
	
	for equipment_type in defender_consumption:
		equipment_consumed.emit(equipment_type, defender_consumption[equipment_type])

func _calculate_equipment_consumption(force: Dictionary, losses: int) -> Dictionary:
	"""Calculate equipment consumption for given losses"""
	var consumption := {}
	
	# Calculate consumption based on unit types and their equipment costs
	for unit_type in force.get("units", {}):
		var unit_count = int(force.units[unit_type])
		var unit_stats = UNIT_TYPES.get(unit_type, {})
		var equipment_cost = unit_stats.get("equipment_cost", {})
		
		# Calculate proportion of this unit type in losses
		var total_units := 0
		for u in force.get("units", {}):
			total_units += int(force.units[u])
		
		if total_units <= 0:
			continue
			
		var unit_losses := int(losses * float(unit_count) / float(total_units))
		
		# Calculate equipment consumption for these losses
		for equipment_type in equipment_cost:
			var cost_per_unit := int(equipment_cost[equipment_type])
			var total_consumption := unit_losses * cost_per_unit
			
			if equipment_type in consumption:
				consumption[equipment_type] += total_consumption
			else:
				consumption[equipment_type] = total_consumption
	
	return consumption

# === Public API ===
func create_force(units: Dictionary, equipment: Dictionary = {}, supplies: Dictionary = {}, gold: int = 0) -> Dictionary:
	"""Create a military force with given composition"""
	return {
		"units": units,
		"equipment": equipment,
		"supplies": supplies,
		"gold": gold
	}

func get_unit_types() -> Dictionary:
	"""Get available unit types and their stats"""
	return UNIT_TYPES.duplicate(true)

func simulate_raid(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	"""Simulate a raid battle"""
	return resolve_battle(attacker, defender, "raid")

func simulate_siege(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	"""Simulate a siege battle"""
	return resolve_battle(attacker, defender, "siege")

func simulate_skirmish(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	"""Simulate a skirmish battle"""
	return resolve_battle(attacker, defender, "skirmish")
