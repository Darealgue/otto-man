extends Node2D
class_name FiremageSpawner

@export var spawn_interval: float = 10.0
@export var max_firemages: int = 2
@export var spawn_range: float = 200.0

var firemage_scene = preload("res://enemy/firemage/firemage_enemy.tscn")
var current_firemages: Array[Node2D] = []
var spawn_timer: float = 0.0

func _ready() -> void:
	# Start spawning after a short delay
	await get_tree().create_timer(2.0).timeout
	spawn_timer = spawn_interval

func _physics_process(delta: float) -> void:
	# Clean up dead firemages
	current_firemages = current_firemages.filter(func(firemage): return is_instance_valid(firemage))
	
	# Spawn new firemage if needed
	if current_firemages.size() < max_firemages:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			_spawn_firemage()
			spawn_timer = 0.0

func _spawn_firemage() -> void:
	if not firemage_scene:
		return
	
	# Create firemage
	var firemage = firemage_scene.instantiate()
	get_tree().current_scene.add_child(firemage)
	
	# Position randomly around spawner
	var random_angle = randf() * 2 * PI
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_range
	firemage.global_position = global_position + spawn_offset
	
	# Add to tracking list
	current_firemages.append(firemage)
	
	# Connect death signal
	if firemage.has_signal("enemy_defeated"):
		firemage.enemy_defeated.connect(_on_firemage_defeated.bind(firemage))

func _on_firemage_defeated(firemage: Node2D) -> void:
	# Remove from tracking list
	current_firemages.erase(firemage)
