extends PowerupResource

func _init() -> void:
	name = "Shield Break Time"
	description = "When your shield breaks, time slows down for 2 seconds"
	powerup_type = PowerupType.SHIELD_BREAK_TIME
	rarity = Rarity.RARE
	required_powerups = [PowerupType.SHIELD]
	synergy_level = 1  # Tier 1 synergy

func apply_powerup(player: CharacterBody2D) -> void:
	# Connect directly to player's shield_broken signal
	if player.has_signal("shield_broken"):
		print("DEBUG: Connecting to player's shield_broken signal")
		player.shield_broken.connect(_on_shield_broken.bind(player))
	else:
		print("DEBUG: Player does not have shield_broken signal!")

func _on_shield_broken(player: CharacterBody2D) -> void:
	print("DEBUG: Shield break detected - Slowing time")
	# Slow time for 2 seconds
	Engine.time_scale = 0.3
	
	# Show visual effect
	if player.has_node("TimeSlowEffect"):
		var effect = player.get_node("TimeSlowEffect")
		effect.visible = true
		
		# Create tween to fade in effect
		var effect_tween = player.create_tween()
		effect_tween.tween_property(effect.material, "shader_parameter/vignette_opacity", 0.5, 0.2)
		effect_tween.tween_property(effect.material, "shader_parameter/desaturation", 0.4, 0.2)
		
		# Create tween to restore time scale and fade out effect
		var restore_tween = player.create_tween()
		restore_tween.tween_interval(2.0)  # Wait for 2 seconds
		restore_tween.tween_callback(func():
			# Fade out effect
			var fade_tween = player.create_tween()
			fade_tween.tween_property(effect.material, "shader_parameter/vignette_opacity", 0.0, 0.3)
			fade_tween.tween_property(effect.material, "shader_parameter/desaturation", 0.0, 0.3)
			fade_tween.tween_callback(func(): effect.visible = false)
			
			# Restore time scale
			var time_tween = player.create_tween()
			time_tween.tween_property(Engine, "time_scale", 1.0, 0.3)
		) 
