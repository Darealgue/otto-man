extends Node2D

@onready var label = $Label

const FLOAT_SPEED = 100  # Pixels per second upward speed
const LIFETIME = 1.0     # How long the number exists
const SPREAD_RANGE = 50  # Maximum horizontal spread
const CRIT_SCALE = 1.4

var velocity = Vector2.ZERO
var time_alive = 0.0

func _ready() -> void:
	# Set initial velocity with random spread
	var spread = randf_range(-SPREAD_RANGE, SPREAD_RANGE)
	velocity = Vector2(spread, -FLOAT_SPEED)
	
	# Start big
	scale = Vector2(1.5, 1.5)

func _process(delta: float) -> void:
	# Update position based on velocity
	position += velocity * delta
	
	# Track lifetime
	time_alive += delta
	
	# Scale down over time
	var scale_factor = lerp(1.5, 0.7, time_alive / LIFETIME)
	scale = Vector2(scale_factor, scale_factor)
	
	# Fade out near the end
	if time_alive > LIFETIME * 0.7:
		modulate.a = lerp(1.0, 0.0, (time_alive - LIFETIME * 0.7) / (LIFETIME * 0.3))
	
	# Delete when lifetime is over
	if time_alive >= LIFETIME:
		queue_free()

func setup(damage: int, is_crit: bool = false) -> void:
	# Set the damage text
	label.text = str(damage)
	
	# Critical hit formatting
	if is_crit:
		scale = Vector2(CRIT_SCALE * 1.5, CRIT_SCALE * 1.5)  # Start even bigger for crits
		label.modulate = Color(1.0, 0.2, 0.2)  # Red for crits
	else:
		label.modulate = Color(1.0, 0.9, 0.2)  # Slightly yellow-tinted for better visibility
