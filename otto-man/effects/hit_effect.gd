extends Node2D

@onready var particles = $GPUParticles2D
@onready var flash = $Flash

func _ready() -> void:
	# Set z-index to appear above decorations but behind player
	z_index = 10
	
	# Start particles
	particles.emitting = true
	
	# Flash animation
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	
	# Delete after particles finish
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()

func setup(color: Color = Color(1, 0.9, 0.2), size: float = 1.0) -> void:
	particles.process_material.color = color
	scale = Vector2(size, size) 