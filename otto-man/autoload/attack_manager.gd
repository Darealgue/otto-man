extends Node

# Base attack configurations
const BASE_CONFIG = {
	"light": {
		"base_damage": 15.0,
		"combo_multipliers": {
			"light_attack1": {"damage": 1.0, "knockback": 1.0},
			"light_attack2": {"damage": 1.2, "knockback": 1.5},
			"light_attack3": {"damage": 1.5, "knockback": 2.0}
		},
		"base_knockback": {
			"force": 100.0,
			"up_force": 50.0
		}
	},
	"heavy": {
		"base_damage": 30.0,
		"base_knockback": {
			"force": 200.0,
			"up_force": 100.0
		}
	}
}

# Stores active modifiers for each player
var player_modifiers = {}
@onready var player_stats = get_node("/root/PlayerStats")

func register_player(player: Node) -> void:
	if not player_modifiers.has(player):
		player_modifiers[player] = {
			"damage_multipliers": [],  # List of active damage multipliers
			"knockback_multipliers": [],  # List of active knockback multipliers
			"combo_modifiers": []  # List of active combo modifiers
		}

func unregister_player(player: Node) -> void:
	if player_modifiers.has(player):
		player_modifiers.erase(player)

# Add a new damage multiplier
func add_damage_multiplier(player: Node, multiplier: float, source: String = "") -> void:
	if not player_modifiers.has(player):
		register_player(player)
	
	player_modifiers[player]["damage_multipliers"].append({
		"value": multiplier,
		"source": source
	})

# Remove a specific damage multiplier
func remove_damage_multiplier(player: Node, multiplier: float, source: String = "") -> void:
	if not player_modifiers.has(player):
		return
	
	var multipliers = player_modifiers[player]["damage_multipliers"]
	for i in range(multipliers.size() - 1, -1, -1):
		if multipliers[i]["value"] == multiplier and multipliers[i]["source"] == source:
			multipliers.remove_at(i)
			break

# Calculate final damage for an attack
func calculate_attack_damage(player: Node, attack_type: String, attack_name: String) -> float:
	if not player_modifiers.has(player):
		register_player(player)
	
	# Get base damage from PlayerStats instead of BASE_CONFIG
	var base_damage = player_stats.get_stat("base_damage")
	
	# Calculate total powerup multiplier first
	var total_powerup_multiplier = 1.0
	for mult in player_modifiers[player]["damage_multipliers"]:
		total_powerup_multiplier *= mult["value"]
	
	# Apply powerup multipliers to base damage first
	var modified_base = base_damage * total_powerup_multiplier
	
	# Then apply combo multiplier to the modified base damage
	var combo_mult = BASE_CONFIG[attack_type]["combo_multipliers"][attack_name]["damage"]
	var final_damage = modified_base * combo_mult
	
	
	return final_damage

# Calculate knockback for an attack
func calculate_knockback(player: Node, attack_type: String, attack_name: String) -> Dictionary:
	if not player_modifiers.has(player):
		register_player(player)
	
	var base_knockback = BASE_CONFIG[attack_type]["base_knockback"]
	var combo_knockback = BASE_CONFIG[attack_type]["combo_multipliers"][attack_name]["knockback"]
	
	var force = base_knockback["force"] * combo_knockback
	var up_force = base_knockback["up_force"] * combo_knockback
	
	# Apply knockback multipliers
	for mult in player_modifiers[player]["knockback_multipliers"]:
		force *= mult["value"]
		up_force *= mult["value"]
	
	return {
		"force": force,
		"up_force": up_force
	}

# Get total damage multiplier for UI display
func get_total_damage_multiplier(player: Node) -> float:
	if not player_modifiers.has(player):
		return 1.0
	
	var total = 1.0
	for mult in player_modifiers[player]["damage_multipliers"]:
		total *= mult["value"]
	return total 
