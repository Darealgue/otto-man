extends Node

@onready var time_slow_effect = $CanvasLayer/TimeSlowEffect

func _ready():
	# Start with effects disabled
	time_slow_effect.visible = false
	Engine.time_scale = 1.0  # Ensure we start with normal time scale

func slow_time(scale: float = 0.2, duration: float = 1.0) -> void:
	
	# Immediately set time scale
	Engine.time_scale = scale
	
	time_slow_effect.visible = true
	
	# Create tween to fade in effect
	var effect_tween = create_tween()
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.7, 0.1)
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.6, 0.1)
	
	# Create timer to restore time scale after duration
	var timer = get_tree().create_timer(duration)  # Don't adjust for slowed time
	await timer.timeout
	
	
	# Fade out effect
	var fade_tween = create_tween()
	fade_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.0, 0.2)
	fade_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.0, 0.2)
	fade_tween.tween_callback(func(): 
		time_slow_effect.visible = false
	)
	
	# Restore time scale
	Engine.time_scale = 1.0

func apply_time_slow_effect():
	slow_time(0.2, 1.0)  # Use standard values for testing
	
