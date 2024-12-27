extends Node2D

@onready var label = $Label

const FLOAT_SPEED = -50  # Speed at which the number floats up
const DURATION = 1.0     # How long the number stays visible
const SPREAD = 30       # How far horizontally the number can spread

func _ready() -> void:
	# Add random horizontal spread
	position.x += randf_range(-SPREAD, SPREAD)
	
	# Create fade out and float up animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float up
	tween.tween_property(self, "position:y", position.y + FLOAT_SPEED, DURATION)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, DURATION)
	
	# Delete after animation
	tween.chain().tween_callback(queue_free)

func set_damage(amount: int) -> void:
	label.text = str(amount) 