extends PowerupEffect

const BASE_SPEED = 300.0  # Base movement speed
const MAX_DAMAGE_BOOST = 0.5  # Maximum 50% extra damage at high speeds
const UPDATE_THRESHOLD = 0.02  # Lower threshold for speed updates (2% change)

var current_damage_boost := 0.0
var current_multiplier := 1.0
var update_timer := 0.0

func _init() -> void:
	powerup_name = "Momentum Master"
	description = "Deal more damage based on movement speed"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["base_damage"]  # Add affected_stats
	tree_name = "mobility"  # Add tree association

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	current_damage_boost = 0.0
	current_multiplier = 1.0
	var attack_manager = get_node("/root/AttackManager")
	if attack_manager:
		# print("[DEBUG] Momentum Master - Initializing with no boost")
		attack_manager.add_damage_multiplier(player, 1.0, "momentum_master")

func deactivate(player: CharacterBody2D) -> void:
	if !is_instance_valid(player):
		var attack_manager = get_node("/root/AttackManager")
		if attack_manager:
			# print("[DEBUG] Momentum Master - Removing multiplier:", current_multiplier)
			attack_manager.remove_damage_multiplier(player, current_multiplier, "momentum_master")
		super.deactivate(player)

func update(player: CharacterBody2D, delta: float) -> void:
	update_timer += delta
	if update_timer >= 0.1:  # Update every 0.1 seconds
		update_timer = 0.0
		
		# Calculate speed ratio (0 to 1)
		var current_speed = abs(player.velocity.x)
		var speed_ratio = min(current_speed / BASE_SPEED, 1.0)
		var new_boost = speed_ratio * MAX_DAMAGE_BOOST
		
		# Only update if boost has changed significantly
		if abs(new_boost - current_damage_boost) > UPDATE_THRESHOLD:
			var attack_manager = get_node("/root/AttackManager")
			if attack_manager:
				# Remove old multiplier
				attack_manager.remove_damage_multiplier(player, current_multiplier, "momentum_master")
				
				# Apply new multiplier
				current_damage_boost = new_boost
				current_multiplier = 1.0 + current_damage_boost
				# print("[DEBUG] Momentum Master - Updating multiplier:", current_multiplier, " (", current_damage_boost * 100, "% boost)")
				attack_manager.add_damage_multiplier(player, current_multiplier, "momentum_master")