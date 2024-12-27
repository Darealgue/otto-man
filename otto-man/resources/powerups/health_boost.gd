extends PowerupResource

const HEALTH_INCREASE_PERCENT = 0.2  # 20% per stack

func _init() -> void:
	id = "health_boost"
	name = "Health Boost"
	description = "Increases max health by 20%"
	can_stack = true

func apply_effect(player: CharacterBody2D) -> void:
	update_stack_effect(player)

func update_stack_effect(player: CharacterBody2D) -> void:
	# Calculate new max health based on player's base max health
	var health_multiplier = 1 + (HEALTH_INCREASE_PERCENT * stack_count)
	var new_max_health = int(player.base_max_health * health_multiplier)
	
	# Update the player's health
	if player.has_method("set_max_health"):
		player.set_max_health(new_max_health)
	else:
		# Fallback if method doesn't exist
		player.health = new_max_health
		if player.has_signal("health_changed"):
			player.health_changed.emit(new_max_health)

func remove_effect(player: CharacterBody2D) -> void:
	# Reset to base max health
	if player.has_method("set_max_health"):
		player.set_max_health(player.base_max_health)
	else:
		# Fallback if method doesn't exist
		player.health = min(player.health, player.base_max_health)
		if player.has_signal("health_changed"):
			player.health_changed.emit(player.health) 
