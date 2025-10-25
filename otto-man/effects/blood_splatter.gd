class_name BloodSplatter
extends Node2D

@export var fade_duration: float = 10.0  # How long before splatter fades
@export var fade_start_time: float = 5.0  # When to start fading

var fade_timer: float = 0.0
var is_fading: bool = false

func _ready() -> void:
	# Random color variation for blood splatters
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var color_variation = randf_range(0.7, 1.0)
		sprite.modulate = Color(color_variation, color_variation * 0.6, color_variation * 0.6, 1.0)
	
	# Start fade timer
	fade_timer = fade_start_time

func _process(delta: float) -> void:
	if is_fading:
		fade_timer -= delta
		
		if fade_timer <= 0.0:
			queue_free()
		else:
			# Fade out over time
			var alpha = fade_timer / fade_duration
			alpha = clamp(alpha, 0.0, 1.0)
			
			if has_node("Sprite2D"):
				var sprite = $Sprite2D
				var current_color = sprite.modulate
				sprite.modulate = Color(current_color.r, current_color.g, current_color.b, alpha)
	else:
		fade_timer -= delta
		if fade_timer <= 0.0:
			is_fading = true
			fade_timer = fade_duration
