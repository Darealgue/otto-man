extends BaseChunk

func _ready() -> void:
	chunk_type = "combat"  # Set this as a combat chunk
	super._ready()  # Call parent _ready to initialize spawn manager

func get_connections() -> Array:
	return [0, 1]  # Left and right connections

# Override to add special combat arena behavior
func start_spawning(interval: float = 5.0) -> void:
	if spawn_manager:
		# Combat arenas might want shorter spawn intervals
		spawn_manager.start_all_spawning(interval * 0.7)  # 30% faster spawning 