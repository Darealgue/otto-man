extends Node2D

@export var blood_particle_scene: PackedScene = preload("res://effects/blood_particle.tscn")
@export var blood_splatter_scene: PackedScene = preload("res://effects/blood_splatter.tscn")

func _ready() -> void:
	# Test blood particle system
	call_deferred("test_blood_system")

func test_blood_system() -> void:
	print("Testing blood particle system...")
	
	# Spawn blood particles
	for i in range(8):
		var particle = blood_particle_scene.instantiate()
		add_child(particle)
		
		# Position particle at center with slight random offset
		var offset = Vector2(
			randf_range(-20, 20),
			randf_range(-10, 10)
		)
		particle.global_position = global_position + offset
		
		# Set up blood splatter scene reference
		if particle.has_method("set_blood_splatter_scene"):
			particle.set_blood_splatter_scene(blood_splatter_scene)
	
	print("Blood particles spawned!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space key
		test_blood_system()
