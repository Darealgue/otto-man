extends PowerupEffect

const MAX_DAMAGE_BOOST = 1.0  # Up to 100% more damage at low health
const DAMAGE_PER_MISSING_HEALTH = 0.01  # 1% damage increase per missing health point

var current_damage_boost := 0.0
var current_multiplier := 1.0
var update_timer := 0.0

func _init() -> void:
	powerup_name = "Berserker Gambit"
	description = "Deal more damage when at low health"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["base_damage"]

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	current_damage_boost = 0.0
	current_multiplier = 1.0
	
	# Ensure player stats are properly initialized
	if player_stats:
		var max_health = player_stats.get_stat("max_health")
		var current_health = player_stats.get_stat("current_health")
		if current_health <= 0:
			print("[DEBUG] Berserker Gambit - Initializing current health to max health")
			player_stats.add_stat_bonus("current_health", max_health)
	
	var attack_manager = get_node("/root/AttackManager")
	if attack_manager:
		print("[DEBUG] Berserker Gambit - Initializing with no boost")
		attack_manager.add_damage_multiplier(player, 1.0, "berserker_gambit")
		_update_damage_boost(player)  # Initial update

func process(player: CharacterBody2D, delta: float) -> void:
	if !player or !is_instance_valid(player):
		return
		
	update_timer += delta
	if update_timer >= 0.1:  # Update every 0.1 seconds
		update_timer = 0.0
		_update_damage_boost(player)

func _update_damage_boost(player: CharacterBody2D) -> void:
	if !player or !is_instance_valid(player):
		return
		
	var max_health = player_stats.get_stat("max_health")
	var current_health = player_stats.get_stat("current_health")
	var missing_health = max_health - current_health
	
	print("[DEBUG] Berserker Gambit - Health status:")
	print("   Max Health:", max_health)
	print("   Current Health:", current_health)
	print("   Missing Health:", missing_health)
	print("   Player Stats Valid:", is_instance_valid(player_stats))
	
	# Calculate new damage boost based on missing health percentage
	var health_percentage = current_health / max_health if max_health > 0 else 1.0
	var new_boost = min((1.0 - health_percentage) * MAX_DAMAGE_BOOST, MAX_DAMAGE_BOOST)
	
	# Only update if boost has changed significantly
	if abs(new_boost - current_damage_boost) > 0.01:  # 1% threshold
		var attack_manager = get_node("/root/AttackManager")
		if attack_manager:
			# Remove old multiplier
			attack_manager.remove_damage_multiplier(player, current_multiplier, "berserker_gambit")
			
			# Apply new multiplier
			current_damage_boost = new_boost
			current_multiplier = 1.0 + current_damage_boost
			
			print("[DEBUG] Berserker Gambit - Updating damage boost:")
			print("   Health Percentage:", health_percentage * 100, "%")
			print("   Missing Health:", missing_health)
			print("   Damage Boost:", current_damage_boost * 100, "%")
			print("   New Multiplier:", current_multiplier)
			
			attack_manager.add_damage_multiplier(player, current_multiplier, "berserker_gambit")

func deactivate(player: CharacterBody2D) -> void:
	print("[DEBUG] Berserker Gambit - Deactivating...")
	print("   Player valid:", is_instance_valid(player))
	print("   Current multiplier:", current_multiplier)
	
	var attack_manager = get_node("/root/AttackManager")
	if attack_manager:
		print("[DEBUG] Berserker Gambit - Removing multiplier:", current_multiplier)
		attack_manager.remove_damage_multiplier(player, current_multiplier, "berserker_gambit")
	super.deactivate(player)

# Synergize with damage and defense powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups 
