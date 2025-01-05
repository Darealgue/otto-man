extends Node

@onready var time_slow_effect = $CanvasLayer/TimeSlowEffect

func _ready():
	# Start with effects disabled
	time_slow_effect.visible = false

func apply_time_slow_effect():
	
	# Slow down time
	Engine.time_scale = 0.3
	
	time_slow_effect.visible = true
	
	# Create tween to fade in effect
	var effect_tween = create_tween()
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.7, 0.2)
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.6, 0.2)
	
	# Create tween to restore time scale and fade out effect
	var restore_tween = create_tween()
	restore_tween.tween_interval(2.0)  # Wait for 2 seconds
	restore_tween.tween_callback(func():
		# Fade out effect
		var fade_tween = create_tween()
		fade_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.0, 0.3)
		fade_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.0, 0.3)
		fade_tween.tween_callback(func(): 
			time_slow_effect.visible = false
		)
		
		# Restore time scale
		var time_tween = create_tween()
		time_tween.tween_property(Engine, "time_scale", 1.0, 0.3)
	) 
