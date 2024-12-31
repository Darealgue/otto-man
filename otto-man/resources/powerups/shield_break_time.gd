@tool
extends PowerupEffect

@export var time_slow_duration: float = 1.0  # Duration of time slow effect
@export var time_slow_factor: float = 0.5  # How much to slow time (0.5 = half speed)
@export var cooldown_reduction: float = 0.3  # 30% shield cooldown reduction

func _init() -> void:
	powerup_name = "Shield Break Time"
	description = "Perfect blocks slow time to {slow}% for {duration}s. Shield cooldown reduced by {cooldown}%".format({
		"slow": time_slow_factor * 100,
		"duration": time_slow_duration,
		"cooldown": cooldown_reduction * 100
	})
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE

func apply(player: CharacterBody2D) -> void:
	print("[DEBUG] Applying Shield Break Time")
	modify_stat("shield_cooldown", 1.0 - cooldown_reduction, true)
	
	# Connect to player's block signals if not already connected
	if player.has_signal("shield_broken") and !player.shield_broken.is_connected(_on_shield_broken):
		player.shield_broken.connect(_on_shield_broken)

func remove(player: CharacterBody2D) -> void:
	print("[DEBUG] Removing Shield Break Time")
	modify_stat("shield_cooldown", 1.0, true)
	
	# Disconnect signals
	if player.has_signal("shield_broken"):
		if player.shield_broken.is_connected(_on_shield_broken):
			player.shield_broken.disconnect(_on_shield_broken)

func update(_player: CharacterBody2D, _delta: float) -> void:
	pass  # No continuous updates needed

func _on_shield_broken() -> void:
	# Get the ScreenEffects singleton
	var screen_effects = get_node_or_null("/root/ScreenEffects")
	if screen_effects and screen_effects.has_method("slow_time"):
		screen_effects.slow_time(time_slow_duration, time_slow_factor)

# Synergize with other defensive powerups
func has_synergy_with(other: PowerupEffect) -> bool:
	return other.powerup_type == PowerupType.DEFENSE 
