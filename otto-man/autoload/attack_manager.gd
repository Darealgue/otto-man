extends Node

# Base attack configurations
const BASE_CONFIG = {
	"light": {
		"base_damage": 15.0,
		"combo_multipliers": {
			"light_attack1": {"damage": 1.0, "knockback": 1.0},
			"light_attack2": {"damage": 1.2, "knockback": 1.5},
			"light_attack3": {"damage": 1.5, "knockback": 2.0},
			# Add air attack configurations
			"air_attack1": {"damage": 1.2, "knockback": 1.2},
			"air_attack2": {"damage": 1.4, "knockback": 1.6},
			"air_attack3": {"damage": 1.6, "knockback": 2.0}
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
	
	# Check if the attack name is an air attack
	if attack_name.begins_with("air_attack"):
		# Check if we have a specific multiplier for this air attack
		if BASE_CONFIG.has(attack_type) and BASE_CONFIG[attack_type].has("combo_multipliers") and BASE_CONFIG[attack_type]["combo_multipliers"].has(attack_name):
			var damage_multiplier = BASE_CONFIG[attack_type]["combo_multipliers"][attack_name]["damage"]
			var final_damage = modified_base * damage_multiplier
			return final_damage
		else:
			# Since no specific multiplier was found, use the general air attack multiplier of 1.2
			var final_damage = modified_base * 1.2  # Default air attack bonus
			return final_damage
	
	# Always use a damage multiplier of 1.0 for other attacks
	var final_damage = modified_base * 1.0
	
	return final_damage

# Calculate knockback for an attack
func calculate_knockback(player: Node, attack_type: String, attack_name: String) -> Dictionary:
	if not player_modifiers.has(player):
		register_player(player)
	
	var base_knockback = BASE_CONFIG[attack_type]["base_knockback"]
	
	# Use a fixed knockback multiplier of 1.0 for all attacks
	var knockback_multiplier = 1.0
	
	# Check if the attack name is an air attack and we have specific multipliers
	if attack_name.begins_with("air_attack") and BASE_CONFIG.has(attack_type) and BASE_CONFIG[attack_type].has("combo_multipliers") and BASE_CONFIG[attack_type]["combo_multipliers"].has(attack_name):
		knockback_multiplier = BASE_CONFIG[attack_type]["combo_multipliers"][attack_name]["knockback"]
	
	var force = base_knockback["force"] * knockback_multiplier
	var up_force = base_knockback["up_force"] * knockback_multiplier
	
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
