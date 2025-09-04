extends Node

# Hitstop System Configuration
const HITSTOP_LEVELS = {
	1: 0.02,     # 0-30 damage: Hafif hitstop (oyuncu 15 hasarla başlıyor)
	2: 0.04,     # 31-60 damage: Orta hitstop
	3: 0.08      # 61+ damage: Güçlü hitstop
}

const HITSTOP_TIME_SCALE = 0.1  # How much to slow down time during hitstop

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
var critical_strike_active = {}  # Track critical strike powerups per player
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
			# Apply critical strike
			return apply_critical_strike(player, final_damage)
		else:
			# Since no specific multiplier was found, use the general air attack multiplier of 1.2
			var final_damage = modified_base * 1.2  # Default air attack bonus
			# Apply critical strike
			return apply_critical_strike(player, final_damage)
	
	# Always use a damage multiplier of 1.0 for other attacks
	var final_damage = modified_base * 1.0
	
	# Apply critical strike
	return apply_critical_strike(player, final_damage)

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

# Critical Strike System
func enable_critical_strike(player: Node, crit_chance: float, crit_multiplier: float) -> void:
	if not critical_strike_active.has(player):
		critical_strike_active[player] = []
	
	critical_strike_active[player].append({
		"chance": crit_chance,
		"multiplier": crit_multiplier
	})

func disable_critical_strike(player: Node) -> void:
	if critical_strike_active.has(player):
		critical_strike_active[player].clear()

func apply_critical_strike(player: Node, base_damage: float) -> float:
	if not critical_strike_active.has(player) or critical_strike_active[player].is_empty():
		return base_damage
	
	# Check each critical strike powerup
	for crit_data in critical_strike_active[player]:
		if randf() < crit_data["chance"]:
			var final_damage = base_damage * crit_data["multiplier"]
			print("[Critical Strike] CRITICAL HIT! Damage: " + str(base_damage) + " -> " + str(final_damage))
			return final_damage
	
	return base_damage

# Hitstop System Functions
func get_hitstop_duration(damage: float) -> float:
	# Determine hitstop level based on damage
	var level = 1  # Default to level 1 (hafif hitstop)
	if damage >= 61:
		level = 3
	elif damage >= 31:
		level = 2
	# else: level = 1 (default)
	
	return HITSTOP_LEVELS[level]

func apply_hitstop(damage: float) -> void:
	var hitstop_duration = get_hitstop_duration(damage)
	if hitstop_duration <= 0:
		print("[Hitstop] No hitstop applied for " + str(damage) + " damage (too low)")
		return
	
	# Debug prints disabled to reduce console spam
	# print("[Hitstop] 🎯 STARTING HITSTOP!")
	# print("[Hitstop] Damage: " + str(damage) + " | Duration: " + str(hitstop_duration) + "s")
	# print("[Hitstop] Time scale changing from " + str(Engine.time_scale) + " to " + str(HITSTOP_TIME_SCALE))
	
	# Slow down time
	Engine.time_scale = HITSTOP_TIME_SCALE
	
	# Create timer for hitstop duration
	var hitstop_timer = get_tree().create_timer(hitstop_duration)
	hitstop_timer.timeout.connect(_on_hitstop_finished)

func _on_hitstop_finished() -> void:
	# Restore normal time scale
	Engine.time_scale = 1.0
	# Debug prints disabled to reduce console spam
	# print("[Hitstop] ✅ HITSTOP FINISHED!")
	# print("[Hitstop] Time scale restored to " + str(Engine.time_scale)) 
