extends Node

@onready var time_slow_effect = $CanvasLayer/TimeSlowEffect

func _ready():
	# Start with effects disabled
	time_slow_effect.visible = false
	print("DEBUG: ScreenEffects initialized, TimeSlowEffect visibility:", time_slow_effect.visible)
	print("DEBUG: Initial shader parameters:", 
		"\n - vignette_opacity:", time_slow_effect.material.get_shader_parameter("vignette_opacity"),
		"\n - desaturation:", time_slow_effect.material.get_shader_parameter("desaturation"))

func apply_time_slow_effect():
	print("DEBUG: Starting time slow effect application")
	print("DEBUG: TimeSlowEffect node valid:", is_instance_valid(time_slow_effect))
	print("DEBUG: TimeSlowEffect material valid:", is_instance_valid(time_slow_effect.material))
	
	# Slow down time
	Engine.time_scale = 0.3
	
	time_slow_effect.visible = true
	print("DEBUG: Set TimeSlowEffect visible")
	
	# Create tween to fade in effect
	var effect_tween = create_tween()
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.7, 0.2)
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.6, 0.2)
	print("DEBUG: Created fade-in tween")
	
	# Create tween to restore time scale and fade out effect
	var restore_tween = create_tween()
	restore_tween.tween_interval(2.0)  # Wait for 2 seconds
	restore_tween.tween_callback(func():
		print("DEBUG: Starting effect fade-out")
		# Fade out effect
		var fade_tween = create_tween()
		fade_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.0, 0.3)
		fade_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.0, 0.3)
		fade_tween.tween_callback(func(): 
			time_slow_effect.visible = false
			print("DEBUG: Effect fade-out complete, TimeSlowEffect hidden")
		)
		
		# Restore time scale
		var time_tween = create_tween()
		time_tween.tween_property(Engine, "time_scale", 1.0, 0.3)
		print("DEBUG: Time scale restoration started")
	) 