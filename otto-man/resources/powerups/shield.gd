@tool
extends PowerupEffect

@export var shield_cooldown_reduction: float = 0.3  # 30% cooldown reduction
@export var shield_strength_bonus: float = 20.0  # +20 shield strength

func _init() -> void:
	powerup_name = "Shield Master"
	description = "Reduces shield cooldown by {cooldown}% and increases shield strength by {strength}".format({
		"cooldown": shield_cooldown_reduction * 100,
		"strength": shield_strength_bonus
	})
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE

func apply(player: CharacterBody2D) -> void:
	modify_stat("shield_cooldown", 1.0 - shield_cooldown_reduction, true)
	modify_stat("shield_strength", shield_strength_bonus)
	
	# Connect to player's block signals if not already connected
	if player.has_signal("shield_broken") and !player.shield_broken.is_connected(_on_shield_broken):
		player.shield_broken.connect(_on_shield_broken)

func remove(player: CharacterBody2D) -> void:
	modify_stat("shield_cooldown", 1.0, true)
	modify_stat("shield_strength", 0)
	
	# Disconnect signals
	if player.has_signal("shield_broken"):
		if player.shield_broken.is_connected(_on_shield_broken):
			player.shield_broken.disconnect(_on_shield_broken)

func update(_player: CharacterBody2D, _delta: float) -> void:
	pass  # No continuous updates needed

func _on_shield_broken() -> void:
	# Add visual feedback when shield breaks
	if player_stats:
		player_stats.emit_signal("effect_triggered", "shield_break")

# Shield synergizes with other defensive powerups
func has_synergy_with(other: PowerupEffect) -> bool:
	return other.powerup_type == PowerupType.DEFENSE